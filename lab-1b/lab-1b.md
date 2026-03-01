# lab-1b-deliverables

notes:

- Create VPC and more - armageddon-demo - vpc-071b3006f1b773b9b

- Create parameters, can only create 2 because 3rd requires endpoint from RDS
arn:aws:ssm:us-east-1:778185677715:parameter/lab/db/name
arn:aws:ssm:us-east-1:778185677715:parameter/lab/db/port

- Create SNS Topic:
```bash
aws sns create-topic --name lab-db-incidents
```
arn:aws:sns:us-east-1:778185677715:lab-db-incidents

```bash
aws sns subscribe \
   --topic-arn arn:aws:sns:us-east-1:778185677715:lab-db-incidents \
   --protocol email \
   --notification-endpoint firstofmyname5802@outlook.com
```
- Create CloudWatch alarm:
```bash
aws cloudwatch put-metric-alarm \
  --alarm-name lab-db-connection-failure \
  --alarm-description "Alarm when the app fails to connect to RDS" \
  --metric-name DBConnectionErrors \
  --namespace Lab/RDSApp \
  --statistic Sum \
  --period 300 \
  --threshold 3 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --alarm-actions arn:aws:sns:us-east-1:778185677715:lab-db-incidents \
  --treat-missing-data notBreaching
```
- Create security groups:
armageddon-db-sg -  > armageddon-public-sg - sg-0de1170290e03b824

- Create Database:
lab-mysql
self-managed secret: admin pw: DawgsRDSPass123

Create Iam Role:
ec2_role_1b

Attach policy below

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ReadSpecificSecret",
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue"
            ],
            "Resource": "arn:aws:secretsmanager:us-east-1:778185677715:secret:lab/rds/mysql*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssm:GetParameter",
                "ssm:GetParameters"
            ],
            "Resource": "arn:aws:ssm:us-east-1:778185677715:parameter/lab/db/*"
        }
    ]
}
```

Also add CloudWatch agent server policy

Create 3rd parameter:

Get endpoint from database - lab-mysql.c89ykq22i31z.us-east-1.rds.amazonaws.com

Create Instance and connect IAM role: i-0a7efcb7ad4cccaf2

lab-ec2-app
ec2_role_1b


Successfully got webpage.
Successfully initialized database

Now we inject failure: 3 choices for project include stopping database, changind db password, stop database.


Runbook for figuring problem:

```bash
  aws logs filter-log-events \
  --log-group-name /aws/ec2/lab-rds-app \
  --filter-pattern "ERROR"
```

output:

{
    "MetricAlarms": [
        {
            "AlarmName": "lab-db-connection-failure",
            "AlarmArn": "arn:aws:cloudwatch:us-east-1:778185677715:alarm:lab-db-connection-failure",
            "AlarmDescription": "Alarm when the app fails to connect to RDS",
            "AlarmConfigurationUpdatedTimestamp": "2026-01-17T08:02:19.865000-06:00",
            "ActionsEnabled": true,
            "OKActions": [],
            "AlarmActions": [
                "arn:aws:sns:us-east-1:778185677715:lab-db-incidents"
            ],
            "InsufficientDataActions": [],
            "StateValue": "ALARM",
            "StateReason": "Threshold Crossed: 1 datapoint [63.0 (17/01/26 17:02:00)] was greater than the threshold (3.0).",
            "StateReasonData": "{\"version\":\"1.0\",\"queryDate\":\"2026-01-17T17:07:38.154+0000\",\"startDate\":\"2026-01-17T17:02:00.000+0000\",\"statistic\":\"Sum\",\"period\":300,\"recentDatapoints\":[63.0],\"threshold\":3.0,\"evaluatedDatapoints\":[{\"timestamp\":\"2026-01-17T17:02:00.000+0000\",\"sampleCount\":63.0,\"value\":63.0}]}",
            "StateUpdatedTimestamp": "2026-01-17T11:07:38.156000-06:00",
            "MetricName": "DBConnectionErrors",
            "Namespace": "Lab/RDSApp",
            "Statistic": "Sum",
            "Dimensions": [],
            "Period": 300,
            "EvaluationPeriods": 1,
            "Threshold": 3.0,
            "ComparisonOperator": "GreaterThanThreshold",
            "TreatMissingData": "notBreaching",
            "StateTransitionedTimestamp": "2026-01-17T11:07:38.156000-06:00"
        }
    ],
    "CompositeAlarms": []
}




Expected output
```
 aws cloudwatch describe-alarms \
--alarm-names dawgs-armageddon-db-connection-failure \
--query "MetricAlarms[].StateValue"
```

[
    "ALARM"
]


```
 MSYS_NO_PATHCONV=1 aws logs filter-log-events \
  --log-group-name "/aws/ec2/dawgs-armageddon-rds-app" \
  --filter-pattern "DB_CONNECTION_FAILURE"
