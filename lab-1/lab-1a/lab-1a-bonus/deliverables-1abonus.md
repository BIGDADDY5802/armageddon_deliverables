#lab-1a-bonus


 Student verification (CLI) for Bonus-A
1) Prove EC2 is private (no public IP)
  aws ec2 describe-instances \
  --instance-ids i-0a5a47e21d83fbba4     i-0ab3c387c8e016f17 \
  --query "Reservations[].Instances[].PublicIpAddress"

Expected: 
  null

2) Prove VPC endpoints exist
  aws ec2 describe-vpc-endpoints \
  --filters "Name=vpc-id,Values=vpc-0f829b41ccc1a91f0" \
  --query "VpcEndpoints[].ServiceName"

Output:

[
    "com.amazonaws.us-east-1.s3",
    "com.amazonaws.us-east-1.kms",
    "com.amazonaws.us-east-1.ssmmessages",
    "com.amazonaws.us-east-1.ssm",
    "com.amazonaws.us-east-1.secretsmanager",
    "com.amazonaws.us-east-1.ec2messages",
    "com.amazonaws.us-east-1.logs"
]


Expected: list includes:
  ssm 
  ec2messages 
  ssmmessages 
  logs 
  secretsmanager
  s3

3) Prove Session Manager path works (no SSH)
  aws ssm describe-instance-information \
  --query "InstanceInformationList[].InstanceId"

Output:

[
    "i-0ab3c387c8e016f17",
    "i-0a5a47e21d83fbba4"
]


Expected: your private EC2 instance ID appears

4) Prove the instance can read both config stores
Run from SSM session:
  aws ssm get-parameter --name /lab/db/endpoint

Output:
{
    "Parameter": {
        "Name": "/lab/db/endpoint",
        "Type": "String",
        "Value": "lab-rds01.c89ykq22i31z.us-east-1.rds.amazonaws.com",
        "Version": 1,
        "LastModifiedDate": "2026-02-07T19:44:23.176000+00:00",
        "ARN": "arn:aws:ssm:us-east-1:778185677715:parameter/lab/db/endpoint",
        "DataType": "text"
    }
}


  aws secretsmanager get-secret-value --secret-id lab/rds/mysql

Output:



5) Prove CloudWatch logs delivery path is available via endpoint
  aws logs describe-log-streams \
    --log-group-name /aws/ec2/lab-rds-app

How this maps to “real company” practice (short, employer-credible)
  Private compute + SSM is standard in regulated orgs and mature cloud shops.
  VPC endpoints reduce exposure and dependency on NAT for AWS APIs.
  Least privilege is not optional in security interviews.
  Terraform submission mirrors how teams ship changes: PR → plan → review → apply → monitor.


aws ec2 describe-instances \
  --query 'Reservations[].Instances[].InstanceId' \
  --output text

Output:

i-0a5a47e21d83fbba4     i-0ab3c387c8e016f17


aws ec2 describe-vpcs \
  --query 'Vpcs[].VpcId' \
  --output text

Outputs:

vpc-035440d5ab0a4ab71   vpc-0f829b41ccc1a91f0


aws ec2 describe-vpcs \
  --vpc-ids vpc-035440d5ab0a4ab71 \
  --query 'Vpcs[0].Tags[?Key==`Name`].Value|[0]' \
  --output text

Output:

DONOTTOUCH

aws ec2 describe-vpcs \
  --vpc-ids vpc-0f829b41ccc1a91f0 \
  --query 'Vpcs[0].Tags[?Key==`Name`].Value|[0]' \
  --output text

Output:

lab-vpc01

aws ec2 describe-vpcs \
  --query 'Vpcs[*].{VpcId:VpcId,Name:Tags[?Key==`Name`].Value|[0]}' \
  --output table

Output:

-----------------------------------------
|             DescribeVpcs              |
+-------------+-------------------------+
|    Name     |          VpcId          |
+-------------+-------------------------+
|  DONOTTOUCH |  vpc-035440d5ab0a4ab71  |
|  lab-vpc01  |  vpc-0f829b41ccc1a91f0  |
+-------------+-------------------------+


aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=lab-vpc01" \
  --query 'Vpcs[0].VpcId' \
  --output text

Output:

vpc-0f829b41ccc1a91f0

aws secretsmanager list-secrets \
  --query 'SecretList[].Name' \
  --output text

