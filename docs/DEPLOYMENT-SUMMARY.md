# K8s GitOps Deployment Summary

本文档总结了整个 GitOps 部署的配置和使用方法。

## 📁 项目结构

```
k8s-gitops/
├── bootstrap/
│   ├── root-us-west.yaml          # ArgoCD: 管理 cluster-infra
│   └── root-apps.yaml             # ArgoCD: 原有 apps 配置(已弃用)
│
├── clusters/us-west/
│   ├── flux-system/               # FluxCD bootstrap (自动创建)
│   └── apps.yaml                  # FluxCD: 管理 apps 入口
│
├── tenants/us-west/
│   ├── cluster-infra/             # ← ArgoCD 管理
│   │   ├── argocd/
│   │   ├── sealed-secrets/
│   │   ├── cert-manager/
│   │   ├── cloudnative-pg/
│   │   ├── redis-operator/
│   │   ├── longhorn/
│   │   └── tailscale-operator/
│   │
│   └── apps/                      # ← FluxCD 管理
│       └── litellm/
│           ├── QUICKSTART.md           # 快速开始指南
│           ├── FLUXCD-DEPLOYMENT.md    # 详细部署文档
│           ├── README.md               # 架构说明
│           │
│           ├── database/
│           │   ├── kustomization-flux.yaml
│           │   └── manifests/
│           │       ├── kustomization.yaml
│           │       └── postgres-cluster.yaml
│           │
│           ├── cache/
│           │   ├── kustomization-flux.yaml  # dependsOn: database
│           │   └── manifests/
│           │       ├── kustomization.yaml
│           │       └── redis.yaml
│           │
│           └── app/
│               ├── kustomization-flux.yaml  # dependsOn: cache
│               └── manifests/
│                   ├── kustomization.yaml
│                   ├── litellm-config.yaml
│                   └── litellm-deployment.yaml
│
├── secret/                        # Secret 模板(本地使用)
│   ├── litellm-postgres-credentials.yaml
│   ├── litellm-redis-credentials.yaml
│   ├── litellm-app-secret.yaml
│   └── litellm-vertex-credentials.yaml
│
├── docs/
│   ├── FLUXCD-SETUP.md           # FluxCD 安装指南
│   ├── FLUXCD-SCOOP.md           # Scoop 安装和多设备使用
│   ├── HYBRID-GITOPS.md          # ArgoCD + FluxCD 混合部署
│   └── ...
│
└── scripts/
    └── setup-dev-env.ps1         # 自动化环境设置脚本
```

## 🎯 架构设计

### 混合 GitOps 模式

```
┌─────────────────────────────────────────────┐
│           Kubernetes Cluster                │
├─────────────────────────────────────────────┤
│                                             │
│  ┌──────────────┐      ┌─────────────────┐ │
│  │   ArgoCD     │      │    FluxCD       │ │
│  │  (namespace: │      │  (namespace:    │ │
│  │   argocd)    │      │   flux-system)  │ │
│  └──────┬───────┘      └────────┬────────┘ │
│         │                       │          │
│         │                       │          │
│  ┌──────▼────────┐      ┌───────▼────────┐ │
│  │ cluster-infra │      │     apps       │ │
│  │               │      │                │ │
│  │ - sealed-     │      │ - litellm      │ │
│  │   secrets     │      │   (database)   │ │
│  │ - cert-       │      │   (cache)      │ │
│  │   manager     │      │   (app)        │ │
│  │ - operators   │      │                │ │
│  └───────────────┘      └────────────────┘ │
│                                             │
└─────────────────────────────────────────────┘
```

### LiteLLM 部署流程 (FluxCD)

```
FluxCD GitRepository (flux-system)
  │
  ├─> apps (Kustomization)
  │   └─> 监控: tenants/us-west/apps/
  │
  ├─> litellm-database (Kustomization)
  │   ├─ Namespace: database
  │   ├─ 部署: PostgreSQL (CloudNativePG)
  │   └─ 健康检查: Cluster/litellm-postgres
  │
  ├─> litellm-cache (Kustomization)
  │   ├─ 依赖: litellm-database ✓
  │   ├─ Namespace: cache
  │   ├─ 部署: Redis (Redis Operator)
  │   └─ 健康检查: Redis/litellm-redis
  │
  └─> litellm-app (Kustomization)
      ├─ 依赖: litellm-database ✓ + litellm-cache ✓
      ├─ Namespace: ai-gateway
      ├─ 部署: LiteLLM (Deployment)
      └─ 健康检查: Deployment/litellm
```

