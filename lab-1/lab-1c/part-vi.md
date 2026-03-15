Students must submit:
    
Recieved an email at 4:27pm stating there was an alarm on DB.

Alarm Details:
- Name:                       lab-db-connection-failure
- Description:               
- State Change:               OK -> ALARM
- Reason for State Change:    Threshold Crossed: 1 datapoint [5.0 (26/01/26 22:22:00)] was greater than or equal to the threshold (3.0).
- Timestamp:                  Monday 26 January, 2026 22:27:25 UTC
- AWS Account:                778185677715
- Alarm Arn:                  arn:aws:cloudwatch:us-east-1:778185677715:alarm:lab-db-connection-failure

Threshold:
- The alarm is in the ALARM state when the metric is GreaterThanOrEqualToThreshold 3.0 for at least 1 of the last 1 period(s) of 300 seconds.

Monitored Metric:
- MetricNamespace:                     Lab/RDSApp
- MetricName:                          DBConnectionErrors
- Dimensions:                         
- Period:                              300 seconds
- Statistic:                           Sum
- Unit:                                not specified
- TreatMissingData:                    notBreaching


PART IV — Mandatory Incident Runbook
Students must follow this order. Deviations lose points.

  aws cloudwatch describe-alarms \
  --alarm-names lab-db-connection-failure \
  --query "MetricAlarms[].StateValue"

Expected:
  ALARM

  output:
  [
    "ALARM"
]
SNS sent email

############

aws logs filter-log-events \
      --log-group-name /aws/ec2/lab-rds-app \
      --filter-pattern "ERROR"

