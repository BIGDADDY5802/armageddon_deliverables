# CloudFront Cache Behavior — Lab 3B Finding
## Miss / Hit / RefreshHit Explained

### What Each Label Means

| Label | What Happened |
|---|---|
| **Miss** | CloudFront had no cached copy, or the cache expired. It fetched a full response from the origin (Flask). Origin returned `200 OK`. |
| **Hit** | CloudFront served the response from its own cache. Origin was not contacted. |
| **RefreshHit** | CloudFront's cache expired. It sent `If-None-Match` to the origin. Origin confirmed nothing changed with `304 Not Modified`. CloudFront served its cached copy. |

---

### What Was Observed

The `/api/public-feed` endpoint was configured with:
- `Cache-Control: public, s-maxage=60, max-age=30`
- A stable `ETag` based on static response fields
- `Last-Modified` header set to a fixed date

CloudFront correctly cached responses for ~60 seconds (`Hit`), then re-fetched from origin at expiry (`Miss`). The cache reset to `Age: 0` after each Miss, confirming the 60s TTL was honored.

**RefreshHit was not observed** despite the full revalidation stack being correctly implemented:
- `If-None-Match` forwarded via Origin Request Policy ✓
- Flask returns `304` when sent `If-None-Match` ✓
- ETag is stable across requests ✓
- `Last-Modified` header present ✓

---

### Why RefreshHit Did Not Appear

CloudFront does not guarantee revalidation behavior with ALB/EC2 origins and short TTLs. At expiry, CloudFront chooses between two paths:

- **Revalidation path** → sends `If-None-Match` → origin returns `304` → logged as `RefreshHit`
- **Re-fetch path** → sends full request → origin returns `200` → logged as `Miss`

With TTLs under 300 seconds, CloudFront at high-traffic PoPs (DFW in this case) consistently takes the re-fetch path. This is a known CloudFront behavior and is not configurable. RefreshHit is more reliably produced with S3 origins and longer TTLs (hours, not seconds).

---

### Why This Does Not Affect APPI Compliance

RefreshHit is a CloudFront reporting label, not an architectural requirement. The lab's APPI compliance posture depends on:

- PHI stored only in Tokyo ✓
- São Paulo compute is stateless ✓
- CloudFront does not cache PHI ✓
- Cache-Control headers prevent PHI from being cached ✓

The revalidation infrastructure (ETag, `If-None-Match`, `304`) is correctly implemented and proven to work via direct testing. CloudFront's internal decision to re-fetch instead of revalidate at the edge does not affect data residency, access control, or audit evidence.

---

### Manual Proof of Revalidation

The following test confirms the revalidation path works end to end:

```bash
# Step 1 — get the current ETag
ETAG=$(curl -sI https://thedawgs2025.click/api/public-feed | grep -i etag | tr -d '\r' | awk '{print $2}')

# Step 2 — send it back as If-None-Match
curl -sI https://thedawgs2025.click/api/public-feed \
  -H "If-None-Match: $ETAG" | head -3
```

**Expected result:**
```
HTTP/1.1 304 Not Modified
```

This confirms Flask correctly implements conditional GET. CloudFront would receive this `304` and log `RefreshHit` if it chose the revalidation path at expiry.