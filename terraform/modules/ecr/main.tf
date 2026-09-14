resource "aws_ecr_repository" "services" {
  for_each = toset(var.service_names)

  name                 = each.key
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name    = each.key
    Project = var.project_name
  }
}

# Mantém só as últimas N imagens por repositório (evita custo de storage indo às alturas)
resource "aws_ecr_lifecycle_policy" "expire_old" {
  for_each   = aws_ecr_repository.services
  repository = each.value.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Mantém apenas as 15 imagens mais recentes"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 15
      }
      action = { type = "expire" }
    }]
  })
}
