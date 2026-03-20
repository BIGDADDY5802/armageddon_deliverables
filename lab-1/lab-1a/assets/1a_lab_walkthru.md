# EC2 Web App → RDS (MySQL) — "Notes" App Lab

---

## Overview

### Goal

Deploy a simple web application on an EC2 instance that can:

- Insert a note into an RDS MySQL database
- List notes stored in the database

### Requirements

| Component | Detail |
|---|---|
| RDS MySQL | Instance in a private subnet |
| EC2 Instance | Running a Python Flask application |
| Security Groups | EC2 → RDS allowed on port 3306 |
| Credentials | Stored in AWS Secrets Manager |

---

## Part 1 — Create RDS MySQL

### Option A — RDS Private + EC2 Public (Recommended)

**Console Steps:**

1. RDS Console → **Create database**
2. Engine: `MySQL`
3. Template: `Free tier` (or Dev/Test)
4. DB instance identifier: `lab-mysql`
5. Master username: `admin`
6. Password: generate or set manually (store securely)
7. Connectivity:
   - VPC: default (or lab VPC)
   - Public access: **No**
   - VPC security group: create new `sg-rds-lab`
8. Click **Create DB**

---

### AWS CLI Verification

#### List all security groups in a region

```bash
aws ec2 describe-security-groups \
  --region us-east-1 \
  --query "SecurityGroups[].{GroupId:GroupId,Name:GroupName,VpcId:VpcId}" \
  --output table
```

**Output:**

```
-------------------------------------------------------------------
|                     DescribeSecurityGroups                      |
+-----------------------+---------------+-------------------------+
|        GroupId        |     Name      |          VpcId          |
+-----------------------+---------------+-------------------------+
|  sg-REDACTED-rds      |  lab-rds-sg01 |  vpc-REDACTED           |
|  sg-REDACTED-ec2      |  lab-ec2-sg01 |  vpc-REDACTED           |
+-----------------------+---------------+-------------------------+
```

> **Note:** Only lab-relevant security groups shown. Additional groups in account are redacted.

---

#### Inspect a specific security group (inbound & outbound rules)

```bash
aws ec2 describe-security-groups \
  --group-ids <sg-ec2-id> \
  --region us-east-1 \
  --output json
```

**Output (redacted):**

```json
{
  "SecurityGroups": [
    {
      "GroupName": "lab-ec2-sg01",
      "Description": "EC2 app security group",
      "IpPermissions": [
        {
          "IpProtocol": "tcp",
          "FromPort": 80,
          "ToPort": 80,
          "IpRanges": [{ "CidrIp": "0.0.0.0/0" }]
        },
        {
          "IpProtocol": "tcp",
          "FromPort": 22,
          "ToPort": 22,
          "IpRanges": [{ "CidrIp": "<MY-IP-REDACTED>/32" }]
        }
      ],
      "IpPermissionsEgress": [
        {
          "IpProtocol": "-1",
          "IpRanges": [{ "CidrIp": "0.0.0.0/0" }]
        }
      ]
    }
  ]
}
```

---

#### Verify which resources are using a security group

**EC2 instances:**

```bash
aws ec2 describe-instances \
  --filters Name=instance.group-id,Values=<sg-ec2-id> \
  --region us-east-1 \
  --query "Reservations[].Instances[].InstanceId" \
  --output table
```

**Output:**

```
-------------------------
|   DescribeInstances   |
+-----------------------+
|  i-REDACTED           |
+-----------------------+
```

**RDS instances:**

```bash
aws rds describe-db-instances \
  --region us-east-1 \
  --query "DBInstances[?contains(VpcSecurityGroups[].VpcSecurityGroupId, '<sg-rds-id>')].DBInstanceIdentifier" \
  --output table
```

**Output:**

```
---------------------
|DescribeDBInstances|
+-------------------+
|  lab-rds01        |
+-------------------+
```

---

#### List all RDS instances

```bash
aws rds describe-db-instances \
  --region us-east-1 \
  --query "DBInstances[].{DB:DBInstanceIdentifier,Engine:Engine,Public:PubliclyAccessible,Vpc:DBSubnetGroup.VpcId}" \
  --output table
```

**Output:**

```
------------------------------------------------------------
|                    DescribeDBInstances                   |
+-----------+---------+---------+--------------------------+
|    DB     | Engine  | Public  |           Vpc            |
+-----------+---------+---------+--------------------------+
|  lab-rds01|  mysql  |  False  |  vpc-REDACTED            |
+-----------+---------+---------+--------------------------+
```

---

