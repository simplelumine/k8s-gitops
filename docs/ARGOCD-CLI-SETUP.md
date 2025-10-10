# ArgoCD CLI 配置指南

## 📋 概述

ArgoCD CLI 可以配置多个上下文（context），类似于 kubectl 的上下文管理。

## 🔍 当前状态

你目前有一个旧的上下文：
```powershell
argocd context
# CURRENT  NAME            SERVER
# *        localhost:8080  localhost:8080
```

这个上下文使用的是 port-forward 方式（`localhost:8080`）。

## 🎯 目标

添加一个新的上下文，使用 Tailscale 地址：`argocd.tailf328f4.ts.net`

---

## 🚀 添加 Tailscale 上下文

### 方法 1: 使用 argocd login（推荐）

```powershell
# 登录到 Tailscale 地址（会自动创建新上下文）
argocd login argocd.tailf328f4.ts.net

# 如果是第一次登录，需要输入：
# - Username: admin
# - Password: <从 secret 中获取，见下方>
```

**获取 ArgoCD 初始密码**：
```powershell
# 方法 A: 通过 kubectl
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d

# 方法 B: 如果没有 initial-admin-secret，使用当前登录
# 先确保旧的上下文还能用
argocd context localhost:8080
argocd account update-password
# 按提示设置新密码
```

### 方法 2: 手动添加上下文

```powershell
# 1. 获取认证 token（通过旧的上下文）
argocd context localhost:8080

# 2. 添加新的服务器
argocd context --server argocd.tailf328f4.ts.net

# 3. 登录
argocd login argocd.tailf328f4.ts.net
```

---

## 🔄 上下文管理

### 查看所有上下文

```powershell
argocd context

# 期望输出：
# CURRENT  NAME                       SERVER
# *        argocd.tailf328f4.ts.net  argocd.tailf328f4.ts.net
#          localhost:8080            localhost:8080
```

### 切换上下文

```powershell
# 切换到 Tailscale
argocd context argocd.tailf328f4.ts.net

# 切换到 localhost（port-forward）
argocd context localhost:8080
```

### 设置默认上下文

```powershell
# 设置 Tailscale 为默认
argocd context argocd.tailf328f4.ts.net

# 验证当前上下文
argocd context
# 应该看到 * 号在 argocd.tailf328f4.ts.net 前面
```

### 删除旧上下文（可选）

```powershell
# 如果不再需要 port-forward 上下文
argocd context --delete localhost:8080
```

---

## 🧪 测试连接

### 测试 Tailscale 上下文

```powershell
# 1. 切换到 Tailscale 上下文
argocd context argocd.tailf328f4.ts.net

# 2. 列出所有应用
argocd app list

# 期望输出：
# NAME                 CLUSTER                         NAMESPACE  PROJECT  STATUS  HEALTH
# argocd               https://kubernetes.default.svc  argocd     default  Synced  Healthy
# root-us-west         https://kubernetes.default.svc  argocd     default  Synced  Healthy
# tailscale-operator   https://kubernetes.default.svc  tailscale  default  Synced  Healthy

# 3. 查看特定应用
argocd app get argocd
```

---

## 📝 完整操作步骤（推荐）

```powershell
# 步骤 1: 查看当前上下文
argocd context

# 步骤 2: 登录 Tailscale 地址
argocd login argocd.tailf328f4.ts.net

# 如果需要密码，获取初始密码：
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath='{.data.password}' | base64 -d

# 或者如果初始密码已被删除，通过 port-forward 重置：
# 1. 启动 port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# 2. 在另一个终端，使用旧的上下文登录
argocd context localhost:8080
argocd login localhost:8080

# 3. 更新密码
argocd account update-password

# 4. 使用新密码登录 Tailscale
argocd login argocd.tailf328f4.ts.net

# 步骤 3: 验证新上下文工作正常
argocd app list

# 步骤 4: 设置为默认
argocd context argocd.tailf328f4.ts.net

# 步骤 5: 删除旧上下文（可选）
argocd context --delete localhost:8080

# 步骤 6: 最终验证
argocd context
argocd app list
```

---

## 🔐 关于认证

### ArgoCD CLI 如何存储认证信息？

ArgoCD CLI 将上下文信息存储在本地配置文件中：

**Windows**:
```
%USERPROFILE%\.config\argocd\config
```

**Linux/Mac**:
```
~/.config/argocd/config
```

### 查看配置文件

```powershell
# Windows
notepad $env:USERPROFILE\.config\argocd\config

# Linux/Mac
cat ~/.config/argocd/config
```

