# 目录结构迁移方案

## 目标

从：
```
tenants/us-west/
├── cluster-infra/  ← ArgoCD 管理
└── apps/           ← FluxCD 管理
```

到：
```
infrastructure/     ← ArgoCD 管理（新）
apps/              ← FluxCD 管理（新）
```

## 零停机迁移步骤

### 第 1 步：创建新目录（保留旧的）

```bash
# 在项目根目录执行
mkdir -p infrastructure
mkdir -p apps

# 复制内容
cp -r tenants/us-west/cluster-infra/* infrastructure/
cp -r tenants/us-west/apps/* apps/
```

### 第 2 步：验证内容完整性

```bash
# 检查文件数量是否一致
find tenants/us-west/cluster-infra -type f | wc -l
find infrastructure -type f | wc -l

find tenants/us-west/apps -type f | wc -l
find apps -type f | wc -l
```

### 第 3 步：提交新目录（旧目录保持不变）

```bash
git add infrastructure/ apps/
git commit -m "Add new directory structure (infrastructure + apps)"
git push
```

**关键**：此时旧目录 `tenants/` 仍然存在，ArgoCD 仍然正常工作。

### 第 4 步：更新 ArgoCD Application（关键步骤）

编辑 `bootstrap/root-us-west.yaml`，修改 `path`：

```yaml
# 从
path: tenants/us-west/cluster-infra

# 改为
path: infrastructure
```

**重要**：暂时**不要**提交此修改！

### 第 5 步：在本地验证（Dry Run）

```bash
# 使用 argocd CLI 模拟同步
argocd app sync root-us-west --dry-run --prune=false

# 检查是否会删除资源
# 应该看到 "unchanged" 而不是 "deleted"
```

如果看到任何 "deleted"，**停止操作**，检查问题。

### 第 6 步：应用新配置

```bash
# 方法 A：先禁用 prune（推荐）
# 编辑 root-us-west.yaml，临时禁用 prune
spec:
  syncPolicy:
    automated:
      prune: false  # 临时禁用

# 提交
git add bootstrap/root-us-west.yaml
git commit -m "Update ArgoCD to use new infrastructure path"
git push

# 等待 ArgoCD 同步（或手动触发）
argocd app sync root-us-west
```

### 第 7 步：验证所有资源正常

```bash
# 检查所有基础设施组件
kubectl get applications -n argocd
kubectl get pods -n sealed-secrets
kubectl get pods -n cert-manager
kubectl get pods -n cnpg-system
kubectl get pods -n ot-operators

# 确认没有资源被删除
argocd app get root-us-west
```

### 第 8 步：重新启用 prune

```bash
# 编辑 root-us-west.yaml
spec:
  syncPolicy:
    automated:
      prune: true  # 重新启用

git add bootstrap/root-us-west.yaml
git commit -m "Re-enable prune for root-us-west"
git push
```

### 第 9 步：删除旧目录

```bash
# 确认一切正常后，删除旧目录
git rm -r tenants/
git commit -m "Remove old tenants directory structure"
git push
```

### 第 10 步：更新 FluxCD 配置

编辑 `clusters/us-west/apps.yaml`：

```yaml
# 从
path: ./tenants/us-west/apps

# 改为
path: ./apps
```

提交：
```bash
git add clusters/us-west/apps.yaml
git commit -m "Update FluxCD to use new apps path"
git push
```

## 回滚方案

如果出现问题，立即回滚：

```bash
# 方法 1：Git revert
git revert HEAD
git push

# 方法 2：手动修改
# 将 root-us-west.yaml 的 path 改回
path: tenants/us-west/cluster-infra
```

## 检查清单

- [ ] 新目录创建并内容已复制
- [ ] 新目录已提交到 Git
- [ ] ArgoCD dry-run 显示 "unchanged"
- [ ] 临时禁用了 prune
- [ ] 更新了 ArgoCD path
- [ ] 验证所有 Pods 正常运行
- [ ] 重新启用 prune
- [ ] 删除旧目录
- [ ] 更新 FluxCD 配置

## 预计耗时

- 准备工作: 10 分钟
- 执行迁移: 15 分钟
- 验证测试: 10 分钟
- 清理旧目录: 5 分钟

**总计: 40 分钟**

## 风险评估

- **风险等级**: 低（只要按步骤操作）
- **最坏情况**: 需要 git revert（30 秒恢复）
- **停机时间**: 0（新旧路径内容相同）
