# AWS Terraform Reference

## Documentation Links

### Terraform AWS Provider
- [AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Provider Configuration](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#configuration)
- [AWS Provider Arguments Reference](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#argument-reference)

### Official AWS Terraform Modules
- [VPC Module](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/latest)
- [EC2 Instance Module](https://registry.terraform.io/modules/terraform-aws-modules/ec2-instance/aws/latest)
- [RDS Module](https://registry.terraform.io/modules/terraform-aws-modules/rds/aws/latest)
- [S3 Bucket Module](https://registry.terraform.io/modules/terraform-aws-modules/s3-bucket/aws/latest)
- [EKS Module](https://registry.terraform.io/modules/terraform-aws-modules/eks/aws/latest)

### AWS Documentation
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
- [AWS Architecture Center](https://aws.amazon.com/architecture/)
- [AWS Security Best Practices](https://docs.aws.amazon.com/general/latest/gr/aws-security.html)
- [AWS Networking and Content Delivery](https://aws.amazon.com/products/networking/)

### Terraform Best Practices
- [Terraform Best Practices](https://www.terraform-best-practices.com)
- [Terraform Style Guide](https://developer.hashicorp.com/terraform/language/style)
- [Terraform Documentation](https://developer.hashicorp.com/terraform/docs)
- [Terraform AWS Examples](https://github.com/hashicorp/terraform-provider-aws/tree/main/examples)

## Useful Commands

```bash
# Format code
terraform fmt -recursive

# Validate configuration
terraform validate

# Initialize and upgrade providers
terraform init -upgrade

# Plan changes
terraform plan -out=tfplan

# Apply changes
terraform apply tfplan

# Destroy resources
terraform destroy

# Show current state
terraform show

# List resources
terraform state list

# Import existing resource
terraform import aws_instance.web i-1234567890abcdef0
```

## Environment Configuration

### Dev Environment
- Instance type: t3.micro
- Multi-AZ: false
- Backup: 0 days
- Deletion protection: false

### Staging Environment
- Instance type: t3.small
- Multi-AZ: true
- Backup: 7 days
- Deletion protection: false

### Prod Environment
- Instance type: t3.medium+
- Multi-AZ: true
- Backup: 30 days
- Deletion protection: true
