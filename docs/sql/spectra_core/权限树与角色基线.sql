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

-- ============================================================
-- OA 费用报销与采购权限（原增量脚本已并入权限基线）
-- ============================================================

DO $$
DECLARE
    root_id UUID;
    module_id UUID;
    role_row RECORD;
    permission_code TEXT;
BEGIN
    SELECT id INTO root_id
      FROM spectra_core.sys_authority
     WHERE code = '*' AND deleted IS NULL
     LIMIT 1;

    IF root_id IS NULL THEN
        RAISE EXCEPTION '缺少顶级权限 *';
    END IF;

    SELECT id INTO module_id
      FROM spectra_core.sys_authority
     WHERE code = 'OA_REIMBURSEMENT:*' AND deleted IS NULL
     LIMIT 1;

    IF module_id IS NULL THEN
        INSERT INTO spectra_core.sys_authority
            (id, pid, name, code, created_at, updated_at)
        VALUES
            (gen_random_uuid(), root_id, 'OA费用报销', 'OA_REIMBURSEMENT:*', NOW(), NOW())
        RETURNING id INTO module_id;
    END IF;

    FOREACH permission_code IN ARRAY ARRAY[
        'OA_REIMBURSEMENT:QUERY', 'OA_REIMBURSEMENT:INSERT',
        'OA_REIMBURSEMENT:UPDATE', 'OA_REIMBURSEMENT:PAYMENT'
    ]
    LOOP
        INSERT INTO spectra_core.sys_authority
            (id, pid, name, code, created_at, updated_at)
        SELECT gen_random_uuid(), module_id,
               CASE permission_code
                   WHEN 'OA_REIMBURSEMENT:QUERY' THEN '报销查询'
                   WHEN 'OA_REIMBURSEMENT:INSERT' THEN '报销新增'
                   WHEN 'OA_REIMBURSEMENT:UPDATE' THEN '报销修改'
                   ELSE '报销付款'
               END,
               permission_code, NOW(), NOW()
         WHERE NOT EXISTS (
             SELECT 1 FROM spectra_core.sys_authority
              WHERE code = permission_code AND deleted IS NULL
         );
    END LOOP;

    FOR role_row IN
        SELECT id, code FROM spectra_core.sys_role
         WHERE code IN ('ROLE_ADMIN_SYSTEM', 'ROLE_USER', 'ROLE_AUDIT')
           AND deleted IS NULL
    LOOP
        FOR permission_code IN SELECT unnest(
            CASE role_row.code
                WHEN 'ROLE_ADMIN_SYSTEM' THEN ARRAY[
                    'OA_REIMBURSEMENT:QUERY', 'OA_REIMBURSEMENT:INSERT',
                    'OA_REIMBURSEMENT:UPDATE', 'OA_REIMBURSEMENT:PAYMENT'
                ]
                WHEN 'ROLE_USER' THEN ARRAY[
                    'OA_REIMBURSEMENT:QUERY', 'OA_REIMBURSEMENT:INSERT', 'OA_REIMBURSEMENT:UPDATE'
                ]
                ELSE ARRAY['OA_REIMBURSEMENT:QUERY']
            END
        ) LOOP
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
    END LOOP;
END $$;

DO $$
DECLARE
    root_id UUID;
    module_id UUID;
    role_row RECORD;
    permission_code TEXT;
