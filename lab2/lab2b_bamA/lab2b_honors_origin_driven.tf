##############################################################
# Lab 2B Honors — Origin-Driven Caching (Managed Policies)
##############################################################

##############################################################
# DATA SOURCES — AWS Managed Cache Policies
#
# Explanation: dawgs-armageddon uses AWS-managed policies —
# battle-tested configs so students learn the real policy names.
# Data sources fetch existing AWS-owned policy IDs at plan time.
# You never create these — Terraform just looks them up by name.
##############################################################

# UseOriginCacheControlHeaders:
# Origin Cache-Control exclusively drives TTL.
# If Flask sends Cache-Control: public, s-maxage=30 -> cached 30s.
# If Flask sends private/no-store or nothing -> TTL=0, not cached.
data "aws_cloudfront_cache_policy" "dawgs-armageddon_managed_origin_cc01" {
  name = "UseOriginCacheControlHeaders"
}

# UseOriginCacheControlHeaders-QueryStrings:
# Same as above but query strings are included in the cache key.
# Use when your API truly varies responses by query parameter.
data "aws_cloudfront_cache_policy" "dawgs-armageddon_managed_origin_cc_qs01" {
  name = "UseOriginCacheControlHeaders-QueryStrings"
}

##############################################################
# DATA SOURCES — AWS Managed Origin Request Policies
##############################################################

# Managed-AllViewer:
# Forwards all viewer headers, cookies, and query strings to origin.
data "aws_cloudfront_origin_request_policy" "dawgs-armageddon_managed_orp_all_viewer01" {
  name = "Managed-AllViewer"
}

# Managed-AllViewerExceptHostHeader:
# Forwards all viewer context but strips the Host header.
# Required for ALB origins to prevent SNI mismatch (400/421).
data "aws_cloudfront_origin_request_policy" "dawgs-armageddon_managed_orp_all_viewer_except_host01" {
  name = "Managed-AllViewerExceptHostHeader"
}

##############################################################
# BEHAVIOR MATRIX (reference)
#
# Order in cloudfront-lab-2a-distribution.tf:
#   1. /api/public-feed  -> UseOriginCacheControlHeaders (managed)
#   2. /api/*            -> cache_api_disabled01 (custom, TTL=0)
#   3. /api/list         -> cache_public_get01 (custom)
#   4. /static/*         -> cache_static01 (custom, aggressive)
#   5. default           -> cache_api_disabled01 (catch-all)
##############################################################
