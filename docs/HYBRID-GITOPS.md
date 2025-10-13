# ArgoCD + FluxCD 混合部署策略

本文档说明如何在同一个集群中同时使用 ArgoCD 和 FluxCD，实现渐进式迁移。

## 架构设计

```
k8s-gitops/
├── bootstrap/
│   └── root-us-west.yaml          # ArgoCD Application (管理 cluster-infra)
├── clusters/
│   └── us-west/
│       ├── flux-system/           # FluxCD bootstrap 文件
│       ├── infrastructure.yaml    # FluxCD Kustomization (可选，未来迁移用)
│       └── apps.yaml              # FluxCD Kustomization (管理 apps)
├── tenants/us-west/
│   ├── cluster-infra/             # ← ArgoCD 管理
│   │   ├── argocd/
│   │   ├── cert-manager/
│   │   ├── sealed-secrets/
│   │   └── ...
│   └── apps/                      # ← FluxCD 管理
│       └── litellm/
```

## 部署顺序

### 阶段 1: 保持现状 (ArgoCD Only)
✅ ArgoCD 继续管理所有基础设施
- Sealed Secrets
- cert-manager
- Longhorn
- CloudNativePG
- Redis Operator
- Tailscale

### 阶段 2: 引入 FluxCD (混合模式)
1. 安装 FluxCD 到集群
2. 配置 FluxCD 只管理 `tenants/us-west/apps/`
3. ArgoCD 继续管理 `tenants/us-west/cluster-infra/`

### 阶段 3: 逐步迁移 (可选)
根据需要，逐步将基础设施从 ArgoCD 迁移到 FluxCD

## 配置示例

### ArgoCD 配置 (保持不变)

`bootstrap/root-us-west.yaml`:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-us-west
  namespace: argocd
spec:
  destination:
    namespace: argocd
    server: https://kubernetes.default.svc
  project: default
  source:
    directory:
      jsonnet: {}
      recurse: true
      include: '**/application.yaml'
      exclude: '**/manifests/**'
    path: tenants/us-west/cluster-infra    # 只管理 cluster-infra
    repoURL: git@github.com:SimpleLumine/k8s-gitops.git
    targetRevision: HEAD
  syncPolicy:
    automated:
      enabled: true
      prune: true
      selfHeal: true
```

### FluxCD 配置 (新增)

`clusters/us-west/apps.yaml`:
```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: apps
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./tenants/us-west/apps    # 只管理 apps
  prune: true
  wait: false
```

## 优势

### ✅ 风险低
- 基础设施（ArgoCD）保持稳定
- 应用层（FluxCD）逐步试验

### ✅ 各司其职
- ArgoCD: 擅长管理基础设施，UI 直观
- FluxCD: 擅长应用部署，依赖管理强大

### ✅ 灵活迁移
- 可以随时将组件从 ArgoCD 迁移到 FluxCD
- 迁移过程无需停机

## 共存注意事项

### 1. 避免资源冲突

确保 ArgoCD 和 FluxCD 不管理相同的资源：

```yaml
# ArgoCD 管理的路径
path: tenants/us-west/cluster-infra

# FluxCD 管理的路径
path: tenants/us-west/apps
```

### 2. Namespace 隔离

- ArgoCD 运行在 `argocd` namespace
- FluxCD 运行在 `flux-system` namespace
- 互不干扰

### 3. Git 仓库访问

两者可以共享同一个 Git 仓库（你的 k8s-gitops），各自管理不同的路径。

### 4. Sealed Secrets 共享

Sealed Secrets 由 ArgoCD 管理安装，但两者都可以使用：

```bash
# FluxCD 管理的应用也可以使用 SealedSecret
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: my-secret
  namespace: ai-gateway  # FluxCD 管理的 namespace
```

## 迁移路径 (未来可选)

如果将来想完全迁移到 FluxCD：

### 第 1 步: 迁移 Sealed Secrets
```yaml
# clusters/us-west/infrastructure/sealed-secrets.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: sealed-secrets
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./tenants/us-west/cluster-infra/sealed-secrets
  prune: true
```

### 第 2 步: 迁移 cert-manager
类似上面，创建对应的 Kustomization

### 第 3 步: 迁移其他组件
逐个迁移，验证稳定后继续

### 第 4 步: 卸载 ArgoCD (可选)
当所有组件都迁移完成后，可以选择卸载 ArgoCD

## 监控两套系统

### ArgoCD
```bash
# 查看 ArgoCD 管理的应用
kubectl get applications -n argocd

# ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# 访问 https://localhost:8080
```

### FluxCD
```bash
# 查看 FluxCD 管理的 Kustomizations
flux get kustomizations -A

# 查看实时同步状态
flux get kustomizations --watch

# 查看日志
flux logs --level=info
```

## 故障隔离

如果 FluxCD 出现问题：
- ArgoCD 管理的基础设施不受影响
- 可以快速回滚或禁用 FluxCD

如果 ArgoCD 出现问题：
- FluxCD 管理的应用不受影响
- 基础设施可以手动管理或迁移到 FluxCD

## 总结

这种混合模式允许你：

1. ✅ 保持现有的稳定基础设施（ArgoCD）
2. ✅ 尝试新的应用部署方式（FluxCD）
3. ✅ 逐步学习和迁移，无需一次性切换
4. ✅ 充分利用两者的优势

**推荐策略**:
- 短期：ArgoCD (infra) + FluxCD (apps)
- 长期：根据使用体验决定是否完全迁移到 FluxCD