BEGIN
    SELECT id INTO root_id
      FROM spectra_core.sys_authority
     WHERE code = '*' AND deleted IS NULL
     LIMIT 1;

    IF root_id IS NULL THEN
        RAISE EXCEPTION '缺少顶级权限 *';
    END IF;

    SELECT id INTO module_id
      FROM spectra_core.sys_authority
     WHERE code = 'OA_PURCHASE:*' AND deleted IS NULL
     LIMIT 1;

    IF module_id IS NULL THEN
        INSERT INTO spectra_core.sys_authority
            (id, pid, name, code, created_at, updated_at)
        VALUES
            (gen_random_uuid(), root_id, 'OA采购申请', 'OA_PURCHASE:*', NOW(), NOW())
        RETURNING id INTO module_id;
    END IF;

    FOREACH permission_code IN ARRAY ARRAY[
        'OA_PURCHASE:QUERY', 'OA_PURCHASE:INSERT', 'OA_PURCHASE:UPDATE',
        'OA_PURCHASE:EXECUTE', 'OA_PURCHASE:RECEIVE'
    ]
    LOOP
        INSERT INTO spectra_core.sys_authority
            (id, pid, name, code, created_at, updated_at)
        SELECT gen_random_uuid(), module_id,
               CASE permission_code
                   WHEN 'OA_PURCHASE:QUERY' THEN '采购查询'
                   WHEN 'OA_PURCHASE:INSERT' THEN '采购新增'
                   WHEN 'OA_PURCHASE:UPDATE' THEN '采购修改'
                   WHEN 'OA_PURCHASE:EXECUTE' THEN '采购执行'
                   ELSE '采购收货'
               END,
               permission_code, NOW(), NOW()
         WHERE NOT EXISTS (
             SELECT 1 FROM spectra_core.sys_authority
              WHERE code = permission_code AND deleted IS NULL
         );
    END LOOP;

    FOR role_row IN
        SELECT id, code FROM spectra_core.sys_role
         WHERE code IN ('ROLE_ADMIN_SYSTEM', 'ROLE_USER', 'ROLE_AUDIT')
           AND deleted IS NULL
    LOOP
        FOR permission_code IN SELECT unnest(
            CASE role_row.code
                WHEN 'ROLE_ADMIN_SYSTEM' THEN ARRAY[
                    'OA_PURCHASE:QUERY', 'OA_PURCHASE:INSERT', 'OA_PURCHASE:UPDATE',
                    'OA_PURCHASE:EXECUTE', 'OA_PURCHASE:RECEIVE'
                ]
                WHEN 'ROLE_USER' THEN ARRAY[
                    'OA_PURCHASE:QUERY', 'OA_PURCHASE:INSERT', 'OA_PURCHASE:UPDATE'
                ]
                ELSE ARRAY['OA_PURCHASE:QUERY']
            END
        ) LOOP
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
    END LOOP;
END $$;

-- ============================================================
-- 审批中心三级菜单（原增量脚本已并入权限基线）
-- ============================================================

DO $$
DECLARE
    approval_root_id UUID;
    all_id UUID;
    finance_id UUID;
    asset_id UUID;
    hr_id UUID;
