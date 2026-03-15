#!/bin/bash
# 1. Install System Dependencies
dnf update -y
dnf install -y python3-pip mariadb105
pip3 install flask pymysql boto3 watchtower

# 2. Create Directory
mkdir -p /opt/rdsapp

# 3. Create the Python Script (The Simple Version)
cat >/opt/rdsapp/app.py <<'PY'
import json
import os
import boto3
import pymysql
import logging
from flask import Flask, request
from watchtower import CloudWatchLogHandler

REGION = os.environ.get("AWS_REGION", "us-east-1")
LOG_GROUP = "/aws/ec2/lab-rds-app"
METRIC_NAMESPACE = "Lab/RDSApp"

ssm = boto3.client("ssm", region_name=REGION)
sm = boto3.client("secretsmanager", region_name=REGION)
cw = boto3.client("cloudwatch", region_name=REGION)

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)
try:
    cw_handler = CloudWatchLogHandler(
        log_group=LOG_GROUP, 
        stream_name="app-stream", 
        boto3_client=boto3.client("logs", region_name=REGION)
    )
    logger.addHandler(cw_handler)
except Exception as e:
    print(f"CloudWatch Logs Setup Pending: {e}")

app = Flask(__name__)

def record_failure(error_msg):
    logger.error(f"DB_CONNECTION_FAILURE: {error_msg}")
    try:
        cw.put_metric_data(
            Namespace=METRIC_NAMESPACE,
            MetricData=[{'MetricName': 'DBConnectionErrors', 'Value': 1.0, 'Unit': 'Count'}]
        )
    except Exception as e:
        logger.warning(f"Failed to push metric: {e}")

def get_config():
    try:
        p_resp = ssm.get_parameters(
            Names=['/lab/db/endpoint', '/lab/db/port', '/lab/db/name'],
            WithDecryption=False
        )
        p_map = {p['Name']: p['Value'] for p in p_resp['Parameters']}
        s_resp = sm.get_secret_value(SecretId='lab/rds/mysql')
        secret = json.loads(s_resp['SecretString'])
        return {
            'host': p_map.get('/lab/db/endpoint'),
            'port': int(p_map.get('/lab/db/port', 3306)),
            'dbname': p_map.get('/lab/db/name', 'labdb'),
            'user': secret.get('username'),
            'password': secret.get('password')
        }
    except Exception as e:
        record_failure(str(e))
        raise e

def get_conn():
    c = get_config()
    return pymysql.connect(
        host=c['host'], user=c['user'], password=c['password'], 
        port=c['port'], database=c['dbname'], autocommit=True
    )

@app.route("/")
def home():
    return """
    <h1>Lab 1b: Simple RDS App</h1>
    <ul>
        <li><a href='/init'>1. Init DB</a></li>
        <li><a href='/add?text=LabEntry'>2. Add Note (?text=...)</a></li>
        <li><a href='/list'>3. List Notes</a></li>
    </ul>
    """

@app.route("/add")
def add_note():
    note_text = request.args.get('text', 'Manual Entry')
    try:
        conn = get_conn()
        cur = conn.cursor()
        cur.execute("INSERT INTO notes (note) VALUES (%s)", (note_text,))
        cur.close()
        conn.close()
        return f"Added: {note_text} | <a href='/list'>View List</a>"
    except Exception as e:
        record_failure(str(e))
        return f"Add Failed: {e}", 500

@app.route("/list")
def list_notes():
    try:
        conn = get_conn()
        cur = conn.cursor()
        cur.execute("SELECT id, note FROM notes ORDER BY id DESC;")
        rows = cur.fetchall()
        cur.close()
        conn.close()
        return "<h3>Notes:</h3>" + "".join([f"<li>{r[1]}</li>" for r in rows]) + "<br><a href='/'>Back</a>"
    except Exception as e:
        record_failure(str(e))
        return f"List Failed: {e}", 500

@app.route("/init")
def init_db():
    try:
        c = get_config()
        conn = pymysql.connect(host=c['host'], user=c['user'], password=c['password'], port=c['port'])
        cur = conn.cursor()
        cur.execute(f"CREATE DATABASE IF NOT EXISTS {c['dbname']};")
        cur.execute(f"USE {c['dbname']};")
        cur.execute("CREATE TABLE IF NOT EXISTS notes (id INT AUTO_INCREMENT PRIMARY KEY, note VARCHAR(255));")
        cur.close()
        conn.close()
        return "Init Success! <a href='/'>Back</a>"
    except Exception as e:
        record_failure(str(e))
        return f"Init Failed: {e}", 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80)
PY

# 4. Create the Service File
cat >/etc/systemd/system/rdsapp.service <<'SERVICE'
[Unit]
Description=Lab 1b RDS App
After=network-online.target
Wants=network-online.target

[Service]
WorkingDirectory=/opt/rdsapp
ExecStartPre=/usr/bin/sleep 20
ExecStart=/usr/bin/python3 /opt/rdsapp/app.py
Restart=always
RestartSec=10s
Environment=AWS_REGION=us-east-1

[Install]
WantedBy=multi-user.target
SERVICE

# 5. Start the Engine
systemctl daemon-reload
systemctl enable rdsapp
systemctl start rdsapp