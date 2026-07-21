#!/usr/bin/env bash
# destroi e recria o cluster do zero, reinstalando argocd e metrics-server
# roda entre baterias para isolar as medicoes (exigencia da metodologia)

source "$(dirname "$0")/comum.sh"

CLUSTER=tcc-gitops
ARGOCD_VERSION=v3.4.4
ARGOCD_MANIFESTO="https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/install.yaml"

echo "==> destruindo o cluster $CLUSTER"
kind delete cluster --name "$CLUSTER"

echo "==> criando o cluster $CLUSTER"
kind create cluster --name "$CLUSTER" --config "$REPO_DIR/kind-config.yaml"

echo "==> instalando o argocd $ARGOCD_VERSION"
kubectl create namespace argocd
# server-side apply obrigatorio: o apply normal estoura o limite de annotation no CRD de applicationsets
kubectl apply -n argocd --server-side -f "$ARGOCD_MANIFESTO" >/dev/null

echo "==> aguardando o argocd subir"
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s
kubectl -n argocd rollout status deployment/argocd-server --timeout=300s
kubectl -n argocd rollout status deployment/argocd-repo-server --timeout=300s

echo "==> instalando o metrics-server"
kubectl apply -f "$REPO_DIR/metrics-server/components.yaml" >/dev/null
kubectl -n kube-system rollout status deployment/metrics-server --timeout=180s

echo "==> validando kubectl top"
for _ in $(seq 1 24); do
  kubectl top nodes >/dev/null 2>&1 && break
  sleep 5
done
kubectl top nodes

echo
echo "ambiente recriado: cluster $CLUSTER + argocd $ARGOCD_VERSION + metrics-server, sem application"
echo "o runner nao precisa de re-registro (o kind reescreveu o ~/.kube/config sozinho)"
echo "proximo passo: ./scripts/prepara-bateria.sh pull   (ou push)"
