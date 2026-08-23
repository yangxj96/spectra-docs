-- 统一通知模块最终表结构。
-- 约束：通知表只允许引用通知域内部表；用户、部门和业务对象均为逻辑弱引用。

CREATE SCHEMA IF NOT EXISTS spectra_notification;

CREATE TABLE IF NOT EXISTS spectra_notification.ntf_template (
    id                    UUID NOT NULL,
    template_group_code   VARCHAR(100) NOT NULL,
    channel               VARCHAR(16) NOT NULL,
    purpose               VARCHAR(50) NOT NULL,
    version_no            INTEGER NOT NULL,
    title_template        TEXT,
    content_template      TEXT NOT NULL,
    html_template         TEXT,
    parameter_schema      JSONB NOT NULL DEFAULT '{}'::jsonb,
    provider_template_code VARCHAR(200),
    state                 VARCHAR(16) NOT NULL DEFAULT 'DRAFT',
    created_by            UUID,
    created_at            TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by            UUID,
    updated_at            TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted               TIMESTAMP(6) WITH TIME ZONE,
    version               BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT "PK_NTF_TEMPLATE" PRIMARY KEY (id),
    CONSTRAINT "CK_NTF_TEMPLATE_CHANNEL" CHECK (channel IN ('IN_APP', 'SMS', 'EMAIL')),
    CONSTRAINT "CK_NTF_TEMPLATE_STATE" CHECK (state IN ('DRAFT', 'PUBLISHED', 'DISABLED', 'ARCHIVED'))
);

