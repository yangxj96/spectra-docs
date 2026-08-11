-- 将早期 ntf_* 表升级为建表.sql 中的标准模型。
-- 本脚本保留旧列作为过渡数据，切换代码稳定后再由独立清理脚本删除旧列。
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
    RETURN jsonb_build_object('legacy_value', value);
END;
$$;

-- 所有通知实体补齐 BaseEntity 对应的审计、软删除和乐观锁字段。
DO $$
DECLARE
    table_name TEXT;
BEGIN
    FOREACH table_name IN ARRAY ARRAY[
        'ntf_template', 'ntf_request', 'ntf_task', 'ntf_delivery', 'ntf_inbox_message', 'ntf_user_preference'
    ] LOOP
        EXECUTE format('ALTER TABLE spectra_notification.%I ADD COLUMN IF NOT EXISTS created_by UUID', table_name);
        EXECUTE format('ALTER TABLE spectra_notification.%I ADD COLUMN IF NOT EXISTS updated_by UUID', table_name);
        EXECUTE format('ALTER TABLE spectra_notification.%I ADD COLUMN IF NOT EXISTS version BIGINT NOT NULL DEFAULT 0', table_name);
    END LOOP;
END;
$$;

ALTER TABLE spectra_notification.ntf_template
    ALTER COLUMN title_template TYPE TEXT;

ALTER TABLE spectra_notification.ntf_request
    ADD COLUMN IF NOT EXISTS external_request_id VARCHAR(100),
    ADD COLUMN IF NOT EXISTS template_group_code VARCHAR(100),
    ADD COLUMN IF NOT EXISTS initiator_type VARCHAR(20),
    ADD COLUMN IF NOT EXISTS initiator_user_id UUID,
    ADD COLUMN IF NOT EXISTS parameters JSONB,
    ADD COLUMN IF NOT EXISTS sensitive_parameters_ciphertext TEXT,
    ADD COLUMN IF NOT EXISTS encryption_key_id VARCHAR(50),
    ADD COLUMN IF NOT EXISTS recipient_count INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS task_count INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS trace_id VARCHAR(100);
UPDATE spectra_notification.ntf_request
SET external_request_id = COALESCE(external_request_id, id::text),
    template_group_code = COALESCE(template_group_code, template_code),
    initiator_type = COALESCE(initiator_type, 'SYSTEM'),
    initiator_user_id = COALESCE(initiator_user_id, sender_user_id),
    parameters = COALESCE(parameters, payload, '{}'::jsonb),
    sensitive_parameters_ciphertext = COALESCE(sensitive_parameters_ciphertext, sensitive_payload);
ALTER TABLE spectra_notification.ntf_request
    ALTER COLUMN external_request_id SET NOT NULL,
    ALTER COLUMN template_group_code SET NOT NULL,
    ALTER COLUMN initiator_type SET NOT NULL,
    ALTER COLUMN parameters SET NOT NULL;

ALTER TABLE spectra_notification.ntf_task
    ADD COLUMN IF NOT EXISTS notification_request_id UUID,
    ADD COLUMN IF NOT EXISTS receiver_user_id UUID,
    ADD COLUMN IF NOT EXISTS recipient_key_hash VARCHAR(128),
    ADD COLUMN IF NOT EXISTS recipient_masked VARCHAR(200),
    ADD COLUMN IF NOT EXISTS recipient_ciphertext TEXT,
    ADD COLUMN IF NOT EXISTS template_id UUID,
    ADD COLUMN IF NOT EXISTS sensitive_parameters_ciphertext TEXT,
    ADD COLUMN IF NOT EXISTS priority SMALLINT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS attempt_count INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS max_attempts INTEGER NOT NULL DEFAULT 3,
    ADD COLUMN IF NOT EXISTS next_retry_at TIMESTAMP(6) WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS locked_by VARCHAR(100),
    ADD COLUMN IF NOT EXISTS locked_at TIMESTAMP(6) WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS last_error_code VARCHAR(100);
