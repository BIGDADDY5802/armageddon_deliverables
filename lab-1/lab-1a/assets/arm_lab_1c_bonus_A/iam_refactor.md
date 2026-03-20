# IAM Role Refactor — `chewbacca_ec2_role01`

## What Changed

| Before | After |
|--------|-------|
| `aws_iam_policy` (standalone managed policy) | Removed |
| `aws_iam_role_policy` referencing `.policy` attribute of managed policy | Replaced with true inline policy containing the full `jsonencode` block |
| Hardcoded account ID in ARNs | `${data.aws_caller_identity.current.account_id}` |
| Commented-out `SecretsManagerReadWrite` attachment | Removed entirely |

---

## Why Inline Policy Over Managed Policy

An **inline policy** is embedded directly inside the IAM role. It lives with the role and is destroyed with the role. A **managed policy** is a separate AWS resource with its own ARN that can be attached to multiple roles.

For a single-purpose EC2 role like this one, inline is the better choice for three reasons:

**1. Auditability**
An auditor examining the role sees its full permission surface in one place. With a managed policy, they must chase an ARN to a separate resource, then verify no other roles share it. Inline removes that ambiguity entirely.

**2. Blast radius is contained**
A managed policy can be attached to multiple roles. A misconfiguration or overly broad edit affects every role that shares it. An inline policy affects exactly one role — the one it belongs to.

**3. Lifecycle coupling**
When the role is destroyed, the inline policy is destroyed with it. Managed policies can be orphaned — left in the account after the role is gone, accumulating over time, and creating confusion during future audits.

---

## Why the Two AWS-Managed Attachments Are Acceptable

`AmazonSSMManagedInstanceCore` and `CloudWatchAgentServerPolicy` are AWS-owned, AWS-maintained policies with well-defined and publicly documented permission sets. Security auditors recognize these by ARN and accept them as standard operational baselines. They are updated by AWS when services change, which reduces maintenance burden without introducing risk.

The previously commented-out `SecretsManagerReadWrite` was **not** acceptable — it grants write access to all secrets in the account, which violates least privilege and would be flagged immediately in any audit. It has been removed.

---

## Why Account ID Is Resolved Dynamically

```hcl
data "aws_caller_identity" "current" {}
```

This data source asks AWS at plan time: *"what account am I running in?"* The account ID is then injected into resource ARNs at apply time. This means:

- No hardcoded account numbers in source control
- The config is portable — it works correctly in any account it is applied to
- No risk of accidentally scoping a policy to the wrong account due to a copy-paste error