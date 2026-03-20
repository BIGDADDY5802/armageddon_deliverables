🚀 EC2 → RDS Integration Lab
Student Deliverables

Welcome to the proof that your cloud architecture actually works (and is secure). Let’s show the receipts.

📸 1. Required Screenshots

Capture clear evidence of your setup:

🔐 RDS Security Group Rule

Must show inbound rule with source = lab-ec2-sg01
![](/attachments/security-group.png)

🖥️ EC2 Instance with IAM Role
![](/attachments/instance-role-attached.png)
Confirm the instance has the correct IAM role attached


📝 /list Endpoint Output
![](/attachments/olidip.png)
![](/attachments/newip.png)
Show at least 3 notes returned from your application



🧠 2. Short Answer Questions
A) Why is DB inbound source restricted to the EC2 security group?

Because your database is not a public service — it’s part of your backend.

Only EC2 instances assigned to lab-ec2-sg01 can reach the database on port 3306.
No internet access. No random VPC traffic. Just the application tier.

🍽️ Analogy: The database is the kitchen.
Only the waitstaff (EC2) gets access — not the customers (internet).

B) What port does MySQL use?
3306
C) Why is Secrets Manager better than storing credentials in code or user data?

Because hardcoding secrets is how breaches happen.

User Data: Visible in EC2 console → low security

Source Code: Exposed via Git → high risk

Secrets Manager:

🔒 Encrypted at rest

🎯 Controlled via IAM

🔄 Supports automatic rotation

Bottom line: your app gets credentials securely at runtime, not from exposed storage.

🧾 3. Audit Evidence — Commands

Run these commands and store the outputs as proof of configuration:

aws ec2 describe-security-groups --group-ids <sg-ec2-id> > sg.json
aws rds describe-db-instances --db-instance-identifier lab-rds01 > rds.json
aws secretsmanager describe-secret --secret-id lab/rds/mysql > secret.json
aws ec2 describe-instances --instance-ids <instance-id> > instance.json
aws iam list-attached-role-policies --role-name lab-ec2-role01 > role-policies.json

💡 Tip: Keep these files — they are your audit trail.

🔍 4. Audit Analysis
Why does each rule exist?

🌐 Inbound TCP 80 (0.0.0.0/0):
Allows users anywhere to access your web app via browser.

🔑 Inbound TCP 22 (Your IP only):
Locks SSH access down to just you — no open doors.

What breaks if rules are removed?

❌ Secrets removed:
App cannot authenticate → DB connection fails

❌ SG rule (EC2 → RDS) removed:
Network path is cut → app can’t reach DB

❌ Port 80 removed:
Web app becomes invisible to users

Why is broader access forbidden?

Because every open door is a potential breach.

Following least privilege:

Only required ports are open

Only required sources are allowed

Anything extra = unnecessary risk.

Why does this IAM role exist?

It gives your EC2 instance an identity in AWS.

Without it:

No API access

No Secrets Manager

No secure authentication

🏢 Think of it as a badge — no badge, no entry.

Why can it read this secret?

Because the role has the SecretsManagerReadWrite policy attached, which includes:

secretsmanager:GetSecretValue

AWS evaluates:

✅ Matching "Allow" → access granted

Why can it NOT read other secrets (future state)?

Right now, the policy is overly broad (lab convenience).

In production:

Replace with inline policy

Scope to:

lab/rds/mysql (specific ARN)

Result:

🔐 Access limited to one secret only

🚫 Everything else denied

✅ Final Thought

This lab isn’t just about making things work — it’s about making them secure by design.

You didn’t just build a cloud app.
You built one that:

Segments access

Protects credentials

Enforces least privilege
