1c_bonusE2.13.26.md

app_url_http = "http://app.thedawgs2025.click"
app_url_https = "https://app.thedawgs2025.click"
app_urls = {
  "alb_direct" = "http://lab-alb01-325759532.us-east-1.elb.amazonaws.com"
  "http" = "http://app.thedawgs2025.click"
  "https" = "https://app.thedawgs2025.click"
}
base_domain = "thedawgs2025.click"
dawgs-armageddon_acm_cert_arn = "arn:aws:acm:us-east-1:778185677715:certificate/727bc9d8-35a5-41bd-bb52-1b8605e99ad3"
dawgs-armageddon_alb_dns_name = "lab-alb01-325759532.us-east-1.elb.amazonaws.com"
dawgs-armageddon_apex_url_https = "https://thedawgs2025.click"
dawgs-armageddon_dashboard_name = "lab-dashboard01"
dawgs-armageddon_ec2_instance_id = "i-03f8aa7ae0a37bc16"
dawgs-armageddon_ec2_private_instance_id = "i-06a66f2e0e8868de8"
dawgs-armageddon_log_group_name = "/aws/ec2/lab-rds-app"
dawgs-armageddon_private_subnet_ids = [
  "subnet-0778dff64624beb4a",
  "subnet-0df22a9a59b82f3f3",
]
dawgs-armageddon_public_subnet_ids = [
  "subnet-06ae68699de3f2a02",
  "subnet-0ade3ec8828e03048",
]
dawgs-armageddon_rds_endpoint = "lab-rds01.c89ykq22i31z.us-east-1.rds.amazonaws.com"
dawgs-armageddon_sns_topic_arn = "arn:aws:sns:us-east-1:778185677715:lab-db-incidents"
dawgs-armageddon_target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:778185677715:targetgroup/lab-tg01/66146301737b56d1"
dawgs-armageddon_vpc_id = "vpc-03b7e7f9bc751e809"
dawgs-armageddon_waf_arn = "arn:aws:wafv2:us-east-1:778185677715:regional/webacl/lab-waf01/e9bd2007-feb9-4d5c-9ba7-e64eb8f458c9"
dawgs-armageddon_waf_log_destination = "cloudwatch"
lb_url = "http://lab-alb01-325759532.us-east-1.elb.amazonaws.com"

Command to check ec2 role:

aws ec2 describe-instances --instance-ids i-xxxxx \
  --query 'Reservations[0].Instances[0].IamInstanceProfile' \
  --output table

aws ec2 describe-instances --instance-ids i-06a66f2e0e8868de8 \
  --query 'Reservations[0].Instances[0].IamInstanceProfile' \
  --output table

------------------------------------------------------------------------------
|                              DescribeInstances                             |
+-----+----------------------------------------------------------------------+
|  Arn|  arn:aws:iam::778185677715:instance-profile/lab-instance-profile01   |
|  Id |  AIPA3KL33DOJ3YWKGD5IH                                               |
+-----+----------------------------------------------------------------------+

aws iam get-instance-profile --instance-profile-name lab-instance-profile01

{
    "InstanceProfile": {
        "Path": "/",
        "InstanceProfileName": "lab-instance-profile01",
        "InstanceProfileId": "AIPA3KL33DOJ3YWKGD5IH",
        "Arn": "arn:aws:iam::778185677715:instance-profile/lab-instance-profile01",
        "CreateDate": "2026-02-14T03:55:07+00:00",
        "Roles": [
            {
                "Path": "/",
                "RoleName": "lab-ec2-role01",
                "RoleId": "AROA3KL33DOJSX3NQFCI7",
                "Arn": "arn:aws:iam::778185677715:role/lab-ec2-role01",
                "CreateDate": "2026-02-14T03:55:06+00:00",
                "AssumeRolePolicyDocument": {
                    "Version": "2012-10-17",
                    "Statement": [
                        {
                            "Effect": "Allow",
                            "Principal": {
                                "Service": "ec2.amazonaws.com"
                            },
                            "Action": "sts:AssumeRole"
                        }
                    ]
                }
            }
        ],
        "Tags": []
    }
}


 aws iam list-attached-role-policies --role-name lab-ec2-role01

