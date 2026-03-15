EC2 → RDS Integration Lab

Foundational Cloud Application Pattern

1) Project Overview (What You Are Building)
  In this lab, you will build a classic cloud application architecture:
  A compute layer running on an Amazon EC2 instance
  A managed relational database hosted on Amazon RDS
  Secure connectivity between the two using VPC networking and security groups
  Credential management using AWS Secrets Manager
  A simple application that writes and reads data from the database

The application itself is intentionally minimal.
The learning value is not the app, but the cloud infrastructure pattern it demonstrates.

This pattern appears in:
  Internal enterprise tools
  SaaS products
  Backend APIs
  Legacy modernization projects
  Lift-and-shift workloads
  Cloud security assessments

If you can build and verify this pattern, you understand the foundation of real AWS workloads.

2) Why This Lab Exists (Industry Context)
This Is One of the Most Common Interview Architectures
Employers routinely expect engineers to understand:
  How EC2 communicates with RDS
  How database access is restricted
  Where credentials are stored
  How connectivity is validated
  How failures are debugged

You will encounter variations of this question in:
  AWS Solutions Architect interviews
  Cloud Security roles
  DevOps and SRE interviews
  Incident response scenarios

If you cannot explain this pattern clearly, you will struggle in real cloud environments.

3) Why This Pattern Matters to the Workforce
What Employers Are Actually Testing
This lab evaluates whether you understand:

Skill	Why                 It Matters
Security Groups	          Primary AWS network security boundary
Least Privilege	          Prevents credential leakage & lateral movement
Managed Databases	        Operational responsibility vs infrastructure
IAM Roles	                Eliminates static credentials
Application-to-DB Trust	  Core of backend security

This is not a toy problem. This is how real systems are built.

4) Architectural Design (Conceptual)
Logical Flow
1. A user sends an HTTP request to an EC2 instance
2. The EC2 application:
    Retrieves database credentials from Secrets Manager
    Connects to the RDS MySQL endpoint
3. Data is written to or read from the database
4. Results are returned to the user

Security Model
  RDS is not publicly accessible
  RDS only allows inbound traffic from the EC2 security group
  EC2 retrieves credentials dynamically via IAM role
  No passwords are stored in code or AMIs

This is intentional friction — security is part of the design.

5) Expected Deliverables (What You Must Produce)
Each student must submit:

A. Infrastructure Proof
  1) EC2 instance running and reachable over HTTP
  2) RDS MySQL instance in the same VPC
  3) Security group rule showing:
    RDS inbound TCP 3306
    Source = EC2 security group (not 0.0.0.0/0)
  IAM role attached to EC2 allowing Secrets Manager access

B. Application Proof
  1) Successful database initialization
  2) Ability to insert records into RDS
  3) Ability to read records from RDS

C. Verification Evidence
  1) CLI output proving connectivity and configuration
  2) Browser output showing database data

6. Technical Verification Using AWS CLI (Mandatory)
You are expected to prove your work using the CLI — not screenshots alone.

6.1 Verify EC2 Instance
aws ec2 describe-instances \
  --filters "Name=tag:Name,Values=lab-ec2-app" \
  --query "Reservations[].Instances[].InstanceId"
Expected:
  Instance ID returned
  Instance state = running

6.2 Verify IAM Role Attached to EC2
aws ec2 describe-instances \
  --instance-ids <INSTANCE_ID> \
  --query "Reservations[].Instances[].IamInstanceProfile.Arn"

Expected:
  ARN of an IAM instance profile (not null)

6.3 Verify RDS Instance State
aws rds describe-db-instances \
  --db-instance-identifier lab-mysql \
  --query "DBInstances[].DBInstanceStatus"

Expected 
  Available

6.4 Verify RDS Endpoint (Connectivity Target)
aws rds describe-db-instances \
  --db-instance-identifier lab-mysql \
  --query "DBInstances[].Endpoint"

Expected:
  Endpoint address
  Port 3306

6.5 Verify Security Group Rules (Critical)
RDS Security Group Inbound Rules
aws ec2 describe-security-groups \
  --group-names sg-rds-lab \
  --query "SecurityGroups[].IpPermissions"

Expected:
  TCP port 3306
  Source referencing EC2 security group ID, not CIDR

6.6 Verify Secrets Manager Access (From EC2)
SSH into EC2 and run:
aws secretsmanager get-secret-value \
  --secret-id lab/rds/mysql

Expected:
  JSON containing:
    username
    password
    host
    port

If this fails, IAM is misconfigured.


6.7 Verify Database Connectivity (From EC2)
Install MySQL client (temporary validation):
sudo dnf install -y mysql

Connect:
mysql -h <RDS_ENDPOINT> -u admin -p

Expected:
  Successful login
  No timeout or connection refused errors

6.8 Verify Data Path End-to-End
From browser:
http://<EC2_PUBLIC_IP>/init
http://<EC2_PUBLIC_IP>/add?note=cloud_labs_are_real
http://<EC2_PUBLIC_IP>/list

Expected:
  Notes persist across refresh
  Data survives application restart

7. Common Failure Modes (And What They Teach)


Failure	                    Lesson
Connection timeout	        Security group or routing issue
Access denied	              IAM or Secrets Manager misconfiguration
App starts but DB fails	    Dependency order matters
Works once then breaks	    Stateless compute vs stateful DB

Every failure here mirrors real production outages.


8. What This Lab Proves About You
  If you complete this lab correctly, you can say:
  “I understand how real AWS applications securely connect compute to managed databases.”

That is a non-trivial claim in the job market.