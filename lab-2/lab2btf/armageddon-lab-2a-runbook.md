# ARMAGEDDON — Lab 2A
## CloudFront Origin Cloaking: Architecture Documentation & Incident Runbook

| Field | Value |
|---|---|
| Project | dawgs-armageddon |
| Domain | app.thedawgs2025.click |
| Account ID | 778185677715 |
| Region | us-east-1 |
| Date | February 24, 2026 |

---

## 1. Architecture Overview

The Lab 2A architecture places CloudFront as the sole public entry point to a private application stack. No component behind CloudFront is directly reachable from the internet.

### 1.1 Traffic Flow

```
Internet → CloudFront (+WAF) → ALB (locked) → Private EC2 → RDS
```

### 1.2 Security Layers

Defense-in-depth is implemented across three independent enforcement points:

| Layer | Type | Enforcement |
|---|---|---|
| Layer 1 | Network (SG) | ALB SG allows port 80 inbound only from CloudFront prefix list `pl-3b927c52` |
| Layer 2 | Application (ALB Listener) | HTTPS listener default returns 403. Only requests with `X-Origin-Verify` header are forwarded |
| Layer 3 | Edge (WAF) | AWS Managed Rules enforced at CloudFront edge before traffic reaches ALB |

### 1.3 Key Resource IDs

| Resource | ID / Value |
|---|---|
| CloudFront Distribution | `E299RJP0LW0OTP` |
| CloudFront Domain | `d2q9xg5p4u19ed.cloudfront.net` |
| ALB DNS | `lab-alb01-776999256.us-east-1.elb.amazonaws.com` |
| ALB SG (HTTP) | `sg-0b8afb4e86ee42fbd` — `lab-alb-sg01` |
| ALB SG (HTTPS) | `sg-007ee4b4fb135c210` — `lab-alb-sg02` |
| Target Group ARN | `arn:aws:elasticloadbalancing:us-east-1:778185677715:targetgroup/lab-tg01/7abac687c89869b9` |
| CloudFront Prefix List | `pl-3b927c52` (45 CIDRs) |
| ACM Cert (ALB) | `51edf58e-ec34-43f2-a002-5578d4e9fcb4` |
| ACM Cert (CloudFront) | `1baef3ab-60e5-4001-b81e-84fe078bf763` |
| WAF (CloudFront scope) | `lab-cf-waf01` / `8771524c-9df4-4800-9b64-752174666971` |
| Route53 Record | `app.thedawgs2025.click` → `d2q9xg5p4u19ed.cloudfront.net` |

---

## 2. Terraform Architecture Decisions

### 2.1 Dual Security Group Design

The standard design uses a single ALB SG for both port 80 and 443 ingress. A quota limit forced a split-SG architecture during this lab.

> **Why:** AWS counts each CIDR in a managed prefix list as an individual rule against the SG quota. `pl-3b927c52` has 45 CIDRs. Two prefix-list rules (port 80 + port 443) would consume 90 rule slots, exceeding the default account limit of 60. A service quota increase to 150 has been requested but is pending AWS approval.

Resolution: split into two security groups:
- `lab-alb-sg01` — handles port 80 (HTTP), locked to CloudFront prefix list
- `lab-alb-sg02` — handles port 443 (HTTPS), currently `0.0.0.0/0` pending quota approval

Both SGs are attached to the ALB in the `security_groups` list.

### 2.2 CloudFront Origin Protocol: `http-only`

The CloudFront origin is configured with `origin_protocol_policy = "http-only"` rather than `"https-only"`. This is a deliberate decision, not a security gap.

> **Why:** CloudFront connects to the ALB using the ALB's own DNS name (`lab-alb01-776999256.us-east-1.elb.amazonaws.com`) as the SNI hostname during TLS negotiation. The ALB certificate covers `thedawgs2025.click` — not the ALB DNS name. This SNI mismatch causes `ClientTLSNegotiationErrorCount` errors and prevents CloudFront from reaching the origin entirely. Switching to `http-only` eliminates the SNI mismatch. The `X-Origin-Verify` header provides application-layer security; CloudFront-to-ALB traffic transits AWS backbone infrastructure.

