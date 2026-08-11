-- 统一通知模块（NT-A～NT-C）基础表。
-- 所有表及字段均显式注释；业务数据通过 tenant_id、recipient_user_id 与 data_scope_key 限定范围。
CREATE SCHEMA IF NOT EXISTS spectra_notification;

CREATE TABLE IF NOT EXISTS spectra_notification.ntf_template (
    id UUID PRIMARY KEY,
    tenant_id UUID NOT NULL,
    template_code VARCHAR(100) NOT NULL,
    channel VARCHAR(20) NOT NULL,
    title VARCHAR(500) NOT NULL,
    content TEXT NOT NULL,
    title_template VARCHAR(500) NOT NULL,
    content_template TEXT NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted TIMESTAMPTZ NULL,
    CONSTRAINT uk_ntf_template_code UNIQUE (tenant_id, template_code, channel),
    CONSTRAINT ck_ntf_template_channel CHECK (channel IN ('INBOX', 'SMS', 'EMAIL'))
);
COMMENT ON TABLE spectra_notification.ntf_template IS '通知模板表：定义站内信、短信和邮件的标题及内容模板';
COMMENT ON COLUMN spectra_notification.ntf_template.id IS '通知模板主键';
COMMENT ON COLUMN spectra_notification.ntf_template.tenant_id IS '租户主键，隔离不同租户模板';
COMMENT ON COLUMN spectra_notification.ntf_template.template_code IS '业务模板编码';
COMMENT ON COLUMN spectra_notification.ntf_template.channel IS '发送渠道：INBOX-站内信，SMS-短信，EMAIL-邮件';
COMMENT ON COLUMN spectra_notification.ntf_template.title_template IS '标题模板，支持变量占位符';
COMMENT ON COLUMN spectra_notification.ntf_template.content_template IS '正文模板，支持变量占位符';
COMMENT ON COLUMN spectra_notification.ntf_template.enabled IS '是否启用';
COMMENT ON COLUMN spectra_notification.ntf_template.created_at IS '创建时间';
COMMENT ON COLUMN spectra_notification.ntf_template.updated_at IS '更新时间';
COMMENT ON COLUMN spectra_notification.ntf_template.deleted IS '软删除时间，NULL表示未删除';

CREATE TABLE IF NOT EXISTS spectra_notification.ntf_request (
    id UUID PRIMARY KEY,
    tenant_id UUID NOT NULL,
    business_type VARCHAR(100) NOT NULL,
    business_id VARCHAR(128) NOT NULL,
    idempotency_key VARCHAR(200) NOT NULL,
    template_code VARCHAR(100) NOT NULL,
    sender_user_id UUID NULL,
    data_scope_key VARCHAR(200) NULL,
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    status VARCHAR(20) NOT NULL DEFAULT 'ACCEPTED',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uk_ntf_request_idempotency UNIQUE (tenant_id, idempotency_key),
    CONSTRAINT ck_ntf_request_status CHECK (status IN ('ACCEPTED', 'DISPATCHED', 'PARTIAL', 'COMPLETED', 'FAILED'))
);
COMMENT ON TABLE spectra_notification.ntf_request IS '通知请求表：记录业务方提交的一次逻辑通知及幂等边界';
COMMENT ON COLUMN spectra_notification.ntf_request.id IS '通知请求主键';
COMMENT ON COLUMN spectra_notification.ntf_request.tenant_id IS '租户主键';
COMMENT ON COLUMN spectra_notification.ntf_request.business_type IS '业务类型编码';
COMMENT ON COLUMN spectra_notification.ntf_request.business_id IS '业务对象标识';
COMMENT ON COLUMN spectra_notification.ntf_request.idempotency_key IS '业务方幂等键，同租户内唯一';
COMMENT ON COLUMN spectra_notification.ntf_request.template_code IS '使用的通知模板编码';
COMMENT ON COLUMN spectra_notification.ntf_request.sender_user_id IS '发起通知的用户主键，系统通知可为空';
COMMENT ON COLUMN spectra_notification.ntf_request.data_scope_key IS '业务数据范围键，用于审计和下游授权校验';
COMMENT ON COLUMN spectra_notification.ntf_request.payload IS '模板变量及审计元数据 JSON';
COMMENT ON COLUMN spectra_notification.ntf_request.status IS '请求状态：ACCEPTED/DISPATCHED/PARTIAL/COMPLETED/FAILED';
COMMENT ON COLUMN spectra_notification.ntf_request.created_at IS '请求创建时间';

