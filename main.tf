# ============================================================
# Головний файл: terraform-блок і провайдери AWS
# Лаба: 2 сервери в різних регіонах + Route 53 latency routing
# ============================================================

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Провайдер за замовчуванням — основний регіон (Європа, Stockholm)
provider "aws" {
  region     = var.primary_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

# Провайдер для резервного регіону (Канада, Central)
provider "aws" {
  alias      = "ca"
  region     = var.backup_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}
