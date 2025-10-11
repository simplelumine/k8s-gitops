# Sealed Secrets 加密脚本
# 用法: .\seal-secret.ps1 <input-secret.yaml> <output-sealed-secret.yaml>
#
# 示例:
#   .\seal-secret.ps1 .local-secrets\tailscale-oauth.yaml tenants\us-west\cluster-infra\tailscale-operator\manifests\oauth-sealed-secret.yaml

param(
    [Parameter(Mandatory=$true)]
    [string]$InputFile,

    [Parameter(Mandatory=$true)]
    [string]$OutputFile
)

# 检查 kubeseal 是否安装
if (-not (Get-Command kubeseal -ErrorAction SilentlyContinue)) {
    Write-Error "kubeseal 未安装！请运行: scoop install kubeseal"
    exit 1
}

# 检查输入文件是否存在
if (-not (Test-Path $InputFile)) {
    Write-Error "文件不存在: $InputFile"
    exit 1
}

# 创建输出目录（如果不存在）
$outputDir = Split-Path -Parent $OutputFile
if ($outputDir -and -not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

Write-Host "正在加密 Secret..." -ForegroundColor Cyan
Write-Host "   输入: $InputFile" -ForegroundColor Gray
Write-Host "   输出: $OutputFile" -ForegroundColor Gray
Write-Host ""

try {
    # 执行 kubeseal
    # 注意：我们的配置使用了 fullnameOverride=sealed-secrets-controller
    # 所以默认参数就可以工作
    Get-Content $InputFile | kubeseal --format yaml | Set-Content $OutputFile

    Write-Host "加密成功！" -ForegroundColor Green
    Write-Host ""
    Write-Host "下一步:" -ForegroundColor Yellow
    Write-Host "   1. 查看加密后的文件: $OutputFile" -ForegroundColor Gray
    Write-Host "   2. 提交到 Git:" -ForegroundColor Gray
    Write-Host "      git add $OutputFile" -ForegroundColor Gray
    Write-Host "      git commit -m 'chore: update sealed secret'" -ForegroundColor Gray
    Write-Host "      git push" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   3. 原始文件已被 .gitignore 保护，不会被提交" -ForegroundColor Gray
}
catch {
    Write-Error "加密失败: $_"
    Write-Host ""
    Write-Host "故障排查:" -ForegroundColor Yellow
    Write-Host "   1. 确保 Sealed Secrets Controller 已部署到集群" -ForegroundColor Gray
    Write-Host "      kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   2. 确保可以访问集群" -ForegroundColor Gray
    Write-Host "      kubectl cluster-info" -ForegroundColor Gray
    Write-Host ""
    Write-Host "   3. 如果 controller 名称不同，使用:" -ForegroundColor Gray
    Write-Host "      kubeseal --controller-name <name> --controller-namespace <namespace> ..." -ForegroundColor Gray
    exit 1
}
