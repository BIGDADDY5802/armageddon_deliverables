# Lab 3B — Apply Walkthrough
## APPI-Compliant Multi-Region Infrastructure (Tokyo + São Paulo)

---

## Prerequisites

- AWS CLI configured with account `778185677715`
- Terraform installed
- Git Bash (Windows) — always prefix commands with `MSYS_NO_PATHCONV=1` when passing boolean vars
- Both Terraform stacks present:
  - `Shinjuku/` — Tokyo (ap-northeast-1)
  - `Liberdade/` — São Paulo (sa-east-1)

---

## Stack Overview

| Stack | Region | Role |
|---|---|---|
| Shinjuku | ap-northeast-1 | Data authority — RDS, Secrets Manager, CloudFront, WAF, CloudTrail |
| Liberdade | sa-east-1 | Stateless compute — EC2, ALB, TGW spoke |

---

## Key Variables

| Variable | Stack | Purpose | Default |
|---|---|---|---|
| `saopaulo_tgw_ready` | Shinjuku | Gates TGW peering attachment and SSM reads | `false` |
| `tokyo_peering_attachment_ready` | Liberdade | Gates peering accepter, secret reads, SSM writes | `false` |
| `tokyo_peering_accepted` | Shinjuku | Gates TGW return route to São Paulo | `false` |

---

## Apply — Four Stages

### Stage 1 — São Paulo Base Infrastructure

```bash
cd Liberdade
terraform apply
```

**What gets created:** VPC, subnets, IGW, NAT, TGW, VPC attachment, EC2, ALB, security groups, SSM parameter `/lab/liberdade/tgw/id`

**Verify:**
```bash
aws ssm get-parameter \
  --name "/lab/liberdade/tgw/id" \
  --region sa-east-1 \
  --query "Parameter.Value" \
  --output text
```

---

### Stage 2 — Tokyo Full Stack

```bash
cd ../Shinjuku
MSYS_NO_PATHCONV=1 terraform apply -var 'saopaulo_tgw_ready=true'
```

**What gets created:** VPC, subnets, RDS, EC2, ALB, TGW, TGW peering attachment (initiates handshake to SP), Secrets Manager secret, CloudFront distribution, WAF, CloudTrail, ACM cert, SSM parameters

**Wait for app to be ready:**
```bash
while true; do
  CODE=$(curl -s -o /dev/null -w "%{http_code}" https://thedawgs2025.click/health)
  echo "$(date +%H:%M:%S) - $CODE"
  if [ "$CODE" = "200" ]; then echo "App is up"; break; fi
  sleep 15
done
```

**Verify CloudFront is serving:**
```bash
curl -I https://thedawgs2025.click/api/public-feed
```
Expected: `HTTP/1.1 200 OK`

---

### Stage 3 — São Paulo Accepts Peering

```bash
cd ../Liberdade
MSYS_NO_PATHCONV=1 terraform apply -var 'tokyo_peering_attachment_ready=true'
```

**What gets created:** TGW peering accepter, TGW route to Tokyo (`10.52.0.0/16`), ALB listener rule with `X-Chewbacca-Growl` header check, SSM parameters for Tokyo RDS endpoint and port

---

### Wait — TGW Peering Propagation

AWS takes 1-2 minutes to propagate peering acceptance from São Paulo back to Tokyo. Poll until `available`:

```bash
CURRENT_TGW=$(aws ec2 describe-transit-gateways \
  --region ap-northeast-1 \
  --query "TransitGateways[?State=='available'].TransitGatewayId" \
  --output text)

ATTACHMENT_ID=$(aws ec2 describe-transit-gateway-attachments \
  --region ap-northeast-1 \
  --filters Name=resource-type,Values=peering Name=transit-gateway-id,Values=$CURRENT_TGW \
  --query "TransitGatewayAttachments[0].TransitGatewayAttachmentId" \
  --output text)

while true; do
  STATE=$(aws ec2 describe-transit-gateway-attachments \
    --region ap-northeast-1 \
    --filters Name=transit-gateway-attachment-id,Values=$ATTACHMENT_ID \
    --query "TransitGatewayAttachments[0].State" \
    --output text)
  echo "Current state: $STATE"
  if [ "$STATE" = "available" ]; then echo "Ready for Stage 4"; break; fi
  sleep 15
done
```

---

### Stage 4 — Tokyo TGW Return Route

```bash
cd ../Shinjuku
MSYS_NO_PATHCONV=1 terraform apply \
  -var 'saopaulo_tgw_ready=true' \
  -var 'tokyo_peering_accepted=true'
```

**What gets created:** TGW static route `10.190.0.0/16 → peering attachment` in Tokyo route table

---

## Post-Apply Verification

### 1. CloudFront serving traffic
```bash
curl -I https://thedawgs2025.click/api/public-feed
```
Expected: `200 OK`, `X-Cache: Hit from cloudfront` on repeat requests

