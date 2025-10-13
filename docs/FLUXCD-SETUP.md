# FluxCD 部署指南

这是一个简化的 FluxCD 部署指南，专门针对你的 k8s-gitops 项目。

## 前提条件

- Kubernetes 集群已运行（版本 >= 1.20.6）
- kubectl 已配置并能访问集群
- Git 仓库（你的 k8s-gitops）
- GitHub Personal Access Token（需要 repo 权限）

## 步骤 1: 安装 Flux CLI

### Windows (使用 Chocolatey)
```powershell
choco install flux
```

### 或者使用 PowerShell 直接下载
```powershell
# 下载最新版本
Invoke-WebRequest -Uri "https://github.com/fluxcd/flux2/releases/latest/download/flux_windows_amd64.zip" -OutFile flux.zip

# 解压
Expand-Archive -Path flux.zip -DestinationPath .

# 移动到 PATH 目录
Move-Item -Path .\flux.exe -Destination C:\Windows\System32\
```

### 验证安装
```bash
flux --version
```

## 步骤 2: 检查集群兼容性

在 bootstrap 之前，先检查集群是否满足要求：

```bash
flux check --pre
```

应该看到类似输出：
```
► checking prerequisites
✔ Kubernetes 1.28.0 >=1.20.6-0
✔ prerequisites checks passed
```

## 步骤 3: 准备 GitHub Personal Access Token

1. 访问 https://github.com/settings/tokens
2. 点击 "Generate new token (classic)"
3. 勾选以下权限：
   - `repo` (完整的仓库访问权限)
4. 生成并复制 token

**在 PowerShell 中设置环境变量：**
```powershell
$env:GITHUB_TOKEN = "ghp_your_token_here"
$env:GITHUB_USER = "SimpleLumine"  # 你的 GitHub 用户名
```

## 步骤 4: Bootstrap FluxCD 到集群

运行 bootstrap 命令：

```bash
flux bootstrap github \
  --token-auth \
  --owner=SimpleLumine \
  --repository=k8s-gitops \
  --branch=main \
  --path=./clusters/us-west \
  --personal
```

### 参数说明：
- `--token-auth`: 使用 token 认证（而不是 SSH）
- `--owner`: GitHub 用户名或组织名
- `--repository`: 仓库名称
- `--branch`: Git 分支（通常是 main）
- `--path`: Flux 将监控这个路径下的 manifests
- `--personal`: 表示这是个人仓库（不是组织）

### Bootstrap 过程会做什么？

1. 在集群中创建 `flux-system` namespace
2. 安装 Flux 控制器（source-controller, kustomize-controller 等）
3. 在你的 Git 仓库中创建必要的配置文件
4. 配置 Flux 自动同步 Git 仓库的更改

## 步骤 5: 验证 FluxCD 安装

### 检查 Flux 组件状态
```bash
flux check
```

应该看到：
```
► checking controllers
✔ helm-controller: deployment ready
✔ kustomize-controller: deployment ready
✔ notification-controller: deployment ready
✔ source-controller: deployment ready
✔ all checks passed
```

### 查看 Flux pods
```bash
kubectl get pods -n flux-system
```

应该看到 4 个运行中的 pods：
```
NAME                                       READY   STATUS    RESTARTS   AGE
helm-controller-xxx                        1/1     Running   0          2m
kustomize-controller-xxx                   1/1     Running   0          2m
notification-controller-xxx                1/1     Running   0          2m
source-controller-xxx                      1/1     Running   0          2m
```

### 查看 GitRepository 资源
```bash
flux get sources git
```

应该看到：
```
NAME            REVISION        SUSPENDED       READY   MESSAGE
flux-system     main@sha1:xxx   False           True    stored artifact for revision 'main@sha1:xxx'
```

## 步骤 6: 检查 Bootstrap 创建的文件

Bootstrap 后，你的仓库会多出一个目录：

```
k8s-gitops/
└── clusters/
    └── us-west/
        └── flux-system/
            ├── gotk-components.yaml    # Flux 核心组件
            ├── gotk-sync.yaml          # 同步配置
            └── kustomization.yaml      # Kustomize 配置
```

**提交这些文件到 Git：**
```bash
git pull origin main
git add clusters/
git commit -m "Add Flux bootstrap configuration"
git push
```

## 步骤 7: 配置 Flux 监控你的应用

现在 Flux 已经安装，但还没有监控你的应用。你需要创建 Kustomization 资源。

### 创建目录结构
```bash
mkdir -p clusters/us-west/apps
```

### 创建 apps Kustomization
创建文件 `clusters/us-west/apps/kustomization.yaml`:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: apps
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./tenants/us-west/apps
  prune: true
  wait: false
```

### 创建 cluster-infra Kustomization
创建文件 `clusters/us-west/infrastructure/kustomization.yaml`:

```yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: infrastructure
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: flux-system
  path: ./tenants/us-west/cluster-infra
  prune: true
  wait: true
```

提交这些文件：
```bash
git add clusters/
git commit -m "Add apps and infrastructure kustomizations"
git push
```

## 步骤 8: 监控 Flux 同步状态

### 实时查看同步状态
```bash
flux get kustomizations --watch
```

### 查看特定 Kustomization
```bash
flux get kustomization infrastructure
flux get kustomization apps
```

### 手动触发同步（如果需要）
```bash
flux reconcile kustomization flux-system --with-source
```

### 查看日志（如果有问题）
```bash
flux logs --level=error
```

## 常用命令

### 暂停同步
```bash
flux suspend kustomization apps
```

### 恢复同步
```bash
flux resume kustomization apps
```

### 导出当前配置
```bash
flux export kustomization apps
```

### 删除 Kustomization（不删除资源）
```bash
flux delete kustomization apps --silent
```

### 完全卸载 Flux
```bash
flux uninstall --namespace=flux-system --keep-namespace
```

## 故障排查

### Flux 无法拉取 Git 仓库

检查 GitRepository 状态：
```bash
flux get sources git -A
kubectl describe gitrepository flux-system -n flux-system
```

### Kustomization 同步失败

查看具体错误：
```bash
flux get kustomizations
kubectl describe kustomization <name> -n flux-system
```

### 查看控制器日志
```bash
# Source controller (负责拉取 Git)
kubectl logs -n flux-system deployment/source-controller

# Kustomize controller (负责应用资源)
kubectl logs -n flux-system deployment/kustomize-controller

# Helm controller (负责 Helm releases)
kubectl logs -n flux-system deployment/helm-controller
```

## 下一步

现在 FluxCD 已经安装完成，你可以：

1. 将 ArgoCD Applications 转换为 Flux Kustomizations
2. 为 LiteLLM 创建 Flux 配置（使用依赖管理）
3. 配置 Sealed Secrets 与 Flux 集成
4. 设置 Flux 通知（Slack/Discord）

需要我帮你继续配置 LiteLLM 的 Flux 部署吗？
