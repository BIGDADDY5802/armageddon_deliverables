# Lab 1C — Bonus D
## Submission Report: Enterprise ALB Pattern
### Account: `778185677715` | Domain: `thedawgs2025.click` | Region: `us-east-1`
### Date: February 10, 2026

---

## Infrastructure Summary

| Resource | Value |
|---|---|
| VPC | `vpc-08fb966c40ac6e647` |
| EC2 Instance (Public) | `i-0a88b975ec3f1ce17` |
| EC2 Instance (Private) | `i-0e32069f6d357132f` |
| RDS Endpoint | `lab-rds01.c89ykq22i31z.us-east-1.rds.amazonaws.com` |
| ALB DNS | `lab-alb01-1790178507.us-east-1.elb.amazonaws.com` |
| ALB ARN | `arn:aws:elasticloadbalancing:us-east-1:778185677715:loadbalancer/app/lab-alb01/4cebea6c14f86f38` |
| Target Group ARN | `arn:aws:elasticloadbalancing:us-east-1:778185677715:targetgroup/lab-tg01/9ee0f96c7c0b3a9b` |
| WAF ARN | `arn:aws:wafv2:us-east-1:778185677715:regional/webacl/lab-waf01/555be549-3ccf-45b8-9835-d9f977b9a0a3` |
| SNS Topic | `arn:aws:sns:us-east-1:778185677715:lab-db-incidents` |
| CloudWatch Dashboard | `lab-dashboard01` |
| ALB Access Log Bucket | `lab-alb-logs-778185677715` |

---

## Verification Results

### 1. Hosted Zone

**Command:**
```bash
aws route53 list-hosted-zones-by-name \
  --dns-name thedawgs2025.click \
  --query "HostedZones[].Id"
```

**Result:**
```json
["/hostedzone/Z0717862367KSPKDBWGDE"]
```

**Status:** ✅ Hosted zone confirmed — `Z0717862367KSPKDBWGDE`

---

### 2. DNS Records

**Command:**
```bash
aws route53 list-resource-record-sets \
  --hosted-zone-id Z0717862367KSPKDBWGDE \
  --query "ResourceRecordSets[?Name=='thedawgs2025.click.']"
```

**Result:**

| Name | Type | Target |
|---|---|---|
| `thedawgs2025.click.` | A (Alias) | `lab-alb01-1790178507.us-east-1.elb.amazonaws.com` |
| `thedawgs2025.click.` | NS | AWS nameservers |
| `thedawgs2025.click.` | SOA | AWS SOA record |

Both `thedawgs2025.click` and `app.thedawgs2025.click` resolve to the ALB with `EvaluateTargetHealth: true`.

**Status:** ✅ Apex and app DNS records confirmed

---

### 3. ALB State

**Command:**
```bash
aws elbv2 describe-load-balancers \
  --load-balancer-arns arn:aws:elasticloadbalancing:us-east-1:778185677715:loadbalancer/app/lab-alb01/4cebea6c14f86f38 \
  --query "LoadBalancers[].State" \
  --output table
```

**Result:**
```
-----------------------
| Code                |
-----------------------
| active              |
-----------------------
```

**Status:** ✅ ALB is active

---

### 4. ALB Access Logging

**Command:**
```bash
aws elbv2 describe-load-balancer-attributes \
  --load-balancer-arn arn:aws:elasticloadbalancing:us-east-1:778185677715:loadbalancer/app/lab-alb01/4cebea6c14f86f38 \
  --query "Attributes[?Key=='access_logs.s3.enabled'].{Enabled:Value}" \
  --output table
```

**Result:**
```
--------------------------------
| Enabled                      |
--------------------------------
| true                         |
--------------------------------
```

| Attribute | Value |
|---|---|
| `access_logs.s3.enabled` | `true` |
| `access_logs.s3.bucket` | `lab-alb-logs-778185677715` |
| `access_logs.s3.prefix` | `alb-access-logs` |