UPDATE spectra_notification.ntf_task
SET notification_request_id = COALESCE(notification_request_id, request_id),
    receiver_user_id = COALESCE(receiver_user_id, recipient_user_id),
    recipient_key_hash = COALESCE(recipient_key_hash, md5(COALESCE(recipient_user_id::text, recipient_address, ''))),
    recipient_masked = COALESCE(recipient_masked, CASE WHEN recipient_address IS NULL THEN NULL ELSE '[已加密]' END),
    recipient_ciphertext = COALESCE(recipient_ciphertext, recipient_address),
    sensitive_parameters_ciphertext = COALESCE(sensitive_parameters_ciphertext, sensitive_payload),
    attempt_count = COALESCE(attempt_count, retry_count, 0),
    next_retry_at = COALESCE(next_retry_at, scheduled_at),
    last_error_code = COALESCE(last_error_code, left(last_error, 100));
ALTER TABLE spectra_notification.ntf_task
    ALTER COLUMN notification_request_id SET NOT NULL,
    ALTER COLUMN recipient_key_hash SET NOT NULL;

ALTER TABLE spectra_notification.ntf_delivery
    ADD COLUMN IF NOT EXISTS notification_task_id UUID,
    ADD COLUMN IF NOT EXISTS attempt_no INTEGER NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS provider VARCHAR(50),
    ADD COLUMN IF NOT EXISTS started_at TIMESTAMP(6) WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS completed_at TIMESTAMP(6) WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS result_status VARCHAR(20),
    ADD COLUMN IF NOT EXISTS error_code VARCHAR(100),
    ADD COLUMN IF NOT EXISTS error_message_sanitized TEXT,
    ADD COLUMN IF NOT EXISTS duration_ms BIGINT;
ALTER TABLE spectra_notification.ntf_delivery
    ALTER COLUMN response_summary TYPE JSONB USING pg_temp.ntf_safe_jsonb(response_summary);
UPDATE spectra_notification.ntf_delivery
SET notification_task_id = COALESCE(notification_task_id, task_id),
    provider = COALESCE(provider, provider_code),
    result_status = COALESCE(result_status, status),
    started_at = COALESCE(started_at, sent_at, created_at),
    completed_at = COALESCE(completed_at, sent_at, created_at);
ALTER TABLE spectra_notification.ntf_delivery
    ALTER COLUMN notification_task_id SET NOT NULL,
    ALTER COLUMN provider SET NOT NULL,
    ALTER COLUMN result_status SET NOT NULL;

ALTER TABLE spectra_notification.ntf_inbox_message
    ADD COLUMN IF NOT EXISTS notification_task_id UUID,
    ADD COLUMN IF NOT EXISTS notification_request_id UUID,
    ADD COLUMN IF NOT EXISTS receiver_user_id UUID,
    ADD COLUMN IF NOT EXISTS is_read BOOLEAN NOT NULL DEFAULT FALSE;
UPDATE spectra_notification.ntf_inbox_message
SET notification_task_id = COALESCE(notification_task_id, task_id),
    notification_request_id = COALESCE(notification_request_id, request_id),
    receiver_user_id = COALESCE(receiver_user_id, recipient_user_id),
    is_read = read_at IS NOT NULL;
ALTER TABLE spectra_notification.ntf_inbox_message
    ALTER COLUMN receiver_user_id SET NOT NULL;

ALTER TABLE spectra_notification.ntf_user_preference
    ADD COLUMN IF NOT EXISTS do_not_disturb_start TIMESTAMP(6) WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS do_not_disturb_end TIMESTAMP(6) WITH TIME ZONE;

CREATE UNIQUE INDEX IF NOT EXISTS "UK_NTF_REQUEST_EXTERNAL_ID"
    ON spectra_notification.ntf_request (tenant_id, external_request_id)
    WHERE deleted IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS "UK_NTF_REQUEST_IDEMPOTENCY"
    ON spectra_notification.ntf_request (tenant_id, idempotency_key)
    WHERE deleted IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS "UK_NTF_TASK_RECIPIENT_CHANNEL"
    ON spectra_notification.ntf_task (notification_request_id, recipient_key_hash, channel)
    WHERE deleted IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS "UK_NTF_DELIVERY_ATTEMPT"
    ON spectra_notification.ntf_delivery (notification_task_id, attempt_no)
    WHERE deleted IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS "UK_NTF_INBOX_TASK"
    ON spectra_notification.ntf_inbox_message (notification_task_id)
    WHERE notification_task_id IS NOT NULL AND deleted IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS "UK_NTF_USER_PREFERENCE"
    ON spectra_notification.ntf_user_preference (tenant_id, user_id, purpose, channel)
    WHERE deleted IS NULL;

COMMIT;
