-- 统一通知模块最终表结构。
-- 约束：通知表只允许引用通知域内部表；用户、部门和业务对象均为逻辑弱引用。

CREATE SCHEMA IF NOT EXISTS spectra_notification;

CREATE TABLE IF NOT EXISTS spectra_notification.ntf_template (
    id                    UUID NOT NULL,
    tenant_id             UUID NOT NULL,
    template_group_code   VARCHAR(100) NOT NULL,
    channel               VARCHAR(16) NOT NULL,
    purpose               VARCHAR(50) NOT NULL,
    version_no            INTEGER NOT NULL,
    title_template        TEXT,
    content_template      TEXT NOT NULL,
    html_template         TEXT,
    parameter_schema      JSONB NOT NULL DEFAULT '{}'::jsonb,
    provider_template_code VARCHAR(200),
    enabled               BOOLEAN NOT NULL DEFAULT TRUE,
    created_by            UUID,
    created_at            TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by            UUID,
    updated_at            TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted               TIMESTAMP(6) WITH TIME ZONE,
    version               BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT "PK_NTF_TEMPLATE" PRIMARY KEY (id),
    CONSTRAINT "CK_NTF_TEMPLATE_CHANNEL" CHECK (channel IN ('IN_APP', 'SMS', 'EMAIL'))
);

CREATE TABLE IF NOT EXISTS spectra_notification.ntf_request (
    id                              UUID NOT NULL,
    tenant_id                       UUID NOT NULL,
    external_request_id             VARCHAR(100) NOT NULL,
    idempotency_key                 VARCHAR(200) NOT NULL,
    purpose                         VARCHAR(50) NOT NULL,
    template_group_code             VARCHAR(100) NOT NULL,
    source_module                   VARCHAR(50) NOT NULL,
    business_type                   VARCHAR(100) NOT NULL,
    business_id                     VARCHAR(100) NOT NULL,
    initiator_type                  VARCHAR(20) NOT NULL,
    initiator_user_id               UUID,
    source_department_id            UUID,
    parameters                      JSONB NOT NULL DEFAULT '{}'::jsonb,
    sensitive_parameters_ciphertext TEXT,
    encryption_key_id               VARCHAR(50),
    status                          VARCHAR(20) NOT NULL DEFAULT 'ACCEPTED',
    recipient_count                 INTEGER NOT NULL DEFAULT 0,
    task_count                      INTEGER NOT NULL DEFAULT 0,
    scheduled_at                    TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at                      TIMESTAMP(6) WITH TIME ZONE,
    priority                        SMALLINT NOT NULL DEFAULT 0,
    trace_id                        VARCHAR(100),
    created_by                      UUID,
    created_at                      TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by                      UUID,
    updated_at                      TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted                         TIMESTAMP(6) WITH TIME ZONE,
    version                         BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT "PK_NTF_REQUEST" PRIMARY KEY (id),
    CONSTRAINT "CK_NTF_REQUEST_STATUS" CHECK (status IN ('ACCEPTED', 'DISPATCHING', 'SUCCEEDED', 'PARTIAL', 'FAILED', 'CANCELLED', 'EXPIRED')),
    CONSTRAINT "CK_NTF_REQUEST_COUNTS" CHECK (recipient_count >= 0 AND task_count >= 0)
);

