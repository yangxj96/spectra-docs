-- ============================================
-- spectra_oa schema 建表语句
-- 既有 OA 基础表 11 张 + 通用 OA P0 表 10 张
-- ============================================

CREATE SCHEMA IF NOT EXISTS spectra_oa;

-- OA 资产
CREATE TABLE spectra_oa.oa_asset (
    id            UUID PRIMARY KEY,
    department_id UUID,
    created_by    UUID,
    created_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by    UUID,
    updated_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted       TIMESTAMP(6) WITH TIME ZONE,
    version       BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_oa.oa_asset IS '资产表';
COMMENT ON COLUMN spectra_oa.oa_asset.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_asset.department_id IS '所属部门ID';
COMMENT ON COLUMN spectra_oa.oa_asset.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_asset.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_asset.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_asset.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_asset.deleted IS '是否删除';
COMMENT ON COLUMN spectra_oa.oa_asset.version IS '乐观锁';

-- OA 日历
CREATE TABLE spectra_oa.oa_calendar (
    id            UUID PRIMARY KEY,
    department_id UUID,
    created_by    UUID,
    created_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by    UUID,
    updated_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted       TIMESTAMP(6) WITH TIME ZONE,
    version       BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_oa.oa_calendar IS '日历表';
COMMENT ON COLUMN spectra_oa.oa_calendar.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_calendar.department_id IS '所属部门ID';
COMMENT ON COLUMN spectra_oa.oa_calendar.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_calendar.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_calendar.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_calendar.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_calendar.deleted IS '是否删除';
COMMENT ON COLUMN spectra_oa.oa_calendar.version IS '乐观锁';

-- OA 合同
CREATE TABLE spectra_oa.oa_contract (
    id                   UUID PRIMARY KEY,
    contract_no          VARCHAR(64) NOT NULL DEFAULT '',
    title                VARCHAR(255) NOT NULL DEFAULT '',
    contract_type        VARCHAR(64) NOT NULL DEFAULT 'OTHER',
    counterparty_name    VARCHAR(255) NOT NULL DEFAULT '',
    counterparty_contact VARCHAR(128),
    owner_id             UUID,
    amount               NUMERIC(18, 2) NOT NULL DEFAULT 0,
    currency             VARCHAR(16) NOT NULL DEFAULT 'CNY',
    start_date           TIMESTAMP(6) WITH TIME ZONE,
    end_date             TIMESTAMP(6) WITH TIME ZONE,
    status               VARCHAR(32) NOT NULL DEFAULT 'DRAFT',
    signing_status       VARCHAR(32) NOT NULL DEFAULT 'UNSIGNED',
    signed_at            TIMESTAMP(6) WITH TIME ZONE,
    visibility           VARCHAR(32) NOT NULL DEFAULT 'DEPARTMENT',
    summary              TEXT,
    department_id        UUID,
    created_by           UUID,
    created_at           TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by           UUID,
    updated_at           TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted              TIMESTAMP(6) WITH TIME ZONE,
    version              BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_oa.oa_contract IS '合同表';
COMMENT ON COLUMN spectra_oa.oa_contract.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_contract.contract_no IS '合同编号';
COMMENT ON COLUMN spectra_oa.oa_contract.title IS '合同标题';
COMMENT ON COLUMN spectra_oa.oa_contract.contract_type IS '合同类型';
COMMENT ON COLUMN spectra_oa.oa_contract.counterparty_name IS '相对方名称';
COMMENT ON COLUMN spectra_oa.oa_contract.counterparty_contact IS '相对方联系人';
COMMENT ON COLUMN spectra_oa.oa_contract.owner_id IS '合同负责人';
COMMENT ON COLUMN spectra_oa.oa_contract.amount IS '合同金额';
COMMENT ON COLUMN spectra_oa.oa_contract.currency IS '币种';
COMMENT ON COLUMN spectra_oa.oa_contract.start_date IS '生效日期';
COMMENT ON COLUMN spectra_oa.oa_contract.end_date IS '到期日期';
COMMENT ON COLUMN spectra_oa.oa_contract.status IS '合同状态（DRAFT/ACTIVE/EXPIRED/TERMINATED/ARCHIVED）';
COMMENT ON COLUMN spectra_oa.oa_contract.signing_status IS '签署状态（UNSIGNED/SIGNED）';
COMMENT ON COLUMN spectra_oa.oa_contract.signed_at IS '签署时间';
COMMENT ON COLUMN spectra_oa.oa_contract.visibility IS '可见范围（PUBLIC/DEPARTMENT/PRIVATE）';
COMMENT ON COLUMN spectra_oa.oa_contract.summary IS '合同摘要';
COMMENT ON COLUMN spectra_oa.oa_contract.department_id IS '所属部门ID';
COMMENT ON COLUMN spectra_oa.oa_contract.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_contract.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_contract.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_contract.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_contract.deleted IS '是否删除';
COMMENT ON COLUMN spectra_oa.oa_contract.version IS '乐观锁';

CREATE TABLE spectra_oa.oa_contract_version (
    id            UUID PRIMARY KEY,
    contract_id   UUID NOT NULL,
    version_no    INTEGER NOT NULL,
    file_id       UUID NOT NULL,
    file_name     VARCHAR(255),
    file_size     BIGINT,
    content_type  VARCHAR(128),
    version_note  VARCHAR(500),
    is_current    BOOLEAN NOT NULL DEFAULT FALSE,
    created_by    UUID,
    created_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by    UUID,
    updated_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted       TIMESTAMP(6) WITH TIME ZONE,
    version       BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_oa.oa_contract_version IS '合同文件版本表';

CREATE TABLE spectra_oa.oa_contract_milestone (
    id                UUID PRIMARY KEY,
    contract_id       UUID NOT NULL,
    name              VARCHAR(255) NOT NULL,
    milestone_type    VARCHAR(64) NOT NULL DEFAULT 'OTHER',
    due_date          TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    status            VARCHAR(32) NOT NULL DEFAULT 'PENDING',
    assignee_id       UUID,
    completed_at      TIMESTAMP(6) WITH TIME ZONE,
    reminder_sent_at  TIMESTAMP(6) WITH TIME ZONE,
    remark            VARCHAR(1000),
    created_by        UUID,
    created_at        TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by        UUID,
    updated_at        TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted           TIMESTAMP(6) WITH TIME ZONE,
    version           BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_oa.oa_contract_milestone IS '合同履约节点表';

CREATE UNIQUE INDEX uk_oa_contract_no ON spectra_oa.oa_contract (NULLIF(contract_no, ''))
    WHERE deleted IS NULL;
CREATE UNIQUE INDEX uk_oa_contract_version_no ON spectra_oa.oa_contract_version (contract_id, version_no)
    WHERE deleted IS NULL;
CREATE UNIQUE INDEX uk_oa_contract_current_version ON spectra_oa.oa_contract_version (contract_id)
    WHERE is_current = TRUE AND deleted IS NULL;
CREATE INDEX idx_oa_contract_status ON spectra_oa.oa_contract (status, end_date);
CREATE INDEX idx_oa_contract_counterparty ON spectra_oa.oa_contract (counterparty_name);
CREATE INDEX idx_oa_contract_version_contract ON spectra_oa.oa_contract_version (contract_id, version_no DESC);
CREATE INDEX idx_oa_contract_milestone_due ON spectra_oa.oa_contract_milestone (due_date, status);

-- OA 文档
CREATE TABLE spectra_oa.oa_document (
    id            UUID PRIMARY KEY,
    folder_id     UUID,
    title         VARCHAR(255) NOT NULL DEFAULT '',
    summary       TEXT,
    status        VARCHAR(32) NOT NULL DEFAULT 'DRAFT',
    visibility    VARCHAR(32) NOT NULL DEFAULT 'DEPARTMENT',
    owner_id      UUID,
    published_at  TIMESTAMP(6) WITH TIME ZONE,
    department_id UUID,
    created_by    UUID,
    created_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by    UUID,
    updated_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted       TIMESTAMP(6) WITH TIME ZONE,
    version       BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_oa.oa_document IS '文档表';
COMMENT ON COLUMN spectra_oa.oa_document.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_document.folder_id IS '所属目录ID';
COMMENT ON COLUMN spectra_oa.oa_document.title IS '文档标题';
COMMENT ON COLUMN spectra_oa.oa_document.summary IS '文档摘要';
COMMENT ON COLUMN spectra_oa.oa_document.status IS '文档状态（DRAFT/PUBLISHED/ARCHIVED）';
COMMENT ON COLUMN spectra_oa.oa_document.visibility IS '可见范围（PUBLIC/DEPARTMENT/PRIVATE）';
COMMENT ON COLUMN spectra_oa.oa_document.owner_id IS '文档所有者';
COMMENT ON COLUMN spectra_oa.oa_document.published_at IS '发布时间';
COMMENT ON COLUMN spectra_oa.oa_document.department_id IS '所属部门ID';
COMMENT ON COLUMN spectra_oa.oa_document.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_document.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_document.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_document.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_document.deleted IS '是否删除';
COMMENT ON COLUMN spectra_oa.oa_document.version IS '乐观锁';

-- OA 会议
CREATE TABLE spectra_oa.oa_meeting (
    id                  UUID PRIMARY KEY,
    title               VARCHAR(255) NOT NULL,
    initiator_id        UUID NOT NULL,
    start_time          TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    end_time            TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    location            VARCHAR(255),
    content             TEXT,
    status              VARCHAR(32) NOT NULL DEFAULT 'draft',
    process_instance_id VARCHAR(64),
    approval_status     VARCHAR(32) NOT NULL DEFAULT 'draft',
    department_id       UUID,
    created_by          UUID,
    created_at          TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by          UUID,
    updated_at          TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted             TIMESTAMP(6) WITH TIME ZONE,
    version             BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_oa.oa_meeting IS '会议表';
COMMENT ON COLUMN spectra_oa.oa_meeting.title IS '会议标题';
COMMENT ON COLUMN spectra_oa.oa_meeting.initiator_id IS '发起人ID';
COMMENT ON COLUMN spectra_oa.oa_meeting.start_time IS '开始时间';
COMMENT ON COLUMN spectra_oa.oa_meeting.end_time IS '结束时间';
COMMENT ON COLUMN spectra_oa.oa_meeting.location IS '会议地点';
COMMENT ON COLUMN spectra_oa.oa_meeting.content IS '会议内容';
COMMENT ON COLUMN spectra_oa.oa_meeting.status IS '状态 draft/cancelled';
COMMENT ON COLUMN spectra_oa.oa_meeting.process_instance_id IS '流程实例ID';
COMMENT ON COLUMN spectra_oa.oa_meeting.approval_status IS '审批状态 draft/cancelled';

-- OA 参会人员
CREATE TABLE spectra_oa.oa_meeting_participant (
    id            UUID PRIMARY KEY,
    meeting_id    UUID NOT NULL,
    user_id       UUID NOT NULL,
    role          VARCHAR(32) DEFAULT 'attendee',
    status        VARCHAR(32) DEFAULT 'pending',
    check_in_at   TIMESTAMP(6) WITH TIME ZONE,
    department_id UUID,
    created_by    UUID,
    created_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by    UUID,
    updated_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted       TIMESTAMP(6) WITH TIME ZONE,
    version       BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_oa.oa_meeting_participant IS '参会人员表';
COMMENT ON COLUMN spectra_oa.oa_meeting_participant.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_meeting_participant.meeting_id IS '会议ID';
COMMENT ON COLUMN spectra_oa.oa_meeting_participant.user_id IS '用户ID';
COMMENT ON COLUMN spectra_oa.oa_meeting_participant.role IS '角色 attendee/organizer';
COMMENT ON COLUMN spectra_oa.oa_meeting_participant.status IS '状态 pending/accepted/declined';
COMMENT ON COLUMN spectra_oa.oa_meeting_participant.check_in_at IS '签到时间';
COMMENT ON COLUMN spectra_oa.oa_meeting_participant.department_id IS '所属部门ID';
COMMENT ON COLUMN spectra_oa.oa_meeting_participant.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_meeting_participant.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_meeting_participant.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_meeting_participant.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_meeting_participant.deleted IS '是否删除';
COMMENT ON COLUMN spectra_oa.oa_meeting_participant.version IS '乐观锁';

-- OA 会议纪要
CREATE TABLE spectra_oa.oa_meeting_record (
    id            UUID PRIMARY KEY,
    meeting_id    UUID NOT NULL,
    content       TEXT,
    department_id UUID,
    created_by    UUID,
    created_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by    UUID,
    updated_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted       TIMESTAMP(6) WITH TIME ZONE,
    version       BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_oa.oa_meeting_record IS '会议纪要表';
COMMENT ON COLUMN spectra_oa.oa_meeting_record.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_meeting_record.meeting_id IS '会议ID';
COMMENT ON COLUMN spectra_oa.oa_meeting_record.content IS '纪要内容';
COMMENT ON COLUMN spectra_oa.oa_meeting_record.department_id IS '所属部门ID';
COMMENT ON COLUMN spectra_oa.oa_meeting_record.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_meeting_record.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_meeting_record.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_meeting_record.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_meeting_record.deleted IS '是否删除';
COMMENT ON COLUMN spectra_oa.oa_meeting_record.version IS '乐观锁';

-- OA 公告通知
CREATE TABLE spectra_oa.oa_notice (
    id            UUID PRIMARY KEY,
    department_id UUID,
    created_by    UUID,
    created_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by    UUID,
    updated_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted       TIMESTAMP(6) WITH TIME ZONE,
    version       BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_oa.oa_notice IS '公告通知表';
COMMENT ON COLUMN spectra_oa.oa_notice.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_notice.department_id IS '所属部门ID';
COMMENT ON COLUMN spectra_oa.oa_notice.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_notice.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_notice.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_notice.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_notice.deleted IS '是否删除';
COMMENT ON COLUMN spectra_oa.oa_notice.version IS '乐观锁';

-- ============================================================
-- 通用 OA P0：统一申请内核
-- ============================================================

CREATE TABLE IF NOT EXISTS spectra_oa.oa_application_type (
    id                     UUID PRIMARY KEY,
    code                   VARCHAR(64) NOT NULL UNIQUE,
    name                   VARCHAR(128) NOT NULL,
    form_definition_id     UUID,
    process_definition_key VARCHAR(128),
    enabled                BOOLEAN NOT NULL DEFAULT TRUE,
    sort_order             INTEGER NOT NULL DEFAULT 0,
    description            VARCHAR(500),
    created_by             UUID,
    created_at             TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by             UUID,
    updated_at             TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted                TIMESTAMP(6) WITH TIME ZONE,
    version                BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_oa.oa_application_type IS 'OA 通用申请类型';

CREATE TABLE IF NOT EXISTS spectra_oa.oa_application (
    id                   UUID PRIMARY KEY,
    application_no       VARCHAR(64) NOT NULL UNIQUE,
    type_code            VARCHAR(64) NOT NULL,
    biz_id               UUID,
    applicant_id         UUID NOT NULL,
    department_id        UUID,
    title                VARCHAR(255) NOT NULL,
    status               VARCHAR(32) NOT NULL DEFAULT 'DRAFT',
    process_instance_id  VARCHAR(64),
    submitted_at         TIMESTAMP(6) WITH TIME ZONE,
    completed_at         TIMESTAMP(6) WITH TIME ZONE,
    reject_reason        VARCHAR(1000),
    created_by            UUID,
    created_at           TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by            UUID,
    updated_at            TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted              TIMESTAMP(6) WITH TIME ZONE,
    version              BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_oa.oa_application IS 'OA 通用申请主表';
COMMENT ON COLUMN spectra_oa.oa_application.status IS 'DRAFT/IN_REVIEW/APPROVED/REJECTED/WITHDRAWN/CANCELLED';
COMMENT ON COLUMN spectra_oa.oa_application.biz_id IS '类型业务明细ID';

CREATE TABLE IF NOT EXISTS spectra_oa.oa_application_attachment (
    id             UUID PRIMARY KEY,
    application_id UUID NOT NULL,
    file_id        UUID NOT NULL,
    file_name      VARCHAR(255),
    created_by     UUID,
    created_at     TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by     UUID,
    updated_at     TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted        TIMESTAMP(6) WITH TIME ZONE,
    version        BIGINT DEFAULT 0,
    CONSTRAINT uk_oa_application_attachment UNIQUE (application_id, file_id)
);

CREATE TABLE IF NOT EXISTS spectra_oa.oa_application_cc (
    id             UUID PRIMARY KEY,
    application_id UUID NOT NULL,
    user_id        UUID NOT NULL,
    created_by     UUID,
    created_at     TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by     UUID,
    updated_at     TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted        TIMESTAMP(6) WITH TIME ZONE,
    version        BIGINT DEFAULT 0,
    CONSTRAINT uk_oa_application_cc UNIQUE (application_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_oa_application_applicant_status
    ON spectra_oa.oa_application (applicant_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_oa_application_process_instance
    ON spectra_oa.oa_application (process_instance_id);

-- ============================================================
-- 通用 OA P0：请假、固定班次与考勤回写
-- ============================================================

CREATE TABLE IF NOT EXISTS spectra_oa.oa_leave_type (
    id            UUID PRIMARY KEY,
    code          VARCHAR(64) NOT NULL UNIQUE,
    name          VARCHAR(128) NOT NULL,
    unit          VARCHAR(16) NOT NULL DEFAULT 'HOUR',
    default_hours NUMERIC(12, 2),
    enabled       BOOLEAN NOT NULL DEFAULT TRUE,
    created_by    UUID,
    created_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by    UUID,
    updated_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted       TIMESTAMP(6) WITH TIME ZONE,
    version       BIGINT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS spectra_oa.oa_leave_application (
    id             UUID PRIMARY KEY,
    application_id UUID NOT NULL UNIQUE,
    department_id  UUID,
    leave_type_code VARCHAR(64) NOT NULL,
    start_time     TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    end_time       TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    duration_hours NUMERIC(12, 2) NOT NULL,
    reason         VARCHAR(2000) NOT NULL,
    contact_address VARCHAR(500),
    created_by     UUID,
    created_at     TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by     UUID,
    updated_at     TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted        TIMESTAMP(6) WITH TIME ZONE,
    version        BIGINT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS spectra_oa.oa_leave_balance (
    id             UUID PRIMARY KEY,
    user_id        UUID NOT NULL,
    department_id  UUID,
    leave_type_code VARCHAR(64) NOT NULL,
    year           INTEGER NOT NULL,
    total_hours    NUMERIC(12, 2) NOT NULL DEFAULT 0,
    used_hours     NUMERIC(12, 2) NOT NULL DEFAULT 0,
    reserved_hours NUMERIC(12, 2) NOT NULL DEFAULT 0,
    created_by     UUID,
    created_at     TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by     UUID,
    updated_at     TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted        TIMESTAMP(6) WITH TIME ZONE,
    version        BIGINT DEFAULT 0,
    CONSTRAINT uk_oa_leave_balance UNIQUE (user_id, leave_type_code, year)
);

CREATE TABLE IF NOT EXISTS spectra_oa.oa_work_shift (
    id            UUID PRIMARY KEY,
    name          VARCHAR(128) NOT NULL,
    work_start    TIME NOT NULL DEFAULT '09:00',
    lunch_start   TIME NOT NULL DEFAULT '12:00',
    lunch_end     TIME NOT NULL DEFAULT '13:00',
    work_end      TIME NOT NULL DEFAULT '18:00',
    enabled       BOOLEAN NOT NULL DEFAULT TRUE,
    created_by    UUID,
    created_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by    UUID,
    updated_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted       TIMESTAMP(6) WITH TIME ZONE,
    version       BIGINT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS spectra_oa.oa_work_calendar (
    id            UUID PRIMARY KEY,
    calendar_date DATE NOT NULL UNIQUE,
    is_workday    BOOLEAN NOT NULL DEFAULT TRUE,
    shift_id      UUID,
    remark        VARCHAR(255),
    created_by    UUID,
    created_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by    UUID,
    updated_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted       TIMESTAMP(6) WITH TIME ZONE,
    version       BIGINT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS spectra_oa.oa_attendance_record (
    id              UUID PRIMARY KEY,
    application_id  UUID NOT NULL,
    user_id         UUID NOT NULL,
    attendance_date TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    status          VARCHAR(32) NOT NULL,
    source          VARCHAR(32) NOT NULL,
    department_id   UUID,
    created_by      UUID,
    created_at      TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by      UUID,
    updated_at      TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted         TIMESTAMP(6) WITH TIME ZONE,
    version         BIGINT DEFAULT 0,
    CONSTRAINT uk_oa_attendance_record UNIQUE (application_id, attendance_date)
);

CREATE INDEX IF NOT EXISTS idx_oa_leave_application_time
    ON spectra_oa.oa_leave_application (start_time, end_time);
CREATE INDEX IF NOT EXISTS idx_oa_attendance_record_user_date
    ON spectra_oa.oa_attendance_record (user_id, attendance_date);

-- P0 最小内置配置：请假类型与流程定义 KEY 对齐，流程图由 Workflow 模块部署。
INSERT INTO spectra_oa.oa_application_type
    (id, code, name, process_definition_key, enabled, sort_order, description,
     created_at, updated_at, version)
VALUES
    ('00000000-0000-0000-0000-000000000001', 'leave', '请假申请', 'oa_leave_approval', TRUE, 10,
     '通用 OA 请假审批', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 0)
ON CONFLICT (code) DO NOTHING;

-- P1 阶段 3：资产管理 MVP
ALTER TABLE spectra_oa.oa_asset
    ADD COLUMN IF NOT EXISTS category_id UUID,
    ADD COLUMN IF NOT EXISTS asset_no VARCHAR(128),
    ADD COLUMN IF NOT EXISTS name VARCHAR(256),
    ADD COLUMN IF NOT EXISTS specification VARCHAR(1000),
    ADD COLUMN IF NOT EXISTS serial_no VARCHAR(128),
    ADD COLUMN IF NOT EXISTS asset_type VARCHAR(32) NOT NULL DEFAULT 'FIXED',
    ADD COLUMN IF NOT EXISTS status VARCHAR(32) NOT NULL DEFAULT 'DRAFT',
    ADD COLUMN IF NOT EXISTS quantity NUMERIC(14, 3) NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS acquisition_date TIMESTAMP(6) WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS acquisition_amount NUMERIC(14, 2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS currency VARCHAR(3) NOT NULL DEFAULT 'CNY',
    ADD COLUMN IF NOT EXISTS supplier VARCHAR(256),
    ADD COLUMN IF NOT EXISTS location VARCHAR(256),
    ADD COLUMN IF NOT EXISTS custodian_id UUID,
    ADD COLUMN IF NOT EXISTS warranty_until TIMESTAMP(6) WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS source_purchase_id UUID,
    ADD COLUMN IF NOT EXISTS source_receipt_id UUID,
    ADD COLUMN IF NOT EXISTS source_purchase_item_id UUID,
    ADD COLUMN IF NOT EXISTS remark VARCHAR(1000);

CREATE TABLE IF NOT EXISTS spectra_oa.oa_asset_category (
    id UUID PRIMARY KEY, pid UUID, code VARCHAR(64) NOT NULL, name VARCHAR(128) NOT NULL,
    asset_type VARCHAR(32) NOT NULL DEFAULT 'FIXED', sort INTEGER NOT NULL DEFAULT 0,
    enabled BOOLEAN NOT NULL DEFAULT TRUE, description VARCHAR(500),
    created_by UUID, created_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by UUID, updated_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted TIMESTAMP(6) WITH TIME ZONE, version BIGINT DEFAULT 0
);
CREATE TABLE IF NOT EXISTS spectra_oa.oa_asset_operation (
    id UUID PRIMARY KEY, asset_id UUID NOT NULL, operation_type VARCHAR(32) NOT NULL,
    from_department_id UUID, to_department_id UUID, from_user_id UUID, to_user_id UUID,
    from_location VARCHAR(256), to_location VARCHAR(256), operation_date TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    reason VARCHAR(1000), maintenance_content VARCHAR(2000), maintenance_cost NUMERIC(14, 2),
    status VARCHAR(32) NOT NULL DEFAULT 'COMPLETE', created_by UUID,
    created_at TIMESTAMP(6) WITH TIME ZONE NOT NULL, updated_by UUID,
    updated_at TIMESTAMP(6) WITH TIME ZONE NOT NULL, deleted TIMESTAMP(6) WITH TIME ZONE,
    version BIGINT DEFAULT 0
);
CREATE UNIQUE INDEX IF NOT EXISTS uk_oa_asset_asset_no ON spectra_oa.oa_asset (asset_no)
    WHERE deleted IS NULL AND asset_no IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uk_oa_asset_category_code ON spectra_oa.oa_asset_category (code)
    WHERE deleted IS NULL;
CREATE INDEX IF NOT EXISTS idx_oa_asset_status_department
    ON spectra_oa.oa_asset (status, department_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_oa_asset_source_receipt_item
    ON spectra_oa.oa_asset (source_receipt_id, source_purchase_item_id);
CREATE INDEX IF NOT EXISTS idx_oa_asset_operation_asset_date
    ON spectra_oa.oa_asset_operation (asset_id, operation_date DESC, created_at DESC);
INSERT INTO spectra_oa.oa_asset_category
    (id, code, name, asset_type, sort, enabled, created_at, updated_at, version)
VALUES
    ('00000000-0000-0000-0000-000000000101', 'OFFICE_EQUIPMENT', '办公设备', 'FIXED', 10, TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 0),
    ('00000000-0000-0000-0000-000000000102', 'IT_EQUIPMENT', '信息设备', 'FIXED', 20, TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 0),
    ('00000000-0000-0000-0000-000000000103', 'FURNITURE', '办公家具', 'FIXED', 30, TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 0),
    ('00000000-0000-0000-0000-000000000104', 'VEHICLE', '车辆', 'FIXED', 40, TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 0)
ON CONFLICT DO NOTHING;

-- P1 阶段 3：办公用品库存 MVP
CREATE TABLE IF NOT EXISTS spectra_oa.oa_supply_item (
    id UUID PRIMARY KEY, category VARCHAR(128), sku VARCHAR(128) NOT NULL,
    name VARCHAR(256) NOT NULL, specification VARCHAR(1000), unit VARCHAR(32) NOT NULL DEFAULT '件',
    current_stock NUMERIC(14, 3) NOT NULL DEFAULT 0, min_stock NUMERIC(14, 3) NOT NULL DEFAULT 0,
    status VARCHAR(32) NOT NULL DEFAULT 'ACTIVE', supplier VARCHAR(256), location VARCHAR(256),
    department_id UUID, remark VARCHAR(1000), created_by UUID,
    created_at TIMESTAMP(6) WITH TIME ZONE NOT NULL, updated_by UUID,
    updated_at TIMESTAMP(6) WITH TIME ZONE NOT NULL, deleted TIMESTAMP(6) WITH TIME ZONE,
    version BIGINT DEFAULT 0
);
CREATE TABLE IF NOT EXISTS spectra_oa.oa_supply_operation (
    id UUID PRIMARY KEY, supply_id UUID NOT NULL, operation_type VARCHAR(32) NOT NULL,
    quantity NUMERIC(14, 3) NOT NULL, before_stock NUMERIC(14, 3) NOT NULL,
    after_stock NUMERIC(14, 3) NOT NULL, department_id UUID, user_id UUID,
    location VARCHAR(256), operation_date TIMESTAMP(6) WITH TIME ZONE NOT NULL, reason VARCHAR(1000),
    source_purchase_id UUID, source_receipt_id UUID, source_purchase_item_id UUID,
    status VARCHAR(32) NOT NULL DEFAULT 'COMPLETE', created_by UUID,
    created_at TIMESTAMP(6) WITH TIME ZONE NOT NULL, updated_by UUID,
    updated_at TIMESTAMP(6) WITH TIME ZONE NOT NULL, deleted TIMESTAMP(6) WITH TIME ZONE,
    version BIGINT DEFAULT 0
);
CREATE UNIQUE INDEX IF NOT EXISTS uk_oa_supply_item_sku ON spectra_oa.oa_supply_item (sku)
    WHERE deleted IS NULL;
CREATE INDEX IF NOT EXISTS idx_oa_supply_item_stock
    ON spectra_oa.oa_supply_item (status, current_stock, min_stock, name);
CREATE INDEX IF NOT EXISTS idx_oa_supply_operation_supply_date
    ON spectra_oa.oa_supply_operation (supply_id, operation_date DESC, created_at DESC);

-- P1 阶段 3：采购申请、执行跟踪与分批收货。
CREATE TABLE IF NOT EXISTS spectra_oa.oa_purchase (
    id                  UUID PRIMARY KEY,
    application_id      UUID NOT NULL UNIQUE,
    department_id       UUID,
    purpose             VARCHAR(2000) NOT NULL,
    expected_date       TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    budget_amount       NUMERIC(14, 2) NOT NULL,
    currency            VARCHAR(3) NOT NULL DEFAULT 'CNY',
    suggested_supplier  VARCHAR(256),
    execution_status    VARCHAR(32) NOT NULL DEFAULT 'NOT_STARTED',
    purchaser_id        UUID,
    order_no            VARCHAR(128),
    ordered_at          TIMESTAMP(6) WITH TIME ZONE,
    completed_at        TIMESTAMP(6) WITH TIME ZONE,
    execution_remark    VARCHAR(1000),
    created_by          UUID,
    created_at          TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by          UUID,
    updated_at          TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted             TIMESTAMP(6) WITH TIME ZONE,
    version             BIGINT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS spectra_oa.oa_purchase_item (
    id                    UUID PRIMARY KEY,
    purchase_id           UUID NOT NULL,
    department_id         UUID,
    item_type             VARCHAR(32) NOT NULL,
    item_name             VARCHAR(256) NOT NULL,
    specification         VARCHAR(1000),
    quantity              NUMERIC(14, 3) NOT NULL,
    estimated_unit_price  NUMERIC(14, 2) NOT NULL DEFAULT 0,
    estimated_amount      NUMERIC(14, 2) NOT NULL DEFAULT 0,
    purpose               VARCHAR(500),
    received_quantity     NUMERIC(14, 3) NOT NULL DEFAULT 0,
    created_by            UUID,
    created_at            TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by            UUID,
    updated_at            TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted               TIMESTAMP(6) WITH TIME ZONE,
    version               BIGINT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS spectra_oa.oa_purchase_receipt (
    id              UUID PRIMARY KEY,
    purchase_id     UUID NOT NULL,
    receipt_no      VARCHAR(128) NOT NULL,
    received_date   TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    receiver_id     UUID,
    status          VARCHAR(32) NOT NULL DEFAULT 'PARTIAL',
    remark          VARCHAR(1000),
    created_by      UUID,
    created_at      TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by      UUID,
    updated_at      TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted         TIMESTAMP(6) WITH TIME ZONE,
    version         BIGINT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS spectra_oa.oa_purchase_receipt_item (
    id                UUID PRIMARY KEY,
    receipt_id        UUID NOT NULL,
    purchase_item_id  UUID NOT NULL,
    quantity          NUMERIC(14, 3) NOT NULL,
    accepted          BOOLEAN NOT NULL DEFAULT TRUE,
    difference_reason VARCHAR(1000),
    created_by        UUID,
    created_at        TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by        UUID,
    updated_at        TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted           TIMESTAMP(6) WITH TIME ZONE,
    version           BIGINT DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_oa_purchase_department_status
    ON spectra_oa.oa_purchase (department_id, execution_status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_oa_purchase_item_purchase
    ON spectra_oa.oa_purchase_item (purchase_id, created_at);
CREATE INDEX IF NOT EXISTS idx_oa_purchase_receipt_purchase
    ON spectra_oa.oa_purchase_receipt (purchase_id, received_date DESC);
CREATE UNIQUE INDEX IF NOT EXISTS uk_oa_purchase_receipt_no
    ON spectra_oa.oa_purchase_receipt (receipt_no)
    WHERE deleted IS NULL;
CREATE INDEX IF NOT EXISTS idx_oa_purchase_receipt_item_receipt
    ON spectra_oa.oa_purchase_receipt_item (receipt_id);

INSERT INTO spectra_oa.oa_application_type
    (id, code, name, process_definition_key, enabled, sort_order, description,
     created_at, updated_at, version)
VALUES
    ('00000000-0000-0000-0000-000000000003', 'purchase', '采购申请', 'oa_purchase_approval', TRUE, 30,
     'P1 采购申请审批', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 0)
ON CONFLICT (code) DO NOTHING;

-- P0-P1 协同办公 MVP：公告、日程、会议的增量结构。
ALTER TABLE spectra_oa.oa_notice
    ADD COLUMN IF NOT EXISTS title VARCHAR(255),
    ADD COLUMN IF NOT EXISTS summary VARCHAR(1000),
    ADD COLUMN IF NOT EXISTS content TEXT,
    ADD COLUMN IF NOT EXISTS status VARCHAR(32) NOT NULL DEFAULT 'DRAFT',
    ADD COLUMN IF NOT EXISTS target_type VARCHAR(32) NOT NULL DEFAULT 'ALL',
    ADD COLUMN IF NOT EXISTS target_department_id UUID,
    ADD COLUMN IF NOT EXISTS publisher_id UUID,
    ADD COLUMN IF NOT EXISTS publish_at TIMESTAMP(6) WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS required_read BOOLEAN NOT NULL DEFAULT FALSE;

CREATE TABLE IF NOT EXISTS spectra_oa.oa_notice_reader (
    id         UUID PRIMARY KEY,
    notice_id  UUID NOT NULL,
    user_id    UUID NOT NULL,
    read_at    TIMESTAMP(6) WITH TIME ZONE,
    created_by UUID,
    created_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by UUID,
    updated_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted    TIMESTAMP(6) WITH TIME ZONE,
    version    BIGINT DEFAULT 0,
    CONSTRAINT uk_oa_notice_reader UNIQUE (notice_id, user_id)
);

ALTER TABLE spectra_oa.oa_calendar
    ADD COLUMN IF NOT EXISTS owner_id UUID,
    ADD COLUMN IF NOT EXISTS title VARCHAR(255),
    ADD COLUMN IF NOT EXISTS content TEXT,
    ADD COLUMN IF NOT EXISTS start_time TIMESTAMP(6) WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS end_time TIMESTAMP(6) WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS all_day BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS event_type VARCHAR(32) NOT NULL DEFAULT 'PERSONAL',
    ADD COLUMN IF NOT EXISTS visibility VARCHAR(32) NOT NULL DEFAULT 'PRIVATE',
    ADD COLUMN IF NOT EXISTS location VARCHAR(255),
    ADD COLUMN IF NOT EXISTS participant_ids TEXT,
    ADD COLUMN IF NOT EXISTS source_type VARCHAR(32),
    ADD COLUMN IF NOT EXISTS source_id UUID;

CREATE INDEX IF NOT EXISTS idx_oa_calendar_owner_time
    ON spectra_oa.oa_calendar (owner_id, start_time, end_time);

CREATE INDEX IF NOT EXISTS idx_oa_notice_publish_scope
    ON spectra_oa.oa_notice (status, target_type, target_department_id, publish_at);

CREATE UNIQUE INDEX IF NOT EXISTS uk_oa_meeting_participant_user
    ON spectra_oa.oa_meeting_participant (meeting_id, user_id)
    WHERE deleted IS NULL;

CREATE INDEX IF NOT EXISTS idx_oa_meeting_location_time
    ON spectra_oa.oa_meeting (location, start_time, end_time);

-- P1 阶段 3：费用报销 MVP，审批状态复用 oa_application，付款状态独立维护。
CREATE TABLE IF NOT EXISTS spectra_oa.oa_reimbursement (
    id              UUID PRIMARY KEY,
    application_id  UUID NOT NULL UNIQUE,
    department_id   UUID,
    purpose         VARCHAR(2000) NOT NULL,
    expense_start   TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    expense_end     TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    total_amount    NUMERIC(14, 2) NOT NULL,
    currency        VARCHAR(3) NOT NULL DEFAULT 'CNY',
    payee_name      VARCHAR(128) NOT NULL,
    payee_account   VARCHAR(256),
    payment_status  VARCHAR(32) NOT NULL DEFAULT 'PENDING',
    payment_at      TIMESTAMP(6) WITH TIME ZONE,
    payment_remark  VARCHAR(1000),
    created_by      UUID,
    created_at      TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by      UUID,
    updated_at      TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted         TIMESTAMP(6) WITH TIME ZONE,
    version         BIGINT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS spectra_oa.oa_reimbursement_item (
    id              UUID PRIMARY KEY,
    reimbursement_id UUID NOT NULL,
    department_id   UUID,
    expense_date    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    category        VARCHAR(64) NOT NULL,
    description     VARCHAR(500) NOT NULL,
    amount          NUMERIC(14, 2) NOT NULL,
    tax_amount      NUMERIC(14, 2) NOT NULL DEFAULT 0,
    invoice_no      VARCHAR(128),
    created_by      UUID,
    created_at      TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by      UUID,
    updated_at      TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted         TIMESTAMP(6) WITH TIME ZONE,
    version         BIGINT DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_oa_reimbursement_department_status
    ON spectra_oa.oa_reimbursement (department_id, payment_status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_oa_reimbursement_item_reimbursement
    ON spectra_oa.oa_reimbursement_item (reimbursement_id, expense_date);

INSERT INTO spectra_oa.oa_application_type
    (id, code, name, process_definition_key, enabled, sort_order, description,
     created_at, updated_at, version)
VALUES
    ('00000000-0000-0000-0000-000000000002', 'reimbursement', '费用报销', 'oa_reimbursement_approval', TRUE, 20,
     'P1 费用报销审批', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 0)
ON CONFLICT (code) DO NOTHING;

INSERT INTO spectra_oa.oa_leave_type
    (id, code, name, unit, default_hours, enabled, created_at, updated_at, version)
VALUES
    ('00000000-0000-0000-0000-000000000011', 'annual', '年假', 'HOUR', 80, TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 0),
    ('00000000-0000-0000-0000-000000000012', 'sick', '病假', 'HOUR', NULL, TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 0),
    ('00000000-0000-0000-0000-000000000013', 'personal', '事假', 'HOUR', NULL, TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 0)
ON CONFLICT (code) DO NOTHING;