示例内容：
```yaml
contexts:
- name: argocd.tailf328f4.ts.net
  server: argocd.tailf328f4.ts.net
  user: argocd.tailf328f4.ts.net
- name: localhost:8080
  server: localhost:8080
  user: localhost:8080
current-context: argocd.tailf328f4.ts.net
servers:
- server: argocd.tailf328f4.ts.net
  auth-token: eyJhbGc...
- server: localhost:8080
  auth-token: eyJhbGc...
users:
- name: argocd.tailf328f4.ts.net
  auth-token: eyJhbGc...
- name: localhost:8080
  auth-token: eyJhbGc...
```

---

## 🆚 两种访问方式对比

| 方式 | 地址 | 优点 | 缺点 | 使用场景 |
|------|------|------|------|----------|
| **Port-Forward** | `localhost:8080` | 快速测试<br>无需网络配置 | 需要保持 kubectl 连接<br>每次需要重新转发 | 临时调试<br>快速访问 |
| **Tailscale** | `argocd.tailf328f4.ts.net` | 稳定连接<br>无需 kubectl<br>任何设备可访问 | 需要加入 Tailnet | 日常使用<br>生产环境 |

---

## 💡 最佳实践

### 1. 使用 Tailscale 作为主要访问方式

```powershell
# 设置 Tailscale 为默认
argocd context argocd.tailf328f4.ts.net
```

### 2. 保留 port-forward 上下文作为备用

如果 Tailscale 出问题，可以快速切换：
```powershell
# 启动 port-forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# 切换上下文
argocd context localhost:8080
```

### 3. 使用别名简化操作（可选）

**PowerShell** (添加到 `$PROFILE`):
```powershell
# 切换到 Tailscale
function argocd-tailscale {
    argocd context argocd.tailf328f4.ts.net
}

# 切换到 port-forward
function argocd-local {
    argocd context localhost:8080
}

# 使用：
# argocd-tailscale
# argocd-local
```

**Bash/Zsh** (添加到 `.bashrc` 或 `.zshrc`):
```bash
alias argocd-tailscale='argocd context argocd.tailf328f4.ts.net'
alias argocd-local='argocd context localhost:8080'
```

---

## 🔧 故障排查

### 问题 1: 登录失败 - "connection refused"

```powershell
# 检查 Tailscale 服务是否可达
curl https://argocd.tailf328f4.ts.net

# 或
Test-NetConnection argocd.tailf328f4.ts.net -Port 443
```

### 问题 2: 证书错误

```powershell
# Tailscale 提供自动 HTTPS，通常不会有证书问题
# 如果遇到，可以使用 --insecure 标志（不推荐生产环境）
argocd login argocd.tailf328f4.ts.net --insecure
```

### 问题 3: 密码错误

```powershell
# 重置密码（需要先通过 kubectl 或旧上下文登录）
argocd account update-password

# 或通过 kubectl 直接修改
kubectl patch secret argocd-secret -n argocd -p '{"data":{"admin.password":"'$(echo -n 'new-password' | base64)'"}}'
```

### 问题 4: Token 过期

```powershell
# 重新登录即可刷新 token
argocd login argocd.tailf328f4.ts.net
```

---

## ✅ 验证清单

- [ ] 已登录 Tailscale 地址：`argocd login argocd.tailf328f4.ts.net`
- [ ] 可以列出应用：`argocd app list`
- [ ] Tailscale 上下文已设为默认：`argocd context`
- [ ] 测试创建/修改应用成功
- [ ] （可选）已删除旧的 port-forward 上下文

---

## 📚 相关命令参考

```powershell
# 上下文管理
argocd context                                  # 列出所有上下文
argocd context <name>                          # 切换上下文
argocd context --delete <name>                 # 删除上下文

# 登录/登出
argocd login <server>                          # 登录服务器
argocd login <server> --username admin --password <pwd>
argocd logout <server>                         # 登出

# 应用管理
argocd app list                                # 列出所有应用
argocd app get <app-name>                      # 查看应用详情
argocd app sync <app-name>                     # 同步应用
argocd app diff <app-name>                     # 查看差异

# 账户管理
argocd account get-user-info                   # 查看当前用户
argocd account update-password                 # 更新密码
argocd account list                            # 列出所有账户

# 仓库管理
argocd repo list                               # 列出所有仓库
argocd repo add <repo-url> --ssh-private-key-path <path>
```

---

## 🎉 完成！

现在你可以：
- ✅ 通过 Tailscale 使用 argocd CLI
- ✅ 随时切换不同的上下文
- ✅ 在任何加入 Tailnet 的设备上访问
