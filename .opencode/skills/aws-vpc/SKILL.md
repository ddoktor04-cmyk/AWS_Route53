---
name: aws-vpc
description: VPC architecture and networking. Use when designing network topology, creating subnets, configuring route tables, or setting up internet/NAT gateways.
metadata:
  author: cmd521
  version: "1.0"
---

# AWS VPC Networking

## When to Use

- Designing network topology
- Creating public and private subnets
- Configuring route tables
- Setting up Internet/NAT Gateways
- VPC Peering and Endpoints

## VPC CIDR Planning

### Recommended CIDR Blocks

| VPC Size | CIDR | Subnets | IPs per Subnet |
|----------|------|---------|----------------|
| Small | /20 | 4 x /24 | 256 |
| Medium | /16 | 4 x /24 | 256 |
| Large | /16 | 8 x /22 | 1,024 |

### Subnet Allocation

```
VPC CIDR: 10.0.0.0/16

Public Subnets:
  - 10.0.0.0/24   (AZ-a)
  - 10.0.1.0/24   (AZ-b)

Private Subnets (App):
  - 10.0.10.0/24  (AZ-a)
  - 10.0.11.0/24  (AZ-b)

Private Subnets (DB):
  - 10.0.20.0/24  (AZ-a)
  - 10.0.21.0/24  (AZ-b)
```

## Basic VPC

```hcl
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "main-vpc"
  }
}
```

## Public Subnets

```hcl
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${count.index}.0/24"
  availability_zone = "eu-north-1${count.index == 0 ? "a" : "b"}"

  map_public_ip_on_launch = true

  tags = {
    Name = "public-subnet-${count.index}"
    Tier = "public"
  }
}
```

## Private Subnets

```hcl
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${10 + count.index}.0/24"
  availability_zone = "eu-north-1${count.index == 0 ? "a" : "b"}"

  tags = {
    Name = "private-subnet-${count.index}"
    Tier = "private"
  }
}
```

## Internet Gateway

```hcl
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}
```

## NAT Gateway

```hcl
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "main-nat"
  }

  depends_on = [aws_internet_gateway.main]
}
```

## Route Tables

### Public Route Table

```hcl
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
```

### Private Route Table

```hcl
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "private-rt"
  }
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
```

## VPC Endpoints

### S3 Gateway Endpoint

```hcl
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.eu-north-1.s3"

  route_table_ids = [
    aws_route_table.private.id
  ]

  tags = {
    Name = "s3-endpoint"
  }
}
```

## Environment Differences

| Aspect | Dev | Staging | Prod |
|--------|-----|---------|------|
| VPC CIDR | 10.0.0.0/16 | 10.0.0.0/16 | 10.0.0.0/16 |
| NAT Gateway | 1 | 1 | 2+ (per AZ) |
| Subnets | 2 public + 2 private | 2 public + 2 private | 2 public + 4 private |
| VPC Endpoints | S3 only | S3 + DynamoDB | S3 + DynamoDB + others |

## Gotchas

1. **CIDR Conflicts**: Cannot peer VPCs with overlapping CIDRs
2. **AZ Distribution**: Spread subnets across multiple AZs
3. **DNS**: Enable `enableDnsSupport` and `enableDnsHostnames`
4. **NAT Gateway**: Costs money per hour + data processing
5. **Default Security Group**: Remove default rules or delete it
6. **Subnet Sizing**: Plan for future growth

## See Also

- [aws-security-groups](../aws-security-groups/SKILL.md) for firewall rules
- [assets/vpc.tf.example](assets/vpc.tf.example) for complete example
