variable "aws_region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefixo usado em todos os recursos"
  type        = string
  default     = "togglemaster"
}

variable "environment" {
  description = "Nome do ambiente"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR da VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "azs" {
  description = "AZs usadas para as subnets"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

# --- AWS Academy ---
variable "use_academy_lab_role" {
  description = "Se true, reusa a LabRole existente (AWS Academy) em vez de criar IAM roles novas"
  type        = bool
  default     = true
}

variable "lab_role_name" {
  description = "Nome da role existente no AWS Academy (padrão do curso)"
  type        = string
  default     = "LabRole"
}

# --- EKS ---
variable "cluster_name" {
  description = "Nome do cluster EKS"
  type        = string
  default     = "togglemaster-cluster"
}

variable "kubernetes_version" {
  type    = string
  default = "1.30"
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "node_min_size" {
  type    = number
  default = 1
}

variable "node_max_size" {
  type    = number
  default = 3
}

# --- Databases ---
variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}

variable "db_engine_version" {
  type    = string
  default = "16.4"
}

variable "db_username" {
  type      = string
  default   = "togglemaster_admin"
  sensitive = true
}

variable "db_password" {
  description = "Senha do RDS. Passe via TF_VAR_db_password ou terraform.tfvars (NUNCA commitado)."
  type        = string
  sensitive   = true
}

variable "redis_node_type" {
  type    = string
  default = "cache.t3.micro"
}

# --- Microserviços (usado para nomear ECR/RDS por serviço) ---
variable "services_with_own_db" {
  description = "Serviços que possuem RDS PostgreSQL dedicado (Fase 2: auth, flag, targeting)"
  type        = list(string)
  default     = ["auth", "flag", "targeting"]
}

variable "all_services" {
  description = "Os 5 microsserviços do ToggleMaster (usado para criar os repositórios ECR)"
  type        = list(string)
  default     = ["auth-service", "flag-service", "targeting-service", "evaluation-service", "analytics-service"]
}