CREATE TABLE IF NOT EXISTS spectra_notification.ntf_task (
    id UUID PRIMARY KEY,
    request_id UUID NOT NULL REFERENCES spectra_notification.ntf_request(id),
    tenant_id UUID NOT NULL,
    recipient_user_id UUID NULL,
    recipient_address VARCHAR(320) NULL,
    channel VARCHAR(20) NOT NULL,
    scheduled_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    retry_count INTEGER NOT NULL DEFAULT 0,
    last_error VARCHAR(1000) NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_ntf_task_channel CHECK (channel IN ('INBOX', 'SMS', 'EMAIL')),
    CONSTRAINT ck_ntf_task_status CHECK (status IN ('PENDING', 'PROCESSING', 'SENT', 'FAILED', 'CANCELLED'))
);
COMMENT ON TABLE spectra_notification.ntf_task IS '通知任务表：按收件人和渠道拆分可重试的发送任务';
COMMENT ON COLUMN spectra_notification.ntf_task.id IS '通知任务主键';
COMMENT ON COLUMN spectra_notification.ntf_task.request_id IS '所属通知请求主键';
COMMENT ON COLUMN spectra_notification.ntf_task.tenant_id IS '租户主键';
COMMENT ON COLUMN spectra_notification.ntf_task.recipient_user_id IS '站内收件人用户主键，外部地址发送时可为空';
COMMENT ON COLUMN spectra_notification.ntf_task.recipient_address IS '短信手机号或邮件地址，按最小必要原则保存';
COMMENT ON COLUMN spectra_notification.ntf_task.channel IS '发送渠道：INBOX/SMS/EMAIL';
COMMENT ON COLUMN spectra_notification.ntf_task.title IS '已渲染通知标题';
COMMENT ON COLUMN spectra_notification.ntf_task.content IS '已渲染通知正文';
COMMENT ON COLUMN spectra_notification.ntf_task.scheduled_at IS '计划发送时间';
COMMENT ON COLUMN spectra_notification.ntf_task.status IS '任务状态：PENDING/PROCESSING/SENT/FAILED/CANCELLED';
COMMENT ON COLUMN spectra_notification.ntf_task.retry_count IS '已重试次数';
COMMENT ON COLUMN spectra_notification.ntf_task.last_error IS '最近一次失败原因摘要，不保存凭证';
COMMENT ON COLUMN spectra_notification.ntf_task.created_at IS '创建时间';
COMMENT ON COLUMN spectra_notification.ntf_task.updated_at IS '更新时间';

CREATE TABLE IF NOT EXISTS spectra_notification.ntf_delivery (
    id UUID PRIMARY KEY,
    task_id UUID NOT NULL REFERENCES spectra_notification.ntf_task(id),
    provider_code VARCHAR(100) NOT NULL,
    provider_message_id VARCHAR(200) NULL,
    status VARCHAR(20) NOT NULL,
    response_summary VARCHAR(1000) NULL,
    sent_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_ntf_delivery_status CHECK (status IN ('ACCEPTED', 'SENT', 'FAILED'))
);
COMMENT ON TABLE spectra_notification.ntf_delivery IS '通知投递记录表：记录每个任务在具体供应商上的结果';
COMMENT ON COLUMN spectra_notification.ntf_delivery.id IS '投递记录主键';
COMMENT ON COLUMN spectra_notification.ntf_delivery.task_id IS '通知任务主键';
COMMENT ON COLUMN spectra_notification.ntf_delivery.provider_code IS '供应商编码';
COMMENT ON COLUMN spectra_notification.ntf_delivery.provider_message_id IS '供应商返回的消息标识';
COMMENT ON COLUMN spectra_notification.ntf_delivery.status IS '投递状态：ACCEPTED/SENT/FAILED';
COMMENT ON COLUMN spectra_notification.ntf_delivery.response_summary IS '供应商响应摘要，不保存完整敏感响应';
COMMENT ON COLUMN spectra_notification.ntf_delivery.sent_at IS '供应商确认发送时间';
COMMENT ON COLUMN spectra_notification.ntf_delivery.created_at IS '记录创建时间';

