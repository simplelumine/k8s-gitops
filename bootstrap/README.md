# Bootstrap 目录

这个目录包含引导 ArgoCD 的初始配置文件。这些文件需要**手动**使用 `kubectl apply` 命令应用。

## 📚 完整文档

详细的部署指南和配置说明请查看 **[docs/](../docs/)** 目录：

- **[部署指南](../docs/DEPLOY.md)** - 完整的部署步骤
- **[ArgoCD CLI 配置](../docs/ARGOCD-CLI-SETUP.md)** - CLI 上下文管理
- **[Tailscale 安全说明](../docs/TAILSCALE-SECURITY.md)** - 安全模型解释
- **[更多文档...](../docs/README.md)** - 文档索引

## 📋 引导步骤

### 前置条件
- Kubernetes 集群已就绪
- kubectl 已配置并能访问集群
- ArgoCD 已安装（通过 Helm 或其他方式）

### 步骤 1: 配置 Git 仓库访问

如果你的 Git 仓库是私有的且需要 SSH 密钥认证：

```bash
# 1. 复制示例文件
cp bootstrap/repository-secret.yaml.example bootstrap/repository-secret.yaml

# 2. 编辑文件，填入你的 SSH 私钥
vim bootstrap/repository-secret.yaml

# 3. 应用 Secret
kubectl apply -f bootstrap/repository-secret.yaml

# 4. 验证 Secret 创建成功
kubectl get secret -n argocd k8s-gitops-repo
```

**重要**: `repository-secret.yaml` 包含敏感信息，已添加到 `.gitignore`，不会被提交到 Git。

### 步骤 2: 创建 Root Application

```bash
# 应用 root application
kubectl apply -f bootstrap/root-application.yaml

# 验证 Application 创建成功
kubectl get application -n argocd root-us-west

# 查看同步状态
kubectl get application -n argocd -w
```

### 步骤 3: 验证部署

```bash
# 查看所有 Applications
kubectl get applications -n argocd

# 查看 ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# 或通过 Tailscale 访问: https://argocd.tailXXXXXX.ts.net
```

## 🔄 更新 Root Application

如果需要修改 Root Application 配置：

```bash
# 编辑文件
vim bootstrap/root-application.yaml

# 重新应用
kubectl apply -f bootstrap/root-application.yaml
```

## 🗑️ 完全重置（谨慎操作）

```bash
# 删除所有由 ArgoCD 管理的应用
kubectl delete application -n argocd root-us-west

# 删除仓库凭证
kubectl delete secret -n argocd k8s-gitops-repo

# 重新开始引导流程
```

## 📝 注意事项

1. **Bootstrap 目录中的文件不由 ArgoCD 管理**
   - 这是"鸡生蛋"问题的解决方案
   - Root Application 需要手动创建才能让 ArgoCD 开始工作

2. **仓库凭证的安全性**
   - 永远不要将包含私钥的文件提交到 Git
   - 考虑使用外部密钥管理工具（如 Sealed Secrets、External Secrets）

3. **备份重要配置**
   - 备份你的 SSH 私钥
   - 备份 ArgoCD 的初始管理员密码