CREATE TABLE IF NOT EXISTS spectra_notification.ntf_task (
    id                              UUID NOT NULL,
    tenant_id                       UUID NOT NULL,
    notification_request_id         UUID NOT NULL,
    channel                         VARCHAR(16) NOT NULL,
    receiver_user_id                UUID,
    recipient_key_hash              VARCHAR(128) NOT NULL,
    recipient_masked                VARCHAR(200),
    recipient_ciphertext            TEXT,
    template_id                     UUID,
    purpose                         VARCHAR(50) NOT NULL,
    title                           TEXT NOT NULL,
    content                         TEXT NOT NULL,
    link                            VARCHAR(500),
    extra                           JSONB NOT NULL DEFAULT '{}'::jsonb,
    sensitive_parameters_ciphertext TEXT,
    priority                        SMALLINT NOT NULL DEFAULT 0,
    attempt_count                   INTEGER NOT NULL DEFAULT 0,
    max_attempts                    INTEGER NOT NULL DEFAULT 3,
    scheduled_at                    TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    next_retry_at                   TIMESTAMP(6) WITH TIME ZONE,
    expires_at                      TIMESTAMP(6) WITH TIME ZONE,
    locked_by                       VARCHAR(100),
    locked_at                       TIMESTAMP(6) WITH TIME ZONE,
    status                          VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    last_error_code                 VARCHAR(100),
    created_by                      UUID,
    created_at                      TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by                      UUID,
    updated_at                      TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted                         TIMESTAMP(6) WITH TIME ZONE,
    version                         BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT "PK_NTF_TASK" PRIMARY KEY (id),
    CONSTRAINT "FK_NTF_TASK_REQUEST" FOREIGN KEY (notification_request_id)
        REFERENCES spectra_notification.ntf_request (id),
    CONSTRAINT "FK_NTF_TASK_TEMPLATE" FOREIGN KEY (template_id)
        REFERENCES spectra_notification.ntf_template (id),
    CONSTRAINT "CK_NTF_TASK_CHANNEL" CHECK (channel IN ('IN_APP', 'SMS', 'EMAIL')),
    CONSTRAINT "CK_NTF_TASK_STATUS" CHECK (status IN ('PENDING', 'PROCESSING', 'RETRYING', 'SENT', 'FAILED', 'BLOCKED', 'UNKNOWN', 'EXPIRED', 'CANCELLED')),
    CONSTRAINT "CK_NTF_TASK_ATTEMPTS" CHECK (attempt_count >= 0 AND max_attempts > 0),
    CONSTRAINT "CK_NTF_TASK_RECEIVER" CHECK (channel <> 'IN_APP' OR receiver_user_id IS NOT NULL),
    CONSTRAINT "CK_NTF_TASK_ADDRESS" CHECK (channel = 'IN_APP' OR (recipient_masked IS NOT NULL AND recipient_ciphertext IS NOT NULL))
);

CREATE TABLE IF NOT EXISTS spectra_notification.ntf_delivery (
    id                      UUID NOT NULL,
    tenant_id               UUID NOT NULL,
    notification_task_id    UUID NOT NULL,
    attempt_no              INTEGER NOT NULL,
    provider                VARCHAR(50) NOT NULL,
    provider_message_id     VARCHAR(200),
    started_at              TIMESTAMP(6) WITH TIME ZONE,
    completed_at            TIMESTAMP(6) WITH TIME ZONE,
    result_status           VARCHAR(20) NOT NULL,
    error_code              VARCHAR(100),
    error_message_sanitized TEXT,
    duration_ms             BIGINT,
    response_summary        JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_by              UUID,
    created_at              TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by              UUID,
    updated_at              TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted                 TIMESTAMP(6) WITH TIME ZONE,
    version                 BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT "PK_NTF_DELIVERY" PRIMARY KEY (id),
    CONSTRAINT "FK_NTF_DELIVERY_TASK" FOREIGN KEY (notification_task_id)
        REFERENCES spectra_notification.ntf_task (id),
    CONSTRAINT "CK_NTF_DELIVERY_ATTEMPT" CHECK (attempt_no > 0),
    CONSTRAINT "CK_NTF_DELIVERY_STATUS" CHECK (result_status IN ('ACCEPTED', 'SENT', 'FAILED', 'BLOCKED', 'UNKNOWN'))
);

CREATE TABLE IF NOT EXISTS spectra_notification.ntf_inbox_message (
    id                       UUID NOT NULL,
    tenant_id                UUID NOT NULL,
    notification_task_id     UUID,
    notification_request_id  UUID,
    receiver_user_id         UUID NOT NULL,
    purpose                  VARCHAR(50) NOT NULL,
    title                    VARCHAR(255) NOT NULL,
    content                  TEXT NOT NULL,
    sender_user_id           UUID,
    sender_name              VARCHAR(100),
    link                     VARCHAR(500),
    is_read                  BOOLEAN NOT NULL DEFAULT FALSE,
    read_at                  TIMESTAMP(6) WITH TIME ZONE,
    extra                    JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_by               UUID,
    created_at               TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by               UUID,
    updated_at               TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted                  TIMESTAMP(6) WITH TIME ZONE,
    version                  BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT "PK_NTF_INBOX_MESSAGE" PRIMARY KEY (id),
    CONSTRAINT "FK_NTF_INBOX_TASK" FOREIGN KEY (notification_task_id)
        REFERENCES spectra_notification.ntf_task (id),
    CONSTRAINT "FK_NTF_INBOX_REQUEST" FOREIGN KEY (notification_request_id)
        REFERENCES spectra_notification.ntf_request (id),
    CONSTRAINT "CK_NTF_INBOX_READ" CHECK ((is_read AND read_at IS NOT NULL) OR (NOT is_read AND read_at IS NULL))
);

