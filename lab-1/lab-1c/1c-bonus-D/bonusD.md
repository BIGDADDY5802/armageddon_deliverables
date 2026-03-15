app_url_http = "http://app.thedawgs2025.click"
app_url_https = "https://app.thedawgs2025.click"
app_urls = {
  "alb_direct" = "http://lab-alb01-1790178507.us-east-1.elb.amazonaws.com"
  "http" = "http://app.thedawgs2025.click"
  "https" = "https://app.thedawgs2025.click"
}
base_domain = "thedawgs2025.click"
dawgs-armageddon_alb_dns_name = "lab-alb01-1790178507.us-east-1.elb.amazonaws.com"
dawgs-armageddon_apex_url_https = "https://thedawgs2025.click"
dawgs-armageddon_dashboard_name = "lab-dashboard01"
dawgs-armageddon_ec2_instance_id = "i-0a88b975ec3f1ce17"
dawgs-armageddon_ec2_private_instance_id = "i-0e32069f6d357132f"
dawgs-armageddon_log_group_name = "/aws/ec2/lab-rds-app"
dawgs-armageddon_private_subnet_ids = [
  "subnet-0fad1ee81106d4597",
  "subnet-05d6c6bbdc6b7e7db",
]
dawgs-armageddon_public_subnet_ids = [
  "subnet-08cab93b9eef407ee",
  "subnet-0ccf4257dfadcee2a",
]
dawgs-armageddon_rds_endpoint = "lab-rds01.c89ykq22i31z.us-east-1.rds.amazonaws.com"
dawgs-armageddon_sns_topic_arn = "arn:aws:sns:us-east-1:778185677715:lab-db-incidents"
dawgs-armageddon_target_group_arn = "arn:aws:elasticloadbalancing:us-east-1:778185677715:targetgroup/lab-tg01/9ee0f96c7c0b3a9b"
dawgs-armageddon_vpc_id = "vpc-08fb966c40ac6e647"
dawgs-armageddon_waf_arn = "arn:aws:wafv2:us-east-1:778185677715:regional/webacl/lab-waf01/555be549-3ccf-45b8-9835-d9f977b9a0a3"
lb_url = "http://lab-alb01-1790178507.us-east-1.elb.amazonaws.com"

load balancer arn - arn:aws:elasticloadbalancing:us-east-1:778185677715:loadbalancer/app/lab-alb01/4cebea6c14f86f38


aws route53 list-resource-record-sets \
    --hosted-zone-id Z0717862367KSPKDBWGDE \
    --query "ResourceRecordSets[?Name=='thedawgs2025.click.']"

[
    {
        "Name": "thedawgs2025.click.",
        "Type": "A",
        "AliasTarget": {
            "HostedZoneId": "Z35SXDOTRQ7X7K",
            "DNSName": "lab-alb01-1790178507.us-east-1.elb.amazonaws.com.",
            "EvaluateTargetHealth": true
        }
    },
    {
        "Name": "thedawgs2025.click.",
        "Type": "NS",
        "TTL": 172800,
        "ResourceRecords": [
            {
                "Value": "ns-1276.awsdns-31.org."
            },
            {
                "Value": "ns-1882.awsdns-43.co.uk."
            },
            {
                "Value": "ns-974.awsdns-57.net."
            },
            {
                "Value": "ns-185.awsdns-23.com."
            }
        ]
    },
    {
        "Name": "thedawgs2025.click.",
        "Type": "SOA",
        "TTL": 900,
        "ResourceRecords": [
            {
                "Value": "ns-1276.awsdns-31.org. awsdns-hostmaster.amazon.com. 1 7200 900 1209600 86400"
            }
        ]
    }
]


aws elbv2 describe-load-balancers \
    --names lab-alb01 \
    --query "LoadBalancers[0].LoadBalancerArn"

"arn:aws:elasticloadbalancing:us-east-1:778185677715:loadbalancer/app/lab-alb01/4cebea6c14f86f38"



aws elbv2 describe-load-balancers \
  --load-balancer-arns arn:aws:elasticloadbalancing:us-east-1:778185677715:loadbalancer/app/lab-alb01/4cebea6c14f86f38 \
  --query "LoadBalancers[].State" \
  --output table

-----------------------
|DescribeLoadBalancers|
+---------------------+
|        Code         |
+---------------------+
|  active             |
+---------------------+

aws elbv2 describe-load-balancer-attributes \
  --load-balancer-arn arn:aws:elasticloadbalancing:us-east-1:778185677715:loadbalancer/app/lab-alb01/4cebea6c14f86f38 \
  --query "Attributes[?Key=='access_logs.s3.enabled'].{Enabled:Value}" \
  --output table

--------------------------------
|DescribeLoadBalancerAttributes|
+------------------------------+
|            Enabled           |
+------------------------------+
|  true                        |
+------------------------------+


aws elbv2 describe-load-balancer-attributes \
  --load-balancer-arn arn:aws:elasticloadbalancing:us-east-1:778185677715:loadbalancer/app/lab-alb01/4cebea6c14f86f38 \
  --output table

---------------------------------------------------------------------------------------------
|                              DescribeLoadBalancerAttributes
            |
+-------------------------------------------------------------------------------------------+
||                                       Attributes
           ||
