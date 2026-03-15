#!/bin/bash
# Lab 1C-Bonus-F: On-Demand CloudWatch Logs Insights Runner
# Executes the A1-A8 (WAF) and B1-B4 (App) query pack via aws logs start-query.
#
# Usage:
#   ./run_insights.sh                      # last 15 min, all queries
#   ./run_insights.sh --minutes 60         # last 60 minutes
#   ./run_insights.sh --query waf          # WAF queries only
#   ./run_insights.sh --query app          # App queries only
#   ./run_insights.sh --project myprefix   # override project name (default: lab)
#   ./run_insights.sh --region us-west-2   # override region

export MSYS_NO_PATHCONV=1

# ── Defaults ──────────────────────────────────────────────────────────────
MINUTES=15
REGION="us-east-1"
PROJECT="lab"
QUERY_FILTER="all"

# ── Parse args ────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --minutes)  MINUTES="$2";       shift 2 ;;
    --region)   REGION="$2";        shift 2 ;;
    --project)  PROJECT="$2";       shift 2 ;;
    --query)    QUERY_FILTER="$2";  shift 2 ;;
    *)          shift ;;
  esac
done

WAF_LOG_GROUP="aws-waf-logs-${PROJECT}-webacl01"
APP_LOG_GROUP="/aws/ec2/${PROJECT}-rds-app"

END_TIME=$(date +%s)
START_TIME=$((END_TIME - MINUTES * 60))

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="insights-${TIMESTAMP}.log"

# ── Query strings ─────────────────────────────────────────────────────────
Q_A1='fields @timestamp, action | stats count() as hits by action | sort hits desc'
Q_A2='fields @timestamp, httpRequest.clientIp as clientIp | stats count() as hits by clientIp | sort hits desc | limit 25'
Q_A3='fields @timestamp, httpRequest.uri as uri | stats count() as hits by uri | sort hits desc | limit 25'
Q_A4='fields @timestamp, action, httpRequest.clientIp as clientIp, httpRequest.uri as uri | filter action = "BLOCK" | stats count() as blocks by clientIp, uri | sort blocks desc | limit 25'
Q_A5='fields @timestamp, action, terminatingRuleId, terminatingRuleType | filter action = "BLOCK" | stats count() as blocks by terminatingRuleId, terminatingRuleType | sort blocks desc | limit 25'
Q_A6='fields @timestamp, httpRequest.clientIp as clientIp, httpRequest.uri as uri | filter uri =~ /wp-login|xmlrpc|\.env|admin|phpmyadmin|\.git|login/ | stats count() as hits by clientIp, uri | sort hits desc | limit 50'
Q_A7='fields @timestamp, httpRequest.clientIp as clientIp, httpRequest.uri as uri | filter uri =~ /wp-login|xmlrpc|\.env|admin|phpmyadmin|\.git|login/ | stats count() as hits by clientIp, uri | sort hits desc | limit 50'
Q_A8='fields @timestamp, httpRequest.country as country | stats count() as hits by country | sort hits desc | limit 25'

Q_B1='fields @timestamp, @message | filter @message =~ /ERROR|Exception|Traceback|timeout|refused/ | stats count() as errors by bin(1m) | sort bin(1m) asc'
Q_B2='fields @timestamp, @message | filter @message =~ /DB|mysql|timeout|refused|Access denied|could not connect/ | sort @timestamp desc | limit 50'
Q_B3='fields @timestamp, @message | filter @message =~ /Access denied|authentication failed|timeout|refused|no route|could not connect/ | stats count() as hits by case(@message like /Access denied/ or @message like /authentication failed/, "Creds-Auth", @message like /timeout/ or @message like /no route/, "Network-Route", @message like /refused/, "Port-SG-Refused", "Other") | sort hits desc'
Q_B4='fields @timestamp, level, event, reason | filter level = "ERROR" | stats count() as n by event, reason | sort n desc'

# ── Header ────────────────────────────────────────────────────────────────
{
  echo "============================================================"
  echo "Lab 1C-Bonus-F: Logs Insights Query Pack"
  echo "Project  : ${PROJECT}"
  echo "Region   : ${REGION}"
  echo "Window   : Last ${MINUTES} minutes"
  echo "Filter   : ${QUERY_FILTER}"
  echo "Run at   : $(date)"
  echo "============================================================"
} | tee "$LOG_FILE"

