# cert-manager Ingress 配置示例

## 基本 Ingress 配置

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
  namespace: default
  annotations:
    # 指定使用哪个 ClusterIssuer（staging 或 production）
    cert-manager.io/cluster-issuer: letsencrypt-staging

    # 可选：其他 Ingress 注解
    # nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx  # 或者您使用的 Ingress Controller

  # TLS 配置
  tls:
  - hosts:
    - app.yourdomain.com
    secretName: my-app-tls  # cert-manager 会自动创建这个 Secret

  # 路由规则
  rules:
  - host: app.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app-service
            port:
              number: 80
```

## 通配符证书配置

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: wildcard-ingress
  namespace: default
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-staging
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - "*.yourdomain.com"    # 通配符域名
    - yourdomain.com         # 也包含根域名
    secretName: wildcard-tls
  rules:
  - host: "*.yourdomain.com"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: default-backend
            port:
              number: 80
```

## 多域名证书配置

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: multi-domain-ingress
  namespace: default
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-production
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - app1.yourdomain.com
    - app2.yourdomain.com
    - app3.yourdomain.com
    secretName: multi-domain-tls  # 一个证书包含多个域名
  rules:
  - host: app1.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app1-service
            port:
              number: 80
  - host: app2.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: app2-service
            port:
              number: 80
```

## 使用 Certificate 资源（推荐用于复杂场景）

如果您需要更精细的控制，可以直接创建 Certificate 资源：

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: my-app-certificate
  namespace: default
spec:
  # 证书存储的 Secret 名称
  secretName: my-app-tls

  # 使用的 Issuer
  issuerRef:
    name: letsencrypt-production
    kind: ClusterIssuer

  # 域名列表
  dnsNames:
    - app.yourdomain.com
    - www.yourdomain.com

  # 证书有效期（可选，默认 90 天）
  duration: 2160h  # 90 天
  renewBefore: 360h  # 提前 15 天续期
```

然后在 Ingress 中引用这个 Secret：

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app-ingress
  namespace: default
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - app.yourdomain.com
    secretName: my-app-tls  # 引用 Certificate 创建的 Secret
  rules:
  - host: app.yourdomain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: my-app-service
            port:
              number: 80
```

## 关键 Annotation 说明

### 必需的 Annotation

```yaml
cert-manager.io/cluster-issuer: letsencrypt-staging
```

或

```yaml
cert-manager.io/cluster-issuer: letsencrypt-production
```

### 可选的 Annotation

```yaml
# 指定使用 Issuer 而非 ClusterIssuer
cert-manager.io/issuer: my-issuer

# 指定使用的 ACME 挑战方式（通常自动选择）
cert-manager.io/acme-challenge-type: dns01

# 自定义证书配置
cert-manager.io/common-name: "app.yourdomain.com"
cert-manager.io/duration: "2160h"
cert-manager.io/renew-before: "360h"
```

## 常见场景

### Staging vs Production

**测试阶段（推荐先用）：**
```yaml
annotations:
  cert-manager.io/cluster-issuer: letsencrypt-staging
```

- 没有速率限制
- 证书不被浏览器信任（测试用）
- 验证配置是否正确

**生产环境：**
```yaml
annotations:
  cert-manager.io/cluster-issuer: letsencrypt-production
```

- 有速率限制（每周 50 个证书/域名）
- 证书被浏览器信任
- 配置测试通过后使用

### 验证证书状态

```bash
# 查看 Certificate 资源
kubectl get certificate -n default

# 查看证书详情
kubectl describe certificate my-app-certificate -n default

# 查看生成的 Secret
kubectl get secret my-app-tls -n default

# 查看 cert-manager 日志
kubectl logs -n cert-manager deployment/cert-manager --tail=50
```

## 故障排查

### 证书未自动创建

1. 检查 Ingress annotation 是否正确
2. 检查 ClusterIssuer 是否 Ready
   ```bash
   kubectl get clusterissuer
   ```
3. 查看 cert-manager 日志
   ```bash
   kubectl logs -n cert-manager deployment/cert-manager
   ```

### DNS 验证失败

1. 确认域名在 Cloudflare
2. 确认 API Token 权限正确
3. 查看 Challenge 资源
   ```bash
   kubectl get challenges --all-namespaces
   kubectl describe challenge <challenge-name> -n <namespace>
   ```

### 证书一直 Pending

```bash
# 查看 CertificateRequest
kubectl get certificaterequest -n default

# 查看 Order
kubectl get order -n default

# 详细信息
kubectl describe certificate <cert-name> -n <namespace>
```

## Let's Encrypt 速率限制

**Production 环境限制：**
- 每个注册域名每周 50 个证书
- 每个证书最多 100 个域名
- 每个账户每小时 300 个待处理授权
- 每个 IP 地址每 3 小时 10 次失败验证

**Staging 环境：**
- 没有速率限制
- 适合测试

**参考：** https://letsencrypt.org/docs/rate-limits/
