# SETUP.md — Setup das Fases 3 e 4

Este repositório contém a base da Fase 3 e a extensão de observabilidade da
Fase 4. A configuração atual do ArgoCD aponta para
`EdsonJunior04/togglemaster-tech-challenge-fase-2`; ajuste `repoURL` nos manifests
`argocd/applications/` caso o repositório de entrega tenha outro endereço.

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

## 5. Registrar as Applications da Fase 3 no ArgoCD

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

## 6. Fase 4 — instalar observabilidade e resposta ativa

### 6.1 Criar e preencher os Secrets

Crie o namespace antes do Secret. O arquivo real está ignorado pelo Git:

```bash
kubectl create namespace observability --dry-run=client -o yaml | kubectl apply -f -
cp gitops/observability/secrets.example.yaml gitops/observability/secrets.yaml
```

Preencha `gitops/observability/secrets.yaml` com:

- `newrelic-license-key`: license key da conta New Relic;
- `pagerduty-routing-key`: integration/routing key do serviço PagerDuty;
- `discord-webhook-url`: URL do webhook do canal Discord;
- `alert-webhook-token`: token aleatório compartilhado entre Alertmanager e o
  serviço interno de automação (gere, por exemplo, com `openssl rand -hex 32`).

Não versionar o arquivo preenchido. Aplique-o antes de sincronizar os apps:

```bash
kubectl apply -f gitops/observability/secrets.yaml
```

### 6.2 Atualizar ECR e construir a imagem da automação

O Terraform agora cria o repositório ECR `observability-actions`. Aplique a
alteração de `terraform/variables.tf` antes do primeiro deploy. Depois, envie
as mudanças para `main` e aguarde o workflow
`.github/workflows/ci-observability-actions.yml` concluir o build, scan e push
da imagem. O workflow também atualiza a tag no GitOps.

### 6.3 Registrar os apps do ArgoCD

```bash
kubectl apply -f argocd/applications/observability-loki.yaml
kubectl apply -f argocd/applications/observability-prometheus.yaml
kubectl wait --for=condition=Established --timeout=180s \
  crd/servicemonitors.monitoring.coreos.com
kubectl apply -f argocd/applications/observability-otel.yaml
kubectl apply -f argocd/applications/observability-actions.yaml
```

O Prometheus/Grafana e o Loki são instalados via Helm chart gerenciado pelo
ArgoCD. O OTel Collector coleta logs dos nodes e recebe métricas/traces dos
serviços; envia logs ao Loki, métricas ao Prometheus e telemetria ao New Relic.
O dashboard é provisionado por ConfigMap. O serviço de self-healing é interno,
autenticado pelo token e só pode aplicar patch nos Deployments `auth-service` e
`evaluation-service`.

### 6.4 Validar o fluxo e coletar as evidências

```bash
kubectl get applications -n argocd
kubectl get pods,svc -n observability
kubectl get servicemonitor -n observability
kubectl port-forward -n observability svc/togglemaster-observability-grafana 3000:80
```

No Grafana, acesse `http://localhost:3000`, abra o dashboard **ToggleMaster -
Saúde do Ecossistema** e consulte logs em Explore com
`{k8s_namespace_name="togglemaster"}`. A senha inicial do Grafana é criada em
Secret pelo chart; obtenha-a com:

```bash
kubectl get secret -n observability togglemaster-observability-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d; echo
```

Gere tráfego em `/evaluate` para preencher métricas e traces. No New Relic,
mostre o Service Map e um trace completo, incluindo as chamadas a flags e
targeting e o evento assíncrono enviado para SQS/consumido pelo analytics.

Para demonstrar self-healing sem indisponibilizar o banco, em ambiente de teste
pause temporariamente a reconciliação automática desse app (para o ArgoCD não
reverter o teste), reduza o `auth-service` a zero réplicas e depois restaure a
Application original:

```bash
kubectl patch application auth-service -n argocd --type=merge \
  -p '{"spec":{"syncPolicy":{"automated":null}}}'
kubectl scale deployment/auth-service -n togglemaster --replicas=0
kubectl get deployment/auth-service -n togglemaster -w
# Depois da evidência e do rollout Ready, reative o GitOps:
kubectl apply -f argocd/applications/auth-service.yaml
```

O alerta `AuthServiceUnavailable` dispara após 1 minuto; PagerDuty e Discord
recebem a notificação e a automação restaura uma réplica e reinicia o pod.
Mostre o evento no Alertmanager/Grafana, no PagerDuty, no Discord e o novo pod
ficando Ready. Faça este teste somente em ambiente controlado. A integração
também monitora erros 5xx de auth e evaluation; o self-healing limita reinícios
repetidos ao mesmo alerta por 10 minutos.
O restart mitiga falhas transitórias; uma dependência persistentemente
indisponível (por exemplo, o banco de dados) ainda exige correção da causa raiz.

Inclua as capturas exigidas no relatório baseado em
`docs/RELATORIO-FASE4-template.md`.

## 7. Rodar o pipeline de CI/CD da Fase 3 (para o vídeo de DevSecOps)

1. Dê um `git push` numa branch e abra PR alterando algo em `auth-service/`
   → mostra o pipeline rodando build/lint/security scan.
2. Insira propositalmente uma dependência vulnerável (ex: uma lib Go/Python
   antiga e com CVE conhecida) → mostra o job `security_scan` **falhando**.
3. Corrija a dependência → mostra o pipeline passando, buildando a imagem,
   escaneando com Trivy, subindo pro ECR e commitando a nova tag em
   `gitops/apps/auth-service/deployment.yaml`.
4. Mostre o ArgoCD detectando a mudança no Git e sincronizando automaticamente
   a nova versão no cluster.

## 8. Roteiro sugerido para demonstrar a Fase 3 (até 20 min)

1. `terraform plan`/`apply` ou os recursos já criados no console (3–4 min)
2. Estrutura do código Terraform (módulos) (1–2 min)
3. Pipeline rodando normalmente (2 min)
4. Alteração proposital → pipeline falhando no security scan (2–3 min)
5. Correção → pipeline passando, build, push, atualização do GitOps (3–4 min)
6. ArgoCD sincronizando automaticamente no cluster (2–3 min)
7. Encerramento com resumo (1 min)

## 9. Entregáveis finais

- Vídeo (link do YouTube/Drive)
- Código-fonte no repositório (já commitado com este pacote)
- Relatório PDF/txt — ver template em `docs/RELATORIO-FASE3-template.md`
  (nomes, links, resumo de decisões, print de custo estimado da AWS —
  Billing → Cost Explorer ou AWS Pricing Calculator)
- Para a Fase 4, use também `docs/RELATORIO-FASE4-template.md`; o vídeo deve
  evidenciar todas as integrações solicitadas e pode ter até 25 minutos.
