# 🚀 Bootstrap 部署指南

## 概述

这个指南说明如何从零开始或从临时配置迁移到标准化的 GitOps 配置。

## 🎯 两种场景

### 场景 A: 全新集群部署
从零开始在新集群上部署 ArgoCD 和应用

### 场景 B: 从临时配置迁移（当前情况）
你已经有临时的 root-us-west，想要迁移到标准化的 YAML 管理

---

## 📋 场景 B: 迁移步骤（推荐用这个）

### 前置条件检查

```powershell
# 1. 检查当前的 Applications
kubectl get application -n argocd

# 2. 检查当前的 repository secrets
kubectl get secret -n argocd -l argocd.argoproj.io/secret-type=repository

# 3. 检查 ArgoCD 是否可以通过 Tailscale 访问
# 访问：https://argocd.tailf328f4.ts.net
```

### 步骤 1: 准备 Repository Secret

```powershell
# 1. 编辑 secret 文件，填入你的 SSH 私钥
notepad secret\argocd-repository-secret.yaml

# 2. 读取你的私钥
Get-Content $env:USERPROFILE\.ssh\argocd_k8s_gitops

# 3. 将私钥内容完整复制到 secret/argocd-repository-secret.yaml 的 sshPrivateKey 字段
```

**重要**: 确保私钥格式正确，包括：
```
-----BEGIN OPENSSH PRIVATE KEY-----
[私钥内容]
-----END OPENSSH PRIVATE KEY-----
```

### 步骤 2: 清理旧的临时资源（可选但推荐）

**⚠️ 注意**: 删除 root application 会暂时停止自动同步，但**不会删除**已部署的应用（argocd, tailscale-operator 等）

```bash
# A. 安全方式：先查看会删除什么
kubectl get application root-us-west -n argocd -o yaml

# B. 删除旧的 root application
kubectl delete application root-us-west -n argocd

# C. 删除旧的自动生成的 repo secret（可选）
kubectl delete secret repo-2216474485 -n argocd

# D. 确认子应用仍然存在
kubectl get application -n argocd
# 应该还能看到：argocd, tailscale-operator 等
```

### 步骤 3: 应用新的标准化配置

```bash
# 1. 创建新的 repository secret
kubectl apply -f secret/argocd-repository-secret.yaml

# 2. 验证 secret 创建成功
kubectl get secret k8s-gitops-repo -n argocd

# 3. 查看 secret 详情（验证 URL 正确）
kubectl get secret k8s-gitops-repo -n argocd -o jsonpath='{.data.url}' | base64 -d
# 应该输出：git@github.com:SimpleLumine/k8s-gitops.git

# 4. 创建新的 root application
kubectl apply -f bootstrap/root-application.yaml

# 5. 立即查看状态
kubectl get application root-us-west -n argocd
```

### 步骤 4: 验证部署

```bash
# 1. 持续观察 Applications 状态
kubectl get application -n argocd -w

# 期望看到：
# NAME                 SYNC STATUS   HEALTH STATUS
# root-us-west         Synced        Healthy
# argocd               Synced        Healthy
# tailscale-operator   Synced        Healthy

# 2. 如果 root-us-west 显示 OutOfSync，手动同步
kubectl patch application root-us-west -n argocd \
  --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'

# 3. 查看详细状态
kubectl describe application root-us-west -n argocd

# 4. 测试 Tailscale 访问
# 打开浏览器访问：https://argocd.tailf328f4.ts.net
```

### 步骤 5: 测试 Git 同步

```bash
# 1. 修改任意一个 application.yaml
# 例如添加注释

# 2. 提交到 Git
git add .
git commit -m "test: verify git sync"
git push

# 3. 等待 3 分钟（ArgoCD 默认轮询周期）
# 或手动触发同步
kubectl patch application root-us-west -n argocd \
  --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'

# 4. 查看同步历史
kubectl get application root-us-west -n argocd -o jsonpath='{.status.sync.revision}'
```

---

## 📋 场景 A: 全新集群部署

如果是全新集群，按此顺序操作：

### 步骤 1: 安装 ArgoCD

```bash
# 使用 Helm 安装（推荐，因为你已经有 application.yaml）
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# 安装 ArgoCD（基础版）
helm install argocd argo/argo-cd \
  -n argocd \
  --create-namespace \
  --version 8.5.10

# 等待 ArgoCD 就绪
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
```

### 步骤 2: 部署 Tailscale Operator（可选）

如果需要 Tailscale 接入：

