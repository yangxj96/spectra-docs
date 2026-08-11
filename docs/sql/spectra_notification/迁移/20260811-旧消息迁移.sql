-- 将旧站内消息迁入通知模块。脚本按旧消息 ID 幂等执行，不删除旧表。
BEGIN;

CREATE OR REPLACE FUNCTION pg_temp.ntf_safe_jsonb(value TEXT)
RETURNS JSONB
LANGUAGE plpgsql
AS $$
BEGIN
    IF value IS NULL OR btrim(value) = '' THEN
        RETURN '{}'::jsonb;
    END IF;
    RETURN value::jsonb;
EXCEPTION WHEN OTHERS THEN
    RETURN '{}'::jsonb;
END;
$$;

DO $$
DECLARE
    old_message RECORD;
    request_id UUID;
    task_id UUID;
    purpose_code VARCHAR(50);
    migration_tenant_id CONSTANT UUID := '00000000-0000-0000-0000-000000000000';
BEGIN
    FOR old_message IN
        SELECT id, title, content, type, sender_id, sender_name, link, is_read, read_at, receiver_id, extra,
               created_at, deleted
        FROM spectra_core.sys_notification
    LOOP
        IF EXISTS (SELECT 1 FROM spectra_notification.ntf_inbox_message WHERE id = old_message.id) THEN
            CONTINUE;
        END IF;

        purpose_code := CASE old_message.type
            WHEN 'workflow' THEN 'WORKFLOW_TODO'
            WHEN 'approval' THEN 'WORKFLOW_TODO'
            WHEN 'oa' THEN 'OA_NOTICE'
            WHEN 'inner_mail' THEN 'INNER_MESSAGE'
            ELSE 'SYSTEM_NOTICE'
        END;
        request_id := gen_random_uuid();
        task_id := gen_random_uuid();

        INSERT INTO spectra_notification.ntf_request
            (id, tenant_id, external_request_id, idempotency_key, purpose, template_group_code, source_module,
             business_type, business_id, initiator_type, initiator_user_id, parameters, status, recipient_count,
             task_count, scheduled_at, created_at, updated_at)
        VALUES
            (request_id, migration_tenant_id, old_message.id::text, 'legacy:notification:' || old_message.id::text,
             purpose_code, 'legacy.' || lower(purpose_code), 'MIGRATION', 'LEGACY_NOTIFICATION', old_message.id::text,
             'SYSTEM', old_message.sender_id, pg_temp.ntf_safe_jsonb(old_message.extra), 'SUCCEEDED', 1, 1,
             old_message.created_at, old_message.created_at, old_message.created_at)
        ON CONFLICT DO NOTHING;

        SELECT id INTO request_id
        FROM spectra_notification.ntf_request
        WHERE ntf_request.tenant_id = migration_tenant_id
          AND idempotency_key = 'legacy:notification:' || old_message.id::text
        ORDER BY created_at
        LIMIT 1;

        INSERT INTO spectra_notification.ntf_task
            (id, tenant_id, notification_request_id, channel, receiver_user_id, recipient_key_hash,
             purpose, title, content, link, extra, priority, attempt_count, max_attempts, scheduled_at,
             status, created_at, updated_at)
        VALUES
            (task_id, migration_tenant_id, request_id, 'IN_APP', old_message.receiver_id, md5(old_message.receiver_id::text),
             purpose_code, COALESCE(old_message.title, ''), COALESCE(old_message.content, ''), old_message.link,
             pg_temp.ntf_safe_jsonb(old_message.extra), 0, 1, 3, old_message.created_at, 'SENT',
             old_message.created_at, old_message.created_at)
        ON CONFLICT DO NOTHING;

        SELECT existing_task.id INTO task_id
        FROM spectra_notification.ntf_task AS existing_task
        WHERE existing_task.notification_request_id = request_id
          AND existing_task.recipient_key_hash = md5(old_message.receiver_id::text)
          AND existing_task.channel = 'IN_APP'
        ORDER BY existing_task.created_at
        LIMIT 1;

        INSERT INTO spectra_notification.ntf_delivery
            (id, tenant_id, notification_task_id, attempt_no, provider, result_status, started_at, completed_at,
             response_summary, created_at, updated_at)
        VALUES
            (gen_random_uuid(), migration_tenant_id, task_id, 1, 'IN_APP', 'SENT', old_message.created_at, old_message.created_at,
             jsonb_build_object('message', '历史消息迁移完成'), old_message.created_at, old_message.created_at)
        ON CONFLICT DO NOTHING;

        INSERT INTO spectra_notification.ntf_inbox_message
            (id, tenant_id, receiver_user_id, notification_request_id, notification_task_id, purpose, title, content,
             sender_user_id, sender_name, link, is_read, read_at, extra, deleted, created_at, updated_at)
        VALUES
            (old_message.id, migration_tenant_id, old_message.receiver_id, request_id, task_id, purpose_code,
             COALESCE(old_message.title, ''), COALESCE(old_message.content, ''), old_message.sender_id,
             old_message.sender_name, old_message.link, COALESCE(old_message.is_read, FALSE),
             CASE WHEN old_message.is_read THEN COALESCE(old_message.read_at, old_message.created_at) ELSE NULL END,
             pg_temp.ntf_safe_jsonb(old_message.extra), old_message.deleted, old_message.created_at, old_message.created_at)
        ON CONFLICT (id) DO NOTHING;
    END LOOP;
END;
$$;

COMMIT;
