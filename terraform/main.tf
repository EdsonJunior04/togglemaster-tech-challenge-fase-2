module "networking" {
  source = "./modules/networking"

  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
  azs          = var.azs
  cluster_name = var.cluster_name
}

module "eks" {
  source = "./modules/eks"

  cluster_name         = var.cluster_name
  kubernetes_version   = var.kubernetes_version
  vpc_id               = module.networking.vpc_id
  private_subnet_ids   = module.networking.private_subnet_ids
  public_subnet_ids    = module.networking.public_subnet_ids
  node_instance_types  = var.node_instance_types
  node_desired_size    = var.node_desired_size
  node_min_size        = var.node_min_size
  node_max_size        = var.node_max_size
  use_academy_lab_role = var.use_academy_lab_role
  lab_role_name        = var.lab_role_name
}

module "rds" {
  source = "./modules/rds"

  project_name                   = var.project_name
  vpc_id                         = module.networking.vpc_id
  private_subnet_ids             = module.networking.private_subnet_ids
  eks_cluster_security_group_id  = module.eks.cluster_security_group_id
  services_with_own_db           = var.services_with_own_db
  db_instance_class              = var.db_instance_class
  db_engine_version              = var.db_engine_version
  db_username                    = var.db_username
  db_password                    = var.db_password
}

module "elasticache" {
  source = "./modules/elasticache"

  project_name                  = var.project_name
  vpc_id                        = module.networking.vpc_id
  private_subnet_ids            = module.networking.private_subnet_ids
  eks_cluster_security_group_id = module.eks.cluster_security_group_id
  redis_node_type                = var.redis_node_type
}

module "dynamodb" {
  source = "./modules/dynamodb"
}

module "sqs" {
  source = "./modules/sqs"

  project_name = var.project_name
}

module "ecr" {
  source = "./modules/ecr"

  project_name  = var.project_name
  service_names = var.all_services
}
