Lab 1b — Incident Response Scenario
Prerequisite: Lab 1a + Lab 1b infrastructure completed

“Anyone can deploy. Professionals recover.”


0. Scenario (Read This First)

You are now on call. Chewbacca is playing with you.

The system was working yesterday.
No infrastructure changes were announced.
Users are reporting failures.

Your job is not to redeploy.
Your job is not to guess.
Your job is to observe, diagnose, and recover using the tools already in place.

Everything you need to recover already exists in AWS.


PART I — Incident Scenario (What Messed Up)
Incident Title
Database Connectivity Failure — Production Application Unavailable
Symptoms Reported
    Application intermittently returns errors
    /list endpoint fails or hangs
    No recent code changes
    EC2 instance is still running

Constraints
  You may NOT:
      Recreate EC2
      Recreate RDS
      Hardcode credentials

You MUST:
    Use logs
    Use alarms
    Use stored configuration values

PART II — Incident Injection (Group Leader / Auto-Grader)
Choose one of the following to trigger the incident:
  Option A — Secret Drift (Recommended)
    Change DB password in Secrets Manager
    Do not update the actual RDS password

  Option B — Network Isolation
    Remove EC2 security group from RDS inbound rule (TCP 3306)

  Option C — DB Interruption
    Stop RDS instance temporarily

Students are not told which failure was injected.

PART III — Monitoring & Alerting (SNS + PagerDuty Simulation)
  1. SNS Alert Channel
    SNS Topic
    Name: lab-db-incidents
    aws sns create-topic --name lab-db-incidents
    Email Subscription (PagerDuty Simulation)

          aws sns subscribe \
            --topic-arn <TOPIC_ARN> \
            --protocol email \
            --notification-endpoint your-email@example.com

    This simulates PagerDuty / OpsGenie paging an engineer.

2. CloudWatch Alarm → SNS
Alarm Concept
Trigger when:
  DB connection errors ≥ 3 in 5 minutes
Alarm Creation (example)

        aws cloudwatch put-metric-alarm \
          --alarm-name lab-db-connection-failure \
          --metric-name DBConnectionErrors \
          --namespace Lab/RDSApp \
          --statistic Sum \
          --period 300 \
          --threshold 3 \
          --comparison-operator GreaterThanOrEqualToThreshold \
          --evaluation-periods 1 \
          --alarm-actions <SNS_TOPIC_ARN>

Expected Behavior
  Alarm transitions to ALARM
  SNS notification sent
  Student receives alert email

PART IV — Mandatory Incident Runbook
Students must follow this order. Deviations lose points.

RUNBOOK SECTION 1 — Acknowledge
1.1 Confirm Alert
  aws cloudwatch describe-alarms \
  --alarm-name lab-db-connection-failure \
  --query "MetricAlarms[].StateValue"

Expected:
  ALARM


RUNBOOK SECTION 2 — Observe
2.1 Check Application Logs

      aws logs filter-log-events \
      --log-group-name /aws/ec2/lab-rds-app \
      --filter-pattern "ERROR"

Expected:
  Clear DB connection failure messages

2.2 Identify Failure Type
Students must classify:
  Credential failure?
  Network failure?
  Database availability failure?
This classification is graded.

RUNBOOK SECTION 3 — Validate Configuration Sources
3.1 Retrieve Parameter Store Values
    
      aws ssm get-parameters \
        --names /lab/db/endpoint /lab/db/port /lab/db/name \
        --with-decryption

Expected:
  Endpoint + port returned

3.2 Retrieve Secrets Manager Values

      aws secretsmanager get-secret-value \
      --secret-id lab/rds/mysql

Expected:
  Username/password visible
  Compare against known-good state

RUNBOOK SECTION 4 — Containment
4.1 Prevent Further Damage
  Do not restart EC2 blindly
  Do not rotate secrets again
  Do not redeploy infrastructure

Students must explicitly state:
  “System state preserved for recovery.”


RUNBOOK SECTION 5 — Recovery
Recovery Paths (Depends on Root Cause)
    If Credential Drift
        Update RDS password to match Secrets Manager
        OR
        Update Secrets Manager to known-good value

    If Network Block
        Restore EC2 security group access to RDS on 3306

    If DB Stopped
        Start RDS and wait for available

Verify Recovery
    curl http://<EC2_PUBLIC_IP>/list

Expected:
    Application returns data
    No errors

RUNBOOK SECTION 6 — Post-Incident Validation
6.1 Confirm Alarm Clears

    aws cloudwatch describe-alarms \
      --alarm-name lab-db-connection-failure \
      --query "MetricAlarms[].StateValue"

Expected:
    OK

6.2 Confirm Logs Normalize

    aws logs filter-log-events \
      --log-group-name /aws/ec2/lab-rds-app \
      --filter-pattern "ERROR"

Expected:
    No new errors


PART V — Grading Rubric (100 Points)
| Category                       | Points |
| ------------------------------ | ------ |
| Alarm acknowledged via CLI     | 10     |
| Correct failure classification | 20     |
| Logs used correctly            | 15     |
| Parameter Store validated      | 10     |
| Secrets Manager validated      | 10     |
| Correct recovery action        | 20     |
| No redeploy / no guesswork     | 10     |
| Clear incident summary         | 5      |

PART VI — Required Incident Report (Short)
Students must submit:
    Incident Summary
    What failed?
    How was it detected?
    Root cause
    Time to recovery

Preventive Action
    One improvement to reduce MTTR
    One improvement to prevent recurrence

PART VII — What This Actually Teaches
By completing this lab, students demonstrate:
    On-call discipline
    Root cause analysis
    Cloud-native recovery
    Proper secret handling
    Operational maturity

This is exactly what separates:
    “I passed an AWS cert”
    from
    “I can be trusted with production.”
