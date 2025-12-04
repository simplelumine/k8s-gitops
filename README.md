# k8s-gitops

Declarative Kubernetes cluster management. A GitOps repository powered by Flux to reconcile the platform and applications.

## Architecture

This repository uses a layered GitOps architecture to manage multiple environments (Sandbox & Production) from a single source of truth.

> 📖 **Deep Dive**: For a detailed explanation of the design philosophy, resource management strategy, and architectural layers, please read [ARCHITECTURE.md](docs/ARCHITECTURE.md).

### Directory Structure

```text
.
├── clusters/             # Cluster definitions (The "Control Plane")
│   ├── production/       # Production environment (Tracks Tags)
│   │   └── overlays/     # Production-specific component selection & patches
│   └── sandbox/          # Sandbox environment (Tracks Main)
│       └── overlays/     # Sandbox-specific component selection & patches
├── core/                 # Base Infrastructure (Cilium, Cert-Manager, Traefik, etc.)
├── services/             # Platform Services (Databases, Monitoring, etc.)
└── apps/                 # User Applications
```

### Environment Strategy

We use a **Cluster-centric Overlay** pattern. The `core`, `services`, and `apps` directories contain stateless "Base" definitions. The `clusters/<env>/overlays` directories act as the control panel, deciding *which* components to deploy and *how* to configure them for that specific environment.

| Feature | Sandbox Cluster | Production Cluster |
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
2.  **Sandbox Sync**: The Sandbox cluster automatically reconciles the latest changes from `main`.
3.  **Verification**: Components are tested in the Sandbox environment.
4.  **Release**: A new Git Tag (e.g., `v1.0.1`) is pushed.
5.  **Production Sync**: The Production cluster detects the new tag and updates itself safely.

## Secrets

Secrets are encrypted using [SOPS](https://github.com/mozilla/sops) and committed safely to the repository. Flux decrypts them inside the cluster using private keys.