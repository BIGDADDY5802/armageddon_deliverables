#!/bin/bash
# CloudWatch Logs Investigation - Final Version
# Complete incident investigation with proper parsing

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="cloudwatch-investigation-${TIMESTAMP}.log"

export MSYS_NO_PATHCONV=1

WAF_LOG_GROUP="aws-waf-logs-lab-webacl01"
APP_LOG_GROUP="/aws/ec2/lab-rds-app"
AWS_REGION="us-east-1"

echo "=========================================" | tee -a "$LOG_FILE"
echo "CloudWatch Logs Investigation Report" | tee -a "$LOG_FILE"
echo "Project: thedawgs2025.click" | tee -a "$LOG_FILE"
echo "Date: $(date)" | tee -a "$LOG_FILE"
echo "=========================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# Time range - last 2 hours in milliseconds
START_TIME=$(($(date +%s) - 7200))000

echo "Time Range: Last 2 hours" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

# ========================================
# Get WAF Logs
# ========================================
echo "[STEP 1] Analyzing WAF logs..." | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

WAF_EVENTS=$(MSYS_NO_PATHCONV=1 aws logs filter-log-events \
  --log-group-name "$WAF_LOG_GROUP" \
  --start-time "$START_TIME" \
  --region "$AWS_REGION" \
  --max-items 500 \
  --output json 2>&1)

if echo "$WAF_EVENTS" | grep -q '"events"'; then
  WAF_COUNT=$(echo "$WAF_EVENTS" | grep -c '"timestamp"')
  echo "✓ Found $WAF_COUNT WAF events" | tee -a "$LOG_FILE"
  echo "" | tee -a "$LOG_FILE"
  
  # Count ALLOW vs BLOCK
  ALLOW_COUNT=$(echo "$WAF_EVENTS" | grep -o '\\"action\\":\\"ALLOW\\"' | wc -l)
  BLOCK_COUNT=$(echo "$WAF_EVENTS" | grep -o '\\"action\\":\\"BLOCK\\"' | wc -l)
  
  echo "=========================================" | tee -a "$LOG_FILE"
  echo "WAF ANALYSIS" | tee -a "$LOG_FILE"
  echo "=========================================" | tee -a "$LOG_FILE"
  echo "" | tee -a "$LOG_FILE"
  
  echo "Actions:" | tee -a "$LOG_FILE"
  echo "  ✓ ALLOW: $ALLOW_COUNT requests" | tee -a "$LOG_FILE"
  
  if [ "$BLOCK_COUNT" -gt 0 ]; then
    echo "  ⚠️  BLOCK: $BLOCK_COUNT requests" | tee -a "$LOG_FILE"
  else
    echo "  BLOCK: 0 requests" | tee -a "$LOG_FILE"
  fi
  echo "" | tee -a "$LOG_FILE"
  
  # Top IPs
  echo "Top Client IPs:" | tee -a "$LOG_FILE"
  echo "$WAF_EVENTS" | grep -o '\\"clientIp\\":\\"[0-9.]*\\"' | \
    sed 's/\\"clientIp\\":\\"//g' | sed 's/\\"//g' | \
    sort | uniq -c | sort -rn | head -10 | \
    awk '{printf "  %3d requests - %s\n", $1, $2}' | tee -a "$LOG_FILE"
  echo "" | tee -a "$LOG_FILE"
  
  # Top URIs
  echo "Top Requested URIs:" | tee -a "$LOG_FILE"
  echo "$WAF_EVENTS" | grep -o '\\"uri\\":\\"[^"]*\\"' | \
    sed 's/\\"uri\\":\\"//g' | sed 's/\\"//g' | \
    sort | uniq -c | sort -rn | head -15 | \
    awk '{printf "  %3d - %s\n", $1, $2}' | tee -a "$LOG_FILE"
  echo "" | tee -a "$LOG_FILE"
  
  # Blocked requests details
  if [ "$BLOCK_COUNT" -gt 0 ]; then
    echo "=========================================" | tee -a "$LOG_FILE"
    echo "⚠️  BLOCKED REQUESTS (ATTACK DETECTED)" | tee -a "$LOG_FILE"
    echo "=========================================" | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
    
    # Save blocked events to temp file
    echo "$WAF_EVENTS" | grep -A5 -B5 '\\"action\\":\\"BLOCK\\"' > /tmp/blocked_events_$$.txt
    
    echo "Blocked IPs and URIs:" | tee -a "$LOG_FILE"
    
    # Extract blocked IPs
    BLOCKED_IPS=$(cat /tmp/blocked_events_$$.txt | grep -o '\\"clientIp\\":\\"[0-9.]*\\"' | \
      sed 's/\\"clientIp\\":\\"//g' | sed 's/\\"//g' | sort -u)
    
    # Extract blocked URIs
    BLOCKED_URIS=$(cat /tmp/blocked_events_$$.txt | grep -o '\\"uri\\":\\"[^"]*\\"' | \
      sed 's/\\"uri\\":\\"//g' | sed 's/\\"//g' | sort -u)
    
    echo "  Blocked IPs:" | tee -a "$LOG_FILE"
    echo "$BLOCKED_IPS" | while read ip; do
      echo "    • $ip" | tee -a "$LOG_FILE"
    done
    
    echo "" | tee -a "$LOG_FILE"
    echo "  Blocked URIs:" | tee -a "$LOG_FILE"
    echo "$BLOCKED_URIS" | while read uri; do
      echo "    • $uri" | tee -a "$LOG_FILE"
    done
    
    echo "" | tee -a "$LOG_FILE"
    
    # Show which WAF rule blocked
    echo "Blocking Rules:" | tee -a "$LOG_FILE"
    cat /tmp/blocked_events_$$.txt | grep -o '\\"terminatingRuleId\\":\\"[^"]*\\"' | \
      sed 's/\\"terminatingRuleId\\":\\"//g' | sed 's/\\"//g' | \
      sort | uniq -c | \
      awk '{printf "  %d blocks by: %s\n", $1, $2}' | tee -a "$LOG_FILE"
    
    echo "" | tee -a "$LOG_FILE"
    rm -f /tmp/blocked_events_$$.txt
  fi
  
  # Suspicious patterns
  echo "Suspicious Activity Detected:" | tee -a "$LOG_FILE"
  
  PHPUNIT=$(echo "$WAF_EVENTS" | grep -c "phpunit")
  WPLI=$(echo "$WAF_EVENTS" | grep -c "wp-login")
  ENV=$(echo "$WAF_EVENTS" | grep -c '\.env')
  ADMIN=$(echo "$WAF_EVENTS" | grep -c '/admin')
  
  if [ "$PHPUNIT" -gt 0 ]; then
    echo "  ⚠️  $PHPUNIT PHPUnit exploit attempts" | tee -a "$LOG_FILE"
  fi
  if [ "$WPLI" -gt 0 ]; then
    echo "  ⚠️  $WPLI WordPress login scans" | tee -a "$LOG_FILE"
  fi
  if [ "$ENV" -gt 0 ]; then
    echo "  ⚠️  $ENV .env file scans" | tee -a "$LOG_FILE"
  fi
  if [ "$ADMIN" -gt 0 ]; then
    echo "  ⚠️  $ADMIN admin panel scans" | tee -a "$LOG_FILE"
  fi
  
  if [ "$PHPUNIT" -eq 0 ] && [ "$WPLI" -eq 0 ] && [ "$ENV" -eq 0 ] && [ "$ADMIN" -eq 0 ]; then
    echo "  ✓ No common attack patterns detected" | tee -a "$LOG_FILE"
  fi
  
  echo "" | tee -a "$LOG_FILE"
  
  # Sample recent events
  echo "Recent WAF Events (Last 10):" | tee -a "$LOG_FILE"
  echo "$WAF_EVENTS" > /tmp/waf_$$.json
  
  if command -v python &> /dev/null; then
    python << EOF | tee -a "$LOG_FILE"
