#1c_bonus-E.md

Key update since “the old days”: AWS WAF logging can go directly to CloudWatch Logs, S3, or Kinesis Data Firehose, 
and you can associate one destination per Web ACL. Also, the destination name must start with aws-waf-logs-. 


Terraform supports this with aws_wafv2_web_acl_logging_configuration. 
Terraform Registry

Below is Lab 1C-Bonus-E (continued): WAF logging in Terraform (with toggles), plus verification commands.

1) Add variables (append to variables.tf)
variable "waf_log_destination" {
  description = "Choose ONE destination per WebACL: cloudwatch | s3 | firehose"
  type        = string
  default     = "cloudwatch"
}

variable "waf_log_retention_days" {
  description = "Retention for WAF CloudWatch log group."
  type        = number
  default     = 14
}

variable "enable_waf_sampled_requests_only" {
  description = "If true, students can optionally filter/redact fields later. (Placeholder toggle.)"
  type        = bool
  default     = false
}


2) Add file: bonus_b_waf_logging.tf (Look in Folder)

This provides three skeleton options (CloudWatch / S3 / Firehose). Students choose one via var.waf_log_destination.


3) Outputs (append to outputs.tf)
# Explanation: Coordinates for the WAF log destination—Chewbacca wants to know where the footprints landed.
output "chewbacca_waf_log_destination" {
  value = var.waf_log_destination
}

output "chewbacca_waf_cw_log_group_name" {
  value = var.waf_log_destination == "cloudwatch" ? aws_cloudwatch_log_group.chewbacca_waf_log_group01[0].name : null
}

output "chewbacca_waf_logs_s3_bucket" {
  value = var.waf_log_destination == "s3" ? aws_s3_bucket.chewbacca_waf_logs_bucket01[0].bucket : null
}

output "chewbacca_waf_firehose_name" {
  value = var.waf_log_destination == "firehose" ? aws_kinesis_firehose_delivery_stream.chewbacca_waf_firehose01[0].name : null
}


4) Student verification (CLI)
A) Confirm WAF logging is enabled (authoritative)
  aws wafv2 get-logging-configuration \
    --resource-arn <WEB_ACL_ARN>

Expected: LogDestinationConfigs contains exactly one destination.

B) Generate traffic (hits + blocks)
  curl -I https://thedawgs2025.click/

HTTP/1.1 200 OK
Date: Thu, 12 Feb 2026 04:28:40 GMT
Content-Type: text/html; charset=utf-8
Content-Length: 233
Connection: keep-alive
Server: Werkzeug/3.1.5 Python/3.9.25

  curl -I https://app.thedawgs2025.click/

HTTP/1.1 200 OK
Date: Thu, 12 Feb 2026 04:29:09 GMT
Content-Type: text/html; charset=utf-8
Content-Length: 233
Connection: keep-alive
Server: Werkzeug/3.1.5 Python/3.9.25

C1) If CloudWatch Logs destination
  aws logs describe-log-streams \
  --log-group-name aws-waf-logs-<project>-webacl01 \
  --order-by LastEventTime --descending

Then pull recent events:
  aws logs filter-log-events \
  --log-group-name aws-waf-logs-<project>-webacl01 \
  --max-items 20

C2) If S3 destination
  aws s3 ls s3://aws-waf-logs-<project>-<account_id>/ --recursive | head

C3) If Firehose destination
  aws firehose describe-delivery-stream \
  --delivery-stream-name aws-waf-logs-<project>-firehose01 \
  --query "DeliveryStreamDescription.DeliveryStreamStatus"

And confirm objects land:
  aws s3 ls s3://<firehose_dest_bucket>/waf-logs/ --recursive | head

5) Why this makes incident response “real”
Now you can answer questions like:
  “Are 5xx caused by attackers or backend failure?”
  “Do we see WAF blocks spike before ALB 5xx?”
  “What paths / IPs are hammering the app?”
  “Is it one client, one ASN, one country, or broad?”
  “Did WAF mitigate, or are we failing downstream?”

This is precisely why WAF logging destinations include CloudWatch Logs (fast search) and S3/Firehose (archive/SIEM pipeline)


app_url_http = "http://app.thedawgs2025.click"
app_url_https = "https://app.thedawgs2025.click"
app_urls = {
  "alb_direct" = "http://lab-alb01-947924813.us-east-1.elb.amazonaws.com"
  "http" = "http://app.thedawgs2025.click"
  "https" = "https://app.thedawgs2025.click"
}
base_domain = "thedawgs2025.click"
dawgs-armageddon_acm_cert_arn = "arn:aws:acm:us-east-1:778185677715:certificate/9cf34a25-f435-43ad-b531-df69a798c860"
dawgs-armageddon_alb_dns_name = "lab-alb01-947924813.us-east-1.elb.amazonaws.com"
dawgs-armageddon_apex_url_https = "https://thedawgs2025.click"
dawgs-armageddon_dashboard_name = "lab-dashboard01"
dawgs-armageddon_ec2_instance_id = "i-09679556d87176ca5"
dawgs-armageddon_ec2_private_instance_id = "i-0e5776c9136139256"
dawgs-armageddon_log_group_name = "/aws/ec2/lab-rds-app"
dawgs-armageddon_private_subnet_ids = [
  "subnet-052acbb34e1c4d042",
  "subnet-0ded8c291fe1c3eb9",
]
dawgs-armageddon_public_subnet_ids = [
  "subnet-016705aa93f732d7f",
  "subnet-0b4de9ca38c5e183f",
]
dawgs-armageddon_rds_endpoint = "lab-rds01.c89ykq22i31z.us-east-1.rds.amazonaws.com"
dawgs-armageddon_sns_topic_arn = "arn:aws:sns:us-east-1:778185677715:lab-db-incidents"
dawgs-armageddon_target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:778185677715:targetgroup/lab-tg01/f0d614c16d755184"
dawgs-armageddon_vpc_id = "vpc-04afeba69e964c861"
dawgs-armageddon_waf_arn = "arn:aws:wafv2:us-east-1:778185677715:regional/webacl/lab-waf01/3ee501d8-57e3-4aaf-b1bb-3d08ca85af6e"
dawgs-armageddon_waf_log_destination = "cloudwatch"
lb_url = "http://lab-alb01-947924813.us-east-1.elb.amazonaws.com"



# Regional (ALB, API GW, etc.)
aws wafv2 list-web-acls \
  --scope REGIONAL \
  --region us-east-1 \
  --query "WebACLs[].Name" \
  --output text

lab-waf01


aws wafv2 list-web-acls \
  --scope REGIONAL \
  --region us-east-1 \
  --query "WebACLs[?Name=='lab-waf01'].ARN" \
  --output table

---------------------------------------------------------------------------------------------------------
|                                              ListWebACLs
                        |
+-------------------------------------------------------------------------------------------------------+
|  arn:aws:wafv2:us-east-1:778185677715:regional/webacl/lab-waf01/3ee501d8-57e3-4aaf-b1bb-3d08ca85af6e  |
+-------------------------------------------------------------------------------------------------------+



