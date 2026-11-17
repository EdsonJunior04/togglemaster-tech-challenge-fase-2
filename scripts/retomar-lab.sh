#!/usr/bin/env bash
# Retoma o ambiente depois de um novo "Start Lab" no AWS Academy.
# Pré-requisito: colar as credenciais novas em ~/.aws/credentials ANTES de rodar.
set -euo pipefail

REGION=us-east-1
CLUSTER=togglemaster-cluster
REPO=EdsonJunior04/togglemaster-tech-challenge-fase-2

echo "==> 1/6 Credenciais e kubeconfig"
aws sts get-caller-identity --query Account --output text
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER" >/dev/null

echo "==> 2/6 Aguardando nós Ready (até 10 min)"
for i in $(seq 1 60); do
  ready=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready" || true)
  echo "   nós Ready: $ready"
  [ "$ready" -ge 3 ] && break
  sleep 10
done
kubectl get nodes

AK=$(aws configure get aws_access_key_id)
SK=$(aws configure get aws_secret_access_key)
ST=$(aws configure get aws_session_token)

echo "==> 3/6 Secret aws-credentials no cluster"
kubectl create secret generic aws-credentials -n togglemaster \
  --from-literal=AWS_ACCESS_KEY_ID="$AK" \
  --from-literal=AWS_SECRET_ACCESS_KEY="$SK" \
  --from-literal=AWS_SESSION_TOKEN="$ST" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> 4/6 Secrets do GitHub Actions"
gh secret set AWS_ACCESS_KEY_ID     -R "$REPO" --body "$AK"
gh secret set AWS_SECRET_ACCESS_KEY -R "$REPO" --body "$SK"
gh secret set AWS_SESSION_TOKEN     -R "$REPO" --body "$ST"

echo "==> 5/6 Reiniciando serviços que usam AWS"
kubectl rollout restart deployment/evaluation-service deployment/analytics-service -n togglemaster
kubectl rollout status deployment/evaluation-service -n togglemaster --timeout=180s
kubectl rollout status deployment/analytics-service -n togglemaster --timeout=180s

echo "==> 6/6 Estado geral"
kubectl get applications -n argocd
kubectl get pods -n togglemaster | grep -v Completed
kubectl get pods -n observability
echo
echo "Pronto. Próximos passos: port-forward do Grafana e ./scripts/gerar-trafego.sh"
