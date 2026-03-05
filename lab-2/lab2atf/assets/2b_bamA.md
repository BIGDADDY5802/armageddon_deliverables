# Lab 2B Honors — Origin-Driven Caching
## Complete Runbook, Instructions & Submission

---

## Objective

Implement safe caching for dynamic API endpoints where:
- Origin declares caching intent via `Cache-Control` header
- CloudFront obeys — caching only what the app explicitly marks as safe
- Proof is demonstrated using `x-cache`, `Age`, and body-visible evidence

---

## What Was Built

### Two Flask Endpoints

#### `/api/public-feed` — cacheable, 30 seconds

```python
@app.route("/api/public-feed")
def public_feed():
    import datetime
    from flask import make_response, jsonify
    data = {
        "server_time_utc": datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
        "message": "Message of the minute — cached by CloudFront for 30 seconds"
    }
    response = make_response(jsonify(data))
    response.headers["Cache-Control"] = "public, s-maxage=30, max-age=0"
    return response
```

#### `/api/list` — never cache

```python
@app.route("/api/list")
def list_notes():
    # ... fetch from RDS ...
    from flask import make_response
    resp = make_response("<h3>Notes:</h3>" + "".join([f"<li>{r[1]}</li>" for r in rows]) + "<br><a href='/'>Back</a>")
    resp.headers["Cache-Control"] = "private, no-store"
    return resp
```

---

### Terraform: AWS Managed Cache Policy (Data Source)

```hcl
# lab2b_honors_origin_driven.tf

data "aws_cloudfront_cache_policy" "dawgs-armageddon_managed_origin_cc01" {
  name = "UseOriginCacheControlHeaders"
}

data "aws_cloudfront_cache_policy" "dawgs-armageddon_managed_origin_cc_qs01" {
  name = "UseOriginCacheControlHeaders-QueryStrings"
}

data "aws_cloudfront_origin_request_policy" "dawgs-armageddon_managed_orp_all_viewer01" {
  name = "Managed-AllViewer"
}

data "aws_cloudfront_origin_request_policy" "dawgs-armageddon_managed_orp_all_viewer_except_host01" {
  name = "Managed-AllViewerExceptHostHeader"
}
```

**Why data sources instead of custom resources:** AWS owns and maintains these policies.
Terraform looks up their IDs at plan time — no hardcoded UUIDs, no lifecycle management.
`UseOriginCacheControlHeaders` has `default_ttl=0`, meaning silence from the origin
equals no caching. Safe by default.

---

### Terraform: Behavior Matrix

```
Order in cloudfront-lab-2a-distribution.tf (first match wins):
  1. /api/public-feed  → UseOriginCacheControlHeaders (managed)
  2. /api/*            → cache_api_disabled01 (custom, TTL=0)
  3. /api/list         → cache_public_get01 (explicit)
  4. /static/*         → cache_static01 (aggressive, S3 origin)
  5. default           → cache_api_disabled01 (catch-all)
```

**Why `/api/public-feed` must be first:** CloudFront evaluates behaviors
top-down. If `/api/*` appears above `/api/public-feed`, every request to
the public feed matches the wildcard and caching is disabled. Specific
patterns always go above general ones.

---

## s-maxage vs max-age

```
Cache-Control: public, s-maxage=30, max-age=0
```

| Directive | Who reads it | Effect |
|---|---|---|
| `s-maxage=30` | Shared caches only (CloudFront, Varnish) | Cache for 30 seconds at CDN |
| `max-age=0` | Browsers only | Revalidate every request — never serve stale from browser |
| `public` | Everyone | Response may be stored by shared caches |

**Why not just `max-age=30`:** That would also tell browsers to cache locally
for 30 seconds. Users could see stale data even after CloudFront has refreshed.
`s-maxage` + `max-age=0` splits CDN caching from browser caching cleanly.

---

## Deployment Instructions

### Step 1 — Deploy updated Flask app to EC2

