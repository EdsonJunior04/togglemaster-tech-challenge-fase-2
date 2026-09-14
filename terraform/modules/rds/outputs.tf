output "endpoints" {
  description = "Mapa serviço -> endpoint:porta do RDS"
  value       = { for k, db in aws_db_instance.this : k => db.endpoint }
}

output "db_names" {
  value = { for k, db in aws_db_instance.this : k => db.db_name }
}

output "security_group_id" {
  value = aws_security_group.rds.id
}
