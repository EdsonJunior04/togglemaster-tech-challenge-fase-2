resource "kubernetes_namespace" "argocd" {
  metadata {
    name = "argocd"
  }
  depends_on = [module.eks]
}

resource "kubernetes_namespace" "togglemaster" {
  metadata {
    name = "togglemaster"
  }
  depends_on = [module.eks]
}

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "7.7.x" # trave uma versão exata em produção; range só pra facilitar o lab
  namespace  = kubernetes_namespace.argocd.metadata[0].name

  set {
    name  = "server.service.type"
    value = "LoadBalancer" # facilita acessar a UI do ArgoCD de fora pro vídeo de demo
  }

  depends_on = [kubernetes_namespace.argocd]
}
