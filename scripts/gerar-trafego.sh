#!/usr/bin/env bash
# Gera tráfego no evaluation-service para popular métricas (Grafana),
# logs (Loki) e traces (New Relic) durante a demonstração da Fase 4.
#
# Uso:
#   kubectl port-forward -n togglemaster svc/evaluation-service 8004:8004 &
#   ./scripts/gerar-trafego.sh                       # 300 requisições
#   N=1000 FLAG=enable-new-dashboard ./scripts/gerar-trafego.sh
#
# Também funciona via Ingress:
#   BASE_URL=http://<ingress-host>/evaluation ./scripts/gerar-trafego.sh
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost:8004}"
FLAG="${FLAG:-enable-new-dashboard}"
N="${N:-300}"
SLEEP="${SLEEP:-0.2}"

ok=0; erro=0
for i in $(seq 1 "$N"); do
  code=$(curl -s -o /dev/null -w '%{http_code}' \
    "${BASE_URL}/evaluate?user_id=user-${RANDOM}&flag_name=${FLAG}" || echo 000)
  if [[ "$code" =~ ^2 ]]; then ok=$((ok+1)); else erro=$((erro+1)); fi
  if (( i % 25 == 0 )); then
    echo "[$i/$N] sucesso=$ok erro=$erro (último HTTP $code)"
  fi
  sleep "$SLEEP"
done
echo "Concluído: sucesso=$ok erro=$erro"
