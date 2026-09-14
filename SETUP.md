# SETUP.md — Ordem de execução (Tech Challenge Fase 3)

Este pacote deve ser mesclado na raiz do repositório
`togglemaster-tech-challenge-fase-2` (copie as pastas `terraform/`,
`.github/`, `gitops/` e `argocd/` para dentro do repo existente, ao lado de
`auth-service/`, `flag-service/`, etc.).

## 0. Pré-requisitos

- Terraform >= 1.9
- AWS CLI configurado com as credenciais temporárias do AWS Academy
  (`aws configure` ou variáveis `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`/`AWS_SESSION_TOKEN`)
- kubectl e helm instalados
- Um Personal Access Token não é necessário (o pipeline usa o `GITHUB_TOKEN` nativo)

## 1. Bootstrap do bucket do state (uma única vez)

```bash
cd terraform/bootstrap
terraform init
terraform apply -var="bucket_name=togglemaster-tfstate-SEU-SUFIXO-UNICO"
```

Copie o nome do bucket criado e atualize `terraform/backend.tf` (campo `bucket`).

## 2. Provisionar toda a infraestrutura (Terraform)

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # ajuste os valores
export TF_VAR_db_password="sua-senha-forte"     # não deixe a senha no tfvars

terraform init
terraform plan     # <- grave isso no vídeo
terraform apply    # <- grave isso no vídeo (cria VPC, EKS, RDS x3, Redis, DynamoDB, SQS, ECR, ArgoCD)
```

Isso já deixa o ArgoCD instalado no cluster (via `terraform/argocd.tf`).

```bash
terraform output   # anote: rds_endpoints, redis_endpoint, sqs_queue_url, ecr_repository_urls
aws eks update-kubeconfig --region us-east-1 --name togglemaster-cluster
```

## 3. Ajustar ConfigMap e aplicar os secrets

Edite `gitops/bootstrap/configmap.yaml` com o `redis_endpoint` e o `sqs_queue_url`
reais do `terraform output`, depois:

```bash
cp gitops/bootstrap/secrets.example.yaml gitops/bootstrap/secrets.yaml
# preencha com os endpoints do RDS (terraform output rds_endpoints) e credenciais
kubectl apply -f gitops/bootstrap/secrets.yaml
```

## 4. Configurar os Secrets do GitHub Actions

No repositório GitHub, em Settings → Secrets and variables → Actions, crie:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN` (credenciais temporárias do AWS Academy — atualize a cada sessão de lab)

## 5. Registrar as Applications no ArgoCD

```bash
kubectl apply -f argocd/applications/00-bootstrap.yaml
kubectl apply -f argocd/applications/auth-service.yaml
kubectl apply -f argocd/applications/flag-service.yaml
kubectl apply -f argocd/applications/targeting-service.yaml
kubectl apply -f argocd/applications/evaluation-service.yaml
kubectl apply -f argocd/applications/analytics-service.yaml
```

Acesse a UI do ArgoCD (ver `argocd/install/README.md` pra pegar URL e senha) e
confirme os 5 apps sincronizados — **isso é print/vídeo obrigatório**.

## 6. Rodar o pipeline de CI/CD (para o vídeo de DevSecOps)

1. Dê um `git push` numa branch e abra PR alterando algo em `auth-service/`
   → mostra o pipeline rodando build/lint/security scan.
2. Insira propositalmente uma dependência vulnerável (ex: uma lib Go/Python
   antiga e com CVE conhecida) → mostra o job `security_scan` **falhando**.
3. Corrija a dependência → mostra o pipeline passando, buildando a imagem,
   escaneando com Trivy, subindo pro ECR e commitando a nova tag em
   `gitops/apps/auth-service/deployment.yaml`.
4. Mostre o ArgoCD detectando a mudança no Git e sincronizando automaticamente
   a nova versão no cluster.

## 7. Roteiro sugerido do vídeo (até 20 min)

1. `terraform plan`/`apply` ou os recursos já criados no console (3–4 min)
2. Estrutura do código Terraform (módulos) (1–2 min)
3. Pipeline rodando normalmente (2 min)
4. Alteração proposital → pipeline falhando no security scan (2–3 min)
5. Correção → pipeline passando, build, push, atualização do GitOps (3–4 min)
6. ArgoCD sincronizando automaticamente no cluster (2–3 min)
7. Encerramento com resumo (1 min)

## 8. Entregáveis finais

- Vídeo (link do YouTube/Drive)
- Código-fonte no repositório (já commitado com este pacote)
- Relatório PDF/txt — ver template em `docs/RELATORIO-FASE3-template.md`
  (nomes, links, resumo de decisões, print de custo estimado da AWS —
  Billing → Cost Explorer ou AWS Pricing Calculator)