BEGIN
    SELECT id INTO approval_root_id
      FROM spectra_core.sys_menu
     WHERE pid IS NULL
       AND name = '审批中心'
       AND deleted IS NULL
     LIMIT 1;

    IF approval_root_id IS NULL THEN
        INSERT INTO spectra_core.sys_menu
            (id, pid, icon, menu_type, route_name, name, sort, created_at, updated_at)
        VALUES
            (gen_random_uuid(), NULL, 'icon-module', 'DIRECTORY', NULL, '审批中心', 5, NOW(), NOW())
        RETURNING id INTO approval_root_id;
    ELSE
        UPDATE spectra_core.sys_menu
           SET icon = 'icon-module', menu_type = 'DIRECTORY', route_name = NULL, sort = 5, updated_at = NOW()
         WHERE id = approval_root_id;
    END IF;

    SELECT id INTO all_id
      FROM spectra_core.sys_menu
     WHERE pid = approval_root_id AND name = '综合审批' AND deleted IS NULL
     LIMIT 1;
    IF all_id IS NULL THEN
        INSERT INTO spectra_core.sys_menu
            (id, pid, icon, menu_type, route_name, name, sort, created_at, updated_at)
        VALUES
            (gen_random_uuid(), approval_root_id, 'icon-folder', 'DIRECTORY', NULL, '综合审批', 0, NOW(), NOW())
        RETURNING id INTO all_id;
    END IF;

    SELECT id INTO finance_id
      FROM spectra_core.sys_menu
     WHERE pid = approval_root_id AND name = '财务相关' AND deleted IS NULL
     LIMIT 1;
    IF finance_id IS NULL THEN
        INSERT INTO spectra_core.sys_menu
            (id, pid, icon, menu_type, route_name, name, sort, created_at, updated_at)
        VALUES
            (gen_random_uuid(), approval_root_id, 'icon-folder', 'DIRECTORY', NULL, '财务相关', 10, NOW(), NOW())
        RETURNING id INTO finance_id;
    END IF;

    SELECT id INTO asset_id
      FROM spectra_core.sys_menu
     WHERE pid = approval_root_id AND name = '资产相关' AND deleted IS NULL
     LIMIT 1;
    IF asset_id IS NULL THEN
        INSERT INTO spectra_core.sys_menu
            (id, pid, icon, menu_type, route_name, name, sort, created_at, updated_at)
        VALUES
            (gen_random_uuid(), approval_root_id, 'icon-folder', 'DIRECTORY', NULL, '资产相关', 20, NOW(), NOW())
        RETURNING id INTO asset_id;
    END IF;

    SELECT id INTO hr_id
      FROM spectra_core.sys_menu
     WHERE pid = approval_root_id AND name = '行政人事' AND deleted IS NULL
     LIMIT 1;
    IF hr_id IS NULL THEN
        INSERT INTO spectra_core.sys_menu
            (id, pid, icon, menu_type, route_name, name, sort, created_at, updated_at)
        VALUES
            (gen_random_uuid(), approval_root_id, 'icon-folder', 'DIRECTORY', NULL, '行政人事', 30, NOW(), NOW())
        RETURNING id INTO hr_id;
    END IF;

    UPDATE spectra_core.sys_menu
       SET pid = all_id, icon = 'icon-list', menu_type = 'MENU', name = '全部审批', sort = 0, updated_at = NOW()
     WHERE route_name = 'OAApproval' AND deleted IS NULL;
    IF NOT FOUND THEN
        INSERT INTO spectra_core.sys_menu
            (id, pid, icon, menu_type, route_name, name, sort, created_at, updated_at)
        VALUES
            (gen_random_uuid(), all_id, 'icon-list', 'MENU', 'OAApproval', '全部审批', 0, NOW(), NOW());
    END IF;

    UPDATE spectra_core.sys_menu
       SET pid = finance_id, icon = 'icon-list', menu_type = 'MENU', name = '费用报销审批', sort = 0, updated_at = NOW()
     WHERE route_name = 'OAApprovalReimbursement' AND deleted IS NULL;
    IF NOT FOUND THEN
        INSERT INTO spectra_core.sys_menu
            (id, pid, icon, menu_type, route_name, name, sort, created_at, updated_at)
        VALUES
            (gen_random_uuid(), finance_id, 'icon-list', 'MENU', 'OAApprovalReimbursement', '费用报销审批', 0, NOW(), NOW());
    END IF;

    UPDATE spectra_core.sys_menu
       SET pid = asset_id, icon = 'icon-list', menu_type = 'MENU', name = '采购申请审批', sort = 0, updated_at = NOW()
     WHERE route_name = 'OAApprovalPurchase' AND deleted IS NULL;
    IF NOT FOUND THEN
        INSERT INTO spectra_core.sys_menu
            (id, pid, icon, menu_type, route_name, name, sort, created_at, updated_at)
        VALUES
            (gen_random_uuid(), asset_id, 'icon-list', 'MENU', 'OAApprovalPurchase', '采购申请审批', 0, NOW(), NOW());
    END IF;

    UPDATE spectra_core.sys_menu
       SET pid = hr_id, icon = 'icon-list', menu_type = 'MENU', name = '请假审批', sort = 0, updated_at = NOW()
     WHERE route_name = 'OAApprovalLeave' AND deleted IS NULL;
    IF NOT FOUND THEN
        INSERT INTO spectra_core.sys_menu
            (id, pid, icon, menu_type, route_name, name, sort, created_at, updated_at)
        VALUES
            (gen_random_uuid(), hr_id, 'icon-list', 'MENU', 'OAApprovalLeave', '请假审批', 0, NOW(), NOW());
    END IF;
END $$;

DO $$
DECLARE
    role_row RECORD;
    route_name_value TEXT;
