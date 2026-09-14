variable "project_name" { type = string }
variable "vpc_cidr" { type = string }
variable "azs" { type = list(string) }
variable "cluster_name" {
  description = "Usado apenas para as tags kubernetes.io exigidas pelo EKS/ALB controller"
  type        = string
}
