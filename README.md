# K8s GitOps

我的 Kubernetes 集群配置，使用 FluxCD 进行 GitOps 管理，采用领域分层架构。

## 🏗️ 架构设计

### 核心原则
- **配置定义与部署意图分离**：`environments/` vs `clusters/`
- **基础配置与环境差异分离**：`base/` vs `overlays/`
- **核心基础设施与业务应用分离**：`core/` vs `apps/`

### 目录结构

```text
k8s-gitops/
├── .sops.yaml                # SOPS 加密配置
├── environments/             # 配置定义层（定义"是什么"）
│   ├── core/                 # 核心基础设施
│   │   ├── base/             # 环境无关的基础配置
│   │   └── overlays/         # 环境特定的差异配置
│   │       ├── staging/
│   │       └── prod/
│   └── apps/                 # 业务应用
│       ├── base/
│       └── overlays/
│           ├── staging/
│           └── prod/
│
└── clusters/                 # 部署意图层（定义"部署到哪"）
    ├── staging/              # Staging 集群配置
    │   ├── core.yaml         # FluxCD Kustomization
    │   └── apps.yaml
    └── us-west/              # 生产集群配置
        ├── flux-system/      # FluxCD 系统文件
        ├── core.yaml
        ├── apps.yaml
        ├── borrowed-staging-core.yaml    # 临时借用 staging
        └── borrowed-staging-apps.yaml
```

## 🚀 工作流程

### 部署新应用（以 portainer-agent 为例）

```bash
# 1. 定义基础配置（环境无关）
environments/core/base/portainer-agent/
├── namespace.yaml
├── serviceaccount.yaml
└── deployment.yaml

# 2. 定义 Staging 环境配置
environments/core/overlays/staging/
└── kustomization.yaml  # 引用 base 并应用补丁

# 3. 提交 PR 到 main 分支
git add . && git commit -m "Add portainer-agent"
git push origin main

# 4. FluxCD 自动部署到 staging namespace
flux get kustomizations

# 5. 验证后推广到生产
# 复制配置到 environments/core/overlays/prod/
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
- ✅ 领域分层架构已建立
- ✅ SOPS 加密配置完成
- ⏳ Staging 环境由 us-west 集群临时代理
- ⏳ 逐步迁移组件中...

## 🛠️ 常用命令

```bash
# 查看同步状态
flux get kustomizations

# 强制同步
flux reconcile kustomization core-prod

# 查看日志
flux logs --kind=Kustomization --name=core-staging

# 加密 Secret
sops --encrypt secret.yaml > secret.enc.yaml

# 解密查看
sops --decrypt secret.enc.yaml
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
