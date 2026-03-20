# Bonus A — Private EC2, SSM-Only Access, VPC Endpoints

## What Changed From the Base Lab

The base lab used a public EC2 instance — it had a public IP, lived in a public subnet,
and was accessible via SSH with a key pair. Bonus A replaces that entirely with a private
instance that has no public IP, no open inbound ports, and no SSH key.

---

## The Four Core Differences

### 1. Private Subnet Placement
The instance moved from `chewbacca_public_subnets[0]` to `chewbacca_private_subnets[0]`.
It has no public IP and no route to the internet gateway. The only traffic path in or out
is through AWS-internal services.

### 2. SSH Removed — SSM Session Manager Replaces It
No `key_name` on the instance. No port 22 in any security group. Access is granted
entirely through IAM — if your AWS identity has `ssm:StartSession` permission and the
instance has `AmazonSSMManagedInstanceCore` attached, you can open a shell. Every session
is logged to CloudTrail automatically. There is no door to attack because the door
does not exist.

### 3. VPC Interface Endpoints
Without a public route, the instance would have no way to reach AWS services like SSM,
Secrets Manager, or CloudWatch. VPC interface endpoints solve this by placing an ENI
inside the private subnet that routes service traffic internally — it never leaves
Amazon's network. Five endpoints were added:

| Endpoint | Purpose |
|----------|---------|
| `ssm` | SSM agent control plane |
| `ssmmessages` | Session Manager shell traffic |
| `ec2messages` | SSM run command channel |
| `secretsmanager` | Flask app credential retrieval |
| `logs` | CloudWatch log shipping |

A Gateway endpoint for S3 was also added so the instance can pull packages and the
CW agent binary without needing NAT.

### 4. CloudWatch Agent Added to `user_data`
The base lab had a TODO comment where the CW agent should have been. Bonus A implements
it — the agent installs at boot, reads a config pointing at `/aws/ec2/lab-rds-app`,
and ships two log streams: `user_data` (boot log) and `system` (OS messages). Combined
with `set -eo pipefail` at the top of the script, any boot failure is captured and
visible in CloudWatch without needing shell access to the instance.

---

## Why This Matters for Compliance

The base lab instance was reachable from the internet. Any audit of that environment
would flag the open attack surface, the unrotated SSH key, and the absence of session
logging. The Bonus A instance has none of those problems:

- No inbound ports means no attack surface to flag
- IAM controls access instead of SSH keys — access is revoked by removing an IAM
  policy, not by rotating and redistributing key files
- Every SSM session produces a CloudTrail event with the caller identity, timestamp,
  and session ID — this is the audit trail APPI compliance requires
- All traffic between the instance and AWS services stays on Amazon's private network —
  no data crosses the public internet

---

## How Browser Access Works Without a Public IP

SSM port forwarding creates a temporary encrypted tunnel from a local port on your
machine through the SSM service to a port on the private instance. Running:

```bash
aws ssm start-session \
  --target <instance-id> \
  --document-name AWS-StartPortForwardingSession \
  --parameters '{"portNumber":["80"],"localPortNumber":["8080"]}'
```

...makes `http://localhost:8080` in your browser hit the Flask app on the private
instance. No security group rules change. No ports open. The tunnel exists only while
the command is running and is authenticated by your IAM identity.

---

## Proof of Completion

### SSM Agent Online

```
$ aws ssm describe-instance-information \
    --filters "Key=InstanceIds,Values=<instance-id>" \
    --query "InstanceInformationList[0].{Status:PingStatus,Agent:AgentVersion,IP:IPAddress}" \
    --output table

-------------------------------------------
|       DescribeInstanceInformation       |
+-------------+-----------------+---------+
|    Agent    |       IP        | Status  |
+-------------+-----------------+---------+
|  3.3.3598.0 |  10.190.101.35  |  Online |
+-------------+-----------------+---------+
```

`PingStatus = Online` confirms the SSM agent registered through the VPC endpoints.
No public IP. No SSH. Access is IAM-controlled.

---

### Flask App + RDS Connectivity (inside SSM session)

```
$ curl -s localhost/init
Initialized labdb + notes table.

$ curl -s localhost/add?note=bonusA-complete
Inserted note: bonusA-complete

$ curl -s localhost/list
<h3>Notes</h3><ul>
  <li>4: bonusA-complete</li>
  <li>3: 3rd_note</li>
  <li>2: 2nd_note</li>
  <li>1: hello</li>
</ul>
```

Flask reached Secrets Manager via VPC endpoint, retrieved RDS credentials,
connected to RDS, and read/wrote data — entirely over Amazon's private network.

---

### CloudWatch Log Streams Confirmed

```
$ aws logs describe-log-streams \
    --log-group-name "/aws/ec2/lab-rds-app" \
    --query "logStreams[*].logStreamName" \
    --output table

-----------------------------------
|       DescribeLogStreams        |
+---------------------------------+
|  <instance-id>/user_data        |
+---------------------------------+
```

Boot logs shipping to `/aws/ec2/lab-rds-app` via the CloudWatch VPC endpoint.
Stream named `<instance-id>/user_data` matches the CW agent config exactly.

---

### Browser Rendering via SSM Port Forwarding Tunnel

Flask app rendered in browser at `http://localhost:8080/list` via SSM port
forwarding tunnel. No public IP. No open ports. Tunnel authenticated by IAM identity.

![Flask app rendered in browser via SSM tunnel](/1c_terrraform/attachments/browser_proof.png)
