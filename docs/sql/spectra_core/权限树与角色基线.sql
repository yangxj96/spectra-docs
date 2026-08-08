-- Spectra 权限树与角色基线
-- 用途：为已有 spectra_core 数据库补齐接口动作权限，并将四个内置角色恢复为最小授权基线。
-- 当前运行库按用户要求通过 API 完成同等操作；本脚本用于新环境/灾备环境初始化。

DO $$
DECLARE
    root_id UUID;
    parent_id UUID;
    module_row RECORD;
    action_code TEXT;
BEGIN
    SELECT id INTO root_id
      FROM spectra_core.sys_authority
     WHERE code = '*' AND deleted IS NULL
     LIMIT 1;

    IF root_id IS NULL THEN
        RAISE EXCEPTION '缺少顶级权限 *';
    END IF;

    FOR module_row IN
        SELECT * FROM (VALUES
            ('MENU', '菜单权限'), ('DICT', '字典管理'), ('DEPT', '部门管理'),
            ('USER', '用户管理'), ('ROLE', '角色管理'), ('AUTHORITY', '权限管理'),
            ('REGION', '区域管理'), ('ACCOUNT', '账号管理'), ('MONITOR', '监控查询'),
            ('CONFIG', '系统配置'), ('CRYPTO', '加密配置'), ('NOTIFICATION', '消息管理'),
            ('NOTIFICATION_SETTING', '消息设置'), ('AI', 'AI服务'), ('FILE', '文件管理'),
            ('OA_ASSET', 'OA资产'), ('OA_ATTENDANCE', 'OA考勤'), ('OA_CALENDAR', 'OA日历'),
            ('OA_CONTACT', 'OA通讯录'), ('OA_CONTRACT', 'OA合同'), ('OA_DOCUMENT', 'OA文档'),
            ('OA_MEETING', 'OA会议'), ('OA_NOTICE', 'OA公告'), ('OA_REPORT', 'OA报表'),
            ('WF_FORM', '流程表单'), ('WF_MODEL', '流程模型'), ('WF_PROCESS', '流程定义'),
            ('WF_INSTANCE', '流程实例'), ('WF_TASK', '流程任务'), ('WF_RUNTIME', '流程运行时'),
            ('WF_HISTORY', '流程历史')
        ) AS modules(code, name)
    LOOP
        SELECT id INTO parent_id
          FROM spectra_core.sys_authority
         WHERE code = module_row.code || ':*' AND deleted IS NULL
         LIMIT 1;

        IF parent_id IS NULL THEN
            INSERT INTO spectra_core.sys_authority
                (id, pid, name, code, created_at, updated_at)
            VALUES
                (gen_random_uuid(), root_id, module_row.name, module_row.code || ':*', NOW(), NOW())
            RETURNING id INTO parent_id;
        END IF;

        FOREACH action_code IN ARRAY ARRAY['QUERY', 'INSERT', 'UPDATE', 'DELETE']
        LOOP
            INSERT INTO spectra_core.sys_authority
                (id, pid, name, code, created_at, updated_at)
            SELECT gen_random_uuid(), parent_id,
                   module_row.name || CASE action_code
                       WHEN 'QUERY' THEN '查询'
                       WHEN 'INSERT' THEN '新增'
                       WHEN 'UPDATE' THEN '修改'
                       ELSE '删除'
                   END,
                   module_row.code || ':' || action_code, NOW(), NOW()
             WHERE NOT EXISTS (
                 SELECT 1
                   FROM spectra_core.sys_authority
                  WHERE code = module_row.code || ':' || action_code
                    AND deleted IS NULL
             );
        END LOOP;
    END LOOP;
END $$;

-- 角色-菜单基线：关联表只保存可点击的 MENU 叶子节点，当前用户菜单接口会自动补齐目录。
-- 运维管理员可见完整导航；其他角色只展示与其业务权限边界对应的菜单。
DELETE FROM spectra_core.sys_rel_role_menu rel
 USING spectra_core.sys_role role_row
 WHERE rel.role_id = role_row.id
   AND role_row.code IN ('ROLE_DEV_OPS', 'ROLE_ADMIN_SYSTEM', 'ROLE_USER', 'ROLE_AUDIT')
   AND rel.deleted IS NULL;

DO $$
DECLARE
    role_id UUID;