#### Verify RDS security group assignment

```bash
aws rds describe-db-instances \
  --db-instance-identifier lab-rds01 \
  --region us-east-1 \
  --query "DBInstances[].VpcSecurityGroups[].VpcSecurityGroupId" \
  --output table
```

**Output:**

```
--------------------------
|   DescribeDBInstances  |
+------------------------+
|  sg-REDACTED-rds       |
+------------------------+
```

**Verification:** `VpcSecurityGroupId` matches `lab-rds-sg01` ✅

---

#### Verify RDS subnet placement

```bash
aws rds describe-db-subnet-groups \
  --region us-east-1 \
  --query "DBSubnetGroups[].{Name:DBSubnetGroupName,Vpc:VpcId,Subnets:Subnets[].SubnetIdentifier}" \
  --output table
```

**Output:**

```
-----------------------------------------------------
|              DescribeDBSubnetGroups               |
+-------------------------+-------------------------+
|          Name           |           Vpc           |
+-------------------------+-------------------------+
|  lab-rds-subnet-group01 |  vpc-REDACTED           |
+-------------------------+-------------------------+
||                     Subnets                     ||
|+-------------------------------------------------+|
||  subnet-REDACTED-1a                             ||
||  subnet-REDACTED-1b                             ||
|+-------------------------------------------------+|
```

**What you are verifying:**
- Private subnets only (no public subnet IDs)
- No Internet Gateway route
- Correct Availability Zone spread (us-east-1a and us-east-1b)

---

#### Verify RDS is not publicly reachable

```bash
aws rds describe-db-instances \
  --db-instance-identifier lab-rds01 \
  --region us-east-1 \
  --query "DBInstances[].PubliclyAccessible" \
  --output text
```

**Expected output:**

```
False
```

**Result:** ✅ Confirmed — RDS is not internet-accessible.

---

### Security Group Design — RDS (`lab-rds-sg01`)

This is the core real-world security pattern: **restrict database access to the app tier only** — not the internet, not your laptop, not other servers.

| Direction | Protocol | Port | Source |
|---|---|---|---|
| Inbound | TCP | 3306 | `lab-ec2-sg01` (security group reference) |
| Outbound | All | All | `0.0.0.0/0` (default — do not modify) |

> Think of it like a bank vault: only the teller (EC2) has the key, not the general public.

---

## Part 2 — Launch EC2

**Console Steps:**

1. EC2 Console → **Launch instance**
2. Name: `lab-ec2-app`
3. AMI: `Amazon Linux 2023`
4. Instance type: `t3.micro` (or `t2.micro`)
5. Key pair: select or create one (**required for SSH access**)
6. Network: same VPC as RDS
7. Security group: create `lab-ec2-sg01`

---

### Security Group Design — EC2 (`lab-ec2-sg01`)

| Direction | Protocol | Port | Source |
|---|---|---|---|
| Inbound | TCP | 80 | `0.0.0.0/0` (public web access) |
| Inbound | TCP | 22 | Your IP only (SSH) |
| Outbound | All | All | `0.0.0.0/0` (default) |

After creating the EC2 security group, go back to the RDS security group inbound rule and set:

> **Source = `lab-ec2-sg01` for TCP 3306**

This creates a security-group-to-security-group reference — the cleanest AWS network trust pattern.

---

### SSH Access — Troubleshooting Log

#### Attempt 1 — Failed (Key Pair Not Attached)

```
ec2-user@<REDACTED>.compute-1.amazonaws.com: Permission denied (publickey)
```

**Root cause:** Instance was launched without a key pair attached. EC2 Instance Connect also failed because SSH port 22 was restricted to a single IP, which conflicts with Instance Connect's IP ranges.

**Resolution:** Terminated instance and relaunched with key pair attached. Public IP changed on relaunch (expected behavior for instances without Elastic IP).

---

#### Attempt 2 — Successful

```bash
chmod 400 "armageddon-lab-1.pem"
ssh -i "armageddon-lab-1.pem" ec2-user@<REDACTED>.compute-1.amazonaws.com
```

Accept the host fingerprint prompt (`yes`) and you are in:

```
   ,     #_
   ~\_  ####_        Amazon Linux 2023
  ~~  \_#####\
  ~~     \###|       https://aws.amazon.com/linux/amazon-linux-2023
  ~~       \#/ ___
   ~~       V~' '->
    ~~~         /
      ~~._.   _/
         _/ _/
       _/m/'
[ec2-user@ip-10-x-x-x ~]$
```

