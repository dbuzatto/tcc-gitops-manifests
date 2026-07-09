#!/usr/bin/env bash
# mede o tempo de deploy: do push no git ate os pods novos ficarem prontos

source "$(dirname "$0")/comum.sh"

MODELO="${1:-}"
ITERACOES="${2:-5}"
TIMEOUT=360

valida_modelo "$MODELO"
garante_branch_experimento

mkdir -p "$RESULTADOS"
CSV="$RESULTADOS/deploy-$MODELO-$(date +%Y%m%d-%H%M%S).csv"
echo "iteracao,imagem,inicio_epoch,duracao_s" > "$CSV"

for i in $(seq 1 "$ITERACOES"); do
  # alterna a imagem para forcar um rollout de verdade a cada iteracao
  if [[ "$(imagem_no_manifesto)" == "nginx:1.27" ]]; then
    nova="nginx:1.28"
  else
    nova="nginx:1.27"
  fi
  sed -i "s|image: .*|image: $nova|" "$REPO_DIR/app/deployment.yaml"

  git -C "$REPO_DIR" add app/deployment.yaml
  git -C "$REPO_DIR" commit -q -m "exp: deploy $MODELO iteracao $i"
  git -C "$REPO_DIR" push -q origin HEAD
  inicio=$(agora)

  espera_imagem "$nova" "$TIMEOUT"
  fim=$(agora)

  tempo=$(duracao "$inicio" "$fim")
  echo "$i,$nova,$inicio,$tempo" >> "$CSV"
  echo "iteracao $i: $nova pronta em ${tempo}s"
  sleep 5
done

echo "resultados em $CSV"