BEGIN
    -- 运维管理员：完整菜单树。
    SELECT id INTO role_id FROM spectra_core.sys_role WHERE code = 'ROLE_DEV_OPS' LIMIT 1;
    INSERT INTO spectra_core.sys_rel_role_menu (id, role_id, menu_id, created_at, updated_at)
    SELECT gen_random_uuid(), role_id, menu.id, NOW(), NOW()
      FROM spectra_core.sys_menu menu
     WHERE menu.route_name = ANY (ARRAY[
         'Dashboard','MonitorTask','MonitorServer','MonitorOnline','MonitorCache',
         'ExampleForm','ExampleTable','ExampleEcharts','ExampleMarkdown',
         'SystemUser','SystemRBAC','SystemDept','SystemConfigured','SystemDict','SystemMenu',
         'SystemStorage','SystemWorkflow','SystemRegion',
         'OAAsset','OASupply','OALeave','OAApplicationTypes','OAApproval','OAReimbursement','OAPurchase',
         'OACalendar','OAContact','OAContract','OADocument','OAMeeting','OANotice','OAReport'
     ]::TEXT[])
       AND menu.menu_type = 'MENU'
       AND menu.deleted IS NULL;

    -- 系统管理员：系统管理、OA、工作流和示例；排除监控、配置、文件信息等运维专属菜单。
    SELECT id INTO role_id FROM spectra_core.sys_role WHERE code = 'ROLE_ADMIN_SYSTEM' LIMIT 1;
    INSERT INTO spectra_core.sys_rel_role_menu (id, role_id, menu_id, created_at, updated_at)
    SELECT gen_random_uuid(), role_id, menu.id, NOW(), NOW()
      FROM spectra_core.sys_menu menu
     WHERE menu.route_name = ANY (ARRAY[
         'Dashboard','ExampleForm','ExampleTable','ExampleEcharts','ExampleMarkdown',
         'SystemUser','SystemRBAC','SystemDept','SystemDict','SystemMenu','SystemWorkflow','SystemRegion',
         'OAAsset','OASupply','OALeave','OAApplicationTypes','OAApproval','OAReimbursement','OAPurchase',
         'OACalendar','OAContact','OAContract','OADocument','OAMeeting','OANotice','OAReport'
     ]::TEXT[])
       AND menu.menu_type = 'MENU'
       AND menu.deleted IS NULL;

    -- 普通用户：OA 业务、首页和非敏感示例。
    SELECT id INTO role_id FROM spectra_core.sys_role WHERE code = 'ROLE_USER' LIMIT 1;
    INSERT INTO spectra_core.sys_rel_role_menu (id, role_id, menu_id, created_at, updated_at)
    SELECT gen_random_uuid(), role_id, menu.id, NOW(), NOW()
      FROM spectra_core.sys_menu menu
     WHERE menu.route_name = ANY (ARRAY[
         'Dashboard','ExampleForm','ExampleTable','ExampleEcharts','ExampleMarkdown',
         'OAAsset','OASupply','OALeave','OAApproval','OAReimbursement','OAPurchase',
         'OACalendar','OAContact','OAContract','OADocument','OAMeeting','OANotice','OAReport'
     ]::TEXT[])
       AND menu.menu_type = 'MENU'
       AND menu.deleted IS NULL;

    -- 审计员：只读审计所需的系统、OA、工作流菜单，不显示示例和运维菜单。
    SELECT id INTO role_id FROM spectra_core.sys_role WHERE code = 'ROLE_AUDIT' LIMIT 1;
    INSERT INTO spectra_core.sys_rel_role_menu (id, role_id, menu_id, created_at, updated_at)
    SELECT gen_random_uuid(), role_id, menu.id, NOW(), NOW()
      FROM spectra_core.sys_menu menu
     WHERE menu.route_name = ANY (ARRAY[
         'Dashboard','SystemUser','SystemRBAC','SystemDept','SystemDict','SystemMenu','SystemWorkflow','SystemRegion',
         'OAAsset','OASupply','OALeave','OAReimbursement','OAPurchase',
         'OACalendar','OAContact','OAContract','OADocument','OAMeeting','OANotice','OAReport'
     ]::TEXT[])
       AND menu.menu_type = 'MENU'
       AND menu.deleted IS NULL;
END $$;