```bash
# 安装 Tailscale Operator
helm repo add tailscale https://pkgs.tailscale.com/helmcharts
helm install tailscale-operator tailscale/tailscale-operator \
  -n tailscale \
  --create-namespace \
  --set oauth.clientId="YOUR_CLIENT_ID" \
  --set oauth.clientSecret="YOUR_CLIENT_SECRET"
```

### 步骤 3: Bootstrap ArgoCD

然后执行**场景 B 的步骤 1-5**

---

## 🔍 故障排查

### 问题 1: Repository 认证失败

```bash
# 查看 ArgoCD repo-server 日志
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server --tail=50

# 常见错误：
# - "Permission denied (publickey)" → SSH 私钥不正确
# - "Host key verification failed" → SSH known_hosts 问题

# 解决方案：
# 1. 重新检查私钥内容
# 2. 确保私钥格式正确（包含 BEGIN/END）
# 3. 确保私钥对应的公钥已添加到 GitHub
```

验证 GitHub SSH 访问：
```powershell
# 在本地测试 SSH 连接
ssh -T -i $env:USERPROFILE\.ssh\argocd_k8s_gitops git@github.com
# 应该看到：Hi SimpleLumine! You've successfully authenticated...
```

### 问题 2: root-us-west 一直 OutOfSync

```bash
# 查看 sync 状态
kubectl get application root-us-west -n argocd -o yaml | grep -A 20 "sync:"

# 手动强制同步
kubectl patch application root-us-west -n argocd \
  --type merge -p '{"operation":{"sync":{"prune":true}}}'
```

### 问题 3: 子 Application 没有被创建

```bash
# 检查 root application 的 directory 配置
kubectl get application root-us-west -n argocd -o jsonpath='{.spec.source.directory}'

# 确认输出包含：
# {"include":"*/application.yaml","recurse":true}

# 检查 Git 仓库中是否有 application.yaml 文件
# tenants/us-west/cluster-infra/*/application.yaml
```

### 问题 4: ArgoCD UI 无法访问

通过 Tailscale：
```bash
# 检查 service
kubectl get svc argocd-server -n argocd

# 应该看到 EXTERNAL-IP 包含：argocd.tailXXXXXX.ts.net
```

临时 port-forward：
```powershell
kubectl port-forward svc/argocd-server -n argocd 8080:443
# 访问：https://localhost:8080
```

---

## ✅ 验证清单

迁移完成后，检查以下项目：

- [ ] Repository secret 已创建：`kubectl get secret k8s-gitops-repo -n argocd`
- [ ] Root application 已创建：`kubectl get application root-us-west -n argocd`
- [ ] Root application 状态为 Synced：`kubectl get application root-us-west -n argocd`
- [ ] 所有子 Applications 正常：`kubectl get application -n argocd`
- [ ] ArgoCD 可通过 Tailscale 访问：`https://argocd.tailf328f4.ts.net`
- [ ] Git 同步正常工作（提交测试）
- [ ] 旧的临时资源已清理

---

## 📚 相关文档

- [bootstrap/README.md](README.md) - Bootstrap 目录说明
- [../GITOPS-STRUCTURE.md](../GITOPS-STRUCTURE.md) - 整体结构说明
- [ArgoCD 官方文档](https://argo-cd.readthedocs.io/)

---

## 💡 提示

### 关于 CLI vs UI vs YAML

你之前的方式：
```powershell
# CLI 方式（临时）
argocd repo add git@github.com:SimpleLumine/k8s-gitops.git \
  --ssh-private-key-path "$env:USERPROFILE\.ssh\argocd_k8s_gitops"

# UI 方式（临时）
# 在 ArgoCD UI 中点击创建
```

现在的方式（推荐）：
```bash
# YAML 声明式（可复现、可版本控制）
kubectl apply -f secret/argocd-repository-secret.yaml
kubectl apply -f bootstrap/root-application.yaml
```

### 为什么 YAML 更好？

1. **可复现性**: 可以在任何集群重复执行
2. **版本控制**: 可以追踪配置变更历史
3. **自动化**: 可以集成到 CI/CD 流程
4. **团队协作**: 其他人能看懂你的配置
5. **灾难恢复**: 快速从备份恢复

### 关于 Tailscale 访问

无需重新注册！Repository credentials 存储在 Kubernetes Secret 中，与访问方式无关：
- ✅ Port-forward → 能访问
- ✅ Tailscale → 能访问
- ✅ Ingress → 能访问

它们都使用同一个 Secret。
