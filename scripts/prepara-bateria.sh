#!/usr/bin/env bash
# deixa o ambiente pronto para uma bateria, com apenas um mecanismo ativo

source "$(dirname "$0")/comum.sh"

MODELO="${1:-}"

case "$MODELO" in
  pull)
    if pgrep -f Runner.Listener >/dev/null; then
      echo "desligue o runner (ctrl+c no run.sh) e rode de novo" >&2
      exit 1
    fi
    if ! git -C "$REPO_DIR" ls-remote --exit-code origin "$BRANCH_EXPERIMENTO" >/dev/null 2>&1; then
      echo "a branch $BRANCH_EXPERIMENTO nao existe no remoto, crie com:" >&2
      echo "  git checkout -b $BRANCH_EXPERIMENTO && git push -u origin $BRANCH_EXPERIMENTO" >&2
      exit 1
    fi
    alterna_workflow disable
    kubectl apply -f "$REPO_DIR/argocd/application.yaml" >/dev/null
    kubectl patch application "$DEPLOYMENT" -n argocd --type merge \
      -p "{\"spec\":{\"source\":{\"targetRevision\":\"$BRANCH_EXPERIMENTO\"}}}" >/dev/null
    echo "bateria pull pronta: application na branch $BRANCH_EXPERIMENTO, workflow desabilitado, runner desligado"
    ;;
  push)
    garante_branch_experimento
    alterna_workflow enable
    kubectl delete application "$DEPLOYMENT" -n argocd --ignore-not-found >/dev/null
    if ! grep -q "$BRANCH_EXPERIMENTO" "$REPO_DIR/.github/workflows/deploy.yaml"; then
      sed -i "s|branches: \[main\]|branches: [main, $BRANCH_EXPERIMENTO]|" \
        "$REPO_DIR/.github/workflows/deploy.yaml"
      git -C "$REPO_DIR" add .github/workflows/deploy.yaml
      git -C "$REPO_DIR" commit -q -m "ci: habilita workflow na branch de experimento"
      git -C "$REPO_DIR" push -q origin HEAD
    fi
    echo "bateria push pronta: application removida, workflow escutando a branch $BRANCH_EXPERIMENTO"
    if ! pgrep -f Runner.Listener >/dev/null; then
      echo "agora inicie o runner em outro terminal: ~/actions-runner/run.sh"
    fi
    ;;
  *)
    echo "uso: $0 pull|push" >&2
    exit 1
    ;;
esac