aws wafv2 get-logging-configuration \
    --resource-arn arn:aws:wafv2:us-east-1:778185677715:regional/webacl/lab-waf01/3ee501d8-57e3-4aaf-b1bb-3d08ca85af6e

{
    "LoggingConfiguration": {
        "ResourceArn": "arn:aws:wafv2:us-east-1:778185677715:regional/webacl/lab-waf01/3ee501d8-57e3-4aaf-b1bb-3d08ca85af6e",
        "LogDestinationConfigs": [
            "arn:aws:logs:us-east-1:778185677715:log-group:aws-waf-logs-lab-webacl01"
        ],
        "ManagedByFirewallManager": false,
        "LogType": "WAF_LOGS",
        "LogScope": "CUSTOMER"
    }
}

aws wafv2 get-logging-configuration \
    --resource-arn arn:aws:wafv2:us-east-1:778185677715:regional/webacl/lab-waf01/3ee501d8-57e3-4aaf-b1bb-3d08ca85af6e \
--output table

---------------------------------------------------------------------------------------------------------------------------------------
|                                                       GetLoggingConfiguration                                                       |
+-------------------------------------------------------------------------------------------------------------------------------------+
||                                                       LoggingConfiguration                                                        ||
|+--------------------------+--------------------------------------------------------------------------------------------------------+|
||  LogScope                |  CUSTOMER
                                                     ||
||  LogType                 |  WAF_LOGS
                                                     ||
||  ManagedByFirewallManager|  False
                                                     ||
