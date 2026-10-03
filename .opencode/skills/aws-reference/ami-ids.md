# AMI IDs for eu-north-1 (Stockholm)

## Amazon Linux 2023

| Name | AMI ID | Architecture |
|------|--------|--------------|
| Amazon Linux 2023 | ami-0aba19e56f3eaec05 | x86_64 |
| Amazon Linux 2023 (HVM) | ami-0aba19e56f3eaec05 | x86_64 |

## Ubuntu

| Name | AMI ID | Architecture |
|------|--------|--------------|
| Ubuntu 22.04 LTS | ami-0b490e4f8a6b7c5d0 | x86_64 |
| Ubuntu 24.04 LTS | ami-0a8f2c5b5e8f3c5d0 | x86_64 |

## Usage in Terraform

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

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}
```

## Notes

- AMI IDs are region-specific
- Use `most_recent = true` to always get the latest version
- Always verify AMI IDs in the AWS Console for your region
- Amazon Linux 2023 is recommended for AWS-optimized workloads
- Ubuntu is recommended for general-purpose workloads
