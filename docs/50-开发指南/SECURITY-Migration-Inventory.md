# Security 迁移前数据盘点与权限映射

> 本文是迁移门禁和报告模板，不保存生产用户名、手机号、邮箱、密码、Token 或密钥。查询必须使用只读账号，并在隔离报告目录保存结果。

## 当前开发数据基线

当前开发数据库 `devops00_spectra_db` 没有旧账号、旧 user-level Scope 或旧业务数据，旧账号已清理，因此不需要执行 Scope 到 Permission Boundary 的逐账号映射。未来导入历史业务库或恢复包含旧 Scope 的备份时，再按本文执行逐条盘点和人工映射门禁。

## 目标

迁移前必须确认：

- 当前有效管理员、`DEV_OPS`、`SYSTEM_ADMIN` 和 Root 数量满足 `root_policy`；
- 用户生命周期、认证身份、密码凭据和活动 RoleAssignment 可追溯；
- 历史 user-level/role-level Scope 的每一条记录都由业务负责人映射到具体 `(RoleAssignment, Permission)` Boundary；
- 没有任何旧 Scope 被自动转换为 `GrantablePermission` 或 Grant Boundary。

## 只读盘点查询

以下查询只返回聚合或内部 UUID。执行前先确认数据库已完成对应 Flyway 迁移；旧表不存在时只记录“无旧表”，不要为了查询恢复兼容表。

```sql
-- 1. 用户生命周期聚合
SELECT status, COUNT(*) AS user_count
FROM spectra_core.sys_user
WHERE deleted IS NULL
GROUP BY status
ORDER BY status;

-- 2. Role 与有效 Assignment 聚合
SELECT r.code,
       r.role_kind,
       r.state,
       COUNT(DISTINCT ra.user_id) FILTER (WHERE ra.state = 'ACTIVE') AS active_user_count,
       COUNT(*) FILTER (WHERE ra.state = 'ACTIVE') AS active_assignment_count
FROM spectra_security.sec_role r
LEFT JOIN spectra_security.sec_role_assignment ra ON ra.role_id = r.id
GROUP BY r.code, r.role_kind, r.state
ORDER BY r.role_kind, r.code;

-- 3. Root policy 与有效 DEV_OPS 数量
SELECT rp.min_effective_dev_ops_users,
       rp.max_dev_ops_users,
       COUNT(DISTINCT ra.user_id) AS effective_dev_ops_users
FROM spectra_security.sec_root_policy rp
LEFT JOIN spectra_security.sec_role r ON r.role_kind = 'DEV_OPS' AND r.state = 'ACTIVE'
LEFT JOIN spectra_security.sec_role_assignment ra
       ON ra.role_id = r.id AND ra.state = 'ACTIVE'
GROUP BY rp.min_effective_dev_ops_users, rp.max_dev_ops_users;

-- 4. 认证身份和密码覆盖率（只返回数量）
SELECT
    (SELECT COUNT(*) FROM spectra_core.sys_user WHERE deleted IS NULL) AS users,
    (SELECT COUNT(DISTINCT user_id) FROM spectra_security.sec_authentication_identity WHERE state = 'ACTIVE') AS users_with_identity,
    (SELECT COUNT(*) FROM spectra_security.sec_password_credential) AS password_credentials;

-- 5. Permission-specific Boundary 覆盖情况
SELECT COUNT(*) AS access_boundary_count
FROM spectra_security.sec_assignment_permission_boundary;
SELECT COUNT(*) AS grant_boundary_count
FROM spectra_security.sec_assignment_grant_boundary;
```

## Scope 人工映射清单

历史 Scope 每条记录必须进入受控清单，完成业务负责人和安全负责人双重复核后，才允许调用 RoleAssignment Preview/Apply：

| 字段 | 要求 |
|---|---|
| `legacy_scope_id` | 旧记录内部 ID；不能只填名称 |
| `user_id` / `role_id` | 受影响主体；无法唯一确定时阻断迁移 |
| `target_assignment_id` | 目标 RoleAssignment；不得使用用户全局 Scope |
| `permission_code` | 具体目标 Permission；不得只映射到 Role |
| `scope_mode` | `NONE` / `ALL` / `SELF` / `RULES`，缺失不等于 `NONE` |
| `rule_type` / `rule_payload` | 仅允许已注册 ResourceScopePolicy；未登记规则统一 deny |
| `grant_boundary` | 默认 `NONE`；只有明确批准才允许写入 Grant Boundary |
| `business_reviewer` / `security_reviewer` | 姓名、工号或外部审批单号 |
| `reviewed_at` / `applied_at` | 复核和实际 Apply 时间 |

迁移门禁：存在未映射、重复映射、无 Permission、无 Assignment、规则无法编译或超出 Root/权限边界的记录时，停止 cutover。旧运行时结构的清理已合并到当前 V1 基线，不负责猜测业务权限。

## 报告结论模板

```text
盘点批次：
数据库快照时间：
Flyway 版本：
有效 DEV_OPS / min / max：
ACTIVE 用户 / LOCKED / DISABLED / DEPARTED：
有认证身份用户数 / 有密码凭据用户数：
待人工 Scope 映射数：
未决高风险项：
业务负责人：
安全负责人：
结论：PASS / BLOCKED
```
