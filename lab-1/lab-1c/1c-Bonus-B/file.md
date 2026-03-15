### 1c_bonus_B

Here, it is assumed that you have your own URL. I'm using chewbacca-growl.com as an example


Alright — Lab 1C-Bonus-B (and yes, we’ll assume the students own chewbacca-growl.com).
This turns your stack into a real enterprise pattern:
  Public ALB (internet-facing)
  Private EC2 targets (no public IP)
  TLS with ACM for chewbacca-growl.com
  WAF attached to ALB
  CloudWatch Dashboard
  SNS alarm on ALB 5xx spikes

This is exactly how modern companies ship: IaC + private compute + managed ingress + TLS + WAF + monitoring + paging. 
If you can submit this in Terraform, you’re no longer “a student who clicked around”— you’re a junior cloud engineers.

Below is a Terraform skeleton overlay you can add to your existing 1C + Bonus-A repo.

Add 1c_bonus_variables.tf (append to variables.tf)

Add file: bonus_b.tf
This assumes you already have from 1C / Bonus-A:
    aws_vpc.chewbacca_vpc01
    aws_subnet.chewbacca_public_subnets
    aws_subnet.chewbacca_private_subnets
    aws_security_group.chewbacca_ec2_sg01 (for private EC2)
    aws_instance.chewbacca_ec201_private_bonus (private EC2 instance)
    aws_sns_topic.chewbacca_sns_topic01 (SNS topic)

Add file: Bonus-B_outputs.tf

What you must implement (so you learn the right pain)
TLS (ACM) validation for app.chewbacca-growl.com
You gave them the domain; they must complete one of:
  DNS validation (best): create Route53 hosted zone + validation records in Terraform
  Email validation (acceptable): do it manually, then Terraform continues (less ideal)

Suggested student path (DNS):
  Create Route53 Hosted Zone for chewbacca-growl.com
  Add aws_route53_record for ACM validation
  Add a CNAME (or ALIAS) pointing app.chewbacca-growl.com → ALB DNS

  I didn’t auto-add Route53 resources because some students may manage DNS outside Route53. 
  But if you want, I can provide a Route53 skeleton too (Hosted Zone + records + ACM validation), 
  Chewbacca-style.

ALB SG rules
you must add:
  inbound 80/443 from 0.0.0.0/0
  outbound to targets on app port

EC2 runs app on the target port
They must ensure their user-data/app listens on port 80 (or update TG/SG accordingly).

Verification commands (CLI) for Bonus-B
1) ALB exists and is active
   
      aws elbv2 describe-load-balancers \
        --names lab-alb01 \
        --query "LoadBalancers[0].State.Code"

Output:

"active"

3) HTTPS listener exists on 443
   
      aws elbv2 describe-listeners \
        --load-balancer-arn  arn:aws:elasticloadbalancing:us-east-1:778185677715:loadbalancer/app/lab-alb01/3d9b38a83dbab0f6 
        --query "Listeners[].Port" \
	--output text

Output:

{
    "Listeners": [
        {
            "ListenerArn": "arn:aws:elasticloadbalancing:us-east-1:778185677715:listener/app/lab-alb01/3d9b38a83dbab0f6/d51f0cda88d24f49",
            "LoadBalancerArn": "arn:aws:elasticloadbalancing:us-east-1:778185677715:loadbalancer/app/lab-alb01/3d9b38a83dbab0f6",
            "Port": 80,
            "Protocol": "HTTP",
            "DefaultActions": [
                {
                    "Type": "redirect",
                    "Order": 1,
                    "RedirectConfig": {
                        "Protocol": "HTTPS",
                        "Port": "443",
                        "Host": "#{host}",
                        "Path": "/#{path}",
                        "Query": "#{query}",
                        "StatusCode": "HTTP_301"
                    }
                }
            ]
        },
        {
            "ListenerArn": "arn:aws:elasticloadbalancing:us-east-1:778185677715:listener/app/lab-alb01/3d9b38a83dbab0f6/eb1d71accfb6f63a",
            "LoadBalancerArn": "arn:aws:elasticloadbalancing:us-east-1:778185677715:loadbalancer/app/lab-alb01/3d9b38a83dbab0f6",
            "Port": 443,
            "Protocol": "HTTPS",
            "Certificates": [
                {
                    "CertificateArn": "arn:aws:acm:us-east-1:778185677715:certificate/242aad40-1328-4049-a0c8-0efa24fade61"
                }
            ],
            "SslPolicy": "ELBSecurityPolicy-TLS13-1-2-2021-06",
            "DefaultActions": [
                {
                    "Type": "forward",
                    "TargetGroupArn": "arn:aws:elasticloadbalancing:us-east-1:778185677715:targetgroup/lab-tg01/2cf7a65ef36a133f",
                    "Order": 1,
                    "ForwardConfig": {
                        "TargetGroups": [
                            {
                                "TargetGroupArn": "arn:aws:elasticloadbalancing:us-east-1:778185677715:targetgroup/lab-tg01/2cf7a65ef36a133f",
                                "Weight": 1
                            }
                        ],
                        "TargetGroupStickinessConfig": {
                            "Enabled": false
                        }
                    }
                }
            ],
            "MutualAuthentication": {
                "Mode": "off"
            }
        }
    ]
}


