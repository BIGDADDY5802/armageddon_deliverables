# SEIR Lab 2B — Deliverables Summary

**Domain:** `thedawgs2025.click`
**CloudFront Distribution:** `E23IU5LEZN6JWC` (`d2bxtlbua9poar.cloudfront.net`)
**Final Badge:** 🟡 **YELLOW (PASS)**

---

## ✅ Completed Deliverables

### 1. Origin Security Group — Remove Open 0.0.0.0/0 on Port 443
**SG:** `sg-0a4a1f67bd5ca8eee` (`lab-alb-sg01`)

Port 443 was wide open to the entire internet. The offending rule was revoked via CLI:

```bash
aws ec2 revoke-security-group-ingress \
  --group-id sg-0a4a1f67bd5ca8eee \
  --protocol tcp \
  --port 443 \
  --cidr 0.0.0.0/0
```

Port 80 and 443 now only allow traffic from the **CloudFront managed prefix list** (`pl-3b927c52`).

> **Root cause:** Two separate security groups (`lab-alb-sg01` / `lab-alb-sg02`) were needed due to the 60-rule-per-SG limit. The gate script was initially pointed at the wrong SG ID, causing false failures on the port 80/443 visibility warnings.

---

### 2. WAF WebACL — Associate with CloudFront Distribution

**WAF ARN:** `arn:aws:wafv2:us-east-1:778185677715:global/webacl/lab-cf-waf01/6f7ea389-33c8-4f7c-a1b1-b86ef88b1ab6`

The WAF was defined in Terraform (`cloufront-lab-2a-waf.tf`) and referenced in the distribution config via `web_acl_id`, but was not reflected live. Config was confirmed via state:

```bash
terraform state show 'aws_cloudfront_distribution.dawgs-armageddon_cf01[0]' | grep web_acl
# web_acl_id = "arn:aws:wafv2:us-east-1:778185677715:global/webacl/lab-cf-waf01/..."
```

Gate confirmed association after apply.

---

### 3. CloudFront Logging — Verified & Corrected Bucket

**Actual log bucket:** `lab-cf-logs-778185677715.s3.amazonaws.com`

Initial gate runs used `lab-alb-logs-778185677715` as the expected bucket — a mismatch. After correcting the `LOG_BUCKET` parameter to `lab-cf-logs-778185677715`, the logging warning resolved to a match.

---

### 4. Route53 Alias Records — A + AAAA Pointing to CloudFront

Both alias records confirmed pointing to `d2bxtlbua9poar.cloudfront.net` with the correct CloudFront hosted zone ID (`Z2FDTNDATAQYW2`):

```json
{ "Type": "A",    "AliasTarget": { "DNSName": "d2bxtlbua9poar.cloudfront.net." } }
{ "Type": "AAAA", "AliasTarget": { "DNSName": "d2bxtlbua9poar.cloudfront.net." } }
```

> The gate script had a trailing-dot comparison bug — both `expected` and `actual` showed the same value but still failed. This was a **gate script issue**, not an infrastructure issue. Records were already correct.

---

## ⚠️ Remaining Warnings (Non-Blocking)

| Warning | Status |
|---|---|
| Port 80/443 prefix-list sources not visible to gate | Expected — uses prefix list `pl-3b927c52`, not CIDR; gate can't enumerate prefix list members |
| Log bucket name mismatch | Resolved after correcting `LOG_BUCKET` param in gate invocation |

---

## Gate Invocation (Final Passing Run)

```bash
ORIGIN_REGION=us-east-1 \
CF_DISTRIBUTION_ID=E23IU5LEZN6JWC \
DOMAIN_NAME=thedawgs2025.click \
ROUTE53_ZONE_ID=Z0717862367KSPKDBWGDE \
ACM_CERT_ARN=arn:aws:acm:us-east-1:778185677715:certificate/2f0cbfa1-c185-4e79-bfb5-beeebb2e1cf4 \
WAF_WEB_ACL_ARN=arn:aws:wafv2:us-east-1:778185677715:global/webacl/lab-cf-waf01/6f7ea389-33c8-4f7c-a1b1-b86ef88b1ab6 \
LOG_BUCKET=lab-cf-logs-778185677715 \
ORIGIN_SG_ID=sg-0a4a1f67bd5ca8eee \
./run_all_gates_alb.sh
```

**Result:** `BADGE: YELLOW (PASS)` — No failures.