> **Key finding:** EC2 Instance Connect requires its own IP range to be allowed on port 22. If SSH is locked to your personal IP only, Instance Connect will not work. Use a `.pem` key instead.

---

## Part 3 — Store DB Credentials in Secrets Manager

**Console Steps:**

1. Secrets Manager → **Store a new secret**
2. Secret type: `Credentials for RDS database`
3. Username/password: `admin` + your password
4. Select RDS instance: `lab-rds01`
5. Secret name: `lab/rds/mysql`

---

### Verify Secrets Manager (Existence, Metadata, Access)

#### List all secrets

```bash
aws secretsmanager list-secrets \
  --region us-east-1 \
  --query "SecretList[].{Name:Name,ARN:ARN,Rotation:RotationEnabled}" \
  --output table
```

**Output (redacted):**

```
+----------+------------------------------------------------------------+
|  ARN     |  arn:aws:secretsmanager:us-east-1:REDACTED:secret:lab/rds/mysql-XXXXX  |
|  Name    |  lab/rds/mysql                                             |
|  Rotation|  None                                                      |
+----------+------------------------------------------------------------+
```

**What you are verifying:**
- Secret exists with the correct name
- Rotation state is known (none in this lab — acceptable)
- Naming convention is intentional (`lab/rds/mysql`)

---

#### Describe a specific secret — safe, no value exposure

```bash
aws secretsmanager describe-secret \
  --secret-id lab/rds/mysql \
  --region us-east-1 \
  --output json
```

**Output (redacted):**

```json
{
  "ARN": "arn:aws:secretsmanager:us-east-1:REDACTED:secret:lab/rds/mysql-XXXXX",
  "Name": "lab/rds/mysql",
  "LastChangedDate": "2026-03-19T...",
  "LastAccessedDate": "2026-03-19T...",
  "VersionIdsToStages": {
    "terraform-XXXXX": ["AWSCURRENT"]
  },
  "CreatedDate": "2026-03-19T..."
}
```

> This command is always safe. It never exposes the secret value — only metadata.

**Key fields to review:**

| Field | Purpose |
|---|---|
| `RotationEnabled` | Confirm rotation status |
| `KmsKeyId` | Confirm encryption key (if custom KMS used) |
| `LastChangedDate` | Detect unexpected modifications |
| `LastAccessedDate` | Confirm the app is reading it |

---

#### Verify which IAM principals can access the secret

```bash
aws secretsmanager get-resource-policy \
  --secret-id lab/rds/mysql \
  --region us-east-1 \
  --output json
```

**Output:**

```json
{
  "ARN": "arn:aws:secretsmanager:us-east-1:REDACTED:secret:lab/rds/mysql-XXXXX",
  "Name": "lab/rds/mysql"
}
```

No resource policy is attached — access is controlled entirely by IAM role policy. This is acceptable for a single-account lab.

**What you are verifying:**
- No wildcard (`*`) principals
- No unexpected cross-account access

---

## Part 4 — IAM Role for EC2

### Create the Role

1. IAM → Roles → **Create role**
2. Trusted entity: `EC2`
3. Permission policy: start with `SecretsManagerReadWrite` for the lab, then tighten to an inline policy scoped to the specific secret ARN
4. Attach role to EC2: `EC2 → Instance → Actions → Security → Modify IAM role`

> **Note:** `SecretsManagerReadWrite` is intentionally broad for lab speed. Replace with a scoped inline policy before any production use. See `inline_policy.json` in this folder.

---

### Verify IAM Role Attached to EC2

#### Step 1 — Identify the instance

```bash
aws ec2 describe-instances \
  --filters Name=tag:Name,Values=lab-ec201 \
  --region us-east-1 \
  --query "Reservations[].Instances[].InstanceId" \
  --output text
```

**Output:**

```
i-REDACTED
```

---

#### Step 2 — Check the attached IAM role

```bash
aws ec2 describe-instances \
  --instance-ids <instance-id> \
  --region us-east-1 \
  --query "Reservations[].Instances[].IamInstanceProfile.Arn" \
  --output text
```

**Output:**

```
arn:aws:iam::REDACTED:instance-profile/lab-instance-profile01
```

> If this returns empty, no role is attached — this is a security finding.

---

#### Step 3 — Resolve instance profile → role name

```bash
aws iam get-instance-profile \
  --instance-profile-name lab-instance-profile01 \
  --query "InstanceProfile.Roles[].RoleName" \
  --output text
```

**Output:**

```
lab-ec2-role01
```

---

### Common Error — Instance Profile vs. IAM Role Confusion

**Error encountered:**