CREATE TABLE IF NOT EXISTS spectra_notification.ntf_user_preference (
    id                    UUID NOT NULL,
    tenant_id             UUID NOT NULL,
    user_id               UUID NOT NULL,
    purpose               VARCHAR(50) NOT NULL,
    channel               VARCHAR(16) NOT NULL,
    enabled               BOOLEAN NOT NULL DEFAULT TRUE,
    do_not_disturb        BOOLEAN NOT NULL DEFAULT FALSE,
    do_not_disturb_start TIMESTAMP(6) WITH TIME ZONE,
    do_not_disturb_end   TIMESTAMP(6) WITH TIME ZONE,
    created_by            UUID,
    created_at            TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by            UUID,
    updated_at            TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted               TIMESTAMP(6) WITH TIME ZONE,
    version               BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT "PK_NTF_USER_PREFERENCE" PRIMARY KEY (id),
    CONSTRAINT "CK_NTF_USER_PREFERENCE_CHANNEL" CHECK (channel IN ('IN_APP', 'SMS', 'EMAIL'))
);

CREATE UNIQUE INDEX IF NOT EXISTS "UK_NTF_TEMPLATE_VERSION"
    ON spectra_notification.ntf_template (tenant_id, template_group_code, channel, version_no)
    WHERE deleted IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS "UK_NTF_TEMPLATE_ENABLED"
    ON spectra_notification.ntf_template (tenant_id, template_group_code, channel)
    WHERE enabled = TRUE AND deleted IS NULL;
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

CREATE INDEX IF NOT EXISTS "IDX_NTF_TASK_PENDING"
    ON spectra_notification.ntf_task (status, next_retry_at, priority DESC, created_at)
    WHERE deleted IS NULL;
CREATE INDEX IF NOT EXISTS "IDX_NTF_TASK_EXPIRES_AT"
    ON spectra_notification.ntf_task (expires_at)
    WHERE deleted IS NULL;
CREATE INDEX IF NOT EXISTS "IDX_NTF_TASK_RECEIVER_CREATED"
    ON spectra_notification.ntf_task (receiver_user_id, created_at DESC)
    WHERE deleted IS NULL;
CREATE INDEX IF NOT EXISTS "IDX_NTF_DELIVERY_TASK_CREATED"
    ON spectra_notification.ntf_delivery (notification_task_id, created_at DESC)
    WHERE deleted IS NULL;
CREATE INDEX IF NOT EXISTS "IDX_NTF_INBOX_RECEIVER_CREATED"
    ON spectra_notification.ntf_inbox_message (tenant_id, receiver_user_id, created_at DESC)
    WHERE deleted IS NULL;
CREATE INDEX IF NOT EXISTS "IDX_NTF_INBOX_RECEIVER_UNREAD"
    ON spectra_notification.ntf_inbox_message (tenant_id, receiver_user_id, created_at DESC)
    WHERE deleted IS NULL AND is_read = FALSE;
CREATE INDEX IF NOT EXISTS "IDX_NTF_USER_PREFERENCE_USER"
    ON spectra_notification.ntf_user_preference (tenant_id, user_id)
    WHERE deleted IS NULL;

COMMENT ON TABLE spectra_notification.ntf_template IS '通知模板版本表';
COMMENT ON TABLE spectra_notification.ntf_request IS '逻辑通知请求表';
COMMENT ON TABLE spectra_notification.ntf_task IS '接收人和渠道维度的通知任务表';
COMMENT ON TABLE spectra_notification.ntf_delivery IS '通知渠道单次投递尝试审计表';
COMMENT ON TABLE spectra_notification.ntf_inbox_message IS '当前用户站内信收件箱表';
COMMENT ON TABLE spectra_notification.ntf_user_preference IS '用户用途和渠道偏好表';
