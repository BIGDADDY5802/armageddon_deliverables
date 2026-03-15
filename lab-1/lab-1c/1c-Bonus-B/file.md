# Lab 1C — Bonus B
## Enterprise ALB Pattern: TLS + WAF + Monitoring
### Domain: thedawgs2025.click

---

## Overview

This lab extends the Lab 1C + Bonus-A stack into a production-grade ingress pattern. The goal is to ship a fully managed, secure, observable entry point for a private EC2 application — using only infrastructure as code.

**What you are building:**

- Internet-facing Application Load Balancer
- Private EC2 targets (no public IP)
- TLS termination via ACM for `app.thedawgs2025.click`
- WAF attached to the ALB
- CloudWatch Dashboard for visibility
- SNS alarm on ALB 5xx error spikes

If you can deliver this in Terraform, you are no longer a student who clicked around. You are operating as a junior cloud engineer.

---

## Prerequisites

The following resources must already exist from Lab 1C and Bonus-A:

| Resource | Name |
|---|---|
| VPC | `aws_vpc.chewbacca_vpc01` |
| Public Subnets | `aws_subnet.chewbacca_public_subnets` |
| Private Subnets | `aws_subnet.chewbacca_private_subnets` |
| EC2 Security Group | `aws_security_group.chewbacca_ec2_sg01` |
| Private EC2 Instance | `aws_instance.chewbacca_ec201_private_bonus` |
| SNS Topic | `aws_sns_topic.chewbacca_sns_topic01` |

---

## Files to Add

```
bonus_b.tf
1c_bonus_variables.tf    ← append to existing variables.tf
Bonus-B_outputs.tf
```

---

## What You Must Implement

### TLS — ACM Certificate for `app.chewbacca-growl.com`

You must validate the certificate using one of two methods:

**Option 1 — DNS Validation (recommended)**

Create the following in Terraform:
- Route53 Hosted Zone for `thedawgs2025.click`
- `aws_route53_record` for ACM DNS validation
- CNAME or ALIAS record pointing `app.thedawgs2025.click` → ALB DNS name

**Option 2 — Email Validation (acceptable)**

Complete validation manually via the ACM console email, then allow Terraform to continue. Less repeatable — not preferred for pipelines.

---

### ALB Security Group Rules

Your ALB security group must include:

| Direction | Protocol | Port | Source |
|---|---|---|---|
| Inbound | TCP | 80 | `0.0.0.0/0` |
| Inbound | TCP | 443 | `0.0.0.0/0` |
| Outbound | TCP | App port | Target EC2 security group |

---

### EC2 Application

Your EC2 user data must start an application that:
- Listens on port 80 (or update the target group and security group to match)
- Responds to `GET /health` with HTTP `200`

The ALB health check targets `/health` and expects response codes `200–399`. A `404` on `/health` will mark the target as unhealthy and block all traffic.

---

## Verification Commands

### 1. ALB is active

```bash
aws elbv2 describe-load-balancers \
  --names lab-alb01 \
  --query "LoadBalancers[0].State.Code" \
  --output text
```

Expected output:
```
active
```

---

### 2. Listeners exist on port 80 and 443

```bash
aws elbv2 describe-listeners \
  --load-balancer-arn <ALB_ARN> \
  --query "Listeners[].{Port:Port,Protocol:Protocol}" \
  --output table
```

Expected output:
```
-----------------
| Port | Protocol |
| 80   | HTTP     |
| 443  | HTTPS    |
-----------------
```

Port 80 should redirect to HTTPS (`HTTP_301`). Port 443 should forward to the target group with your ACM certificate attached.

---

### 3. Target is healthy

```bash
aws elbv2 describe-target-health \
  --target-group-arn <TARGET_GROUP_ARN> \
  --query "TargetHealthDescriptions[*].{ID:Target.Id,State:TargetHealth.State,Reason:TargetHealth.Reason}" \
  --output table
```

Expected output:
```
State: healthy
```

If you see `Target.ResponseCodeMismatch` with code `404` — your application is missing the `/health` route. Add it before proceeding.

---

### 4. WAF is attached to the ALB

```bash
aws wafv2 get-web-acl-for-resource \
  --resource-arn <ALB_ARN> \
  --region us-east-1 \
  --query "WebACL.Name" \
  --output text
```

Expected output: your WAF ACL name.

---

### 5. CloudWatch alarm exists for ALB 5xx errors

```bash
aws cloudwatch describe-alarms \
  --alarm-name-prefix chewbacca-alb-5xx \
  --query "MetricAlarms[*].{Name:AlarmName,State:StateValue}" \
  --output table
```

Expected output: alarm present with state `OK` or `INSUFFICIENT_DATA`.

---

### 6. CloudWatch dashboard exists

```bash
aws cloudwatch list-dashboards \
  --dashboard-name-prefix chewbacca \
  --query "DashboardEntries[*].DashboardName" \
  --output text
```

Expected output: your dashboard name.

---

## Current State — Verified

The following has been confirmed against account `778185677715`:

**ALB**
- Name: `lab-alb01`
- ARN: `arn:aws:elasticloadbalancing:us-east-1:778185677715:loadbalancer/app/lab-alb01/3d9b38a83dbab0f6`
- Status: Active

**Listeners**
- Port 80 → HTTP 301 redirect to HTTPS ✓
- Port 443 → HTTPS forward to target group ✓
- Certificate: `arn:aws:acm:us-east-1:778185677715:certificate/242aad40-1328-4049-a0c8-0efa24fade61` ✓
- TLS policy: `ELBSecurityPolicy-TLS13-1-2-2021-06` ✓

**Target Health**
- Instance: `i-0be5027784aea2f9c`
- State: `unhealthy`
- Reason: `Target.ResponseCodeMismatch — health checks failed with code 404`
- Fix required: add `/health` route to application returning `200`

---

## Known Issue — Health Check 404

The target group health check is configured to hit `/health` on port 80. The EC2 instance is returning `404` because the running application does not have a `/health` route defined.

**Fix:** Add the following route to your application and redeploy:

```python
# Flask example
@app.route("/health")
def health():
    return {"status": "ok"}, 200
```

```javascript
// Express example
app.get('/health', (req, res) => res.json({ status: 'ok' }));
```

Once the health check passes, the target state will change from `unhealthy` to `healthy` and traffic will flow through the ALB.

---

## DNS Setup (Route53)

If managing DNS in Route53, add the following to your Terraform:

```hcl
resource "aws_route53_zone" "chewbacca" {
  name = "chewbacca-growl.com"
}

resource "aws_route53_record" "app" {
  zone_id = aws_route53_zone.chewbacca.zone_id
  name    = "app.chewbacca-growl.com"
  type    = "A"

  alias {
    name                   = aws_lb.chewbacca_alb01.dns_name
    zone_id                = aws_lb.chewbacca_alb01.zone_id
    evaluate_target_health = true
  }
}
```

If your DNS is managed outside Route53, create the CNAME manually at your registrar pointing `app.chewbacca-growl.com` to the ALB DNS name.

---

## What This Lab Proves

| Capability | Implementation |
|---|---|
| Managed ingress | Internet-facing ALB with HTTP → HTTPS redirect |
| TLS termination | ACM certificate on port 443 listener |
| Private compute | EC2 in private subnet, no public IP |
| Edge protection | WAF attached to ALB |
| Observability | CloudWatch Dashboard + SNS alarm on 5xx |
| Infrastructure as code | Everything deployed via Terraform |

This is the pattern used by real engineering teams to ship applications securely. Completing this lab means you understand how traffic enters a system, how it is secured at the edge, and how failures are surfaced to on-call teams.
