# 迁移到 environments/ 结构

## 目标结构

### 从
```
k8s-gitops/
├── bootstrap/
├── clusters/
├── tenants/us-west/
│   ├── cluster-infra/
│   └── apps/
├── docs/
├── scripts/
└── secret/
```

### 到
```
k8s-gitops/
├── bootstrap/
├── clusters/
├── environments/          ← 新增
│   └── us-west/
│       ├── infrastructure/
│       └── apps/
├── docs/
├── scripts/
└── secret/
```

## 为什么用 environments/?

### ✅ 优势

1. **语义精确**
   - `us-west` 是环境/集群，不是租户
   - `environments` 比 `tenants` 更准确

2. **根目录清爽**
   ```
   bootstrap/      - 引导配置
   clusters/       - FluxCD 控制层
   environments/   - 实际配置（数据层）
   docs/          - 文档
   scripts/       - 工具
   secret/        - 模板
   ```

3. **扩展性强**
   ```
   environments/
   ├── us-west/      # 生产 US
   ├── us-east/      # 灾备 US
   ├── eu-west/      # 生产 EU
   └── staging/      # 测试环境
   ```

4. **职责清晰**
   - `infrastructure/` - 平台组件
   - `apps/` - 业务应用

   在每个环境下都有这两类资源

## 快速迁移（5分钟）

### 第 1 步：运行迁移脚本

```powershell
cd k8s-gitops
.\scripts\migrate-to-environments.ps1
```

### 第 2 步：提交新目录

```bash
git add environments/
git commit -m "Add environments/us-west structure"
git push
```

### 第 3 步：更新 ArgoCD（关键！）

编辑 `bootstrap/root-us-west.yaml`:

```yaml
spec:
  # 临时禁用 prune（防止删除资源）
  syncPolicy:
    automated:
      prune: false  # ← 改为 false

  source:
    # 更新路径
    path: environments/us-west/infrastructure  # ← 新路径
    # 旧的: path: tenants/us-west/cluster-infra
```

提交：
```bash
git add bootstrap/root-us-west.yaml
git commit -m "Update ArgoCD path to environments/us-west/infrastructure"
git push
```

### 第 4 步：验证（重要！）

```bash
# 等待 ArgoCD 同步（约 3 分钟）
argocd app sync root-us-west

# 检查应用状态
argocd app get root-us-west

# 检查所有 pods 仍在运行
kubectl get pods -A | grep -E "(sealed-secrets|cert-manager|cnpg|ot-operators)"

# 应该看到所有服务正常，没有被删除
```

### 第 5 步：重新启用 prune

编辑 `bootstrap/root-us-west.yaml`:

```yaml
spec:
  syncPolicy:
    automated:
      prune: true  # ← 改回 true
```

提交：
```bash
git add bootstrap/root-us-west.yaml
git commit -m "Re-enable prune for root-us-west"
git push
```

### 第 6 步：更新 FluxCD

编辑 `clusters/us-west/apps.yaml`:

```yaml
spec:
  path: ./environments/us-west/apps  # ← 新路径
  # 旧的: path: ./tenants/us-west/apps
```

提交：
```bash
git add clusters/us-west/apps.yaml
git commit -m "Update FluxCD path to environments/us-west/apps"
git push
```

### 第 7 步：删除旧目录

```bash
# 确认一切正常后
git rm -r tenants/
git commit -m "Remove old tenants directory"
git push
```

## ✅ 完成！

新结构：
```
environments/
└── us-west/
    ├── infrastructure/  ← ArgoCD 管理
    └── apps/           ← FluxCD 管理
        └── litellm/
            ├── database/
            ├── cache/
            └── app/
```

## 对比其他方案

| 方案 | 根目录整洁度 | 语义准确性 | 扩展性 | 推荐度 |
|------|------------|----------|--------|--------|
| `tenants/us-west/` | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| `infrastructure/` + `apps/` | ⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐ |
| **`environments/us-west/`** | **⭐⭐⭐⭐⭐** | **⭐⭐⭐⭐⭐** | **⭐⭐⭐⭐⭐** | **⭐⭐⭐⭐⭐** |

## 回滚方案

如果出问题：

```bash
# 方法 1：Git revert
git revert HEAD~3..HEAD
git push

# 方法 2：手动恢复
# 编辑 bootstrap/root-us-west.yaml
path: tenants/us-west/cluster-infra  # 改回旧路径
```

## FAQ

### Q: 为什么不直接放根目录？

A: 根目录会变得拥挤：
```
k8s-gitops/
├── infrastructure/  ← 混在一起
├── apps/           ← 不清晰
├── docs/
├── scripts/
├── secret/
└── ...太多了
```

用 `environments/` 分组更清晰：
```
k8s-gitops/
├── environments/    ← 所有配置在这里
├── docs/           ← 所有文档在这里
├── scripts/        ← 所有工具在这里
└── ...清晰！
```

### Q: 未来如何添加新环境？

A: 非常简单：
```bash
# 复制现有环境
cp -r environments/us-west environments/us-east

# 修改配置
# 创建新的 ArgoCD Application

# 提交
git add environments/us-east
git commit -m "Add us-east environment"
git push
```

### Q: 这是官方推荐吗？

A: `environments/` 是社区广泛使用的模式，虽然官方示例使用 `apps/` + `infrastructure/`，但很多企业级项目使用 `environments/` 或 `envs/` 来组织多环境。

**实际上，两者结合就是你现在的方案**：
- 官方：按类型分（infrastructure, apps）
- 你：按环境分，每个环境内再按类型分

## 安全保障

- ✅ 零停机：资源内容相同，不会被删除
- ✅ 可回滚：任何时候都可以 git revert
- ✅ 渐进式：每步都可验证
- ✅ prune 禁用：迁移期间不会误删

## 总结

`environments/us-west/` 结构：
- ✅ 语义清晰（环境/集群）
- ✅ 根目录整洁
- ✅ 易于扩展
- ✅ 职责分明
- ✅ 社区认可

**强烈推荐使用！**
