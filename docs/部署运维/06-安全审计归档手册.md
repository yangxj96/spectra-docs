# Security Audit 归档与恢复 Runbook

> 生效条件：`1.0.0` 发布前完成独立 S3 Object Lock bucket、Compliance retention、完整性校验和隔离恢复门禁。

## 已选后端

首版选择 S3-compatible Object Lock（Compliance mode）作为安全审计归档介质：

- 单独的 `S3_SECURITY_AUDIT_ARCHIVE_BUCKET`，不得与普通文件上传 bucket 共用；
- bucket 必须在平台侧开启 Object Lock/WORM、版本保护、服务端加密和跨可用区备份；
- Object Lock 保留期限至少覆盖 `total_retention_years`，默认热存 12 个月、总保留 5 年；
- 对象写入携带 SHA-256 metadata、归档保留截止时间和不可变 key；
- 应用只拥有归档对象写入/读取校验能力，不拥有删除、覆盖、缩短保留期限或修改 manifest 的权限。

代码端口为 `com.devops00.spectra.common.port.audit.SecurityAuditArchiveBackend`，S3 实现仅在 `spectra.security.audit-archive-backend=S3_OBJECT_LOCK` 时由 Core 的 upload 子域装配。`sec_security_audit_archive_manifest` 是归档状态事实，Core worker 负责租约、重试、完整性校验和恢复状态，归档自身通过 `SecurityAuditArchiveAuditTrail` 写入 planned/started/completed/failed/verified/restored 事件。开发环境默认策略 `archive_backend=PENDING`，没有对象存储时保持待处理状态，不将本地文件或普通上传 bucket 伪装成安全归档。

## 归档流程

1. 由 `ROLE_DEV_OPS` 调用 `POST /api/1.0.0/security/audit/archive/plan`，校验分区名、半开时间范围和活动保留策略，创建 `PLANNED` manifest。
2. Core worker 按 PostgreSQL 租约领取 manifest；策略为 `PENDING` 或没有匹配后端时失败重试，不伪造成功。
3. 以稳定排序导出分区内容，计算 SHA-256、UTF-8 字节长度和行数；内容写入独立 Object Lock bucket。
4. 将 URI、摘要、字节长度和行数写入 manifest，进入 `ARCHIVED`；对象写入必须具备幂等 key 和保留截止时间。
5. worker 重新读取对象，校验存在性、SHA-256、字节长度，并重新读取源分区校验范围、行数和内容摘要；全部一致后才进入 `VERIFIED`。
6. 只有在恢复验证、独立复核和保留期限核对全部通过后，才允许数据库负责人执行分区 detach；归档失败不得卸载、删除或标记删除源热数据。

## 恢复验证

- 先将对象恢复到隔离 PostgreSQL 临时表，不直接覆盖在线审计表；
- 校验 manifest 的 range、row count、SHA-256、event ID/occurred_at 主键唯一性和 JSONB 可解析性；
- 通过审计查询服务验证可见性、二次脱敏、分页和导出；
- 记录恢复耗时、失败点和查询 SLA；
- 恢复验证通过后写入 `RESTORED`，失败写入 `FAILED` 并保留原对象；
- 正式 API 仅提供计划、状态、失败重试、恢复申请和校验：`GET /api/1.0.0/security/audit/archive/{manifestId}`、`POST .../{manifestId}/retry`、`POST .../{manifestId}/restore`、`POST .../{manifestId}/verify`；所有归档运维写操作要求 `ROLE_DEV_OPS`，不提供删除/覆盖接口；
- 任何最终处置必须晚于最低 5 年保留期，并取得外部治理批准；应用不提供删除接口。

## 失败处置与观测

- outbox 和归档 worker 都使用 `FOR UPDATE SKIP LOCKED`、租约续期、指数退避、最大尝试次数和 `DEAD_LETTER/FAILED` 状态；人工重试必须保留原失败原因和审计事件。
- 重点观察待处理数量、最老事件年龄、归档延迟、失败次数、校验失败次数、恢复次数和租约超时；对象存储故障恢复后先验证积压，再执行源分区处置。
- 本机开发验证只运行单元测试、静态 migration/schema 检查和编译测试；不依赖 Docker，也不连接或改动本机 PostgreSQL 服务。

## 上线前必填项

```text
SPECTRA_SECURITY_AUDIT_ARCHIVE_BACKEND=S3_OBJECT_LOCK
S3_SECURITY_AUDIT_ARCHIVE_BUCKET=<独立的已启用 Object Lock bucket>
S3_SECURITY_AUDIT_ARCHIVE_PREFIX=security-audit/
Object Lock 模式=COMPLIANCE
保留期限>=5 年：是/否
对象版本、加密、跨区备份：是/否
首次写入/读取/篡改校验/恢复演练编号：
```
