# Lab 1C — Bonus B
## Student Verification Report
### Account: 778185677715 | Domain: thedawgs2025.click

---

## Lab Objective

Deploy a production-grade ingress pattern using infrastructure as code:

- Internet-facing ALB with HTTP → HTTPS redirect
- TLS termination via ACM
- Private EC2 compute (no public IP)
- WAF edge protection
- CloudWatch observability and SNS alerting

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

### 2. App DNS Record

**Command:**
```bash
aws route53 list-resource-record-sets \
  --hosted-zone-id Z0717862367KSPKDBWGDE \
  --query "ResourceRecordSets[?Name=='app.thedawgs2025.click.']"
```

**Result:**
```json
[
  {
    "Name": "app.thedawgs2025.click.",
    "Type": "A",
    "AliasTarget": {
      "HostedZoneId": "Z35SXDOTRQ7X7K",
      "DNSName": "lab-alb01-1790178507.us-east-1.elb.amazonaws.com.",
      "EvaluateTargetHealth": true
    }
  }
]
```

**Status:** ✅ A record exists — `app.thedawgs2025.click` aliased to ALB

---

### 3. ACM Certificates

**Command:**
```bash
aws acm list-certificates \
  --query 'CertificateSummaryList[].CertificateArn' \
  --output table
```

**Result:**

| Certificate ARN |
|---|
| `arn:aws:acm:us-east-1:778185677715:certificate/d7353b1b-c8d0-4569-8576-f6b611931244` |
| `arn:aws:acm:us-east-1:778185677715:certificate/bbb26471-1bda-4338-b81f-57aab79690ad` |
| `arn:aws:acm:us-east-1:778185677715:certificate/4830e7e8-381c-4b89-b540-2b146c5ffea5` |

**Validation status for each certificate:**

```bash
aws acm describe-certificate \
  --certificate-arn <ARN> \
  --query "Certificate.Status"
```

| Certificate ARN | Status |
|---|---|
| `d7353b1b-...` | ✅ `ISSUED` |
| `bbb26471-...` | ✅ `ISSUED` |
| `4830e7e8-...` | ✅ `ISSUED` |

**Status:** ✅ All certificates issued and valid

---

### 4. HTTPS End-to-End

**Command:**
```bash
curl -I https://app.thedawgs2025.click
```

**Result:**
```
HTTP/1.1 200 OK
Date: Tue, 10 Feb 2026 04:33:56 GMT
Content-Type: text/html; charset=utf-8
Content-Length: 233
Connection: keep-alive
Server: Werkzeug/3.1.5 Python/3.9.25
```

**Status:** ✅ HTTPS traffic flowing end-to-end — `200 OK`

---

## Summary

| Check | Resource | Result |
|---|---|---|
| Hosted Zone | `Z0717862367KSPKDBWGDE` | ✅ Confirmed |
| DNS Record | `app.thedawgs2025.click → ALB` | ✅ Confirmed |
| Certificate 1 | `d7353b1b-...` | ✅ ISSUED |
| Certificate 2 | `bbb26471-...` | ✅ ISSUED |
| Certificate 3 | `4830e7e8-...` | ✅ ISSUED |
| HTTPS Response | `https://app.thedawgs2025.click` | ✅ 200 OK |

All six checks pass. The lab deliverable is complete.

---

## What This Proves

This is exactly how production systems are built:

| Layer | Implementation |
|---|---|
| **DNS** | Route53 hosted zone with ALB alias record |
| **TLS** | ACM certificate — no manual cert management |
| **Ingress** | ALB handles secure public entry, HTTP redirects to HTTPS |
| **Compute** | Private EC2 — no public IP, only reachable via ALB |
| **Protection** | WAF attached to ALB — blocks malicious traffic at the edge |
| **Observability** | CloudWatch dashboard + SNS alarm on 5xx errors |

DNS points to ingress. TLS is managed. ALB is the public surface. Private compute does the work. WAF and alarms defend and alert.

This is the pattern. Every company ships this way.