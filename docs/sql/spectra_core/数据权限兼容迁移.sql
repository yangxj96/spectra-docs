-- ============================================================
-- 数据权限安全基线兼容迁移
--
-- 适用范围：已存在 sys_role.scope / sys_*_data_scope 表的环境。
-- 目标：统一活动范围唯一性、补齐查询索引、把旧角色 scope 回填到规范表。
-- 执行前：先在备份库执行下方重复数据检查；生产执行需走变更审批。
-- ============================================================

BEGIN;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM spectra_core.sys_user_data_scope
        WHERE deleted IS NULL
        GROUP BY user_id
        HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION 'sys_user_data_scope 存在同一用户多条活动记录，请先人工合并';
    END IF;
    IF EXISTS (
        SELECT 1
        FROM spectra_core.sys_role_data_scope
        WHERE deleted IS NULL
        GROUP BY role_id
        HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION 'sys_role_data_scope 存在同一角色多条活动记录，请先人工合并';
    END IF;
END
$$;

-- 旧角色范围字段回填。已存在规范记录的角色不重复写入。
INSERT INTO spectra_core.sys_role_data_scope
    (id, role_id, scope_type, created_at, updated_at, version)
SELECT gen_random_uuid(), r.id, r.scope, NOW(), NOW(), 0
FROM spectra_core.sys_role r
WHERE r.scope IS NOT NULL
  AND r.deleted IS NULL
  AND NOT EXISTS (
      SELECT 1
      FROM spectra_core.sys_role_data_scope s
      WHERE s.role_id = r.id
        AND s.deleted IS NULL
  );

CREATE UNIQUE INDEX IF NOT EXISTS uk_sys_user_data_scope_active
    ON spectra_core.sys_user_data_scope (user_id)
    WHERE deleted IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uk_sys_role_data_scope_active
    ON spectra_core.sys_role_data_scope (role_id)
    WHERE deleted IS NULL;

CREATE INDEX IF NOT EXISTS idx_sys_user_data_scope_target_active
    ON spectra_core.sys_user_data_scope_target (user_id, target_id)
    WHERE deleted IS NULL;

CREATE INDEX IF NOT EXISTS idx_sys_role_data_scope_target_active
    ON spectra_core.sys_role_data_scope_target (role_id, target_id)
    WHERE deleted IS NULL;

COMMIT;

-- 回滚（仅回滚本迁移新增的索引；角色 scope 回填需根据备份人工确认后删除）：
-- DROP INDEX IF EXISTS spectra_core.uk_sys_user_data_scope_active;
-- DROP INDEX IF EXISTS spectra_core.uk_sys_role_data_scope_active;
-- DROP INDEX IF EXISTS spectra_core.idx_sys_user_data_scope_target_active;
-- DROP INDEX IF EXISTS spectra_core.idx_sys_role_data_scope_target_active;
