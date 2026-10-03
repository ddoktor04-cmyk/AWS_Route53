---
name: aws-s3
description: S3 bucket configuration. Use when creating storage buckets, setting up lifecycle policies, configuring versioning, or managing bucket policies.
metadata:
  author: cmd521
  version: "1.0"
---

# AWS S3 Storage

## When to Use

- Creating storage buckets
- Storing static assets
- Setting up lifecycle policies
- Configuring versioning
- Managing bucket policies

## Bucket Naming Conventions

- **Globally unique** across all AWS accounts
- **Lowercase letters, numbers, hyphens** only
- **3-63 characters** long
- **Format**: `{project}-{environment}-{purpose}`

```
myapp-prod-assets
myapp-staging-backups
myapp-dev-logs
```

## Basic S3 Bucket

```hcl
resource "aws_s3_bucket" "main" {
  bucket = "${var.project}-${var.environment}-assets"

  tags = {
    Name        = "${var.project}-${var.environment}-assets"
    Environment = var.environment
  }
}
```

## Block Public Access (Always Enable)

```hcl
resource "aws_s3_bucket_public_access_block" "main" {
  bucket = aws_s3_bucket.main.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

## Versioning

```hcl
resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id

  versioning_configuration {
    status = "Enabled"
  }
}
```

## Server-Side Encryption

### SSE-S3 (AES-256)

```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

### SSE-KMS

```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.main.arn
    }
  }
}
```

## Lifecycle Rules

```hcl
resource "aws_s3_bucket_lifecycle_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}
```

## Bucket Policy

> ⚠️ The `EnforceHTTPS` deny statement below is for **REST (HTTPS) endpoints
> only**. Omit it for static website hosting — website endpoints are HTTP-only,
> the deny would return 403 (see "Static Website Hosting").

```hcl
resource "aws_s3_bucket_policy" "main" {
  bucket = aws_s3_bucket.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "EnforceHTTPS"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.main.arn,
          "${aws_s3_bucket.main.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}
```

## Static Website Hosting

```hcl
resource "aws_s3_bucket_website_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}
```

Requires a **public-read bucket policy** (`s3:GetObject` for `Principal = "*"`),
otherwise the endpoint returns 403 for every object.

### Custom domain via CNAME — the bucket name MUST equal the domain

S3 website endpoints pick the bucket from the **`Host` header** of the incoming
request. A browser that opens `http://example.com/` sends `Host: example.com`,
so S3 looks up a bucket literally named `example.com`.

Verified behaviour (eu-north-1):

| Request | Result |
|---------|--------|
| `Host: example.com.s3-website.eu-north-1.amazonaws.com` | 200 |
| `Host: example.com` (what a CNAME'd browser sends), bucket named differently | **404 NoSuchBucket** |
| `Host: example.com`, bucket named `example.com` | 200 |

Therefore: **name the bucket exactly like the domain** you point the CNAME at,
then add `CNAME @ → <bucket>.s3-website.<region>.amazonaws.com.` (trailing dot).

### No access by bare IP address

- The endpoint **IPs are not static** — they rotate between lookups
  (e.g. `3.5.216.102` → `3.5.218.145` → `3.5.216.71`).
- `http://<endpoint-ip>/` sends `Host: <ip>` → S3 looks up bucket `<ip>` →
  AWS error/redirect page instead of the site.
- Path-style `http://<rest-ip>/<bucket>/index.html` over plain HTTP returns a
  broken `301` without a usable `Location` header.
- Serving a site by literal IP requires an **EC2 instance with an Elastic IP**
  reverse-proxying to the website endpoint (and rewriting `Host`).

### Website endpoint is HTTP-only

- Endpoint format: `http://<bucket>.s3-website.<region>.amazonaws.com`
  (dashes and dots region formats are both valid; Terraform outputs the dot one).
- **Do NOT add the `EnforceHTTPS` deny statement** to the bucket policy of a
  website-hosting bucket — every request would get 403. Keep only public read.
- HTTPS needs CloudFront + ACM (out of scope for a pure-S3 lab).

### DNS cutover & browser troubleshooting (custom domain)

All verified in the `hwbarabash1.pp.ua` lab (nic.ua registrar, eu-north-1):

- **Trailing dot — only in the DNS value, never in the browser URL.**
  The registrar record needs `example.com.s3-website.<region>.amazonaws.com.`
  (absolute name), but pasting that value *with the dot* into the address bar
  gives `http://…amazonaws.com./` → **404 NoSuchBucket** (verified).
- **Always type an explicit `http://`.** Website endpoints have no TLS, and
  browsers that get a scheme-less hostname try `https://` first →
  "connection closed" error instead of the site (verified: `https://` to the
  endpoint times out on :443).
- **nic.ua name servers**: a domain's zone lives on `ns10/ns11/ns12.uadns.com`;
  `ns1/ns2/ns3.uadns.com` are the *parent* `pp.ua` zone servers. When checking
  the delegation, expect `ns10-12`, not `ns1-3`.
- **Stale resolver cache after the NS/DNS switch**: resolvers keep serving the
  pre-change A record (e.g. the registrar's parking IP `135.181.41.169`) until
  its TTL expires — up to a couple of hours, visible as `ping → old IP` while
  the config is already correct. Diagnose by comparing with public resolvers
  (`nslookup example.com 8.8.8.8` / `1.1.1.1` → already the new answer).
  `ipconfig /flushdns` clears only the local Windows cache, not the ISP's.

## CORS Configuration

```hcl
resource "aws_s3_bucket_cors_configuration" "main" {
  bucket = aws_s3_bucket.main.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["https://example.com"]
    max_age_seconds = 3000
  }
}
```

## Environment Differences

| Aspect | Dev | Staging | Prod |
|--------|-----|---------|------|
| Versioning | Suspended | Enabled | Enabled |
| Lifecycle | 30 days → delete | 30 → IA → Glacier | 30 → IA → Glacier |
| Encryption | SSE-S3 | SSE-S3 | SSE-KMS |
| Force destroy | true | false | false |

## Gotchas

1. **Naming**: Cannot change bucket name after creation (replace = destroy + create)
2. **Region**: Cannot change region after creation
3. **Force Destroy**: Use `force_destroy = true` only for dev
4. **Versioning**: Once enabled, can only suspend (not disable)
5. **Access Logging**: Enable for audit purposes
6. **Requester Pays**: For buckets shared with other accounts
7. **Website hosting**: bucket name must equal the CNAME domain — S3 routes
   website requests by `Host` header (see "Static Website Hosting")
8. **Website hosting**: no bare-IP access and no HTTPS; public-read policy is
   mandatory, `aws:SecureTransport` deny breaks the endpoint

## See Also

- [assets/s3.tf.example](assets/s3.tf.example) for complete example
