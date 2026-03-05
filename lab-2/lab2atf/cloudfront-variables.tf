############################################
# Lab 2A - CloudFront Variables
#
# Purpose: All variables that control the
# CloudFront distribution, origin secret,
# WAF CLOUDFRONT scope, and ALB lockdown.
#
# These extend the existing variables.tf
# from Lab 1C without touching it.
############################################

# ── Origin Shield Secret ─────────────────────────────────────────────────
# Explanation: This is the password the bouncer (ALB) demands at the door.
# Only CloudFront knows it. Anyone who hits the ALB directly without it
# gets a 403 — like showing up to the Rebel base without the right code.

variable "cloudfront_origin_secret" {
  description = "Shared secret CloudFront sends to the ALB via X-Origin-Verify header. Must be kept out of source control. Change this to something unique to your project."
  type        = string
  sensitive   = true
  default     = "dawgs-armageddon-cf-secret-2025"
  # TODO: In production rotate this via Secrets Manager and Lambda.
  # For lab, hardcoding here is acceptable.
}

variable "cloudfront_origin_header_name" {
  description = "HTTP header name CloudFront injects into every origin request. ALB checks for this header before forwarding traffic."
  type        = string
  default     = "X-Origin-Verify"
}

# ── CloudFront Distribution Toggles ──────────────────────────────────────

variable "enable_cloudfront" {
  description = "Master toggle. Set to false to destroy the CloudFront distribution while keeping ALB intact."
  type        = bool
  default     = true
}

variable "cloudfront_price_class" {
  description = "CloudFront price class (controls which edge locations serve traffic). PriceClass_100 = US/EU only — cheapest for lab use."
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.cloudfront_price_class)
    error_message = "Must be PriceClass_100, PriceClass_200, or PriceClass_All."
  }
}

variable "cloudfront_min_ttl" {
  description = "Minimum TTL (seconds) for cached objects at the edge."
  type        = number
  default     = 0
}

variable "cloudfront_default_ttl" {
  description = "Default TTL (seconds) when the origin does not send Cache-Control headers."
  type        = number
  default     = 0
  # NOTE: 0 means pass-through (no caching) — correct for a dynamic Flask app.
  # Students working on static assets can raise this to 86400 (1 day).
}

variable "cloudfront_max_ttl" {
  description = "Maximum TTL (seconds) for cached objects."
  type        = number
  default     = 31536000
}

variable "cloudfront_http_version" {
  description = "Max HTTP version CloudFront supports. http2and3 gives best performance."
  type        = string
  default     = "http2and3"
}

# ── CloudFront WAF (CLOUDFRONT scope) ────────────────────────────────────
# Explanation: WAF attached to CloudFront MUST be deployed in us-east-1
# regardless of where everything else lives. This is an AWS constraint —
# like how the Senate always meets on Coruscant no matter where you're from.

variable "enable_cloudfront_waf" {
  description = "Attach a WAFv2 Web ACL (CLOUDFRONT scope) to the distribution. Requires resources in us-east-1."
  type        = bool
  default     = true
}

# ── Geo Restriction ───────────────────────────────────────────────────────

variable "cloudfront_geo_restriction_type" {
  description = "Geo restriction type: none | whitelist | blacklist. Use none for lab unless required."
  type        = string
  default     = "none"

  validation {
    condition     = contains(["none", "whitelist", "blacklist"], var.cloudfront_geo_restriction_type)
    error_message = "Must be none, whitelist, or blacklist."
  }
}

variable "cloudfront_geo_restriction_locations" {
  description = "ISO 3166-1-alpha-2 country codes for geo restriction. Only used when type is whitelist or blacklist."
  type        = list(string)
  default     = []
}

# ── Logging ───────────────────────────────────────────────────────────────

variable "enable_cloudfront_logging" {
  description = "Enable CloudFront standard access logging to an S3 bucket."
  type        = bool
  default     = false
  # NOTE: Logging adds S3 cost. Default off for lab. Flip to true for production or bonus work.
}

variable "cloudfront_log_prefix" {
  description = "S3 key prefix for CloudFront access logs."
  type        = string
  default     = "cf-access-logs"
}

# ── Route53 Integration ───────────────────────────────────────────────────

variable "cloudfront_subdomain" {
  description = "Subdomain that will point to CloudFront. Defaults to 'app' (same as ALB subdomain). Students can change to 'www' or 'cdn' if desired."
  type        = string
  default     = "app"
}
