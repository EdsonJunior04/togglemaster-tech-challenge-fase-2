output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "ecr_repository_urls" {
  value = module.ecr.repository_urls
}

output "rds_endpoints" {
  value = module.rds.endpoints
}

output "redis_endpoint" {
  value = module.elasticache.redis_endpoint
}

output "dynamodb_table_name" {
  value = module.dynamodb.table_name
}

output "sqs_queue_url" {
  value = module.sqs.queue_url
}

output "configure_kubectl" {
  description = "Comando pra configurar o kubectl depois do apply"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
