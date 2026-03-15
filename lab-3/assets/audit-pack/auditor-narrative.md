# Auditor Narrative — APPI Compliance Statement

This architecture was designed to comply with Japan's 個人情報保護法 (APPI) by ensuring
that all patient medical records (PHI) are stored exclusively within Japan at all times.
Tokyo (ap-northeast-1) serves as the sole data authority, hosting the RDS instance
(shinjuku-rds01) in availability zone ap-northeast-1c. São Paulo (sa-east-1) operates
as stateless compute only — it contains no database, no read replicas, no PHI cache,
and no persistent storage of any kind. This separation is enforced at the infrastructure
level, not by policy alone: the São Paulo Terraform state has no RDS resource and no
capability to create one. Doctors in South America access patient records by sending
requests through CloudFront to the São Paulo ALB, which forwards application queries
across an AWS Transit Gateway peering corridor directly to the Tokyo RDS private IP
(10.52.102.98) — traffic never traverses the public internet. CloudFront is permitted
under this design because it does not cache PHI: all /api/* behaviors use TTL=0 cache
policies, and Cache-Control headers from the origin are honored. WAF is applied at the
CloudFront edge to block malicious traffic before it reaches either region. All
infrastructure changes are captured in CloudTrail with a 90-day immutable record.
The data residency assertion was verified programmatically: RDS exists only in
ap-northeast-1, São Paulo returns an empty DB list, and a live TCP connection from
the São Paulo EC2 to Tokyo RDS on port 3306 was established in 280ms over the TGW
corridor. Access is permitted globally. Storage never leaves Japan.
