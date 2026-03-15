Student verification (CLI)
Student verification (CLI)
1) Confirm hosted zone exists (if managed)
  aws route53 list-hosted-zones-by-name \
    --dns-name thedawgs2025.click \
    --query "HostedZones[].Id"

[
    "/hostedzone/Z0717862367KSPKDBWGDE"
]


2) Confirm app record exists
  aws route53 list-resource-record-sets \
  --hosted-zone-id Z0717862367KSPKDBWGDE \
  --query "ResourceRecordSets[?Name=='app.thedawgs2025.click.']"

[
    {
        "Name": "app.thedawgs2025.click.",
        "Type": "A",
        "AliasTarget": {
            "HostedZoneId": "Z35SXDOTRQ7X7K",
            "DNSName": "lab-alb01-1790178507.us-east-1.elb.amazonaws.com.",
            "EvaluateTargetHealth": true
        }
    }
]

aws acm list-certificates --query 'CertificateSummaryList[].CertificateArn' --output table

-----------------------------------------------------------------------------------------
|                                   ListCertificates
        |
+---------------------------------------------------------------------------------------+
|  arn:aws:acm:us-east-1:778185677715:certificate/d7353b1b-c8d0-4569-8576-f6b611931244  |
|  arn:aws:acm:us-east-1:778185677715:certificate/bbb26471-1bda-4338-b81f-57aab79690ad  |
|  arn:aws:acm:us-east-1:778185677715:certificate/4830e7e8-381c-4b89-b540-2b146c5ffea5  |
+---------------------------------------------------------------------------------------+




3) Confirm certificate issued
  aws acm describe-certificate \
  --certificate-arn arn:aws:acm:us-east-1:778185677715:certificate/d7353b1b-c8d0-4569-8576-f6b611931244 \
  --query "Certificate.Status"

Expected: ISSUED

aws acm describe-certificate \
  --certificate-arn arn:aws:acm:us-east-1:778185677715:certificate/bbb26471-1bda-4338-b81f-57aab79690ad \
  --query "Certificate.Status"

"ISSUED"

aws acm describe-certificate \
  --certificate-arn arn:aws:acm:us-east-1:778185677715:certificate/4830e7e8-381c-4b89-b540-2b146c5ffea5 \
  --query "Certificate.Status"

"ISSUED"


4) Confirm HTTPS works
  curl -I https://app.thedawgs2025.click

HTTP/1.1 200 OK
Date: Tue, 10 Feb 2026 04:33:56 GMT
Content-Type: text/html; charset=utf-8
Content-Length: 233
Connection: keep-alive
Server: Werkzeug/3.1.5 Python/3.9.25


What YOU must understand (career point)
This is exactly how companies do it:
  DNS points to ingress
  TLS via ACM
  ALB handles secure public entry
  private compute does the work
  WAF + alarms defend and alert