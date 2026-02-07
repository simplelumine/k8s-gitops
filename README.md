# k8s-gitops

Declarative Kubernetes cluster management. A GitOps repository powered by Flux to reconcile the platform and applications.

## Architecture

This repository uses a layered GitOps architecture to manage multiple environments (laboratory & Production) from a single source of truth.

### Directory Structure

```text
.
├── clusters/             # Cluster definitions (The "Control Plane")
│   ├── production/       # Production environment (Tracks Tags)
│   │   └── overlays/     # Production-specific component selection & patches
│   └── laboratory/       # laboratory environment (Tracks Main)
│       └── overlays/     # laboratory-specific component selection & patches
│           └── core/
│               ├── secrets/ # Local Encrypted Secrets
│               └── patches/ # Local Config Patches
├── core/                 # Base Infrastructure (Cilium, Cert-Manager, Traefik, etc.)
├── services/             # Platform Services (Databases, Monitoring, etc.)
├── apps/                 # User Applications
└── docs/                 # Architecture Decision Records (ADR)
```


### Environment Strategy

We use a **Cluster-centric Overlay** pattern. The `core`, `services`, and `apps` directories contain stateless "Base" definitions. The `clusters/<env>/overlays` directories act as the control panel, deciding _which_ components to deploy and _how_ to configure them for that specific environment.

| Feature        | laboratory Cluster                        | Production Cluster                           |
| :------------- | :---------------------------------------- | :------------------------------------------- |
| **Source**     | Tracks `main` branch (Bleeding Edge)      | Tracks Git Tags (e.g., `v1.0.0`) (Stable)    |
| **Purpose**    | Testing, experimentation, rapid iteration | Stable services, long-running workloads      |
| **Management** | Components enabled/disabled on demand     | Components strictly versioned and controlled |

## Prerequisites & Initialization

Before bootstrapping this GitOps repository, the underlying infrastructure (servers, OS, K3s, CNI) must be provisioned.

Please refer to the **[infra-provisioning](https://github.com/simplelumine/infra-provisioning)** repository for:

- Server provisioning (Ansible)
- K3s cluster initialization (with specific flags to disable conflicting components)
- Base networking setup (Cilium)

## Workflow

1.  **Development**: Changes are pushed to the `main` branch.
2.  **laboratory Sync**: The laboratory cluster automatically reconciles the latest changes from `main`.
3.  **Verification**: Components are tested in the laboratory environment.
4.  **Release**: A new Git Tag (e.g., `v1.0.1`) is pushed.
5.  **Production Sync**: The Production cluster detects the new tag and updates itself safely.

## Secrets

Secrets are encrypted using [SOPS](https://github.com/mozilla/sops) and committed safely to the repository. Flux decrypts them inside the cluster using private keys.

## Fast-Terminal

### Bootstrap Flux
```bash
flux --version
flux check --pre

$env:GITHUB_TOKEN = "your_token"
$env:GITHUB_USER = "your_username"

flux bootstrap github `
  --owner=$env:GITHUB_USER `
  --repository=k8s-gitops `
  --branch=main `
  --path=./clusters/production `
  --personal

kubectl create secret generic sops-age `
  --namespace=flux-system `
  --from-file=age.agekey="$env:APPDATA\sops\age\keys.txt"
```

### Encrypting Secrets
```bash
sops --encrypt --in-place <.sops.yaml>
```

### Flux Debugging
```bash
flux reconcile kustomization flux-system --with-source
flux reconcile kustomization <kustomization> --with-source
flux get helmreleases -A
flux get kustomizations -A
```

### Helm Debugging
```bash
helm repo list
helm repo add <repo> <url>
helm repo remove <repo>
helm repo update
helm search repo <repo>
helm show values <repo>/<app> > <path>/values.yaml
helm uninstall <app> -n <namespace>
```

### Kubectl Debugging
```bash
kubectl delete helmrelease <name> -n <namespace>
kubectl exec -it <kind>/<name> -n <namespace> -- sh

kubectl get all -n <namespace>
kubectl get helmrelease <name> -n <namespace> -o yaml
kubectl describe helmrelease <name> -n <namespace>
kubectl get secret <name> -n <namespace> -o yaml
kubectl get deployment <name> -n <namespace> -o yaml
kubectl logs -n <namespace> deployment/<deployment> --tail=50
kubectl delete helmrelease <name> -n <namespace>

kubectl get <kind> <kind.name> -n <namespace>
kubectl describe <kind> <kind.name> -n <namespace>
kubectl logs <kind>/<kind.name> --tail=50 -n <namespace>
kubectl rollout restart <kind> <kind.name> -n <namespace>
kubectl explain <kind>
kubectl exec it pods 
``` 
