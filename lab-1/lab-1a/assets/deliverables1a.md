Lab Security Review — EC2, Security Groups, RDS, and Secrets

Environment: us-east-1
Account: REDACTED
Date: 2026-02-24

This document provides a comprehensive technical assessment of the current architecture, validates security posture, and explains key design decisions in employer-credible language.

🧭 Executive Summary

Your environment demonstrates a partially hardened cloud pattern with strong controls around:

Private RDS

IAM-scoped secret access

IMDSv2 enforcement

Encryption at rest

However, the EC2 instance is still publicly exposed via SSH and HTTP, which would not pass most production security reviews.

Overall posture: ⚠️ Mixed (Good data-layer security, weak edge posture)

🖥️ EC2 Instance Analysis
Instance Identity
Attribute	Value
Instance ID	REDACTED
Name	lab-ec2-app
Type	t3.micro
State	running
AZ	us-east-1a
🌐 Network Exposure
Public Interface
Property	Value
Public IP	REDACTED
Public DNS	REDACTED
Private IP	REDACTED
Subnet	REDACTED
🚨 Security Assessment

This instance is publicly reachable from the internet.

Implications:

Internet scanners can reach the host

SSH brute-force attempts likely

Increases attack surface

Not aligned with modern zero-trust patterns

🔐 Instance Security Group Review
Security Group
Field	Value
Name	armageddon-public-sg
ID	REDACTED
VPC	REDACTED
Inbound Rules
Port	Protocol	Source	Description	Risk
80	TCP	0.0.0.0/0	homepage	⚠️ Public
22	TCP	0.0.0.0/0	secure-shell	🚨 High
🔴 Critical Finding

SSH is open to the entire internet.

This is one of the most commonly exploited misconfigurations in cloud environments.

Outbound Rules
Protocol	Destination
All (-1)	0.0.0.0/0

Status: Standard default — acceptable in most architectures.

🗄️ RDS Instance Review
Database Identity
Property	Value
Identifier	lab-mysql
Engine	MySQL 8.4.7
Class	db.m7g.large
Port	3306
Multi-AZ	false
🔒 Network Security
Public Exposure
Setting	Value
PubliclyAccessible	false ✅

Result: Database is private.

Subnet Placement

RDS subnet group:

REDACTED (us-east-1a)

REDACTED (us-east-1b)

Status: Proper multi-AZ subnet placement.

Encryption
Control	Status
Storage encrypted	✅
KMS key	Present
Performance Insights	Enabled
CloudWatch exports	Enabled

Assessment: Strong data-layer posture.

🔐 IAM Role and Secrets Access
Attached Policy

get_secrets_secret_manager

Purpose: Allow EC2 workload to retrieve database credentials securely.

Secret Metadata
Field	Value
Name	lab/rds/mysql
Rotation	Not shown
Last changed	REDACTED
Last accessed	REDACTED
✅ Why Secrets Manager Is Superior

Using managed secrets provides:

Centralized secret lifecycle

Fine-grained IAM authorization

Audit visibility

Encryption at rest

Runtime retrieval

Rotation capability

❌ Problems With Hardcoding

If credentials were in:

user-data

environment variables

source code

You would lose:

rotation agility

auditability

blast-radius control

secure storage guarantees

🧠 Concept Questions (Validated)
A) Why is DB inbound source restricted to the EC2 security group?

Correct reasoning.

Security group referencing:

Enforces least privilege

Prevents arbitrary network access

Limits lateral movement

Uses stateful connection tracking

Security Impact

If the EC2 is compromised:

attacker still cannot directly access DB from elsewhere

lateral movement is constrained

blast radius is reduced

✅ This is the industry-preferred pattern

B) What port does MySQL use?

Answer: 3306 ✅

C) Why is Secrets Manager better than storing creds in code/user-data?

Your explanation is technically sound.

Key Advantages

Secrets Manager provides:

Encryption with KMS

IAM-based authorization

API retrieval

Versioning

Optional rotation

Audit trails

Verdict: Correct and interview-ready.

🔐 Least-Privilege Analysis
Why broader access is forbidden

Allowing wide Secrets Manager access would:

Increase credential exfiltration risk

Expand blast radius

Violate least privilege

Enable lateral discovery attacks

This restriction is correct and necessary.

Why the role exists

The IAM role:

Enables runtime secret retrieval

Avoids hardcoded credentials

Supports secure workload identity

Enables future rotation

Design quality: Good

Why it can read this secret

Because the identity policy explicitly grants appropriate access to the specific secret resource.

This is proper resource-scoped authorization.

Why it cannot read others

Because the policy scope is narrow.

This enforces:

tenant isolation

credential boundary control

least privilege

This is exactly what security reviewers want to see.

🚨 Top Security Findings
Critical

SSH open to internet (0.0.0.0/0)

Instance has public IP

Medium

Single-AZ RDS (availability concern)

No evidence of secret rotation

Low

Wide egress (usually acceptable)

Monitoring disabled on EC2

🛠️ Recommended Hardening (Production Grade)
Immediate (High Impact)

Remove public IP from EC2

Remove port 22 from internet

Use SSM Session Manager only

Move instance to private subnet

Strongly Recommended

Enable secret rotation

Enable EC2 detailed monitoring

Consider Multi-AZ RDS

Add VPC Flow Logs

Add CloudWatch agent

Elite-Level Improvements

Add WAF in front of ALB

Use private ALB + CloudFront

Implement SCP guardrails

Add GuardDuty

Add Inspector

🏁 Final Verdict

Data layer: ✅ Strong
Identity model: ✅ Good
Edge exposure: 🚨 Needs improvement

You are very close to enterprise-ready, but the public EC2 exposure would be flagged in a real security review.

💬 Interview-Ready One-Liner

“The database tier is fully private and IAM-scoped via Secrets Manager; next step is removing direct internet exposure from the compute layer and enforcing SSM-only access.”