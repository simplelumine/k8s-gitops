# 绝对安全的迁移指南

## 核心安全原则

**在任何时候，都确保 ArgoCD 不会误删资源。**

## 🔒 三重安全保护

### 第一重：禁用 Prune
### 第二重：使用 Dry Run
### 第三重：禁用 Self-Heal

---

## 详细步骤（每步都可回滚）

### 阶段 1：准备新目录（安全）

#### 步骤 1.1：运行迁移脚本

```powershell
.\scripts\migrate-to-environments.ps1
```

**风险**：无（只是复制文件）

#### 步骤 1.2：验证内容完全相同

```bash
# 验证文件数量
$infraOld = (Get-ChildItem -Path "tenants/us-west/cluster-infra" -Recurse -File).Count
$infraNew = (Get-ChildItem -Path "environments/us-west/infrastructure" -Recurse -File).Count

Write-Host "Old: $infraOld files"
Write-Host "New: $infraNew files"

if ($infraOld -ne $infraNew) {
    Write-Host "ERROR: File count mismatch!" -ForegroundColor Red
    exit 1
}
```

**验证点**：文件数量必须完全相同

#### 步骤 1.3：对比文件内容（重要！）

```bash
# 使用 git diff 对比（因为都是新文件，用工具对比）
# 或者手动检查几个关键文件

# 检查 sealed-secrets
diff tenants/us-west/cluster-infra/sealed-secrets/application.yaml environments/us-west/infrastructure/sealed-secrets/application.yaml

# 检查 cert-manager
diff tenants/us-west/cluster-infra/cert-manager/application.yaml environments/us-west/infrastructure/cert-manager/application.yaml
```

**验证点**：内容必须完全相同（除了路径）

#### 步骤 1.4：提交新目录

```bash
git add environments/
git commit -m "Add environments/us-west structure (migration preparation)"
git push
```

**风险**：无（ArgoCD 不会扫描这个新目录）

---

### 阶段 2：安全配置（关键！）

#### 步骤 2.1：三重保险配置

编辑 `bootstrap/root-us-west.yaml`，添加三重保护：

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
    path: tenants/us-west/cluster-infra  # 暂时不改
    repoURL: git@github.com:SimpleLumine/k8s-gitops.git
    targetRevision: HEAD
  syncPolicy:
    automated:
      enabled: false    # ← 第一重：禁用自动同步
      prune: false      # ← 第二重：禁用 prune
      selfHeal: false   # ← 第三重：禁用 self-heal
```

#### 步骤 2.2：提交并等待生效

```bash
git add bootstrap/root-us-west.yaml
git commit -m "Disable auto-sync for migration safety"
git push

# 等待 ArgoCD 读取配置（约 3 分钟）
# 或手动刷新
argocd app get root-us-west
```

**验证点**：
```bash
argocd app get root-us-west | grep "Auto sync"
# 应该显示: Auto sync:     false
```

**风险**：无（只是禁用自动同步）

---

### 阶段 3：模拟切换（Dry Run）

#### 步骤 3.1：本地创建测试配置

创建临时文件 `bootstrap/root-us-west-test.yaml`：

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-us-west-test    # ← 不同的名字（不影响现有）
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
    path: environments/us-west/infrastructure  # ← 新路径
    repoURL: git@github.com:SimpleLumine/k8s-gitops.git
    targetRevision: HEAD
  syncPolicy:
    automated:
      enabled: false
      prune: false
      selfHeal: false
```

#### 步骤 3.2：应用测试配置

```bash
kubectl apply -f bootstrap/root-us-west-test.yaml

# 查看测试应用状态
argocd app get root-us-west-test
```

**验证点**：查看 ArgoCD UI，`root-us-west-test` 应该显示所有资源都是 "Synced"

#### 步骤 3.3：对比两个 Application

```bash
# 旧的（指向 tenants/）
argocd app get root-us-west --refresh

# 新的（指向 environments/）
argocd app get root-us-west-test --refresh

# 对比资源列表，应该完全相同
argocd app resources root-us-west > old-resources.txt
argocd app resources root-us-west-test > new-resources.txt

diff old-resources.txt new-resources.txt
# 应该没有差异！
```

**验证点**：两个 Application 管理的资源列表**完全相同**

#### 步骤 3.4：清理测试应用

```bash
# 删除测试应用（不会删除实际资源）
argocd app delete root-us-west-test --cascade=false

# 或者通过 kubectl
kubectl delete application root-us-west-test -n argocd
```

**风险**：无（`--cascade=false` 不会删除实际资源）

---

### 阶段 4：正式切换（谨慎操作）

#### 步骤 4.1：更新路径（但保持 prune=false）

编辑 `bootstrap/root-us-west.yaml`：

```yaml
spec:
  source:
    path: environments/us-west/infrastructure  # ← 改为新路径
  syncPolicy:
    automated:
      enabled: false   # 保持禁用
      prune: false     # 保持禁用
      selfHeal: false  # 保持禁用
```

#### 步骤 4.2：提交并手动同步

```bash
git add bootstrap/root-us-west.yaml
git commit -m "Switch to environments/us-west/infrastructure (prune disabled)"
git push

# 手动刷新（不会删除任何东西）
argocd app get root-us-west --refresh

# 查看有哪些变化（应该是 0 changes）
argocd app diff root-us-west
```

