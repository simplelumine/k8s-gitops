# PostgreSQL 架构决策指南

## 架构选择：共享 vs 独立

### 决策树

```
应用是核心业务？
├─ 是 → 独立 PostgreSQL 实例
└─ 否 → 继续判断
    ├─ 数据量 > 50GB？
    │   ├─ 是 → 独立实例
    │   └─ 否 → 继续判断
    └─ QPS > 500？
        ├─ 是 → 独立实例
        └─ 否 → 共享实例
```

---

## 推荐架构

### 方案：混合部署

```
databases namespace:
├── postgresql-shared       # 轻量级应用共享
│   ├── database: langflow
│   ├── database: n8n
│   └── database: nocodb
│
├── postgresql-litellm      # 核心应用独立
└── postgresql-open-webui   # 核心应用独立
```

---

## 配置示例

### 1. 共享 PostgreSQL 实例

```yaml
# data-infra/databases/shared/application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: postgresql-shared
  namespace: argocd
spec:
  project: default
  sources:
    # Source 1: PostgreSQL Helm Chart
    - repoURL: 'https://charts.bitnami.com/bitnami'
      chart: postgresql
      targetRevision: 15.5.38
      helm:
        valuesObject:
          auth:
            enablePostgresUser: true
            postgresPassword: <use-sealed-secret>

          primary:
            persistence:
              enabled: true
              size: 20Gi
              storageClass: longhorn

            resources:
              requests:
                cpu: 250m
                memory: 512Mi
              limits:
                cpu: 1000m
                memory: 2Gi

            # 初始化脚本
            initdb:
              scripts:
                init.sql: |
                  -- 创建多个 database
                  CREATE DATABASE langflow;
                  CREATE DATABASE n8n;
                  CREATE DATABASE nocodb;

                  -- 为每个应用创建独立用户
                  CREATE USER langflow_user WITH PASSWORD 'changeme';
                  GRANT ALL PRIVILEGES ON DATABASE langflow TO langflow_user;

                  CREATE USER n8n_user WITH PASSWORD 'changeme';
                  GRANT ALL PRIVILEGES ON DATABASE n8n TO n8n_user;

                  CREATE USER nocodb_user WITH PASSWORD 'changeme';
                  GRANT ALL PRIVILEGES ON DATABASE nocodb TO nocodb_user;

    # Source 2: Secrets and additional configs
    - repoURL: 'git@github.com:SimpleLumine/k8s-gitops.git'
      targetRevision: HEAD
      path: tenants/us-west/data-infra/databases/shared/manifests

  destination:
    server: 'https://kubernetes.default.svc'
    namespace: databases

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

**连接字符串示例：**
```
Langflow:  postgresql://langflow_user:password@postgresql-shared.databases.svc.cluster.local:5432/langflow
n8n:       postgresql://n8n_user:password@postgresql-shared.databases.svc.cluster.local:5432/n8n
NocoDB:    postgresql://nocodb_user:password@postgresql-shared.databases.svc.cluster.local:5432/nocodb
```

---

### 2. 独立 PostgreSQL 实例（LiteLLM）

```yaml
# data-infra/databases/litellm/application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: postgresql-litellm
  namespace: argocd
spec:
  project: default
  source:
    repoURL: 'https://charts.bitnami.com/bitnami'
    chart: postgresql
    targetRevision: 15.5.38
    helm:
      valuesObject:
        auth:
          database: litellm
          username: litellm
          password: <use-sealed-secret>

        primary:
          persistence:
            enabled: true
            size: 50Gi  # 更大的存储
            storageClass: longhorn

          resources:
            requests:
              cpu: 500m     # 更多资源
              memory: 1Gi
            limits:
              cpu: 2000m
              memory: 4Gi

          # 性能调优
          extendedConfiguration: |
            max_connections = 200
            shared_buffers = 1GB
            effective_cache_size = 3GB
            work_mem = 16MB

  destination:
    server: 'https://kubernetes.default.svc'
    namespace: databases

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

**连接字符串：**
```
postgresql://litellm:password@postgresql-litellm.databases.svc.cluster.local:5432/litellm
```

---

## 资源消耗对比

### 共享实例（5个应用）

```
1个 PostgreSQL Pod:
  CPU: 1 core
  Memory: 2GB
  Storage: 20GB

总计: 1 core, 2GB RAM
```

### 独立实例（5个应用）

```
5个 PostgreSQL Pods:
  CPU: 5 cores
  Memory: 10GB
  Storage: 100GB

总计: 5 cores, 10GB RAM
```

**节省：80% 资源**（如果使用共享实例）

---

## 安全考虑

### 共享实例的安全措施