BEGIN
    FOR role_row IN
        SELECT id
          FROM spectra_core.sys_role
         WHERE code IN ('ROLE_DEV_OPS', 'ROLE_ADMIN_SYSTEM', 'ROLE_USER', 'ROLE_AUDIT')
    LOOP
        FOR route_name_value IN
            SELECT unnest(ARRAY[
                'OAApproval',
                'OAApprovalReimbursement',
                'OAApprovalPurchase',
                'OAApprovalLeave'
            ]::TEXT[])
        LOOP
            INSERT INTO spectra_core.sys_rel_role_menu
                (id, role_id, menu_id, created_at, updated_at)
            SELECT gen_random_uuid(), role_row.id, menu.id, NOW(), NOW()
              FROM spectra_core.sys_menu menu
             WHERE menu.route_name = route_name_value
               AND menu.menu_type = 'MENU'
               AND menu.deleted IS NULL
               AND NOT EXISTS (
                   SELECT 1
                     FROM spectra_core.sys_rel_role_menu rel
                    WHERE rel.role_id = role_row.id
                      AND rel.menu_id = menu.id
                      AND rel.deleted IS NULL
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

-- ============================================================
-- 存量数据权限兼容回填（原迁移脚本已并入权限基线）
-- ============================================================

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

-- 后置补齐：通用角色基线会先清理业务角色关系，这里在其后恢复报销、采购和审批中心授权。
DO $$
DECLARE
    role_row RECORD;
    permission_code TEXT;
BEGIN
    FOR role_row IN
        SELECT id, code
          FROM spectra_core.sys_role
         WHERE code IN ('ROLE_ADMIN_SYSTEM', 'ROLE_USER', 'ROLE_AUDIT')
           AND deleted IS NULL
    LOOP
        FOR permission_code IN SELECT unnest(
            CASE role_row.code
                WHEN 'ROLE_ADMIN_SYSTEM' THEN ARRAY[
                    'OA_REIMBURSEMENT:QUERY', 'OA_REIMBURSEMENT:INSERT',
                    'OA_REIMBURSEMENT:UPDATE', 'OA_REIMBURSEMENT:PAYMENT',
                    'OA_PURCHASE:QUERY', 'OA_PURCHASE:INSERT', 'OA_PURCHASE:UPDATE',
                    'OA_PURCHASE:EXECUTE', 'OA_PURCHASE:RECEIVE'
                ]
                WHEN 'ROLE_USER' THEN ARRAY[
                    'OA_REIMBURSEMENT:QUERY', 'OA_REIMBURSEMENT:INSERT', 'OA_REIMBURSEMENT:UPDATE',
                    'OA_PURCHASE:QUERY', 'OA_PURCHASE:INSERT', 'OA_PURCHASE:UPDATE'
                ]
                ELSE ARRAY['OA_REIMBURSEMENT:QUERY', 'OA_PURCHASE:QUERY']
            END
        ) LOOP
            INSERT INTO spectra_core.sys_rel_role_authority
                (id, role_id, authority_id, created_at, updated_at)
            SELECT gen_random_uuid(), role_row.id, authority.id, NOW(), NOW()
              FROM spectra_core.sys_authority authority
             WHERE authority.code = permission_code
               AND authority.deleted IS NULL
               AND NOT EXISTS (
                   SELECT 1
                     FROM spectra_core.sys_rel_role_authority rel
                    WHERE rel.role_id = role_row.id
                      AND rel.authority_id = authority.id
                      AND rel.deleted IS NULL
               );
        END LOOP;
    END LOOP;
END $$;

DO $$
DECLARE
    role_row RECORD;
    route_name_value TEXT;
BEGIN
    FOR role_row IN
        SELECT id
          FROM spectra_core.sys_role
         WHERE code IN ('ROLE_DEV_OPS', 'ROLE_ADMIN_SYSTEM', 'ROLE_USER', 'ROLE_AUDIT')
    LOOP
        FOR route_name_value IN
            SELECT unnest(ARRAY[
                'OAApproval',
                'OAApprovalReimbursement',
                'OAApprovalPurchase',
                'OAApprovalLeave'
            ]::TEXT[])
        LOOP
            INSERT INTO spectra_core.sys_rel_role_menu
                (id, role_id, menu_id, created_at, updated_at)
            SELECT gen_random_uuid(), role_row.id, menu.id, NOW(), NOW()
              FROM spectra_core.sys_menu menu
             WHERE menu.route_name = route_name_value
               AND menu.menu_type = 'MENU'
               AND menu.deleted IS NULL
               AND NOT EXISTS (
                   SELECT 1
                     FROM spectra_core.sys_rel_role_menu rel
                    WHERE rel.role_id = role_row.id
                      AND rel.menu_id = menu.id
                      AND rel.deleted IS NULL
               );
        END LOOP;
    END LOOP;
END $$;
