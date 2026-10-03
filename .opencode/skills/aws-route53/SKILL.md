---
name: aws-route53
description: Route 53 DNS setup: hosted zones, records, routing policies (latency, weighted, failover), NS delegation, stale-DNS troubleshooting, free-tier cost control. Use when creating DNS zones, pointing domains to AWS, or routing traffic by latency or weight.
metadata:
  author: cmd521
  version: "1.0"
---

# Amazon Route 53

## When to Use

- Public/private hosted zones for a domain
- Routing policies: latency-based, weighted, failover, geolocation
- Delegating DNS from a registrar to AWS
- Troubleshooting DNS propagation

## Hosted Zone

```hcl
resource "aws_route53_zone" "main" {
  name = var.domain  # e.g. "hwbarabash1.pp.ua"
}

output "nameservers" {
  value = aws_route53_zone.main.name_servers  # 4 NS for the registrar
}
```

## Routing Policies

Every routing-policy record **requires** a unique `set_identifier`,
and policy blocks conflict with each other (one policy per record).

### Latency-Based Routing (lab-proven)

Route 53 answers with the record whose region has the lowest latency
**from the resolver that asked**.

```hcl
resource "aws_route53_record" "primary" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain
  type    = "A"
  ttl     = 60
  records = [aws_eip.primary.public_ip]

  set_identifier = "eu-north-1"          # REQUIRED, unique per record

  latency_routing_policy {
    region = var.primary_region         # REQUIRED, the AWS region
  }
}
```

### Weighted Routing

`weight` = 0..255; traffic share = weight / sum(weights).
Example: weights **200 and 50** → 80% / 20% of queries.

```hcl
resource "aws_route53_record" "primary" {
  # ... same as above, but:
  set_identifier = "primary"

  weighted_routing_policy {
    weight = 200
  }
}
```

### Failover Routing

`failover = "PRIMARY" | "SECONDARY"` + Route 53 health checks;
secondary answers only when primary fails health check.

## Multi-Region Providers

Latency lab pattern — one provider per region:

```hcl
provider "aws" {
  region = var.primary_region   # default
}

provider "aws" {
  alias  = "ca"
  region = var.backup_region
}

# resources pick their provider:
resource "aws_instance" "backup" {
  provider = aws.ca
  # ...
}
```

Data sources (`aws_ami`, `aws_vpc`) and regional resources (SG, EIP)
must repeat the `provider` argument. Route 53 itself is global —
use the default provider.

## NS Delegation at the Registrar

1. Output `aws_route53_zone.main.name_servers` (4 names, e.g.
   `ns-126.awsdns-15.com` …)
2. Registrar panel → domain → NS servers → **custom/own name servers**
   (nic.ua: «NS-сервери» → «Власні сервери імен» → one NS per line,
   no quotes, no IPs)
3. Propagation: registrar panel says 4–72 h (mostly resolver caches);
   the parent zone itself usually updates in minutes
4. **After `terraform destroy` you MUST revert NS at the registrar**,
   otherwise the domain points at deleted servers

## Verifying Latency Routing From One Desk

You cannot physically be in two regions — simulate clients with
Google DoH + EDNS client subnet (ECS):

```bash
# "Client" in Europe (RIPE subnet):
curl "https://dns.google/resolve?name=example.com&type=A&edns_client_subnet=193.0.6.0/24"

# "Client" in Canada (Rogers subnet):
curl "https://dns.google/resolve?name=example.com&type=A&edns_client_subnet=24.114.0.0/16"

# "Client" in the USA (Google subnet):
curl "https://dns.google/resolve?name=example.com&type=A&edns_client_subnet=8.8.8.0/24"
```

Different `data` IPs per subnet = latency routing works.
Also cross-check with <https://www.whatsmydns.net/#A/domain>.

## Stale-DNS Troubleshooting

Classic symptoms and causes after a nameserver switch:

| Symptom | Cause | Fix |
|---|---|---|
| Old answers right after NS switch | old child zone servers still answer with old apex NS/records | query the **parent** zone servers (`nslookup -type=NS domain parent-ns`), not the old child |
| Mixed old/new answers | resolver edge caches expire gradually (e.g. Google 8.8.8.8) | wait out the old TTL (up to 1 h) |
| One program works, another 404s | program has its own DNS cache (browser) | restart browser fully; `ipconfig /flushdns` clears only Windows cache |
| Two apps disagree on the same PC | multiple adapters → different DNS servers | `Get-DnsClientServerAddress`, query each server directly |
| `Resolve-DnsName … -Server X` → "server failure" | tool quirk | fall back to `nslookup -type=NS name server` |

Old records with **TTL 3600** keep haunting resolvers for up to an hour
after the switch — a 404 from the *old* infrastructure right after
delegation is normal, not a broken deployment.

## Cost (Free-Tier Lab Strategy)

| Item | Price | Lab strategy |
|---|---|---|
| Hosted zone | $0.50/month, **not prorated**, charged at creation | **deleted within 12 h of creation → NOT charged** — do the whole lab in one session |
| Standard queries | $0.40 / million | pennies |
| Latency-routed queries | slightly higher (~$0.06/million per 100k) | pennies |
| Alias → ELB/CloudFront/S3 | free queries | prefer alias for prod |

12-hour grace is per zone creation; there is no way to extend it —
schedule `terraform destroy` before the deadline.

## Gotchas

1. **`set_identifier` is mandatory** for latency/weighted/failover/
   geolocation records — plan fails without it (or warns at apply)
2. Policy blocks conflict: a record can carry only one routing policy
3. Apex (zone apex) cannot use CNAME — use alias records or A records;
   `ttl = 60` makes labs converge fast
4. NS switch moves the **whole zone**: records at the old provider
   become unreachable leftovers (delete them for cleanliness)
5. Two `aws_route53_zone` resources with the same name in one account
   are allowed — you may find leftovers from earlier experiments
6. Latency routing picks per **resolver location**, not per user
   location — mobile/VPN users may land in an unexpected region

## See Also

- [aws-ec2](../aws-ec2/SKILL.md) for the servers behind the records
- [aws-security-groups](../aws-security-groups/SKILL.md) for HTTP access
- [assets/route53.tf.example](assets/route53.tf.example) for a complete example
