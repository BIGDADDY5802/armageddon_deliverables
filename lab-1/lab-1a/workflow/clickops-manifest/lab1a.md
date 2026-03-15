EC2 Web App → RDS (MySQL) “Notes” App
Goal

Deploy a simple web app on an EC2 instance that can:
  Insert a note into RDS MySQL
  List notes from the database
  VPC: armageddon-demo
  VPC CIDR: 10.180.0.0/16

Subnet CIDRs: public - 10.180.1.0/24, 10.180.2.0/24 
              private - 10.180.11.0/24, 10.180.12.0/24

Requirements
  RDS MySQL instance in a private subnet (or publicly accessible if you want ultra-simple)
  EC2 instance running a Python Flask app
  Security groups allowing EC2 → RDS on port 3306
  Credentials stored in AWS Secrets Manager (recommended) or plain env vars (simpler)

Part 1 — Create RDS MySQL
  Option A (recommended, still simple): RDS private + EC2 public
    RDS Console → Create database
    Engine: MySQL
    Template: Free tier (or Dev/Test)
    DB instance identifier: lab-mysql
    Master username: admin
    Password: DawgsPwd123
    Connectivity
    VPC: default (or class VPC)
    Public access: No
    VPC security group: create new sg-rds-lab
    Create DB

AWS CLI:

List all security groups in a region

    aws ec2 describe-security-groups \
      --region us-east-1 \
      --query "SecurityGroups[].{GroupId:GroupId,Name:GroupName,VpcId:VpcId}" \
      --output table

Inspect a specific security group (inbound & outbound rules)

    aws ec2 describe-security-groups \
      --group-ids sg-0123456789abcdef0 \
      --region us-east-1 \
      --output json

Verify which resources are using the security group
EC2 instances

    aws ec2 describe-instances \
      --filters Name=instance.group-id,Values=sg-0123456789abcdef0 \
      --region us-east-1 \
      --query "Reservations[].Instances[].InstanceId" \
      --output table

RDS instances

    aws rds describe-db-instances \
      --region us-east-1 \
      --query "DBInstances[?contains(VpcSecurityGroups[].VpcSecurityGroupId, 'sg-0123456789abcdef0')].DBInstanceIdentifier" \
      --output table

List all RDS instances

    aws rds describe-db-instances \
      --region us-east-1 \
      --query "DBInstances[].{DB:DBInstanceIdentifier,Engine:Engine,Public:PubliclyAccessible,Vpc:DBSubnetGroup.VpcId}" \
      --output table

Inspect a specific RDS instance

    aws rds describe-db-instances \
      --db-instance-identifier mydb01 \
      --region us-east-1 \
      --output json

Critical checks
    "PubliclyAccessible": false
    Correct VPC
    Correct subnet group
    Correct security groups

Verify RDS security groups explicitly

    aws rds describe-db-instances \
      --db-instance-identifier mydb01 \
      --region us-east-1 \
      --query "DBInstances[].VpcSecurityGroups[].VpcSecurityGroupId" \
      --output table

Verify RDS subnet placement

    aws rds describe-db-subnet-groups \
      --region us-east-1 \
      --query "DBSubnetGroups[].{Name:DBSubnetGroupName,Vpc:VpcId,Subnets:Subnets[].SubnetIdentifier}" \
      --output table

What you’re verifying
    Private subnets only
    No IGW route
    Correct AZ spread

Verify Network Exposure (Fast Sanity Checks)
Check if RDS is publicly reachable (quick flag)

    aws rds describe-db-instances \
      --db-instance-identifier mydb01 \
      --region us-east-1 \
      --query "DBInstances[].PubliclyAccessible" \
      --output text

Expected output: false






Security group for RDS (sg-rds-lab): This is the key “real-world” security pattern: allow DB access only from the app server’s SG.
  Inbound
    MySQL/Aurora (TCP 3306) Source = sg-ec2-lab (we’ll create that next)
Outbound
    default allow-all is fine: Don't touch this or Chewbacca will touch you.

Part 2 — Launch EC2
  1) EC2 Console → Launch instance
  2) Name: lab-ec2-app
  3) AMI: Amazon Linux 2023
  4) Instance type: t3.micro (or t2.micro)
  5) Key pair: choose/create (only if you want SSH access)
  6) Network: same VPC as RDS
  7) Security group: create sg-ec2-lab

Security group for EC2 (sg-ec2-lab)
  Inbound
    HTTP TCP 80 from 0.0.0.0/0 (so they can test in browser)
    (Optional) SSH TCP 22 from your IP only

  Outbound
    allow-all (default)

Now go back to RDS SG inbound rule
Set Source = sg-ec2-lab for TCP 3306.

Part 3 — Store DB creds (Secrets Manager)
  1) Secrets Manager → Store a new secret
  2) Secret type: Credentials for RDS database
  3) Username/password: admin + your password
  4) Select your RDS instance lab-mysql
  5) Secret name: lab/rds/mysql

Verify Secrets Manager (Existence, Metadata, Access)

    aws secretsmanager list-secrets \
      --region us-east-1 \
      --query "SecretList[].{Name:Name,ARN:ARN,Rotation:RotationEnabled}" \
      --output table

