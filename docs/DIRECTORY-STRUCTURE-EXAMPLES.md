# GitOps 目录结构示例

## 🎯 Root Application 的 `include` 过滤器

### 问题
`include: '*/application.yaml'` 会影响子 Application 使用 manifests 目录吗？

### 答案
❌ **不会！** `include` 只影响 Root Application 的扫描行为。

---

## 📁 推荐的目录结构

### 方案 1: Application + Helm (当前方式)

```
tenants/us-west/cluster-infra/
├── argocd/
│   └── application.yaml              # Root App 扫描到 ✅
│
├── tailscale-operator/
│   └── application.yaml              # Root App 扫描到 ✅
│
└── longhorn/
    └── application.yaml              # Root App 扫描到 ✅
```

**特点：**
- ✅ 简洁，每个应用只有一个 `application.yaml`
- ✅ 使用 Helm Chart 或远程仓库
- ✅ 适合成熟的第三方应用

**argocd/application.yaml 示例：**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argocd
spec:
  source:
    repoURL: 'https://argoproj.github.io/argo-helm'
    chart: argo-cd
    targetRevision: 8.5.10
    helm:
      valuesObject:
        server:
          service:
            type: LoadBalancer
```

---

### 方案 2: Application + Manifests 目录

```
tenants/us-west/cluster-infra/
├── argocd/
│   ├── application.yaml              # Root App 扫描到 ✅
│   └── manifests/                    # Root App 忽略 ✅
│       ├── deployment.yaml           # argocd Application 会扫描 ✅
│       ├── service.yaml
│       └── configmap.yaml
│
├── my-custom-app/
│   ├── application.yaml              # Root App 扫描到 ✅
│   └── manifests/                    # Root App 忽略 ✅
│       ├── base/
│       │   ├── deployment.yaml
│       │   └── service.yaml
│       └── overlays/
│           └── prod/
│               └── kustomization.yaml
│
└── nginx-ingress/
    ├── application.yaml              # Root App 扫描到 ✅
    └── values.yaml                   # Root App 忽略 ✅
```

**特点：**
- ✅ 自定义应用的完整控制
- ✅ manifests 目录存放实际的 Kubernetes 资源
- ✅ Root App 不关心 manifests 内容

**my-custom-app/application.yaml 示例：**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-custom-app
spec:
  source:
    repoURL: 'git@github.com:SimpleLumine/k8s-gitops.git'
    targetRevision: HEAD
    path: tenants/us-west/cluster-infra/my-custom-app/manifests  # ← 指向 manifests
    directory:
      recurse: true  # ← 这个 App 会扫描 manifests 下所有文件 ✅
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: my-custom-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

---

### 方案 3: Application + Kustomize

```
tenants/us-west/cluster-infra/
├── my-app/
│   ├── application.yaml              # Root App 扫描到 ✅
│   └── kustomize/                    # Root App 忽略 ✅
│       ├── base/
│       │   ├── deployment.yaml
│       │   ├── service.yaml
│       │   └── kustomization.yaml
│       └── overlays/
│           ├── dev/
│           │   └── kustomization.yaml
│           └── prod/
│               └── kustomization.yaml
```

**my-app/application.yaml 示例：**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
spec:
  source:
    repoURL: 'git@github.com:SimpleLumine/k8s-gitops.git'
    targetRevision: HEAD
    path: tenants/us-west/cluster-infra/my-app/kustomize/overlays/prod  # ← 指向 kustomize overlay
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: my-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

### 方案 4: 混合模式（推荐）

```
tenants/us-west/cluster-infra/
├── argocd/                           # Helm Chart
│   └── application.yaml
│
├── tailscale-operator/               # Helm Chart
│   └── application.yaml
│
├── longhorn/                         # Helm Chart
│   └── application.yaml
│
├── my-backend/                       # 自定义应用 + manifests
│   ├── application.yaml
│   └── manifests/
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── configmap.yaml
│       └── ingress.yaml
│
└── monitoring/                       # Kustomize
    ├── application.yaml
    └── kustomize/
        ├── base/
        └── overlays/
```

**特点：**
- ✅ 根据应用类型选择合适的方式
- ✅ 第三方应用用 Helm
- ✅ 自定义应用用 manifests 或 kustomize
- ✅ 灵活、实用

---

## 🔍 Root Application 的扫描规则

### 当前配置

```yaml
# bootstrap/root-application.yaml
spec:
  source:
    path: tenants/us-west/cluster-infra
    directory:
      recurse: true
      include: '*/application.yaml'
