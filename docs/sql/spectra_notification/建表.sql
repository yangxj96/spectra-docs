-- 统一通知模块最终表结构（NT-A～NT-F）。
-- 所有业务引用均为弱引用；消息中心查询必须额外绑定当前用户。
CREATE SCHEMA IF NOT EXISTS spectra_notification;

CREATE TABLE IF NOT EXISTS spectra_notification.ntf_template (
    id UUID PRIMARY KEY,
    tenant_id UUID NOT NULL,
    template_group_code VARCHAR(100) NOT NULL,
    channel VARCHAR(20) NOT NULL,
    purpose VARCHAR(50) NOT NULL,
    version_no INTEGER NOT NULL,
    title_template VARCHAR(500) NULL,
    content_template TEXT NOT NULL,
    html_template TEXT NULL,
    parameter_schema JSONB NOT NULL DEFAULT '{}'::jsonb,
    provider_template_code VARCHAR(200) NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted TIMESTAMPTZ NULL,
    CONSTRAINT uk_ntf_template_version UNIQUE (tenant_id, template_group_code, channel, version_no),
    CONSTRAINT ck_ntf_template_channel CHECK (channel IN ('IN_APP', 'SMS', 'EMAIL'))
);

CREATE UNIQUE INDEX IF NOT EXISTS uk_ntf_template_enabled
    ON spectra_notification.ntf_template (tenant_id, template_group_code, channel)
    WHERE enabled = TRUE AND deleted IS NULL;

CREATE TABLE IF NOT EXISTS spectra_notification.ntf_request (
    id UUID PRIMARY KEY,
    tenant_id UUID NOT NULL,
    business_type VARCHAR(100) NOT NULL,
    business_id VARCHAR(128) NOT NULL,
    idempotency_key VARCHAR(200) NOT NULL,
    template_code VARCHAR(100) NOT NULL,
    purpose VARCHAR(50) NOT NULL,
    sender_user_id UUID NULL,
    source_module VARCHAR(50) NOT NULL,
    source_department_id UUID NULL,
    data_scope_key VARCHAR(200) NULL,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    status VARCHAR(20) NOT NULL DEFAULT 'ACCEPTED',
    scheduled_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ NULL,
    priority INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_ntf_request_idempotency UNIQUE (tenant_id, idempotency_key),
    CONSTRAINT ck_ntf_request_status CHECK (status IN ('ACCEPTED', 'DISPATCHING', 'SUCCEEDED', 'PARTIAL', 'FAILED', 'CANCELLED', 'EXPIRED'))
);

CREATE TABLE IF NOT EXISTS spectra_notification.ntf_task (
    id UUID PRIMARY KEY,
    request_id UUID NOT NULL REFERENCES spectra_notification.ntf_request(id),
    tenant_id UUID NOT NULL,
    recipient_user_id UUID NULL,
    recipient_address VARCHAR(320) NULL,
    channel VARCHAR(20) NOT NULL,
    purpose VARCHAR(50) NOT NULL,
    title VARCHAR(500) NOT NULL,
    content TEXT NOT NULL,
    link VARCHAR(500) NULL,
    extra JSONB NOT NULL DEFAULT '{}'::jsonb,
    scheduled_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    retry_count INTEGER NOT NULL DEFAULT 0,
    last_error VARCHAR(1000) NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_ntf_task_recipient_channel UNIQUE (request_id, recipient_user_id, channel),
    CONSTRAINT ck_ntf_task_channel CHECK (channel IN ('IN_APP', 'SMS', 'EMAIL')),
    CONSTRAINT ck_ntf_task_status CHECK (status IN ('PENDING', 'PROCESSING', 'RETRYING', 'SENT', 'FAILED', 'BLOCKED', 'UNKNOWN', 'EXPIRED', 'CANCELLED'))
);

CREATE TABLE IF NOT EXISTS spectra_notification.ntf_delivery (
    id UUID PRIMARY KEY,
    task_id UUID NOT NULL REFERENCES spectra_notification.ntf_task(id),
    provider_code VARCHAR(100) NOT NULL,
    provider_message_id VARCHAR(200) NULL,
    status VARCHAR(20) NOT NULL,
    response_summary VARCHAR(1000) NULL,
    sent_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_ntf_delivery_status CHECK (status IN ('ACCEPTED', 'SENT', 'FAILED', 'BLOCKED', 'UNKNOWN'))
);

CREATE TABLE IF NOT EXISTS spectra_notification.ntf_inbox_message (
    id UUID PRIMARY KEY,
    tenant_id UUID NOT NULL,
    recipient_user_id UUID NOT NULL,
    request_id UUID NOT NULL REFERENCES spectra_notification.ntf_request(id),
    task_id UUID NOT NULL REFERENCES spectra_notification.ntf_task(id),
    purpose VARCHAR(50) NOT NULL,
    title VARCHAR(500) NOT NULL,
    content TEXT NOT NULL,
    sender_user_id UUID NULL,
    sender_name VARCHAR(200) NULL,
    link VARCHAR(500) NULL,
    extra JSONB NOT NULL DEFAULT '{}'::jsonb,
    read_at TIMESTAMPTZ NULL,
    archived_at TIMESTAMPTZ NULL,
    deleted TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_ntf_inbox_task UNIQUE (task_id)
);

CREATE TABLE IF NOT EXISTS spectra_notification.ntf_user_preference (
    id UUID PRIMARY KEY,
    tenant_id UUID NOT NULL,
    user_id UUID NOT NULL,
    purpose VARCHAR(50) NOT NULL,
    channel VARCHAR(20) NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    do_not_disturb BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_ntf_user_preference UNIQUE (tenant_id, user_id, purpose, channel),
    CONSTRAINT ck_ntf_user_preference_channel CHECK (channel IN ('IN_APP', 'SMS', 'EMAIL'))
);

CREATE INDEX IF NOT EXISTS idx_ntf_task_pending ON spectra_notification.ntf_task (status, scheduled_at);
CREATE INDEX IF NOT EXISTS idx_ntf_task_request ON spectra_notification.ntf_task (request_id, status);
CREATE INDEX IF NOT EXISTS idx_ntf_delivery_task ON spectra_notification.ntf_delivery (task_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ntf_inbox_owner_created
    ON spectra_notification.ntf_inbox_message (tenant_id, recipient_user_id, created_at DESC)
    WHERE deleted IS NULL AND archived_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_ntf_inbox_owner_unread
    ON spectra_notification.ntf_inbox_message (tenant_id, recipient_user_id, read_at)
    WHERE deleted IS NULL AND archived_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_ntf_user_preference_user
    ON spectra_notification.ntf_user_preference (tenant_id, user_id);

COMMENT ON TABLE spectra_notification.ntf_template IS '通知模板：按模板组、用途和渠道版本化管理';
COMMENT ON TABLE spectra_notification.ntf_request IS '逻辑通知请求：以幂等键约束一次业务通知';
COMMENT ON TABLE spectra_notification.ntf_task IS '通知投递任务：按接收人和渠道展开，支持 Worker 重试';
COMMENT ON TABLE spectra_notification.ntf_delivery IS '通知渠道投递尝试记录，不保存敏感正文';
COMMENT ON TABLE spectra_notification.ntf_inbox_message IS '站内信收件箱，所有权强制绑定 recipient_user_id';
COMMENT ON TABLE spectra_notification.ntf_user_preference IS '用户用途×渠道偏好，安全用途由策略强制开启';
