# Lab 2B — Safe Caching Runbook
## Origin-Driven Cache-Control for a Public GET Endpoint

---

## What This Lab Requires

You must prove three things:

1. A public GET endpoint sends `Cache-Control` from the origin (Flask)
2. CloudFront respects that header and caches accordingly
3. You can demonstrate the Miss → Hit → Miss cycle with evidence

---

## Why Cache-Control Is Preferred Over Expires

| | `Cache-Control: max-age=30` | `Expires: Thu, 01 Jan 2026 12:00:00 GMT` |
|---|---|---|
| **Type** | Relative duration | Absolute timestamp |
| **Clock skew** | Immune — counts from response time | Breaks silently if clocks differ |
| **RFC 7234** | Wins if both headers present | Loses to Cache-Control |
| **Readability** | Self-explanatory | Requires mental math |
| **CDN support** | Universal standard | Legacy, deprecated pattern |

**Rule:** Always use `Cache-Control`. Never use `Expires` for new infrastructure.

---

## What Was Built

### Flask endpoint: `/list` (renamed to `/api/list`)

```python
@app.route("/api/list")
def list_notes():
    # ... fetch from RDS ...
    from flask import make_response
    response = make_response("<h3>Notes:</h3>" + rows + "")
    response.headers["Cache-Control"] = "public, max-age=30"
    return response
```

**Why `make_response()`** — Flask's default `return` sets no cache headers.
`make_response()` gives you a response object you can attach headers to before returning.

### CloudFront cache policy: `dawgs-armageddon_cache_public_get01`

```hcl
resource "aws_cloudfront_cache_policy" "dawgs-armageddon_cache_public_get01" {
  name        = "${var.project_name}-cache-public-get01"
  min_ttl     = 0
  default_ttl = 0      # if origin sends no Cache-Control, do not cache
  max_ttl     = 60     # cap at 60s even if origin requests more

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config  { cookie_behavior  = "none" }
    headers_config  { header_behavior  = "none" }
    query_strings_config { query_string_behavior = "none" }
    enable_accept_encoding_gzip   = true
    enable_accept_encoding_brotli = true
  }
}
```

**Key design decisions:**

- `default_ttl = 0` — if Flask forgets to send `Cache-Control`, CloudFront does not cache. Safe by default.
- `max_ttl = 60` — a safety ceiling. Origin cannot accidentally set a huge TTL.
- No cookies/headers/query strings in cache key — this is a public endpoint with no per-user variation.

### CloudFront behavior: `/api/list`

```hcl
ordered_cache_behavior {
  path_pattern           = "/api/list"
  target_origin_id       = "${var.project_name}-alb-origin"
  viewer_protocol_policy = "redirect-to-https"
  allowed_methods        = ["GET", "HEAD"]
  cached_methods         = ["GET", "HEAD"]
  cache_policy_id          = aws_cloudfront_cache_policy.dawgs-armageddon_cache_public_get01.id
  origin_request_policy_id = aws_cloudfront_origin_request_policy.dawgs-armageddon_orp_api01.id
}
```

---

## How It Works End-to-End

```
Browser → CloudFront edge → ALB → Flask
                ↑
         checks cache first

If cache MISS:
  CloudFront → ALB → Flask → returns body + Cache-Control: public, max-age=30
  CloudFront stores response for 30 seconds
  Returns to browser with x-cache: Miss from cloudfront

If cache HIT (within 30s):
  CloudFront serves stored copy
  Does NOT contact ALB or Flask
  Returns with x-cache: Hit from cloudfront, Age: <seconds since cached>

After 30s (TTL expired):
  CloudFront discards cached copy
  Next request is a Miss again
  Cycle repeats
```

---

## Verification Sequence

Run these commands in order. Save the outputs for submission.

### Hit 1 — Populate the cache (expect Miss)

```bash
curl -si https://thedawgs2025.click/api/list \
  | grep -E "cache-control|x-cache|age"
```

**Expected:**
```
cache-control: public, max-age=30
x-cache: Miss from cloudfront
age: 0
```

### Hit 2 — Within 30 seconds (expect Hit)

```bash
curl -si https://thedawgs2025.click/api/list \
  | grep -E "cache-control|x-cache|age"
```

**Expected:**
```
cache-control: public, max-age=30
x-cache: Hit from cloudfront
age: 8        ← non-zero, increases with each request
```

### Hit 3 — After 31 seconds (expect Miss again)

```bash
sleep 31
curl -si https://thedawgs2025.click/api/list \
  | grep -E "cache-control|x-cache|age"
```

**Expected:**
```
cache-control: public, max-age=30
x-cache: Miss from cloudfront
age: 0        ← reset — new cache entry
```

---

## Header Reference

| Header | Source | What it means |
|---|---|---|
| `cache-control` | Flask (origin) | Passed through unchanged by CloudFront |
| `x-cache: Miss from cloudfront` | CloudFront edge | Origin was contacted, response now cached |
| `x-cache: Hit from cloudfront` | CloudFront edge | Served from edge cache, origin not contacted |
| `age` | CloudFront edge | Seconds since this response was cached. Increments until TTL, then resets to 0 on next Miss |
| `x-amz-cf-pop` | CloudFront edge | Which edge location served the request (e.g. DFW59-P3) |

---

## Common Mistakes

**Mistake: `Cache-Control` header missing from response**

Cause: Using `return "..."` instead of `make_response()`.

Fix:
```python
from flask import make_response
response = make_response(your_content)
response.headers["Cache-Control"] = "public, max-age=30"
return response
```

**Mistake: Always seeing Miss, never Hit**

Cause 1: CloudFront behavior is pointing at the wrong cache policy (one with TTL=0).
Cause 2: The `/api/list` ordered behavior is below `/api/*` in the distribution — CloudFront matches top-down, first match wins.

Fix: Confirm behavior order in the distribution. `/api/list` must come before `/api/*`.

**Mistake: Hit never expires**

Cause: `max_ttl` in the cache policy is set too high, overriding the origin's `max-age=30`.

Fix: Set `max_ttl = 60` (or any value ≥ 30 but reasonable). CloudFront uses `min(origin TTL, max_ttl)`.

**Mistake: Different edge nodes show inconsistent results**

Cause: CloudFront has hundreds of edge locations. Your two curl requests may hit different POPs.

Fix: Check `x-amz-cf-pop` — if it changes between requests, force the same edge by running from the same machine quickly, or accept that cache state is per-edge.

---

## Deployment Steps

1. Update `/opt/rdsapp/app.py` on the EC2 instance with the new `make_response()` route
2. Restart the service: `sudo systemctl restart rdsapp`
3. Verify Flask is sending the header directly (before CloudFront):
   ```bash
   curl -si http://<ALB-DNS>/api/list | grep cache-control
   # Must show: cache-control: public, max-age=30
   ```
4. Run `terraform apply` to deploy the cache policy and behavior
5. Wait 5–15 minutes for CloudFront propagation
6. Run the three-hit verification sequence above

---

## Submission Checklist

- [ ] Flask route uses `make_response()` and sets `Cache-Control: public, max-age=30`
- [ ] CloudFront cache policy has `default_ttl=0` and `max_ttl=60`
- [ ] `/api/list` ordered behavior exists and is ordered before `/api/*`
- [ ] Hit 1 shows `x-cache: Miss from cloudfront` and `age: 0`
- [ ] Hit 2 (within 30s) shows `x-cache: Hit from cloudfront` and `age > 0`
- [ ] Hit 3 (after 31s) shows `x-cache: Miss from cloudfront` and `age: 0`
- [ ] One paragraph explaining why `Cache-Control` is preferred over `Expires`