Output:

lab/rds/MySQL

MSYS_NO_PATHCONV=1 aws logs describe-log-streams \
  --log-group-name '/aws/ec2/lab-rds-app'

Output:

{
    "logStreams": []
}


 aws ec2 describe-instances \
  --query 'Reservations[*].Instances[*].InstanceId' \
  --output text

Output:

i-0a5a47e21d83fbba4
i-0ab3c387c8e016f17

aws ec2 describe-instances \
  --query 'Reservations[*].Instances[].[InstanceId,Tags[?Key==`Name`]| [0].Value]' \
  --output table

Output:

----------------------------------------------
|              DescribeInstances             |
+----------------------+---------------------+
|  i-0a5a47e21d83fbba4 |  lab-ec201          |
|  i-0ab3c387c8e016f17 |  lab-ec201-private  |
+----------------------+---------------------+





# Check if instance shows as "Managed" in SSM
aws ssm describe-instance-information --filters Key=InstanceIds,Values=i-0ab3c387c8e016f17

Output:

{
    "InstanceInformationList": [
        {
            "InstanceId": "i-0ab3c387c8e016f17",
            "PingStatus": "Online",
            "LastPingDateTime": "2026-02-07T18:09:13.890000-06:00",
            "AgentVersion": "3.3.3572.0",
            "IsLatestVersion": false,
            "PlatformType": "Linux",
            "PlatformName": "Amazon Linux",
            "PlatformVersion": "2023",
            "ResourceType": "EC2Instance",
            "IPAddress": "10.190.101.34",
            "ComputerName": "ip-10-190-101-34.ec2.internal",
            "SourceId": "i-0ab3c387c8e016f17",
            "SourceType": "AWS::EC2::Instance"
        }
    ]
}

 curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/windows/SessionManagerPluginSetup.exe" -o "SessionManagerPluginSetup.exe"

Output:  

% Total    % Received % Xferd  Average Speed  Time    Time    Time   Current
                                 Dload  Upload  Total   Spent   Left   Speed
100  8.47M 100  8.47M   0      0  6.01M      0   00:01   00:01         163.0k


session-manager-plugin --version

Output:

1.2.764.0


aws ssm start-session --target i-0ab3c387c8e016f17

Output:

Starting session with SessionId: awscli-dzv4of28oq8k39utz4h658devq
sh-5.2$  sudo yum upgrade -y

Amazon Linux 2023 Kernel Livepatch repository   216 kB/s |  31 kB     00:00
================================================================================
WARNING:
  A newer release of "Amazon Linux" is available.

  Available Versions:

  Version 2023.10.20260120:
    Run the following command to upgrade to 2023.10.20260120:

      dnf upgrade --releasever=2023.10.20260120

    Release notes:
     https://docs.aws.amazon.com/linux/al2023/release-notes/relnotes-2023.10.20260120.html

  Version 2023.10.20260202:
    Run the following command to upgrade to 2023.10.20260202:

      dnf upgrade --releasever=2023.10.20260202

    Release notes:
     https://docs.aws.amazon.com/linux/al2023/release-notes/relnotes-2023.10.20260202.html

================================================================================
Dependencies resolved.
Nothing to do.
Complete!


 aws logs describe-log-streams \
 >     --log-group-name /aws/ec2/lab-rds-app

Output:

{
    "logStreams": []
}



REGION="${REGION:-us-east-1}"
INSTANCE_ID="${INSTANCE_ID:-i-0d175e39303b3ff70}"
SECRET_ID="${SECRET_ID:-lab/rds/mysql}"
DB_ID="${DB_ID:-lab-rds01}"

REGION="${REGION:-us-east-1}"
INSTANCE_ID="${INSTANCE_ID:-}"
SECRET_ID="${SECRET_ID:-}"
OUT_JSON="${OUT_JSON:-gate_result.json}"


=== SEIR Gate: Secrets + EC2 Role Verification ===
Timestamp (UTC): 2026-02-08T02:49:22Z
Region:          us-east-1
Instance ID:     i-0d175e39303b3ff70
Secret ID:       lab/rds/mysql
Resolved Role:   lab-ec2-role01
Caller ARN:      arn:aws:iam::778185677715:user/awscli
-----------------------------------------------
PASS: aws sts get-caller-identity succeeded (credentials OK).
PASS: secret exists and is describable (lab/rds/mysql).
INFO: rotation requirement disabled (REQUIRE_ROTATION=false).
PASS: no resource policy found (OK) or not applicable (lab/rds/mysql).
PASS: instance has IAM instance profile attached (i-0d175e39303b3ff70).
PASS: resolved instance profile -> role (lab-instance-profile01 -> lab-ec2-role01).
INFO: EXPECTED_ROLE_NAME not set; using resolved role (lab-ec2-role01).
INFO: on-instance checks skipped (not running as expected role on EC2).

