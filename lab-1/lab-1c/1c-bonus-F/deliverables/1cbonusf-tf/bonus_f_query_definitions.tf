############################################
# Bonus F – CloudWatch Logs Insights Saved Query Definitions
# Deploys all A1–A8 (WAF) and B1–B4 (App) queries from the lab runbook
# as Saved Queries visible in: CloudWatch > Logs > Insights > Saved Queries.
#
# WAF queries: only created when var.waf_log_destination = "cloudwatch"
# App queries: always created
#
# Run on-demand: ./run_insights.sh [--minutes N] [--query waf|app|all]
############################################

locals {
  # ── WAF queries (A1–A8) ──────────────────────────────────────────────────
  # Only deployed when WAF destination is CloudWatch.
  waf_insight_queries = {

    "A1-Top-Actions" = {
      query = <<-EOQ
        fields @timestamp, action
        | stats count() as hits by action
        | sort hits desc
      EOQ
    }

    "A2-Top-Client-IPs" = {
      query = <<-EOQ
        fields @timestamp, httpRequest.clientIp as clientIp
        | stats count() as hits by clientIp
        | sort hits desc
        | limit 25
      EOQ
    }

    "A3-Top-URIs" = {
      query = <<-EOQ
        fields @timestamp, httpRequest.uri as uri
        | stats count() as hits by uri
        | sort hits desc
        | limit 25
      EOQ
    }

    "A4-Blocked-Requests" = {
      query = <<-EOQ
        fields @timestamp, action, httpRequest.clientIp as clientIp, httpRequest.uri as uri
        | filter action = "BLOCK"
        | stats count() as blocks by clientIp, uri
        | sort blocks desc
        | limit 25
      EOQ
    }

    "A5-Blocking-Rule" = {
      query = <<-EOQ
        fields @timestamp, action, terminatingRuleId, terminatingRuleType
        | filter action = "BLOCK"
        | stats count() as blocks by terminatingRuleId, terminatingRuleType
        | sort blocks desc
        | limit 25
      EOQ
    }

    # NOTE: =~ used instead of like /pattern/i — CWL Insights does not support the /i flag.
    "A6-Scanner-URI-Rate" = {
      query = <<-EOQ
        fields @timestamp, httpRequest.clientIp as clientIp, httpRequest.uri as uri
        | filter uri =~ /wp-login|xmlrpc|\.env|admin|phpmyadmin|\.git|login/
        | stats count() as hits by clientIp, uri
        | sort hits desc
        | limit 50
      EOQ
    }

    "A7-Suspicious-Scanners" = {
      query = <<-EOQ
        fields @timestamp, httpRequest.clientIp as clientIp, httpRequest.uri as uri
        | filter uri =~ /wp-login|xmlrpc|\.env|admin|phpmyadmin|\.git|login/
        | stats count() as hits by clientIp, uri
        | sort hits desc
        | limit 50
      EOQ
    }

    "A8-Country-Geo" = {
      query = <<-EOQ
        fields @timestamp, httpRequest.country as country
        | stats count() as hits by country
        | sort hits desc
        | limit 25
      EOQ
    }
  }

  # ── App queries (B1–B4) ──────────────────────────────────────────────────
  # Always deployed — app log group always exists.
  app_insight_queries = {

    "B1-Error-Rate-Over-Time" = {
      query = <<-EOQ
        fields @timestamp, @message
        | filter @message =~ /ERROR|Exception|Traceback|timeout|refused/
        | stats count() as errors by bin(1m)
        | sort bin(1m) asc
      EOQ
    }

    "B2-Recent-DB-Failures" = {
      query = <<-EOQ
        fields @timestamp, @message
        | filter @message =~ /DB|mysql|timeout|refused|Access denied|could not connect/
        | sort @timestamp desc
        | limit 50
      EOQ
    }

    # Classifier: creds drift vs network/SG failure.
    # NOTE: CWL Insights case() does not support /i flag — uppercase patterns used.
    "B3-Creds-vs-Network-Classifier" = {
      query = <<-EOQ
        fields @timestamp, @message
        | filter @message =~ /Access denied|authentication failed|timeout|refused|no route|could not connect/
        | stats count() as hits by
            case(
              @message like /Access denied/ or @message like /authentication failed/, "Creds-Auth",
              @message like /timeout/ or @message like /no route/, "Network-Route",
              @message like /refused/, "Port-SG-Refused",
              "Other"
            )
        | sort hits desc
      EOQ
    }

    # Requires app to emit structured JSON logs: {"level":"ERROR","event":"...","reason":"..."}
    "B4-Structured-JSON-Errors" = {
      query = <<-EOQ
        fields @timestamp, level, event, reason
        | filter level = "ERROR"
        | stats count() as n by event, reason
        | sort n desc
      EOQ
    }
  }
}

############################################
# WAF saved queries
# Gated on cloudwatch destination — log group only exists in that case.
############################################

resource "aws_cloudwatch_query_definition" "dawgs-armageddon_waf_queries" {
  for_each = var.waf_log_destination == "cloudwatch" ? local.waf_insight_queries : {}

  name            = "${var.project_name}/WAF/${each.key}"
  log_group_names = [aws_cloudwatch_log_group.dawgs-armageddon_waf_log_group01[0].name]
  query_string    = each.value.query
}

############################################
# App saved queries
# Always deployed.
############################################

resource "aws_cloudwatch_query_definition" "dawgs-armageddon_app_queries" {
  for_each = local.app_insight_queries

  name            = "${var.project_name}/App/${each.key}"
  log_group_names = [aws_cloudwatch_log_group.dawgs-armageddon_log_group01.name]
  query_string    = each.value.query
}
