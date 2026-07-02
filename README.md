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
```

## Como funciona

Este repositório é a fonte de verdade do estado desejado do cluster. No modelo pull, o ArgoCD observa a pasta `app/` e aplica qualquer mudança commitada aqui automaticamente (auto-sync), além de reverter alterações manuais feitas direto no cluster (self-heal). No modelo push, um workflow do GitHub Actions aplica os mesmos manifestos via `kubectl apply` a cada push.

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
