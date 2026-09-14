output "repository_urls" {
  value = { for k, r in aws_ecr_repository.services : k => r.repository_url }
}
