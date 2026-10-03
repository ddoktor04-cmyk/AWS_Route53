---
name: aws-iam
description: IAM users, roles, and policies. Use when configuring access control, creating service roles, setting up OIDC, or managing permissions.
metadata:
  author: cmd521
  version: "1.0"
---

# AWS IAM Access Control

## When to Use

- Configuring access control
- Creating service roles for EC2, Lambda, ECS
- Setting up OIDC for GitHub Actions
- Managing permissions
- Creating IAM users, groups, and policies

## Users vs Roles

| Feature | Users | Roles |
|---------|-------|-------|
| Credentials | Long-term | Temporary |
| Use case | Human access | Services, cross-account |
| Recommended | Rarely | Yes |

## Least Privilege Principle

### BAD

```hcl
resource "aws_iam_policy" "bad" {
  name = "admin-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "*"
      Resource = "*"
    }]
  })
}
```

### GOOD

```hcl
resource "aws_iam_policy" "good" {
  name = "s3-read-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:ListBucket"
      ]
      Resource = [
        "arn:aws:s3:::my-bucket",
        "arn:aws:s3:::my-bucket/*"
      ]
    }]
  })
}
```

## EC2 Instance Profile

```hcl
resource "aws_iam_role" "ec2" {
  name = "${var.project}-${var.environment}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2.name
}

resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
```

## Lambda Execution Role

```hcl
resource "aws_iam_role" "lambda" {
  name = "${var.project}-${var.environment}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
```

## OIDC for GitHub Actions

```hcl
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["ffffffffffffffffffffffffffffffffffffffff"]
}

data "aws_iam_policy_document" "github_actions" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.project}-${var.environment}-github-actions"
  assume_role_policy = data.aws_iam_policy_document.github_actions.json
}
```

## IAM Groups

```hcl
resource "aws_iam_group" "developers" {
  name = "developers"
}

resource "aws_iam_group_policy_attachment" "developers" {
  group      = aws_iam_group.developers.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}
```

## Environment Differences

| Aspect | Dev | Staging | Prod |
|--------|-----|---------|------|
| Roles | Basic | Full | Full |
| OIDC | Dev repo only | Staging repo | Prod repo only |
| Policies | PowerUser | Restricted | Least privilege |
| Users | Individual | Team | Team |

## Gotchas

1. **Policy Size**: Max 6,144 characters
2. **Managed vs Inline**: Use managed policies
3. **Propagation**: IAM changes take up to 10 minutes
4. **Service-Linked Roles**: Auto-created, don't delete
5. **Policy Versions**: Max 5 versions per policy
6. **ARN Format**: Different for different services

## See Also

- [terraform-security](~/.config/opencode/skills/terraform-security/SKILL.md) for security best practices
- [assets/iam.tf.example](assets/iam.tf.example) for complete example
