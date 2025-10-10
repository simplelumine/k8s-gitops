# GitOps 仓库结构说明

## 📁 当前目录结构

```
k8s-gitops/
├── bootstrap/                              # 🔧 引导目录（手动管理）
│   ├── root-application.yaml              # Root App 定义
│   ├── repository-secret.yaml.example     # Git 凭证示例
│   └── README.md                          # 引导步骤说明
│
├── tenants/                                # 🏢 租户目录
│   └── us-west/                           # 美西集群
│       ├── cluster-infra/                 # 基础设施应用
│       │   ├── argocd/
│       │   │   └── application.yaml      # ArgoCD 自管理
│       │   ├── tailscale-operator/
│       │   │   └── application.yaml
│       │   └── longhorn/
│       │       └── application.yaml
│       │
│       └── sillytavern/                   # 业务应用（考虑移到 applications/ 下）
│
├── .gitignore                             # Git 忽略规则
└── README.md                              # 项目说明
```

## 🎯 设计原则

### 1. Bootstrap 原则
- **Bootstrap 目录不由 ArgoCD 管理**
- 包含"鸡生蛋"问题的解决方案
- 需要手动 `kubectl apply` 来启动整个 GitOps 流程

### 2. 分层管理
```
Bootstrap Layer (手动)
    ↓
Root Application (ArgoCD 自动)
    ↓
Infrastructure Apps + Business Apps (ArgoCD 自动)
```

### 3. 目录命名规范
- `cluster-infra/`: 集群级别的基础设施（存储、网络、监控等）
- `applications/`: 业务应用
- `bootstrap/`: 引导配置（不在 ArgoCD 管理范围内）

## 🚀 工作流程

### 初始化流程（首次部署）

```bash
# 1. 安装 ArgoCD（如果还没有）
helm install argocd argo/argo-cd -n argocd --create-namespace

# 2. 配置 Git 仓库访问
cp bootstrap/repository-secret.yaml.example bootstrap/repository-secret.yaml
vim bootstrap/repository-secret.yaml  # 填入 SSH 私钥
kubectl apply -f bootstrap/repository-secret.yaml

# 3. 创建 Root Application
kubectl apply -f bootstrap/root-application.yaml

# 4. 验证
kubectl get applications -n argocd
```

### 日常开发流程

```bash
# 1. 创建新的应用
mkdir -p tenants/us-west/cluster-infra/new-app
vim tenants/us-west/cluster-infra/new-app/application.yaml

# 2. 提交到 Git
git add .
git commit -m "feat: add new-app"
git push

# 3. 等待 ArgoCD 自动同步（3分钟内）
# 或手动触发同步
kubectl patch application root-us-west -n argocd \
  --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'
```

## 🔐 安全最佳实践

### Git 凭证管理

**当前方案**: Kubernetes Secret
```yaml
# bootstrap/repository-secret.yaml (不提交到 Git)
apiVersion: v1
kind: Secret
metadata:
  name: k8s-gitops-repo
  namespace: argocd
stringData:
  sshPrivateKey: |
    -----BEGIN OPENSSH PRIVATE KEY-----
    ...
    -----END OPENSSH PRIVATE KEY-----
```

**推荐升级方案**:
1. **Sealed Secrets**: 加密的 Secret 可以安全提交到 Git
2. **External Secrets Operator**: 从外部密钥管理系统（Vault, AWS Secrets Manager）读取
3. **ArgoCD Vault Plugin**: 直接集成 Vault

### 敏感信息保护

`.gitignore` 中已配置：
```
**/repository-secret.yaml
**/*-secret.yaml
!**/*-secret.yaml.example
```

## 📊 App of Apps 模式

### 当前实现

```yaml
# bootstrap/root-application.yaml
spec:
  source:
    path: tenants/us-west/cluster-infra
    directory:
      recurse: true
      include: '*/application.yaml'
```

这个配置会：
- ✅ 递归扫描 `cluster-infra` 目录
- ✅ 只包含名为 `application.yaml` 的文件
- ✅ 自动发现新的应用
- ✅ 自动同步变更

### 推荐的改进（可选）

可以创建多个 Root Applications：

```
bootstrap/
├── root-infrastructure.yaml    # 管理基础设施
└── root-applications.yaml      # 管理业务应用
```

这样可以：
- 分离基础设施和业务应用的生命周期
- 不同的同步策略
- 更细粒度的权限控制

## 🔄 迁移建议

### 短期（当前结构）
保持现有的 `cluster-infra` 结构，已经很好了！

### 中期建议
```
tenants/us-west/
├── infrastructure/              # 基础设施
│   ├── argocd/
│   ├── tailscale-operator/
│   └── longhorn/
└── applications/                # 业务应用
    └── sillytavern/
```

### 长期建议（多集群）
```
clusters/
├── us-west-prod/
│   ├── infrastructure/
│   └── applications/
├── us-east-prod/
│   ├── infrastructure/
│   └── applications/
└── dev/
    ├── infrastructure/
    └── applications/
```

## 🎓 学习资源

- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [GitOps Principles](https://www.gitops.tech/)

## ❓ 常见问题

### Q: 为什么 bootstrap 目录不由 ArgoCD 管理？
A: 这是"鸡生蛋"问题。ArgoCD 需要先知道 Root Application 存在，才能开始管理其他资源。

### Q: 如何更新 Root Application？
A: 编辑 `bootstrap/root-application.yaml`，然后 `kubectl apply -f bootstrap/root-application.yaml`

### Q: 如何备份配置？
A: 所有配置都在 Git 中，除了：
- SSH 私钥（需要单独备份）
- ArgoCD 初始密码（存储在集群的 Secret 中）

### Q: 多个开发者如何协作？
A:
1. 每个开发者配置自己的 Git SSH 密钥
2. 通过 PR 审查变更
3. 合并后自动部署到集群