```bash
# SSM into the healthy target instance
aws ssm start-session --target <INSTANCE_ID>

# Verify routes are present
grep "@app.route" /opt/rdsapp/app.py

# Verify Cache-Control headers are set
grep -n "Cache-Control" /opt/rdsapp/app.py

# Restart the service
sudo systemctl restart rdsapp
sleep 3

# Confirm headers at origin before testing through CloudFront
curl -si http://localhost:80/api/public-feed | grep -i cache-control
# Expected: Cache-Control: public, s-maxage=30, max-age=0

curl -si http://localhost:80/api/list | grep -i cache-control
# Expected: Cache-Control: private, no-store
```

### Step 2 — Apply Terraform

```bash
exit  # exit SSM session
terraform apply
# Adds: data sources, /api/public-feed behavior, /api/* behavior
# CloudFront propagation: 5–15 minutes
```

### Step 3 — Initialize the database (new instance only)

```bash
curl -si https://thedawgs2025.click/init
# Expected: 200 OK, "Init Success!"
```

---

## Verification Sequence

### Safety Proof — `/api/list` must never cache

```bash
curl -i https://thedawgs2025.click/api/list | sed -n '1,30p'
curl -i https://thedawgs2025.click/api/list | sed -n '1,30p'
```

**Expected on both hits:**
```
HTTP/1.1 200 OK
Cache-Control: private, no-store
X-Cache: Miss from cloudfront
# No Age header
# X-Amz-Cf-Id changes each request (origin contacted every time)
```

A `Hit from cloudfront` on this endpoint is a **data leak failure**.

---

### Honors Proof — `/api/public-feed` Miss → Hit → Miss cycle

**Hit 1 — populate cache (expect Miss)**
```bash
curl -si https://thedawgs2025.click/api/public-feed | grep -i "x-cache\|cache-control\|age"
```
```
cache-control: public, s-maxage=30, max-age=0
x-cache: Miss from cloudfront
# Age absent or 0
# server_time_utc = current time (origin was called)
```

**Hit 2 — within 30 seconds (expect Hit)**
```bash
curl -si https://thedawgs2025.click/api/public-feed | grep -i "x-cache\|cache-control\|age"
```
```
cache-control: public, s-maxage=30, max-age=0
x-cache: Hit from cloudfront
age: 8          ← non-zero, increases with each request
# server_time_utc = SAME as Hit 1 — body is frozen, origin not called
```

**Hit 3 — after TTL expires (expect Miss)**
```bash
sleep 31
curl -si https://thedawgs2025.click/api/public-feed | grep -i "x-cache\|cache-control\|age"
```
```
cache-control: public, s-maxage=30, max-age=0
x-cache: Miss from cloudfront
age: 0          ← reset — new cache entry created
# server_time_utc = NEW time — origin was called again
```

---

## Failure Injection Challenges

### Challenge 1 — Origin forgot Cache-Control

**Inject the failure:**
```bash
aws ssm start-session --target <INSTANCE_ID>
sudo sed -i 's/    response.headers\["Cache-Control"\] = "public, s-maxage=30, max-age=0"/    # response.headers["Cache-Control"] = "public, s-maxage=30, max-age=0"/' /opt/rdsapp/app.py
sudo systemctl restart rdsapp
exit
```

**Observe:**
```bash
curl -si https://thedawgs2025.click/api/public-feed | grep -i "x-cache\|cache-control\|age"
curl -si https://thedawgs2025.click/api/public-feed | grep -i "x-cache\|cache-control\|age"
```

**Expected:** Both hits show `X-Cache: Miss from cloudfront`. No `Cache-Control`
header. No `Age`. Timestamps change on every request — origin is being hit every
time. `UseOriginCacheControlHeaders` defaults to TTL=0 when origin sends nothing.
CloudFront passes every request through to Flask, increasing origin load.

**Fix — restore the header:**
```bash
aws ssm start-session --target <INSTANCE_ID>
sudo sed -i '126s/.*/    response.headers["Cache-Control"] = "public, s-maxage=30, max-age=0"/' /opt/rdsapp/app.py
sudo systemctl restart rdsapp
exit
```

**Confirm fix:**
```bash
curl -si https://thedawgs2025.click/api/public-feed | grep -i "x-cache\|cache-control\|age"
curl -si https://thedawgs2025.click/api/public-feed | grep -i "x-cache\|cache-control\|age"
# Second hit must show: X-Cache: Hit from cloudfront
```

---

