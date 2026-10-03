# ============================================================
# Route 53: public hosted zone + latency-based routing
# Route 53 направляє клієнта до сервера з найменшою затримкою
# ============================================================

resource "aws_route53_zone" "main" {
  name = var.domain

  tags = {
    Name = var.domain
  }
}

# ---------- Основний сервер: Європа (Stockholm) ----------
resource "aws_route53_record" "primary" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain
  type    = "A"
  ttl     = 60
  records = [aws_eip.primary.public_ip]

  # Ідентифікатор запису в політиці latency (унікальний на запис)
  set_identifier = var.primary_region

  # Політика: обираємо цей запис, якщо до Європи менша затримка
  latency_routing_policy {
    region = var.primary_region
  }
}

# ---------- Резервний сервер: Канада ----------
resource "aws_route53_record" "backup" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain
  type    = "A"
  ttl     = 60
  records = [aws_eip.backup.public_ip]

  set_identifier = var.backup_region

  latency_routing_policy {
    region = var.backup_region
  }
}
