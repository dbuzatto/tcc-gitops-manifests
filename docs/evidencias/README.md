# Evidências do experimento

Registros coletados durante o desenvolvimento, para uso na monografia e na apresentação.

## argocd/ - Primeiro deploy no modelo pull (02/07/2026)

Deploy da aplicação de teste realizado exclusivamente pelo ArgoCD (v3.4.4) a partir do commit `1f842cb` da branch main, sem nenhum `kubectl apply` dos manifestos da aplicação.

- `application-sincronizada.png`: tela de Applications com a application `app-teste` Healthy/Synced, apontando para este repositório (branch main, path `app`), destino in-cluster no namespace default.
- `arvore-de-recursos.png`: árvore de recursos sincronizada no commit `1f842cb`, com auto-sync habilitado: Service + Deployment > ReplicaSet > 2 pods Running.
- `pods-do-cluster.png`: saída de `kubectl get pods -A` mostrando os componentes do ArgoCD no namespace `argocd` e os 2 pods da aplicação no namespace `default`, distribuídos no cluster kind de 3 nodes.

No mesmo dia foi validado o self-heal: um `kubectl scale --replicas=5` manual foi revertido pelo ArgoCD para as 2 réplicas declaradas no Git em menos de 15 segundos.

## actions/ - Primeira execução no modelo push (06/07/2026)

Pipeline do GitHub Actions validado com runner self-hosted registrado na máquina do experimento (necessário porque os runners da nuvem do GitHub não alcançam o cluster kind local).

- `runner-registrado.png`: página de runners do repositório mostrando o runner self-hosted `ROG-DIOGO` (Linux x64) disponível.
- `etapas-do-job.png`: primeira execução do workflow `deploy`, concluída com sucesso em 9 segundos: checkout, aplicação dos manifestos com `kubectl apply` e verificação do rollout.
