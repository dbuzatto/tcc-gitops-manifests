# tcc-gitops-manifests

Manifestos usados no experimento do meu TCC: comparação entre entrega contínua no modelo pull (GitOps com ArgoCD) e no modelo push (GitHub Actions) em Kubernetes.

## Estrutura

```
├── kind-config.yaml   # config do cluster kind (1 control-plane + 2 workers)
├── app/
│   ├── deployment.yaml   # nginx:1.27, 2 réplicas
│   └── service.yaml      # Service ClusterIP na porta 80
├── argocd/
│   └── application.yaml  # Application do ArgoCD (auto-sync + self-heal)
├── .github/workflows/
│   └── deploy.yaml       # workflow do modelo push (runner self-hosted)
├── metrics-server/
│   └── components.yaml   # metrics-server v0.8.1 com ajuste para o kind
├── scripts/              # scripts de medição das baterias do experimento
├── docs/
│   └── evidencias/       # registros datados dos marcos do experimento
```

## Como funciona

Este repositório é a fonte de verdade do estado desejado do cluster. No modelo pull, o ArgoCD observa a pasta `app/` e aplica qualquer mudança commitada aqui automaticamente (auto-sync), além de reverter alterações manuais feitas direto no cluster (self-heal). No modelo push, o workflow em `.github/workflows/deploy.yaml` aplica os mesmos manifestos via `kubectl apply` a cada push que altere `app/`, executando em um runner self-hosted na máquina do experimento (os runners da nuvem do GitHub não alcançam o cluster kind local).

Durante as medições os dois mecanismos nunca ficam ativos ao mesmo tempo, para um não interferir nas métricas do outro. O `scripts/prepara-bateria.sh` prepara o ambiente para cada bateria e os scripts de medição validam esse estado antes de rodar.

## Medições

Os scripts em `scripts/` automatizam as métricas do experimento e gravam os resultados em CSV na pasta `resultados/`:

- `mede-deploy.sh pull|push [n]`: tempo do push no Git até os pods novos ficarem prontos, alternando a imagem do nginx a cada iteração
- `mede-rollback.sh pull|push [n]`: tempo do `git revert` até a versão anterior ficar pronta
- `mede-drift.sh pull|push [n]`: tempo de correção de um `kubectl scale` manual até o estado do Git ser restaurado
- `coleta-recursos.sh pull|push [s]`: consumo de CPU e memória do mecanismo de entrega (pods do ArgoCD via metrics-server no pull, processos do runner via /proc no push)

As baterias rodam numa branch dedicada (`experimento`) para os commits de iteração não poluírem o histórico da main.

O metrics-server não vem instalado no kind: `kubectl apply -f metrics-server/components.yaml` (manifesto oficial com a flag `--kubelet-insecure-tls`, necessária porque os kubelets do kind usam certificado auto-assinado).

A aplicação de teste é um nginx simples de propósito: o objeto de estudo do TCC é o mecanismo de entrega, não a aplicação.

## Reproduzindo o ambiente

```bash
# criar o cluster
kind create cluster --name tcc-gitops --config kind-config.yaml

# instalar o ArgoCD (server-side apply é obrigatório por causa do CRD de applicationsets)
kubectl create namespace argocd
kubectl apply -n argocd --server-side -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# registrar a aplicação no ArgoCD (modelo pull)
kubectl apply -f argocd/application.yaml
```

A partir daí o ArgoCD sincroniza sozinho: qualquer commit na pasta `app/` é aplicado no cluster sem `kubectl apply` manual, e alterações feitas direto no cluster são revertidas pelo self-heal. O acesso ao repositório é anônimo (repo público via HTTPS), então nenhuma credencial de cluster sai do ambiente, que é justamente um dos pontos comparados no experimento.
