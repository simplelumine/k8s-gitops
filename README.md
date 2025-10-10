# K8s GitOps

我的 Kubernetes 集群配置，使用 ArgoCD 进行 GitOps 管理。

## 📚 文档

完整的文档请查看 **[docs/](docs/)** 目录：

- 🚀 **[部署指南](docs/DEPLOY.md)** - 从零开始部署或迁移配置
- 🏗️ **[GitOps 结构说明](docs/GITOPS-STRUCTURE.md)** - 仓库结构和设计原则
- 📁 **[目录结构示例](docs/DIRECTORY-STRUCTURE-EXAMPLES.md)** - 各种应用部署方式
- 🔐 **[Tailscale 安全说明](docs/TAILSCALE-SECURITY.md)** - 网络安全模型
- 🛠️ **[ArgoCD CLI 配置](docs/ARGOCD-CLI-SETUP.md)** - CLI 工具使用指南

更多文档请查看 **[文档索引](docs/README.md)**

## 🗂️ 仓库结构

```text
k8s-gitops/
├── docs/                              # 📚 完整文档
├── bootstrap/                         # 🔧 引导配置（手动部署）
│   ├── root-application.yaml          # Root Application 定义
│   └── repository-secret.yaml.example # Git 仓库凭证示例
├── tenants/                           # 🏢 租户配置
│   └── us-west/                       # 美西集群
│       └── cluster-infra/             # 基础设施应用
│           ├── argocd/                # ArgoCD (自管理)
│           ├── tailscale-operator/    # Tailscale Operator
│           └── longhorn/              # Longhorn 存储
└── secret/                            # 🔐 敏感信息（不提交 Git）
```

## 🚀 快速开始

### 新集群部署

```bash
# 1. 安装 ArgoCD (如果还没有)
helm install argocd argo/argo-cd -n argocd --create-namespace

# 2. 配置 Git 仓库访问（如果是私有仓库）
cp bootstrap/repository-secret.yaml.example secret/argocd-repository-secret.yaml
# 编辑 secret/argocd-repository-secret.yaml，填入 SSH 私钥
kubectl apply -f secret/argocd-repository-secret.yaml

# 3. 创建 Root Application
kubectl apply -f bootstrap/root-application.yaml

# 4. 查看部署状态
kubectl get applications -n argocd -w
```

详细步骤请查看 [部署指南](docs/DEPLOY.md)

## 🎯 主要功能

- ✅ **GitOps 自动化**: 所有配置通过 Git 管理，自动同步到集群
- ✅ **ArgoCD 自管理**: ArgoCD 通过 GitOps 管理自己
- ✅ **App of Apps 模式**: Root Application 自动发现并部署子应用
- ✅ **Tailscale 集成**: 通过 Tailscale 安全访问 ArgoCD
- ✅ **结构化配置**: 清晰的目录结构，易于维护

## 🔐 安全性

- 🔒 **私有仓库**: 使用 SSH 密钥认证
- 🔒 **Tailscale 网络**: 零信任网络，不暴露到公网
- 🔒 **Secret 管理**: 敏感信息存储在 `secret/` 目录（不提交 Git）

## 📖 学习资源

- [ArgoCD 官方文档](https://argo-cd.readthedocs.io/)
- [GitOps 原则](https://www.gitops.tech/)
- [Tailscale Kubernetes Operator](https://tailscale.com/kb/1236/kubernetes-operator/)

## 🤝 维护

这是一个学习项目，记录了我的 Kubernetes GitOps 实践。

如果你也在学习 GitOps，欢迎参考这个仓库的结构和文档！