# ── run_query(label, log_group, query_string) ─────────────────────────────
run_query() {
  local label="$1"
  local log_group="$2"
  local query="$3"

  echo "" | tee -a "$LOG_FILE"
  echo "--- ${label} ---" | tee -a "$LOG_FILE"

  # Start the query
  local query_id
  query_id=$(aws logs start-query \
    --log-group-name "$log_group" \
    --start-time "$START_TIME" \
    --end-time "$END_TIME" \
    --query-string "$query" \
    --region "$REGION" \
    --output text --query 'queryId' 2>&1)

  if [[ -z "$query_id" || "$query_id" == *"xception"* || "$query_id" == *"rror"* || "$query_id" == *"does not exist"* ]]; then
    echo "  (skipped — log group not found or start-query failed)" | tee -a "$LOG_FILE"
    echo "  Detail: $query_id" | tee -a "$LOG_FILE"
    return
  fi

  # Poll until Complete (2s intervals, max ~60s)
  local status="Scheduled"
  local attempts=0
  while [[ "$status" != "Complete" && "$status" != "Failed" && "$status" != "Cancelled" && $attempts -lt 30 ]]; do
    sleep 2
    status=$(aws logs get-query-results \
      --query-id "$query_id" \
      --region "$REGION" \
      --output text --query 'status' 2>/dev/null) || status="Unknown"
    ((attempts++)) || true
  done

  if [[ "$status" != "Complete" ]]; then
    echo "  (query ended with status: ${status})" | tee -a "$LOG_FILE"
    return
  fi

  # Fetch results into a temp file and parse with python
  local tmp_file="/tmp/insights_results_$$.json"
  aws logs get-query-results \
    --query-id "$query_id" \
    --region "$REGION" \
    --output json > "$tmp_file" 2>/dev/null

  python3 <<PYEOF 2>/dev/null | tee -a "$LOG_FILE"
import json

with open("$tmp_file") as f:
    data = json.load(f)

results = data.get("results", [])
stats   = data.get("statistics", {})

if not results:
    print("  (no results in window)")
else:
    for row in results:
        fields = {f["field"]: f["value"] for f in row if f["field"] != "@ptr"}
        print("  " + "  |  ".join(f"{k}: {v}" for k, v in fields.items()))

scanned   = stats.get("recordsScanned", 0)
matched   = stats.get("recordsMatched", 0)
print(f"\n  [scanned: {scanned:.0f}  matched: {matched:.0f}]")
PYEOF

  rm -f "$tmp_file"
}

# ── WAF group check ───────────────────────────────────────────────────────
waf_group_exists() {
  local found
  found=$(aws logs describe-log-groups \
    --log-group-name-prefix "$WAF_LOG_GROUP" \
    --region "$REGION" \
    --output text --query 'logGroups[0].logGroupName' 2>/dev/null) || true
  [[ "$found" == "$WAF_LOG_GROUP" ]]
}

# ── WAF Queries ───────────────────────────────────────────────────────────
if [[ "$QUERY_FILTER" == "all" || "$QUERY_FILTER" == "waf" ]]; then
  {
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "WAF QUERIES  (${WAF_LOG_GROUP})"
    echo "════════════════════════════════════════════════════════════"
  } | tee -a "$LOG_FILE"

  if ! waf_group_exists; then
    {
      echo "  WAF log group not found."
      echo "  Ensure var.waf_log_destination = \"cloudwatch\" and terraform apply has run."
    } | tee -a "$LOG_FILE"
  else
    run_query "A1: Top Actions (ALLOW/BLOCK)"      "$WAF_LOG_GROUP" "$Q_A1"
    run_query "A2: Top Client IPs"                 "$WAF_LOG_GROUP" "$Q_A2"
    run_query "A3: Top Requested URIs"             "$WAF_LOG_GROUP" "$Q_A3"
    run_query "A4: Blocked Requests (IP + URI)"    "$WAF_LOG_GROUP" "$Q_A4"
    run_query "A5: Which Rule is Blocking"         "$WAF_LOG_GROUP" "$Q_A5"
    run_query "A6: Scanner URI Rate"               "$WAF_LOG_GROUP" "$Q_A6"
    run_query "A7: Suspicious Scanners"            "$WAF_LOG_GROUP" "$Q_A7"
    run_query "A8: Country/Geo Distribution"       "$WAF_LOG_GROUP" "$Q_A8"
  fi
fi

# ── App Queries ───────────────────────────────────────────────────────────
if [[ "$QUERY_FILTER" == "all" || "$QUERY_FILTER" == "app" ]]; then
  {
    echo ""
    echo "════════════════════════════════════════════════════════════"
    echo "APP QUERIES  (${APP_LOG_GROUP})"
    echo "════════════════════════════════════════════════════════════"
  } | tee -a "$LOG_FILE"

  run_query "B1: Error Rate Over Time"              "$APP_LOG_GROUP" "$Q_B1"
  run_query "B2: Recent DB Failures"                "$APP_LOG_GROUP" "$Q_B2"
  run_query "B3: Creds vs Network Classifier"       "$APP_LOG_GROUP" "$Q_B3"
  run_query "B4: Structured JSON Errors"            "$APP_LOG_GROUP" "$Q_B4"
fi

# ── Footer ────────────────────────────────────────────────────────────────
{
  echo ""
  echo "============================================================"
  echo "Done. Report saved to: ${LOG_FILE}"
  echo "============================================================"
} | tee -a "$LOG_FILE"