### 2. TGW corridor open — both sides
```bash
# Tokyo side
aws ec2 describe-transit-gateway-attachments \
  --region ap-northeast-1 \
  --filters Name=transit-gateway-id,Values=<tokyo-tgw-id> \
  --query "TransitGatewayAttachments[*].{Name:Tags[?Key=='Name']|[0].Value,State:State}" \
  --output table

# São Paulo side
aws ec2 describe-transit-gateway-attachments \
  --region sa-east-1 \
  --filters Name=transit-gateway-id,Values=<sp-tgw-id> \
  --query "TransitGatewayAttachments[*].{Name:Tags[?Key=='Name']|[0].Value,State:State}" \
  --output table
```
Expected: all attachments `available`

### 3. São Paulo EC2 → Tokyo RDS connectivity
```bash
# Get current SP instance ID
aws ec2 describe-instances \
  --region sa-east-1 \
  --filters Name=tag:Name,Values="liberdade-ec201" \
  --query "Reservations[*].Instances[*].InstanceId" \
  --output text

# SSM into SP instance
aws ssm start-session --target <instance-id> --region sa-east-1

# Inside the session
nc -zv shinjuku-rds01.c76yg4640twf.ap-northeast-1.rds.amazonaws.com 3306
```
Expected: `Ncat: Connected to 10.52.x.x:3306`

### 4. Origin cloaking — secret header match
```bash
# CloudFront is sending correct secret
aws cloudfront get-distribution \
  --id <cf-distribution-id> \
  --query "Distribution.DistributionConfig.Origins.Items[*].CustomHeaders" \
  --output json

# ALB is enforcing correct secret
aws elbv2 describe-rules \
  --region sa-east-1 \
  --listener-arn <listener-arn> \
  --query "Rules[*].{Priority:Priority,Conditions:Conditions}" \
  --output json
```
Both `HeaderValue` fields must match.

---

## Destroy Order

Always destroy Tokyo first — it holds SSM parameters that São Paulo reads.

```bash
# Tokyo first
cd Shinjuku
MSYS_NO_PATHCONV=1 terraform destroy \
  -var 'saopaulo_tgw_ready=true' \
  -var 'tokyo_peering_accepted=true'

# São Paulo second — no flags needed, Tokyo SSM params already gone
cd ../Liberdade
terraform destroy
```

> **Note:** If Tokyo is already destroyed when you run São Paulo destroy, omit all `-var` flags. The data sources are gated and will skip gracefully.

---

## Common Errors and Fixes

| Error | Cause | Fix |
|---|---|---|
| `couldn't find resource` on SSM data source | Applying wrong stage order or Tokyo not yet applied | Apply stages in order 1→2→3→4 |
| `InvalidTransitGatewayAttachmentID.NotFound` | Accepter running before initiator exists | Run Stage 2 before Stage 3 |
| `A condition must be specified` on ALB listener rule | Empty `condition {}` block | Add `http_header` block with secret value |
| `is a bool is required` on `-var` flag | Git Bash path conversion mangling booleans | Prefix with `MSYS_NO_PATHCONV=1` |
| `IncorrectState` on TGW route | Route created before peering is `available` | Wait for peering propagation between Stage 3 and Stage 4 |
| `Parameter name must be a fully qualified name` | SSM parameter name missing leading `/` | Ensure all SSM names start with `/lab/` |
| `ParameterAlreadyExists` | Previous apply left SSM parameter behind | Add `overwrite = true` to SSM resource |
| `already exists` on Route53 record | Record persists from previous deployment | Add `allow_overwrite = true` to record resource |
| `NoSuchDistribution` on CloudFront CLI | Stale distribution ID in outputs | Run `terraform output cloudfront_distribution_id` for current ID |

---

## Audit Evidence Collection

Run after full four-stage apply:

```bash
mkdir -p evidence

python malgus_residency_proof.py \
  > evidence/residency_proof_$(date +%Y%m%d).json

python malgus_tgw_corridor_proof.py \
  > evidence/tgw_corridor_$(date +%Y%m%d).json

python malgus_cloudtrail_last_changes.py \
  > evidence/cloudtrail_$(date +%Y%m%d).json

python malgus_waf_summary.py --log-group aws-waf-logs-lab3 \
  > evidence/waf_summary_$(date +%Y%m%d).json

python malgus_cloudfront_log_explainer.py \
  --bucket class-lab3-778185677715 \
  --prefix Chwebacca-logs/ \
  > evidence/cloudfront_logs_$(date +%Y%m%d).txt
```

---

## APPI Compliance Summary

| Requirement | Implementation | Evidence |
|---|---|---|
| PHI stored only in Japan | RDS exists only in `ap-northeast-1` | `malgus_residency_proof.py` → `PASS` |
| No PHI in São Paulo | No RDS in `sa-east-1` | `malgus_residency_proof.py` → `saopaulo_rds: []` |
| Controlled cross-region access | TGW peering with explicit route tables | `malgus_tgw_corridor_proof.py` |
| All API actions logged | CloudTrail active in both regions | `malgus_cloudtrail_last_changes.py` |
| Edge traffic enforcement | WAF blocking malicious requests | `malgus_waf_summary.py` |
| Access logging | CloudFront logs to S3 `Chwebacca-logs/` | `malgus_cloudfront_log_explainer.py` |
| Origin cloaking | ALB rejects requests without `X-Chewbacca-Growl` | ALB listener rule + manual curl test |
