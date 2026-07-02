# Evidências do experimento

Registros coletados durante o desenvolvimento, para uso na monografia e na apresentação.

## 02/07/2026 — Primeiro deploy no modelo pull

Deploy da aplicação de teste realizado exclusivamente pelo ArgoCD (v3.4.4) a partir do commit `1f842cb` da branch main, sem nenhum `kubectl apply` dos manifestos da aplicação.

- `2026-07-02-argocd-application-synced.png`: tela de Applications com a application `app-teste` Healthy/Synced, apontando para este repositório (branch main, path `app`), destino in-cluster no namespace default.
- `2026-07-02-argocd-arvore-recursos.png`: árvore de recursos sincronizada no commit `1f842cb`, com auto-sync habilitado: Service + Deployment > ReplicaSet > 2 pods Running.
- `2026-07-02-pods-do-cluster.png`: saída de `kubectl get pods -A` mostrando os componentes do ArgoCD no namespace `argocd` e os 2 pods da aplicação no namespace `default`, distribuídos no cluster kind de 3 nodes.

No mesmo dia foi validado o self-heal: um `kubectl scale --replicas=5` manual foi revertido pelo ArgoCD para as 2 réplicas declaradas no Git em menos de 15 segundos.