```
aws: [ERROR]: An error occurred (NoSuchEntity) when calling the ListAttachedRolePolicies operation:
The role with name lab-instance-profile01 cannot be found.
```

**Root cause:** An IAM Instance Profile and an IAM Role are separate entities. Although the console often creates them with the same name, you must query the **role name** (retrieved above), not the profile name.

Think of it like a lanyard (instance profile) holding a badge (IAM role). You don't ask what the lanyard can do — you ask what the badge says.

**Correct command:**

```bash
aws iam list-attached-role-policies \
  --role-name lab-ec2-role01 \
  --output table
```

---

### Verify IAM Role Permissions

#### List attached managed policies

```bash
aws iam list-attached-role-policies \
  --role-name lab-ec2-role01 \
  --output table
```

**Output:**

```
+-------------------------------------------------------+--------------------------------+
|                       PolicyArn                       |          PolicyName            |
+-------------------------------------------------------+--------------------------------+
|  arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy  |  CloudWatchAgentServerPolicy   |
|  arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore |  AmazonSSMManagedInstanceCore  |
|  arn:aws:iam::aws:policy/SecretsManagerReadWrite      |  SecretsManagerReadWrite       |
+-------------------------------------------------------+--------------------------------+
```

---

#### List inline policies

```bash
aws iam list-role-policies \
  --role-name lab-ec2-role01 \
  --output table
```

**Output:**

```
------------------
|ListRolePolicies|
+----------------+
```

No inline policies attached. Currently using the broad managed policy. Inline policy with least-privilege scoping is the planned next step.

---

#### Inspect the SecretsManagerReadWrite managed policy

```bash
aws iam get-policy-version \
  --policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite \
  --version-id v1 \
  --output json
```

**Key finding:** This policy grants `secretsmanager:*` on `Resource: "*"` — meaning it can read, write, and delete **any** secret in the account. This is acceptable for a lab but must be replaced with a scoped inline policy in production.

**What you are verifying:**

| Check | Target |
|---|---|
| Least privilege | Only `secretsmanager:GetSecretValue` needed for read-only |
| No wildcard `*` on resource | Should be scoped to specific secret ARN |
| No unintended Lambda/S3 permissions | Review all statements in the policy |

---

## Part 5 — Bootstrap the EC2 Application

In the EC2 launch wizard, paste the bootstrap script into **User data**, or run it manually after SSH.

> **Important:** Replace `SECRET_ID` if you used a different secret name.

See `user_data.sh` in this folder for the full script.

---

## Part 6 — Test the Application

### Endpoints

| Endpoint | Action |
|---|---|
| `http://<EC2_PUBLIC_IP>/init` | Initialize the database table |
| `http://<EC2_PUBLIC_IP>/add?note=first_note` | Insert a note |
| `http://<EC2_PUBLIC_IP>/list` | List all notes |

---

### Verified Output

```bash
curl -I http://<REDACTED>/list
```

```
HTTP/1.1 200 OK
Server: Werkzeug/3.1.6 Python/3.9.25
Content-Type: text/html; charset=utf-8
```

```bash
curl -i http://<REDACTED>/list
```

```html
<h3>Notes</h3>
<ul>
  <li>4: add_notes_here</li>
  <li>3: blue_in_the_face</li>
  <li>2: we_adding_notes</li>
  <li>1: hello</li>
</ul>
```

**Result:** ✅ Application successfully inserting and retrieving notes from RDS.

---

### Common Failure Points

If `/init` hangs or returns an error, check these in order:

1. RDS security group inbound rule does not allow `lab-ec2-sg01` on port 3306
2. RDS and EC2 are not in the same VPC or subnets are not routable
3. EC2 IAM role is missing `secretsmanager:GetSecretValue`
4. Secret does not contain `host`, `username`, or `password` fields — fix by creating the secret as "Credentials for RDS database" type

---

### Verify EC2 → RDS Network Path

```bash
aws ec2 describe-security-groups \
  --group-ids <sg-ec2-id> \
  --region us-east-1 \
  --query "SecurityGroups[].IpPermissions"
```

> **Note:** The `--group-ids` parameter requires the security group ID (e.g., `sg-XXXXXXXX`), not the group name. Passing the name returns `InvalidGroupId.Malformed`.

**Output confirms:**

```json
[
  { "IpProtocol": "tcp", "FromPort": 80, "ToPort": 80, "IpRanges": [{ "CidrIp": "0.0.0.0/0" }] },
  { "IpProtocol": "tcp", "FromPort": 22, "ToPort": 22, "IpRanges": [{ "CidrIp": "<MY-IP-REDACTED>/32" }] }
]
```

