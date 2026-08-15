# Security Audit 归档与恢复 Runbook

## 已选后端

首版选择 S3-compatible Object Lock（Compliance mode）作为安全审计归档介质：

- 单独的 `S3_SECURITY_AUDIT_ARCHIVE_BUCKET`，不得与普通文件上传 bucket 共用；
- bucket 必须在平台侧开启 Object Lock/WORM、版本保护、服务端加密和跨可用区备份；
- Object Lock 保留期限至少覆盖 `total_retention_years`，默认热存 12 个月、总保留 5 年；
- 对象写入携带 SHA-256 metadata、归档保留截止时间和不可变 key；
- 应用只拥有归档对象写入/读取校验能力，不拥有删除、覆盖、缩短保留期限或修改 manifest 的权限。

代码端口为 `SecurityAuditArchiveBackend`，S3 实现仅在 `spectra.security.audit-archive-backend=S3_OBJECT_LOCK` 时装配。V9 manifest 仍是归档状态事实，归档自身通过 `SecurityAuditArchiveAuditTrail` 写入 started/completed/failed/verified 事件。

## 归档流程

1. 查询满足热存期限的完整 PostgreSQL 分区，并创建 `PLANNED` manifest。
2. 写入 `SECURITY_AUDIT_ARCHIVE_STARTED`。
3. 以稳定排序导出分区内容，计算 SHA-256 和行数；内容写入独立 Object Lock bucket。
4. 将 URI、摘要、行数和 retain-until 写入 manifest；应用 runtime 账号不能执行这一步的任意写入，必须由受控归档身份完成。
5. 从对象存储重新读取并计算摘要；一致后写入 `VERIFIED` 和 `SECURITY_AUDIT_ARCHIVE_VERIFIED`。
6. 只有在恢复验证、独立复核和保留期限核对全部通过后，才允许数据库负责人执行分区 detach；归档失败不得卸载热数据。

## 恢复验证

- 先将对象恢复到隔离 PostgreSQL 临时表，不直接覆盖在线审计表；
- 校验 manifest 的 range、row count、SHA-256、event ID/occurred_at 主键唯一性和 JSONB 可解析性；
- 通过审计查询服务验证可见性、二次脱敏、分页和导出；
- 记录恢复耗时、失败点和查询 SLA；
- 恢复验证通过后写入 `RESTORED`，失败写入 `FAILED` 并保留原对象；
- 任何最终处置必须晚于最低 5 年保留期，并取得外部治理批准；应用不提供删除接口。

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
