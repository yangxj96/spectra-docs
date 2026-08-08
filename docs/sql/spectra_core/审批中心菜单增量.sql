-- 审批中心三级菜单增量
-- 用途：为已有 spectra_core 数据库补齐审批中心顶部模块、二级分类和三级流程菜单。
-- 特点：可重复执行；目录节点不绑定路由，角色关系只关联 MENU 叶子节点。

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