Warnings:
  - WARN: current caller ARN is not assumed-role/lab-ec2-role01 (you may be running off-instance).

RESULT: PASS
===============================================

Wrote: gate_result.json



=== SEIR Gate: Network + RDS Verification ===
Timestamp (UTC): 2026-02-08T02:57:47Z
Region:          us-east-1
EC2 Instance:    i-0d175e39303b3ff70
RDS Instance:    lab-rds01
Engine:          mysql
DB Port:         3306
Caller ARN:      arn:aws:iam::778185677715:user/awscli
-------------------------------------------
PASS: aws sts get-caller-identity succeeded (credentials OK).
PASS: RDS instance exists (lab-rds01).
PASS: RDS is not publicly accessible (PubliclyAccessible=False).
INFO: using DB_PORT override = 3306.
PASS: EC2 security groups resolved (i-0d175e39303b3ff70): sg-03002451ecf88f98e
PASS: RDS security groups resolved (lab-rds01): sg-02683c315b30abaa3
PASS: RDS SG allows DB port 3306 from EC2 SG (SG-to-SG ingress present).
INFO: DB subnet group (lab-rds-subnet-group01) subnets: subnet-074fe2ac94aa83b6f        subnet-0d5d9021b712b422a
PASS: subnet subnet-074fe2ac94aa83b6f shows no IGW route (private check OK).
PASS: subnet subnet-0d5d9021b712b422a shows no IGW route (private check OK).

RESULT: PASS
===========================================

Wrote: gate_2_result.json

=== Running Gate 1/2: secrets_and_role ===

=== SEIR Gate: Secrets + EC2 Role Verification ===
Timestamp (UTC): 2026-02-08T03:02:16Z
Region:          us-east-1
Instance ID:     i-0d175e39303b3ff70
Secret ID:       lab/rds/mysql
Resolved Role:   lab-ec2-role01
Caller ARN:      arn:aws:iam::778185677715:user/awscli
-----------------------------------------------
PASS: aws sts get-caller-identity succeeded (credentials OK).
PASS: secret exists and is describable (lab/rds/mysql).
INFO: rotation requirement disabled (REQUIRE_ROTATION=false).
PASS: no resource policy found (OK) or not applicable (lab/rds/mysql).
PASS: instance has IAM instance profile attached (i-0d175e39303b3ff70).
PASS: resolved instance profile -> role (lab-instance-profile01 -> lab-ec2-role01).
INFO: EXPECTED_ROLE_NAME not set; using resolved role (lab-ec2-role01).
INFO: on-instance checks skipped (not running as expected role on EC2).

Warnings:
  - WARN: current caller ARN is not assumed-role/lab-ec2-role01 (you may be running off-instance).

RESULT: PASS
===============================================

Wrote: gate_result.json
=== Running Gate 2/2: network_db ===

=== SEIR Gate: Network + RDS Verification ===
Timestamp (UTC): 2026-02-08T03:02:44Z
Region:          us-east-1
EC2 Instance:    i-0d175e39303b3ff70
RDS Instance:    lab-rds01
Engine:          mysql
DB Port:         3306
Caller ARN:      arn:aws:iam::778185677715:user/awscli
-------------------------------------------
PASS: aws sts get-caller-identity succeeded (credentials OK).
PASS: RDS instance exists (lab-rds01).
PASS: RDS is not publicly accessible (PubliclyAccessible=False).
INFO: using DB_PORT override = 3306.
PASS: EC2 security groups resolved (i-0d175e39303b3ff70): sg-03002451ecf88f98e
PASS: RDS security groups resolved (lab-rds01): sg-02683c315b30abaa3
PASS: RDS SG allows DB port 3306 from EC2 SG (SG-to-SG ingress present).
INFO: private subnet check disabled (CHECK_PRIVATE_SUBNETS=false).

RESULT: PASS
===========================================

