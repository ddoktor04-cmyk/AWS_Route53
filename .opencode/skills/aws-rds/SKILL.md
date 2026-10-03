---
name: aws-rds
description: RDS database provisioning. Use when creating relational databases, configuring read replicas, setting up subnet groups, or managing database parameters.
metadata:
  author: cmd521
  version: "1.0"
---

# AWS RDS Databases

## When to Use

- Creating relational databases
- Configuring read replicas
- Setting up subnet groups
- Managing database parameters
- Multi-AZ deployments

## Engine Selection

| Engine | Use Case | Notes |
|--------|----------|-------|
| PostgreSQL | New projects | Recommended |
| MySQL | Legacy applications | Widely supported |
| MariaDB | MySQL compatibility | Drop-in replacement |

## Instance Classes

| Environment | Instance Class | vCPU | RAM |
|-------------|---------------|------|-----|
| Dev | db.t3.micro | 2 | 1 GB |
| Staging | db.t3.small | 2 | 2 GB |
| Prod (Small) | db.r5.large | 2 | 16 GB |
| Prod (Large) | db.r5.xlarge | 4 | 32 GB |

## Basic RDS Instance

```hcl
resource "aws_db_instance" "main" {
  identifier = "${var.project}-${var.environment}-db"

  engine         = "postgres"
  engine_version = "15.4"
  instance_class = var.db_instance_class

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_encrypted     = true

  db_name  = "mydb"
  username = "admin"
  password = var.db_password

  publicly_accessible = false

  vpc_security_group_ids = [aws_security_group.db.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name

  backup_retention_period = var.environment == "prod" ? 30 : 7
  deletion_protection     = var.environment == "prod" ? true : false
  skip_final_snapshot     = var.environment == "dev" ? true : false

  tags = {
    Name        = "${var.project}-${var.environment}-db"
    Environment = var.environment
  }
}
```

## Subnet Group

```hcl
resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-${var.environment}-db-subnet"
  subnet_ids = var.private_db_subnet_ids

  tags = {
    Name = "${var.project}-${var.environment}-db-subnet"
  }
}
```

## Parameter Group

```hcl
resource "aws_db_parameter_group" "main" {
  name   = "${var.project}-${var.environment}-params"
  family = "postgres15"

  parameter {
    name  = "log_connections"
    value = "1"
  }

  parameter {
    name  = "log_disconnections"
    value = "1"
  }

  tags = {
    Name = "${var.project}-${var.environment}-params"
  }
}
```

## Read Replicas

```hcl
resource "aws_db_instance" "replica" {
  identifier = "${var.project}-${var.environment}-db-replica"

  replicate_source_db = aws_db_instance.main.identifier

  instance_class = var.db_instance_class

  vpc_security_group_ids = [aws_security_group.db.id]

  tags = {
    Name = "${var.project}-${var.environment}-db-replica"
  }
}
```

## Multi-AZ

```hcl
resource "aws_db_instance" "main" {
  # ... other config ...

  multi_az = var.environment == "prod" ? true : false
}
```

## Environment Differences

| Aspect | Dev | Staging | Prod |
|--------|-----|---------|------|
| Instance class | db.t3.micro | db.t3.small | db.r5.large |
| Multi-AZ | false | true | true |
| Backup retention | 0 days | 7 days | 30 days |
| Deletion protection | false | false | true |
| Skip final snapshot | true | false | false |
| Storage autoscaling | false | true | true |
| Parameter group | default | custom | custom |
| Performance Insights | false | false | true |

## Gotchas

1. **Public Access**: Always `false` for production
2. **Encryption**: Always enable `storage_encrypted = true`
3. **Password**: Use AWS Secrets Manager or SSM Parameter Store
4. **Final Snapshot**: Set `skip_final_snapshot = false` for prod
5. **Storage Autoscaling**: Enable `max_allocated_storage` for production
6. **IAM Authentication**: Enable for enhanced security
7. **Deletion Protection**: Always enable for production

## See Also

- [aws-security-groups](../aws-security-groups/SKILL.md) for network rules
- [assets/rds.tf.example](assets/rds.tf.example) for complete example