-- 运维管理员保留 *；其余角色删除旧的 * / USER:*，随后由 API 或下方基线重新授权。
DELETE FROM spectra_core.sys_rel_role_authority rel
 USING spectra_core.sys_role role_row
 WHERE rel.role_id = role_row.id
   AND role_row.code IN ('ROLE_ADMIN_SYSTEM', 'ROLE_USER', 'ROLE_AUDIT')
   AND rel.deleted IS NULL;

DO $$
DECLARE
    role_row RECORD;
    permission_code TEXT;
BEGIN
    -- 系统管理员：系统管理 + OA 基础 CRUD + 工作流业务操作，运维专属接口不授予。
    SELECT id INTO role_row FROM spectra_core.sys_role WHERE code = 'ROLE_ADMIN_SYSTEM' LIMIT 1;
    FOR permission_code IN SELECT unnest(ARRAY[
        'MENU:QUERY','MENU:INSERT','MENU:UPDATE','MENU:DELETE',
        'DICT:QUERY','DICT:INSERT','DICT:UPDATE','DICT:DELETE',
        'DEPT:QUERY','DEPT:INSERT','DEPT:UPDATE','DEPT:DELETE',
        'USER:QUERY','USER:INSERT','USER:UPDATE','USER:DELETE',
        'ROLE:QUERY','ROLE:INSERT','ROLE:UPDATE','ROLE:DELETE',
        'AUTHORITY:QUERY','REGION:QUERY','ACCOUNT:QUERY','ACCOUNT:UPDATE',
        'NOTIFICATION:QUERY','NOTIFICATION:UPDATE','NOTIFICATION:DELETE',
        'NOTIFICATION_SETTING:QUERY','NOTIFICATION_SETTING:UPDATE',
        'AI:QUERY','AI:INSERT','AI:UPDATE','AI:DELETE',
        'FILE:QUERY','FILE:INSERT',
        'OA_ASSET:QUERY','OA_ASSET:INSERT','OA_ASSET:UPDATE','OA_ASSET:DELETE',
        'OA_ATTENDANCE:QUERY','OA_ATTENDANCE:INSERT','OA_ATTENDANCE:UPDATE','OA_ATTENDANCE:DELETE',
        'OA_CALENDAR:QUERY','OA_CALENDAR:INSERT','OA_CALENDAR:UPDATE','OA_CALENDAR:DELETE',
        'OA_CONTACT:QUERY','OA_CONTACT:INSERT','OA_CONTACT:UPDATE','OA_CONTACT:DELETE',
        'OA_CONTRACT:QUERY','OA_CONTRACT:INSERT','OA_CONTRACT:UPDATE','OA_CONTRACT:DELETE',
        'OA_DOCUMENT:QUERY','OA_DOCUMENT:INSERT','OA_DOCUMENT:UPDATE','OA_DOCUMENT:DELETE',
        'OA_MEETING:QUERY','OA_MEETING:INSERT','OA_MEETING:UPDATE','OA_MEETING:DELETE',
        'OA_NOTICE:QUERY','OA_NOTICE:INSERT','OA_NOTICE:UPDATE','OA_NOTICE:DELETE',
        'OA_REPORT:QUERY','OA_REPORT:INSERT','OA_REPORT:UPDATE','OA_REPORT:DELETE',
        'WF_FORM:QUERY','WF_FORM:INSERT','WF_FORM:UPDATE','WF_FORM:DELETE',
        'WF_PROCESS:QUERY','WF_PROCESS:UPDATE','WF_INSTANCE:QUERY','WF_INSTANCE:INSERT',
        'WF_TASK:QUERY','WF_TASK:UPDATE','WF_RUNTIME:QUERY','WF_HISTORY:QUERY'
    ]) LOOP
        INSERT INTO spectra_core.sys_rel_role_authority
            (id, role_id, authority_id, created_at, updated_at)
        SELECT gen_random_uuid(), role_row.id, authority.id, NOW(), NOW()
          FROM spectra_core.sys_authority authority
         WHERE authority.code = permission_code
           AND authority.deleted IS NULL
           AND NOT EXISTS (
               SELECT 1 FROM spectra_core.sys_rel_role_authority rel
                WHERE rel.role_id = role_row.id
                  AND rel.authority_id = authority.id
                  AND rel.deleted IS NULL
           );
    END LOOP;

    -- 普通用户：本人业务查询/提交，不允许系统管理和删除。
    SELECT id INTO role_row FROM spectra_core.sys_role WHERE code = 'ROLE_USER' LIMIT 1;
    FOR permission_code IN SELECT unnest(ARRAY[
        'ACCOUNT:QUERY','ACCOUNT:UPDATE','NOTIFICATION:QUERY','NOTIFICATION:UPDATE','NOTIFICATION:DELETE',
        'NOTIFICATION_SETTING:QUERY','NOTIFICATION_SETTING:UPDATE','AI:QUERY','AI:INSERT','AI:UPDATE','AI:DELETE',
        'FILE:QUERY','FILE:INSERT','WF_FORM:QUERY','WF_PROCESS:QUERY','WF_INSTANCE:QUERY','WF_INSTANCE:INSERT',
        'WF_TASK:QUERY','WF_TASK:UPDATE','WF_HISTORY:QUERY',
        'OA_ASSET:QUERY','OA_ASSET:INSERT','OA_ASSET:UPDATE',
        'OA_ATTENDANCE:QUERY','OA_ATTENDANCE:INSERT','OA_ATTENDANCE:UPDATE',
        'OA_CALENDAR:QUERY','OA_CALENDAR:INSERT','OA_CALENDAR:UPDATE',
        'OA_CONTACT:QUERY','OA_CONTACT:INSERT','OA_CONTACT:UPDATE',
        'OA_CONTRACT:QUERY','OA_CONTRACT:INSERT','OA_CONTRACT:UPDATE',
        'OA_DOCUMENT:QUERY','OA_DOCUMENT:INSERT','OA_DOCUMENT:UPDATE',
        'OA_MEETING:QUERY','OA_MEETING:INSERT','OA_MEETING:UPDATE',
        'OA_NOTICE:QUERY','OA_NOTICE:INSERT','OA_NOTICE:UPDATE',
        'OA_REPORT:QUERY','OA_REPORT:INSERT','OA_REPORT:UPDATE'
    ]) LOOP
        INSERT INTO spectra_core.sys_rel_role_authority (id, role_id, authority_id, created_at, updated_at)
        SELECT gen_random_uuid(), role_row.id, authority.id, NOW(), NOW()
          FROM spectra_core.sys_authority authority
         WHERE authority.code = permission_code
           AND authority.deleted IS NULL
           AND NOT EXISTS (
               SELECT 1 FROM spectra_core.sys_rel_role_authority rel
                WHERE rel.role_id = role_row.id
                  AND rel.authority_id = authority.id
                  AND rel.deleted IS NULL
           );
    END LOOP;

    -- 审计员：只读查询。
    SELECT id INTO role_row FROM spectra_core.sys_role WHERE code = 'ROLE_AUDIT' LIMIT 1;
    FOR permission_code IN SELECT unnest(ARRAY[
        'USER:QUERY','ROLE:QUERY','AUTHORITY:QUERY','MENU:QUERY','DEPT:QUERY','DICT:QUERY','REGION:QUERY',
        'ACCOUNT:QUERY','NOTIFICATION:QUERY','AI:QUERY','FILE:QUERY',
        'OA_ASSET:QUERY','OA_ATTENDANCE:QUERY','OA_CALENDAR:QUERY','OA_CONTACT:QUERY','OA_CONTRACT:QUERY',
        'OA_DOCUMENT:QUERY','OA_MEETING:QUERY','OA_NOTICE:QUERY','OA_REPORT:QUERY',
        'WF_FORM:QUERY','WF_PROCESS:QUERY','WF_INSTANCE:QUERY','WF_TASK:QUERY','WF_RUNTIME:QUERY','WF_HISTORY:QUERY'
    ]) LOOP
        INSERT INTO spectra_core.sys_rel_role_authority (id, role_id, authority_id, created_at, updated_at)
        SELECT gen_random_uuid(), role_row.id, authority.id, NOW(), NOW()
          FROM spectra_core.sys_authority authority
         WHERE authority.code = permission_code
           AND authority.deleted IS NULL
           AND NOT EXISTS (
               SELECT 1 FROM spectra_core.sys_rel_role_authority rel
                WHERE rel.role_id = role_row.id
                  AND rel.authority_id = authority.id
                  AND rel.deleted IS NULL
           );
    END LOOP;
END $$;
