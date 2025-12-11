# Architecture Decision Record: Cilium Configuration & GitOps Structure

**Date:** 2025-12-11
**Status:** Accepted
**Context:** Refactoring Cilium configuration in the Laboratory cluster to resolve SOPS validation errors and establish a scalable GitOps pattern.

## 1. The Problem

We encountered a validation error when attempting to update Cilium in the `laboratory` cluster.

- **Error:** `HelmRelease/kube-system/cilium dry-run failed... .sops: field not declared in schema`.
- **Root Cause:** The original configuration used a SOPS-encrypted file (`cilium-patch.sops.yaml`) directly as a Kustomize patch. When applied, the SOPS metadata (`.sops` field) was merged into the `HelmRelease` object. Since the `HelmRelease` CRD schema does not define a `sops` field, Kubernetes rejected the resource.

## 2. Solution Evolution

### Phase 1: The Fix (Secret Injection)

We moved away from "Patching with Encrypted Data" to the standard "Secret Injection" pattern.

- **Why:** `HelmRelease` supports `valuesFrom` to read from Kubernetes Secrets. This avoids polluting the `HelmRelease` object with SOPS metadata.
- **Mechanism:**
  1.  Create a `Secret` resource containing the sensitive data (IPs, Tokens).
  2.  Use a `Patch` to update the `HelmRelease` to reference this Secret via `spec.valuesFrom`.

### Phase 2: Auditability (Granular Encryption)

We discussed how to encrypt the `Secret`.

- **Initial Approach:** Encrypt the entire `stringData` or a monolithic `values.yaml` key.
- **Refinement:** The user suggested (correctly) that we should only encrypt the _values_ of specific keys (`k8sServiceHost`, `k8sServicePort`), leaving the _keys_ visible.
- **Outcome:** Improved `.sops.yaml` regex rules to target specific fields. This significantly improves auditability in Git—we can see _what_ changed, even if we can't see the _value_.

## 3. The Grand Architectural Debate

The most significant discussion revolved around the directory structure for `overlays`. How do we organize Secrets, Patches, and Resources without creating a mess?

### Option A: The "Wrapper/Component" Pattern (Hyper-Encapsulation)

- **Structure:** Create a folder for every component (e.g., `overlays/core/cilium/`). Put `kustomization.yaml`, `secret.sops.yaml`, and `patch.yaml` all inside it.
- **Pros:** High cohesion. Everything related to Cilium is in one folder.
- **Cons:** High fragmentation. To see "what is deployed in Lab", you have to traverse many folders. Requires creating a `kustomization.yaml` for every single component override.
- **User Feedback:** Felt "fragmented" and "complicated" for simple changes. "Do I really need a folder just to change a replica count?"

### Option B: The "Flat & Organized" Pattern (Selected)

- **Structure:** Keep a single `kustomization.yaml` in `overlays/core/`. Use dedicated subdirectories for resource types.
- **Layout:**
  ```text
  clusters/laboratory/overlays/core/
  ├── kustomization.yaml         <-- The Assembly Line (Single Pane of Glass)
  ├── secrets/                   <-- Warehouse for ALL secrets
  │   └── cilium-secret.sops.yaml
  └── patches/                   <-- Warehouse for ALL configs/patches
      └── cilium.yaml
  ```
- **Pros:**
  - **Visibility:** One file (`kustomization.yaml`) lists the entire inventory of the environment.
  - **Simplicity:** No need to create new folders/kustomizations for simple patches.
  - **Clarity:** Separates "Data" (Secrets) from "Logic" (Patches).

## 4. Final Implementation Details

### File Roles

- **`core/cilium/helmrelease.yaml` (Base):** The pure component definition. No environmental pollution.
- **`overlays/.../secrets/cilium-secret.sops.yaml`:** The "Noun". Contains sensitive data using SOPS.
- **`overlays/.../patches/cilium.yaml`:** The "Verb".
  - Links the Secret (`valuesFrom`).
  - Applies cleartext config (`values.hubble.enabled: true`).
  - Acts as the single source of truth for Laboratory-specific Cilium configuration.

### Deployment Safety

We confirmed that updating Base or adding Patches triggers a standard Helm Upgrade (Diff -> Apply) by Flux, ensuring safety and zero-downtime (no unnecessary uninstall/reinstall).

## 5. Conclusion

We adopted the **Flat & Organized** structure. It offers the best balance of organization and simplicity for the current scale, avoiding the overhead of the Wrapper pattern while preventing the chaos of a completely flat directory.
