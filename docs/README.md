# 📚 K8s GitOps 文档中心

欢迎查阅 K8s GitOps 仓库的文档！

## 📖 文档目录

### 🚀 快速开始

1. **[部署指南 (DEPLOY.md)](DEPLOY.md)** ⭐ 新手必读
   - 如何从零开始部署 ArgoCD
   - 从临时配置迁移到标准化配置
   - Bootstrap 步骤详解

### 🏗️ 架构与结构

2. **[GitOps 仓库结构说明 (GITOPS-STRUCTURE.md)](GITOPS-STRUCTURE.md)**
   - 整体目录结构
   - 设计原则
   - 工作流程
   - 安全最佳实践

3. **[目录结构示例 (DIRECTORY-STRUCTURE-EXAMPLES.md)](DIRECTORY-STRUCTURE-EXAMPLES.md)**
   - 各种目录结构方案（Helm/Manifests/Kustomize）
   - Root Application 的扫描规则
   - 完整的实际示例

### 🔐 安全与网络

4. **[Tailscale 安全说明 (TAILSCALE-SECURITY.md)](TAILSCALE-SECURITY.md)**
   - Tailscale 不是公网暴露
   - HTTP vs HTTPS on Tailscale
   - 域名解析机制
   - 安全性对比

### 🛠️ 工具配置

5. **[ArgoCD CLI 配置指南 (ARGOCD-CLI-SETUP.md)](ARGOCD-CLI-SETUP.md)**
   - 添加新的上下文（Tailscale）
   - 上下文管理
   - 测试连接
   - 故障排查

---

## 🎯 按使用场景查找

### 场景 1: 我是新手，第一次部署

1. 阅读 [GITOPS-STRUCTURE.md](GITOPS-STRUCTURE.md) 了解整体结构
2. 按照 [DEPLOY.md](DEPLOY.md) 的步骤部署
3. 阅读 [TAILSCALE-SECURITY.md](TAILSCALE-SECURITY.md) 理解安全模型

### 场景 2: 我想添加新的应用

1. 参考 [DIRECTORY-STRUCTURE-EXAMPLES.md](DIRECTORY-STRUCTURE-EXAMPLES.md)
2. 选择合适的目录结构（Helm/Manifests/Kustomize）
3. 创建 `application.yaml` 文件
4. 提交到 Git，等待自动同步

### 场景 3: 我想配置 ArgoCD CLI

1. 阅读 [ARGOCD-CLI-SETUP.md](ARGOCD-CLI-SETUP.md)
2. 添加 Tailscale 上下文
3. 测试连接

### 场景 4: 我在迁移现有配置

1. 阅读 [DEPLOY.md](DEPLOY.md) 的"场景 B: 从临时配置迁移"
2. 按照步骤执行迁移
3. 验证配置

### 场景 5: 我对安全性有疑问

1. 阅读 [TAILSCALE-SECURITY.md](TAILSCALE-SECURITY.md)
2. 理解 Tailscale 的安全模型
3. 了解为什么 HTTP 在 Tailnet 上是安全的

---

## 📂 仓库结构概览

```
k8s-gitops/
├── docs/                              # 📚 文档目录（你在这里）
│   ├── README.md                      # 文档索引
│   ├── DEPLOY.md                      # 部署指南
│   ├── GITOPS-STRUCTURE.md            # 结构说明
│   ├── DIRECTORY-STRUCTURE-EXAMPLES.md # 目录示例
│   ├── TAILSCALE-SECURITY.md          # 安全说明
│   └── ARGOCD-CLI-SETUP.md            # CLI 配置
│
├── bootstrap/                         # 🔧 引导目录（手动管理）
│   ├── README.md                      # Bootstrap 说明
│   ├── root-application.yaml          # Root Application
│   └── repository-secret.yaml.example # Git 凭证示例
│
├── tenants/                           # 🏢 租户目录
│   └── us-west/                       # 美西集群
│       ├── cluster-infra/             # 基础设施
│       │   ├── argocd/
│       │   ├── tailscale-operator/
│       │   └── longhorn/
│       └── applications/              # 业务应用（未来）
│
├── secret/                            # 🔐 敏感信息（不提交 Git）
│   └── argocd-repository-secret.yaml
│
├── .gitignore                         # Git 忽略规则
└── README.md                          # 项目主 README
```

