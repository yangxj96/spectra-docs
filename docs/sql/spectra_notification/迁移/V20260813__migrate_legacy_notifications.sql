-- 统一通知模块历史数据迁移。
--
-- 迁移来源：spectra_core.sys_notification、spectra_core.sys_notification_setting。
-- 迁移目标：spectra_notification.ntf_inbox_message、ntf_user_preference。
-- 约定：旧表没有租户字段，统一归入系统租户 00000000-0000-0000-0000-000000000000；
--       脚本可重复执行，不删除旧数据，偏好 ID 使用稳定哈希保证重复执行不产生新行。

BEGIN;

DO $$
DECLARE
    migrated_count BIGINT := 0;
    invalid_extra_count BIGINT := 0;
BEGIN
    IF to_regclass('spectra_core.sys_notification') IS NULL THEN
        RAISE NOTICE '跳过通知消息迁移：spectra_core.sys_notification 不存在';
        RETURN;
    END IF;

    SELECT count(*)
      INTO invalid_extra_count
      FROM spectra_core.sys_notification
     WHERE extra IS NOT NULL
       AND jsonb_typeof(extra) <> 'object';

    INSERT INTO spectra_notification.ntf_inbox_message (
        id,
        tenant_id,
        notification_task_id,
        notification_request_id,
        receiver_user_id,
        purpose,
        title,
        content,
        sender_user_id,
        sender_name,
        link,
        is_read,
        read_at,
        extra,
        created_by,
        created_at,
        updated_by,
        updated_at,
        deleted,
        version
    )
    SELECT
        source.id,
        '00000000-0000-0000-0000-000000000000'::uuid,
        NULL,
        NULL,
        source.receiver_id,
        CASE lower(source.type)
            WHEN 'workflow' THEN CASE
                WHEN jsonb_typeof(source.extra) = 'object'
                     AND source.extra ?| array['result', 'approval_result', 'decision', 'approved']
                    THEN 'WORKFLOW_RESULT'
                ELSE 'WORKFLOW_TODO'
            END
            WHEN 'oa' THEN 'OA_NOTICE'
            WHEN 'inner_mail' THEN 'INNER_MESSAGE'
            WHEN 'approval' THEN 'WORKFLOW_TODO'
            ELSE 'SYSTEM_NOTICE'
        END,
        source.title,
        coalesce(source.content, ''),
        source.sender_id,
        source.sender_name,
        source.link,
        coalesce(source.is_read, false),
        CASE WHEN coalesce(source.is_read, false)
            THEN coalesce(source.read_at, source.updated_at, source.created_at)
            ELSE NULL
        END,
        CASE WHEN jsonb_typeof(source.extra) = 'object' THEN source.extra ELSE '{}'::jsonb END,
        source.created_by,
        source.created_at,
        source.updated_by,
        source.updated_at,
        source.deleted,
        coalesce(source.version, 0)
    FROM spectra_core.sys_notification source
    ON CONFLICT (id) DO NOTHING;

    GET DIAGNOSTICS migrated_count = ROW_COUNT;
    RAISE NOTICE '通知消息迁移完成：新增 %, 非对象 extra 已匿名归一化 % 条',
        migrated_count, invalid_extra_count;
END
$$;

DO $$
DECLARE
    migrated_count BIGINT := 0;
BEGIN
    IF to_regclass('spectra_core.sys_notification_setting') IS NULL THEN
        RAISE NOTICE '跳过通知偏好迁移：spectra_core.sys_notification_setting 不存在';
        RETURN;
    END IF;

    INSERT INTO spectra_notification.ntf_user_preference (
        id,
        tenant_id,
        user_id,
        purpose,
        channel,
        enabled,
        do_not_disturb,
        do_not_disturb_start,
        do_not_disturb_end,
        created_by,
        created_at,
        updated_by,
        updated_at,
        deleted,
        version
    )
    SELECT
        md5(source.id::text || ':' || purpose.purpose || ':IN_APP')::uuid,
        '00000000-0000-0000-0000-000000000000'::uuid,
        source.user_id,
        purpose.purpose,
        'IN_APP',
        purpose.enabled,
        coalesce(source.do_not_disturb, false),
        source.do_not_disturb_start,
        source.do_not_disturb_end,
        source.created_by,
        source.created_at,
        source.updated_by,
        source.updated_at,
        source.deleted,
        coalesce(source.version, 0)
    FROM spectra_core.sys_notification_setting source
    CROSS JOIN LATERAL (
        VALUES
            ('SYSTEM_NOTICE', coalesce(source.system_enabled, true)),
            ('WORKFLOW_TODO', coalesce(source.workflow_enabled, true)),
            ('OA_NOTICE', coalesce(source.oa_enabled, true)),
            ('INNER_MESSAGE', coalesce(source.inner_mail_enabled, true)),
            ('WORKFLOW_RESULT', coalesce(source.approval_enabled, true))
    ) AS purpose(purpose, enabled)
    WHERE NOT EXISTS (
        SELECT 1
          FROM spectra_notification.ntf_user_preference target
         WHERE target.tenant_id = '00000000-0000-0000-0000-000000000000'::uuid
           AND target.user_id = source.user_id
           AND target.purpose = purpose.purpose
           AND target.channel = 'IN_APP'
           AND target.deleted IS NULL
    )
    ON CONFLICT (id) DO NOTHING;

    GET DIAGNOSTICS migrated_count = ROW_COUNT;
    RAISE NOTICE '通知偏好迁移完成：新增 % 条（每个旧设置展开为 5 条 IN_APP 偏好）', migrated_count;
END
$$;

COMMIT;