**验证点**：
```bash
argocd app diff root-us-west
# 应该显示: No changes detected
```

如果显示有 changes，**立即停止！检查原因！**

#### 步骤 4.3：手动同步（最关键！）

```bash
# Dry run（模拟同步，不实际执行）
argocd app sync root-us-west --dry-run

# 仔细检查输出，确保没有 "delete" 操作
# 应该只看到 "unchanged" 或 "update"（如果有微小差异）

# 如果一切正常，执行实际同步
argocd app sync root-us-west --prune=false
```

**验证点**：
```bash
# 检查所有 pods 仍在运行
kubectl get pods -n sealed-secrets
kubectl get pods -n cert-manager
kubectl get pods -n cnpg-system
kubectl get pods -n ot-operators

# 检查 Application 状态
argocd app get root-us-west
```

所有服务应该仍然正常！

---

### 阶段 5：恢复自动化（谨慎）

#### 步骤 5.1：只启用 Auto Sync（prune 仍禁用）

```yaml
spec:
  syncPolicy:
    automated:
      enabled: true    # ← 启用自动同步
      prune: false     # ← 仍禁用 prune
      selfHeal: true   # ← 启用 self-heal
```

提交并观察：
```bash
git add bootstrap/root-us-west.yaml
git commit -m "Re-enable auto-sync (prune still disabled)"
git push

# 观察 5 分钟
watch -n 10 "kubectl get pods -A | grep -E '(sealed|cert|cnpg|redis)'"
```

**验证点**：所有 pods 保持稳定运行

#### 步骤 5.2：启用 Prune（最后一步）

```yaml
spec:
  syncPolicy:
    automated:
      enabled: true
      prune: true      # ← 最后启用 prune
      selfHeal: true
```

提交并观察：
```bash
git add bootstrap/root-us-west.yaml
git commit -m "Re-enable prune (migration complete)"
git push

# 观察 10 分钟
watch -n 10 "kubectl get pods -A | grep -E '(sealed|cert|cnpg|redis)'"
```

**验证点**：所有 pods 保持稳定运行

---

### 阶段 6：清理旧目录

#### 步骤 6.1：再次验证

```bash
# 确认 ArgoCD 指向新路径
argocd app get root-us-west | grep "Path:"
# 应该显示: Path: environments/us-west/infrastructure

# 确认所有服务正常
kubectl get applications -n argocd
kubectl get pods -A | grep -E "(sealed|cert|cnpg|redis)"
```

#### 步骤 6.2：删除旧目录

```bash
git rm -r tenants/
git commit -m "Remove old tenants directory (migration complete)"
git push
```

**验证点**：ArgoCD 不应该删除任何资源（因为它现在监控的是 `environments/`）

---

## 🆘 紧急回滚方案

### 在任何阶段出问题

#### 立即回滚配置
```bash
# 编辑 bootstrap/root-us-west.yaml
# 将 path 改回
path: tenants/us-west/cluster-infra

# 提交
git add bootstrap/root-us-west.yaml
git commit -m "EMERGENCY ROLLBACK"
git push

# 手动同步
argocd app sync root-us-west
```

#### Git 回滚
```bash
# 回滚最近 3 个 commit
git revert HEAD~2..HEAD
git push
```

---

## 📋 每个阶段的验证清单

### 阶段 1 ✅
- [ ] 新目录已创建
- [ ] 文件数量相同
- [ ] 关键文件内容相同
- [ ] 已提交到 Git

### 阶段 2 ✅
- [ ] Auto sync 已禁用
- [ ] Prune 已禁用
- [ ] Self-heal 已禁用
- [ ] 配置已生效

### 阶段 3 ✅
- [ ] 测试 Application 创建成功
- [ ] 资源列表完全相同
- [ ] 测试 Application 已清理

### 阶段 4 ✅
- [ ] 路径已更新
- [ ] Dry run 显示无变化
- [ ] 手动同步成功
- [ ] 所有 pods 正常运行

### 阶段 5 ✅
- [ ] Auto sync 已启用
- [ ] 观察期内无异常
- [ ] Prune 已启用
- [ ] 观察期内无异常

### 阶段 6 ✅
- [ ] 旧目录已删除
- [ ] 无资源被删除

---

## 💡 关键理解

### ArgoCD 如何识别资源？

**不是通过文件路径**，而是通过：
```yaml
apiVersion + kind + metadata.name + metadata.namespace
```

### 为什么还要小心？

1. **Prune 机制**：ArgoCD 会删除"不在 Git 中"的资源
2. **路径切换瞬间**：可能存在 race condition
3. **内容差异**：哪怕一个空格不同，也可能触发更新

### 三重保护原理

1. **禁用 Auto Sync**：完全由你控制同步时机
2. **禁用 Prune**：即使有差异，也不会删除
3. **手动 Dry Run**：模拟执行，看到结果再决定

---

## 🎓 总结

这个迁移方案：
- ✅ **绝对安全**：每步都可验证，可回滚
- ✅ **零风险**：三重保护机制
- ✅ **零停机**：资源不会被删除
- ✅ **可追溯**：每步都有 Git 记录

**最坏情况**：发现问题 → Git revert → 30 秒恢复

**最好情况**：顺利迁移 → 10 分钟完成 → 结构更优雅