### 2.3 HTTP Listener: Forward (not Redirect)

The ALB HTTP listener on port 80 forwards directly to the target group rather than redirecting to HTTPS.

> **Why:** CloudFront connects to the ALB on port 80 (`http-only`). If the HTTP listener redirects to HTTPS, the redirect `Location` header contains the ALB's own DNS name — not `app.thedawgs2025.click`. CloudFront receives this and reports a 301 error. Viewer-facing HTTPS enforcement is handled by CloudFront's `viewer_protocol_policy = "redirect-to-https"`, making the ALB-level redirect redundant.

### 2.4 EC2 Ingress from Both ALB SGs

Because the ALB uses two security groups, the EC2 security group must reference both:

```hcl
resource "aws_vpc_security_group_ingress_rule" "dawgs-armageddon_ec2_ingress_from_alb_sg01" {
  security_group_id            = aws_security_group.dawgs-armageddon_ec2_sg01.id
  referenced_security_group_id = aws_security_group.dawgs-armageddon_alb_sg01.id
  from_port   = 80
  ip_protocol = "tcp"
  to_port     = 80
}

resource "aws_vpc_security_group_ingress_rule" "dawgs-armageddon_ec2_ingress_from_alb_sg02" {
  security_group_id            = aws_security_group.dawgs-armageddon_ec2_sg01.id
  referenced_security_group_id = aws_security_group.dawgs-armageddon_alb_sg02.id
  from_port   = 80
  ip_protocol = "tcp"
  to_port     = 80
}
```

Without rules for both SGs, health checks from one SG would time out and the target would be marked unhealthy.

---

## 3. Session Incident Log & Resolutions

### Issue 1 — `RulesPerSecurityGroupLimitExceeded`

**Error:**
```
creating VPC Security Group Rule: RulesPerSecurityGroupLimitExceeded:
The maximum number of rules per security group has been reached.
```

**Diagnostic steps:**
- Checked Terraform state — HTTPS rule not present, HTTP rule was
- Ran `aws ec2 describe-security-groups` — confirmed only 1 rule in AWS
- Ran `aws ec2 get-managed-prefix-list-entries` — confirmed `pl-3b927c52` has 45 CIDRs
- Ran `aws service-quotas get-service-quota` — confirmed account limit is 60

**Root cause:** AWS counts each CIDR in a managed prefix list as an individual rule. `pl-3b927c52` contains 45 CIDRs. Two prefix-list rules (port 80 + port 443) would consume 90 slots, exceeding the 60-rule limit.

**Resolution:**
- Submitted service quota increase request to 150 (pending AWS approval)
- Immediate fix: split into two SGs — `sg01` for HTTP, `sg02` for HTTPS
- Both SGs attached to the ALB in `security_groups`

---

### Issue 2 — Target Health: `Target.Timeout`

**Error:**
```json
{
  "State": "unhealthy",
  "Reason": "Target.Timeout",
  "Description": "Request timed out"
}
```

**Diagnostic steps:**
- Verified target health via `aws elbv2 describe-target-health`
- Confirmed app running: `sudo systemctl status rdsapp` — active
- Confirmed app listening on port 80: `sudo ss -tlnp | grep python`
- Identified commented-out EC2 ingress rule in `bonus_b.tf`

**Root cause:** The EC2 security group had no inbound rule allowing traffic from the ALB SGs. The original `ec2_ingress_from_alb01` rule was commented out in the template. With the new dual-SG design, both SGs needed explicit inbound rules.

**Resolution:** Added two `aws_vpc_security_group_ingress_rule` resources referencing `alb_sg01` and `alb_sg02`. See Section 2.4.

---

### Issue 3 — 502 Bad Gateway: `ClientTLSNegotiationErrorCount`

