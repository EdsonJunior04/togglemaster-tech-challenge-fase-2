# ToggleMaster - Tech Challenge Fase 2

## Visao Geral

Este projeto executa localmente os 5 microsservicos do ToggleMaster e suas dependencias usando Docker Compose.

## Servicos

| Servico | Porta | Descricao |
|---|---:|---|
| auth-service | 8001 | Autenticacao e API keys |
| flag-service | 8002 | CRUD de feature flags |
| targeting-service | 8003 | Regras de segmentacao |
| evaluation-service | 8004 | Avaliacao das flags |
| analytics-service | 8005 | Worker de analytics |
| postgres-auth | 5432 | PostgreSQL do auth-service |
| postgres-flags-targeting | 5433 | PostgreSQL compartilhado para flags e targeting |
| redis | 6379 | Cache do evaluation-service |
| dynamodb-local | 8000 | DynamoDB Local para analytics |

## Build Das Imagens

```bash
docker build -t auth-service ./auth-service
docker build -t flag-service ./flag-service
docker build -t targeting-service ./targeting-service
docker build -t evaluation-service ./evaluation-service
docker build -t analytics-service ./analytics-service
```

## Subindo O Ambiente

```bash
docker compose up -d
```

## Verificando Containers

```bash
docker compose ps
```
Devem existir 9 containers em execucao.

## Health Checks

```bash
curl http://localhost:8001/health
curl http://localhost:8002/health
curl http://localhost:8003/health
curl http://localhost:8004/health
curl http://localhost:8005/health
```

## Criando API Key

```bash
curl -X POST http://localhost:8001/admin/keys \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer admin-secreto-123" \
  -d '{"name": "evaluation-service-key"}'
```
Copie o valor retornado em key.

## Configurando SERVICE_API_KEY

No arquivo docker-compose.yaml, atualize:
```yaml
SERVICE_API_KEY: "tm_key_sua_chave"
```
Depois recrie o evaluation-service:
```bash
docker compose up -d --force-recreate evaluation-service
```

## Criando Feature Flag

```bash
curl -X POST http://localhost:8002/flags \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer tm_key_sua_chave" \
  -d '{
    "name": "enable-new-dashboard",
    "description": "Ativa o novo dashboard para usuarios",
    "is_enabled": true
  }'
```

## Criando Regra De Segmentacao

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

## Avaliando Feature Flag

```bash
curl "http://localhost:8004/evaluate?user_id=user-123&flag_name=enable-new-dashboard"
```

## Analytics Local
O analytics-service roda em modo local com DynamoDB Local e worker SQS desabilitado.
```bash
curl http://localhost:8005/health
```
Resposta esperada:
```bash
{
  "dynamodb_table": "ToggleMasterAnalytics",
  "sqs_worker_enabled": false,
  "status": "ok"
}
```

## DynamoDB Local

Para listar tabelas pelo container do analytics:
```bash
docker exec togglemaster-analytics-service python -c "import boto3; c=boto3.client('dynamodb', region_name='us-east-1', endpoint_url='http://dynamodb-local:8000', aws_access_key_id='local', aws_secret_access_key='local'); print(c.list_tables())"
```