**Status:** ✅ Access logging enabled — writing to `s3://lab-alb-logs-778185677715/alb-access-logs/`

---

### 5. ACM Certificates

**Command:**
```bash
aws acm list-certificates \
  --query 'CertificateSummaryList[].CertificateArn' \
  --output table
```

**Validation:**
```bash
aws acm describe-certificate \
  --certificate-arn <ARN> \
  --query "Certificate.Status"
```

| Certificate ARN | Status |
|---|---|
| `d7353b1b-c8d0-4569-8576-f6b611931244` | ✅ `ISSUED` |
| `bbb26471-1bda-4338-b81f-57aab79690ad` | ✅ `ISSUED` |
| `4830e7e8-381c-4b89-b540-2b146c5ffea5` | ✅ `ISSUED` |

**Status:** ✅ All certificates issued and valid

---

### 6. HTTPS End-to-End

**Commands:**
```bash
curl -I https://thedawgs2025.click
curl -I https://app.thedawgs2025.click
```

**Results:**

| URL | Status | Server |
|---|---|---|
| `https://thedawgs2025.click` | ✅ `200 OK` | Werkzeug/3.1.5 Python/3.9.25 |
| `https://app.thedawgs2025.click` | ✅ `200 OK` | Werkzeug/3.1.5 Python/3.9.25 |

**Status:** ✅ HTTPS traffic flowing end-to-end on both endpoints

---

### 7. Access Logs Writing to S3

**Command:**
```bash
aws s3 ls s3://lab-alb-logs-778185677715/alb-access-logs/AWSLogs/778185677715/elasticloadbalancing/ \
  --recursive | head
```

**Result:** Log files confirmed writing at 5-minute intervals:

```
2026-02-10 ...app.lab-alb01.4cebea6c14f86f38_20260210T0325Z_...log.gz
2026-02-10 ...app.lab-alb01.4cebea6c14f86f38_20260210T0330Z_...log.gz
2026-02-10 ...app.lab-alb01.4cebea6c14f86f38_20260210T0335Z_...log.gz
2026-02-10 ...app.lab-alb01.4cebea6c14f86f38_20260210T0340Z_...log.gz
2026-02-10 ...app.lab-alb01.4cebea6c14f86f38_20260210T0345Z_...log.gz
```

**Status:** ✅ Access logs actively writing — client IPs, paths, response codes, and latency captured

---

## Verification Summary

| Check | Resource | Result |
|---|---|---|
| Hosted Zone | `Z0717862367KSPKDBWGDE` | ✅ Pass |
| Apex DNS Record | `thedawgs2025.click → ALB` | ✅ Pass |
| App DNS Record | `app.thedawgs2025.click → ALB` | ✅ Pass |
| ALB State | `lab-alb01` | ✅ Active |
| Access Logging | `lab-alb-logs-778185677715` | ✅ Enabled |
| Certificate 1 | `d7353b1b-...` | ✅ Issued |
| Certificate 2 | `bbb26471-...` | ✅ Issued |
| Certificate 3 | `4830e7e8-...` | ✅ Issued |
| HTTPS — Apex | `https://thedawgs2025.click` | ✅ 200 OK |
| HTTPS — App | `https://app.thedawgs2025.click` | ✅ 200 OK |
| S3 Log Files | `alb-access-logs/` | ✅ Writing |

All eleven checks pass. Lab deliverable is complete.

---

## Why Access Logs Matter

ALB access logs are incident response fuel. Every log file contains:

| Field | Value |
|---|---|
| Client IP | Who made the request |
| Request path | What they asked for |
| Response code | What the server returned |
| Target behavior | Which backend handled it |
| Latency | How long it took |

Combined with WAF logs and CloudWatch 5xx alarms, access logs allow real triage:

> "Is this an attacker, a misroute, or a downstream failure?"

This is how on-call engineers diagnose production incidents. The infrastructure you built here — DNS, TLS, ALB, WAF, access logs, alarms — is the exact stack that gets paged at 2am and needs to be understood cold.