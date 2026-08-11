BEGIN;
INSERT INTO spectra_notification.ntf_user_preference
    (id, tenant_id, user_id, purpose, channel, enabled, do_not_disturb, created_at, updated_at)
SELECT gen_random_uuid(), '00000000-0000-0000-0000-000000000000', s.user_id, v.purpose, 'IN_APP', v.enabled,
       COALESCE(s.do_not_disturb, FALSE), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM spectra_core.sys_notification_setting s
CROSS JOIN LATERAL (VALUES
    ('SYSTEM_NOTICE', COALESCE(s.system_enabled, TRUE)),
    ('WORKFLOW_TODO', COALESCE(s.workflow_enabled, TRUE)),
    ('OA_NOTICE', COALESCE(s.oa_enabled, TRUE)),
    ('INNER_MESSAGE', COALESCE(s.inner_mail_enabled, TRUE)),
    ('WORKFLOW_RESULT', COALESCE(s.approval_enabled, TRUE))
) AS v(purpose, enabled)
ON CONFLICT (tenant_id, user_id, purpose, channel) DO UPDATE
SET enabled = EXCLUDED.enabled, do_not_disturb = EXCLUDED.do_not_disturb, updated_at = CURRENT_TIMESTAMP;
COMMIT;
