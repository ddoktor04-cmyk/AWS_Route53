---
name: aws-elb
description: Load balancer configuration. Use when setting up ALB/NLB, creating target groups, configuring listeners, or managing health checks.
metadata:
  author: cmd521
  version: "1.0"
---

# AWS Elastic Load Balancing

## When to Use

- Setting up Application Load Balancer (ALB)
- Setting up Network Load Balancer (NLB)
- Creating target groups
- Configuring listeners
- Managing health checks

## ALB vs NLB

| Feature | ALB | NLB |
|---------|-----|-----|
| Protocol | HTTP, HTTPS | TCP, UDP, TLS |
| Use case | Web applications | High performance, static IP |
| Routing | Path, Host, Header | IP, Port |
| Latency | Milliseconds | Sub-millisecond |
| Cost | Lower | Higher |

## Application Load Balancer

```hcl
resource "aws_lb" "web" {
  name               = "${var.project}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.web_security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = var.environment == "prod" ? true : false

  access_logs {
    bucket  = var.access_logs_bucket
    enabled = true
  }

  tags = {
    Name        = "${var.project}-${var.environment}-alb"
    Environment = var.environment
  }
}
```

## Target Group

```hcl
resource "aws_lb_target_group" "web" {
  name     = "${var.project}-${var.environment}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 3
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    path                = "/"
    matcher             = "200"
  }

  tags = {
    Name = "${var.project}-${var.environment}-tg"
  }
}
```

## Listeners

### HTTP to HTTPS Redirect

```hcl
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}
```

### HTTPS Listener

```hcl
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.web.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
```

### Path-Based Routing

```hcl
resource "aws_lb_listener_rule" "api" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}
```

## Target Group Attachments

```hcl
resource "aws_lb_target_group_attachment" "web" {
  count            = var.instance_count
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = var.instance_ids[count.index]
  port             = 80
}
```

## Accessing the Load Balancer

After `terraform apply` the ALB URL is not an IP — it is an AWS DNS name.

```bash
# Get the URL from outputs
terraform output -raw site_urls      # full URL: http://<alb-dns>/
terraform output -raw alb_dns_name   # DNS name only
```

Or in AWS Console → EC2 → Load Balancers → select ALB → **DNS name**.

The DNS resolves to **3 AWS-owned IPs** (ALB nodes, not your instances).
Your EC2 public IPs are different and may change on re-apply.

```hcl
output "site_urls" {
  value = "http://${aws_lb.web.dns_name}/"
}
```

### Verify it works

```bash
# Single check
curl -s -o /dev/null -w "%{http_code}\n" http://<alb-dns>/

# Round-robin check: repeat and confirm both targets answer
for i in 1 2 3 4; do
  curl -s http://<alb-dns>/ | grep -o "<title>[^<]*" | head -1
done
# Expect alternating titles when nodes serve different content
```

In PowerShell:

```powershell
1..4 | ForEach-Object {
  $r = Invoke-WebRequest -Uri $albUrl -UseBasicParsing -TimeoutSec 10
  "REQ $_ : HTTP $($r.StatusCode) | $($r.Content.Length) bytes"
}
```

### Health check status (why 502/503?)

- `curl` returns **503** → targets still unhealthy: user_data (web server
  install) usually needs 1–2 minutes after apply; wait and retry
- `curl` returns **502** → target process down or wrong port in TG
- Check in Console → EC2 → Target Groups → **Target health** tab:
  `healthy` / `unhealthy` / `unused`
- Instance must listen on the TG port (80) and answer `200` on the
  health check path (`/`)

### Direct instance access vs ALB

By default instances should only accept port 80 **from the ALB security
group** (tiered SG rule with `source_security_group_id`). Then:

- ALB DNS → works
- `http://<instance-public-ip>/` → times out (expected)

If lab/task requires direct access too, open 80 to `0.0.0.0/0` on the web SG
(lab simplification) — both direct IP and ALB will work.

### Troubleshooting checklist

| Symptom | Likely cause |
|---------|--------------|
| DNS doesn't resolve | typo in `dns_name`, or ALB deleted |
| Connection timed out (ALB) | ALB SG missing ingress 80 |
| 503 Service Temporarily Unavailable | no healthy targets — wait for user_data / check TG health |
| 502 Bad Gateway | target not listening on TG port |
| Round-robin not alternating | only 1 target healthy — check second attachment |
| Works by IP but not via ALB | instance SG blocks ALB SG / wrong `vpc_security_group_ids` |

## Environment Differences

| Aspect | Dev | Staging | Prod |
|--------|-----|---------|------|
| Deletion protection | false | false | true |
| Access logs | false | true | true |
| SSL policy | TLS 1.2 | TLS 1.3 | TLS 1.3 |
| Cross-zone | false | true | true |
| Internal | true | false | false |

## Gotchas

1. **Deletion Protection**: Enable for production
2. **Health Checks**: Configure appropriate thresholds
3. **Deregistration Delay**: Default 300s, reduce for fast deploys
4. **Cross-Zone**: ALB enabled by default, NLB opt-in
5. **SSL Policy**: Use latest TLS 1.3 policy
6. **Access Logs**: Enable for debugging and audit
7. **Connection Draining**: Graceful shutdown of connections
8. **Find the URL**: Never hardcode the ALB address — it is created by AWS;
   always expose it via `output` (`aws_lb.x.dns_name`) and read it with
   `terraform output`

## See Also

- [aws-ec2](../aws-ec2/SKILL.md) for instances
- [aws-security-groups](../aws-security-groups/SKILL.md) for firewall rules
- [assets/elb.tf.example](assets/elb.tf.example) for complete example