```

### 扫描行为

| 文件路径 | Root App 是否扫描？ | 原因 |
|---------|-------------------|------|
| `argocd/application.yaml` | ✅ 扫描 | 匹配 `*/application.yaml` |
| `argocd/manifests/deployment.yaml` | ❌ 忽略 | 不匹配模式 |
| `argocd/manifests/application.yaml` | ❌ 忽略 | 模式是 `*/application.yaml`，不是 `**/application.yaml` |
| `argocd/values.yaml` | ❌ 忽略 | 不匹配模式 |
| `argocd/README.md` | ❌ 忽略 | 不匹配模式 |
| `my-app/application.yaml` | ✅ 扫描 | 匹配 `*/application.yaml` |
| `my-app/manifests/service.yaml` | ❌ 忽略 | 不匹配模式 |

**`*/application.yaml` 的含义：**
- `*` 匹配一层目录
- 只匹配直接子目录下的 `application.yaml`
- 不会递归匹配更深层的 `application.yaml`

---

## 🎯 最佳实践

### 1. Root Application 的职责

✅ **应该做：**
- 发现并创建子 Application
- 只扫描 `application.yaml` 文件
- 使用 `include` 过滤不相关文件

❌ **不应该做：**
- 直接管理具体的 Kubernetes 资源
- 关心 manifests 目录的内容

### 2. 子 Application 的职责

✅ **应该做：**
- 管理具体的 Kubernetes 资源
- 自己决定如何部署（Helm/Kustomize/Plain YAML）
- 指定自己的 source.path

❌ **不应该做：**
- 依赖 Root App 的配置

### 3. 目录命名约定

推荐的命名：
- ✅ `application.yaml` - Application 定义（Root App 扫描）
- ✅ `manifests/` - Kubernetes 资源清单
- ✅ `kustomize/` - Kustomize 配置
- ✅ `values.yaml` - Helm values（可选）
- ✅ `README.md` - 文档

避免的命名：
- ❌ `app.yaml` - 不会被 Root App 扫描到
- ❌ `application-prod.yaml` - 不会被扫描到（除非修改 include 模式）

---

## 📝 完整示例

### 示例应用：自定义的 Web 应用

**目录结构：**
```
tenants/us-west/cluster-infra/my-web-app/
├── application.yaml              # Application 定义
├── README.md                     # 文档
└── manifests/                    # Kubernetes 资源
    ├── namespace.yaml
    ├── deployment.yaml
    ├── service.yaml
    ├── ingress.yaml
    └── configmap.yaml
```

**application.yaml：**
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-web-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: 'git@github.com:SimpleLumine/k8s-gitops.git'
    targetRevision: HEAD
    path: tenants/us-west/cluster-infra/my-web-app/manifests  # ← 指向 manifests
    directory:
      recurse: true  # ← 扫描 manifests 下所有 YAML
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: my-web-app  # ← 部署到专门的 namespace
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

**工作流程：**
1. Root App 扫描 `tenants/us-west/cluster-infra/my-web-app/application.yaml` ✅
2. Root App 创建 `my-web-app` Application ✅
3. `my-web-app` Application 扫描 `manifests/` 目录 ✅
4. 部署 namespace, deployment, service, ingress, configmap ✅

**Root App 的 `include` 不影响第 3 步！** ✅

---

## ✅ 结论

### 回答你的问题

**Q: `include: '*/application.yaml'` 会影响 manifests 目录吗？**

**A: 不会！**

- ✅ `include` 只影响 Root Application 的扫描
- ✅ 子 Application 可以自由使用 `manifests/` 目录
- ✅ 子 Application 自己决定扫描哪些文件
- ✅ 这是正确的分层设计

### 推荐配置

```yaml
# Root Application - 保持这个配置 ✅
spec:
  source:
    path: tenants/us-west/cluster-infra
    directory:
      recurse: true
      include: '*/application.yaml'  # ← 只扫描 Application 定义
```

这个配置：
- ✅ 清晰明确
- ✅ 避免扫描无关文件
- ✅ 不影响子 Application 的功能
- ✅ 符合 GitOps 最佳实践