||  ResourceArn             |  arn:aws:wafv2:us-east-1:778185677715:regional/web5af6e   ||
m
   LogDestinationConfigs                                                      |o[2m||
------------------------------------------------------------------------------+o[2m||
group:aws-waf-logs-lab-webacl01                                             -- M           |||
------------------------------------------------------------------------------+o[2m||

aws logs describe-log-groups \
  --query "logGroups[].logGroupName" \
  --output text

/aws/ec2/lab-rds-app    /aws/lambda/S3toSNSLambda       /aws/lambda/s3-sns-email-handler        /aws/lambda/s3tosnslambda       /aws/rds/instance/lab-mysql-2/error     /aws/rds/instance/lab-mysql/error       /aws/rds/instance/labmysql/error        RDSOSMetrics    aws-waf-logs-lab-webacl01

aws logs describe-log-streams \
  --log-group-name aws-waf-logs-lab-webacl01 \
  --order-by LastEventTime --descending

{
    "logStreams": [
        {
            "logStreamName": "log_stream_created_by_aws_to_validate_log_delivery_subscriptions",
            "creationTime": 1770870032749,
            "firstEventTimestamp": 1770870032759,
            "lastEventTimestamp": 1770870032759,
            "lastIngestionTime": 1770870032781,
            "uploadSequenceToken": "49039859661598467936524020508471915780554229083552288979",
            "arn": "arn:aws:logs:us-east-1:778185677715:log-group:aws-waf-logs-lab-webacl01:log-stream:log_stream_created_by_aws_to_validate_log_delivery_subscriptions",
            "storedBytes": 0
        },
        {
            "logStreamName": "us-east-1_lab-waf01_0",
            "creationTime": 1770865997968,
            "firstEventTimestamp": 1770865986537,
            "lastEventTimestamp": 1770867555732,
            "lastIngestionTime": 1770867571068,
            "uploadSequenceToken": "49039859661595195758686832835863683065191151877400760516",
            "arn": "arn:aws:logs:us-east-1:778185677715:log-group:aws-waf-logs-lab-webacl01:log-stream:us-east-1_lab-waf01_0",
            "storedBytes": 0
        }
    ]
}

aws logs filter-log-events \
  --log-group-name aws-waf-logs-lab-webacl01 \
  --max-items 20

{
    "events": [
        {
            "logStreamName": "us-east-1_lab-waf01_0",
            "timestamp": 1770865986537,
            "message": "{\"timestamp\":1770865986537,\"formatVersion\":1,\"webaclId\":\"arn:aws:wafv2:us-east-1:778185677715:regional/webacl/lab-waf01/3b0f2686-6523-4553-800f-7467dc8849dc\",\"terminatingRuleId\":\"Default_Action\",\"terminatingRuleType\":\"REGULAR\",\"action\":\"ALLOW\",\"terminatingRuleMatchDetails\":[],\"httpSourceName\":\"ALB\",\"httpSourceId\":\"778185677715-app/lab-alb01/70007e49db426320\",\"ruleGroupList\":[{\"ruleGroupId\":\"AWS#AWSManagedRulesCommonRuleSet\",\"terminatingRule\":null,\"nonTerminatingMatchingRules\":[],\"excludedRules\":null,\"customerConfig\":null}],\"rateBasedRuleList\":[],\"nonTerminatingMatchingRules\":[],\"requestHeadersInserted\":null,\"responseCodeSent\":null,\"httpRequest\":{\"clientIp\":\"176.65.148.161\",\"country\":\"NL\",\"headers\":[{\"name\":\"Host\",\"value\":\"app.thedawgs2025.click\"},{\"name\":\"User-Agent\",\"value\":\"Mozilla/5.0 (compatible; Let's Encrypt validation server; +https://www.letsencrypt.org)\"},{\"name\":\"Accept\",\"value\":\"*/*\"}],\"uri\":\"/\",\"args\":\"\",\"httpVersion\":\"HTTP/1.1\",\"httpMethod\":\"HEAD\",\"requestId\":\"1-698d4542-655e9ee2583163974560fa3f\",\"fragment\":\"\",\"scheme\":\"http\",\"host\":\"app.thedawgs2025.click\"}}",
            "ingestionTime": 1770866004809,
            "eventId": "39491631146506197874481857556408017745093896167608483840"
        },
        {
            "logStreamName": "us-east-1_lab-waf01_0",
            "timestamp": 1770865986538,
            "message": "{\"timestamp\":1770865986538,\"formatVersion\":1,\"webaclId\":\"arn:aws:wafv2:us-east-1:778185677715:regional/webacl/lab-waf01/3b0f2686-6523-4553-800f-7467dc8849dc\",\"terminatingRuleId\":\"Default_Action\",\"terminatingRuleType\":\"REGULAR\",\"action\":\"ALLOW\",\"terminatingRuleMatchDetails\":[],\"httpSourceName\":\"ALB\",\"httpSourceId\":\"778185677715-app/lab-alb01/70007e49db426320\",\"ruleGroupList\":[{\"ruleGroupId\":\"AWS#AWSManagedRulesCommonRuleSet\",\"terminatingRule\":null,\"nonTerminatingMatchingRules\":[],\"excludedRules\":null,\"customerConfig\":null}],\"rateBasedRuleList\":[],\"nonTerminatingMatchingRules\":[],\"requestHeadersInserted\":null,\"responseCodeSent\":null,\"httpRequest\":{\"clientIp\":\"176.65.148.161\",\"country\":\"NL\",\"headers\":[{\"name\":\"Host\",\"value\":\"thedawgs2025.click\"},{\"name\":\"User-Agent\",\"value\":\"Mozilla/5.0 (compatible; Let's Encrypt validation server; +https://www.letsencrypt.org)\"},{\"name\":\"Accept\",\"value\":\"*/*\"}],\"uri\":\"/\",\"args\":\"\",\"httpVersion\":\"HTTP/1.1\",\"httpMethod\":\"HEAD\",\"requestId\":\"1-698d4542-5fe7253c5de4bde30754dd41\",\"fragment\":\"\",\"scheme\":\"http\",\"host\":\"thedawgs2025.click\"}}",
            "ingestionTime": 1770865998016,
            "eventId": "39491631146528498619680388171337196112249982818344108032"
        },
        {
            "logStreamName": "us-east-1_lab-waf01_0",
            "timestamp": 1770865987524,
            "message": "{\"timestamp\":1770865987524,\"formatVersion\":1,\"webaclId\":\"arn:aws:wafv2:us-east-1:778185677715:regional/webacl/lab-waf01/3b0f2686-6523-4553-800f-7467dc8849dc\",\"terminatingRuleId\":\"Default_Action\",\"terminatingRuleType\":\"REGULAR\",\"action\":\"ALLOW\",\"terminatingRuleMatchDetails\":[],\"httpSourceName\":\"ALB\",\"httpSourceId\":\"778185677715-app/lab-alb01/70007e49db426320\",\"ruleGroupList\":[{\"ruleGroupId\":\"AWS#AWSManagedRulesCommonRuleSet\",\"terminatingRule\":null,\"nonTerminatingMatchingRules\":[],\"excludedRules\":null,\"customerConfig\":null}],\"rateBasedRuleList\":[],\"nonTerminatingMatchingRules\":[],\"requestHeadersInserted\":null,\"responseCodeSent\":null,\"httpRequest\":{\"clientIp\":\"176.65.148.161\",\"country\":\"NL\",\"headers\":[{\"name\":\"Host\",\"value\":\"app.thedawgs2025.click\"},{\"name\":\"User-Agent\",\"value\":\"Mozilla/5.0 (compatible; Let's Encrypt validation server; +https://www.letsencrypt.org)\"},{\"name\":\"Accept\",\"value\":\"*/*\"},{\"name\":\"Referer\",\"value\":\"http://app.thedawgs2025.click\"}],\"uri\":\"/\",\"args\":\"\",\"httpVersion\":\"HTTP/1.1\",\"httpMethod\":\"HEAD\",\"requestId\":\"1-698d4543-6bdc04f93002c2da06356c7c\",\"fragment\":\"\",\"scheme\":\"https\",\"host\":\"app.thedawgs2025.click\"},\"ja3Fingerprint\":\"20b279993ae2e137e62b9647c6d768fb\",\"ja4Fingerprint\":\"t13d131100_f57a46bbacb6_ab7e3b40a677\"}",
            "ingestionTime": 1770866007605,
            "eventId": "39491631168517033385431582600483959635609220578778284032"
        },
        {
            "logStreamName": "us-east-1_lab-waf01_0",
            "timestamp": 1770865987525,
            "message": "{\"timestamp\":1770865987525,\"formatVersion\":1,\"webaclId\":\"arn:aws:wafv2:us-east-1:778185677715:regional/webacl/lab-waf01/3b0f2686-6523-4553-800f-7467dc8849dc\",\"terminatingRuleId\":\"Default_Action\",\"terminatingRuleType\":\"REGULAR\",\"action\":\"ALLOW\",\"terminatingRuleMatchDetails\":[],\"httpSourceName\":\"ALB\",\"httpSourceId\":\"778185677715-app/lab-alb01/70007e49db426320\",\"ruleGroupList\":[{\"ruleGroupId\":\"AWS#AWSManagedRulesCommonRuleSet\",\"terminatingRule\":null,\"nonTerminatingMatchingRules\":[],\"excludedRules\":null,\"customerConfig\":null}],\"rateBasedRuleList\":[],\"nonTerminatingMatchingRules\":[],\"requestHeadersInserted\":null,\"responseCodeSent\":null,\"httpRequest\":{\"clientIp\":\"176.65.148.161\",\"country\":\"NL\",\"headers\":[{\"name\":\"Host\",\"value\":\"thedawgs2025.click\"},{\"name\":\"User-Agent\",\"value\":\"Mozilla/5.0 (compatible; Let's Encrypt validation server; +https://www.letsencrypt.org)\"},{\"name\":\"Accept\",\"value\":\"*/*\"},{\"name\":\"Referer\",\"value\":\"http://thedawgs2025.click\"}],\"uri\":\"/\",\"args\":\"\",\"httpVersion\":\"HTTP/1.1\",\"httpMethod\":\"HEAD\",\"requestId\":\"1-698d4543-15685d1c567f870704567dba\",\"fragment\":\"\",\"scheme\":\"https\",\"host\":\"thedawgs2025.click\"},\"ja3Fingerprint\":\"20b279993ae2e137e62b9647c6d768fb\",\"ja4Fingerprint\":\"t13d131100_f57a46bbacb6_ab7e3b40a677\"}",
            "ingestionTime": 1770866005141,
            "eventId": "39491631168539334130630113220646629676537973799967850496"
        },
        {
            "logStreamName": "us-east-1_lab-waf01_0",
            "timestamp": 1770865987741,
            "message": "{\"timestamp\":1770865987741,\"formatVersion\":1,\"webaclId\":\"arn:aws:wafv2:us-east-1:778185677715:regional/webacl/lab-waf01/3b0f2686-6523-4553-800f-7467dc8849dc\",\"terminatingRuleId\":\"Default_Action\",\"terminatingRuleType\":\"REGULAR\",\"action\":\"ALLOW\",\"terminatingRuleMatchDetails\":[],\"httpSourceName\":\"ALB\",\"httpSourceId\":\"778185677715-app/lab-alb01/70007e49db426320\",\"ruleGroupList\":[{\"ruleGroupId\":\"AWS#AWSManagedRulesCommonRuleSet\",\"terminatingRule\":null,\"nonTerminatingMatchingRules\":[],\"excludedRules\":null,\"customerConfig\":null}],\"rateBasedRuleList\":[],\"nonTerminatingMatchingRules\":[],\"requestHeadersInserted\":null,\"responseCodeSent\":null,\"httpRequest\":{\"clientIp\":\"176.65.148.161\",\"country\":\"NL\",\"headers\":[{\"name\":\"Host\",\"value\":\"thedawgs2025.click\"},{\"name\":\"User-Agent\",\"value\":\"Mozilla/5.0 (compatible; Let's Encrypt validation server; +https://www.letsencrypt.org)\"},{\"name\":\"Accept\",\"value\":\"*/*\"},{\"name\":\"Range\",\"value\":\"bytes=0-2048\"}],\"uri\":\"/\",\"args\":\"\",\"httpVersion\":\"HTTP/1.1\",\"httpMethod\":\"GET\",\"requestId\":\"1-698d4543-4b192bde5dd4f11f407f898e\",\"fragment\":\"\",\"scheme\":\"http\",\"host\":\"thedawgs2025.click\"}}",
            "ingestionTime": 1770865998595,
            "eventId": "39491631173356295093512727811304839041206951490995552256"
        },
        {
            "logStreamName": "us-east-1_lab-waf01_0",
            "timestamp": 1770865987741,
            "message": "{\"timestamp\":1770865987741,\"formatVersion\":1,\"webaclId\":\"arn:aws:wafv2:us-east-1:778185677715:regional/webacl/lab-waf01/3b0f2686-6523-4553-800f-7467dc8849dc\",\"terminatingRuleId\":\"Default_Action\",\"terminatingRuleType\":\"REGULAR\",\"action\":\"ALLOW\",\"terminatingRuleMatchDetails\":[],\"httpSourceName\":\"ALB\",\"httpSourceId\":\"778185677715-app/lab-alb01/70007e49db426320\",\"ruleGroupList\":[{\"ruleGroupId\":\"AWS#AWSManagedRulesCommonRuleSet\",\"terminatingRule\":null,\"nonTerminatingMatchingRules\":[],\"excludedRules\":null,\"customerConfig\":null}],\"rateBasedRuleList\":[],\"nonTerminatingMatchingRules\":[],\"requestHeadersInserted\":null,\"responseCodeSent\":null,\"httpRequest\":{\"clientIp\":\"176.65.148.161\",\"country\":\"NL\",\"headers\":[{\"name\":\"Host\",\"value\":\"app.thedawgs2025.click\"},{\"name\":\"User-Agent\",\"value\":\"Mozilla/5.0 (compatible; Let's Encrypt validation server; +https://www.letsencrypt.org)\"},{\"name\":\"Accept\",\"value\":\"*/*\"},{\"name\":\"Range\",\"value\":\"bytes=0-2048\"}],\"uri\":\"/\",\"args\":\"\",\"httpVersion\":\"HTTP/1.1\",\"httpMethod\":\"GET\",\"requestId\":\"1-698d4543-05ac2d344ba9cda437c88ea2\",\"fragment\":\"\",\"scheme\":\"http\",\"host\":\"app.thedawgs2025.click\"}}",
            "ingestionTime": 1770866000240,
            "eventId": "39491631173356295093512727813293182041765915602043731968"
        },
        {
            "logStreamName": "us-east-1_lab-waf01_0",
            "timestamp": 1770865987981,
            "message": "{\"timestamp\":1770865987981,\"formatVersion\":1,\"webaclId\":\"arn:aws:wafv2:us-east-1:778185677715:regional/webacl/lab-waf01/3b0f2686-6523-4553-800f-7467dc8849dc\",\"terminatingRuleId\":\"Default_Action\",\"terminatingRuleType\":\"REGULAR\",\"action\":\"ALLOW\",\"terminatingRuleMatchDetails\":[],\"httpSourceName\":\"ALB\",\"httpSourceId\":\"778185677715-app/lab-alb01/70007e49db426320\",\"ruleGroupList\":[{\"ruleGroupId\":\"AWS#AWSManagedRulesCommonRuleSet\",\"terminatingRule\":null,\"nonTerminatingMatchingRules\":[],\"excludedRules\":null,\"customerConfig\":null}],\"rateBasedRuleList\":[],\"nonTerminatingMatchingRules\":[],\"requestHeadersInserted\":null,\"responseCodeSent\":null,\"httpRequest\":{\"clientIp\":\"176.65.148.161\",\"country\":\"NL\",\"headers\":[{\"name\":\"Host\",\"value\":\"app.thedawgs2025.click\"},{\"name\":\"User-Agent\",\"value\":\"Mozilla/5.0 (compatible; Let's Encrypt validation server; +https://www.letsencrypt.org)\"},{\"name\":\"Accept\",\"value\":\"*/*\"},{\"name\":\"Range\",\"value\":\"bytes=0-2048\"},{\"name\":\"Referer\",\"value\":\"http://app.thedawgs2025.click\"}],\"uri\":\"/\",\"args\":\"\",\"httpVersion\":\"HTTP/1.1\",\"httpMethod\":\"GET\",\"requestId\":\"1-698d4543-2da84f1f63fdc22224b86213\",\"fragment\":\"\",\"scheme\":\"https\",\"host\":\"app.thedawgs2025.click\"},\"ja3Fingerprint\":\"20b279993ae2e137e62b9647c6d768fb\",\"ja4Fingerprint\":\"t13d131100_f57a46bbacb6_ab7e3b40a677\"}",
            "ingestionTime": 1770866003523,
            "eventId": "39491631178708473941160077371230699861976425199434858496"
        },
        {
            "logStreamName": "us-east-1_lab-waf01_0",
            "timestamp": 1770865988133,
            "message": "{\"timestamp\":1770865988133,\"formatVersion\":1,\"webaclId\":\"arn:aws:wafv2:us-east-1:778185677715:regional/webacl/lab-waf01/3b0f2686-6523-4553-800f-7467dc8849dc\",\"terminatingRuleId\":\"Default_Action\",\"terminatingRuleType\":\"REGULAR\",\"action\":\"ALLOW\",\"terminatingRuleMatchDetails\":[],\"httpSourceName\":\"ALB\",\"httpSourceId\":\"778185677715-app/lab-alb01/70007e49db426320\",\"ruleGroupList\":[{\"ruleGroupId\":\"AWS#AWSManagedRulesCommonRuleSet\",\"terminatingRule\":null,\"nonTerminatingMatchingRules\":[],\"excludedRules\":null,\"customerConfig\":null}],\"rateBasedRuleList\":[],\"nonTerminatingMatchingRules\":[],\"requestHeadersInserted\":null,\"responseCodeSent\":null,\"httpRequest\":{\"clientIp\":\"176.65.148.161\",\"country\":\"NL\",\"headers\":[{\"name\":\"Host\",\"value\":\"thedawgs2025.click\"},{\"name\":\"User-Agent\",\"value\":\"Mozilla/5.0 (compatible; Let's Encrypt validation server; +https://www.letsencrypt.org)\"},{\"name\":\"Accept\",\"value\":\"*/*\"},{\"name\":\"Range\",\"value\":\"bytes=0-2048\"},{\"name\":\"Referer\",\"value\":\"http://thedawgs2025.click\"}],\"uri\":\"/\",\"args\":\"\",\"httpVersion\":\"HTTP/1.1\",\"httpMethod\":\"GET\",\"requestId\":\"1-698d4544-7b1f99a40c2017a57727f38d\",\"fragment\":\"\",\"scheme\":\"https\",\"host\":\"thedawgs2025.click\"},\"ja3Fingerprint\":\"20b279993ae2e137e62b9647c6d768fb\",\"ja4Fingerprint\":\"t13d131100_f57a46bbacb6_ab7e3b40a677\"}",
            "ingestionTime": 1770866001023,
            "eventId": "39491631182098187211336732085721879732250893335160815616"
        },
        {
            "logStreamName": "us-east-1_lab-waf01_0",
            "timestamp": 1770865988239,
            "message": "{\"timestamp\":1770865988239,\"formatVersion\":1,\"webaclId\":\"arn:aws:wafv2:us-east-1:778185677715:regional/webacl/lab-waf01/3b0f2686-6523-4553-800f-7467dc8849dc\",\"terminatingRuleId\":\"Default_Action\",\"terminatingRuleType\":\"REGULAR\",\"action\":\"ALLOW\",\"terminatingRuleMatchDetails\":[],\"httpSourceName\":\"ALB\",\"httpSourceId\":\"778185677715-app/lab-alb01/70007e49db426320\",\"ruleGroupList\":[{\"ruleGroupId\":\"AWS#AWSManagedRulesCommonRuleSet\",\"terminatingRule\":null,\"nonTerminatingMatchingRules\":[],\"excludedRules\":null,\"customerConfig\":null}],\"rateBasedRuleList\":[],\"nonTerminatingMatchingRules\":[],\"requestHeadersInserted\":null,\"responseCodeSent\":null,\"httpRequest\":{\"clientIp\":\"176.65.148.161\",\"country\":\"NL\",\"headers\":[{\"name\":\"Host\",\"value\":\"app.thedawgs2025.click\"},{\"name\":\"User-Agent\",\"value\":\"Mozilla/5.0 (compatible; Let's Encrypt validation server; +https://www.letsencrypt.org)\"},{\"name\":\"Accept\",\"value\":\"*/*\"}],\"uri\":\"/_next\",\"args\":\"\",\"httpVersion\":\"HTTP/1.1\",\"httpMethod\":\"HEAD\",\"requestId\":\"1-698d4544-767c1a0125dff4fc4fde074b\",\"fragment\":\"\",\"scheme\":\"http\",\"host\":\"app.thedawgs2025.click\"}}",
            "ingestionTime": 1770866001101,
            "eventId": "39491631184462066202380978138818896468376212172567609344"
        },
        {
            "logStreamName": "us-east-1_lab-waf01_0",
            "timestamp": 1770865988337,
            "message": "{\"timestamp\":1770865988337,\"formatVersion\":1,\"webaclId\":\"arn:aws:wafv2:us-east-1:778185677715:regional/webacl/lab-waf01/3b0f2686-6523-4553-800f-7467dc8849dc\",\"terminatingRuleId\":\"Default_Action\",\"terminatingRuleType\":\"REGULAR\",\"action\":\"ALLOW\",\"terminatingRuleMatchDetails\":[],\"httpSourceName\":\"ALB\",\"httpSourceId\":\"778185677715-app/lab-alb01/70007e49db426320\",\"ruleGroupList\":[{\"ruleGroupId\":\"AWS#AWSManagedRulesCommonRuleSet\",\"terminatingRule\":null,\"nonTerminatingMatchingRules\":[],\"excludedRules\":null,\"customerConfig\":null}],\"rateBasedRuleList\":[],\"nonTerminatingMatchingRules\":[],\"requestHeadersInserted\":null,\"responseCodeSent\":null,\"httpRequest\":{\"clientIp\":\"176.65.148.161\",\"country\":\"NL\",\"headers\":[{\"name\":\"Host\",\"value\":\"thedawgs2025.click\"},{\"name\":\"User-Agent\",\"value\":\"Mozilla/5.0 (compatible; Let's Encrypt validation server; +https://www.letsencrypt.org)\"},{\"name\":\"Accept\",\"value\":\"*/*\"}],\"uri\":\"/_next\",\"args\":\"\",\"httpVersion\":\"HTTP/1.1\",\"httpMethod\":\"HEAD\",\"requestId\":\"1-698d4544-699fadef3a7fe9ae2acf62fa\",\"fragment\":\"\",\"scheme\":\"http\",\"host\":\"thedawgs2025.click\"}}",
            "ingestionTime": 1770866004786,
            "eventId": "39491631186647539231836979211144597112794045508093476864"
        },
        {
            "logStreamName": "us-east-1_lab-waf01_0",
            "timestamp": 1770865988532,
            "message": "{\"timestamp\":1770865988532,\"formatVersion\":1,\"webaclId\":\"arn:aws:wafv2:us-east-1:778185677715:regional/webacl/lab-waf01/3b0f2686-6523-4553-800f-7467dc8849dc\",\"terminatingRuleId\":\"Default_Action\",\"terminatingRuleType\":\"REGULAR\",\"action\":\"ALLOW\",\"terminatingRuleMatchDetails\":[],\"httpSourceName\":\"ALB\",\"httpSourceId\":\"778185677715-app/lab-alb01/70007e49db426320\",\"ruleGroupList\":[{\"ruleGroupId\":\"AWS#AWSManagedRulesCommonRuleSet\",\"terminatingRule\":null,\"nonTerminatingMatchingRules\":[],\"excludedRules\":null,\"customerConfig\":null}],\"rateBasedRuleList\":[],\"nonTerminatingMatchingRules\":[],\"requestHeadersInserted\":null,\"responseCodeSent\":null,\"httpRequest\":{\"clientIp\":\"176.65.148.161\",\"country\":\"NL\",\"headers\":[{\"name\":\"Host\",\"value\":\"app.thedawgs2025.click\"},{\"name\":\"User-Agent\",\"value\":\"Mozilla/5.0 (compatible; Let's Encrypt validation server; +https://www.letsencrypt.org)\"},{\"name\":\"Accept\",\"value\":\"*/*\"},{\"name\":\"Referer\",\"value\":\"http://app.thedawgs2025.click/_next\"}],\"uri\":\"/_next\",\"args\":\"\",\"httpVersion\":\"HTTP/1.1\",\"httpMethod\":\"HEAD\",\"requestId\":\"1-698d4544-08bdc3ef0eeb83d5680fc374\",\"fragment\":\"\",\"scheme\":\"https\",\"host\":\"app.thedawgs2025.click\"},\"ja3Fingerprint\":\"20b279993ae2e137e62b9647c6d768fb\",\"ja4Fingerprint\":\"t13d131100_f57a46bbacb6_ab7e3b40a677\"}",
            "ingestionTime": 1770866004500,
            "eventId": "39491631190996184545550450723398000986888783078686720000"
        },
        {
            "logStreamName": "us-east-1_lab-waf01_0",
            "timestamp": 1770865988618,
            "message": "{\"timestamp\":1770865988618,\"formatVersion\":1,\"webaclId\":\"arn:aws:wafv2:us-east-1:778185677715:regional/webacl/lab-waf01/3b0f2686-6523-4553-800f-7467dc8849dc\",\"terminatingRuleId\":\"Default_Action\",\"terminatingRuleType\":\"REGULAR\",\"action\":\"ALLOW\",\"terminatingRuleMatchDetails\":[],\"httpSourceName\":\"ALB\",\"httpSourceId\":\"778185677715-app/lab-alb01/70007e49db426320\",\"ruleGroupList\":[{\"ruleGroupId\":\"AWS#AWSManagedRulesCommonRuleSet\",\"terminatingRule\":null,\"nonTerminatingMatchingRules\":[],\"excludedRules\":null,\"customerConfig\":null}],\"rateBasedRuleList\":[],\"nonTerminatingMatchingRules\":[],\"requestHeadersInserted\":null,\"responseCodeSent\":null,\"httpRequest\":{\"clientIp\":\"176.65.148.161\",\"country\":\"NL\",\"headers\":[{\"name\":\"Host\",\"value\":\"thedawgs2025.click\"},{\"name\":\"User-Agent\",\"value\":\"Mozilla/5.0 (compatible; Let's Encrypt validation server; +https://www.letsencrypt.org)\"},{\"name\":\"Accept\",\"value\":\"*/*\"},{\"name\":\"Referer\",\"value\":\"http://thedawgs2025.click/_next\"}],\"uri\":\"/_next\",\"args\":\"\",\"httpVersion\":\"HTTP/1.1\",\"httpMethod\":\"HEAD\",\"requestId\":\"1-698d4544-193df1ad430390df0761ca9d\",\"fragment\":\"\",\"scheme\":\"https\",\"host\":\"thedawgs2025.click\"},\"ja3Fingerprint\":\"20b279993ae2e137e62b9647c6d768fb\",\"ja4Fingerprint\":\"t13d131100_f57a46bbacb6_ab7e3b40a677\"}",
            "ingestionTime": 1770866005554,
            "eventId": "39491631192914048632624084314844406056467491830358016000"
        },
        {
            "logStreamName": "us-east-1_lab-waf01_0",
            "timestamp": 1770866035169,
            "message": "{\"timestamp\":1770866035169,\"formatVersion\":1,\"webaclId\":\"arn:aws:wafv2:us-east-1:778185677715:regional/webacl/lab-waf01/3b0f2686-6523-4553-800f-7467dc8849dc\",\"terminatingRuleId\":\"Default_Action\",\"terminatingRuleType\":\"REGULAR\",\"action\":\"ALLOW\",\"terminatingRuleMatchDetails\":[],\"httpSourceName\":\"ALB\",\"httpSourceId\":\"778185677715-app/lab-alb01/70007e49db426320\",\"ruleGroupList\":[{\"ruleGroupId\":\"AWS#AWSManagedRulesCommonRuleSet\",\"terminatingRule\":null,\"nonTerminatingMatchingRules\":[],\"excludedRules\":null,\"customerConfig\":null}],\"rateBasedRuleList\":[],\"nonTerminatingMatchingRules\":[],\"requestHeadersInserted\":null,\"responseCodeSent\":null,\"httpRequest\":{\"clientIp\":\"176.65.148.161\",\"country\":\"NL\",\"headers\":[{\"name\":\"Host\",\"value\":\"app.thedawgs2025.click\"},{\"name\":\"User-Agent\",\"value\":\"Mozilla/5.0 (compatible; Let's Encrypt validation server; +https://www.letsencrypt.org)\"},{\"name\":\"Accept\",\"value\":\"*/*\"}],\"uri\":\"/\",\"args\":\"\",\"httpVersion\":\"HTTP/1.1\",\"httpMethod\":\"HEAD\",\"requestId\":\"1-698d4573-7726e21f039fca47077f072f\",\"fragment\":\"\",\"scheme\":\"http\",\"host\":\"app.thedawgs2025.click\"}}",
            "ingestionTime": 1770866046272,
            "eventId": "39491632231036038369423122225699086083575671667002114048"
        },
        {
            "logStreamName": "us-east-1_lab-waf01_0",
            "timestamp": 1770866035169,
            "message": "{\"timestamp\":1770866035169,\"formatVersion\":1,\"webaclId\":\"arn:aws:wafv2:us-east-1:778185677715:regional/webacl/lab-waf01/3b0f2686-6523-4553-800f-7467dc8849dc\",\"terminatingRuleId\":\"Default_Action\",\"terminatingRuleType\":\"REGULAR\",\"action\":\"ALLOW\",\"terminatingRuleMatchDetails\":[],\"httpSourceName\":\"ALB\",\"httpSourceId\":\"778185677715-app/lab-alb01/70007e49db426320\",\"ruleGroupList\":[{\"ruleGroupId\":\"AWS#AWSManagedRulesCommonRuleSet\",\"terminatingRule\":null,\"nonTerminatingMatchingRules\":[],\"excludedRules\":null,\"customerConfig\":null}],\"rateBasedRuleList\":[],\"nonTerminatingMatchingRules\":[],\"requestHeadersInserted\":null,\"responseCodeSent\":null,\"httpRequest\":{\"clientIp\":\"176.65.148.161\",\"country\":\"NL\",\"headers\":[{\"name\":\"Host\",\"value\":\"thedawgs2025.click\"},{\"name\":\"User-Agent\",\"value\":\"Mozilla/5.0 (compatible; Let's Encrypt validation server; +https://www.letsencrypt.org)\"},{\"name\":\"Accept\",\"value\":\"*/*\"}],\"uri\":\"/\",\"args\":\"\",\"httpVersion\":\"HTTP/1.1\",\"httpMethod\":\"HEAD\",\"requestId\":\"1-698d4573-17d74ab73fc541695a252959\",\"fragment\":\"\",\"scheme\":\"http\",\"host\":\"thedawgs2025.click\"}}",
            "ingestionTime": 1770866051863,
            "eventId": "39491632231036038369423122232458181945338327766708518912"
        },
        {
            "logStreamName": "us-east-1_lab-waf01_0",
            "timestamp": 1770866036581,
            "message": "{\"timestamp\":1770866036581,\"formatVersion\":1,\"webaclId\":\"arn:aws:wafv2:us-east-1:778185677715:regional/webacl/lab-waf01/3b0f2686-6523-4553-800f-7467dc8849dc\",\"terminatingRuleId\":\"Default_Action\",\"terminatingRuleType\":\"REGULAR\",\"action\":\"ALLOW\",\"terminatingRuleMatchDetails\":[],\"httpSourceName\":\"ALB\",\"httpSourceId\":\"778185677715-app/lab-alb01/70007e49db426320\",\"ruleGroupList\":[{\"ruleGroupId\":\"AWS#AWSManagedRulesCommonRuleSet\",\"terminatingRule\":null,\"nonTerminatingMatchingRules\":[],\"excludedRules\":null,\"customerConfig\":null}],\"rateBasedRuleList\":[],\"nonTerminatingMatchingRules\":[],\"requestHeadersInserted\":null,\"responseCodeSent\":null,\"httpRequest\":{\"clientIp\":\"176.65.148.161\",\"country\":\"NL\",\"headers\":[{\"name\":\"Host\",\"value\":\"thedawgs2025.click\"},{\"name\":\"User-Agent\",\"value\":\"Mozilla/5.0 (compatible; Let's Encrypt validation server; +https://www.letsencrypt.org)\"},{\"name\":\"Accept\",\"value\":\"*/*\"},{\"name\":\"Referer\",\"value\":\"http://thedawgs2025.click\"}],\"uri\":\"/\",\"args\":\"\",\"httpVersion\":\"HTTP/1.1\",\"httpMethod\":\"HEAD\",\"requestId\":\"1-698d4574-3df035a77b5e9b1225b8b06c\",\"fragment\":\"\",\"scheme\":\"https\",\"host\":\"thedawgs2025.click\"},\"ja3Fingerprint\":\"20b279993ae2e137e62b9647c6d768fb\",\"ja4Fingerprint\":\"t13d131100_f57a46bbacb6_ab7e3b40a677\"}",
            "ingestionTime": 1770866048524,
            "eventId": "39491632262524690589748362104270020260766902961928470528"
        },
        {
            "logStreamName": "us-east-1_lab-waf01_0",
            "timestamp": 1770866036584,
            "message": "{\"timestamp\":1770866036584,\"formatVersion\":1,\"webaclId\":\"arn:aws:wafv2:us-east-1:778185677715:regional/webacl/lab-waf01/3b0f2686-6523-4553-800f-7467dc8849dc\",\"terminatingRuleId\":\"Default_Action\",\"terminatingRuleType\":\"REGULAR\",\"action\":\"ALLOW\",\"terminatingRuleMatchDetails\":[],\"httpSourceName\":\"ALB\",\"httpSourceId\":\"778185677715-app/lab-alb01/70007e49db426320\",\"ruleGroupList\":[{\"ruleGroupId\":\"AWS#AWSManagedRulesCommonRuleSet\",\"terminatingRule\":null,\"nonTerminatingMatchingRules\":[],\"excludedRules\":null,\"customerConfig\":null}],\"rateBasedRuleList\":[],\"nonTerminatingMatchingRules\":[],\"requestHeadersInserted\":null,\"responseCodeSent\":null,\"httpRequest\":{\"clientIp\":\"176.65.148.161\",\"country\":\"NL\",\"headers\":[{\"name\":\"Host\",\"value\":\"app.thedawgs2025.click\"},{\"name\":\"User-Agent\",\"value\":\"Mozilla/5.0 (compatible; Let's Encrypt validation server; +https://www.letsencrypt.org)\"},{\"name\":\"Accept\",\"value\":\"*/*\"},{\"name\":\"Referer\",\"value\":\"http://app.thedawgs2025.click\"}],\"uri\":\"/\",\"args\":\"\",\"httpVersion\":\"HTTP/1.1\",\"httpMethod\":\"HEAD\",\"requestId\":\"1-698d4574-27146fe019838d4457268248\",\"fragment\":\"\",\"scheme\":\"https\",\"host\":\"app.thedawgs2025.click\"},\"ja3Fingerprint\":\"20b279993ae2e137e62b9647c6d768fb\",\"ja4Fingerprint\":\"t13d131100_f57a46bbacb6_ab7e3b40a677\"}",
            "ingestionTime": 1770866053479,
            "eventId": "39491632262591592825343953979684269387080973934630207488"
        },
        {
            "logStreamName": "us-east-1_lab-waf01_0",
            "timestamp": 1770866036888,
            "message": "{\"timestamp\":1770866036888,\"formatVersion\":1,\"webaclId\":\"arn:aws:wafv2:us-east-1:778185677715:regional/webacl/lab-waf01/3b0f2686-6523-4553-800f-7467dc8849dc\",\"terminatingRuleId\":\"Default_Action\",\"terminatingRuleType\":\"REGULAR\",\"action\":\"ALLOW\",\"terminatingRuleMatchDetails\":[],\"httpSourceName\":\"ALB\",\"httpSourceId\":\"778185677715-app/lab-alb01/70007e49db426320\",\"ruleGroupList\":[{\"ruleGroupId\":\"AWS#AWSManagedRulesCommonRuleSet\",\"terminatingRule\":null,\"nonTerminatingMatchingRules\":[],\"excludedRules\":null,\"customerConfig\":null}],\"rateBasedRuleList\":[],\"nonTerminatingMatchingRules\":[],\"requestHeadersInserted\":null,\"responseCodeSent\":null,\"httpRequest\":{\"clientIp\":\"176.65.148.161\",\"country\":\"NL\",\"headers\":[{\"name\":\"Host\",\"value\":\"thedawgs2025.click\"},{\"name\":\"User-Agent\",\"value\":\"Mozilla/5.0 (compatible; Let's Encrypt validation server; +https://www.letsencrypt.org)\"},{\"name\":\"Accept\",\"value\":\"*/*\"},{\"name\":\"Range\",\"value\":\"bytes=0-2048\"}],\"uri\":\"/\",\"args\":\"\",\"httpVersion\":\"HTTP/1.1\",\"httpMethod\":\"GET\",\"requestId\":\"1-698d4574-1c10417e5237568a1f15f2d3\",\"fragment\":\"\",\"scheme\":\"http\",\"host\":\"thedawgs2025.click\"}}",
            "ingestionTime": 1770866051633,
            "eventId": "39491632269371019365697263412479446439980209495747526656"
        },
        {
            "logStreamName": "us-east-1_lab-waf01_0",
            "timestamp": 1770866036917,
            "message": "{\"timestamp\":1770866036917,\"formatVersion\":1,\"webaclId\":\"arn:aws:wafv2:us-east-1:778185677715:regional/webacl/lab-waf01/3b0f2686-6523-4553-800f-7467dc8849dc\",\"terminatingRuleId\":\"Default_Action\",\"terminatingRuleType\":\"REGULAR\",\"action\":\"ALLOW\",\"terminatingRuleMatchDetails\":[],\"httpSourceName\":\"ALB\",\"httpSourceId\":\"778185677715-app/lab-alb01/70007e49db426320\",\"ruleGroupList\":[{\"ruleGroupId\":\"AWS#AWSManagedRulesCommonRuleSet\",\"terminatingRule\":null,\"nonTerminatingMatchingRules\":[],\"excludedRules\":null,\"customerConfig\":null}],\"rateBasedRuleList\":[],\"nonTerminatingMatchingRules\":[],\"requestHeadersInserted\":null,\"responseCodeSent\":null,\"httpRequest\":{\"clientIp\":\"176.65.148.161\",\"country\":\"NL\",\"headers\":[{\"name\":\"Host\",\"value\":\"app.thedawgs2025.click\"},{\"name\":\"User-Agent\",\"value\":\"Mozilla/5.0 (compatible; Let's Encrypt validation server; +https://www.letsencrypt.org)\"},{\"name\":\"Accept\",\"value\":\"*/*\"},{\"name\":\"Range\",\"value\":\"bytes=0-2048\"}],\"uri\":\"/\",\"args\":\"\",\"httpVersion\":\"HTTP/1.1\",\"httpMethod\":\"GET\",\"requestId\":\"1-698d4574-7a55f3c26aa8783c41b8aa8f\",\"fragment\":\"\",\"scheme\":\"http\",\"host\":\"app.thedawgs2025.click\"}}",
            "ingestionTime": 1770866054235,
            "eventId": "39491632270017740976454651486729916161112959025425940480"
        },
        {
            "logStreamName": "us-east-1_lab-waf01_0",
            "timestamp": 1770866037203,
            "message": "{\"timestamp\":1770866037203,\"formatVersion\":1,\"webaclId\":\"arn:aws:wafv2:us-east-1:778185677715:regional/webacl/lab-waf01/3b0f2686-6523-4553-800f-7467dc8849dc\",\"terminatingRuleId\":\"Default_Action\",\"terminatingRuleType\":\"REGULAR\",\"action\":\"ALLOW\",\"terminatingRuleMatchDetails\":[],\"httpSourceName\":\"ALB\",\"httpSourceId\":\"778185677715-app/lab-alb01/70007e49db426320\",\"ruleGroupList\":[{\"ruleGroupId\":\"AWS#AWSManagedRulesCommonRuleSet\",\"terminatingRule\":null,\"nonTerminatingMatchingRules\":[],\"excludedRules\":null,\"customerConfig\":null}],\"rateBasedRuleList\":[],\"nonTerminatingMatchingRules\":[],\"requestHeadersInserted\":null,\"responseCodeSent\":null,\"httpRequest\":{\"clientIp\":\"176.65.148.161\",\"country\":\"NL\",\"headers\":[{\"name\":\"Host\",\"value\":\"thedawgs2025.click\"},{\"name\":\"User-Agent\",\"value\":\"Mozilla/5.0 (compatible; Let's Encrypt validation server; +https://www.letsencrypt.org)\"},{\"name\":\"Accept\",\"value\":\"*/*\"},{\"name\":\"Range\",\"value\":\"bytes=0-2048\"},{\"name\":\"Referer\",\"value\":\"http://thedawgs2025.click\"}],\"uri\":\"/\",\"args\":\"\",\"httpVersion\":\"HTTP/1.1\",\"httpMethod\":\"GET\",\"requestId\":\"1-698d4575-7f979b3e037fae190b650fe6\",\"fragment\":\"\",\"scheme\":\"https\",\"host\":\"thedawgs2025.click\"},\"ja3Fingerprint\":\"20b279993ae2e137e62b9647c6d768fb\",\"ja4Fingerprint\":\"t13d131100_f57a46bbacb6_ab7e3b40a677\"}",
            "ingestionTime": 1770866049637,
            "eventId": "39491632276395754103234409699650525077428869782045458432"
        },
        {
            "logStreamName": "us-east-1_lab-waf01_0",
            "timestamp": 1770866037228,
            "message": "{\"timestamp\":1770866037228,\"formatVersion\":1,\"webaclId\":\"arn:aws:wafv2:us-east-1:778185677715:regional/webacl/lab-waf01/3b0f2686-6523-4553-800f-7467dc8849dc\",\"terminatingRuleId\":\"Default_Action\",\"terminatingRuleType\":\"REGULAR\",\"action\":\"ALLOW\",\"terminatingRuleMatchDetails\":[],\"httpSourceName\":\"ALB\",\"httpSourceId\":\"778185677715-app/lab-alb01/70007e49db426320\",\"ruleGroupList\":[{\"ruleGroupId\":\"AWS#AWSManagedRulesCommonRuleSet\",\"terminatingRule\":null,\"nonTerminatingMatchingRules\":[],\"excludedRules\":null,\"customerConfig\":null}],\"rateBasedRuleList\":[],\"nonTerminatingMatchingRules\":[],\"requestHeadersInserted\":null,\"responseCodeSent\":null,\"httpRequest\":{\"clientIp\":\"176.65.148.161\",\"country\":\"NL\",\"headers\":[{\"name\":\"Host\",\"value\":\"app.thedawgs2025.click\"},{\"name\":\"User-Agent\",\"value\":\"Mozilla/5.0 (compatible; Let's Encrypt validation server; +https://www.letsencrypt.org)\"},{\"name\":\"Accept\",\"value\":\"*/*\"},{\"name\":\"Range\",\"value\":\"bytes=0-2048\"},{\"name\":\"Referer\",\"value\":\"http://app.thedawgs2025.click\"}],\"uri\":\"/\",\"args\":\"\",\"httpVersion\":\"HTTP/1.1\",\"httpMethod\":\"GET\",\"requestId\":\"1-698d4575-0f78622f4de64d855363e200\",\"fragment\":\"\",\"scheme\":\"https\",\"host\":\"app.thedawgs2025.click\"},\"ja3Fingerprint\":\"20b279993ae2e137e62b9647c6d768fb\",\"ja4Fingerprint\":\"t13d131100_f57a46bbacb6_ab7e3b40a677\"}",
            "ingestionTime": 1770866050813,
            "eventId": "39491632276953272733197675279610653222511951013292605440"
        }
    ],
    "searchedLogStreams": [],
    "NextToken": "eyJuZXh0VG9rZW4iOiBudWxsLCAiYm90b190cnVuY2F0ZV9hbW91bnQiOiAyMH0="
}

Kept wondering why no WAF was being was being provisioned via Terraform. Low and behold the variable was set to false. I had conflated it with the logging enablement flag until re-inspecting and realized it was the WAF


=== Running Gate 1/2: secrets_and_role ===

=== SEIR Gate: Secrets + EC2 Role Verification ===
Timestamp (UTC): 2026-02-12T05:05:51Z
Region:          us-east-1
Instance ID:      i-0e5776c9136139256
Secret ID:       lab/rds/mysql
Resolved Role:   (none)
Caller ARN:      arn:aws:iam::778185677715:user/awscli
-----------------------------------------------
PASS: aws sts get-caller-identity succeeded (credentials OK).
PASS: secret exists and is describable (lab/rds/mysql).
INFO: rotation requirement disabled (REQUIRE_ROTATION=false).
PASS: no resource policy found (OK) or not applicable (lab/rds/mysql).
INFO: on-instance checks skipped (not running as expected role on EC2).

Warnings:
  - WARN: expected role unknown; cannot validate caller role context.

Failures:
  - FAIL: instance has NO IAM instance profile attached ( i-0e5776c9136139256).

RESULT: FAIL
===============================================

Wrote: gate_result.json
=== Running Gate 2/2: network_db ===

=== SEIR Gate: Network + RDS Verification ===
Timestamp (UTC): 2026-02-12T05:06:14Z
Region:          us-east-1
EC2 Instance:     i-0e5776c9136139256
RDS Instance:    lab-rds01
Engine:          mysql
DB Port:         3306
Caller ARN:      arn:aws:iam::778185677715:user/awscli
-------------------------------------------
PASS: aws sts get-caller-identity succeeded (credentials OK).
PASS: RDS instance exists (lab-rds01).
PASS: RDS is not publicly accessible (PubliclyAccessible=False).
INFO: using DB_PORT override = 3306.
PASS: RDS security groups resolved (lab-rds01): sg-03572076bce3e29c0
INFO: private subnet check disabled (CHECK_PRIVATE_SUBNETS=false).

Failures:
  - FAIL: could not resolve EC2 security groups for  i-0e5776c9136139256.

RESULT: FAIL
===========================================

Wrote: gate_result.json