## 🚀 部署指南

### 首次部署

#### 1. 安装 FluxCD
```bash
# 参考 docs/FLUXCD-SETUP.md
scoop install flux
flux bootstrap github --token-auth --owner=SimpleLumine --repository=k8s-gitops --branch=main --path=./clusters/us-west --personal
```

#### 2. 创建 Sealed Secrets
```bash
# 参考 tenants/us-west/apps/litellm/QUICKSTART.md
cd secret/
# 创建所有 secrets...
```

#### 3. 应用 FluxCD Kustomization
```bash
kubectl apply -f clusters/us-west/apps.yaml
```

#### 4. 监控部署
```bash
flux get kustomizations --watch
```

### 在新电脑上工作

```bash
# 1. 运行自动设置脚本
git clone git@github.com:SimpleLumine/k8s-gitops.git
cd k8s-gitops
.\scripts\setup-dev-env.ps1

# 2. 配置 kubeconfig (从其他电脑复制)

# 3. 验证连接
flux check
kubectl get nodes
```

## 📚 文档导航

### 快速入门
- **[QUICKSTART.md](tenants/us-west/apps/litellm/QUICKSTART.md)** - LiteLLM 5分钟快速部署

### FluxCD
- **[FLUXCD-SETUP.md](docs/FLUXCD-SETUP.md)** - FluxCD 安装和配置
- **[FLUXCD-SCOOP.md](docs/FLUXCD-SCOOP.md)** - 使用 Scoop 管理工具
- **[FLUXCD-DEPLOYMENT.md](tenants/us-west/apps/litellm/FLUXCD-DEPLOYMENT.md)** - LiteLLM 详细部署

### 架构
- **[HYBRID-GITOPS.md](docs/HYBRID-GITOPS.md)** - ArgoCD + FluxCD 混合架构
- **[README.md](tenants/us-west/apps/litellm/README.md)** - LiteLLM 架构说明

## 🔧 常用命令

### FluxCD

```bash
# 查看状态
flux get all -A
flux get kustomizations --watch

# 手动同步
flux reconcile kustomization apps --with-source

# 查看日志
flux logs --all-namespaces --follow
flux logs --level=error

# 暂停/恢复
flux suspend kustomization litellm-app
flux resume kustomization litellm-app
```

### ArgoCD

```bash
# 查看应用
kubectl get applications -n argocd

# 手动同步
argocd app sync root-us-west

# 访问 UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# https://localhost:8080
```

### Kubernetes

```bash
# 查看所有 namespaces
kubectl get pods -A

# LiteLLM 组件
kubectl get pods -n database
kubectl get pods -n cache
kubectl get pods -n ai-gateway

# 查看日志
kubectl logs -n ai-gateway deployment/litellm --tail=100 -f
```

### Sealed Secrets

```bash
# 获取公钥
kubeseal --fetch-cert --controller-namespace=sealed-secrets > pub-sealed-secrets.pem

# 查看 sealed secrets
kubectl get sealedsecrets -A

# 加密 secret
kubectl create secret generic my-secret \
  --from-literal=key=value \
  --namespace=my-namespace \
  --dry-run=client -o yaml | \
  kubeseal --format=yaml --cert=pub-sealed-secrets.pem
```

## 🎓 学习路径

### 如果你是新手

1. 阅读 [FLUXCD-SETUP.md](docs/FLUXCD-SETUP.md)
2. 运行 `setup-dev-env.ps1` 安装工具
3. 完成 FluxCD bootstrap
4. 按照 [QUICKSTART.md](tenants/us-west/apps/litellm/QUICKSTART.md) 部署 LiteLLM
5. 学习 [HYBRID-GITOPS.md](docs/HYBRID-GITOPS.md) 理解架构

### 如果你有经验

