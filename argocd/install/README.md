# Instalação do ArgoCD

O Terraform (terraform/argocd.tf) já instala o ArgoCD via provider Helm
automaticamente no `terraform apply`. Este arquivo é só a alternativa manual,
caso precise reinstalar/depurar.

## Instalação manual (alternativa ao Terraform)

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  --set server.service.type=LoadBalancer
```

## Pegar a senha inicial do admin

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
```

## Pegar a URL da UI (LoadBalancer)

```bash
kubectl -n argocd get svc argocd-server \
  -o jsonpath="{.status.loadBalancer.ingress[0].hostname}"
```

## Aplicar as Applications (bootstrap + 5 microsserviços)

```bash
kubectl apply -f argocd/applications/00-bootstrap.yaml
kubectl apply -f argocd/applications/auth-service.yaml
kubectl apply -f argocd/applications/flag-service.yaml
kubectl apply -f argocd/applications/targeting-service.yaml
kubectl apply -f argocd/applications/evaluation-service.yaml
kubectl apply -f argocd/applications/analytics-service.yaml
```

## Aplicar os secrets (fora do GitOps, credenciais sensíveis)

```bash
cp gitops/bootstrap/secrets.example.yaml gitops/bootstrap/secrets.yaml
# edite com os valores reais (endpoints do RDS vindos do `terraform output`,
# credenciais temporárias do AWS Academy, etc.)
kubectl apply -f gitops/bootstrap/secrets.yaml
```
