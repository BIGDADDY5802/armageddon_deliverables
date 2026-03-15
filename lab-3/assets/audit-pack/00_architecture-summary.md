# Lab 3 — APPI-Compliant Cross-Region Medical Architecture
## Architecture Summary

### Design Principle
**Global access does not require global storage.**
Japanese patient medical records (PHI) are stored exclusively in Tokyo (ap-northeast-1)
in compliance with Japan's 個人情報保護法 (APPI). Doctors in South America access
records via a controlled network corridor — never through public internet, never via
a database outside Japan.

### Regional Roles

| Region | Role | Contains |
|---|---|---|
| Tokyo (ap-northeast-1) | Data Authority | RDS, EC2, ALB, TGW hub, WAF, CloudFront, CloudTrail, Secrets Manager |
| São Paulo (sa-east-1) | Stateless Compute | EC2, ALB, TGW spoke — NO database, NO PHI at rest |

### Traffic Flow
```
User (anywhere)
   ↓
CloudFront EQUDJ3PPRYIZ (global edge)
   WAF: lab3-waf-cloudfront — blocks malicious traffic
   Origin cloaking: X-Chewbacca-Growl header
   ↓
Route 53 latency routing → origin.thedawgs2025.click
   ↓                          ↓
Tokyo ALB                 São Paulo ALB
shinjuku-alb01            liberdade-alb01
   ↓                          ↓
Tokyo EC2                 São Paulo EC2 (stateless)
   ↓                          ↓
Tokyo RDS ←——TGW Peering Corridor (tgw-attach-03d4fd57d799ee664)——
shinjuku-rds01
ap-northeast-1c
(PHI stored here ONLY)
```

### Key Resources

| Resource | ID |
|---|---|
| Domain | thedawgs2025.click |
| CloudFront Distribution | EQUDJ3PPRYIZ |
| WAF ACL | lab3-waf-cloudfront (us-east-1, CLOUDFRONT scope) |
| Tokyo VPC | vpc-05340bd48477eff9a (10.52.0.0/16) |
| Tokyo TGW | tgw-0072e50001f63a6db |
| Tokyo RDS | shinjuku-rds01.c76yg4640twf.ap-northeast-1.rds.amazonaws.com |
| São Paulo VPC | vpc-04dc19eed15db2858 (10.190.0.0/16) |
| São Paulo TGW | tgw-06ccfdc693b07e688 |
| TGW Peering | tgw-attach-03d4fd57d799ee664 (available) |
| Audit Bucket | class-lab3-778185677715 |
| CloudTrail | lab3-audit-trail (ap-northeast-1) |

### Compliance Controls
- PHI never leaves ap-northeast-1 (RDS, backups, snapshots all in Tokyo)
- CloudFront does not cache PHI (Cache-Control respected, /api/* TTL=0)
- TGW corridor is encrypted in transit on AWS backbone
- All infrastructure changes logged in CloudTrail (90-day immutable record)
- WAF applied at edge before traffic reaches any compute
- ALBs reject direct access — origin cloaking header required


evidence.json

{
  "lab": "Lab 3 — APPI-Compliant Cross-Region Medical Architecture",
  "account_id": "778185677715",
  "date": "2026-03-08",
  "domain": "thedawgs2025.click",

  "residency_proof": {
    "tokyo_rds": [
      {
        "region": "ap-northeast-1",
        "id": "shinjuku-rds01",
        "az": "ap-northeast-1c",
        "endpoint": "shinjuku-rds01.c76yg4640twf.ap-northeast-1.rds.amazonaws.com"
      }
    ],
    "saopaulo_rds": [],
    "assertion": "PASS"
  },

  "tgw_corridor": {
    "tokyo": {
      "region": "ap-northeast-1",
      "tgw_id": "tgw-0072e50001f63a6db",
      "tgw_state": "available",
      "role": "hub",
      "peering_attachment": "tgw-attach-03d4fd57d799ee664",
      "peering_state": "available",
      "vpc_attachment": "tgw-attach-0abc7be08c6874c49",
      "vpc_id": "vpc-05340bd48477eff9a"
    },
    "saopaulo": {
      "region": "sa-east-1",
      "tgw_id": "tgw-06ccfdc693b07e688",
      "tgw_state": "available",
      "role": "spoke",
      "peering_attachment": "tgw-attach-03d4fd57d799ee664",
      "peering_state": "available",
      "vpc_attachment": "tgw-attach-027d11e9454147fa5",
      "vpc_id": "vpc-04dc19eed15db2858"
    }
  },

  "waf_summary": {
    "log_group": "aws-waf-logs-lab3",
    "actions": [
      { "action": "ALLOW", "hits": "33" }
    ],
    "top_ips": [
      { "ip": "35.135.236.158", "hits": "31" },
      { "ip": "195.211.77.141", "hits": "2" }
    ]
  },

  "cloudfront": {
    "distribution_id": "EQUDJ3PPRYIZ",
    "domain": "d1b5fjh3xb6gu4.cloudfront.net",
    "log_bucket": "s3://class-lab3-778185677715/Chwebacca-logs/",
    "cache_outcomes": {
      "Hit": 0,
      "Miss": 2,
      "RefreshHit": 0,
      "Other:Error": 30,
      "Other:Redirect": 1
    },
    "note": "Error outcomes are from secret mismatch during initial setup. Resolved by syncing Secrets Manager to CloudFront origin header value."
  },

  "cloudtrail": {
    "trail_arn": "arn:aws:cloudtrail:ap-northeast-1:778185677715:trail/lab3-audit-trail",
    "notable_events": [
      {
        "time": "2026-03-08T20:10:12",
        "event": "ModifyRule",
        "user": "awscli",
        "source": "elasticloadbalancing.amazonaws.com",
        "region": "ap-northeast-1",
        "note": "ALB listener rule updated to sync X-Chewbacca-Growl secret"
      },
      {
        "time": "2026-03-08T18:45:21",
        "event": "StartSession",
        "user": "awscli",
        "source": "ssm.amazonaws.com",
        "region": "sa-east-1",
        "note": "SSM session to São Paulo EC2 for TGW RDS connectivity test"
      }
    ]
  },

  "curl_verification": {
    "command": "curl -I https://thedawgs2025.click/api/public-feed",
    "result": "HTTP/1.1 200 OK",
    "cache_control": "public, s-maxage=30, max-age=0",
    "x_cache": "Hit from cloudfront",
    "age": "6",
    "cf_pop": "DFW56-P6",
    "serving_region": "sa-east-1 (Route 53 latency routing — São Paulo closest to Fort Worth TX)"
  },

  "rds_connectivity_from_saopaulo": {
    "command": "nc -zv shinjuku-rds01.c76yg4640twf.ap-northeast-1.rds.amazonaws.com 3306",
    "result": "Connected to 10.52.102.98:3306",
    "latency_ms": 280,
    "path": "São Paulo EC2 → São Paulo TGW → TGW Peering → Tokyo TGW → Tokyo VPC → RDS private IP"
  }
}