CREATE TABLE IF NOT EXISTS spectra_notification.ntf_inbox (
    id UUID PRIMARY KEY,
    tenant_id UUID NOT NULL,
    recipient_user_id UUID NOT NULL,
    request_id UUID NOT NULL REFERENCES spectra_notification.ntf_request(id),
    title VARCHAR(500) NOT NULL,
    content TEXT NOT NULL,
    read_at TIMESTAMPTZ NULL,
    archived_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE spectra_notification.ntf_inbox IS '站内信收件箱：仅允许收件人查询和变更已读/归档状态';
COMMENT ON COLUMN spectra_notification.ntf_inbox.id IS '站内信主键';
COMMENT ON COLUMN spectra_notification.ntf_inbox.tenant_id IS '租户主键';
COMMENT ON COLUMN spectra_notification.ntf_inbox.recipient_user_id IS '收件人用户主键';
COMMENT ON COLUMN spectra_notification.ntf_inbox.request_id IS '来源通知请求主键';
COMMENT ON COLUMN spectra_notification.ntf_inbox.title IS '站内信标题';
COMMENT ON COLUMN spectra_notification.ntf_inbox.content IS '站内信正文';
COMMENT ON COLUMN spectra_notification.ntf_inbox.read_at IS '阅读时间，NULL表示未读';
COMMENT ON COLUMN spectra_notification.ntf_inbox.archived_at IS '归档时间，NULL表示未归档';
COMMENT ON COLUMN spectra_notification.ntf_inbox.created_at IS '入箱时间';

CREATE INDEX IF NOT EXISTS idx_ntf_task_pending ON spectra_notification.ntf_task (status, scheduled_at);
CREATE INDEX IF NOT EXISTS idx_ntf_inbox_recipient ON spectra_notification.ntf_inbox (tenant_id, recipient_user_id, created_at DESC);

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
    CONSTRAINT ck_ntf_user_preference_channel CHECK (channel IN ('INBOX', 'SMS', 'EMAIL'))
);
COMMENT ON TABLE spectra_notification.ntf_user_preference IS '用户通知偏好表：按用途和渠道保存可选通知设置，安全用途由策略强制覆盖';
COMMENT ON COLUMN spectra_notification.ntf_user_preference.id IS '偏好记录主键';
COMMENT ON COLUMN spectra_notification.ntf_user_preference.tenant_id IS '租户主键';
COMMENT ON COLUMN spectra_notification.ntf_user_preference.user_id IS '用户主键';
COMMENT ON COLUMN spectra_notification.ntf_user_preference.purpose IS '通知用途编码';
COMMENT ON COLUMN spectra_notification.ntf_user_preference.channel IS '通知渠道：INBOX/SMS/EMAIL';
COMMENT ON COLUMN spectra_notification.ntf_user_preference.enabled IS '是否启用该用途和渠道';
COMMENT ON COLUMN spectra_notification.ntf_user_preference.do_not_disturb IS '是否在免打扰时段抑制可选通知';
COMMENT ON COLUMN spectra_notification.ntf_user_preference.created_at IS '创建时间';
COMMENT ON COLUMN spectra_notification.ntf_user_preference.updated_at IS '更新时间';
CREATE INDEX IF NOT EXISTS idx_ntf_user_preference_user ON spectra_notification.ntf_user_preference (tenant_id, user_id);