**Error:**
```
curl -I https://app.thedawgs2025.click
HTTP/1.1 502 Bad Gateway
X-Cache: Error from cloudfront
```

**ALB `RequestCount` metric = 0 throughout.**

**Diagnostic steps:**
- Confirmed CloudFront distribution `Deployed`, Route53 correct, ACM certs `ISSUED`
- Confirmed ALB `internet-facing`, correct subnets, IGW routes present
- Confirmed NACLs wide open (rule 100 allow all, both directions)
- Ran `ClientTLSNegotiationErrorCount` CloudWatch metric — consistent errors present
- Confirmed `RequestCount = 0` — CloudFront never successfully reached ALB
- Tested directly: `curl -I https://ALB-DNS --insecure -H "X-Origin-Verify: ..."` returned `200 OK`

**Root cause:** CloudFront connects to the ALB origin using the ALB DNS name as the SNI hostname in the TLS ClientHello. The ALB certificate covers `thedawgs2025.click` and subdomains — not the ALB's own DNS name. AWS rejects the handshake, producing `ClientTLSNegotiationErrorCount`. CloudFront reports this as 502 to the viewer.

> **Note:** This issue is subtle because everything looks correct in isolation — cert is `ISSUED`, origin config is valid, SG rules are in place. The failure only becomes visible through `ClientTLSNegotiationErrorCount` rather than `RequestCount`.

**Resolution:** Changed `origin_protocol_policy` from `https-only` to `http-only`:

```hcl
custom_origin_config {
  http_port              = 80
  https_port             = 443
  origin_protocol_policy = "http-only"   # was https-only — SNI mismatch caused TLS failure
  origin_ssl_protocols   = ["TLSv1.2"]
}
```

---

### Issue 4 — 301 Redirect Loop After `http-only` Fix

**Error:**
```
HTTP/1.1 301 Moved Permanently
Location: https://lab-alb01-776999256.us-east-1.elb.amazonaws.com:443/
```

**Root cause:** With `origin_protocol_policy = "http-only"`, CloudFront now hits the ALB on port 80. The HTTP listener was configured to redirect all requests to HTTPS. The redirect `Location` header contained the ALB's own DNS name — not `app.thedawgs2025.click`. CloudFront received this redirect and reported it as an error.

**Resolution:** Changed the HTTP listener `default_action` from `redirect` to `forward`:

```hcl
resource "aws_lb_listener" "dawgs-armageddon_http_listener01" {
  load_balancer_arn = aws_lb.dawgs-armageddon_alb01.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.dawgs-armageddon_tg01.arn
  }
}
```

Viewer HTTPS enforcement is handled by CloudFront's `viewer_protocol_policy = "redirect-to-https"`.

---

## 4. Known States & Outstanding Items

| Item | Status | Notes |
|---|---|---|
| Service quota increase (VPC rules) | ⚠️ Pending | Requested 150. ID: `0d64311c...`. Current limit: 60 |
| ALB SG02 (HTTPS) ingress | ⚠️ Open | Currently `0.0.0.0/0`. Lock to `pl-3b927c52` once quota approved |
| CloudFront origin protocol | ✅ | `http-only` — intentional. SNI mismatch prevents `https-only` |
| Direct ALB access (HTTP) | ✅ | Blocked — missing `X-Origin-Verify` returns 403 |
| Direct ALB access (HTTPS) | ✅ | Blocked — SNI cert mismatch + 403 default listener action |
| CloudFront path | ✅ | Returns 200 OK end-to-end |
| WAF at CloudFront edge | ✅ | `lab-cf-waf01`, CLOUDFRONT scope, AWSManagedRulesCommonRuleSet active |
| DNS resolution | ✅ | `app.thedawgs2025.click` resolves to CloudFront IPs (`52.84.199.x`) |
| Target health | ✅ | Healthy — `rdsapp` Flask service active on port 80 |

---

## 5. Operational Runbook

### 5.1 Lab Verification Checklist

Run these three commands after any `terraform apply`:

