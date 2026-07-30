-- ============================================================
-- V20260730_01: 扩展菜单导航权限字段
--
-- 执行者：用户手动执行
-- 说明：本阶段保留旧字段和隐藏菜单，旧版前端仍可运行。
-- ============================================================

BEGIN;

ALTER TABLE spectra_core.sys_menu
    ADD COLUMN IF NOT EXISTS menu_type VARCHAR(16),
    ADD COLUMN IF NOT EXISTS route_name VARCHAR(100);

COMMENT ON COLUMN spectra_core.sys_menu.menu_type IS '菜单类型：DIRECTORY-目录，MENU-可点击菜单';
COMMENT ON COLUMN spectra_core.sys_menu.route_name IS '对应 Vue Router 的唯一命名路由';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'spectra_core.sys_menu'::regclass
          AND conname = 'ck_sys_menu_type'
    ) THEN
        ALTER TABLE spectra_core.sys_menu
            ADD CONSTRAINT ck_sys_menu_type
            CHECK (menu_type IN ('DIRECTORY', 'MENU'));
    END IF;
END
$$;

-- 现有可见根节点是顶部导航目录。首页暂时保留“首页默认”子节点，
-- 在数据切换阶段再合并为可点击的根菜单。
UPDATE spectra_core.sys_menu
SET menu_type = 'DIRECTORY',
    route_name = NULL,
    updated_at = NOW(),
    version = COALESCE(version, 0) + 1
WHERE deleted IS NULL
  AND COALESCE(hide, FALSE) IS FALSE
  AND component = 'layout';

-- 可见页面显式映射到稳定的 Vue Router 名称。
UPDATE spectra_core.sys_menu
SET menu_type = 'MENU',
    route_name = CASE component
        WHEN '/Dashboard/index' THEN 'Dashboard'
        WHEN '/Monitor/Task/index' THEN 'MonitorTask'
        WHEN '/Monitor/Server/index' THEN 'MonitorServer'
        WHEN '/Monitor/Online/index' THEN 'MonitorOnline'
        WHEN '/Monitor/Cache/index' THEN 'MonitorCache'
        WHEN '/System/User/index' THEN 'SystemUser'
        WHEN '/System/RBAC/index' THEN 'SystemRBAC'
        WHEN '/System/Dept/index' THEN 'SystemDept'
        WHEN 'System/Configured/index' THEN 'SystemConfigured'
        WHEN '/System/Dict/index' THEN 'SystemDict'
        WHEN '/System/Menu/index' THEN 'SystemMenu'
        WHEN '/System/Storage/index' THEN 'SystemStorage'
        WHEN '/System/Workflow/index' THEN 'SystemWorkflow'
        WHEN '/System/Region/index' THEN 'SystemRegion'
        WHEN '/OA/Asset/index' THEN 'OAAsset'
        WHEN '/OA/Attendance/index' THEN 'OAAttendance'
        WHEN '/OA/Calendar/index' THEN 'OACalendar'
        WHEN '/OA/Contact/index' THEN 'OAContact'
        WHEN '/OA/Contract/index' THEN 'OAContract'
        WHEN '/OA/Document/index' THEN 'OADocument'
        WHEN '/OA/Meeting/index' THEN 'OAMeeting'
        WHEN '/OA/Notice/index' THEN 'OANotice'
        WHEN '/OA/Report/index' THEN 'OAReport'
        WHEN '/Example/Form/index' THEN 'ExampleForm'
        WHEN '/Example/Table/index' THEN 'ExampleTable'
        WHEN '/Example/Echarts/index' THEN 'ExampleEcharts'
        WHEN '/Example/Markdown/index' THEN 'ExampleMarkdown'
        ELSE route_name
    END,
    updated_at = NOW(),
    version = COALESCE(version, 0) + 1
WHERE deleted IS NULL
  AND COALESCE(hide, FALSE) IS FALSE
  AND component <> 'layout';

CREATE UNIQUE INDEX IF NOT EXISTS uk_sys_menu_route_name_active
    ON spectra_core.sys_menu (route_name)
    WHERE deleted IS NULL AND route_name IS NOT NULL;

DO $$
DECLARE
    unmapped_count INTEGER;
    menu_with_children_count INTEGER;
BEGIN
    SELECT COUNT(*)
    INTO unmapped_count
    FROM spectra_core.sys_menu
    WHERE deleted IS NULL
      AND COALESCE(hide, FALSE) IS FALSE
      AND (menu_type IS NULL
        OR (menu_type = 'MENU' AND route_name IS NULL));

    SELECT COUNT(*)
    INTO menu_with_children_count
    FROM spectra_core.sys_menu menu
    WHERE menu.deleted IS NULL
      AND menu.menu_type = 'MENU'
      AND EXISTS (
          SELECT 1
          FROM spectra_core.sys_menu child
          WHERE child.deleted IS NULL
            AND child.pid = menu.id
      );

    IF unmapped_count > 0 OR menu_with_children_count > 0 THEN
        RAISE EXCEPTION '菜单回填无效：未映射=%，拥有活动子节点的菜单=%',
            unmapped_count, menu_with_children_count;
    END IF;
END
$$;

COMMIT;
