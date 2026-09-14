provider "aws" {
  region = var.aws_region
  # No AWS Academy as credenciais vêm do próprio Lab (variáveis de ambiente /
  # ~/.aws/credentials com aws_session_token). Não defina profile fixo aqui.
}

# Providers kubernetes/helm apontam para o cluster EKS que este MESMO
# terraform está criando. Isso é o padrão "data-source chaining": eles só
# conseguem autenticar depois que o módulo eks existe no state.
data "aws_eks_cluster_auth" "this" {
  name = module.eks.cluster_name
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}
