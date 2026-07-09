#!/usr/bin/env bash
# funcoes e checagens compartilhadas pelos scripts de medicao

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESULTADOS="$REPO_DIR/resultados"
DEPLOYMENT=app-teste
NAMESPACE=default
REPLICAS=2
BRANCH_EXPERIMENTO=experimento
GITHUB_REPO=dbuzatto/tcc-gitops-manifests

agora() { date +%s.%N; }

duracao() { awk -v ini="$1" -v fim="$2" 'BEGIN { printf "%.2f", fim - ini }'; }

imagem_no_cluster() {
  kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
    -o jsonpath='{.spec.template.spec.containers[0].image}'
}

imagem_no_manifesto() {
  awk '/image:/ { print $2 }' "$REPO_DIR/app/deployment.yaml"
}

# rollout completo: imagem nova no spec e replicas atualizadas/prontas/totais batendo
espera_imagem() {
  local imagem=$1 timeout=$2 limite status
  limite=$(( $(date +%s) + timeout ))
  while (( $(date +%s) < limite )); do
    if [[ "$(imagem_no_cluster)" == "$imagem" ]]; then
      status=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" \
        -o jsonpath='{.status.updatedReplicas}/{.status.readyReplicas}/{.status.replicas}')
      [[ "$status" == "$REPLICAS/$REPLICAS/$REPLICAS" ]] && return 0
    fi
    sleep 0.5
  done
  echo "timeout esperando a imagem $imagem ficar pronta" >&2
  return 1
}

espera_replicas() {
  local esperado=$1 timeout=$2 limite spec ready
  limite=$(( $(date +%s) + timeout ))
  while (( $(date +%s) < limite )); do
    spec=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}')
    ready=$(kubectl get deployment "$DEPLOYMENT" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}')
    [[ "$spec" == "$esperado" && "$ready" == "$esperado" ]] && return 0
    sleep 0.5
  done
  echo "timeout esperando $esperado replicas" >&2
  return 1
}

dispara_workflow() {
  : "${GITHUB_TOKEN:?defina GITHUB_TOKEN para disparar o workflow via api}"
  curl -s -o /dev/null -X POST \
    -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$GITHUB_REPO/actions/workflows/deploy.yaml/dispatches" \
    -d "{\"ref\":\"$BRANCH_EXPERIMENTO\"}"
}

garante_branch_experimento() {
  local atual
  atual=$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD)
  if [[ "$atual" != "$BRANCH_EXPERIMENTO" ]]; then
    echo "as medicoes rodam na branch $BRANCH_EXPERIMENTO, voce esta em $atual" >&2
    exit 1
  fi
}

# as baterias nunca rodam com os dois mecanismos ativos ao mesmo tempo
valida_modelo() {
  case "${1:-}" in
    pull)
      if pgrep -f Runner.Listener >/dev/null; then
        echo "runner do actions esta rodando, desligue antes da bateria pull" >&2
        exit 1
      fi
      if ! kubectl get application "$DEPLOYMENT" -n argocd >/dev/null 2>&1; then
        echo "application do argocd nao existe, rode prepara-bateria.sh pull" >&2
        exit 1
      fi
      ;;
    push)
      if kubectl get application "$DEPLOYMENT" -n argocd >/dev/null 2>&1; then
        echo "application do argocd ainda existe, rode prepara-bateria.sh push" >&2
        exit 1
      fi
      if ! pgrep -f Runner.Listener >/dev/null; then
        echo "runner do actions nao esta rodando, inicie ~/actions-runner/run.sh" >&2
        exit 1
      fi
      ;;
    *)
      echo "uso: $0 pull|push [iteracoes]" >&2
      exit 1
      ;;
  esac
}
