# Security 数据库备份、恢复、全局登出与回滚 Runbook

> 本文只描述流程和证据要求，不包含生产连接串、密码、密钥或真实备份位置。执行必须由数据库负责人和 Security/Audit Owner 共同授权。

## 适用范围

适用于 Security 重构 cutover、Flyway 升级、权限大批量变更、MFA/Session 故障和安全事件。应用账号不能更新/删除 Security Audit；备份与恢复使用独立数据库运维权限。

## 变更前门禁

1. 记录变更单、事件编号、目标 Flyway 版本、回滚负责人和独立复核人。
2. 对 `spectra_core`、`spectra_security`、`spectra_notification`、`spectra_oa` 和 `spectra_workflow` 做一致性快照或可恢复备份。
3. 备份完成后执行独立校验，并在隔离数据库恢复至少一次；只验证“备份文件存在”不算通过。
4. 记录当前 `root_policy`、有效 DEV_OPS 数量、活动 Assignment、Session policy、MFA enrollment 数量和 Redis key namespace 统计。
5. 明确全局 logout 的执行窗口。Security Redis 不可用时不得宣称已完成全局 logout，也不得用本地缓存替代撤销。

## 恢复验收

恢复到隔离 PostgreSQL 后至少验证：

- Flyway history 连续且校验通过；
- `security_audit_event` 仍可追加，更新/删除 trigger 仍拒绝；
- `root_policy` 和有效 DEV_OPS 数量满足最小 Root 约束；
- RoleAssignment、Permission Boundary、AuthenticationIdentity、PasswordCredential、MFA 和 Recovery Code 数量与备份报告一致；
- `security_audit_archive_manifest` 的摘要、对象 URI 和状态可查询；
- Redis 使用 `sec:v2:*` namespace，抽样 Token Digest 不会在日志或响应中出现；
- 使用测试账户完成登录、刷新、logout、全局 revoke 后，旧 Access/Refresh Token 均被拒绝。

## 全局登出步骤

1. 先写入 `SECURITY_GLOBAL_LOGOUT_STARTED` 审计事件；Audit 不可用则停止。
2. 通过 `SecuritySessionRevocationPort` 按用户、Client 或全量撤销；禁止直接删除任意业务 Redis key。
3. 验证 `sec:v2:session:*`、Token family 和 replay revoke 结果，并保留数量证据；不记录 token 原文。
4. 追加 `SECURITY_GLOBAL_LOGOUT_SUCCEEDED` 或 `SECURITY_GLOBAL_LOGOUT_FAILED`。
5. 让 Web/App 重新登录并验证 Refresh rotation；旧 Refresh Token 必须被拒绝。

## 回滚规则

- 数据库迁移不使用 `baselineOnMigrate`，不使用 Flyway clean 作为回滚。
- 发现结构或权限异常时，先停止写流量、冻结高风险安全写，再从已验证快照恢复到隔离环境确认方案。
- 任何回滚都必须保留故障期间新增 Audit，不能通过恢复旧快照覆盖或删除安全事实；必要时将恢复前后的审计导出合并归档。
- 回滚后重新执行 Root、Audit append-only、Redis fail-closed、Cookie/CSRF 和旧 Token 失效验收。
- 没有经过隔离恢复验证、未确认数据时间点和责任人的方案，不得在生产执行。

## 证据清单

变更单、备份摘要、恢复日志、Flyway history、Root/Assignment 计数、Audit append-only 结果、Redis revoke 计数、登录/刷新/logout 测试结果、告警编号和复盘结论必须关联事件编号保存。证据中不得包含密码、Token、TOTP Secret、Recovery Code 或私钥。
