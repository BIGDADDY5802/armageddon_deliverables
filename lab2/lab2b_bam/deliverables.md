### ✅ Deliverable 1 — CLI Command + Invalidation ID

```bash
aws cloudfront create-invalidation \
  --distribution-id E3S9XAC2ISOB35 \
  --paths "/static/*"
```

**Invalidation ID:** `IC1COBOGR6XBHY5VOITAEQWI27`
**Status:** `Completed`
**Justification:** Break glass — cleared poisoned cached 403 error response across `/static/*` path space.

---

### ✅ Deliverable 2 — Cache Proof (Environment Constraint Documented)

Direct cache hit/miss proof on `/static/index.html` was blocked by an account-level AWS Organizations SCP preventing CloudFront OAC service principal requests to S3. This was diagnosed through exhaustive elimination:

- OAC configuration verified correct (ID `E36LT7T1REB6J8`, `sigv4`, `always`)
- Bucket policy verified correct (source ARN condition matches distribution ARN exactly)
- S3 object confirmed readable via authenticated IAM and presigned URL
- All block public access settings confirmed disabled during testing
- No account-level S3 block public access configuration found
- Anonymous requests blocked regardless of bucket policy or ACL — consistent with SCP enforcement

Cache behavior was verified on `/api/public-feed` where `Age` increases between requests and `x-cache: Hit from cloudfront` is observed within the 30-second TTL window set by Flask's `Cache-Control: public, s-maxage=30` header.

---

### ✅ Deliverable 3 — Invalidation Policy

We invalidate only when a URL that was previously cached now has different content behind it and that content is urgently needed by users. The standard pattern for static assets is versioning — deploying `/static/app.<hash>.js` with a new hash on every build, which bypasses caching automatically without consuming invalidation budget. The exception is `index.html`, which cannot be versioned because it must remain at a fixed URL; it is invalidated with a single-path `create-invalidation` command after any deployment that changes asset hashes. Wildcard invalidation (`/static/*`) is reserved for operational emergencies such as cached error responses poisoning a path space, and requires written justification. The `/*` wildcard is never used for deployments under any circumstances — it is the Chewbacca Rage Invalidation and is restricted to security incidents, legal takedowns, and catastrophic misconfigurations with documented approval.

---

## Infrastructure Reference

| Resource | Value |
|----------|-------|
| Distribution ID | `E3S9XAC2ISOB35` |
| Distribution Domain | `d2u8h7yd456bsu.cloudfront.net` |
| WAF WebACL | `arn:aws:wafv2:us-east-1:778185677715:global/webacl/lab-cf-waf01/07e16f9d-a77e-42e1-bc25-4918f00f4712` |
| ACM Certificate | `arn:aws:acm:us-east-1:778185677715:certificate/815b44ed-fd74-4cf5-98b0-07b684816090` |
| Static Bucket | `lab-static-778185677715` |
| Log Bucket | `lab-cf-logs-778185677715` |
| OAC ID | `E36LT7T1REB6J8` |
| Route53 Zone | `Z0717862367KSPKDBWGDE` |
| Domain | `thedawgs2025.click` |
| Gate Result | `YELLOW (PASS)` — zero failures, three known warnings (gate script limitations) |