---

## Part 7 — Verify EC2 Identity and Secret Access (From Inside the Instance)

### Confirm EC2 is Assuming the Correct Role

```bash
aws sts get-caller-identity
```

**Output (redacted):**

```json
{
  "UserId": "REDACTED:i-REDACTED",
  "Account": "REDACTED",
  "Arn": "arn:aws:sts::REDACTED:assumed-role/lab-ec2-role01/i-REDACTED"
}
```

**What to confirm:** The `Arn` shows `assumed-role/lab-ec2-role01` — proving the instance profile is attached and the role is active.

---

### Confirm the Instance Can Read the Secret

```bash
aws secretsmanager describe-secret \
  --secret-id lab/rds/mysql \
  --region us-east-1
```

**Output (redacted):**

```json
{
  "ARN": "arn:aws:secretsmanager:us-east-1:REDACTED:secret:lab/rds/mysql-XXXXX",
  "Name": "lab/rds/mysql",
  "LastAccessedDate": "2026-03-19T..."
}
```

**If this succeeds:** IAM role is correctly attached and permissions are effective. ✅

---

## Student Deliverables

### 1. Screenshots Required

- RDS security group inbound rule showing source = `lab-ec2-sg01`
![](/attachments/security-group.png)
- EC2 instance with IAM role attached
![](/attachments/instance-role-attached.png)
- `/list` endpoint output showing at least 3 notes
![](/attachments/olidip.png)
![](/attachments/newip.png)

Find in deliverables.md

---

### 2. Short Answer Questions

**A) Why is DB inbound source restricted to the EC2 security group?**

So that only EC2 instances assigned to `lab-ec2-sg01` can reach the database on port 3306 — not the internet, not other VPC resources, just the application tier. Think of it like a restaurant kitchen: only the waitstaff (EC2) can enter, not the customers (the internet).

**B) What port does MySQL use?**

`3306`

**C) Why is Secrets Manager better than storing credentials in code or user data?**

User data is visible in the AWS console to anyone with EC2 read access. Code checked into a Git repository exposes credentials to anyone with repo access. Secrets Manager encrypts the value at rest, controls access through IAM policies, and supports automatic rotation — meaning the password can change without touching your code.

---

### 3. Audit Evidence — Recommended Commands

Run these and save the outputs for evidence:

```bash
aws ec2 describe-security-groups --group-ids <sg-ec2-id> > sg.json
aws rds describe-db-instances --db-instance-identifier lab-rds01 > rds.json
aws secretsmanager describe-secret --secret-id lab/rds/mysql > secret.json
aws ec2 describe-instances --instance-ids <instance-id> > instance.json
aws iam list-attached-role-policies --role-name lab-ec2-role01 > role-policies.json
```

---

### 4. Audit Analysis

**Why does each rule exist?**

- **Inbound TCP 80 from `0.0.0.0/0`:** Allows any browser on the internet to reach the Flask web application over HTTP.
- **Inbound TCP 22 from my IP only:** Restricts SSH shell access exclusively to my workstation, preventing unauthorized remote access.

**What would break if each rule were removed?**

- Removing the database secret from Secrets Manager would break the application's ability to authenticate to RDS — the Flask app would fail to connect.
- Removing the EC2 security group's access to the RDS security group on port 3306 would sever the network path between the app and the database.
- Removing inbound TCP 80 from `0.0.0.0/0` would make the web application unreachable from any browser.

**Why is broader access forbidden?**

Broader access increases the attack surface. Any port or IP range beyond what is strictly required gives a bad actor an additional path into the system. The principle of least access means we only open what the application actually needs.

**Why does this IAM role exist?**

This role gives the EC2 instance an AWS identity so it can securely call Secrets Manager without needing hardcoded credentials anywhere. Without it, the instance has no way to authenticate to AWS APIs — it would be like trying to enter a secure building with no badge at all.

**Why can it read this secret?**

The `SecretsManagerReadWrite` managed policy is attached to the role, which grants `secretsmanager:GetSecretValue` (among other permissions). AWS evaluates the request, finds a matching Allow statement, and permits the call.

**Why can it not read others (intended end state)?**

Once the broad managed policy is replaced with an inline policy scoped to the ARN of `lab/rds/mysql` specifically, least privilege enforcement will prevent the role from accessing any other secret in the account. The current `SecretsManagerReadWrite` policy is a temporary lab shortcut and will be tightened before this pattern is used in production.

---
