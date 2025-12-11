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
├── core/                 # Base Infrastructure (Cilium, Cert-Manager, Traefik, etc.)
├── services/             # Platform Services (Databases, Monitoring, etc.)
└── apps/                 # User Applications
```

### Environment Strategy

We use a **Cluster-centric Overlay** pattern. The `core`, `services`, and `apps` directories contain stateless "Base" definitions. The `clusters/<env>/overlays` directories act as the control panel, deciding *which* components to deploy and *how* to configure them for that specific environment.

| Feature | laboratory Cluster | Production Cluster |
| :--- | :--- | :--- |
| **Source** | Tracks `main` branch (Bleeding Edge) | Tracks Git Tags (e.g., `v1.0.0`) (Stable) |
| **Purpose** | Testing, experimentation, rapid iteration | Stable services, long-running workloads |
| **Management** | Components enabled/disabled on demand | Components strictly versioned and controlled |

## Prerequisites & Initialization

Before bootstrapping this GitOps repository, the underlying infrastructure (servers, OS, K3s, CNI) must be provisioned.

Please refer to the **[infra-provisioning](https://github.com/simplelumine/infra-provisioning)** repository for:
*   Server provisioning (Ansible)
*   K3s cluster initialization (with specific flags to disable conflicting components)
*   Base networking setup (Cilium)

## Workflow

1.  **Development**: Changes are pushed to the `main` branch.
2.  **laboratory Sync**: The laboratory cluster automatically reconciles the latest changes from `main`.
3.  **Verification**: Components are tested in the laboratory environment.
4.  **Release**: A new Git Tag (e.g., `v1.0.1`) is pushed.
5.  **Production Sync**: The Production cluster detects the new tag and updates itself safely.

## Secrets

Secrets are encrypted using [SOPS](https://github.com/mozilla/sops) and committed safely to the repository. Flux decrypts them inside the cluster using private keys.


## Fast-Terminal

```bash
flux --version
flux check --pre

export GITHUB_TOKEN=<Github_PAT_Token>
export GITHUB_USER=<Github_Username>

flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=k8s-gitops \
  --branch=main \
  --path=./clusters/laboratory \
  --personal \
  --timeout=5m

kubectl create secret generic sops-age `
  --namespace=flux-system `
  --from-file=age.agekey="$env:APPDATA\sops\age\keys.txt"

flux get kustomizations -A

sops --encrypt --in-place <path>.yaml

kubectl annotate gitrepository flux-system -n flux-system reconcile.fluxcd.io/requestedAt="now" --overwrite
kubectl annotate kustomization core -n flux-system reconcile.fluxcd.io/requestedAt="now" --overwrite

flux reconcile kustomization core -n flux-system --with-source --timeout=5m

flux get kustomization core -n flux-system
```