# k8s-gitops

**Production-Grade GitOps Repository powered by Flux v2.**

## 🏗 Architecture

This repository follows a structured **GitOps** workflow to manage Kubernetes clusters. It uses a **Multi-Layer Kustomization** strategy to ensure dependencies are deployed in the correct order.

### Directory Structure

```text
.
├── clusters/             # Cluster Entrypoints (Flux Bootstrap)
│   └── production/       # Production Enviroment
│       └── flux-sync/    # GitOps Control Plane (Kustomizations)
├── system/               # Layer 0: System Infrastructure (CNI, Ingress, Cert-Manager)
├── datastores/           # Layer 1: Stateful Services (Redis, Postgres, etc.)
├── platform/             # Layer 2: Platform Services (Monitoring, Auth, etc.)
└── workloads/            # Layer 3: User Applications (Lumine, DeepSeek, etc.)
```

### Dependency Chain

We use Flux `dependsOn` to enforce startup order, preventing "CrashLoopBackOff" caused by missing dependencies.

1.  **System** (`system/`): Core capabilities. _No dependencies._
2.  **Datastores** (`datastores/`): Databases & Queues. _Depends on System._
3.  **Platform** (`platform/`): Shared middleware. _Depends on Datastores._
4.  **Workloads** (`workloads/`): Business logic. _Depends on Platform & Datastores._

### Secret Management

Secrets are encrypted using **SOPS (Age)**.

- **Encrypted**: `.secret.yaml` files committed to Git.
- **Decrypted**: By Flux controller inside the cluster using private keys.

---

## ⚡ Fast-Terminal / Cheat Sheet

A quick reference guide for managing this specific GitOps setup.
**Environment**: Windows (PowerShell)

### 1. Bootstrap Cluster

Initialize Flux on a new cluster.

```powershell
# 1. Pre-flight check
flux --version
flux check --pre

# 2. Set Credentials
$env:GITHUB_TOKEN = "ghp_your_token_here"
$env:GITHUB_USER = "simplelumine"

# 3. Bootstrap (Installing Flux Components)
flux bootstrap github `
  --owner=$env:GITHUB_USER `
  --repository=k8s-gitops `
  --branch=main `
  --path=./clusters/production `
  --personal

# 4. Inject SOPS Private Key (Required for Secret Decryption)
kubectl create secret generic sops-age `
  --namespace=flux-system `
  --from-file=age.agekey="$env:APPDATA\sops\age\keys.txt"
```

### 2. Secret Management (SOPS)

Encrypt secrets before committing.

```powershell
# Encrypt existing file in-place
sops --encrypt --in-place litellm-secret.yaml

# Decrypt existing file in-place
sops --decrypt --in-place litellm-secret.yaml

# Verify encryption (Check for "sops" metadata block)
cat litellm-secret.yaml
```

### 3. Debugging Flux

Force syncs and check reconciliation status.

```powershell
# Reconcile the Core System
flux reconcile kustomization flux-system --with-source

# Reconcile specific layers (e.g., if workloads are stuck)
flux reconcile kustomization workloads --with-source

# Reconcile 
flux reconcile helmrelease victoria-metrics -n monitoring --force

# View all installed releases
flux get helmreleases -A
flux get kustomizations -A

# Check for specific reconciliation errors
flux logs --level=error
```

### 4. Debugging Helm

Directly inspect charts managed by HelmController.

```powershell
# Search for charts
helm repo add bitnami https://charts.bitnami.com/bitnami
helm search repo redis

# Inspect values (Crucial for debugging "HelmChartConfig")
helm show values bitnami/redis > ./temp-values.yaml

# Uninstall a stuck release (Flux will reinstall it on next sync)
helm uninstall <release-name> -n <namespace>
```

### 5. Kubectl Operations

Low-level cluster interaction.

```powershell
# --- View Resources ---
kubectl get all -n litellm
kubectl get helmrelease -n litellm
kubectl get pod -o wide -n litellm

# --- Inspect Details ---
# Why is my pod pending?
kubectl describe pod <pod-name> -n <namespace>
# Why is the HelmRelease failing?
kubectl describe helmrelease <release-name> -n <namespace>

# --- Logs ---
kubectl logs -f deployment/<deployment-name> -n <namespace>
kubectl logs -f -l app=<label> -n <namespace> --tail=100

# --- Interactive Shell (Debug inside pod) ---
# Syntax: kubectl exec -it <pod> -n <ns> -- <cmd>
kubectl exec -it <pod-name> -n <namespace> -- sh

# --- Restart Workloads ---
kubectl rollout restart deployment <deployment-name> -n <namespace>

# --- Clean Up ---
# Force delete a stuck namespace (Use with caution)
kubectl delete namespace <namespace> --grace-period=0 --force
```