import json
try:
    with open('/tmp/waf_$$.json', 'r') as f:
        data = json.load(f)
    
    events = data.get('events', [])[-10:]
    
    for event in events:
        try:
            msg = json.loads(event['message'])
            http = msg.get('httpRequest', {})
            
            ip = http.get('clientIp', 'N/A')[:17]
            country = http.get('country', 'N/A')
            action = msg.get('action', 'N/A')
            uri = http.get('uri', 'N/A')[:40]
            method = http.get('httpMethod', 'GET')
            
            print(f"  {ip:17s} | {country:4s} | {action:5s} | {method:4s} {uri}")
        except:
            pass
except:
    print("  (Unable to parse events)")
EOF
  else
    echo "  Install Python for better formatting" | tee -a "$LOG_FILE"
  fi
  
  rm -f /tmp/waf_$$.json
  echo "" | tee -a "$LOG_FILE"
  
else
  echo "✗ No WAF events found" | tee -a "$LOG_FILE"
  echo "" | tee -a "$LOG_FILE"
fi

# ========================================
# Get App Logs
# ========================================
echo "=========================================" | tee -a "$LOG_FILE"
echo "[STEP 2] Analyzing App logs..." | tee -a "$LOG_FILE"
echo "=========================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

APP_EVENTS=$(MSYS_NO_PATHCONV=1 aws logs filter-log-events \
  --log-group-name "$APP_LOG_GROUP" \
  --start-time "$START_TIME" \
  --region "$AWS_REGION" \
  --max-items 200 \
  --output json 2>&1)