{
    "AttachedPolicies": [
        {
            "PolicyName": "lab-lp-ssm-read01",
            "PolicyArn": "arn:aws:iam::778185677715:policy/lab-lp-ssm-read01"
        },
        {
            "PolicyName": "lab-lp-secrets-read01",
            "PolicyArn": "arn:aws:iam::778185677715:policy/lab-lp-secrets-read01"
        },
        {
            "PolicyName": "lab-lp-cwlogs01",
            "PolicyArn": "arn:aws:iam::778185677715:policy/lab-lp-cwlogs01"
        },
        {
            "PolicyName": "CloudWatchAgentServerPolicy",
            "PolicyArn": "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
        },
        {
            "PolicyName": "AmazonSSMManagedInstanceCore",
            "PolicyArn": "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
        },
        {
            "PolicyName": "SecretsManagerReadWrite",
            "PolicyArn": "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
        }
    ]
}



Check Instance security groups:

aws ec2 describe-instances --instance-ids i-xxxxx \
  --query 'Reservations.Instances.SecurityGroups' --output table

aws ec2 describe-instances --instance-ids i-06a66f2e0e8868de8 \
  --query 'Reservations.Instances.SecurityGroups' --output table

------------------------------------------
|            DescribeInstances           |
+-----------------------+----------------+
|        GroupId        |   GroupName    |
+-----------------------+----------------+
|  sg-07a776ab08da11ad0 |  lab-ec2-sg01  |
+-----------------------+----------------+



REGION="${REGION:-us-east-1}"
INSTANCE_ID="${INSTANCE_ID:- i-06a66f2e0e8868de8}"
./run_all_gates.sh


=== Running Gate 1/2: secrets_and_role ===

=== SEIR Gate: Secrets + EC2 Role Verification ===
Timestamp (UTC): 2026-02-14T04:32:31Z
Region:          us-east-1
Instance ID:     i-06a66f2e0e8868de8
Secret ID:       lab/rds/mysql
Resolved Role:   lab-ec2-role01
Caller ARN:      arn:aws:iam::778185677715:user/awscli
-----------------------------------------------
PASS: aws sts get-caller-identity succeeded (credentials OK).
PASS: secret exists and is describable (lab/rds/mysql).
INFO: rotation requirement disabled (REQUIRE_ROTATION=false).
PASS: no resource policy found (OK) or not applicable (lab/rds/mysql).
PASS: instance has IAM instance profile attached (i-06a66f2e0e8868de8).
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
Timestamp (UTC): 2026-02-14T04:32:55Z
Region:          us-east-1
EC2 Instance:    i-06a66f2e0e8868de8
RDS Instance:    lab-rds01
Engine:          mysql
DB Port:         3306
Caller ARN:      arn:aws:iam::778185677715:user/awscli
-------------------------------------------
PASS: aws sts get-caller-identity succeeded (credentials OK).
PASS: RDS instance exists (lab-rds01).
PASS: RDS is not publicly accessible (PubliclyAccessible=False).
INFO: using DB_PORT override = 3306.
PASS: EC2 security groups resolved (i-06a66f2e0e8868de8): sg-07a776ab08da11ad0
PASS: RDS security groups resolved (lab-rds01): sg-0b393f603d0522963
PASS: RDS SG allows DB port 3306 from EC2 SG (SG-to-SG ingress present).
INFO: private subnet check disabled (CHECK_PRIVATE_SUBNETS=false).

RESULT: PASS
===========================================

Wrote: gate_result.json


Troubleshooting:

Found that gate result file was causing a caching issue with run_all_gates.sh

$rm -f gate_result.json

Had not noticed that it was using old output from last passing run because of the old pass. Had to erase old gate_result.json to get script to read correctly.

WAF running...

Logging had succeeded on last run. 

SIEM:
SIEM stands for Security Information and Event Management.

Core Functions:

Collects logs from AWS services (CloudTrail, CloudWatch, VPC Flow Logs, GuardDuty)

Correlates events across your EC2, RDS, IAM, and network activity

Detects anomalies like failed secret access, unauthorized RDS connections

Provides alerts and compliance reports (SOC2, PCI-DSS)

Popular AWS SIEM Options:

Splunk - Heavy hitter, great AWS add-on

Elastic - Open source, CloudWatch integration

Sumo Logic - Cloud-native

AWS Native: CloudWatch + GuardDuty + Security Hub
