# K8s GitOps

我的 Kubernetes 集群配置，使用 FluxCD 进行 GitOps 管理，采用**简化的领域分层架构**。

## 🏗️ 架构设计

### 核心原则

- **配置定义与部署意图分离**：`environments/` 定义组件配置，`clusters/` 决定部署什么
- **核心基础设施与业务应用分离**：`core/` vs `apps/`
- **集群是决策层**：集群配置是 source of truth，决定该集群需要哪些组件
- **简单优先**：不使用复杂的 base/overlays 分层，直接在 environments/ 存放组件配置

### 目录结构

```text
k8s-gitops/
├── .sops.yaml                # SOPS 加密配置
├── environments/             # 配置定义层（存放组件配置，不决定部署）
│   ├── core/                 # 核心基础设施配置
│   │   └── portainer-agent/  # 每个组件一个目录
│   │       ├── namespace.yaml
│   │       ├── deployment.yaml
│   │       ├── service.yaml
│   │       └── kustomization.yaml
│   └── apps/                 # 业务应用配置
│       └── open-webui/
│
└── clusters/                 # 部署意图层（决定"部署什么"）
    ├── staging/              # Staging 集群（未来）
    └── us-west/              # 生产集群
        ├── flux-system/      # FluxCD 系统文件
        ├── kustomization.yaml
        ├── core/             # 核心组件的 FluxCD Kustomization CRDs
        │   ├── kustomization.yaml
        │   └── portainer-agent.yaml
        └── apps/             # 业务应用的 FluxCD Kustomization CRDs
            └── kustomization.yaml
```

## 🚀 工作流程

### 部署新组件（以 portainer-agent 为例）

```bash
# 1. 创建分支
git checkout -b add-portainer

# 2. 在 environments/ 定义组件配置
mkdir -p environments/core/portainer-agent
# 创建 namespace.yaml, deployment.yaml, service.yaml, kustomization.yaml

# 3. 在 clusters/us-west/core/ 创建 FluxCD Kustomization CRD
cat > clusters/us-west/core/portainer-agent.yaml <<EOF
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: portainer-agent
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./environments/core/portainer-agent
  prune: true
  wait: true
  timeout: 5m
EOF

# 4. 在 clusters/us-west/core/kustomization.yaml 引用新组件
# resources:
#   - portainer-agent.yaml

# 5. 提交 PR
git add .
git commit -m "feat: add portainer-agent to us-west cluster"
git push origin add-portainer
# 在 GitHub 创建 PR 并合并

# 6. 合并后，FluxCD 自动部署
flux get kustomizations
kubectl get pods -n portainer
```

### 集群特定配置

如果需要针对 us-west 集群的特定配置（如副本数、节点选择器），使用 FluxCD Kustomization 的 `patches` 字段：

```yaml
# clusters/us-west/core/portainer-agent.yaml
spec:
  path: ./environments/core/portainer-agent
  patches:
    - patch: |
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: portainer-agent
          namespace: portainer
        spec:
          replicas: 2  # us-west 特定：2 个副本
      target:
        kind: Deployment
        name: portainer-agent
```

## 🔐 密钥管理

使用 **SOPS + age** 加密敏感信息：

```bash
# 加密 Secret
sops --encrypt secret.yaml > secret.enc.yaml

# 提交加密文件到 Git
git add secret.enc.yaml
git commit -m "Add encrypted secret"

# FluxCD 自动解密并部署
```

## 🎯 当前状态

- ✅ 使用 FluxCD 进行 GitOps 自动化
- ✅ 简化的领域分层架构（不使用复杂的 base/overlays 结构）
- ✅ SOPS 加密配置完成
- ✅ 集群决策层设计（clusters/ 决定部署什么）
- ✅ PR 工作流程建立
- ⏳ 准备部署第一个组件
- 📚 在实践中学习 FluxCD...

## 🛠️ 常用命令

```bash
# 查看所有 Kustomization 同步状态
flux get kustomizations

# 强制同步特定组件
flux reconcile kustomization portainer-agent --with-source

# 查看组件日志
flux logs --kind=Kustomization --name=portainer-agent

# 测试配置是否正确
kubectl kustomize environments/core/portainer-agent
kubectl kustomize clusters/us-west

# 加密 Secret
sops --encrypt secret.yaml > secret.enc.yaml

# 解密查看
sops --decrypt secret.enc.yaml

# 验证 FluxCD 健康状态
flux check
```

## 📖 技术栈

- **GitOps 工具**: FluxCD v2.7.2
- **密钥管理**: SOPS + age
- **存储**: Longhorn
- **网络**: Tailscale Operator
- **证书**: cert-manager
- **数据库**: CloudNativePG, Redis Operator

## 🤝 维护

这是一个学习项目，记录了我的 Kubernetes GitOps 实践。

如果你也在学习 GitOps，欢迎参考这个仓库的结构和设计！