1. 查看项目结构（本文档顶部）
2. 直接阅读 [FLUXCD-DEPLOYMENT.md](tenants/us-west/apps/litellm/FLUXCD-DEPLOYMENT.md)
3. 创建 secrets 并部署

## 🔐 安全最佳实践

1. ✅ **永远不要提交明文 secrets**
   - 使用 Sealed Secrets
   - secret/ 目录已在 .gitignore 中

2. ✅ **定期轮换密钥**
   - 更新 secret 模板
   - 重新加密并提交

3. ✅ **使用强密码**
   - 数据库密码至少 16 位
   - API keys 使用官方生成的

4. ✅ **限制访问权限**
   - kubeconfig 权限控制
   - GitHub token 最小权限

## 🆘 故障排查

### FluxCD 无法同步

```bash
# 检查 GitRepository
flux get sources git
kubectl describe gitrepository flux-system -n flux-system

# 检查认证
kubectl get secret -n flux-system flux-system
```

### Kustomization 失败

```bash
# 查看详细错误
kubectl describe kustomization <name> -n flux-system

# 查看日志
flux logs --kind=Kustomization --name=<name>
```

### Sealed Secret 解密失败

```bash
# 检查 controller
kubectl get pods -n sealed-secrets
kubectl logs -n sealed-secrets deployment/sealed-secrets-controller

# 检查 sealed secret
kubectl get sealedsecret <name> -n <namespace> -o yaml
```

### 应用启动失败

```bash
# 查看 Pod 状态
kubectl get pods -n <namespace>
kubectl describe pod <pod-name> -n <namespace>

# 查看日志
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous
```

## 📊 监控和可观测性

### 查看部署状态

```bash
# FluxCD 整体状态
flux check

# 所有 Kustomizations
flux get kustomizations -A

# 所有资源
flux get all -A
```

### 实时监控

```bash
# 使用 k9s (推荐)
k9s

# 使用 watch
watch -n 2 kubectl get pods -A
```

### 日志聚合

```bash
# FluxCD 日志
flux logs --all-namespaces --follow --since=10m

# 特定应用日志
kubectl logs -n ai-gateway -l app=litellm --tail=100 -f
```

## 🔄 更新和维护

### 更新 LiteLLM 镜像

```bash
# 编辑 deployment
vim tenants/us-west/apps/litellm/app/manifests/litellm-deployment.yaml
# 修改 image 版本

# 提交
git add .
git commit -m "Update LiteLLM to v1.80.0"
git push

# FluxCD 会自动应用（或手动触发）
flux reconcile kustomization litellm-app --with-source
```

### 更新 API Keys

```bash
# 1. 更新 secret 模板
vim secret/litellm-app-secret.yaml

# 2. 重新加密
kubectl create secret generic litellm-app-secret \
  --from-env-file=litellm.env \
  --namespace=ai-gateway --dry-run=client -o yaml | \
  kubeseal --format=yaml --cert=pub-sealed-secrets.pem > \
  tenants/us-west/apps/litellm/app/manifests/litellm-app-secret-sealed.yaml

# 3. 提交并推送
git add .
git commit -m "Update API keys"
git push
```

### 更新配置

```bash
# 编辑 ConfigMap
vim tenants/us-west/apps/litellm/app/manifests/litellm-config.yaml

# 提交
git add .
git commit -m "Update LiteLLM configuration"
git push

# 重启应用以加载新配置
kubectl rollout restart deployment/litellm -n ai-gateway
```

## 🎯 下一步

- [ ] 配置 Flux 通知 (Slack/Discord)
- [ ] 设置 Image Automation (自动更新镜像)
- [ ] 添加 Flux monitoring (Prometheus/Grafana)
- [ ] 配置备份策略 (Velero)
- [ ] 实现多集群管理

## 📞 获取帮助

- **FluxCD 文档**: https://fluxcd.io/docs/
- **ArgoCD 文档**: https://argo-cd.readthedocs.io/
- **CloudNativePG 文档**: https://cloudnative-pg.io/documentation/
- **Redis Operator 文档**: https://ot-container-kit.github.io/redis-operator/

## 🙏 致谢

感谢以下开源项目:
- FluxCD
- ArgoCD
- Sealed Secrets
- CloudNativePG
- Redis Operator
- LiteLLM
