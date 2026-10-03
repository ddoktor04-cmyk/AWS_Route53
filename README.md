# AWS Lab — Route 53 Latency-Based Routing

Two Ubuntu/Apache web servers in two AWS regions, one domain
(`hwbarabash1.pp.ua`), and Amazon Route 53 **latency-based routing** that
sends every visitor to the server with the lowest latency.

| Role | Region | Page heading | Routing policy |
|---|---|---|---|
| Primary | `eu-north-1` (Stockholm, EU) | ОСНОВНИЙ СЕРВЕР | `latency_routing_policy { region = "eu-north-1" }` |
| Backup | `ca-central-1` (Canada Central) | РЕЗЕРВНИЙ СЕРВЕР | `latency_routing_policy { region = "ca-central-1" }` |

## How it works

1. Route 53 hosts a public zone for the domain with two `A` records —
   one per region, each with `set_identifier` + `latency_routing_policy`.
2. When a client resolves `hwbarabash1.pp.ua`, Route 53 measures latency
   from the client to each region and answers with the closest server's IP.
3. Each instance runs Apache 2 (Ubuntu 24.04, installed via `user_data`)
   and serves a static page showing which server answered.

## Usage

```bash
terraform init
terraform plan     # review the plan
terraform apply
```

Key outputs:

- `nameservers` — the 4 Route 53 name servers to enter at nic.ua
- `primary_url` / `backup_url` — direct links to each server
- `domain_url` — the site via the domain (after DNS delegation)

## Delegate DNS at nic.ua

1. [nic.ua](https://nic.ua) → **Домени** → gear icon next to `hwbarabash1.pp.ua`
2. Section **NS-сервери** → choose **«Власні сервери імен»**
3. Click **«Змінити»** and enter the 4 `nameservers` values from Terraform
   output — one per line, no quotes, no IPs
4. Save. Propagation takes **4–72 hours** (resolver caches)

> ⚠️ Route 53 hosted zones are free only when deleted **within 12 hours**
> of creation — do the whole lab in one session (see Cost).

## Verify

```powershell
# Direct hits — each server shows its own heading
curl http://<primary_ip>/
curl http://<backup_ip>/

# Delegation — must return *.awsdns-* servers
Resolve-DnsName hwbarabash1.pp.ua -Type NS

# From Europe you should get the Stockholm IP
Resolve-DnsName hwbarabash1.pp.ua -Type A -Server 8.8.8.8
```

Check the latency effect from around the world:
<https://www.whatsmydns.net/#A/hwbarabash1.pp.ua>
(North America → Canada IP, Europe → Stockholm IP).

## Cost (kept at $0)

| Item | Cost | Strategy |
|---|---|---|
| Route 53 hosted zone | $0.50/month, **free if deleted within 12 h** | run the lab in one session |
| Route 53 queries | $0.40/million | pennies |
| 2 × t3.micro | free tier (750 h/month total) | destroy after the lab |
| 2 × EIP, gp3, traffic | free while attached / within free tier | — |

## Teardown

```bash
terraform destroy
```

Afterwards revert NS at nic.ua back to **«Сервери імен NIC.UA»**
(`ns10–ns12.uadns.com`), otherwise the domain points at deleted servers.