What you’re verifying
    Secret exists
    Rotation state is known
    Naming is intentional

Describe a specific secret (NO value exposure)

    aws secretsmanager describe-secret \
      --secret-id deez-db-secret-nuts \
      --region us-east-1 \
      --output json

Key fields to check
    RotationEnabled
    KmsKeyId
    LastChangedDate
    LastAccessedDate

This command is always safe. It does not expose the secret value.

Create an IAM Role for EC2 to read the secret
  1) IAM → Roles → Create role
  2) Trusted entity: EC2
  3) Add permission policy (tightest good enough for lab):
      SecretsManagerReadWrite is too broad (but easy).
      Better: create a small inline policy like below.

Inline policy (recommended)
Replace <REGION>, <ACCOUNT_ID>, and secret name if different:
#Check inline_policy.json in this folder 

  4) Attach role to EC2:
      EC2 → Instance → Actions → Security → Modify IAM role → select your role

Verify which IAM principals can access the secret

    aws secretsmanager get-resource-policy \
      --secret-id my-db-secret \
      --region us-east-1 \
      --output json

What you’re verifying
    Only expected roles are listed
    No wildcard principals
    No cross-account access unless justified

Verify IAM Role Attached to an EC2 Instance
  Step 1: Identify the EC2 instance

    aws ec2 describe-instances \
      --filters Name=tag:Name,Values=MyInstance \
      --region us-east-1 \
      --query "Reservations[].Instances[].InstanceId" \
      --output text

  Step 2: Check the IAM role attached to the instance

    aws ec2 describe-instances \
      --instance-ids i-0123456789abcdef0 \
      --region us-east-1 \
      --query "Reservations[].Instances[].IamInstanceProfile.Arn" \
      --output text

Expected: arn:aws:iam::123456789012:instance-profile/MyEC2Role

If empty → no role attached (this is a finding).

  Step 3: Resolve instance profile → role name

    aws iam get-instance-profile \
      --instance-profile-name MyEC2Role \
      --query "InstanceProfile.Roles[].RoleName" \
      --output text


Verify IAM Role Permissions (Critical)
List policies attached to the role

    aws iam list-attached-role-policies \
      --role-name MyEC2Role \
      --output table

List inline policies (often forgotten)

    aws iam list-role-policies \
      --role-name MyEC2Role \
      --output table

Inspect a specific managed policy

    aws iam get-policy-version \
      --policy-arn arn:aws:iam::aws:policy/SecretsManagerReadWrite \
      --version-id v1 \
      --output json

What you’re verifying
    Least privilege
    Only secretsmanager:GetSecretValue if read-only
    No wildcard * unless justified
    
Part 4 — Bootstrap the EC2 app (User Data)
In EC2 launch, you can paste this in User data (or run manually after SSH).
Important: Replace SECRET_ID if you used a different name.
#user.data.sh

Part 5 — Test
  1) In RDS console, copy the endpoint (you won’t paste it into app because Secrets Manager provides host)
  2) Open browser:
      http://<EC2_PUBLIC_IP>/init
      http://<EC2_PUBLIC_IP>/add?note=first_note
      http://<EC2_PUBLIC_IP>/list
  If /init hangs or errors, it’s almost always:
    RDS SG inbound not allowing from EC2 SG on 3306
    RDS not in same VPC/subnets routing-wise
    EC2 role missing secretsmanager:GetSecretValue
    Secret doesn’t contain host / username / password fields (fix by storing as “Credentials for RDS database”)

Verify EC2 → RDS access path (security-group–to–security-group)

    aws ec2 describe-security-groups \
      --group-ids sg-ec2-access \
      --region us-east-1 \
      --query "SecurityGroups[].IpPermissions"

Verify That EC2 Can Actually Read the Secret (From the Instance)
From inside the EC2 instance:

    aws sts get-caller-identity

Expected:Arn: arn:aws:sts::123456789012:assumed-role/MyEC2Role/i-0123456789abcdef0

Then test access:

    aws secretsmanager describe-secret \
      --secret-id my-db-secret \
      --region us-east-1

If this works:
    IAM role is correctly attached
    Permissions are effective

Student Deliverables:
1) Screenshot of:
  RDS SG inbound rule using source = sg-ec2-lab
  EC2 role attached
  /list output showing at least 3 notes

2) Short answers:
  A) Why is DB inbound source restricted to the EC2 security group?
  B) What port does MySQL use?
  C) Why is Secrets Manager better than storing creds in code/user-data?

3) Evidence for Audits / Labs (Recommended Output)

      aws ec2 describe-security-groups --group-ids sg-0123456789abcdef0 > sg.json
      aws rds describe-db-instances --db-instance-identifier mydb01 > rds.json
      aws secretsmanager describe-secret --secret-id my-db-secret > secret.json
      aws ec2 describe-instances --instance-ids i-0123456789abcdef0 > instance.json
      aws iam list-attached-role-policies --role-name MyEC2Role > role-policies.json


    Why each rule exists:
    
    What would break if removed
    Why broader access is forbidden
    Why this role exists
    Why it can read this secret
    Why it cannot read others