if echo "$APP_EVENTS" | grep -q '"events"'; then
  APP_COUNT=$(echo "$APP_EVENTS" | grep -c '"timestamp"')
  echo "✓ Found $APP_COUNT app log events" | tee -a "$LOG_FILE"
  
  # Count errors
  ERROR_COUNT=$(echo "$APP_EVENTS" | grep -ci "ERROR")
  WARNING_COUNT=$(echo "$APP_EVENTS" | grep -ci "WARNING")
  
  echo "" | tee -a "$LOG_FILE"
  echo "Log Summary:" | tee -a "$LOG_FILE"
  echo "  Total entries: $APP_COUNT" | tee -a "$LOG_FILE"
  
  if [ "$ERROR_COUNT" -gt 0 ]; then
    echo "  ⚠️  Errors: $ERROR_COUNT" | tee -a "$LOG_FILE"
  else
    echo "  ✓ Errors: 0" | tee -a "$LOG_FILE"
  fi
  
  if [ "$WARNING_COUNT" -gt 0 ]; then
    echo "  ⚠️  Warnings: $WARNING_COUNT" | tee -a "$LOG_FILE"
  fi
  
  echo "" | tee -a "$LOG_FILE"
  
  if [ "$ERROR_COUNT" -gt 0 ]; then
    echo "Recent Errors:" | tee -a "$LOG_FILE"
    echo "$APP_EVENTS" | grep -i "ERROR" | head -5 | \
      sed 's/.*"message":"\([^"]*\)".*/  • \1/' | tee -a "$LOG_FILE"
    echo "" | tee -a "$LOG_FILE"
  fi
  
else
  echo "ℹ️  No app log events in last 2 hours" | tee -a "$LOG_FILE"
  echo "   (This is normal if app isn't logging much)" | tee -a "$LOG_FILE"
  echo "" | tee -a "$LOG_FILE"
fi

# ========================================
# Infrastructure Check
# ========================================
echo "=========================================" | tee -a "$LOG_FILE"
echo "[STEP 3] Infrastructure Health" | tee -a "$LOG_FILE"
echo "=========================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://app.thedawgs2025.click/list" 2>&1)
if [ "$HTTP_STATUS" = "200" ]; then
  echo "✓ Application: Responding (HTTP $HTTP_STATUS)" | tee -a "$LOG_FILE"
else
  echo "⚠️  Application: Issues (HTTP $HTTP_STATUS)" | tee -a "$LOG_FILE"
fi

echo "" | tee -a "$LOG_FILE"

# ========================================
# Final Analysis
# ========================================
echo "=========================================" | tee -a "$LOG_FILE"
echo "INCIDENT ANALYSIS" | tee -a "$LOG_FILE"
echo "=========================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"

if [ "$BLOCK_COUNT" -gt 5 ]; then
  echo "🚨 ACTIVE ATTACK DETECTED" | tee -a "$LOG_FILE"
  echo "" | tee -a "$LOG_FILE"
  echo "   • WAF blocked $BLOCK_COUNT malicious requests" | tee -a "$LOG_FILE"
  echo "   • Review blocked IPs and URIs above" | tee -a "$LOG_FILE"
  echo "   • Consider adding rate limiting rules" | tee -a "$LOG_FILE"
  echo "" | tee -a "$LOG_FILE"
elif [ "$BLOCK_COUNT" -gt 0 ]; then
  echo "⚠️  Minor Attack Activity" | tee -a "$LOG_FILE"
  echo "" | tee -a "$LOG_FILE"
  echo "   • WAF blocked $BLOCK_COUNT requests" | tee -a "$LOG_FILE"
  echo "   • Likely automated scanners" | tee -a "$LOG_FILE"
  echo "   • No immediate action needed - WAF is working" | tee -a "$LOG_FILE"
  echo "" | tee -a "$LOG_FILE"
else
  echo "✓ No Attack Activity" | tee -a "$LOG_FILE"
  echo "" | tee -a "$LOG_FILE"
  echo "   • All $ALLOW_COUNT requests allowed" | tee -a "$LOG_FILE"
  echo "   • Normal traffic patterns" | tee -a "$LOG_FILE"
  echo "" | tee -a "$LOG_FILE"
fi

if [ "$ERROR_COUNT" -gt 0 ]; then
  echo "⚠️  Application Errors Detected" | tee -a "$LOG_FILE"
  echo "" | tee -a "$LOG_FILE"
  echo "   • $ERROR_COUNT error entries in logs" | tee -a "$LOG_FILE"
  echo "   • Review error details above" | tee -a "$LOG_FILE"
  echo "" | tee -a "$LOG_FILE"
fi

echo "=========================================" | tee -a "$LOG_FILE"
echo "Investigation Complete!" | tee -a "$LOG_FILE"
echo "=========================================" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"
echo "Full report saved to: $LOG_FILE" | tee -a "$LOG_FILE"
echo "" | tee -a "$LOG_FILE"