**Test 1 — Direct ALB must be blocked**
```bash
curl -I https://lab-alb01-776999256.us-east-1.elb.amazonaws.com --insecure
```
Expected: `HTTP/1.1 403 Forbidden`

**Test 2 — CloudFront path must succeed**
```bash
curl -I https://app.thedawgs2025.click
```
Expected: `HTTP/1.1 200 OK` with `Via: CloudFront` header

**Test 3 — DNS must resolve to CloudFront**
```bash
nslookup app.thedawgs2025.click
```
Expected: Addresses in CloudFront ranges (e.g. `52.84.x.x`) — not ALB IPs

---

### 5.2 Diagnosing 502 from CloudFront

**Step 1 — Check target health**
```bash
aws elbv2 describe-target-health --target-group-arn \
  arn:aws:elasticloadbalancing:us-east-1:778185677715:targetgroup/lab-tg01/7abac687c89869b9
```
- `unhealthy + Target.Timeout` → EC2 SG missing inbound rule from ALB SG — go to Section 5.3
- `healthy` → proceed to Step 2

**Step 2 — Check ALB RequestCount**
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name RequestCount \
  --dimensions Name=LoadBalancer,Value=app/lab-alb01/a8cb6018f79bac6c \
  --start-time <ISO_START> --end-time <ISO_END> \
  --period 300 --statistics Sum
```
- `Sum = 0` → CloudFront never reached ALB — proceed to Step 3
- `Sum > 0` → ALB receiving requests but returning error — check listener rules

**Step 3 — Check ClientTLSNegotiationErrorCount**
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name ClientTLSNegotiationErrorCount \
  --dimensions Name=LoadBalancer,Value=app/lab-alb01/a8cb6018f79bac6c \
  --start-time <ISO_START> --end-time <ISO_END> \
  --period 300 --statistics Sum
```
- Errors present → TLS SNI mismatch — set `origin_protocol_policy = "http-only"` in CloudFront origin config

**Step 4 — Verify CloudFront origin header is configured**
```bash
aws cloudfront get-distribution --id E299RJP0LW0OTP \
  --query "Distribution.DistributionConfig.Origins.Items[*].CustomHeaders"
```
Must show `X-Origin-Verify` with correct secret value.

**Step 5 — Simulate CloudFront request directly to ALB**
```bash
curl -I http://lab-alb01-776999256.us-east-1.elb.amazonaws.com \
  -H "X-Origin-Verify: dawgs-armageddon-cf-secret-2025"
```
- `200 OK` → ALB and app are healthy, issue is upstream (CloudFront config)
- `403` → Listener rule not matching header — verify rule exists on HTTPS listener
- Timeout / connection refused → SG blocking — check ALB SG ingress rules

---

### 5.3 Diagnosing Target.Timeout

**Step 1 — Verify app is running on EC2**
```bash
sudo systemctl status rdsapp
sudo ss -tlnp | grep python
```

**Step 2 — Test app responds locally**
```bash
curl -I http://localhost
```
Expected: `200 OK`

**Step 3 — Verify EC2 SG has inbound rules from both ALB SGs**
```bash
aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=*ec2*" \
  --query "SecurityGroups[0].IpPermissions"
```
Must show `UserIdGroupPairs` entries for both `sg-0b8afb4e86ee42fbd` and `sg-007ee4b4fb135c210`.

---

### 5.4 Checking SG Rule Quota

```bash
aws service-quotas get-service-quota \
  --service-code vpc \
  --quota-code L-0EA8095F \
  --query "Quota.Value"
```

Check pending increase requests:
```bash
aws service-quotas list-requested-service-quota-changes-by-service \
  --service-code vpc
```

---

### 5.5 ALB Listener Rules Verification

```bash
aws elbv2 describe-rules \
  --listener-arn arn:aws:elasticloadbalancing:us-east-1:778185677715:listener/app/lab-alb01/a8cb6018f79bac6c/9a115d2ec6124dc6 \
  --query "Rules[*].{Priority:Priority,Conditions:Conditions,Actions:Actions[0].Type}"
```

