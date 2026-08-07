-- P1 采购申请权限增量
-- 适用于已执行“权限树与角色基线.sql”的环境；重复执行安全。
-- 菜单 route_name=OAPurchase 仍需通过系统菜单管理接口创建/授权。

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
