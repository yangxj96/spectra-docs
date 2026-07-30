-- ============================================================
-- V20260730_03: 删除菜单旧路由字段
--
-- 执行者：用户手动执行
-- 前置条件：后端和 spectra-ui 已不再读取旧字段，完整回归通过。
-- ============================================================

BEGIN;

DO $$
DECLARE
    invalid_menu_count INTEGER;
    invalid_relation_count INTEGER;
    required_constraint_count INTEGER;
    required_index_count INTEGER;
    required_not_null_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO invalid_menu_count
    FROM spectra_core.sys_menu
    WHERE deleted IS NULL
      AND (menu_type IS NULL
        OR (menu_type = 'DIRECTORY' AND route_name IS NOT NULL)
        OR (menu_type = 'MENU' AND route_name IS NULL));

    SELECT COUNT(*)
    INTO invalid_relation_count
    FROM spectra_core.sys_rel_role_menu relation
    LEFT JOIN spectra_core.sys_menu menu
      ON menu.id = relation.menu_id AND menu.deleted IS NULL
    WHERE relation.deleted IS NULL
      AND (menu.id IS NULL OR menu.menu_type <> 'MENU');

    SELECT COUNT(*)
    INTO required_constraint_count
    FROM pg_constraint
    WHERE conrelid = 'spectra_core.sys_menu'::regclass
      AND conname IN ('ck_sys_menu_type', 'ck_sys_menu_route_binding')
      AND convalidated IS TRUE;

    SELECT COUNT(*)
    INTO required_index_count
    FROM pg_indexes
    WHERE schemaname = 'spectra_core'
      AND ((indexname = 'uk_sys_menu_route_name_active'
            AND indexdef LIKE '%(route_name)%'
            AND indexdef LIKE '%deleted IS NULL%')
        OR (indexname = 'uk_sys_rel_role_menu_active'
            AND indexdef LIKE '%(role_id, menu_id)%'
            AND indexdef LIKE '%deleted IS NULL%'));

    SELECT COUNT(*)
    INTO required_not_null_count
    FROM information_schema.columns
    WHERE table_schema = 'spectra_core'
      AND table_name = 'sys_menu'
      AND column_name IN ('menu_type', 'sort')
      AND is_nullable = 'NO';

    IF invalid_menu_count > 0
        OR invalid_relation_count > 0
        OR required_constraint_count <> 2
        OR required_index_count <> 2
        OR required_not_null_count <> 2 THEN
        RAISE EXCEPTION '禁止删除旧字段：菜单=%，角色菜单关系=%，约束=%/2，索引=%/2，非空列=%/2',
            invalid_menu_count, invalid_relation_count, required_constraint_count,
            required_index_count, required_not_null_count;
    END IF;
END
$$;

ALTER TABLE spectra_core.sys_menu
    DROP COLUMN IF EXISTS path,
    DROP COLUMN IF EXISTS component,
    DROP COLUMN IF EXISTS layout,
    DROP COLUMN IF EXISTS hide,
    DROP COLUMN IF EXISTS metadata;

DO $$
DECLARE
    legacy_column_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO legacy_column_count
    FROM information_schema.columns
    WHERE table_schema = 'spectra_core'
      AND table_name = 'sys_menu'
      AND column_name IN ('path', 'component', 'layout', 'hide', 'metadata');

    IF legacy_column_count > 0 THEN
        RAISE EXCEPTION '仍存在 % 个菜单旧字段，迁移已回滚', legacy_column_count;
    END IF;
END
$$;

COMMIT;
