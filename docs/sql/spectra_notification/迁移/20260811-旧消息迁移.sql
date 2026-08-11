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
            (id, tenant_id, business_type, business_id, idempotency_key, template_code, purpose, sender_user_id,
             source_module, payload, status, created_at, updated_at)
        VALUES
            (request_id, '00000000-0000-0000-0000-000000000000', 'LEGACY_NOTIFICATION', old_message.id::text,
             'legacy:notification:' || old_message.id::text, 'legacy.' || lower(purpose_code), purpose_code,
             old_message.sender_id, 'MIGRATION', pg_temp.ntf_safe_jsonb(old_message.extra), 'SUCCEEDED',
             old_message.created_at, old_message.created_at)
        ON CONFLICT (tenant_id, idempotency_key) DO NOTHING;

        INSERT INTO spectra_notification.ntf_task
            (id, request_id, tenant_id, recipient_user_id, channel, purpose, title, content, link, extra, status,
             created_at, updated_at)
        VALUES
            (task_id, request_id, '00000000-0000-0000-0000-000000000000', old_message.receiver_id, 'IN_APP',
             purpose_code, COALESCE(old_message.title, ''), COALESCE(old_message.content, ''), old_message.link,
             pg_temp.ntf_safe_jsonb(old_message.extra), 'SENT', old_message.created_at, old_message.created_at)
        ON CONFLICT (request_id, recipient_user_id, channel) DO NOTHING;

        INSERT INTO spectra_notification.ntf_delivery
            (id, task_id, provider_code, status, response_summary, sent_at, created_at)
        VALUES
            (gen_random_uuid(), task_id, 'IN_APP', 'SENT', '历史消息迁移完成', old_message.created_at, old_message.created_at);

        INSERT INTO spectra_notification.ntf_inbox_message
            (id, tenant_id, recipient_user_id, request_id, task_id, purpose, title, content, sender_user_id,
             sender_name, link, extra, read_at, deleted, created_at)
        VALUES
            (old_message.id, '00000000-0000-0000-0000-000000000000', old_message.receiver_id, request_id, task_id,
             purpose_code, COALESCE(old_message.title, ''), COALESCE(old_message.content, ''), old_message.sender_id,
             old_message.sender_name, old_message.link, pg_temp.ntf_safe_jsonb(old_message.extra),
             CASE WHEN old_message.is_read THEN COALESCE(old_message.read_at, old_message.created_at) ELSE NULL END,
             old_message.deleted, old_message.created_at)
        ON CONFLICT (id) DO NOTHING;
    END LOOP;
END;
$$;

COMMIT;
