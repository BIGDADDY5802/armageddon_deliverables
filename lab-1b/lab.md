Lab 1b — Operations, Secrets, and Incident Response
Prerequisite: Lab 1a completed and verified

1. Project Overview (What This Lab Is About)
In Lab 1a, you built a working system.
In Lab 1b, you will operate, observe, break, and recover that system.
You will extend your EC2 → RDS application to include:
  Dual secret storage
    AWS Systems Manager Parameter Store
    AWS Secrets Manager
  Centralized logging via CloudWatch Logs
  Automated alarms when database connectivity fails
  Incident-response actions using previously saved values

This lab simulates what happens after deployment, which is where most real cloud work lives.

2. Why This Lab Exists (Real-World Context)
Most cloud failures are not caused by:
  Bad code
  Missing features
  Wrong instance sizes

They are caused by:
  Credential issues
  Secret rotation failures
  Misconfigured access
  Silent connectivity loss
  Poor observability

This lab teaches you how to design for failure, detect it early, and recover using stored configuration data.


3. Workforce Relevance (Why Employers Care)
This Lab Maps Directly to Job Responsibilities
In the workforce, you will be expected to:
  Know where secrets live
  Understand why multiple secret systems exist
  Diagnose outages using logs and metrics
  Respond to incidents without redeploying everything
  Restore service quickly using known-good configuration

This is the difference between:
  “I can deploy AWS resources”
  and
  “I can keep systems running under pressure”


4. Parameter Store vs Secrets Manager (Conceptual)
You will store database connection values in both systems and intentionally use them during recovery.
AWS Systems Manager Parameter Store
  Best for:
    Configuration values
    Non-rotating data
    Shared application parameters

  Supports:
    Plain text
    SecureString (encrypted)
    
  Often used for:
    Feature flags
    Endpoints
    Environment configuration

AWS Secrets Manager
  Best for:
    Credentials
    Passwords
    Rotating secrets

  Supports:
    Automatic rotation
    Tight audit integration

  Often used for:
    Database passwords
    API keys

Industry Reality:
Many environments use both — intentionally.


5. What You Are Building in Lab 1b
New Capabilities Added
  1) Store DB values in Parameter Store
  2) Store DB credentials in Secrets Manager
  3) Log application DB connection failures to CloudWatch Logs
  4) Create a CloudWatch Alarm that triggers when failures exceed a threshold
  5) Simulate a DB outage or credential failure
  6) Recover the system using saved parameters/secrets without redeploying EC2

This is operations engineering, not app development.

6. Expected Deliverables (What You Must Produce)
A. Configuration Artifacts
  Parameter Store entries for:
    DB endpoint
    DB port
    DB name

  Secrets Manager secret for:
    DB username/password

B. Observability
  Application logs visible in CloudWatch Logs
  Explicit log entries on DB connection failure
  CloudWatch Alarm configured on error count

C. Incident Response Proof
  Evidence of a simulated failure
  Evidence of alarm triggering
  Evidence of successful recovery using stored values

7. Technical Verification Using AWS CLI (Required)
You must verify everything via CLI — not screenshots alone. What? You think this is easy?

7.1 Verify Parameter Store Values

    aws ssm get-parameters \
      --names /lab/db/endpoint /lab/db/port /lab/db/name \
      --with-decryption

Expected:
  Parameter names returned
  Correct DB endpoint and port

  7.2 Verify Secrets Manager Value
  
      aws secretsmanager get-secret-value \
      --secret-id lab/rds/mysql

Expected:
  JSON output
  Fields: 
    username 
    password 
    host 
    port

7.3 Verify EC2 Can Read Both Systems
From EC2:

    aws ssm get-parameter --name /lab/db/endpoint
    aws secretsmanager get-secret-value --secret-id lab/rds/mysql

Expected:
  Both commands succeed
  No AccessDeniedException
  
7.4 Verify CloudWatch Log Group Exists
    
    aws logs describe-log-groups \
      --log-group-name-prefix /aws/ec2/lab-rds-app

Expected:
  Log group present

7.5 Verify DB Failure Logs Appear
Simulate failure (examples):
  Stop RDS
  Change DB password in Secrets Manager without updating DB
  Block SG temporarily

Then check logs:

    aws logs filter-log-events \
      --log-group-name /aws/ec2/lab-rds-app \
      --filter-pattern "ERROR"

Expected:
  Explicit DB connection failure messages
  
7.6 Verify CloudWatch Alarm

    aws cloudwatch describe-alarms \
      --alarm-name-prefix lab-db-connection

Expected:
  Alarm present
  State transitions to ALARM during failure

7.7 Incident Recovery Verification
After restoring correct credentials or connectivity:

    curl http://<EC2_PUBLIC_IP>/list

Expected:
  Application resumes normal operation
  No redeployment required

8. Incident-Response Focus (What This Lab Teaches)
During recovery, you must:
  Identify failure source via logs
  Retrieve correct values from:
    Parameter Store
    Secrets Manager
  Restore service using configuration — not guesswork

This mirrors real on-call workflows.

9. Common Failure Modes (And Why They Matter)
| Failure                    | Real-World Meaning        |
| -------------------------- | ------------------------- |
| Alarm never fires          | Poor observability        |
| Logs lack detail           | Weak incident diagnostics |
| EC2 can’t read parameters  | IAM misdesign             |
| Recovery requires redeploy | Fragile architecture      |

10. What Completing Lab 1b Proves
If you complete this lab, you can confidently say:
  “I can operate, monitor, and recover AWS workloads using proper secret management and observability.”

That is mid-level engineer capability, not entry-level.

11. Reflection Questions: Answer all of these
  A) Why might Parameter Store still exist alongside Secrets Manager?
  B) What breaks first during secret rotation?
  C) Why should alarms be based on symptoms instead of causes?  
  D) How does this lab reduce mean time to recovery (MTTR)?
  E) What would you automate next?
