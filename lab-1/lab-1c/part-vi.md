# Lab Incident Report — DB Connection Failure
## Mandatory Incident Runbook Submission
### Account: `778185677715` | Region: `us-east-1` | Date: January 26, 2026

---

## Incident Summary

| Field | Value |
|---|---|
| Alarm Name | `lab-db-connection-failure` |
| Alarm ARN | `arn:aws:cloudwatch:us-east-1:778185677715:alarm:lab-db-connection-failure` |
| State Change | `OK → ALARM` |
| Triggered | Monday, January 26, 2026 at 22:27:25 UTC |
| Notification | SNS email received at 4:27 PM |
| Root Cause | RDS security group missing all ingress and egress rules |
| Resolution | Security group rules restored — port 3306 traffic permitted |
| Final State | `ALARM → OK` |

---

## Alarm Configuration

| Field | Value |
|---|---|
| Metric Namespace | `Lab/RDSApp` |
| Metric Name | `DBConnectionErrors` |
| Period | 300 seconds |
| Statistic | Sum |
| Threshold | GreaterThanOrEqualTo `3.0` for 1 of last 1 period(s) |
| Trigger Value | `5.0` at `2026-01-26 22:22:00 UTC` |
| Missing Data Treatment | `notBreaching` |

---

## Runbook — Step by Step

### Step 1 — Confirm Alarm State

```bash
aws cloudwatch describe-alarms \
  --alarm-names lab-db-connection-failure \
  --query "MetricAlarms[].StateValue"
```

**Result:**
```json
["ALARM"]
```

**Finding:** ✅ Alarm confirmed in `ALARM` state. SNS notification delivered.

---

### Step 2 — Check Application Logs for Error Detail

```bash
aws logs filter-log-events \
  --log-group-name /aws/ec2/lab-rds-app \
  --filter-pattern "ERROR"
```

**Result:**

| Timestamp | Error |
|---|---|
| `1769463993596` | `DB_CONNECTION_FAILURE: (1146, "Table 'labdb.notes' doesn't exist")` |
| `1769466339497` | `DB_CONNECTION_FAILURE: (2003, "Can't connect to MySQL server on 'lab-rds01...' (timed out)")` |
| `1769466353475` | `DB_CONNECTION_FAILURE: (2003, "Can't connect to MySQL server on 'lab-rds01...' (timed out)")` |

**Finding:** Two distinct error types observed. First error was a missing table — resolved separately. Second error is a connection timeout — points to a network-layer failure, not an application issue.

---

### Step 3 — Verify SSM Parameters

```bash
aws ssm get-parameters \
  --names /lab/db/endpoint /lab/db/port /lab/db/name \
  --with-decryption
```

**Result:**

| Parameter | Value |
|---|---|
| `/lab/db/endpoint` | `lab-rds01.c89ykq22i31z.us-east-1.rds.amazonaws.com` |
| `/lab/db/port` | `3306` |
| `/lab/db/name` | `labdb` |

**Finding:** ✅ SSM parameters intact. Endpoint, port, and database name correct.

---

### Step 4 — Verify Secrets Manager

```bash
aws secretsmanager get-secret-value \
  --secret-id lab/rds/mysql
```

**Result:**

| Field | Value |
|---|---|
| Secret Name | `lab/rds/mysql` |
| Username | `admin` |
| Database | `labdb` |
| Host | `lab-rds01.c89ykq22i31z.us-east-1.rds.amazonaws.com` |
| Port | `3306` |

**Finding:** ✅ Credentials match known-good state. Password confirmed correct. Credentials were not the cause of the timeout.

---

### Step 5 — Identify Security Groups

```bash
aws ec2 describe-security-groups \
  --region us-east-1 \
  --query "SecurityGroups[].{GroupId:GroupId,Name:GroupName,VpcId:VpcId}" \
  --output table
```

**Result:**

| Group ID | Name | VPC |
|---|---|---|
| `sg-0fc0d361597c47fcb` | `lab-ec2-sg01` | `vpc-068d1fd4fc05e9d80` |
| `sg-0b1725c943055f81d` | `lab-rds-sg01` | `vpc-068d1fd4fc05e9d80` |

