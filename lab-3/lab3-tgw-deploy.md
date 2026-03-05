# Lab 3 — TGW Cross-Region Peering: Pinpoint Launch Instructions

## Prerequisites
- São Paulo Terraform state is clean
- Tokyo Terraform state is clean
- Both `saopaulo_tgw_id` and `tokyo_tgw_peering_attachment_id` variables are present in their respective configs
- AWS CLI configured with access to both `sa-east-1` and `ap-northeast-1`

---

## Critical Rules Before You Start

- **Never apply Tokyo peering attachment before São Paulo TGW exists**
- **Never apply TGW routes before peering state is `available`**
- **Variable `tokyo_tgw_peering_attachment_id` takes an attachment ID (`tgw-attach-...`), not a TGW ID (`tgw-...`)**
- Verify state at each checkpoint before moving to the next step

---

## Step 1 — Deploy São Paulo TGW Only

```bash
cd saopaulo
terraform apply -target=aws_ec2_transit_gateway.liberdade_tgw01
```

**Checkpoint:** Capture `liberdade_tgw_id` from outputs.

```
liberdade_tgw_id = "tgw-XXXXXXXXXXXXXXXXX"
```

---

## Step 2 — Deploy Tokyo (Peering Attachment, Skip Route)

```bash
cd tokyo
terraform apply \
  -var="saopaulo_tgw_id=<liberdade_tgw_id>" \
  -target=aws_ec2_transit_gateway.shinjuku_tgw01 \
  -target=aws_ec2_transit_gateway_vpc_attachment.shinjuku_attach_tokyo_vpc01 \
  -target=aws_ec2_transit_gateway_peering_attachment.shinjuku_to_liberdade_peer01
```

> Do **not** include `aws_ec2_transit_gateway_route.tokyo_to_saopaulo` yet — peering is not accepted.

**Checkpoint:** Capture `tokyo_tgw_peering_attachment_id` from outputs.

```
tokyo_tgw_peering_attachment_id = "tgw-attach-XXXXXXXXXXXXXXXXX"
```

---

## Step 3 — Deploy São Paulo Full (Accept Peering + Add Route)

```bash
cd saopaulo
terraform apply -var="tokyo_tgw_peering_attachment_id=<tokyo_tgw_peering_attachment_id>"
```

This creates:
- `aws_ec2_transit_gateway_peering_attachment_accepter`
- `aws_ec2_transit_gateway_route.saopaulo_to_tokyo` (10.52.0.0/16 via peering)
- All remaining São Paulo resources

---

## Step 4 — Verify Peering is Available

```bash
aws ec2 describe-transit-gateway-peering-attachments \
  --region ap-northeast-1 \
  --filters "Name=transit-gateway-attachment-id,Values=<tokyo_tgw_peering_attachment_id>"
```

**Expected:**
```json
"State": "available"
```

Do not proceed until you see `available`. `pendingAcceptance` means São Paulo has not accepted yet.

---

## Step 5 — Deploy Tokyo Full (Add TGW Route)

```bash
cd tokyo
terraform apply -var="saopaulo_tgw_id=<liberdade_tgw_id>"
```

This adds `aws_ec2_transit_gateway_route.tokyo_to_saopaulo` (10.190.0.0/16 via peering).

---

## Step 6 — Verify Routes on Both Sides

**São Paulo** — must show `10.52.0.0/16` via TGW:
```bash
aws ec2 describe-route-tables \
  --region sa-east-1 \
  --filters Name=vpc-id,Values=<liberdade_vpc_id> \
  --query 'RouteTables[].Routes[]'
```

**Tokyo** — must show `10.190.0.0/16` via TGW:
```bash
aws ec2 describe-route-tables \
  --region ap-northeast-1 \
  --filters Name=vpc-id,Values=<tokyo_vpc_id> \
  --query 'RouteTables[].Routes[]'
```

---

## Step 7 — Verify TGW Route Tables on Both Sides

**Tokyo TGW route table:**
```bash
aws ec2 describe-transit-gateway-route-tables \
  --region ap-northeast-1 \
  --filters "Name=transit-gateway-id,Values=<tokyo_tgw_id>"

aws ec2 search-transit-gateway-routes \
  --region ap-northeast-1 \
  --transit-gateway-route-table-id <tgw-rtb-id> \
  --filters "Name=type,Values=static,propagated"
```

Must show `10.190.0.0/16` via peering attachment.

**São Paulo TGW route table:**
```bash
aws ec2 describe-transit-gateway-route-tables \
  --region sa-east-1 \
  --filters "Name=transit-gateway-id,Values=<liberdade_tgw_id>"

aws ec2 search-transit-gateway-routes \
  --region sa-east-1 \
  --transit-gateway-route-table-id <tgw-rtb-id> \
  --filters "Name=type,Values=static,propagated"
```

Must show `10.52.0.0/16` via peering attachment.

---

## Step 8 — End-to-End Connectivity Test

SSM into São Paulo EC2:
```bash
aws ssm start-session --target <liberdade_ec2_instance_id> --region sa-east-1
```

Test port 3306 to Tokyo RDS:
```bash
nc -zv <tokyo_rds_endpoint> 3306
```

**Expected:**
```
Ncat: Connected to 10.52.x.x:3306.
```

---

## What Each Piece Does

| Resource | Purpose |
|---|---|
| `aws_ec2_transit_gateway` | Regional TGW — the router |
| `aws_ec2_transit_gateway_vpc_attachment` | Connects VPC to local TGW |
| `aws_ec2_transit_gateway_peering_attachment` | Initiates cross-region peering (Tokyo side) |
| `aws_ec2_transit_gateway_peering_attachment_accepter` | Accepts peering (São Paulo side) |
| `aws_ec2_transit_gateway_route` | Tells TGW where to send cross-region traffic |
| VPC route table entry | Tells VPC to send cross-region traffic into TGW |
| Security group rules | Allow specific CIDR + port combinations |

---

## Common Failure Points

| Symptom | Cause |
|---|---|
| `nc` timeout | Missing TGW route — check both TGW route tables |
| Peering attachment `failed` | São Paulo TGW did not exist when Tokyo applied |
| Accepter forces replacement | Variable set to TGW ID instead of attachment ID |
| TGW route `IncorrectState` | Tried to add route before peering was `available` |
| Empty peering result | Queried wrong region — peering lives on requester (Tokyo) side |
