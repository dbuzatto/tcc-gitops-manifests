#!/usr/bin/env bash
# amostra o consumo do mecanismo de entrega enquanto uma bateria roda em outro terminal
# pull: pods do argocd via kubectl top | push: processos do runner via /proc

source "$(dirname "$0")/comum.sh"

MODELO="${1:-}"
DURACAO="${2:-300}"
INTERVALO=15
CLK_TCK=$(getconf CLK_TCK)

case "$MODELO" in
  pull|push) ;;
  *) echo "uso: $0 pull|push [duracao_s]" >&2; exit 1 ;;
esac

mkdir -p "$RESULTADOS"
CSV="$RESULTADOS/recursos-$MODELO-$(date +%Y%m%d-%H%M%S).csv"
echo "timestamp,origem,cpu_milicores,memoria_mib" > "$CSV"

jiffies_dos_pids() {
  local total=0 pid
  for pid in $1; do
    [[ -r /proc/$pid/stat ]] && total=$(( total + $(awk '{ print $14 + $15 }' "/proc/$pid/stat") ))
  done
  echo "$total"
}

memoria_dos_pids() {
  local total=0 pid
  for pid in $1; do
    [[ -r /proc/$pid/status ]] && total=$(( total + $(awk '/VmRSS/ { print $2 }' "/proc/$pid/status") ))
  done
  echo $(( total / 1024 ))
}

limite=$(( $(date +%s) + DURACAO ))
while (( $(date +%s) < limite )); do
  if [[ "$MODELO" == "pull" ]]; then
    kubectl top pods -n argocd --no-headers | awk -v ts="$(date +%s)" \
      '{ gsub("m","",$2); gsub("Mi","",$3); print ts "," $1 "," $2 "," $3 }' >> "$CSV"
    sleep "$INTERVALO"
  else
    pids=$(pgrep -f 'Runner.Listener|Runner.Worker' || true)
    if [[ -z "$pids" ]]; then
      echo "$(date +%s),runner,0,0" >> "$CSV"
      sleep "$INTERVALO"
      continue
    fi
    j1=$(jiffies_dos_pids "$pids")
    sleep "$INTERVALO"
    j2=$(jiffies_dos_pids "$pids")
    cpu=$(( (j2 - j1) * 1000 / CLK_TCK / INTERVALO ))
    (( cpu < 0 )) && cpu=0
    echo "$(date +%s),runner,$cpu,$(memoria_dos_pids "$pids")" >> "$CSV"
  fi
done

echo "resultados em $CSV"
