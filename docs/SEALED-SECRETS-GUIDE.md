# Sealed Secrets 管理指南

完整的 Sealed Secrets 使用文档。

## 目录

- [什么是 Sealed Secrets](#什么是-sealed-secrets)
- [工作原理](#工作原理)
- [使用流程](#使用流程)
- [安全最佳实践](#安全最佳实践)
- [故障排查](#故障排查)
- [常见问题](#常见问题)

## 什么是 Sealed Secrets

Sealed Secrets 是一个 Kubernetes controller，允许您安全地将加密的 Secret 存储在 Git 仓库中。

**核心概念：**
- **明文 Secret**：标准的 Kubernetes Secret YAML（包含敏感信息）
- **SealedSecret**：加密后的 Secret，可以安全地提交到 Git
- **Controller**：部署在集群中，负责解密 SealedSecret 并创建实际的 Secret

## 工作原理

```
1. 本地创建明文 Secret
   ↓
2. 使用 kubeseal 加密（使用集群的公钥）
   ↓
3. 生成 SealedSecret（加密数据）
   ↓
4. 提交 SealedSecret 到 Git
   ↓
5. ArgoCD 同步到集群
   ↓
6. Sealed Secrets Controller 解密（使用私钥）
   ↓
7. 创建实际的 Secret 供应用使用
```

**安全性：**
- 只有集群中的 Controller 拥有私钥，可以解密
- 即使 Git 仓库泄露，攻击者也无法解密 SealedSecret
- 加密密钥存储在集群的 `kube-system` namespace

## 使用流程

### 前提条件

1. **Sealed Secrets Controller 已部署**
   ```bash
   kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets
   ```

2. **安装 kubeseal CLI**
   ```powershell
   scoop install kubeseal
   ```

### 步骤 1：创建明文 Secret

在 `.local-secrets/` 目录创建标准的 Kubernetes Secret：

```yaml
# .local-secrets/my-app-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: my-app-secret
  namespace: my-namespace
type: Opaque
stringData:
  username: admin
  password: super-secret-password
```

### 步骤 2：加密 Secret

使用脚本（推荐）：

```powershell
.\scripts\seal-secret.ps1 `
  .local-secrets\my-app-secret.yaml `
  tenants\us-west\apps\my-app\manifests\my-app-sealed-secret.yaml
```

或手动使用 kubeseal：

```powershell
kubeseal --format yaml `
  < .local-secrets\my-app-secret.yaml `
  > tenants\us-west\apps\my-app\manifests\my-app-sealed-secret.yaml
```

生成的 SealedSecret：

```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: my-app-secret
  namespace: my-namespace
spec:
  encryptedData:
    username: AgBy3i4OJSWK+PiTySYZZA9rO3xvTAztp...
    password: AgAR9Z2K5LmN8QwX3V6bY1cD9fH7jK2...
```

### 步骤 3：提交到 Git

```bash
# 只提交加密后的文件
git add tenants/us-west/apps/my-app/manifests/my-app-sealed-secret.yaml
git commit -m "chore: add my-app secrets"
git push
```

### 步骤 4：ArgoCD 自动部署

ArgoCD 会：
1. 检测到变更
2. 同步 SealedSecret 到集群
3. Controller 自动解密并创建 Secret
4. 应用可以使用 Secret

验证：

```bash
# 查看 SealedSecret
kubectl get sealedsecrets -n my-namespace

# 查看解密后的 Secret
kubectl get secrets -n my-namespace
```

## 安全最佳实践

### 1. 密钥备份

**立即备份加密密钥**（集群重建时需要）：

```bash
kubectl get secret -n kube-system \
  -l sealedsecrets.bitnami.com/sealed-secrets-key \
  -o yaml > sealed-secrets-key-backup.yaml
```

**存储位置：**
- ✅ 密码管理器（1Password, Bitwarden）
- ✅ 安全的离线存储
- ❌ 不要提交到 Git！

### 2. 文件组织

```
项目/
├── .local-secrets/              # 明文 secrets（本地，不提交）
│   ├── app1-secret.yaml
│   └── app2-secret.yaml
└── tenants/us-west/apps/
    ├── app1/
    │   └── manifests/
    │       └── app1-sealed-secret.yaml    # 加密 secrets（提交）
    └── app2/
        └── manifests/
            └── app2-sealed-secret.yaml
```

### 3. 访问控制

- 明文 secrets 只存在于本地开发机器
- 使用 `.gitignore` 防止意外提交
- 定期轮换密码

### 4. Git 历史清理

如果不小心提交了明文 secret：

```bash
# 警告：这会重写 Git 历史！
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch path/to/secret.yaml" \
  --prune-empty --tag-name-filter cat -- --all

# 强制推送
git push origin --force --all
```

然后立即轮换泄露的密码！

## 故障排查

### 问题 1：kubeseal 无法连接到集群

**症状：**
```
error: cannot get sealed secret service: services "sealed-secrets-controller" not found
```

**解决方案：**

1. 检查 controller 是否运行：
   ```bash
   kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets
   ```

2. 检查 service：
   ```bash
   kubectl get svc -n kube-system sealed-secrets-controller
   ```

3. 明确指定 controller：
   ```bash
   kubeseal --controller-name sealed-secrets-controller \
            --controller-namespace kube-system \
            --format yaml < input.yaml > output.yaml
   ```

### 问题 2：SealedSecret 无法解密

**症状：**
SealedSecret 创建了，但 Secret 没有出现。

**解决方案：**

1. 查看 controller 日志：
   ```bash
   kubectl logs -n kube-system -l app.kubernetes.io/name=sealed-secrets
   ```

2. 常见原因：
   - namespace 不匹配
   - 使用了错误的加密密钥（集群重建后）
   - SealedSecret 名称/namespace 与加密时不一致

### 问题 3：集群重建后无法解密

**原因：**
新集群生成了新的加密密钥。

**解决方案：**

恢复原来的密钥：

```bash
# 应用备份的密钥
kubectl apply -f sealed-secrets-key-backup.yaml

# 重启 controller
kubectl rollout restart deployment -n kube-system sealed-secrets-controller

# 等待 controller 就绪
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=sealed-secrets \
  -n kube-system
```

### 问题 4：权限错误

**症状：**
```
Error from server (Forbidden): error when creating "STDIN": ...
```

**解决方案：**

检查 RBAC 权限：

```bash
# 检查 controller 的 ServiceAccount
kubectl get sa -n kube-system sealed-secrets-controller

# 检查 ClusterRole
kubectl get clusterrole sealed-secrets-controller

# 检查 ClusterRoleBinding
kubectl get clusterrolebinding sealed-secrets-controller
```

## 常见问题

### Q: 为什么需要两个文件（明文 + 加密）？

**A:**
- **明文 Secret**（`.local-secrets/`）：便于您编辑和更新
- **加密 SealedSecret**（`manifests/`）：安全地存储在 Git 中

### Q: 可以直接编辑 SealedSecret 吗？

**A:** 不行。必须：
1. 编辑明文 Secret
2. 重新运行 kubeseal 加密
3. 提交新的 SealedSecret

### Q: 多个环境（dev/staging/prod）如何管理？

**A:** 每个集群有自己的加密密钥：

```bash
# 为 staging 集群加密
kubeseal --kubeconfig ~/.kube/staging-config \
  < secret.yaml > staging-sealed-secret.yaml

# 为 prod 集群加密
kubeseal --kubeconfig ~/.kube/prod-config \
  < secret.yaml > prod-sealed-secret.yaml
```

### Q: 如何轮换 Secret？

**A:**
1. 更新 `.local-secrets/` 中的明文 Secret
2. 重新加密生成新的 SealedSecret
3. 提交到 Git
4. ArgoCD 自动同步
5. 应用会获取新的 Secret（可能需要重启 Pod）

### Q: 加密密钥会过期吗？

**A:** 默认情况下，Sealed Secrets 每 30 天轮换一次加密密钥（但旧密钥保留用于解密旧的 SealedSecret）。这是自动的，不需要手动干预。

### Q: 性能影响？

**A:**
- 加密/解密操作很快（毫秒级）
- Controller 资源占用很小
- 对集群性能影响可忽略不计

### Q: 可以在 CI/CD 中使用吗？

**A:** 可以！需要：
1. CI/CD 有访问集群的权限
2. 安装 kubeseal CLI
3. 在 pipeline 中加密 secrets

示例：

```yaml
# GitHub Actions
- name: Seal secret
  run: |
    kubeseal --format yaml \
      < secret.yaml > sealed-secret.yaml
```

## 参考资料

- [Sealed Secrets 官方仓库](https://github.com/bitnami-labs/sealed-secrets)
- [Sealed Secrets Helm Chart](https://github.com/bitnami-labs/sealed-secrets/tree/main/helm/sealed-secrets)
- [ArgoCD 多 Source 文档](https://argo-cd.readthedocs.io/en/latest/user-guide/multiple_sources/)
- [Kubernetes Secrets 最佳实践](https://kubernetes.io/docs/concepts/security/secrets-good-practices/)