```
{
    "events": [
        {
            "logStreamName": "app-stream",
            "timestamp": 1768669577785,
            "message": "DB_CONNECTION_FAILURE: (1045, \"Access denied for user 'admin'@'10.180.10.164' (using password: YES)\")",
            "ingestionTime": 1768669637857,
            "eventId": "39442649594576023236271119525355883329689685131857100800"
        },
        {
            "logStreamName": "app-stream",
            "timestamp": 1768669583066,
            "message": "DB_CONNECTION_FAILURE: (1045, \"Access denied for user 'admin'@'10.180.10.164' (using password: YES)\")",
            "ingestionTime": 1768669637857,
            "eventId": "39442649712346258629711340335806011527545682244939677697"
        },
        {
            "logStreamName": "app-stream",
            "timestamp": 1768669584942,
            "message": "DB_CONNECTION_FAILURE: (1045, \"Access denied for user 'admin'@'10.180.10.164' (using password: YES)\")",
            "ingestionTime": 1768669637857,
            "eventId": "39442649754182456622154789349327019007034008430158938114"
        },
        {
            "logStreamName": "app-stream",
            "timestamp": 1768669585254,
            "message": "DB_CONNECTION_FAILURE: (1045, \"Access denied for user 'admin'@'10.180.10.164' (using password: YES)\")",
            "ingestionTime": 1768669637857,
            "eventId": "39442649761140289124096343769486163108100297220024827907"
        },
        {
            "logStreamName": "app-stream",
            "timestamp": 1768669585494,
            "message": "DB_CONNECTION_FAILURE: (1045, \"Access denied for user 'admin'@'10.180.10.164' (using password: YES)\")",
            "ingestionTime": 1768669637857,
            "eventId": "39442649766492467971743693323454735493535903981460127748"
        },
        {
            "logStreamName": "app-stream",
            "timestamp": 1768669585700,
            "message": "DB_CONNECTION_FAILURE: (1045, \"Access denied for user 'admin'@'10.180.10.164' (using password: YES)\")",
            "ingestionTime": 1768669637857,
            "eventId": "39442649771086421482641001690611093457701466451692093445"
        },
        {
            "logStreamName": "app-stream",
            "timestamp": 1768669585870,
            "message": "DB_CONNECTION_FAILURE: (1045, \"Access denied for user 'admin'@'10.180.10.164' (using password: YES)\")",
            "ingestionTime": 1768669637857,
            "eventId": "39442649774877548166391207624672165564051687907708764166"
        },
        {
            "logStreamName": "app-stream",
            "timestamp": 1768669586027,
            "message": "DB_CONNECTION_FAILURE: (1045, \"Access denied for user 'admin'@'10.180.10.164' (using password: YES)\")",
            "ingestionTime": 1768669637857,
            "eventId": "39442649778378765162560515457893273332857480664147689479"
        },
        {
            "logStreamName": "app-stream",
            "timestamp": 1768669586196,
            "message": "DB_CONNECTION_FAILURE: (1045, \"Access denied for user 'admin'@'10.180.10.164' (using password: YES)\")",
            "ingestionTime": 1768669637857,
            "eventId": "39442649782147591101112190768812809720935053758658379784


```
aws ssm get-parameters \
  --names "//lab\\db\\endpoint" "//lab\\db\\name" "//lab\\db\\port" \
  --with-decryption
```

{
    "Parameters": [
        {
            "Name": "/lab/db/endpoint",
            "Type": "String",
            "Value": "lab-mysql.c89ykq22i31z.us-east-1.rds.amazonaws.com",
            "Version": 1,
            "LastModifiedDate": "2026-01-17T09:17:06.670000-06:00",
            "ARN": "arn:aws:ssm:us-east-1:778185677715:parameter/lab/db/endpoint",
            "DataType": "text"
        },
        {
            "Name": "/lab/db/name",
            "Type": "String",
            "Value": "labdb",
            "Version": 1,
            "LastModifiedDate": "2026-01-17T07:37:28.482000-06:00",
            "ARN": "arn:aws:ssm:us-east-1:778185677715:parameter/lab/db/name",
            "DataType": "text"
        },
        {
            "Name": "/lab/db/port",
            "Type": "String",
            "Value": "3306",
            "Version": 1,
            "LastModifiedDate": "2026-01-17T07:40:21.088000-06:00",
            "ARN": "arn:aws:ssm:us-east-1:778185677715:parameter/lab/db/port",
            "DataType": "text"
        }
    ],
    "InvalidParameters": []
}


```
  aws secretsmanager get-secret-value \
  --secret-id lab/rds/mysql
```

{
    "ARN": "arn:aws:secretsmanager:us-east-1:778185677715:secret:lab/rds/mysql-ogi2rZ",
    "Name": "lab/rds/mysql",
    "VersionId": "5e957cf1-ddb3-4174-8f68-c5316f1ccd93",
    "SecretString": "{\"username\":\"admin\",\"password\":\"DawgsRDSPass123\",\"engine\":\"mysql\",\"host\":\"lab-mysql.c89ykq22i31z.us-east-1.rds.amazonaws.com\",\"port\":3306,\"dbInstanceIdentifier\":\"lab-mysql\"}",
    "VersionStages": [
        "AWSCURRENT"
    ],
    "CreatedDate": "2026-01-02T19:18:34.063000-06:00"
}

Prove recovery:
curl http://98.80.204.135/list


aws cloudwatch describe-alarms \
  --alarm-name-prefix lab-db-connection
