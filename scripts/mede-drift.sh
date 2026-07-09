#!/usr/bin/env bash
# mede o tempo de correcao de drift: scale manual ate voltar ao estado do git
# no pull a correcao e automatica (self-heal), no push depende de uma execucao do pipeline

source "$(dirname "$0")/comum.sh"

MODELO="${1:-}"
ITERACOES="${2:-5}"
TIMEOUT=360

valida_modelo "$MODELO"

mkdir -p "$RESULTADOS"
CSV="$RESULTADOS/drift-$MODELO-$(date +%Y%m%d-%H%M%S).csv"
echo "iteracao,inicio_epoch,duracao_s" > "$CSV"

for i in $(seq 1 "$ITERACOES"); do
  kubectl scale deployment "$DEPLOYMENT" -n "$NAMESPACE" --replicas=5 >/dev/null

  if [[ "$MODELO" == "push" ]]; then
    dispara_workflow
  fi
  inicio=$(agora)

  espera_replicas "$REPLICAS" "$TIMEOUT"
  fim=$(agora)

  tempo=$(duracao "$inicio" "$fim")
  echo "$i,$inicio,$tempo" >> "$CSV"
  echo "iteracao $i: drift corrigido em ${tempo}s"
  sleep 10
done

echo "resultados em $CSV"
