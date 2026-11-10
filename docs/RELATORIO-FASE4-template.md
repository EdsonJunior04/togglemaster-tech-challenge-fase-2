# Tech Challenge — Fase 4 | ToggleMaster

## Integrantes

| Nome | RM | Username |
|---|---|---|
| Nome do integrante | RM | Username |

## Links

- Repositório: URL
- Vídeo de demonstração (até 25 minutos): URL

## Arquitetura de observabilidade

Descreva o fluxo implementado:

```text
Microsserviços (OTel SDK/auto-instrumentação)
  -> OpenTelemetry Collector
  -> Prometheus (métricas) / Loki (logs) / New Relic (APM e traces)
  -> Alertmanager
  -> PagerDuty + Discord + webhook interno de self-healing
```

Explique como o contexto de trace é propagado entre os microsserviços e através
da fila SQS. Registre decisões, limites de retenção e medidas de segurança dos
Secrets e das permissões RBAC.

## Ferramentas escolhidas

- APM: New Relic — justificativa:
- Incidentes: PagerDuty — justificativa:
- ChatOps: Discord:
- Automação: webhook interno autenticado com token, cooldown e RBAC restrito:

## Evidências obrigatórias

### Dashboard Grafana

> Inserir captura do dashboard customizado mostrando recursos do cluster, taxa
> de requisições e logs consultados no Loki.

### Trace distribuído e Service Map

> Inserir captura do Service Map no New Relic e do trace de uma chamada ao
> `evaluation-service`, incluindo dependências e o fluxo assíncrono SQS.

### Incidente e ChatOps

> Inserir captura do alerta firing/incidente no PagerDuty e da notificação
> correspondente no canal Discord.

### Self-healing

> Inserir captura do log/execução da automação e do rollout do Deployment
> recuperado no Kubernetes.

## Procedimento de validação

Descreva a falha controlada usada, o instante de disparo do alerta, a abertura
do incidente, a notificação e a recuperação automática. Informe também como a
sincronização GitOps foi restaurada após o teste.

## Conclusão

Resumo dos resultados, problemas encontrados e melhorias futuras.