|+-----------------------------------------------------------+-----------------------------+|
||                            Key                            |            Value            ||
|+-----------------------------------------------------------+-----------------------------+|
||  access_logs.s3.enabled                                   |  true
           ||
||  access_logs.s3.bucket                                    |  lab-alb-logs-778185677715  ||
||  access_logs.s3.prefix                                    |  alb-access-logs            ||
||  health_check_logs.s3.enabled                             |  false
           ||
       |                             ||
       |                             ||
       |  60                         ||
       |  false                      ||
       |  true                       ||
       |  false                      ||
       |  false                      ||
       |  false                      ||
       |  append                     ||
       |  true                       ||
       |  defensive                  ||
       |  3600                       ||
       |  false                      ||
ed |  false                      ||
       |  false                      ||
       |  false                      ||
       |                             ||
       |                             ||
------------------------+|


curl -I https://thedawgs2025.click
HTTP/1.1 200 OK
Date: Tue, 10 Feb 2026 03:49:56 GMT
Content-Type: text/html; charset=utf-8
Content-Length: 233
Connection: keep-alive
Server: Werkzeug/3.1.5 Python/3.9.25

curl -I https://app.thedawgs2025.click

HTTP/1.1 200 OK
Date: Tue, 10 Feb 2026 03:50:26 GMT
Content-Type: text/html; charset=utf-8
Content-Length: 233
Connection: keep-alive
Server: Werkzeug/3.1.5 Python/3.9.25

aws s3 ls s3://lab-alb-logs-778185677715/alb-access-logs/AWSLogs/778185677715/elasticloadbalancing/ --recursive | head
                           
2026-02-09 21:24:39        857 alb-access-logs/AWSLogs/778185677715/elasticloadbalancing/us-east-1/2026/02/10/778185677715_elasticloadbalancing_us-east-1_app.lab-alb01.4cebea6c14f86f38_20260210T0325Z_3.237.56.85_2153pwuf.log.gz
2026-02-09 21:30:09        410 alb-access-logs/AWSLogs/778185677715/elasticloadbalancing/us-east-1/2026/02/10/778185677715_elasticloadbalancing_us-east-1_app.lab-alb01.4cebea6c14f86f38_20260210T0330Z_3.237.56.85_5ymqr9u3.log.gz
2026-02-09 21:35:09       2266 alb-access-logs/AWSLogs/778185677715/elasticloadbalancing/us-east-1/2026/02/10/778185677715_elasticloadbalancing_us-east-1_app.lab-alb01.4cebea6c14f86f38_20260210T0335Z_3.237.56.85_4zzciffv.log.gz
2026-02-09 21:35:10       3281 alb-access-logs/AWSLogs/778185677715/elasticloadbalancing/us-east-1/2026/02/10/778185677715_elasticloadbalancing_us-east-1_app.lab-alb01.4cebea6c14f86f38_20260210T0335Z_54.172.165.195_y3uf97gw.log.gz
2026-02-09 21:40:09       1015 alb-access-logs/AWSLogs/778185677715/elasticloadbalancing/us-east-1/2026/02/10/778185677715_elasticloadbalancing_us-east-1_app.lab-alb01.4cebea6c14f86f38_20260210T0340Z_3.237.56.85_5sqtwaq3.log.gz
2026-02-09 21:40:10       1113 alb-access-logs/AWSLogs/778185677715/elasticloadbalancing/us-east-1/2026/02/10/778185677715_elasticloadbalancing_us-east-1_app.lab-alb01.4cebea6c14f86f38_20260210T0340Z_54.172.165.195_fmzc72ap.log.gz
2026-02-09 21:45:09        579 alb-access-logs/AWSLogs/778185677715/elasticloadbalancing/us-east-1/2026/02/10/778185677715_elasticloadbalancing_us-east-1_app.lab-alb01.4cebea6c14f86f38_20260210T0345Z_3.237.56.85_38r7x2jf.log.gz
2026-02-09 21:45:10        703 alb-access-logs/AWSLogs/778185677715/elasticloadbalancing/us-east-1/2026/02/10/778185677715_elasticloadbalancing_us-east-1_app.lab-alb01.4cebea6c14f86f38_20260210T0345Z_54.172.165.195_3c4akwkd.log.gz
2026-02-09 21:50:09       1343 alb-access-logs/AWSLogs/778185677715/elasticloadbalancing/us-east-1/2026/02/10/778185677715_elasticloadbalancing_us-east-1_app.lab-alb01.4cebea6c14f86f38_20260210T0350Z_3.237.56.85_1bpsxm3g.log.gz
2026-02-09 21:55:10       1175 alb-access-logs/AWSLogs/778185677715/elasticloadbalancing/us-east-1/2026/02/10/778185677715_elasticloadbalancing_us-east-1_app.lab-alb01.4cebea6c14f86f38_20260210T0355Z_3.237.56.85_4phdca8k.log.gz


Why this matters to YOU (career-critical point)
This is incident response fuel:
  Access logs tell you:
    client IPs
    paths
    response codes
    target behavior
    latency

Combined with WAF logs/metrics and ALB 5xx alarms, you can do real triage:
  “Is it attackers, misroutes, or downstream failure?”