Expected:
- Priority `1`: Condition = `X-Origin-Verify` header match, Action = `forward`
- Priority `default`: No condition, Action = `fixed-response` (403)

---

### 5.6 WAF Verification

```bash
aws wafv2 get-web-acl \
  --name lab-cf-waf01 \
  --scope CLOUDFRONT \
  --id 8771524c-9df4-4800-9b64-752174666971 \
  --region us-east-1 \
  --query "WebACL.Rules[*].{Name:Name,Priority:Priority}"

aws cloudfront get-distribution --id E299RJP0LW0OTP \
  --query "Distribution.DistributionConfig.WebACLId"
```

Expected: WAF ARN present on the distribution.

---

## 6. Issue Reference Table

| Issue | Root Cause | Resolution |
|---|---|---|
| `RulesPerSecurityGroupLimitExceeded` on HTTPS rule | `pl-3b927c52` has 45 CIDRs. Two prefix-list rules = 90 slots. Default limit = 60. | Split into two SGs (`sg01` for HTTP, `sg02` for HTTPS). Attach both to ALB. Quota increase requested. |
| `Target.Timeout` — EC2 never responds to ALB | EC2 SG had no inbound rule from ALB SGs. Original template had rule commented out. | Added two `aws_vpc_security_group_ingress_rule` resources referencing both ALB SGs. |
| 502 Bad Gateway — `RequestCount = 0` | `ClientTLSNegotiationErrorCount` errors. SNI mismatch: CloudFront sends ALB DNS as SNI but cert covers `thedawgs2025.click`. | Changed `origin_protocol_policy` to `http-only`. Eliminates TLS handshake on origin leg. |
| 301 Redirect to ALB DNS name | HTTP listener redirected to HTTPS using ALB hostname in `Location` header. CloudFront received redirect loop. | Changed HTTP listener `default_action` to `forward`. Viewer HTTPS enforcement handled by CloudFront. |
| `TargetGroupNotFound` in nested CLI command | Git Bash breaks multiline commands — inner command produced no output. | Split into separate single-line commands. Copy ARN manually between steps. |
| `aws.exe: argument expected` on multiline paste | Git Bash interprets line breaks in copy-pasted CLI commands as separate statements. | Always run AWS CLI commands as a single unbroken line in Git Bash. |

---

## 7. Terraform File Reference

| File | Purpose |
|---|---|
| `bonus_b.tf` | ALB, SGs (`sg01` + `sg02`), EC2 ingress rules, target group, listeners, ACM cert, WAF (regional), CloudWatch |
| `cloudfront-lab-2a-distribution.tf` | CloudFront distribution, CloudFront ACM cert, ALB listener rule (priority 1), Route53 alias, CloudFront WAF (global) |
| `cloudfront-lab-2a-outputs.tf` | CloudFront distribution outputs |
| `cloudfront-variables.tf` | Variables: `cloudfront_subdomain`, `enable_cloudfront`, origin header name/secret, WAF toggles, geo restriction |

### 7.1 Critical Configuration Values

| Variable / Setting | Value | Reason |
|---|---|---|
| `origin_protocol_policy` | `http-only` | SNI mismatch with `https-only` causes TLS failure |
| `cloudfront_origin_header_name` | `X-Origin-Verify` | Secret header name checked by ALB listener rule |
| `cloudfront_origin_secret` | `dawgs-armageddon-cf-secret-2025` | Shared secret between CloudFront and ALB |
| ALB HTTP listener action | `forward` (not `redirect`) | Redirect causes loop when CloudFront hits port 80 |
| CloudFront prefix list | `pl-3b927c52` | AWS-managed CloudFront origin-facing IPs, us-east-1 (45 CIDRs) |
| ALB SSL policy | `ELBSecurityPolicy-TLS13-1-2-2021-06` | Enforces TLS 1.2+ on viewer-facing HTTPS |

---

*Armageddon Lab 2A — Documentation complete. February 24, 2026.*
