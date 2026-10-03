---
name: aws-security-groups
description: Security Groups and NACLs configuration. Use when defining network access rules, configuring firewall rules, or troubleshooting connectivity.
metadata:
  author: cmd521
  version: "1.0"
---

# AWS Security Groups

## When to Use

- Defining network access rules
- Configuring firewall rules
- Troubleshooting connectivity
- Setting up tier-based access control

## Security Groups vs NACLs

| Feature | Security Groups | NACLs |
|---------|-----------------|-------|
| Level | Instance-level | Subnet-level |
| State | Stateful | Stateless |
| Rules | Allow only | Allow and Deny |
| Evaluation | All rules evaluated | Rules in order |

**Recommendation**: Use Security Groups. NACLs only for additional subnet-level defense.

## Basic Security Group

```hcl
resource "aws_security_group" "web" {
  name        = "web-sg"
  description = "Security group for web servers"
  vpc_id      = var.vpc_id

  tags = {
    Name = "web-sg"
  }
}
```

## Ingress Rules

### SSH Access (Restricted)

```hcl
resource "aws_security_group_rule" "ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = ["10.0.0.0/8"]  # Internal only
  security_group_id = aws_security_group.web.id
  description       = "SSH access from internal"
}
```

### HTTP/HTTPS (Public)

```hcl
resource "aws_security_group_rule" "http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web.id
  description       = "HTTP access"
}

resource "aws_security_group_rule" "https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web.id
  description       = "HTTPS access"
}
```

### Application Port (From Specific SG)

```hcl
resource "aws_security_group_rule" "app_port" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.web.id
  security_group_id        = aws_security_group.app.id
  description              = "App port from web servers"
}
```

## Egress Rules

```hcl
resource "aws_security_group_rule" "egress_all" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.web.id
  description       = "Allow all outbound traffic"
}
```

## Self-Referencing Rules (Clusters)

```hcl
resource "aws_security_group_rule" "cluster_communication" {
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "tcp"
  self              = true
  security_group_id = aws_security_group.cluster.id
  description       = "Allow all traffic between cluster instances"
}
```

## Tier-Based Access Control

```hcl
# Web Tier
resource "aws_security_group" "web" {
  name   = "web-sg"
  vpc_id = var.vpc_id
}

# App Tier - only accepts traffic from Web Tier
resource "aws_security_group" "app" {
  name   = "app-sg"
  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "app_from_web" {
  type                     = "ingress"
  from_port                = 8080
  to_port                  = 8080
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.web.id
  security_group_id        = aws_security_group.app.id
}

# DB Tier - only accepts traffic from App Tier
resource "aws_security_group" "db" {
  name   = "db-sg"
  vpc_id = var.vpc_id
}

resource "aws_security_group_rule" "db_from_app" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.app.id
  security_group_id        = aws_security_group.db.id
}
```

## Common Ports Reference

| Service | Port | Protocol |
|---------|------|----------|
| SSH | 22 | TCP |
| HTTP | 80 | TCP |
| HTTPS | 443 | TCP |
| MySQL | 3306 | TCP |
| PostgreSQL | 5432 | TCP |
| Redis | 6379 | TCP |
| MongoDB | 27017 | TCP |

## Environment Differences

| Aspect | Dev | Staging | Prod |
|--------|-----|---------|------|
| SSH CIDR | 0.0.0.0/0 (for testing) | Specific IP range | Specific IP range |
| Management ports | Open | Restricted | Restricted |
| Cross-SG rules | Basic | Full tier | Full tier |

## Gotchas

1. **Default SG**: Always remove default allow-all rules
2. **Propagation**: Security Group changes take a few seconds
3. **No Priority**: All rules are evaluated (no ordering)
4. **Stateful**: Return traffic automatically allowed
5. **References**: Use SG IDs, not CIDR when possible
6. **NACLs**: Remember NACLs are stateless (need both inbound and outbound)

## See Also

- [aws-vpc](../aws-vpc/SKILL.md) for network setup
- [assets/security-groups.tf.example](assets/security-groups.tf.example) for complete example
