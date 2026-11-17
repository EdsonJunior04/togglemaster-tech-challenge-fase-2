# observability-actions

Serviço interno de resposta a incidentes da Fase 4. Recebe webhooks do
Alertmanager (autenticados por token Bearer) e:

- `/discord`: encaminha o alerta para o canal do Discord (ChatOps);
- `/self-heal`: faz rollout restart (e restaura 1 réplica, se zerada) do
  deployment afetado, via API do Kubernetes, com RBAC restrito e cooldown.
