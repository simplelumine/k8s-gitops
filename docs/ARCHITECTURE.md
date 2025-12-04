# Architectural Philosophy & Design Principles

## Core Principles

- **Declarative:** All configurations are defined as code in this repository.
- **Versioned and Immutable:** Git's version history provides a complete, auditable trail of all changes.
- **Automated:** CI/CD pipelines automate the validation and deployment of changes.
- **Continuous Reconciliation:** A GitOps operator (like Flux CD) ensures the cluster state always matches the configuration in Git.

## Layered Architecture

This repository follows a layered and modular architectural approach, designed for clarity, scalability, and security.

- **`core/` (The Foundation):** This layer contains the operators and controllers that extend Kubernetes itself. This is the stable, rarely-touched bedrock of the platform (e.g., `cert-manager`, `longhorn`).
- **`services/` (The Platform Layer):** This layer contains the instances and deployments created *by* the `core` operators or that provide shared functionality. These are the consumable, often stateful, and swappable components that support your applications (e.g., a PostgreSQL cluster, Prometheus for monitoring).
- **`apps/` (The Application Layer):** This layer contains the final, user-facing applications.

This separation allows for clear dependency management and isolates the foundational components from the more dynamic application and service layers.

## Namespace and Resource Management Strategy

This repository adopts a **one-namespace-per-component** strategy. While GitOps tools like Flux simplify cleanup, the primary reasons for this strategy are security, isolation, and control during runtime.

- **Security:** Dedicated namespaces are the foundation for `NetworkPolicy` rules, creating a firewall between components and enforcing a zero-trust model.
- **Access Control (RBAC):** Permissions can be scoped to a specific namespace, enforcing the principle of least privilege.
- **Clarity:** This approach provides a clean separation of resources, making it easier to manage and troubleshoot individual components.

Each component in the `core`, `services`, and `apps` directories will have its own namespace defined within its folder, which Flux will manage automatically.

### Pod `limits` vs. Namespace `ResourceQuota`

A key concept in this architecture is the complementary relationship between pod-level resource limits and namespace-level resource quotas.

- **Pod `requests` and `limits`** are set on individual deployments to define the resource needs and containment for a single instance of an application.
- **Namespace `ResourceQuota`** acts as a higher-level administrative budget for the entire namespace. It limits the *sum total* of resources that all pods within that namespace can consume.

This is crucial in a declarative, multi-replica environment. While a pod's `limit` might be small, a change in a Git commit that increases the `replicas` count could lead to a massive aggregate resource request. The `ResourceQuota` serves as a vital safety rail, preventing a single namespace from accidentally starving the entire cluster by exceeding its allocated budget. This ensures that scalability does not come at the cost of platform stability.
