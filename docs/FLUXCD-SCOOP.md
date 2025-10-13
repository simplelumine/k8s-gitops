# 使用 Scoop 安装 FluxCD

本文档说明如何使用 Scoop 包管理器安装 FluxCD CLI，以及多设备使用的最佳实践。

## 在当前电脑上安装 (使用 Scoop)

### 1. 确保 Scoop 已安装

```powershell
# 检查 Scoop 版本
scoop --version

# 如果未安装，运行：
# Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
# irm get.scoop.sh | iex
```

### 2. 添加 Scoop extras bucket (如果还没添加)

```powershell
scoop bucket add extras
```

### 3. 安装 FluxCD

```powershell
scoop install flux
```

### 4. 验证安装

```powershell
flux --version
# 输出类似: flux version 2.x.x
```

### 5. 更新 FluxCD (当需要时)

```powershell
scoop update flux
```

## 在另一台电脑上安装

使用 Scoop 的好处是配置可以跨设备同步！有两种方法：

### 方法 1: 简单安装 (推荐)

在新电脑上重复上述安装步骤：

```powershell
# 1. 安装 Scoop
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
irm get.scoop.sh | iex

# 2. 添加 bucket
scoop bucket add extras

# 3. 安装 flux
scoop install flux
```

### 方法 2: 使用 Scoop Export/Import (高级)

如果你想在多台电脑上保持完全相同的工具集：

**在当前电脑上导出：**
```powershell
# 导出已安装的应用列表
scoop export > C:\Users\YourName\scoop-apps.json

# 或者直接导出到你的 Git 仓库
scoop export > C:\Users\simplelumine\Documents\k8s-gitops\docs\scoop-apps.json
```

**在新电脑上导入：**
```powershell
# 1. 先安装 Scoop

# 2. 克隆你的 Git 仓库 (或者复制 scoop-apps.json)
git clone git@github.com:SimpleLumine/k8s-gitops.git

# 3. 导入应用列表（会自动安装所有工具）
cd k8s-gitops
scoop import docs/scoop-apps.json

# 或者只安装 flux
scoop install flux
```

## 多设备使用 FluxCD

### 认证配置共享

FluxCD 本身不需要特殊配置，但你需要在每台电脑上配置：

#### 1. Kubeconfig (Kubernetes 集群访问)

```powershell
# 方法 A: 从现有电脑复制 kubeconfig
# 在当前电脑上：
Copy-Item $env:USERPROFILE\.kube\config -Destination .\kubeconfig-backup

# 在新电脑上：
mkdir $env:USERPROFILE\.kube
Copy-Item .\kubeconfig-backup -Destination $env:USERPROFILE\.kube\config
```

```powershell
# 方法 B: 从集群重新获取 kubeconfig
# 例如，如果使用 k3s：
# scp user@cluster:/etc/rancher/k3s/k3s.yaml ~/.kube/config
```

#### 2. GitHub Token (如果需要)

```powershell
# 在新电脑上设置环境变量
$env:GITHUB_TOKEN = "ghp_your_token_here"
$env:GITHUB_USER = "SimpleLumine"

# 永久保存 (可选)
[System.Environment]::SetEnvironmentVariable('GITHUB_TOKEN', 'ghp_your_token_here', 'User')
[System.Environment]::SetEnvironmentVariable('GITHUB_USER', 'SimpleLumine', 'User')
```

### 工作流程

安装完成后，在任何电脑上都可以：

```powershell
# 1. 验证集群连接
kubectl get nodes

# 2. 检查 Flux 状态
flux check

# 3. 查看 Kustomizations
flux get kustomizations -A

# 4. 手动触发同步
flux reconcile kustomization apps --with-source

# 5. 查看日志
flux logs --level=info
```

## Git 仓库的使用

### 最佳实践：使用 SSH Key

在每台电脑上配置 SSH key，这样 Git 操作更方便：

```powershell
# 1. 生成 SSH key (如果没有)
ssh-keygen -t ed25519 -C "your_email@example.com"

# 2. 复制公钥
cat ~/.ssh/id_ed25519.pub | clip

# 3. 添加到 GitHub
# 访问 https://github.com/settings/keys
# 点击 "New SSH key" 并粘贴
```

### 在新电脑上克隆仓库

```powershell
cd C:\Users\simplelumine\Documents\
git clone git@github.com:SimpleLumine/k8s-gitops.git
cd k8s-gitops
```

## 推荐的跨设备工作流

### 1. 标准化你的环境

创建一个安装脚本 `scripts/setup-dev-env.ps1`:

```powershell
# scripts/setup-dev-env.ps1

# 检查 Scoop
if (!(Get-Command scoop -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Scoop..."
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    irm get.scoop.sh | iex
}

# 添加 buckets
scoop bucket add extras

# 安装必要工具
$tools = @('flux', 'kubectl', 'kubeseal', 'k9s', 'git')
foreach ($tool in $tools) {
    if (!(scoop list | Select-String $tool)) {
        Write-Host "Installing $tool..."
        scoop install $tool
    } else {
        Write-Host "$tool already installed"
    }
}

Write-Host "Development environment setup complete!"
```

### 2. 在新电脑上运行

```powershell
# 克隆仓库
git clone git@github.com:SimpleLumine/k8s-gitops.git
cd k8s-gitops

# 运行设置脚本
.\scripts\setup-dev-env.ps1

# 配置 kubeconfig (手动复制或从集群获取)

# 验证
kubectl get nodes
flux check
```

## 常用工具推荐 (Scoop)

除了 flux，这些工具也很有用：

```powershell
# Kubernetes 工具
scoop install kubectl      # Kubernetes CLI
scoop install k9s         # Kubernetes TUI
scoop install helm        # Helm 包管理器

# GitOps 工具
scoop install flux        # FluxCD CLI
scoop install argocd      # ArgoCD CLI (如果需要)

# 加密工具
scoop install kubeseal    # Sealed Secrets CLI

# 其他有用工具
scoop install git         # Git
scoop install gh          # GitHub CLI
scoop install yq          # YAML 处理器
scoop install jq          # JSON 处理器
```

## 故障排查

### Scoop 安装失败

```powershell
# 重置 Scoop
scoop reset

# 更新 Scoop
scoop update

# 清理缓存
scoop cache rm *
```

### Flux 命令找不到

```powershell
# 刷新环境变量
refreshenv

# 或者重新启动 PowerShell
```

### Kubeconfig 权限问题

```powershell
# 检查文件权限
Get-Acl $env:USERPROFILE\.kube\config

# 验证内容
kubectl config view
```

## 总结

使用 Scoop 的优势：
- ✅ 统一的包管理
- ✅ 易于更新和维护
- ✅ 可以导出/导入配置
- ✅ 跨设备安装一致

在多台电脑上使用：
1. 安装 Scoop 和 flux (每台电脑)
2. 配置 kubeconfig (复制或重新获取)
3. 配置 Git SSH key (每台电脑)
4. 克隆仓库，开始工作！
