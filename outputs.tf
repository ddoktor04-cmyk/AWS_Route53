# ============================================================
# Виведення результатів
# ============================================================

output "nameservers" {
  description = "4 NS-сервери Route 53 — вписати на nic.ua (розділ «NS-сервери» → «Власні сервери імен»)"
  value       = aws_route53_zone.main.name_servers
}

output "primary_ip" {
  description = "Public IP основного сервера (Європа, Stockholm)"
  value       = aws_eip.primary.public_ip
}

output "backup_ip" {
  description = "Public IP резервного сервера (Канада, Central)"
  value       = aws_eip.backup.public_ip
}

output "primary_url" {
  description = "Пряме посилання на основний сервер"
  value       = "http://${aws_eip.primary.public_ip}/"
}

output "backup_url" {
  description = "Пряме посилання на резервний сервер"
  value       = "http://${aws_eip.backup.public_ip}/"
}

output "domain_url" {
  description = "Сайт через домен (після делегації NS на nic.ua)"
  value       = "http://${var.domain}/"
}