### Challenge 2 — Cache Fragmentation (forwarding unnecessary headers)

**What causes it:** Including `User-Agent` or all headers in the cache key means
every different browser, device, or client gets its own cache entry. A response
cached for Chrome on Windows is not reused for Safari on Mac — even though the
response is identical. Hit ratio tanks to near zero.

**Simulate it:** Add `User-Agent` to the cache key in the `/api/public-feed` behavior:

```hcl
# BAD — do not deploy this
parameters_in_cache_key_and_forwarded_to_origin {
  headers_config {
    header_behavior = "whitelist"
    headers { items = ["User-Agent"] }  # fragments the cache
  }
  cookies_config  { cookie_behavior = "none" }
  query_strings_config { query_string_behavior = "none" }
}
```

**Observe:** Hit ratio drops. Every `curl -A "different-agent"` is a Miss even
within the 30-second TTL window because each User-Agent value creates a separate
cache key.

**Fix:** Remove all headers from the cache key. The correct configuration has
`header_behavior = "none"`. Public endpoints with no per-user variation need no
headers in the cache key.

```hcl
# CORRECT
headers_config { header_behavior = "none" }
```

CloudFront's documentation explicitly warns that forwarding unnecessary headers
into the cache key reduces your hit ratio and increases origin load.

---

## Header Reference

| Header | Source | Meaning |
|---|---|---|
| `cache-control` | Flask (origin) | Passed through unchanged by CloudFront |
| `x-cache: Miss from cloudfront` | CloudFront edge | Origin was contacted, response now cached |
| `x-cache: Hit from cloudfront` | CloudFront edge | Served from edge cache, origin not contacted |
| `x-cache: Error from cloudfront` | CloudFront edge | Origin returned 4xx/5xx |
| `age` | CloudFront edge | Seconds since response was cached. Increments to TTL then resets |
| `x-amz-cf-pop` | CloudFront edge | Which edge location served the request (e.g. DFW59-P7) |

---

## Submission Checklist

- [ ] Terraform diff shows `data "aws_cloudfront_cache_policy"` with `UseOriginCacheControlHeaders`
- [ ] `/api/public-feed` behavior uses the managed policy data source ID
- [ ] Hit 1 shows `x-cache: Miss from cloudfront` and `cache-control: public, s-maxage=30, max-age=0`
- [ ] Hit 2 (within 30s) shows `x-cache: Hit from cloudfront` and non-zero `age`
- [ ] Hit 3 (after 31s) shows `x-cache: Miss from cloudfront` and `age: 0`
- [ ] Both `/api/list` hits show `x-cache: Miss from cloudfront` and `cache-control: private, no-store`
- [ ] Failure Injection 1 documented: no Hit observed when Cache-Control removed
- [ ] Failure Injection 2 explained: User-Agent in cache key fragments hit ratio
- [ ] Submission paragraph answered (below)

---

## Submission Answers

### Why origin-driven caching is safer for APIs

Origin-driven caching is safer for APIs because the app itself decides what can be stored in a cache and for how long, instead of the cloud setup making that choice for everything.
If you set cache rules directly in Terraform, those rules apply to every response the same way. That can be risky — a reply meant for one user could accidentally be shown to someone else if the cache rules aren’t set up perfectly.
When your app (like Flask) adds headers such as “Cache-Control: public, s-maxage=30,” it’s clearly saying, “This response is safe to share with anyone for 30 seconds.” But if it says “private, no-store,” then CloudFront won’t cache it at all — even if Terraform says it can. The app’s rules always win.
The built-in “UseOriginCacheControlHeaders” policy helps with this by setting the default to “don’t cache” when the app doesn’t send any caching rules. That way, the system never assumes something is safe to store unless the app says so.

### When you would still disable caching entirely

You would completely turn off caching for certain API endpoints — like login pages, payment actions, or anything that changes data — because even a short delay or reused response could cause serious problems.
For example, if a cached version of a login or payment request were reused, someone might see another person’s data or repeat a transaction by mistake.
The key idea is this: origin-driven caching works well for safe, read-only endpoints where the app can decide what’s OK to store temporarily. But for sensitive actions — like logging in, sending forms, or saving data — it’s safer to say, “Never cache this” under any circumstance.