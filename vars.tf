# ============================================================
# Змінні проєкту
# ============================================================

variable "aws_access_key" {
  type        = string
  description = "AWS Access Key ID"
  sensitive   = true
}

variable "aws_secret_key" {
  type        = string
  description = "AWS Secret Access Key"
  sensitive   = true
}

variable "primary_region" {
  type        = string
  description = "Основний регіон (Європа)"
  default     = "eu-north-1"
}

variable "backup_region" {
  type        = string
  description = "Резервний регіон (Канада)"
  default     = "ca-central-1"
}

variable "domain" {
  type        = string
  description = "Доменне ім'я сайту = назва зони Route 53"
  default     = "hwbarabash1.pp.ua"
}

variable "instance_type" {
  type        = string
  description = "Тип віртуальних машин (free tier)"
  default     = "t3.micro"
}
