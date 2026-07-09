#!/usr/bin/env bash
# mede o tempo de rollback: revert do ultimo commit ate a versao anterior ficar pronta

source "$(dirname "$0")/comum.sh"

MODELO="${1:-}"
ITERACOES="${2:-5}"
TIMEOUT=360

valida_modelo "$MODELO"
garante_branch_experimento

if ! git -C "$REPO_DIR" diff HEAD~1 --name-only | grep -q app/deployment.yaml; then
  echo "o ultimo commit precisa ser uma troca de imagem, rode mede-deploy.sh antes" >&2
  exit 1
fi

mkdir -p "$RESULTADOS"
CSV="$RESULTADOS/rollback-$MODELO-$(date +%Y%m%d-%H%M%S).csv"
echo "iteracao,imagem_alvo,inicio_epoch,duracao_s" > "$CSV"

for i in $(seq 1 "$ITERACOES"); do
  git -C "$REPO_DIR" revert --no-edit --no-commit HEAD
  git -C "$REPO_DIR" commit -q -m "exp: rollback $MODELO iteracao $i"
  alvo=$(imagem_no_manifesto)
  git -C "$REPO_DIR" push -q origin HEAD
  inicio=$(agora)

  espera_imagem "$alvo" "$TIMEOUT"
  fim=$(agora)

  tempo=$(duracao "$inicio" "$fim")
  echo "$i,$alvo,$inicio,$tempo" >> "$CSV"
  echo "iteracao $i: rollback para $alvo em ${tempo}s"
  sleep 5
done

echo "resultados em $CSV"