Expected:
  Clear DB connection failure messages

  {
    "events": [
        {
            "logStreamName": "app-stream",
            "timestamp": 1769463993596,
            "message": "DB_CONNECTION_FAILURE: (1146, \"Table 'labdb.notes' doesn't exist\")",
            "ingestionTime": 1769464053664,
            "eventId": "39460365659158818297263398380553646282928003050689265664"
        },
        {
            "logStreamName": "app-stream",
            "timestamp": 1769466339497,
            "message": "DB_CONNECTION_FAILURE: (2003, \"Can't connect to MySQL server on 'lab-rds01.c89ykq22i31z.us-east-1.rds.amazonaws.com' (timed out)\")",
            "ingestionTime": 1769466393808,
            "eventId": "39460417974499280275450759561397227138364628294044614656"
        },
        {
            "logStreamName": "app-stream",
            "timestamp": 1769466353475,
            "message": "DB_CONNECTION_FAILURE: (2003, \"Can't connect to MySQL server on 'lab-rds01.c89ykq22i31z.us-east-1.rds.amazonaws.com' (timed out)\")",
            "ingestionTime": 1769466393808,
            "eventId": "39460418286219096660511809833783497153443425424638869505"
        },

#####

aws ssm get-parameters \
        --names /lab/db/endpoint /lab/db/port /lab/db/name \
        --with-decryption

Expected:
  Endpoint + port returned

  {
    "Parameters": [
        {
            "Name": "/lab/db/endpoint",
            "Type": "String",
            "Value": "lab-rds01.c89ykq22i31z.us-east-1.rds.amazonaws.com",
            "Version": 1,
            "LastModifiedDate": "2026-01-26T14:59:23.882000-06:00",
            "ARN": "arn:aws:ssm:us-east-1:778185677715:parameter/lab/db/endpoint",
            "DataType": "text"
        },
        {
            "Name": "/lab/db/name",
            "Type": "String",
            "Value": "labdb",
            "Version": 1,
            "LastModifiedDate": "2026-01-26T14:53:58.440000-06:00",
            "ARN": "arn:aws:ssm:us-east-1:778185677715:parameter/lab/db/name",
            "DataType": "text"
        },
        {
            "Name": "/lab/db/port",
            "Type": "String",
            "Value": "3306",
            "Version": 1,
            "LastModifiedDate": "2026-01-26T14:59:23.887000-06:00",
            "ARN": "arn:aws:ssm:us-east-1:778185677715:parameter/lab/db/port",
            "DataType": "text"
        }
    ],
    "InvalidParameters": []
}

aws secretsmanager get-secret-value \
      --secret-id lab/rds/mysql

Expected:
  Username/password visible
  Compare against known-good state

  {
    "ARN": "arn:aws:secretsmanager:us-east-1:778185677715:secret:lab/rds/mysql-e1U2tM",
    "Name": "lab/rds/mysql",
    "VersionId": "terraform-20260126205922543100000006",
    "SecretString": "{\"dbname\":\"labdb\",\"host\":\"lab-rds01.c89ykq22i31z.us-east-1.rds.amazonaws.com\",\"password\":\"DawgsRDSPass123\",\"port\":3306,\"username\":\"admin\"}",
    "VersionStages": [
        "AWSCURRENT"
    ],
    "CreatedDate": "2026-01-26T14:59:23.889000-06:00"
}

Chacked against database password and it matched. Clear this wasn't the problem as the database said it timed out.
Now will test obvious time out issue. Security group.

aws ec2 describe-security-groups \
  --region us-east-1 \
  --query "SecurityGroups[].{GroupId:GroupId,Name:GroupName,VpcId:VpcId}" \
  --output table

-------------------------------------------------------------------
|                     DescribeSecurityGroups                      |
+-----------------------+---------------+-------------------------+
|        GroupId        |     Name      |          VpcId          |
+-----------------------+---------------+-------------------------+
|  sg-0fc0d361597c47fcb |  lab-ec2-sg01 |  vpc-068d1fd4fc05e9d80  |
|  sg-0d535c9d5a698237c |  default      |  vpc-035440d5ab0a4ab71  |
|  sg-06ad0071312fd450d |  nvadefsg1    |  vpc-035440d5ab0a4ab71  |
|  sg-0afe423aa62c643f1 |  demo-alb-sec |  vpc-035440d5ab0a4ab71  |
|  sg-004ca40904641044b |  default      |  vpc-068d1fd4fc05e9d80  |
|  sg-0b1725c943055f81d |  lab-rds-sg01 |  vpc-068d1fd4fc05e9d80  |
+-----------------------+---------------+-------------------------+

aws rds describe-db-instances \
  --region us-east-1 \
  --query "DBInstances[].{DB:DBInstanceIdentifier,Engine:Engine,Public:PubliclyAccessible,Vpc:DBSubnetGroup.VpcId}" \
  --output table

------------------------------------------------------------
|                    DescribeDBInstances                   |
+-----------+---------+---------+--------------------------+
|    DB     | Engine  | Public  |           Vpc            |
+-----------+---------+---------+--------------------------+
|  lab-rds01|  mysql  |  False  |  vpc-068d1fd4fc05e9d80   |
+-----------+---------+---------+--------------------------+

aws rds describe-db-instances \
  --db-instance-identifier lab-rds01 \
  --region us-east-1 \
  --query "DBInstances[].VpcSecurityGroups[].VpcSecurityGroupId" \
  --output table

  --------------------------
|   DescribeDBInstances  |
+------------------------+
|  sg-0b1725c943055f81d  |
+------------------------+


aws ec2 describe-security-groups \
  --group-ids sg-0b1725c943055f81d \
  --region us-east-1 \
  --output json

  {
    "SecurityGroups": [
        {
            "GroupId": "sg-0b1725c943055f81d",
            "IpPermissionsEgress": [],
            "Tags": [
                {
                    "Key": "Name",
                    "Value": "lab-rds-sg01"
                }
            ],
            "VpcId": "vpc-068d1fd4fc05e9d80",
            "SecurityGroupArn": "arn:aws:ec2:us-east-1:778185677715:security-group/sg-0b1725c943055f81d",
            "OwnerId": "778185677715",
            "GroupName": "lab-rds-sg01",
            "Description": "RDS security group",
            "IpPermissions": []
        }
    ]
}

    Security group failure: through runbook I found that there are no egress rules on sg. Also no mention of 
    ingress rules no port or protocol. I will check against Instance sg just to be sure.

aws ec2 describe-security-groups \
  --group-ids sg-0fc0d361597c47fcb \
  --region us-east-1 \
  --output json

  {
    "SecurityGroups": [
        {
            "GroupId": "sg-0fc0d361597c47fcb",
            "IpPermissionsEgress": [
                {
                    "IpProtocol": "-1",
                    "UserIdGroupPairs": [],
                    "IpRanges": [
                        {
                            "CidrIp": "0.0.0.0/0"
                        }
                    ],
                    "Ipv6Ranges": [],
                    "PrefixListIds": []
                }
            ],
            "Tags": [
                {
                    "Key": "Name",
                    "Value": "lab-ec2-sg01"
                }
            ],
            "VpcId": "vpc-068d1fd4fc05e9d80",
            "SecurityGroupArn": "arn:aws:ec2:us-east-1:778185677715:security-group/sg-0fc0d361597c47fcb",
            "OwnerId": "778185677715",
            "GroupName": "lab-ec2-sg01",
            "Description": "EC2 app security group",
            "IpPermissions": [
                {
                    "IpProtocol": "tcp",
                    "FromPort": 80,
                    "ToPort": 80,
                    "UserIdGroupPairs": [],
                    "IpRanges": [
                        {
                            "CidrIp": "0.0.0.0/0"
                        }
                    ],
                    "Ipv6Ranges": [],
                    "PrefixListIds": []
                },
                {
                    "IpProtocol": "tcp",
                    "FromPort": 22,
                    "ToPort": 22,
                    "UserIdGroupPairs": [],
                    "IpRanges": [
                        {
                            "CidrIp": "0.0.0.0/0"
                        }
                    ],
                    "Ipv6Ranges": [],
                    "PrefixListIds": []
                }
            ]
        }
    ]
}

Verify Recovery
    curl http://44.200.161.199/list


    <h3>Notes:</h3><li>3rd_entry</li><li>LabEntry</li><li>LabEntry</li><li>LabEntry</li><br><a href='/'>Back</a>


aws cloudwatch describe-alarms \
      --alarm-names lab-db-connection-failure \
      --query "MetricAlarms[].StateValue"


[
    "OK"
]


MSYS_NO_PATHCONV=1 aws logs filter-log-events \
  --log-group-name "/aws/ec2/lab-rds-app" \
  --filter-pattern "DB_CONNECTION_FAILURE"

{
    "events": [
        {
            "logStreamName": "app-stream",
            "timestamp": 1769463993596,
            "message": "DB_CONNECTION_FAILURE: (1146, \"Table 'labdb.notes' doesn't exist\")",
            "ingestionTime": 1769464053664,
            "eventId": "39460365659158818297263398380553646282928003050689265664"
        },
        {
            "logStreamName": "app-stream",
            "timestamp": 1769466339497,
            "message": "DB_CONNECTION_FAILURE: (2003, \"Can't connect to MySQL server on 'lab-rds01.c89ykq22i31z.us-east-1.rds.amazonaws.com' (timed out)\")",
            "ingestionTime": 1769466393808,
            "eventId": "39460417974499280275450759561397227138364628294044614656"
        },
        {
            "logStreamName": "app-stream",
            "timestamp": 1769466353475,

No new errors...

Root Cause

Security group rules were not allowing port 3306 traffic from the ec2 nor was it allowing outbound traffic. Recovered successfully with no errors.

After inspecting instance security group I notice a mention ingress, egress, ports and protocol. I suspect there is a
network failure. Security group is not allowing traffic from ec2 instance...

Preventive Action
    One improvement to reduce MTTR

The best improvement could be a Cloudwatch alarm that checks every 5 to 10 minutes for sg rules,
if not matching the desired state it should invoke a lambda function that will send an SNS message and notify that security group is not configured properly.

    One improvement to prevent recurrence

The best way to prevent this error is to use infrastructure as code to deploy, is
also smart to do peer reviews and validation checks before deployment.


What I learned from this lab:
Meticulous runbook planning prevents infrastructure recovery failures. Creating runbooks reactively during 3AM incidents is exponentially more difficult than proactive development.

When rollback isn't viable and rapid recovery is mission-critical, pre-defined failure recovery paths (launch-time vs. runtime) eliminate root cause analysis under pressure, reducing MTTR from hours to minutes.
​

Technical Takeaway: Document idempotent remediation sequences for common failure modes (security group detachment, IAM drift, network ACL blocks) with CLI verification commands and success criteria before incidents occur.