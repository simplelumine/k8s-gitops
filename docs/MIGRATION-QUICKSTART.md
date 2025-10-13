# 目录迁移快速指南

## ⚡ 5分钟快速迁移

### 第 1 步：运行迁移脚本

```powershell
cd k8s-gitops
.\scripts\migrate-directory-structure.ps1
```

### 第 2 步：提交新目录

```bash
git add infrastructure/ apps/
git commit -m "Add new directory structure"
git push
```

### 第 3 步：暂时禁用 prune（关键！）

编辑 `bootstrap/root-us-west.yaml`:
```yaml
spec:
  syncPolicy:
    automated:
      prune: false  # 临时禁用，防止删除资源
```

### 第 4 步：更新路径

在同一文件中:
```yaml
source:
  path: infrastructure  # 从 tenants/us-west/cluster-infra 改为 infrastructure
```

### 第 5 步：提交并等待同步

```bash
git add bootstrap/root-us-west.yaml
git commit -m "Update ArgoCD to new infrastructure path"
git push

# 等待 ArgoCD 自动同步，或手动触发
argocd app sync root-us-west
```

### 第 6 步：验证

```bash
# 检查所有应用正常
argocd app get root-us-west

# 检查 pods
kubectl get pods -A | grep -E "(sealed-secrets|cert-manager|cnpg|ot-operators)"

# 应该看到所有 pods 仍在运行，没有被删除
```

### 第 7 步：重新启用 prune

编辑 `bootstrap/root-us-west.yaml`:
```yaml
spec:
  syncPolicy:
    automated:
      prune: true  # 重新启用
```

提交：
```bash
git add bootstrap/root-us-west.yaml
git commit -m "Re-enable prune"
git push
```

### 第 8 步：删除旧目录

```bash
git rm -r tenants/
git commit -m "Remove old tenants directory"
git push
```

### 第 9 步：更新 FluxCD 配置

编辑 `clusters/us-west/apps.yaml`:
```yaml
spec:
  path: ./apps  # 从 ./tenants/us-west/apps 改为 ./apps
```

提交：
```bash
git add clusters/us-west/apps.yaml
git commit -m "Update FluxCD to new apps path"
git push
```

## ✅ 完成！

新结构：
```
k8s-gitops/
├── clusters/us-west/
├── infrastructure/     ← ArgoCD 管理
└── apps/              ← FluxCD 管理
```

## 🆘 出问题了？

立即回滚：
```bash
git revert HEAD~2..HEAD
git push
```

或者手动修改 `root-us-west.yaml`，将 path 改回：
```yaml
path: tenants/us-west/cluster-infra
```

## 📋 检查清单

- [ ] 运行了迁移脚本
- [ ] 新目录已提交
- [ ] 禁用了 prune
- [ ] 更新了 ArgoCD path
- [ ] 验证了所有 pods 正常
- [ ] 重新启用了 prune
- [ ] 删除了旧目录
- [ ] 更新了 FluxCD 配置

## ⏱️ 预计耗时：5-10 分钟