1. **每个应用独立的数据库用户**
   ```sql
   CREATE USER app_user WITH PASSWORD 'secure-password';
   GRANT CONNECT ON DATABASE app_db TO app_user;
   REVOKE ALL ON DATABASE other_db FROM app_user;
   ```

2. **行级安全（RLS）**
   ```sql
   ALTER TABLE sensitive_data ENABLE ROW LEVEL SECURITY;
   CREATE POLICY app_isolation ON sensitive_data
     FOR ALL TO app_user
     USING (tenant_id = current_setting('app.tenant_id'));
   ```

3. **连接限制**
   ```sql
   ALTER USER app_user CONNECTION LIMIT 20;
   ```

4. **Schema 隔离**
   ```sql
   CREATE SCHEMA langflow;
   GRANT ALL ON SCHEMA langflow TO langflow_user;
   SET search_path TO langflow;
   ```

---

## 迁移策略

### 从共享迁移到独立

当应用增长到需要独立实例时：

**步骤：**

1. **创建独立实例**
   ```bash
   # 部署新的独立 PostgreSQL
   kubectl apply -f postgresql-litellm.yaml
   ```

2. **数据迁移**
   ```bash
   # 从共享实例导出
   pg_dump -h postgresql-shared.databases \
           -U litellm_user \
           -d litellm > litellm.sql

   # 导入到独立实例
   psql -h postgresql-litellm.databases \
        -U litellm \
        -d litellm < litellm.sql
   ```

3. **切换应用连接**
   ```yaml
   # 更新应用的数据库连接
   DATABASE_URL: postgresql://litellm:pass@postgresql-litellm.databases:5432/litellm
   ```

4. **验证后清理**
   ```sql
   -- 在共享实例中删除旧数据
   DROP DATABASE litellm;
   DROP USER litellm_user;
   ```

---

## 监控建议

### 共享实例监控指标

关注以下指标，决定是否需要拆分：

```
1. 连接数
   - 总连接数 > 80% max_connections
   → 考虑拆分

2. CPU 使用率
   - 持续 > 70%
   → 考虑拆分

3. 查询延迟
   - P95 延迟 > 100ms
   → 检查慢查询，可能需要拆分

4. 锁等待
   - 频繁出现锁等待
   → 考虑拆分

5. 磁盘 I/O
   - IOPS 接近限制
   → 考虑拆分
```

---

## 备份策略

### 共享实例备份

```yaml
# 使用 PostgreSQL 的逻辑备份
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgresql-shared-backup
  namespace: databases
spec:
  schedule: "0 2 * * *"  # 每天凌晨 2 点
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:16
            command:
            - /bin/sh
            - -c
            - |
              # 备份所有 database
              for db in langflow n8n nocodb; do
                pg_dump -h postgresql-shared \
                        -U postgres \
                        -d $db \
                        -F c \
                        -f /backup/$db-$(date +%Y%m%d).dump
              done
            volumeMounts:
            - name: backup
              mountPath: /backup
          volumes:
          - name: backup
            persistentVolumeClaim:
              claimName: postgres-backup-pvc
          restartPolicy: OnFailure
```

### 独立实例备份

```yaml
# 可以使用 Longhorn 快照
# 或者 PostgreSQL 的 PITR（Point-in-Time Recovery）
```

---

## 最佳实践总结

### ✅ 推荐做法

1. **初期：共享实例**
   - 快速启动
   - 节省资源
   - 易于管理

2. **监控并评估**
   - 定期检查性能指标
   - 识别需要独立的应用

3. **按需拆分**
   - 关键应用独立
   - 非关键应用共享

4. **统一管理**
   - 所有 PostgreSQL 都在 `databases` namespace
   - 统一的备份和监控策略

### ❌ 避免的做法

1. 一开始就全部独立（资源浪费）
2. 永远都共享（性能瓶颈）
3. 混合在应用 namespace（管理混乱）
4. 没有备份策略（数据风险）

---

## 具体建议（针对您的场景）

### 初期部署

```
1. postgresql-shared (共享)
   ├── langflow
   ├── n8n
   └── 其他工具

2. postgresql-litellm (独立)
   └── 如果 LiteLLM 是核心服务

3. postgresql-open-webui (独立)
   └── 如果 Open-WebUI 是主要入口
```

### 何时调整

**拆分信号：**
- 共享实例 CPU > 70%
- 某个应用的查询占用 > 50% 资源
- 出现跨应用的锁竞争

**合并信号：**
- 独立实例 CPU < 10%
- 数据量 < 5GB
- QPS < 10

---

## 参考资源

- [PostgreSQL High Availability](https://www.postgresql.org/docs/current/high-availability.html)
- [Bitnami PostgreSQL Helm Chart](https://github.com/bitnami/charts/tree/main/bitnami/postgresql)
- [Database Sharding vs Partitioning](https://www.postgresql.org/docs/current/ddl-partitioning.html)