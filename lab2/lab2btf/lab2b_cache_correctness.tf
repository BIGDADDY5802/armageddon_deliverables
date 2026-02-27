#################################################
#1) Cache policy for static content (aggressive)
##############################################################

# Explanation: Static files are the easy win—dawgs-armageddon caches them like hyperfuel for speed.
resource "aws_cloudfront_cache_policy" "dawgs-armageddon_cache_static01" {
  name        = "${var.project_name}-cache-static01"
  # NOTE: target_origin_id does not belong here — cache policies are reusable
  # and not bound to a specific origin. The association happens in the
  # ordered_cache_behavior block inside the distribution (Section 6).
  comment     = "Aggressive caching for /static/*"
  default_ttl = 86400        # 1 day
  max_ttl     = 31536000     # 1 year
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    # Explanation: Static should not vary on cookies—dawgs-armageddon refuses to cache 10,000 versions of a PNG.
    cookies_config { cookie_behavior = "none" }

    # Explanation: Static should not vary on query strings (unless you do versioning); students can change later.
    query_strings_config { query_string_behavior = "none" }

    # Explanation: Keep headers out of cache key to maximize hit ratio.
    headers_config { header_behavior = "none" }

    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true
  }
}

############################################################
#2) Cache policy for API (safe default: caching disabled)
##############################################################



# Explanation: APIs are dangerous to cache by accident—dawgs-armageddon disables caching until proven safe.
resource "aws_cloudfront_cache_policy" "dawgs-armageddon_cache_api_disabled01" {
  name        = "${var.project_name}-cache-api-disabled01"
  comment     = "Disable caching for /api/* by default"
  default_ttl = 0
  max_ttl     = 0
  min_ttl     = 0

  parameters_in_cache_key_and_forwarded_to_origin {
    # FIX: When TTL=0 (caching disabled), nothing is ever stored, so cache key
    # components are irrelevant. Setting them to "all" or "whitelist" is harmless
    # but semantically wrong—it implies caching varies on these values, which
    # misleads anyone reading the config. Keep the key minimal and explicit.
    cookies_config { cookie_behavior = "none" }
    query_strings_config { query_string_behavior = "none" }

    # FIX: Removed "Host" from the headers whitelist here. Host is managed by
    # CloudFront internally—it must never appear in the cache key, as it either
    # has no effect or causes unexpected fragmentation. Forwarding Host to the
    # origin is handled correctly in dawgs-armageddon_orp_api01 (the origin
    # request policy), which is the right place for it.
    headers_config { header_behavior = "none" }

    # FIX: With TTL=0 there is nothing to compress at the cache layer.
    # Disable encoding flags to match intent.
    enable_accept_encoding_gzip   = false
    enable_accept_encoding_brotli = false
  }
}

############################################################
#3) Origin request policy for API (forward what origin needs)
##############################################################


# Explanation: Origins need context—dawgs-armageddon forwards what the app needs without polluting the cache key.
resource "aws_cloudfront_origin_request_policy" "dawgs-armageddon_orp_api01" {
  name    = "${var.project_name}-orp-api01"
  comment = "Forward necessary values for API calls"

  cookies_config { cookie_behavior = "all" }
  query_strings_config { query_string_behavior = "all" }

  headers_config {
    header_behavior = "whitelist"
    headers {
      items = ["Content-Type", "Origin", "Host"]  # removed "Authorization", add lambda@edge or signed requests. when cookie_behavior = "all" is set, session/auth cookies are already being forwarded, which is how most app auth works in practice
    }
  }
}

##################################################################
# 4) Origin request policy for static (minimal)
##############################################################


# Explanation: Static origins need almost nothing—dawgs-armageddon forwards minimal values for maximum cache sanity.
resource "aws_cloudfront_origin_request_policy" "dawgs-armageddon_orp_static01" {
  name    = "${var.project_name}-orp-static01"
  comment = "Minimal forwarding for static assets"

  cookies_config { cookie_behavior = "none" }
  query_strings_config { query_string_behavior = "none" }
  headers_config { header_behavior = "none" }
}

##############################################################
# 5) Response headers policy (optional but nice)
##############################################################

# Explanation: Make caching intent explicit—dawgs-armageddon stamps Cache-Control so humans and CDNs agree.
resource "aws_cloudfront_response_headers_policy" "dawgs-armageddon_rsp_static01" {
  name    = "${var.project_name}-rsp-static01"
  comment = "Add explicit Cache-Control for static content"

  custom_headers_config {
    items {
      header   = "Cache-Control"
      override = true
      # FIX: max-age here must match the cache policy max_ttl (31536000 = 1 year).
      # A mismatch means browsers cache for 1 day while CloudFront caches for 1 year,
      # causing stale-content reports that are hard to reproduce and diagnose.
      value    = "public, max-age=31536000, immutable"
    }
  }
}


# ##############################################################
# #6) Patch your CloudFront distribution behaviors
# ##############################################################

# # Explanation: Default behavior is conservative—dawgs-armageddon assumes dynamic until proven static.
# default_cache_behavior {
#   target_origin_id       = "${var.project_name}-alb-origin01"
#   viewer_protocol_policy = "redirect-to-https"

#   allowed_methods = ["GET","HEAD","OPTIONS","PUT","POST","PATCH","DELETE"]
#   cached_methods  = ["GET","HEAD"]

#   cache_policy_id          = aws_cloudfront_cache_policy.dawgs-armageddon_cache_api_disabled01.id
#   origin_request_policy_id = aws_cloudfront_origin_request_policy.dawgs-armageddon_orp_api01.id
# }

# # Explanation: Static behavior is the speed lane—dawgs-armageddon caches it hard for performance.
# # FIX: target_origin_id must point to your S3 origin, NOT the ALB origin.
# # Sending /static/* to the ALB means static files go through your app server on
# # every cache miss—defeating the performance and cost purpose of this behavior.
# # Replace the value below with your actual S3 origin ID from Lab 2.
# ordered_cache_behavior {
#   path_pattern           = "/static/*"
#   target_origin_id       = "${var.project_name}-s3-origin01"  # was: -alb-origin01 (WRONG)
#   viewer_protocol_policy = "redirect-to-https"

#   allowed_methods = ["GET","HEAD","OPTIONS"]
#   cached_methods  = ["GET","HEAD"]

#   cache_policy_id            = aws_cloudfront_cache_policy.dawgs-armageddon_cache_static01.id
#   origin_request_policy_id   = aws_cloudfront_origin_request_policy.dawgs-armageddon_orp_static01.id
#   response_headers_policy_id = aws_cloudfront_response_headers_policy.dawgs-armageddon_rsp_static01.id
# }