---

## 🔗 外部资源

### ArgoCD 官方文档
- [ArgoCD 用户指南](https://argo-cd.readthedocs.io/en/stable/user-guide/)
- [Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)

### Tailscale 文档
- [Tailscale 快速入门](https://tailscale.com/kb/1017/install/)
- [Kubernetes Operator](https://tailscale.com/kb/1236/kubernetes-operator/)
- [安全白皮书](https://tailscale.com/security)

### GitOps 原则
- [GitOps Principles](https://www.gitops.tech/)
- [CNCF GitOps Working Group](https://github.com/cncf/tag-app-delivery/tree/main/gitops-wg)

---

## 💡 常见问题速查

### Q: Root Application 的 `include` 会影响子应用的 manifests 目录吗？
**A**: 不会。参见 [DIRECTORY-STRUCTURE-EXAMPLES.md](DIRECTORY-STRUCTURE-EXAMPLES.md#-root-application-的-include-过滤器)

### Q: Tailscale 域名是公网暴露吗？
**A**: 不是。参见 [TAILSCALE-SECURITY.md](TAILSCALE-SECURITY.md#-关键理解)

### Q: 为什么只能用 HTTP 不能用 HTTPS？
**A**: 因为配置了 `server.insecure: true`。参见 [TAILSCALE-SECURITY.md](TAILSCALE-SECURITY.md#-http-vs-https-on-tailscale)

### Q: HEAD vs main，应该用哪个？
**A**: 推荐用 `HEAD`。参见 [DEPLOY.md](DEPLOY.md)

### Q: 如何添加新的 ArgoCD CLI 上下文？
**A**: 参见 [ARGOCD-CLI-SETUP.md](ARGOCD-CLI-SETUP.md#-添加-tailscale-上下文)

### Q: Repository credentials 是怎么工作的？
**A**: 参见 [GITOPS-STRUCTURE.md](GITOPS-STRUCTURE.md#-安全最佳实践)

---

## 🤝 贡献

如果你发现文档有错误或需要改进，欢迎：
1. 直接编辑文档文件
2. 提交 PR（如果是团队协作）
3. 添加新的文档到这个目录

### 文档命名规范

- 使用大写字母和连字符：`MY-DOC-NAME.md`
- 文件名应该清晰表达内容
- 必须在这个 README 中添加索引

---

## 📝 文档更新日志

| 日期 | 文档 | 变更 |
|------|------|------|
| 2025-10-10 | 全部 | 创建文档中心，整理所有文档 |
| 2025-10-10 | DEPLOY.md | 添加部署指南 |
| 2025-10-10 | TAILSCALE-SECURITY.md | 添加安全说明 |
| 2025-10-10 | ARGOCD-CLI-SETUP.md | 添加 CLI 配置指南 |
| 2025-10-10 | DIRECTORY-STRUCTURE-EXAMPLES.md | 添加目录结构示例 |
| 2025-10-10 | GITOPS-STRUCTURE.md | 添加 GitOps 结构说明 |

---

## ⭐ 推荐阅读顺序

**完全新手：**
1. GITOPS-STRUCTURE.md - 了解整体
2. DEPLOY.md - 动手部署
3. TAILSCALE-SECURITY.md - 理解安全

**有 GitOps 经验：**
1. DIRECTORY-STRUCTURE-EXAMPLES.md - 看最佳实践
2. DEPLOY.md - 快速参考
3. ARGOCD-CLI-SETUP.md - 配置工具

**只想解决具体问题：**
- 直接查看"常见问题速查"部分
- 或使用 Ctrl+F 搜索关键词

---

**提示**: 所有文档都支持 Markdown 语法，可以在 IDE 中预览或在 GitHub 上阅读。
