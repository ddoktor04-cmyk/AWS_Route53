# ============================================================
# EC2: дві Ubuntu-віртуалки з Apache
# Основний — Європа (Stockholm), резервний — Канада
# ============================================================

# ---------- AMI: Ubuntu 24.04 LTS (Canonical) ----------
data "aws_ami" "ubuntu_primary" {
  provider    = aws
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd*/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

data "aws_ami" "ubuntu_backup" {
  provider    = aws.ca
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd*/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# ---------- Default VPC у кожному регіоні ----------
data "aws_vpc" "default_primary" {
  provider = aws
  default  = true
}

data "aws_vpc" "default_backup" {
  provider = aws.ca
  default  = true
}

# ---------- Security Group: тільки HTTP 80 ----------
resource "aws_security_group" "web_primary" {
  provider    = aws
  name        = "hwbarabash1-primary-web"
  description = "HTTP to primary server (Stockholm)"
  vpc_id      = data.aws_vpc.default_primary.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "hwbarabash1-primary-web"
  }
}

resource "aws_security_group" "web_backup" {
  provider    = aws.ca
  name        = "hwbarabash1-backup-web"
  description = "HTTP to backup server (Canada)"
  vpc_id      = data.aws_vpc.default_backup.id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "hwbarabash1-backup-web"
  }
}

# ---------- Основний сервер: Європа (Stockholm) ----------
resource "aws_instance" "primary" {
  provider               = aws
  ami                    = data.aws_ami.ubuntu_primary.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.web_primary.id]

  user_data = templatefile("${path.module}/files/userdata.sh.tftpl", {
    heading       = "ОСНОВНИЙ СЕРВЕР"
    subhead       = "Європа · Stockholm (eu-north-1)"
    note          = "Відвідувачі з Європи потрапляють сюди: Route 53 обирає цей сервер, бо затримка до нього найменша."
    region_name   = var.primary_region
    instance_kind = var.instance_type
    accent        = "#22c55e"
  })

  tags = {
    Name = "hwbarabash1-primary"
    Role = "primary"
  }
}

# ---------- Резервний сервер: Канада ----------
resource "aws_instance" "backup" {
  provider               = aws.ca
  ami                    = data.aws_ami.ubuntu_backup.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.web_backup.id]

  user_data = templatefile("${path.module}/files/userdata.sh.tftpl", {
    heading       = "РЕЗЕРВНИЙ СЕРВЕР"
    subhead       = "Канада · Central (ca-central-1)"
    note          = "Клієнти з Північної Америки потрапляють сюди: для них затримка до Канади менша, ніж до Європи."
    region_name   = var.backup_region
    instance_kind = var.instance_type
    accent        = "#f59e0b"
  })

  tags = {
    Name = "hwbarabash1-backup"
    Role = "backup"
  }
}

# ---------- Постійні публічні IP (безкоштовні, поки прив'язані) ----------
resource "aws_eip" "primary" {
  provider = aws
  instance = aws_instance.primary.id
  domain   = "vpc"

  tags = {
    Name = "hwbarabash1-primary-eip"
  }
}

resource "aws_eip" "backup" {
  provider = aws.ca
  instance = aws_instance.backup.id
  domain   = "vpc"

  tags = {
    Name = "hwbarabash1-backup-eip"
  }
}
