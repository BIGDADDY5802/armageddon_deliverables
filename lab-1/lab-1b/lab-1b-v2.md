# Lab Security Review — EC2, Security Groups, RDS, and Secrets

**Region:** us-east-1
**Account:** 778185677715
**Report Date:** 2026-02-24

---

# Executive Summary

This assessment reviews the security posture of your current cloud deployment on Amazon Web Services.

**Strengths**

* Private database configuration
* Encryption at rest enabled
* IAM-scoped secret access
* IMDSv2 enforced
* Performance Insights enabled

**Primary Risk**

* EC2 instance is publicly exposed via SSH and HTTP

**Overall Posture:** ⚠️ Mixed — strong data-layer security, weak edge exposure

---

# Architecture Overview

## Core Services

* Compute: Amazon EC2
* Database: Amazon RDS
* Secret storage: AWS Secrets Manager
* Monitoring: Amazon CloudWatch Logs

---

# EC2 Instance Analysis

## Instance Identity

| Attribute     | Value               |
| ------------- | ------------------- |
| Instance ID   | i-0d38fc923280ebb68 |
| Name          | lab-ec2-app         |
| Instance Type | t3.micro            |
| State         | running             |
| AZ            | us-east-1a          |

---

## Network Exposure

### Public Interface

| Property   | Value                                    |
| ---------- | ---------------------------------------- |
| Public IP  | **3.231.93.117**                         |
| Public DNS | ec2-3-231-93-117.compute-1.amazonaws.com |
| Private IP | 10.180.1.145                             |
| Subnet     | subnet-0d28bd34e9f2d296e                 |

### Security Assessment

🚨 **The instance is publicly reachable from the internet.**

**Implications**

* Internet-wide scanning possible
* SSH brute-force risk
* Increased attack surface
* Not aligned with zero-trust patterns

---

# Instance Security Group Review

## Security Group Metadata

| Field | Value                 |
| ----- | --------------------- |
| Name  | armageddon-public-sg  |
| ID    | sg-01a0f1bc58d478430  |
| VPC   | vpc-013c423ca14ee628e |

---

## Inbound Rules

| Port | Protocol | Source    | Description  | Risk      |
| ---- | -------- | --------- | ------------ | --------- |
| 80   | TCP      | 0.0.0.0/0 | homepage     | ⚠️ Public |
| 22   | TCP      | 0.0.0.0/0 | secure-shell | 🚨 High   |

### Critical Finding

**SSH open to the world (0.0.0.0/0)** is one of the most common cloud security failures.

**Recommended state**

* Remove SSH entirely
* Use Session Manager instead
* Restrict HTTP behind ALB/CloudFront

---

## Outbound Rules

| Protocol | Destination |
| -------- | ----------- |
| All (-1) | 0.0.0.0/0   |

**Assessment:** Acceptable default in most architectures.

---

# RDS Instance Review

## Database Identity

| Property   | Value        |
| ---------- | ------------ |
| Identifier | lab-mysql    |
| Engine     | MySQL 8.4.7  |
| Class      | db.m7g.large |
| Port       | 3306         |
| Multi-AZ   | false        |

---

## Network Security

### Public Exposure

| Setting            | Value       |
| ------------------ | ----------- |
| PubliclyAccessible | **false** ✅ |

**Result:** Database is private and not internet reachable.

---

## Subnet Placement

RDS subnet group contains:

* subnet-030784edc268424b3 (us-east-1a)
* subnet-0963e454eb1bc66a8 (us-east-1b)

**Assessment:** Proper multi-AZ subnet coverage.

---

## Encryption and Observability

| Control              | Status |
| -------------------- | ------ |
| Storage encrypted    | ✅      |
| KMS key configured   | ✅      |
| Performance Insights | ✅      |
| CloudWatch exports   | ✅      |

**Data-layer posture:** Strong.

---

# IAM Role and Secret Access

## Attached Policy

* `get_secrets_secret_manager`

**Purpose:** Allow EC2 workload to retrieve database credentials securely.

---

## Secret Metadata

| Field         | Value                                     |
| ------------- | ----------------------------------------- |
| Name          | lab/rds/mysql                             |
| Description   | Access credentials for MySQL RDS database |
| Last changed  | 2026-01-05                                |
| Last accessed | 2026-01-14                                |
| Version stage | AWSCURRENT                                |

---

# Why Secrets Manager Is Superior

Using managed secrets provides:

* Centralized lifecycle management
* Fine-grained IAM authorization
* Encryption with KMS
* Audit visibility
* Runtime retrieval
* Optional automatic rotation

---

## Risks of Hardcoded Credentials

If credentials were stored in:

* user-data
* environment variables
* source code

You would lose:

* secure rotation
* auditability
* blast-radius control
* centralized governance

**Conclusion:** Secrets Manager is the correct production pattern.

---

# Concept Validation

## A) Why is DB inbound restricted to the EC2 security group?

Your reasoning is correct.

Security group referencing:

* Enforces least privilege
* Prevents arbitrary network access
* Limits lateral movement
* Uses stateful connection tracking

**Security impact**

If EC2 is compromised:

* attacker cannot directly access DB from elsewhere
* blast radius remains constrained

✅ This is the industry-preferred design.

---

## B) What port does MySQL use?

**Answer:** 3306 ✅

---

## C) Why is Secrets Manager better than storing creds in code/user-data?

Your explanation is technically accurate and interview-ready.

**Key advantages**

* Encryption at rest
* IAM authorization
* Versioning
* Rotation capability
* Audit trails

---

# Least-Privilege Analysis

## Why broader access is forbidden

Allowing wide Secrets Manager access would:

* Increase credential exfiltration risk
* Expand blast radius
* Violate least privilege
* Enable lateral discovery attacks

**Restriction is correct and necessary.**

---

## Why the role exists

The IAM role enables:

* Runtime secret retrieval
* Removal of hardcoded credentials
* Secure workload identity
* Future rotation support

**Design quality:** Good.

---

## Why it can read this secret

Because the identity policy explicitly grants:

```bash
secretsmanager:GetSecretValue
```

for the matching secret ARN.

This is proper resource-scoped authorization.

---

## Why it cannot read others

Because the IAM policy scope is narrowly defined.

This enforces:

* tenant isolation
* credential boundary control
* least privilege

---

# Top Security Findings

## Critical

* SSH open to internet
* EC2 has public IP

## Medium

* RDS is single-AZ (availability concern)
* No evidence of secret rotation

## Low

* Wide egress (generally acceptable)
* EC2 detailed monitoring disabled

---

# Recommended Hardening Roadmap

## Immediate (High Priority)

* Remove public IP from EC2
* Remove port 22 exposure
* Use Session Manager only
* Move instance to private subnet

---

## Strongly Recommended

* Enable Secrets Manager rotation
* Enable EC2 detailed monitoring
* Consider Multi-AZ RDS
* Add VPC Flow Logs
* Install CloudWatch agent

---

## Elite-Level Improvements

* Add WAF in front of ALB
* Use private ALB + CloudFront
* Implement SCP guardrails
* Enable GuardDuty
* Enable Inspector

---

# Final Verdict

**Data layer:** ✅ Strong
**Identity model:** ✅ Good
**Network edge:** 🚨 Needs improvement

You are close to enterprise-grade, but the public EC2 exposure would be flagged in most security reviews.

---

# Interview-Ready Summary

> The database tier is private and IAM-scoped via Secrets Manager; the remaining hardening step is eliminating direct internet exposure from the compute layer and enforcing Session Manager–only access.

---

**End of Report**

```
```