```bash
aws rds describe-db-instances \
  --db-instance-identifier lab-rds01 \
  --region us-east-1 \
  --query "DBInstances[].VpcSecurityGroups[].VpcSecurityGroupId" \
  --output table
```

**Result:**
```
sg-0b1725c943055f81d
```

**Finding:** RDS is attached to `lab-rds-sg01`. Proceeding to inspect rules.

---

### Step 6 — Inspect RDS Security Group Rules

```bash
aws ec2 describe-security-groups \
  --group-ids sg-0b1725c943055f81d \
  --region us-east-1 \
  --output json
```

**Result:**

| Direction | Protocol | Port | Source |
|---|---|---|---|
| Inbound | — | — | **None** |
| Outbound | — | — | **None** |

**Finding:** ❌ `lab-rds-sg01` has no inbound or outbound rules. Port 3306 traffic from the EC2 instance is being silently dropped. **Root cause identified.**

---

### Step 7 — Confirm EC2 Security Group (Cross-check)

```bash
aws ec2 describe-security-groups \
  --group-ids sg-0fc0d361597c47fcb \
  --region us-east-1 \
  --output json
```

**Result:**

| Direction | Protocol | Port | Source |
|---|---|---|---|
| Inbound | TCP | 80 | `0.0.0.0/0` |
| Inbound | TCP | 22 | `0.0.0.0/0` |
| Outbound | All | All | `0.0.0.0/0` |

**Finding:** ✅ EC2 security group is correctly configured. EC2 can initiate outbound traffic — it is the RDS security group that is blocking the connection.

---

## Root Cause

The RDS security group `lab-rds-sg01` (`sg-0b1725c943055f81d`) had no inbound or outbound rules. Port 3306 TCP traffic from the EC2 application tier was being dropped at the network layer, causing connection timeouts. The application correctly logged these as `DB_CONNECTION_FAILURE` events, which crossed the CloudWatch alarm threshold of 3 errors within a 300-second window.

---

## Recovery Verification

### Application responding

```bash
curl http://44.200.161.199/list
```

**Result:**
```html
<h3>Notes:</h3>
<li>3rd_entry</li>
<li>LabEntry</li>
<li>LabEntry</li>
<li>LabEntry</li>
```

**Status:** ✅ Application reading from RDS successfully.

### Alarm cleared

```bash
aws cloudwatch describe-alarms \
  --alarm-names lab-db-connection-failure \
  --query "MetricAlarms[].StateValue"
```

**Result:**
```json
["OK"]
```

**Status:** ✅ Alarm returned to `OK` state.

### No new errors in logs

```bash
MSYS_NO_PATHCONV=1 aws logs filter-log-events \
  --log-group-name "/aws/ec2/lab-rds-app" \
  --filter-pattern "DB_CONNECTION_FAILURE"
```

**Result:** No new error events after security group remediation.

**Status:** ✅ Clean log stream confirmed.

---

## Recovery Summary

| Check | Result |
|---|---|
| Alarm state | ✅ `OK` |
| Application response | ✅ `200` — data returned |
| Log stream | ✅ No new errors |
| RDS connectivity | ✅ Restored |

---

## Preventive Actions

### Reduce MTTR — Automated Security Group Drift Detection

Deploy a CloudWatch alarm that evaluates security group configuration on a 5–10 minute schedule. On drift detection, invoke a Lambda function that sends an SNS alert identifying the non-compliant rule. This eliminates manual investigation time during incidents.

### Prevent Recurrence — Infrastructure as Code with Peer Review

Security group rules managed through Terraform are version-controlled and auditable. Any rule change requires a pull request, peer review, and plan approval before apply. This prevents accidental misconfiguration from reaching production.

---

## What This Lab Taught

Meticulous runbook planning prevents infrastructure recovery failures. Creating runbooks reactively during incidents is exponentially harder than building them proactively.

When rollback is not viable and rapid recovery is mission-critical, pre-defined failure recovery paths eliminate root cause analysis under pressure — reducing MTTR from hours to minutes.

**Technical takeaway:** Document idempotent remediation sequences for common failure modes — security group detachment, IAM drift, network ACL blocks — with CLI verification commands and success criteria defined before incidents occur.