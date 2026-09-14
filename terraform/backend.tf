terraform {
  required_version = ">= 1.9.0"

  # Backend remoto obrigatório (Aula 2 de IaC) - substitui o state local.
  # O bucket precisa existir ANTES do primeiro `terraform init` (crie manualmente
  # uma única vez, ou rode um `terraform apply` local isolado no bootstrap/).
  backend "s3" {
    bucket       = "togglemaster-tfstate-SEU-SUFIXO-UNICO" # troque por um nome único (ex: com seu RM)
    key          = "togglemaster/fase3/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true # lock nativo do S3 (Terraform >= 1.9), sem precisar de DynamoDB
    encrypt      = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.31"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.14"
    }
  }
}
