-- ============================================================
-- V20260730_02: 切换菜单数据到导航权限模型
--
-- 执行者：用户手动执行
-- 前置条件：新版后端和 spectra-ui 已部署并通过阶段五验证。
-- ============================================================

BEGIN;

DO $$
DECLARE
    home_count INTEGER;
    dashboard_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO home_count
    FROM spectra_core.sys_menu
    WHERE deleted IS NULL AND name = '首页' AND pid IS NULL AND menu_type = 'DIRECTORY';

    SELECT COUNT(*) INTO dashboard_count
    FROM spectra_core.sys_menu
    WHERE deleted IS NULL AND route_name = 'Dashboard';

    IF home_count <> 1 OR dashboard_count <> 1 THEN
        RAISE EXCEPTION '首页数据不符合迁移前提：首页=%，首页默认=%', home_count, dashboard_count;
    END IF;
END
$$;

-- 将“首页默认”的角色授权合并到“首页”根节点。
WITH home AS (
    SELECT id
    FROM spectra_core.sys_menu
    WHERE deleted IS NULL AND name = '首页' AND pid IS NULL AND menu_type = 'DIRECTORY'
), dashboard AS (
    SELECT id
    FROM spectra_core.sys_menu
    WHERE deleted IS NULL AND route_name = 'Dashboard'
)
INSERT INTO spectra_core.sys_rel_role_menu (
    id, role_id, menu_id, created_by, created_at, updated_by, updated_at, deleted, version
)
SELECT DISTINCT ON (relation.role_id)
       uuidv7(), relation.role_id, home.id,
       relation.created_by, NOW(), relation.updated_by, NOW(), NULL, 0
FROM spectra_core.sys_rel_role_menu relation
CROSS JOIN home
CROSS JOIN dashboard
WHERE relation.deleted IS NULL
  AND relation.menu_id = dashboard.id
  AND NOT EXISTS (
      SELECT 1
      FROM spectra_core.sys_rel_role_menu existing
      WHERE existing.deleted IS NULL
        AND existing.role_id = relation.role_id
        AND existing.menu_id = home.id
  )
ORDER BY relation.role_id, relation.id;

-- 清理悬空关系、即将删除的隐藏页面、首页默认和所有目录关联。
UPDATE spectra_core.sys_rel_role_menu relation
SET deleted = NOW(),
    updated_at = NOW(),
    version = COALESCE(relation.version, 0) + 1
WHERE relation.deleted IS NULL
  AND (NOT EXISTS (
          SELECT 1
          FROM spectra_core.sys_menu active_menu
          WHERE active_menu.id = relation.menu_id
            AND active_menu.deleted IS NULL
      )
      OR relation.menu_id IN (
          SELECT menu.id
          FROM spectra_core.sys_menu menu
          WHERE menu.deleted IS NULL
            AND (menu.hide IS TRUE
              OR menu.route_name = 'Dashboard'
              OR (menu.menu_type = 'DIRECTORY'
                AND NOT (menu.name = '首页' AND menu.pid IS NULL)))
      ));

-- 隐藏页面改由前端静态路由提供；首页默认已合并到首页。
UPDATE spectra_core.sys_menu
SET deleted = NOW(),
    updated_at = NOW(),
    version = COALESCE(version, 0) + 1
WHERE deleted IS NULL
  AND (hide IS TRUE
    OR route_name = 'Dashboard');

-- “首页默认”软删除后释放 Dashboard 唯一路由名，首页成为顶部可点击菜单。
UPDATE spectra_core.sys_menu
SET menu_type = 'MENU',
    route_name = 'Dashboard',
    updated_at = NOW(),
    version = COALESCE(version, 0) + 1
WHERE deleted IS NULL
  AND name = '首页'
  AND pid IS NULL;

-- 历史软删除记录也补齐类型，使列可以设置 NOT NULL；
-- 活动记录的一致性由 ck_sys_menu_route_binding 约束。
UPDATE spectra_core.sys_menu
SET menu_type = 'MENU'
WHERE menu_type IS NULL;

UPDATE spectra_core.sys_menu
SET sort = 0
WHERE sort IS NULL;

ALTER TABLE spectra_core.sys_menu
    ALTER COLUMN menu_type SET NOT NULL,
    ALTER COLUMN sort SET DEFAULT 0,
    ALTER COLUMN sort SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'spectra_core.sys_menu'::regclass
          AND conname = 'ck_sys_menu_route_binding'
    ) THEN
        ALTER TABLE spectra_core.sys_menu
            ADD CONSTRAINT ck_sys_menu_route_binding
            CHECK (
                deleted IS NOT NULL
                OR (menu_type = 'DIRECTORY' AND route_name IS NULL)
                OR (menu_type = 'MENU' AND route_name IS NOT NULL)
            );
    END IF;
END
$$;

DO $$
DECLARE
    duplicate_relation_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO duplicate_relation_count
    FROM (
        SELECT role_id, menu_id
        FROM spectra_core.sys_rel_role_menu
        WHERE deleted IS NULL
        GROUP BY role_id, menu_id
        HAVING COUNT(*) > 1
    ) duplicate_relation;

    IF duplicate_relation_count > 0 THEN
        RAISE EXCEPTION '存在 % 组重复角色菜单关系，请先确认清理策略', duplicate_relation_count;
    END IF;
END
$$;

CREATE UNIQUE INDEX IF NOT EXISTS uk_sys_rel_role_menu_active
    ON spectra_core.sys_rel_role_menu (role_id, menu_id)
    WHERE deleted IS NULL;

DO $$
DECLARE
    invalid_menu_count INTEGER;
    invalid_relation_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO invalid_menu_count
    FROM spectra_core.sys_menu
    WHERE deleted IS NULL
      AND ((menu_type = 'DIRECTORY' AND route_name IS NOT NULL)
        OR (menu_type = 'MENU' AND route_name IS NULL));

    SELECT COUNT(*)
    INTO invalid_relation_count
    FROM spectra_core.sys_rel_role_menu relation
    LEFT JOIN spectra_core.sys_menu menu
      ON menu.id = relation.menu_id AND menu.deleted IS NULL
    WHERE relation.deleted IS NULL
      AND (menu.id IS NULL OR menu.menu_type <> 'MENU');

    IF invalid_menu_count > 0 OR invalid_relation_count > 0 THEN
        RAISE EXCEPTION '切换后数据无效：菜单=%，角色菜单关系=%',
            invalid_menu_count, invalid_relation_count;
    END IF;
END
$$;

COMMIT;