CREATE TABLE IF NOT EXISTS spectra_notification.ntf_request (
    id                              UUID NOT NULL,
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
    ON spectra_notification.ntf_template (template_group_code, channel, version_no)
    WHERE deleted IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS "UK_NTF_TEMPLATE_PUBLISHED"
    ON spectra_notification.ntf_template (template_group_code, channel)
    WHERE state = 'PUBLISHED' AND deleted IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS "UK_NTF_REQUEST_EXTERNAL_ID"
    ON spectra_notification.ntf_request (external_request_id)
    WHERE deleted IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS "UK_NTF_REQUEST_IDEMPOTENCY"
    ON spectra_notification.ntf_request (idempotency_key)
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
    ON spectra_notification.ntf_user_preference (user_id, purpose, channel)
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
    ON spectra_notification.ntf_inbox_message (receiver_user_id, created_at DESC)
    WHERE deleted IS NULL;
CREATE INDEX IF NOT EXISTS "IDX_NTF_INBOX_RECEIVER_UNREAD"
    ON spectra_notification.ntf_inbox_message (receiver_user_id, created_at DESC)
    WHERE deleted IS NULL AND is_read = FALSE;
CREATE INDEX IF NOT EXISTS "IDX_NTF_USER_PREFERENCE_USER"
    ON spectra_notification.ntf_user_preference (user_id)
    WHERE deleted IS NULL;

COMMENT ON TABLE spectra_notification.ntf_template IS '通知模板版本表';
COMMENT ON TABLE spectra_notification.ntf_request IS '逻辑通知请求表';
COMMENT ON TABLE spectra_notification.ntf_task IS '接收人和渠道维度的通知任务表';
COMMENT ON TABLE spectra_notification.ntf_delivery IS '通知渠道单次投递尝试审计表';
COMMENT ON TABLE spectra_notification.ntf_inbox_message IS '当前用户站内信收件箱表';
COMMENT ON TABLE spectra_notification.ntf_user_preference IS '用户用途和渠道偏好表';

COMMENT ON COLUMN spectra_notification.ntf_template.id IS '主键ID';
COMMENT ON COLUMN spectra_notification.ntf_template.template_group_code IS '逻辑模板组编码';
COMMENT ON COLUMN spectra_notification.ntf_template.channel IS '投递渠道：IN_APP、SMS或EMAIL';
COMMENT ON COLUMN spectra_notification.ntf_template.purpose IS '通知用途';
COMMENT ON COLUMN spectra_notification.ntf_template.version_no IS '模板版本号';
COMMENT ON COLUMN spectra_notification.ntf_template.title_template IS '标题模板；无需标题时可为空';
COMMENT ON COLUMN spectra_notification.ntf_template.content_template IS '正文模板';
COMMENT ON COLUMN spectra_notification.ntf_template.html_template IS 'HTML正文模板；非HTML渠道可为空';
COMMENT ON COLUMN spectra_notification.ntf_template.parameter_schema IS '模板参数JSON Schema';
COMMENT ON COLUMN spectra_notification.ntf_template.provider_template_code IS '渠道供应商模板编码';
COMMENT ON COLUMN spectra_notification.ntf_template.state IS '模板生命周期状态：DRAFT、PUBLISHED、DISABLED或ARCHIVED';
COMMENT ON COLUMN spectra_notification.ntf_template.created_by IS '创建人ID';
COMMENT ON COLUMN spectra_notification.ntf_template.created_at IS '创建时间';
COMMENT ON COLUMN spectra_notification.ntf_template.updated_by IS '最后更新人ID';
COMMENT ON COLUMN spectra_notification.ntf_template.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_notification.ntf_template.deleted IS '删除时间；NULL表示未删除';
COMMENT ON COLUMN spectra_notification.ntf_template.version IS '乐观锁版本号';

COMMENT ON COLUMN spectra_notification.ntf_request.id IS '主键ID';
COMMENT ON COLUMN spectra_notification.ntf_request.external_request_id IS '调用方生成的外部请求ID';
COMMENT ON COLUMN spectra_notification.ntf_request.idempotency_key IS '业务幂等键；通知域内唯一';
COMMENT ON COLUMN spectra_notification.ntf_request.purpose IS '通知用途';
COMMENT ON COLUMN spectra_notification.ntf_request.template_group_code IS '逻辑模板组编码';
COMMENT ON COLUMN spectra_notification.ntf_request.source_module IS '发起请求的业务模块编码';
COMMENT ON COLUMN spectra_notification.ntf_request.business_type IS '业务对象类型；与business_id构成弱引用';
COMMENT ON COLUMN spectra_notification.ntf_request.business_id IS '业务对象ID；不建立跨模块外键';
COMMENT ON COLUMN spectra_notification.ntf_request.initiator_type IS '发起方类型：用户或系统';
COMMENT ON COLUMN spectra_notification.ntf_request.initiator_user_id IS '发起用户ID；系统发起时可为空';
COMMENT ON COLUMN spectra_notification.ntf_request.source_department_id IS '发起请求时的来源部门ID';
COMMENT ON COLUMN spectra_notification.ntf_request.parameters IS '可记录和持久化的非敏感模板参数';
COMMENT ON COLUMN spectra_notification.ntf_request.sensitive_parameters_ciphertext IS '加密后的敏感模板参数';
COMMENT ON COLUMN spectra_notification.ntf_request.encryption_key_id IS '敏感参数使用的加密密钥标识';
COMMENT ON COLUMN spectra_notification.ntf_request.status IS '逻辑通知请求状态';
COMMENT ON COLUMN spectra_notification.ntf_request.recipient_count IS '请求展开后的接收人数';
COMMENT ON COLUMN spectra_notification.ntf_request.task_count IS '请求展开后的投递任务数';
COMMENT ON COLUMN spectra_notification.ntf_request.scheduled_at IS '计划开始投递时间';
COMMENT ON COLUMN spectra_notification.ntf_request.expires_at IS '投递截止时间；为空表示不过期';
COMMENT ON COLUMN spectra_notification.ntf_request.priority IS '任务优先级；数值越大越优先';
COMMENT ON COLUMN spectra_notification.ntf_request.trace_id IS '调用链追踪ID';
COMMENT ON COLUMN spectra_notification.ntf_request.created_by IS '创建人ID';
COMMENT ON COLUMN spectra_notification.ntf_request.created_at IS '创建时间';
COMMENT ON COLUMN spectra_notification.ntf_request.updated_by IS '最后更新人ID';
COMMENT ON COLUMN spectra_notification.ntf_request.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_notification.ntf_request.deleted IS '删除时间；NULL表示未删除';
COMMENT ON COLUMN spectra_notification.ntf_request.version IS '乐观锁版本号';

COMMENT ON COLUMN spectra_notification.ntf_task.id IS '主键ID';
COMMENT ON COLUMN spectra_notification.ntf_task.notification_request_id IS '所属逻辑通知请求ID';
COMMENT ON COLUMN spectra_notification.ntf_task.channel IS '投递渠道：IN_APP、SMS或EMAIL';
COMMENT ON COLUMN spectra_notification.ntf_task.receiver_user_id IS '接收用户ID；直接地址投递时可为空';
COMMENT ON COLUMN spectra_notification.ntf_task.recipient_key_hash IS '接收人稳定哈希；用于任务幂等';
COMMENT ON COLUMN spectra_notification.ntf_task.recipient_masked IS '脱敏后的外部接收地址';
COMMENT ON COLUMN spectra_notification.ntf_task.recipient_ciphertext IS '加密后的外部接收地址';
COMMENT ON COLUMN spectra_notification.ntf_task.template_id IS '锁定的通知模板版本ID';
COMMENT ON COLUMN spectra_notification.ntf_task.purpose IS '通知用途';
COMMENT ON COLUMN spectra_notification.ntf_task.title IS '渲染后的通知标题快照';
COMMENT ON COLUMN spectra_notification.ntf_task.content IS '渲染后的通知正文快照';
COMMENT ON COLUMN spectra_notification.ntf_task.link IS '客户端站内跳转路径';
COMMENT ON COLUMN spectra_notification.ntf_task.extra IS '非敏感扩展参数';
COMMENT ON COLUMN spectra_notification.ntf_task.sensitive_parameters_ciphertext IS '加密后的敏感渲染载荷';
COMMENT ON COLUMN spectra_notification.ntf_task.priority IS '任务优先级；数值越大越优先';
COMMENT ON COLUMN spectra_notification.ntf_task.attempt_count IS '已尝试投递次数';
COMMENT ON COLUMN spectra_notification.ntf_task.max_attempts IS '最大允许投递次数';
COMMENT ON COLUMN spectra_notification.ntf_task.scheduled_at IS '计划投递时间';
COMMENT ON COLUMN spectra_notification.ntf_task.next_retry_at IS '下次重试时间';
COMMENT ON COLUMN spectra_notification.ntf_task.expires_at IS '任务过期时间；为空表示不过期';
COMMENT ON COLUMN spectra_notification.ntf_task.locked_by IS '领取任务的Worker标识';
COMMENT ON COLUMN spectra_notification.ntf_task.locked_at IS 'Worker领取任务的时间';
COMMENT ON COLUMN spectra_notification.ntf_task.status IS '通知任务状态';
COMMENT ON COLUMN spectra_notification.ntf_task.last_error_code IS '最后一次投递错误码';
COMMENT ON COLUMN spectra_notification.ntf_task.created_by IS '创建人ID';
COMMENT ON COLUMN spectra_notification.ntf_task.created_at IS '创建时间';
COMMENT ON COLUMN spectra_notification.ntf_task.updated_by IS '最后更新人ID';
COMMENT ON COLUMN spectra_notification.ntf_task.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_notification.ntf_task.deleted IS '删除时间；NULL表示未删除';
COMMENT ON COLUMN spectra_notification.ntf_task.version IS '乐观锁版本号';

COMMENT ON COLUMN spectra_notification.ntf_delivery.id IS '主键ID';
COMMENT ON COLUMN spectra_notification.ntf_delivery.notification_task_id IS '所属通知任务ID';
COMMENT ON COLUMN spectra_notification.ntf_delivery.attempt_no IS '当前任务的投递尝试序号';
COMMENT ON COLUMN spectra_notification.ntf_delivery.provider IS '执行投递的渠道供应商编码';
COMMENT ON COLUMN spectra_notification.ntf_delivery.provider_message_id IS '供应商返回的消息ID';
COMMENT ON COLUMN spectra_notification.ntf_delivery.started_at IS '本次投递开始时间';
COMMENT ON COLUMN spectra_notification.ntf_delivery.completed_at IS '本次投递完成时间';
COMMENT ON COLUMN spectra_notification.ntf_delivery.result_status IS '标准化投递结果状态';
COMMENT ON COLUMN spectra_notification.ntf_delivery.error_code IS '供应商或模块返回的错误码';
COMMENT ON COLUMN spectra_notification.ntf_delivery.error_message_sanitized IS '脱敏后的错误信息';
COMMENT ON COLUMN spectra_notification.ntf_delivery.duration_ms IS '本次投递耗时；单位为毫秒';
COMMENT ON COLUMN spectra_notification.ntf_delivery.response_summary IS '可安全持久化的脱敏响应摘要';
COMMENT ON COLUMN spectra_notification.ntf_delivery.created_by IS '创建人ID';
COMMENT ON COLUMN spectra_notification.ntf_delivery.created_at IS '创建时间';
COMMENT ON COLUMN spectra_notification.ntf_delivery.updated_by IS '最后更新人ID';
COMMENT ON COLUMN spectra_notification.ntf_delivery.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_notification.ntf_delivery.deleted IS '删除时间；NULL表示未删除';
COMMENT ON COLUMN spectra_notification.ntf_delivery.version IS '乐观锁版本号';

COMMENT ON COLUMN spectra_notification.ntf_inbox_message.id IS '主键ID';
COMMENT ON COLUMN spectra_notification.ntf_inbox_message.notification_task_id IS '对应的站内信通知任务ID';
COMMENT ON COLUMN spectra_notification.ntf_inbox_message.notification_request_id IS '对应的逻辑通知请求ID';
COMMENT ON COLUMN spectra_notification.ntf_inbox_message.receiver_user_id IS '消息接收用户ID';
COMMENT ON COLUMN spectra_notification.ntf_inbox_message.purpose IS '通知用途';
COMMENT ON COLUMN spectra_notification.ntf_inbox_message.title IS '消息标题';
COMMENT ON COLUMN spectra_notification.ntf_inbox_message.content IS '消息正文';
COMMENT ON COLUMN spectra_notification.ntf_inbox_message.sender_user_id IS '消息发送用户ID；系统发送时可为空';
COMMENT ON COLUMN spectra_notification.ntf_inbox_message.sender_name IS '消息发送人名称快照';
COMMENT ON COLUMN spectra_notification.ntf_inbox_message.link IS '客户端站内跳转路径';
COMMENT ON COLUMN spectra_notification.ntf_inbox_message.is_read IS '是否已读';
COMMENT ON COLUMN spectra_notification.ntf_inbox_message.read_at IS '阅读时间；未读时为空';
COMMENT ON COLUMN spectra_notification.ntf_inbox_message.extra IS '白名单扩展信息';
COMMENT ON COLUMN spectra_notification.ntf_inbox_message.created_by IS '创建人ID';
COMMENT ON COLUMN spectra_notification.ntf_inbox_message.created_at IS '创建时间';
COMMENT ON COLUMN spectra_notification.ntf_inbox_message.updated_by IS '最后更新人ID';
COMMENT ON COLUMN spectra_notification.ntf_inbox_message.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_notification.ntf_inbox_message.deleted IS '删除时间；NULL表示未删除';
COMMENT ON COLUMN spectra_notification.ntf_inbox_message.version IS '乐观锁版本号';

COMMENT ON COLUMN spectra_notification.ntf_user_preference.id IS '主键ID';
COMMENT ON COLUMN spectra_notification.ntf_user_preference.user_id IS '用户ID';
COMMENT ON COLUMN spectra_notification.ntf_user_preference.purpose IS '通知用途';
COMMENT ON COLUMN spectra_notification.ntf_user_preference.channel IS '投递渠道：IN_APP、SMS或EMAIL';
COMMENT ON COLUMN spectra_notification.ntf_user_preference.enabled IS '是否允许该用途通过该渠道投递';
COMMENT ON COLUMN spectra_notification.ntf_user_preference.do_not_disturb IS '是否启用免打扰';
COMMENT ON COLUMN spectra_notification.ntf_user_preference.do_not_disturb_start IS '免打扰开始时间';
COMMENT ON COLUMN spectra_notification.ntf_user_preference.do_not_disturb_end IS '免打扰结束时间';
COMMENT ON COLUMN spectra_notification.ntf_user_preference.created_by IS '创建人ID';
COMMENT ON COLUMN spectra_notification.ntf_user_preference.created_at IS '创建时间';
COMMENT ON COLUMN spectra_notification.ntf_user_preference.updated_by IS '最后更新人ID';
COMMENT ON COLUMN spectra_notification.ntf_user_preference.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_notification.ntf_user_preference.deleted IS '删除时间；NULL表示未删除';
COMMENT ON COLUMN spectra_notification.ntf_user_preference.version IS '乐观锁版本号';

-- =============================================================================
-- 历史数据迁移（原 迁移/V20260813__migrate_legacy_notifications.sql）
-- =============================================================================

-- LEGACY INPUT ONLY: this migration belongs to the pre-target tenant-aware
-- notification schema and is not part of the new Flyway V1 runtime model.
-- The target schema intentionally removes tenant_id; use the reviewed
-- export/transform/validate/cutover process instead of applying this file to V1.

-- 统一通知模块历史数据迁移。
--
-- 迁移来源：spectra_core.sys_notification、spectra_core.sys_notification_setting。
-- 迁移目标：spectra_notification.ntf_inbox_message、ntf_user_preference。
-- 约定：目标通知表不包含租户字段；脚本可重复执行，不删除旧数据，偏好 ID 使用稳定哈希保证重复执行不产生新行。

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
         WHERE target.user_id = source.user_id
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
