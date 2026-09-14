variable "project_name" { type = string }
variable "vpc_id" { type = string }
variable "private_subnet_ids" { type = list(string) }
variable "eks_cluster_security_group_id" { type = string }
variable "services_with_own_db" { type = list(string) }
variable "db_instance_class" { type = string }
variable "db_engine_version" { type = string }
variable "db_username" { type = string }
variable "db_password" {
  type      = string
  sensitive = true
}
