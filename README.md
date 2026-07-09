# ToggleMaster - Tech Challenge Fase 2

Projeto desenvolvido para a Fase 2 do Tech Challenge da Pos Tech. O objetivo foi migrar o ToggleMaster de uma arquitetura monolitica para uma arquitetura baseada em microsservicos, conteinerizada com Docker e executada em Kubernetes na AWS com EKS.

## Arquitetura

O sistema foi dividido em 5 microsservicos:

| Servico | Stack | Responsabilidade | Dependencias |
|---|---|---|---|
| auth-service | Go | Criacao e validacao de API keys | PostgreSQL |
| flag-service | Python/Flask | CRUD de feature flags | PostgreSQL, auth-service |
| targeting-service | Python/Flask | Regras de segmentacao | PostgreSQL, auth-service |
| evaluation-service | Go | Avaliacao de flags em tempo real | Redis, SQS, flag-service, targeting-service |
| analytics-service | Python/Flask | Consumo de eventos e persistencia analitica | SQS, DynamoDB |

Fluxo principal:

```txt
Cliente
  -> evaluation-service
  -> flag-service + targeting-service
  -> Redis cache
  -> SQS
  -> analytics-service
  -> DynamoDB
```

## Estrutura Do Repositorio

```txt
.
├── analytics-service/
├── auth-service/
├── evaluation-service/
├── flag-service/
├── targeting-service/
├── docker/
├── k8s/
│   ├── apps/
│   ├── hpa/
│   ├── ingress/
│   └── jobs/
├── docker-compose.yaml
├── .env.example
└── README.md
```

## Execucao Local Com Docker Compose

O ambiente local sobe 9 containers:

- 5 microsservicos
- 2 PostgreSQL
- 1 Redis
- 1 DynamoDB Local

Crie o arquivo `.env` a partir do exemplo:

```bash
cp .env.example .env
```

Exemplo de variaveis:

```env
MASTER_KEY=troque-esta-chave
SERVICE_API_KEY=tm_key_exemplo
POSTGRES_USER=usuario
POSTGRES_PASSWORD=senha
AUTH_DB=auth_db
POSTGRES_SHARED_DB=togglemaster
FLAGS_DB=flags_db
TARGETING_DB=targeting_db
```

Build das imagens:

```bash
docker build -t auth-service ./auth-service
docker build -t flag-service ./flag-service
docker build -t targeting-service ./targeting-service
docker build -t evaluation-service ./evaluation-service
docker build -t analytics-service ./analytics-service
```

Subir ambiente:

```bash
docker compose up -d
docker compose ps
```

Health checks locais:

```bash
curl http://localhost:8001/health
curl http://localhost:8002/health
curl http://localhost:8003/health
curl http://localhost:8004/health
curl http://localhost:8005/health
```

## Fluxo Local

Criar API key:

```bash
curl -X POST http://localhost:8001/admin/keys \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer troque-esta-chave" \
  -d '{"name": "evaluation-service-key"}'
```

Atualize `SERVICE_API_KEY` no `.env` com a chave retornada e recrie os servicos que usam a chave:

```bash
docker compose up -d --force-recreate flag-service targeting-service evaluation-service
```

Criar feature flag:

```bash
curl -X POST http://localhost:8002/flags \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer tm_key_sua_chave" \
  -d '{
    "name": "enable-new-dashboard",
    "description": "Ativa o novo dashboard",
    "is_enabled": true
  }'
```

Criar regra de segmentacao:

```bash
curl -X POST http://localhost:8003/rules \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer tm_key_sua_chave" \
  -d '{
    "flag_name": "enable-new-dashboard",
    "is_enabled": true,
    "rules": {
      "type": "PERCENTAGE",
      "value": 50
    }
  }'
```

Avaliar flag:

```bash
curl "http://localhost:8004/evaluate?user_id=user-123&flag_name=enable-new-dashboard"
```

## Recursos AWS Utilizados

Na AWS foram criados:

| Recurso | Quantidade | Uso |
|---|---:|---|
| ECR | 5 repositorios | Imagens dos microsservicos |
| RDS PostgreSQL | 3 instancias | auth, flags e targeting |
| ElastiCache Redis | 1 cache | Cache do evaluation-service |
| DynamoDB | 1 tabela | Eventos analiticos |
| SQS | 1 fila | Comunicacao evaluation -> analytics |
| EKS | 1 cluster | Orquestracao Kubernetes |
| Nginx Ingress Controller | 1 | Entrada HTTP externa |
| Metrics Server | 1 | Metricas para HPA |

## Publicacao Das Imagens No ECR

Exemplo de login:

```bash
aws ecr get-login-password --region us-east-1 \
  | docker login --username AWS --password-stdin 463543537600.dkr.ecr.us-east-1.amazonaws.com
```

Tag e push:

```bash
docker tag auth-service:latest 463543537600.dkr.ecr.us-east-1.amazonaws.com/auth-service:latest
docker tag flag-service:latest 463543537600.dkr.ecr.us-east-1.amazonaws.com/flag-service:latest
docker tag targeting-service:latest 463543537600.dkr.ecr.us-east-1.amazonaws.com/targeting-service:latest
docker tag evaluation-service:latest 463543537600.dkr.ecr.us-east-1.amazonaws.com/evaluation-service:latest
docker tag analytics-service:latest 463543537600.dkr.ecr.us-east-1.amazonaws.com/analytics-service:latest

docker push 463543537600.dkr.ecr.us-east-1.amazonaws.com/auth-service:latest
docker push 463543537600.dkr.ecr.us-east-1.amazonaws.com/flag-service:latest
docker push 463543537600.dkr.ecr.us-east-1.amazonaws.com/targeting-service:latest
docker push 463543537600.dkr.ecr.us-east-1.amazonaws.com/evaluation-service:latest
docker push 463543537600.dkr.ecr.us-east-1.amazonaws.com/analytics-service:latest
```

## Kubernetes No EKS

Conectar no cluster:

```bash
aws eks update-kubeconfig --region us-east-1 --name togglemaster-cluster
kubectl get nodes
```

Aplicar namespace, secrets e configs:

```bash
kubectl apply -f k8s/00-namespace.yaml
kubectl apply -f k8s/01-secrets.yaml
kubectl apply -f k8s/02-configmaps.yaml
```

O arquivo real `k8s/01-secrets.yaml` nao deve ser versionado. Use `k8s/01-secrets.example.yaml` como modelo seguro.

Inicializar tabelas nos RDS:

```bash
kubectl apply -f k8s/jobs/auth-db-init-sql-configmap.yaml
kubectl apply -f k8s/jobs/flag-db-init-sql-configmap.yaml
kubectl apply -f k8s/jobs/targeting-db-init-sql-configmap.yaml

kubectl apply -f k8s/jobs/auth-db-init-job.yaml
kubectl apply -f k8s/jobs/flag-db-init-job.yaml
kubectl apply -f k8s/jobs/targeting-db-init-job.yaml

kubectl get jobs -n togglemaster
```

Aplicar os microsservicos:

```bash
kubectl apply -f k8s/apps/auth-service.yaml
kubectl apply -f k8s/apps/flag-service.yaml
kubectl apply -f k8s/apps/targeting-service.yaml
kubectl apply -f k8s/apps/evaluation-service.yaml
kubectl apply -f k8s/apps/analytics-service.yaml
```

Aplicar Ingress e HPA:

```bash
kubectl apply -f k8s/ingress/ingress.yaml
kubectl apply -f k8s/hpa/evaluation-hpa.yaml
kubectl apply -f k8s/hpa/analytics-hpa.yaml
```

## Validacoes No Kubernetes

```bash
kubectl get pods -n togglemaster
kubectl get deployments -n togglemaster
kubectl get svc -n togglemaster
kubectl get ingress -n togglemaster
kubectl get hpa -n togglemaster
kubectl get jobs -n togglemaster
```

Health checks via Ingress:

```bash
INGRESS_HOST=a47ec370d006f42e8a8fa1c844b01416-d5f7120d581e93c9.elb.us-east-1.amazonaws.com

curl http://$INGRESS_HOST/auth/health
curl http://$INGRESS_HOST/flags/health
curl http://$INGRESS_HOST/targeting/health
curl http://$INGRESS_HOST/evaluation/health
curl http://$INGRESS_HOST/analytics/health
```

## Escalabilidade

Foram criados HPAs para:

- evaluation-service
- analytics-service

Ambos usam CPU como metrica, com alvo de 70%:

```bash
kubectl get hpa -n togglemaster
kubectl describe hpa evaluation-service-hpa -n togglemaster
kubectl describe hpa analytics-service-hpa -n togglemaster
```

## Seguranca E Hardening

Medidas aplicadas:

- Dockerfiles com imagens base atualizadas.
- Imagens Python baseadas em `python:3.13-alpine3.24`.
- Imagens Go com build multi-stage usando `golang:1.25-alpine3.24` e runtime `alpine:3.24`.
- Containers executando como usuario nao-root.
- Secrets reais fora do versionamento.
- `.env` fora do versionamento.
- RDS e Redis privados em Security Group controlado.
- Ingress expondo apenas os servicos HTTP.

## Observacoes Sobre AWS Academy

As credenciais do AWS Academy sao temporarias. Ao iniciar uma nova sessao do lab, atualize:

- `~/.aws/credentials`
- `k8s/01-secrets.yaml`, bloco `aws-credentials`

Depois reaplique e reinicie os servicos que usam AWS:

```bash
kubectl apply -f k8s/01-secrets.yaml
kubectl rollout restart deployment/evaluation-service -n togglemaster
kubectl rollout restart deployment/analytics-service -n togglemaster
```

## Status Final Validado

O ambiente foi validado com:

- 5 deployments em estado `Ready`.
- 5 services `ClusterIP`.
- Ingress externo respondendo health checks.
- HPA ativo com metricas do Metrics Server.
- Jobs de banco finalizados com sucesso.
- Fluxo completo funcionando: criacao de flag, criacao de regra, avaliacao, envio para SQS, consumo pelo analytics-service e persistencia no DynamoDB.
