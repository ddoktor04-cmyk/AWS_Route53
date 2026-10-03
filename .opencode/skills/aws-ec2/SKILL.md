---
name: aws-ec2
description: EC2 instance provisioning. Use when creating virtual machines, configuring user data, managing key pairs, or setting up EBS volumes.
metadata:
  author: cmd521
  version: "1.0"
---

# AWS EC2 Instances

## When to Use

- Provisioning virtual machines
- Configuring user data scripts
- Managing key pairs
- Setting up EBS volumes
- Auto Scaling Groups

## AMI Selection

### Amazon Linux 2023 (Recommended for AWS-optimized)

```hcl
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
```

### Ubuntu 22.04 LTS

```hcl
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}
```

## Instance Types

| Use Case | Instance Type | vCPU | RAM | Network |
|----------|---------------|------|-----|---------|
| Dev/Testing | t3.micro | 2 | 1 GB | Low to Moderate |
| Small App | t3.small | 2 | 4 GB | Low to Moderate |
| Medium App | t3.medium | 2 | 4 GB | Up to 5 Gbps |
| Compute Optimized | c5.large | 2 | 4 GB | Up to 10 Gbps |
| Memory Optimized | r5.large | 2 | 16 GB | Up to 10 Gbps |

## Basic EC2 Instance

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name      = var.key_name

  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]

  tags = {
    Name = "web-server"
  }
}
```

## User Data

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name      = var.key_name

  user_data = <<-EOF
              #!/bin/bash
              yum update -y
              yum install -y httpd
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Hello from $(hostname)</h1>" > /var/www/html/index.html
              EOF

  tags = {
    Name = "web-server"
  }
}
```

## EBS Volumes

```hcl
resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true

    tags = {
      Name = "RootVolume"
    }
  }

  ebs_block_device {
    device_name = "/dev/sdf"
    volume_size = 100
    volume_type = "gp3"
    encrypted   = true

    tags = {
      Name = "DataVolume"
    }
  }
}
```

## Key Pairs

```hcl
resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = var.ssh_public_key
}

resource "aws_instance" "web" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.deployer.key_name
}
```

## Environment Differences

| Aspect | Dev | Staging | Prod |
|--------|-----|---------|------|
| Instance type | t3.micro | t3.small | t3.medium+ |
| EBS size | 20 GB | 20 GB | 20 GB + data volume |
| EBS type | gp3 | gp3 | gp3 |
| Monitoring | Basic | Basic | Detailed |
| EBS encryption | optional | true | true |

## Gotchas

1. **Public IP**: Use `associate_public_ip_address = true` only in public subnets
2. **Tenancy**: Default is shared, use `dedicated` for compliance
3. **Instance Store**: Ephemeral storage, not for important data
4. **User Data**: Only runs at first boot (unless `cloud_init_config` is used)
5. **Termination**: Stop vs Terminate - be careful with `disable_api_termination`
6. **AMI Updates**: AMI IDs change frequently, always use `data` source with `most_recent = true`

## See Also

- [aws-vpc](../aws-vpc/SKILL.md) for network setup
- [aws-security-groups](../aws-security-groups/SKILL.md) for firewall rules
- [assets/ec2.tf.example](assets/ec2.tf.example) for complete example