bash: --query: command not found

The bash: --query: command not found error suggests there's an issue with how bash is parsing the command.




4) Target is healthy
   
      aws elbv2 describe-target-health \
        --target-group-arn  arn:aws:elasticloadbalancing:us-east-1:778185677715:targetgroup/lab-tg01/2cf7a65ef36a133f

{
    "TargetHealthDescriptions": [
        {
            "Target": {
                "Id": "i-0be5027784aea2f9c",
                "Port": 80
            },
            "HealthCheckPort": "80",
            "TargetHealth": {
                "State": "unhealthy",
                "Reason": "Target.ResponseCodeMismatch",
                "Description": "Health checks failed with these codes: [404]"
            },
            "AdministrativeOverride": {
                "State": "no_override",
                "Reason": "AdministrativeOverride.NoOverride",
                "Description": "No override is currently active on target"
            }
        }
    ]
}

health check is looking for /health path and expecting HTTP codes 200-399. The 404 error means the /health endpoint doesn't exist on your web server.




5) WAF attached
   
      aws wafv2 get-web-acl-for-resource \
        --resource-arn <ALB_ARN>

7) Alarm created (ALB 5xx)
   
      aws cloudwatch describe-alarms \
        --alarm-name-prefix chewbacca-alb-5xx

9) Dashboard exists
    
      aws cloudwatch list-dashboards \
        --dashboard-name-prefix chewbacca



$aws elbv2 describe-load-balancers \
  --query "LoadBalancers[].{Name:LoadBalancerName,ARN:LoadBalancerArn}" \
  --output table

-------------------------------------------------------------------------------------------------------------
|                                           DescribeLoadBalancers
                            |
+------+----------------------------------------------------------------------------------------------------+
|  ARN |  arn:aws:elasticloadbalancing:us-east-1:778185677715:loadbalancer/app/lab-alb01/3d9b38a83dbab0f6   |
|  Name|  lab-alb01
                            |
+------+----------------------------------------------------------------------------------------------------+


 $aws elbv2 describe-rules --listener-arn arn:aws:elasticloadbalancing:us-east-1:778185677715:listener/app/lab-alb01/3d9b38a83dbab0f6/eb1d71accfb6f63a
{
    "Rules": [
        {
            "RuleArn": "arn:aws:elasticloadbalancing:us-east-1:778185677715:listener-rule/app/lab-alb01/3d9b38a83dbab0f6/eb1d71accfb6f63a/eb6a431e59e6e5c6",
            "Priority": "default",
            "Conditions": [],
            "Actions": [
                {
                    "Type": "forward",
                    "TargetGroupArn": "arn:aws:elasticloadbalancing:us-east-1:778185677715:targetgroup/lab-tg01/2cf7a65ef36a133f",
                    "Order": 1,
                    "ForwardConfig": {
                        "TargetGroups": [
                            {
                                "TargetGroupArn": "arn:aws:elasticloadbalancing:us-east-1:778185677715:targetgroup/lab-tg01/2cf7a65ef36a133f",
                                "Weight": 1
                            }
                        ],
                        "TargetGroupStickinessConfig": {
                            "Enabled": false
                        }
                    }
                }
            ],
            "IsDefault": true,
            "Transforms": []
        }
    ]
}


