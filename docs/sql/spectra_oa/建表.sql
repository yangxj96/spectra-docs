-- ============================================
-- spectra_oa schema 建表语句
-- OA 业务、申请、资产、库存、采购、报销、文档和合同最终结构（33 张表）
-- 固定种子的审计元数据由当前 Flyway V1 基线统一为零 UUID 和 1996-10-15 00:00:00+08。
-- ============================================

CREATE SCHEMA IF NOT EXISTS spectra_oa;

-- OA 资产
CREATE TABLE spectra_oa.oa_asset (
    id                     UUID PRIMARY KEY,
    department_id          UUID,
    category_id            UUID,
    asset_no               VARCHAR(128),
    name                   VARCHAR(256),
    specification          VARCHAR(1000),
    serial_no              VARCHAR(128),
    asset_type             VARCHAR(32) NOT NULL DEFAULT 'FIXED',
    status                 VARCHAR(32) NOT NULL DEFAULT 'DRAFT',
    quantity               NUMERIC(14, 3) NOT NULL DEFAULT 1,
    acquisition_date       TIMESTAMP(6) WITH TIME ZONE,
    acquisition_amount     NUMERIC(14, 2) NOT NULL DEFAULT 0,
    currency               VARCHAR(3) NOT NULL DEFAULT 'CNY',
    supplier               VARCHAR(256),
    location               VARCHAR(256),
    custodian_id           UUID,
    warranty_until         TIMESTAMP(6) WITH TIME ZONE,
    source_purchase_id     UUID,
    source_receipt_id      UUID,
    source_purchase_item_id UUID,
    remark                 VARCHAR(1000),
    created_by             UUID,
    created_at             TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by             UUID,
    updated_at             TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted                TIMESTAMP(6) WITH TIME ZONE,
    version                BIGINT DEFAULT 0
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
    id               UUID PRIMARY KEY,
    owner_id         UUID,
    department_id    UUID,
    title            VARCHAR(255),
    content          TEXT,
    start_time       TIMESTAMP(6) WITH TIME ZONE,
    end_time         TIMESTAMP(6) WITH TIME ZONE,
    all_day          BOOLEAN NOT NULL DEFAULT FALSE,
    event_type       VARCHAR(32) NOT NULL DEFAULT 'PERSONAL',
    visibility       VARCHAR(32) NOT NULL DEFAULT 'PRIVATE',
    location         VARCHAR(255),
    participant_ids  TEXT,
    source_type      VARCHAR(32),
    source_id        UUID,
    created_by       UUID,
    created_at       TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by       UUID,
    updated_at       TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted          TIMESTAMP(6) WITH TIME ZONE,
    version          BIGINT DEFAULT 0
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

-- OA 文档目录
CREATE TABLE IF NOT EXISTS spectra_oa.oa_document_folder (
    id            UUID PRIMARY KEY,
    pid           UUID,
    name          VARCHAR(128) NOT NULL,
    department_id UUID,
    visibility    VARCHAR(32) NOT NULL DEFAULT 'DEPARTMENT',
    sort          INTEGER NOT NULL DEFAULT 0,
    created_by    UUID,
    created_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by    UUID,
    updated_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted       TIMESTAMP(6) WITH TIME ZONE,
    version       BIGINT DEFAULT 0
);

-- OA 文档版本
CREATE TABLE IF NOT EXISTS spectra_oa.oa_document_version (
    id            UUID PRIMARY KEY,
    document_id   UUID NOT NULL,
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

CREATE UNIQUE INDEX IF NOT EXISTS uk_oa_document_version_no
    ON spectra_oa.oa_document_version (document_id, version_no)
    WHERE deleted IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uk_oa_document_current_version
    ON spectra_oa.oa_document_version (document_id)
    WHERE is_current = TRUE AND deleted IS NULL;
CREATE INDEX IF NOT EXISTS idx_oa_document_folder ON spectra_oa.oa_document (folder_id);
CREATE INDEX IF NOT EXISTS idx_oa_document_status ON spectra_oa.oa_document (status, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_oa_document_version_document
    ON spectra_oa.oa_document_version (document_id, version_no DESC);

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
    id                    UUID PRIMARY KEY,
    title                 VARCHAR(255),
    summary               VARCHAR(1000),
    content               TEXT,
    status                VARCHAR(32) NOT NULL DEFAULT 'DRAFT',
    target_type           VARCHAR(32) NOT NULL DEFAULT 'ALL',
    target_department_id  UUID,
    publisher_id          UUID,
    publish_at            TIMESTAMP(6) WITH TIME ZONE,
    required_read         BOOLEAN NOT NULL DEFAULT FALSE,
    department_id         UUID,
    created_by            UUID,
    created_at            TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by            UUID,
    updated_at            TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted               TIMESTAMP(6) WITH TIME ZONE,
    version               BIGINT DEFAULT 0
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
     created_by, created_at, updated_by, updated_at, version)
VALUES
    ('00000000-0000-0000-0000-000000000001', 'leave', '请假申请', 'oa_leave_approval', TRUE, 10,
     '通用 OA 请假审批', '00000000-0000-0000-0000-000000000000',
     TIMESTAMPTZ '1996-10-15 00:00:00+08:00',
     '00000000-0000-0000-0000-000000000000',
     TIMESTAMPTZ '1996-10-15 00:00:00+08:00', 0)
ON CONFLICT (code) DO NOTHING;

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
    (id, code, name, asset_type, sort, enabled, created_by, created_at, updated_by, updated_at, version)
VALUES
    ('00000000-0000-0000-0000-000000000101', 'OFFICE_EQUIPMENT', '办公设备', 'FIXED', 10, TRUE,
     '00000000-0000-0000-0000-000000000000', TIMESTAMPTZ '1996-10-15 00:00:00+08:00',
     '00000000-0000-0000-0000-000000000000', TIMESTAMPTZ '1996-10-15 00:00:00+08:00', 0),
    ('00000000-0000-0000-0000-000000000102', 'IT_EQUIPMENT', '信息设备', 'FIXED', 20, TRUE,
     '00000000-0000-0000-0000-000000000000', TIMESTAMPTZ '1996-10-15 00:00:00+08:00',
     '00000000-0000-0000-0000-000000000000', TIMESTAMPTZ '1996-10-15 00:00:00+08:00', 0),
    ('00000000-0000-0000-0000-000000000103', 'FURNITURE', '办公家具', 'FIXED', 30, TRUE,
     '00000000-0000-0000-0000-000000000000', TIMESTAMPTZ '1996-10-15 00:00:00+08:00',
     '00000000-0000-0000-0000-000000000000', TIMESTAMPTZ '1996-10-15 00:00:00+08:00', 0),
    ('00000000-0000-0000-0000-000000000104', 'VEHICLE', '车辆', 'FIXED', 40, TRUE,
     '00000000-0000-0000-0000-000000000000', TIMESTAMPTZ '1996-10-15 00:00:00+08:00',
     '00000000-0000-0000-0000-000000000000', TIMESTAMPTZ '1996-10-15 00:00:00+08:00', 0)
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
     created_by, created_at, updated_by, updated_at, version)
VALUES
    ('00000000-0000-0000-0000-000000000003', 'purchase', '采购申请', 'oa_purchase_approval', TRUE, 30,
    'P1 采购申请审批', '00000000-0000-0000-0000-000000000000',
    TIMESTAMPTZ '1996-10-15 00:00:00+08:00',
    '00000000-0000-0000-0000-000000000000',
    TIMESTAMPTZ '1996-10-15 00:00:00+08:00', 0)
ON CONFLICT (code) DO NOTHING;

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
     created_by, created_at, updated_by, updated_at, version)
VALUES
    ('00000000-0000-0000-0000-000000000002', 'reimbursement', '费用报销', 'oa_reimbursement_approval', TRUE, 20,
     'P1 费用报销审批', '00000000-0000-0000-0000-000000000000',
     TIMESTAMPTZ '1996-10-15 00:00:00+08:00',
     '00000000-0000-0000-0000-000000000000',
     TIMESTAMPTZ '1996-10-15 00:00:00+08:00', 0)
ON CONFLICT (code) DO NOTHING;

INSERT INTO spectra_oa.oa_leave_type
    (id, code, name, unit, default_hours, enabled, created_by, created_at, updated_by, updated_at, version)
VALUES
    ('00000000-0000-0000-0000-000000000011', 'annual', '年假', 'HOUR', 80, TRUE,
     '00000000-0000-0000-0000-000000000000', TIMESTAMPTZ '1996-10-15 00:00:00+08:00',
     '00000000-0000-0000-0000-000000000000', TIMESTAMPTZ '1996-10-15 00:00:00+08:00', 0),
    ('00000000-0000-0000-0000-000000000012', 'sick', '病假', 'HOUR', NULL, TRUE,
     '00000000-0000-0000-0000-000000000000', TIMESTAMPTZ '1996-10-15 00:00:00+08:00',
     '00000000-0000-0000-0000-000000000000', TIMESTAMPTZ '1996-10-15 00:00:00+08:00', 0),
    ('00000000-0000-0000-0000-000000000013', 'personal', '事假', 'HOUR', NULL, TRUE,
     '00000000-0000-0000-0000-000000000000', TIMESTAMPTZ '1996-10-15 00:00:00+08:00',
     '00000000-0000-0000-0000-000000000000', TIMESTAMPTZ '1996-10-15 00:00:00+08:00', 0)
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- OA 表及字段注释（最终建表结构）
-- ============================================================

COMMENT ON TABLE spectra_oa.oa_asset IS '资产台账表';
COMMENT ON COLUMN spectra_oa.oa_asset.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_asset.department_id IS '所属部门ID';
COMMENT ON COLUMN spectra_oa.oa_asset.category_id IS '资产分类ID';
COMMENT ON COLUMN spectra_oa.oa_asset.asset_no IS '资产编号';
COMMENT ON COLUMN spectra_oa.oa_asset.name IS '资产名称';
COMMENT ON COLUMN spectra_oa.oa_asset.specification IS '规格型号';
COMMENT ON COLUMN spectra_oa.oa_asset.serial_no IS '序列号';
COMMENT ON COLUMN spectra_oa.oa_asset.asset_type IS '资产类型';
COMMENT ON COLUMN spectra_oa.oa_asset.status IS '资产状态（DRAFT/IN_STOCK/IN_USE/RETURNED/MAINTENANCE/SCRAPPED）';
COMMENT ON COLUMN spectra_oa.oa_asset.quantity IS '资产数量';
COMMENT ON COLUMN spectra_oa.oa_asset.acquisition_date IS '购置日期';
COMMENT ON COLUMN spectra_oa.oa_asset.acquisition_amount IS '购置金额';
COMMENT ON COLUMN spectra_oa.oa_asset.currency IS '币种';
COMMENT ON COLUMN spectra_oa.oa_asset.supplier IS '供应商';
COMMENT ON COLUMN spectra_oa.oa_asset.location IS '存放位置';
COMMENT ON COLUMN spectra_oa.oa_asset.custodian_id IS '资产保管人ID';
COMMENT ON COLUMN spectra_oa.oa_asset.warranty_until IS '保修截止时间';
COMMENT ON COLUMN spectra_oa.oa_asset.source_purchase_id IS '来源采购申请ID';
COMMENT ON COLUMN spectra_oa.oa_asset.source_receipt_id IS '来源收货单ID';
COMMENT ON COLUMN spectra_oa.oa_asset.source_purchase_item_id IS '来源采购明细ID';
COMMENT ON COLUMN spectra_oa.oa_asset.remark IS '备注';
COMMENT ON COLUMN spectra_oa.oa_asset.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_asset.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_asset.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_asset.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_asset.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_oa.oa_asset.version IS '乐观锁版本号';

COMMENT ON TABLE spectra_oa.oa_calendar IS '日历日程表';
COMMENT ON COLUMN spectra_oa.oa_calendar.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_calendar.owner_id IS '日程所有者ID';
COMMENT ON COLUMN spectra_oa.oa_calendar.department_id IS '所属部门ID';
COMMENT ON COLUMN spectra_oa.oa_calendar.title IS '日程标题';
COMMENT ON COLUMN spectra_oa.oa_calendar.content IS '日程内容';
COMMENT ON COLUMN spectra_oa.oa_calendar.start_time IS '开始时间';
COMMENT ON COLUMN spectra_oa.oa_calendar.end_time IS '结束时间';
COMMENT ON COLUMN spectra_oa.oa_calendar.all_day IS '是否全天事件';
COMMENT ON COLUMN spectra_oa.oa_calendar.event_type IS '事件类型';
COMMENT ON COLUMN spectra_oa.oa_calendar.visibility IS '可见范围';
COMMENT ON COLUMN spectra_oa.oa_calendar.location IS '日程地点';
COMMENT ON COLUMN spectra_oa.oa_calendar.participant_ids IS '参与人ID列表（文本）';
COMMENT ON COLUMN spectra_oa.oa_calendar.source_type IS '来源业务类型';
COMMENT ON COLUMN spectra_oa.oa_calendar.source_id IS '来源业务ID';
COMMENT ON COLUMN spectra_oa.oa_calendar.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_calendar.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_calendar.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_calendar.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_calendar.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_oa.oa_calendar.version IS '乐观锁版本号';

COMMENT ON TABLE spectra_oa.oa_contract IS '合同台账表';
COMMENT ON COLUMN spectra_oa.oa_contract.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_contract.contract_no IS '合同编号';
COMMENT ON COLUMN spectra_oa.oa_contract.title IS '合同标题';
COMMENT ON COLUMN spectra_oa.oa_contract.contract_type IS '合同类型';
COMMENT ON COLUMN spectra_oa.oa_contract.counterparty_name IS '相对方名称';
COMMENT ON COLUMN spectra_oa.oa_contract.counterparty_contact IS '相对方联系人';
COMMENT ON COLUMN spectra_oa.oa_contract.owner_id IS '合同负责人ID';
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
COMMENT ON COLUMN spectra_oa.oa_contract.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_oa.oa_contract.version IS '乐观锁版本号';

COMMENT ON TABLE spectra_oa.oa_contract_version IS '合同文件版本表';
COMMENT ON COLUMN spectra_oa.oa_contract_version.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_contract_version.contract_id IS '合同ID';
COMMENT ON COLUMN spectra_oa.oa_contract_version.version_no IS '版本号';
COMMENT ON COLUMN spectra_oa.oa_contract_version.file_id IS '文件ID';
COMMENT ON COLUMN spectra_oa.oa_contract_version.file_name IS '文件名称';
COMMENT ON COLUMN spectra_oa.oa_contract_version.file_size IS '文件大小（字节）';
COMMENT ON COLUMN spectra_oa.oa_contract_version.content_type IS '文件MIME类型';
COMMENT ON COLUMN spectra_oa.oa_contract_version.version_note IS '版本说明';
COMMENT ON COLUMN spectra_oa.oa_contract_version.is_current IS '是否当前版本';
COMMENT ON COLUMN spectra_oa.oa_contract_version.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_contract_version.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_contract_version.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_contract_version.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_contract_version.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_oa.oa_contract_version.version IS '乐观锁版本号';

COMMENT ON TABLE spectra_oa.oa_contract_milestone IS '合同履约节点表';
COMMENT ON COLUMN spectra_oa.oa_contract_milestone.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_contract_milestone.contract_id IS '合同ID';
COMMENT ON COLUMN spectra_oa.oa_contract_milestone.name IS '节点名称';
COMMENT ON COLUMN spectra_oa.oa_contract_milestone.milestone_type IS '节点类型';
COMMENT ON COLUMN spectra_oa.oa_contract_milestone.due_date IS '计划截止时间';
COMMENT ON COLUMN spectra_oa.oa_contract_milestone.status IS '节点状态';
COMMENT ON COLUMN spectra_oa.oa_contract_milestone.assignee_id IS '节点负责人ID';
COMMENT ON COLUMN spectra_oa.oa_contract_milestone.completed_at IS '完成时间';
COMMENT ON COLUMN spectra_oa.oa_contract_milestone.reminder_sent_at IS '提醒发送时间';
COMMENT ON COLUMN spectra_oa.oa_contract_milestone.remark IS '备注';
COMMENT ON COLUMN spectra_oa.oa_contract_milestone.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_contract_milestone.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_contract_milestone.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_contract_milestone.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_contract_milestone.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_oa.oa_contract_milestone.version IS '乐观锁版本号';

COMMENT ON TABLE spectra_oa.oa_document IS '文档表';
COMMENT ON COLUMN spectra_oa.oa_document.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_document.folder_id IS '所属目录ID';
COMMENT ON COLUMN spectra_oa.oa_document.title IS '文档标题';
COMMENT ON COLUMN spectra_oa.oa_document.summary IS '文档摘要';
COMMENT ON COLUMN spectra_oa.oa_document.status IS '文档状态（DRAFT/PUBLISHED/ARCHIVED）';
COMMENT ON COLUMN spectra_oa.oa_document.visibility IS '可见范围（PUBLIC/DEPARTMENT/PRIVATE）';
COMMENT ON COLUMN spectra_oa.oa_document.owner_id IS '文档所有者ID';
COMMENT ON COLUMN spectra_oa.oa_document.published_at IS '发布时间';
COMMENT ON COLUMN spectra_oa.oa_document.department_id IS '所属部门ID';
COMMENT ON COLUMN spectra_oa.oa_document.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_document.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_document.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_document.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_document.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_oa.oa_document.version IS '乐观锁版本号';

COMMENT ON TABLE spectra_oa.oa_document_folder IS '文档目录表';
COMMENT ON COLUMN spectra_oa.oa_document_folder.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_document_folder.pid IS '父目录ID';
COMMENT ON COLUMN spectra_oa.oa_document_folder.name IS '目录名称';
COMMENT ON COLUMN spectra_oa.oa_document_folder.department_id IS '所属部门ID';
COMMENT ON COLUMN spectra_oa.oa_document_folder.visibility IS '可见范围';
COMMENT ON COLUMN spectra_oa.oa_document_folder.sort IS '排序号';
COMMENT ON COLUMN spectra_oa.oa_document_folder.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_document_folder.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_document_folder.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_document_folder.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_document_folder.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_oa.oa_document_folder.version IS '乐观锁版本号';

COMMENT ON TABLE spectra_oa.oa_document_version IS '文档文件版本表';
COMMENT ON COLUMN spectra_oa.oa_document_version.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_document_version.document_id IS '文档ID';
COMMENT ON COLUMN spectra_oa.oa_document_version.version_no IS '版本号';
COMMENT ON COLUMN spectra_oa.oa_document_version.file_id IS '文件ID';
COMMENT ON COLUMN spectra_oa.oa_document_version.file_name IS '文件名称';
COMMENT ON COLUMN spectra_oa.oa_document_version.file_size IS '文件大小（字节）';
COMMENT ON COLUMN spectra_oa.oa_document_version.content_type IS '文件MIME类型';
COMMENT ON COLUMN spectra_oa.oa_document_version.version_note IS '版本说明';
COMMENT ON COLUMN spectra_oa.oa_document_version.is_current IS '是否当前版本';
COMMENT ON COLUMN spectra_oa.oa_document_version.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_document_version.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_document_version.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_document_version.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_document_version.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_oa.oa_document_version.version IS '乐观锁版本号';

COMMENT ON TABLE spectra_oa.oa_meeting IS '会议表';
COMMENT ON COLUMN spectra_oa.oa_meeting.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_meeting.title IS '会议标题';
COMMENT ON COLUMN spectra_oa.oa_meeting.initiator_id IS '发起人ID';
COMMENT ON COLUMN spectra_oa.oa_meeting.start_time IS '开始时间';
COMMENT ON COLUMN spectra_oa.oa_meeting.end_time IS '结束时间';
COMMENT ON COLUMN spectra_oa.oa_meeting.location IS '会议地点';
COMMENT ON COLUMN spectra_oa.oa_meeting.content IS '会议内容';
COMMENT ON COLUMN spectra_oa.oa_meeting.status IS '会议状态';
COMMENT ON COLUMN spectra_oa.oa_meeting.process_instance_id IS '流程实例ID';
COMMENT ON COLUMN spectra_oa.oa_meeting.approval_status IS '审批状态';
COMMENT ON COLUMN spectra_oa.oa_meeting.department_id IS '所属部门ID';
COMMENT ON COLUMN spectra_oa.oa_meeting.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_meeting.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_meeting.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_meeting.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_meeting.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_oa.oa_meeting.version IS '乐观锁版本号';

COMMENT ON TABLE spectra_oa.oa_meeting_participant IS '会议参会人员表';
COMMENT ON COLUMN spectra_oa.oa_meeting_participant.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_meeting_participant.meeting_id IS '会议ID';
COMMENT ON COLUMN spectra_oa.oa_meeting_participant.user_id IS '用户ID';
COMMENT ON COLUMN spectra_oa.oa_meeting_participant.role IS '参会角色（attendee/organizer）';
COMMENT ON COLUMN spectra_oa.oa_meeting_participant.status IS '参会状态（pending/accepted/declined）';
COMMENT ON COLUMN spectra_oa.oa_meeting_participant.check_in_at IS '签到时间';
COMMENT ON COLUMN spectra_oa.oa_meeting_participant.department_id IS '所属部门ID';
COMMENT ON COLUMN spectra_oa.oa_meeting_participant.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_meeting_participant.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_meeting_participant.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_meeting_participant.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_meeting_participant.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_oa.oa_meeting_participant.version IS '乐观锁版本号';

COMMENT ON TABLE spectra_oa.oa_meeting_record IS '会议纪要表';
COMMENT ON COLUMN spectra_oa.oa_meeting_record.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_meeting_record.meeting_id IS '会议ID';
COMMENT ON COLUMN spectra_oa.oa_meeting_record.content IS '纪要内容';
COMMENT ON COLUMN spectra_oa.oa_meeting_record.department_id IS '所属部门ID';
COMMENT ON COLUMN spectra_oa.oa_meeting_record.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_meeting_record.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_meeting_record.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_meeting_record.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_meeting_record.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_oa.oa_meeting_record.version IS '乐观锁版本号';

COMMENT ON TABLE spectra_oa.oa_notice IS '公告通知表';
COMMENT ON COLUMN spectra_oa.oa_notice.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_notice.title IS '公告标题';
COMMENT ON COLUMN spectra_oa.oa_notice.summary IS '公告摘要';
COMMENT ON COLUMN spectra_oa.oa_notice.content IS '公告内容';
COMMENT ON COLUMN spectra_oa.oa_notice.status IS '公告状态';
COMMENT ON COLUMN spectra_oa.oa_notice.target_type IS '发布目标类型（ALL/DEPARTMENT）';
COMMENT ON COLUMN spectra_oa.oa_notice.target_department_id IS '目标部门ID';
COMMENT ON COLUMN spectra_oa.oa_notice.publisher_id IS '发布人ID';
COMMENT ON COLUMN spectra_oa.oa_notice.publish_at IS '发布时间';
COMMENT ON COLUMN spectra_oa.oa_notice.required_read IS '是否要求阅读';
COMMENT ON COLUMN spectra_oa.oa_notice.department_id IS '所属部门ID';
COMMENT ON COLUMN spectra_oa.oa_notice.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_notice.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_notice.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_notice.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_notice.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_oa.oa_notice.version IS '乐观锁版本号';

COMMENT ON TABLE spectra_oa.oa_notice_reader IS '公告阅读回执表';
COMMENT ON COLUMN spectra_oa.oa_notice_reader.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_notice_reader.notice_id IS '公告ID';
COMMENT ON COLUMN spectra_oa.oa_notice_reader.user_id IS '阅读用户ID';
COMMENT ON COLUMN spectra_oa.oa_notice_reader.read_at IS '阅读时间';
COMMENT ON COLUMN spectra_oa.oa_notice_reader.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_notice_reader.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_notice_reader.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_notice_reader.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_notice_reader.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_oa.oa_notice_reader.version IS '乐观锁版本号';

COMMENT ON TABLE spectra_oa.oa_application_type IS 'OA 通用申请类型表';
COMMENT ON COLUMN spectra_oa.oa_application_type.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_application_type.code IS '申请类型编码';
COMMENT ON COLUMN spectra_oa.oa_application_type.name IS '申请类型名称';
COMMENT ON COLUMN spectra_oa.oa_application_type.form_definition_id IS '表单定义ID';
COMMENT ON COLUMN spectra_oa.oa_application_type.process_definition_key IS '流程定义KEY';
COMMENT ON COLUMN spectra_oa.oa_application_type.enabled IS '是否启用';
COMMENT ON COLUMN spectra_oa.oa_application_type.sort_order IS '排序号';
COMMENT ON COLUMN spectra_oa.oa_application_type.description IS '类型说明';
COMMENT ON COLUMN spectra_oa.oa_application_type.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_application_type.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_application_type.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_application_type.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_application_type.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_oa.oa_application_type.version IS '乐观锁版本号';

COMMENT ON TABLE spectra_oa.oa_application IS 'OA 通用申请主表';
COMMENT ON COLUMN spectra_oa.oa_application.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_application.application_no IS '申请单编号';
COMMENT ON COLUMN spectra_oa.oa_application.type_code IS '申请类型编码';
COMMENT ON COLUMN spectra_oa.oa_application.biz_id IS '类型业务明细ID';
COMMENT ON COLUMN spectra_oa.oa_application.applicant_id IS '申请人ID';
COMMENT ON COLUMN spectra_oa.oa_application.department_id IS '申请人所属部门ID';
COMMENT ON COLUMN spectra_oa.oa_application.title IS '申请标题';
COMMENT ON COLUMN spectra_oa.oa_application.status IS '申请状态（DRAFT/IN_REVIEW/APPROVED/REJECTED/WITHDRAWN/CANCELLED）';
COMMENT ON COLUMN spectra_oa.oa_application.process_instance_id IS '流程实例ID';
COMMENT ON COLUMN spectra_oa.oa_application.submitted_at IS '提交时间';
COMMENT ON COLUMN spectra_oa.oa_application.completed_at IS '完成时间';
COMMENT ON COLUMN spectra_oa.oa_application.reject_reason IS '驳回原因';
COMMENT ON COLUMN spectra_oa.oa_application.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_application.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_application.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_application.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_application.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_oa.oa_application.version IS '乐观锁版本号';

COMMENT ON TABLE spectra_oa.oa_application_attachment IS '申请附件关联表';
COMMENT ON COLUMN spectra_oa.oa_application_attachment.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_application_attachment.application_id IS '申请ID';
COMMENT ON COLUMN spectra_oa.oa_application_attachment.file_id IS '文件ID';
COMMENT ON COLUMN spectra_oa.oa_application_attachment.file_name IS '文件名称';
COMMENT ON COLUMN spectra_oa.oa_application_attachment.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_application_attachment.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_application_attachment.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_application_attachment.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_application_attachment.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_oa.oa_application_attachment.version IS '乐观锁版本号';

COMMENT ON TABLE spectra_oa.oa_application_cc IS '申请抄送关联表';
COMMENT ON COLUMN spectra_oa.oa_application_cc.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_application_cc.application_id IS '申请ID';
COMMENT ON COLUMN spectra_oa.oa_application_cc.user_id IS '抄送用户ID';
COMMENT ON COLUMN spectra_oa.oa_application_cc.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_application_cc.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_application_cc.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_application_cc.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_application_cc.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_oa.oa_application_cc.version IS '乐观锁版本号';

COMMENT ON TABLE spectra_oa.oa_leave_type IS '请假类型表';
COMMENT ON COLUMN spectra_oa.oa_leave_type.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_leave_type.code IS '请假类型编码';
COMMENT ON COLUMN spectra_oa.oa_leave_type.name IS '请假类型名称';
COMMENT ON COLUMN spectra_oa.oa_leave_type.unit IS '额度单位';
COMMENT ON COLUMN spectra_oa.oa_leave_type.default_hours IS '默认年度时长';
COMMENT ON COLUMN spectra_oa.oa_leave_type.enabled IS '是否启用';
COMMENT ON COLUMN spectra_oa.oa_leave_type.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_leave_type.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_leave_type.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_leave_type.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_leave_type.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_oa.oa_leave_type.version IS '乐观锁版本号';

COMMENT ON TABLE spectra_oa.oa_leave_application IS '请假申请明细表';
COMMENT ON COLUMN spectra_oa.oa_leave_application.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_leave_application.application_id IS '通用申请ID';
COMMENT ON COLUMN spectra_oa.oa_leave_application.department_id IS '所属部门ID';
COMMENT ON COLUMN spectra_oa.oa_leave_application.leave_type_code IS '请假类型编码';
COMMENT ON COLUMN spectra_oa.oa_leave_application.start_time IS '请假开始时间';
COMMENT ON COLUMN spectra_oa.oa_leave_application.end_time IS '请假结束时间';
COMMENT ON COLUMN spectra_oa.oa_leave_application.duration_hours IS '请假时长（小时）';
COMMENT ON COLUMN spectra_oa.oa_leave_application.reason IS '请假原因';
COMMENT ON COLUMN spectra_oa.oa_leave_application.contact_address IS '请假期间联系地址';
COMMENT ON COLUMN spectra_oa.oa_leave_application.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_leave_application.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_leave_application.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_leave_application.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_leave_application.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_oa.oa_leave_application.version IS '乐观锁版本号';

COMMENT ON TABLE spectra_oa.oa_leave_balance IS '请假年度额度表';
COMMENT ON COLUMN spectra_oa.oa_leave_balance.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_leave_balance.user_id IS '用户ID';
COMMENT ON COLUMN spectra_oa.oa_leave_balance.department_id IS '所属部门ID';
COMMENT ON COLUMN spectra_oa.oa_leave_balance.leave_type_code IS '请假类型编码';
COMMENT ON COLUMN spectra_oa.oa_leave_balance.year IS '额度年度';
COMMENT ON COLUMN spectra_oa.oa_leave_balance.total_hours IS '年度总额度（小时）';
COMMENT ON COLUMN spectra_oa.oa_leave_balance.used_hours IS '已使用额度（小时）';
COMMENT ON COLUMN spectra_oa.oa_leave_balance.reserved_hours IS '已预占额度（小时）';
COMMENT ON COLUMN spectra_oa.oa_leave_balance.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_leave_balance.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_leave_balance.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_leave_balance.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_leave_balance.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_oa.oa_leave_balance.version IS '乐观锁版本号';

COMMENT ON TABLE spectra_oa.oa_work_shift IS '固定工作班次表';
COMMENT ON COLUMN spectra_oa.oa_work_shift.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_work_shift.name IS '班次名称';
COMMENT ON COLUMN spectra_oa.oa_work_shift.work_start IS '上班时间';
COMMENT ON COLUMN spectra_oa.oa_work_shift.lunch_start IS '午休开始时间';
COMMENT ON COLUMN spectra_oa.oa_work_shift.lunch_end IS '午休结束时间';
COMMENT ON COLUMN spectra_oa.oa_work_shift.work_end IS '下班时间';
COMMENT ON COLUMN spectra_oa.oa_work_shift.enabled IS '是否启用';
COMMENT ON COLUMN spectra_oa.oa_work_shift.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_work_shift.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_work_shift.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_work_shift.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_work_shift.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_oa.oa_work_shift.version IS '乐观锁版本号';

COMMENT ON TABLE spectra_oa.oa_work_calendar IS '工作日日历表';
COMMENT ON COLUMN spectra_oa.oa_work_calendar.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_work_calendar.calendar_date IS '日历日期';
COMMENT ON COLUMN spectra_oa.oa_work_calendar.is_workday IS '是否工作日';
COMMENT ON COLUMN spectra_oa.oa_work_calendar.shift_id IS '班次ID';
COMMENT ON COLUMN spectra_oa.oa_work_calendar.remark IS '备注';
COMMENT ON COLUMN spectra_oa.oa_work_calendar.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_work_calendar.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_work_calendar.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_work_calendar.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_work_calendar.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_oa.oa_work_calendar.version IS '乐观锁版本号';

COMMENT ON TABLE spectra_oa.oa_attendance_record IS '请假审批回写的考勤影响记录表';
COMMENT ON COLUMN spectra_oa.oa_attendance_record.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_attendance_record.application_id IS '通用申请ID';
COMMENT ON COLUMN spectra_oa.oa_attendance_record.user_id IS '用户ID';
COMMENT ON COLUMN spectra_oa.oa_attendance_record.attendance_date IS '考勤日期';
COMMENT ON COLUMN spectra_oa.oa_attendance_record.status IS '考勤状态';
COMMENT ON COLUMN spectra_oa.oa_attendance_record.source IS '记录来源';
COMMENT ON COLUMN spectra_oa.oa_attendance_record.department_id IS '所属部门ID';
COMMENT ON COLUMN spectra_oa.oa_attendance_record.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_attendance_record.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_attendance_record.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_attendance_record.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_attendance_record.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_oa.oa_attendance_record.version IS '乐观锁版本号';

COMMENT ON TABLE spectra_oa.oa_asset_category IS '资产分类表';
COMMENT ON COLUMN spectra_oa.oa_asset_category.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_asset_category.pid IS '父分类ID';
COMMENT ON COLUMN spectra_oa.oa_asset_category.code IS '分类编码';
COMMENT ON COLUMN spectra_oa.oa_asset_category.name IS '分类名称';
COMMENT ON COLUMN spectra_oa.oa_asset_category.asset_type IS '资产类型';
COMMENT ON COLUMN spectra_oa.oa_asset_category.sort IS '排序号';
COMMENT ON COLUMN spectra_oa.oa_asset_category.enabled IS '是否启用';
COMMENT ON COLUMN spectra_oa.oa_asset_category.description IS '分类说明';
COMMENT ON COLUMN spectra_oa.oa_asset_category.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_asset_category.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_asset_category.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_asset_category.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_asset_category.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_oa.oa_asset_category.version IS '乐观锁版本号';

COMMENT ON TABLE spectra_oa.oa_asset_operation IS '资产生命周期操作表';
COMMENT ON COLUMN spectra_oa.oa_asset_operation.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_asset_operation.asset_id IS '资产ID';
COMMENT ON COLUMN spectra_oa.oa_asset_operation.operation_type IS '操作类型';
COMMENT ON COLUMN spectra_oa.oa_asset_operation.from_department_id IS '变更前部门ID';
COMMENT ON COLUMN spectra_oa.oa_asset_operation.to_department_id IS '变更后部门ID';
COMMENT ON COLUMN spectra_oa.oa_asset_operation.from_user_id IS '变更前责任人ID';
COMMENT ON COLUMN spectra_oa.oa_asset_operation.to_user_id IS '变更后责任人ID';
COMMENT ON COLUMN spectra_oa.oa_asset_operation.from_location IS '变更前位置';
COMMENT ON COLUMN spectra_oa.oa_asset_operation.to_location IS '变更后位置';
COMMENT ON COLUMN spectra_oa.oa_asset_operation.operation_date IS '操作时间';
COMMENT ON COLUMN spectra_oa.oa_asset_operation.reason IS '操作原因';
COMMENT ON COLUMN spectra_oa.oa_asset_operation.maintenance_content IS '维修内容';
COMMENT ON COLUMN spectra_oa.oa_asset_operation.maintenance_cost IS '维修费用';
COMMENT ON COLUMN spectra_oa.oa_asset_operation.status IS '操作状态';
COMMENT ON COLUMN spectra_oa.oa_asset_operation.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_asset_operation.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_asset_operation.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_asset_operation.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_asset_operation.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_oa.oa_asset_operation.version IS '乐观锁版本号';

COMMENT ON TABLE spectra_oa.oa_supply_item IS '办公用品 SKU 库存台账表';
COMMENT ON COLUMN spectra_oa.oa_supply_item.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_supply_item.category IS '用品分类';
COMMENT ON COLUMN spectra_oa.oa_supply_item.sku IS 'SKU编码';
COMMENT ON COLUMN spectra_oa.oa_supply_item.name IS '用品名称';
COMMENT ON COLUMN spectra_oa.oa_supply_item.specification IS '规格型号';
COMMENT ON COLUMN spectra_oa.oa_supply_item.unit IS '计量单位';
COMMENT ON COLUMN spectra_oa.oa_supply_item.current_stock IS '当前库存数量';
COMMENT ON COLUMN spectra_oa.oa_supply_item.min_stock IS '最低库存数量';
COMMENT ON COLUMN spectra_oa.oa_supply_item.status IS '用品状态';
COMMENT ON COLUMN spectra_oa.oa_supply_item.supplier IS '供应商';
COMMENT ON COLUMN spectra_oa.oa_supply_item.location IS '存放位置';
COMMENT ON COLUMN spectra_oa.oa_supply_item.department_id IS '所属部门ID';
COMMENT ON COLUMN spectra_oa.oa_supply_item.remark IS '备注';
COMMENT ON COLUMN spectra_oa.oa_supply_item.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_supply_item.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_supply_item.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_supply_item.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_supply_item.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_oa.oa_supply_item.version IS '乐观锁版本号';

COMMENT ON TABLE spectra_oa.oa_supply_operation IS '办公用品库存变动流水表';
COMMENT ON COLUMN spectra_oa.oa_supply_operation.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_supply_operation.supply_id IS '办公用品ID';
COMMENT ON COLUMN spectra_oa.oa_supply_operation.operation_type IS '操作类型（入库/领用/退库/调整）';
COMMENT ON COLUMN spectra_oa.oa_supply_operation.quantity IS '变动数量';
COMMENT ON COLUMN spectra_oa.oa_supply_operation.before_stock IS '变动前库存';
COMMENT ON COLUMN spectra_oa.oa_supply_operation.after_stock IS '变动后库存';
COMMENT ON COLUMN spectra_oa.oa_supply_operation.department_id IS '所属部门ID';
COMMENT ON COLUMN spectra_oa.oa_supply_operation.user_id IS '操作用户ID';
COMMENT ON COLUMN spectra_oa.oa_supply_operation.location IS '库存位置';
COMMENT ON COLUMN spectra_oa.oa_supply_operation.operation_date IS '操作时间';
COMMENT ON COLUMN spectra_oa.oa_supply_operation.reason IS '变动原因';
COMMENT ON COLUMN spectra_oa.oa_supply_operation.source_purchase_id IS '来源采购申请ID';
COMMENT ON COLUMN spectra_oa.oa_supply_operation.source_receipt_id IS '来源收货单ID';
COMMENT ON COLUMN spectra_oa.oa_supply_operation.source_purchase_item_id IS '来源采购明细ID';
COMMENT ON COLUMN spectra_oa.oa_supply_operation.status IS '操作状态';
COMMENT ON COLUMN spectra_oa.oa_supply_operation.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_supply_operation.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_supply_operation.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_supply_operation.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_supply_operation.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_oa.oa_supply_operation.version IS '乐观锁版本号';

COMMENT ON TABLE spectra_oa.oa_purchase IS '采购申请执行表';
COMMENT ON COLUMN spectra_oa.oa_purchase.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_purchase.application_id IS '通用申请ID';
COMMENT ON COLUMN spectra_oa.oa_purchase.department_id IS '所属部门ID';
COMMENT ON COLUMN spectra_oa.oa_purchase.purpose IS '采购用途';
COMMENT ON COLUMN spectra_oa.oa_purchase.expected_date IS '预计采购日期';
COMMENT ON COLUMN spectra_oa.oa_purchase.budget_amount IS '预算金额';
COMMENT ON COLUMN spectra_oa.oa_purchase.currency IS '币种';
COMMENT ON COLUMN spectra_oa.oa_purchase.suggested_supplier IS '建议供应商';
COMMENT ON COLUMN spectra_oa.oa_purchase.execution_status IS '执行状态（NOT_STARTED/ORDERED/PARTIAL_RECEIVED/RECEIVED/CANCELLED）';
COMMENT ON COLUMN spectra_oa.oa_purchase.purchaser_id IS '采购经办人ID';
COMMENT ON COLUMN spectra_oa.oa_purchase.order_no IS '订单编号';
COMMENT ON COLUMN spectra_oa.oa_purchase.ordered_at IS '下单时间';
COMMENT ON COLUMN spectra_oa.oa_purchase.completed_at IS '执行完成时间';
COMMENT ON COLUMN spectra_oa.oa_purchase.execution_remark IS '执行备注';
COMMENT ON COLUMN spectra_oa.oa_purchase.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_purchase.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_purchase.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_purchase.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_purchase.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_oa.oa_purchase.version IS '乐观锁版本号';

COMMENT ON TABLE spectra_oa.oa_purchase_item IS '采购申请明细表';
COMMENT ON COLUMN spectra_oa.oa_purchase_item.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_purchase_item.purchase_id IS '采购申请ID';
COMMENT ON COLUMN spectra_oa.oa_purchase_item.department_id IS '所属部门ID';
COMMENT ON COLUMN spectra_oa.oa_purchase_item.item_type IS '采购项类型';
COMMENT ON COLUMN spectra_oa.oa_purchase_item.item_name IS '采购项名称';
COMMENT ON COLUMN spectra_oa.oa_purchase_item.specification IS '规格型号';
COMMENT ON COLUMN spectra_oa.oa_purchase_item.quantity IS '采购数量';
COMMENT ON COLUMN spectra_oa.oa_purchase_item.estimated_unit_price IS '预计单价';
COMMENT ON COLUMN spectra_oa.oa_purchase_item.estimated_amount IS '预计金额';
COMMENT ON COLUMN spectra_oa.oa_purchase_item.purpose IS '明细用途';
COMMENT ON COLUMN spectra_oa.oa_purchase_item.received_quantity IS '已收货数量';
COMMENT ON COLUMN spectra_oa.oa_purchase_item.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_purchase_item.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_purchase_item.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_purchase_item.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_purchase_item.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_oa.oa_purchase_item.version IS '乐观锁版本号';

COMMENT ON TABLE spectra_oa.oa_purchase_receipt IS '采购收货批次表';
COMMENT ON COLUMN spectra_oa.oa_purchase_receipt.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_purchase_receipt.purchase_id IS '采购申请ID';
COMMENT ON COLUMN spectra_oa.oa_purchase_receipt.receipt_no IS '收货单编号';
COMMENT ON COLUMN spectra_oa.oa_purchase_receipt.received_date IS '收货时间';
COMMENT ON COLUMN spectra_oa.oa_purchase_receipt.receiver_id IS '收货人ID';
COMMENT ON COLUMN spectra_oa.oa_purchase_receipt.status IS '收货状态';
COMMENT ON COLUMN spectra_oa.oa_purchase_receipt.remark IS '备注';
COMMENT ON COLUMN spectra_oa.oa_purchase_receipt.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_purchase_receipt.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_purchase_receipt.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_purchase_receipt.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_purchase_receipt.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_oa.oa_purchase_receipt.version IS '乐观锁版本号';

COMMENT ON TABLE spectra_oa.oa_purchase_receipt_item IS '采购收货明细表';
COMMENT ON COLUMN spectra_oa.oa_purchase_receipt_item.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_purchase_receipt_item.receipt_id IS '收货批次ID';
COMMENT ON COLUMN spectra_oa.oa_purchase_receipt_item.purchase_item_id IS '采购明细ID';
COMMENT ON COLUMN spectra_oa.oa_purchase_receipt_item.quantity IS '本次收货数量';
COMMENT ON COLUMN spectra_oa.oa_purchase_receipt_item.accepted IS '是否验收通过';
COMMENT ON COLUMN spectra_oa.oa_purchase_receipt_item.difference_reason IS '验收差异原因';
COMMENT ON COLUMN spectra_oa.oa_purchase_receipt_item.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_purchase_receipt_item.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_purchase_receipt_item.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_purchase_receipt_item.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_purchase_receipt_item.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_oa.oa_purchase_receipt_item.version IS '乐观锁版本号';

COMMENT ON TABLE spectra_oa.oa_reimbursement IS '费用报销主表';
COMMENT ON COLUMN spectra_oa.oa_reimbursement.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_reimbursement.application_id IS '通用申请ID';
COMMENT ON COLUMN spectra_oa.oa_reimbursement.department_id IS '所属部门ID';
COMMENT ON COLUMN spectra_oa.oa_reimbursement.purpose IS '报销用途';
COMMENT ON COLUMN spectra_oa.oa_reimbursement.expense_start IS '费用开始时间';
COMMENT ON COLUMN spectra_oa.oa_reimbursement.expense_end IS '费用结束时间';
COMMENT ON COLUMN spectra_oa.oa_reimbursement.total_amount IS '报销总金额';
COMMENT ON COLUMN spectra_oa.oa_reimbursement.currency IS '币种';
COMMENT ON COLUMN spectra_oa.oa_reimbursement.payee_name IS '收款人姓名';
COMMENT ON COLUMN spectra_oa.oa_reimbursement.payee_account IS '收款账户';
COMMENT ON COLUMN spectra_oa.oa_reimbursement.payment_status IS '付款状态';
COMMENT ON COLUMN spectra_oa.oa_reimbursement.payment_at IS '付款时间';
COMMENT ON COLUMN spectra_oa.oa_reimbursement.payment_remark IS '付款备注';
COMMENT ON COLUMN spectra_oa.oa_reimbursement.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_reimbursement.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_reimbursement.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_reimbursement.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_reimbursement.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_oa.oa_reimbursement.version IS '乐观锁版本号';

COMMENT ON TABLE spectra_oa.oa_reimbursement_item IS '费用报销明细表';
COMMENT ON COLUMN spectra_oa.oa_reimbursement_item.id IS '主键ID';
COMMENT ON COLUMN spectra_oa.oa_reimbursement_item.reimbursement_id IS '报销单ID';
COMMENT ON COLUMN spectra_oa.oa_reimbursement_item.department_id IS '所属部门ID';
COMMENT ON COLUMN spectra_oa.oa_reimbursement_item.expense_date IS '费用发生时间';
COMMENT ON COLUMN spectra_oa.oa_reimbursement_item.category IS '费用类别';
COMMENT ON COLUMN spectra_oa.oa_reimbursement_item.description IS '费用说明';
COMMENT ON COLUMN spectra_oa.oa_reimbursement_item.amount IS '费用金额';
COMMENT ON COLUMN spectra_oa.oa_reimbursement_item.tax_amount IS '税额';
COMMENT ON COLUMN spectra_oa.oa_reimbursement_item.invoice_no IS '发票号码';
COMMENT ON COLUMN spectra_oa.oa_reimbursement_item.created_by IS '创建人';
COMMENT ON COLUMN spectra_oa.oa_reimbursement_item.created_at IS '创建时间';
COMMENT ON COLUMN spectra_oa.oa_reimbursement_item.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_oa.oa_reimbursement_item.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_oa.oa_reimbursement_item.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_oa.oa_reimbursement_item.version IS '乐观锁版本号';

-- Phase 6: Permission-aware DataScope predicates
CREATE INDEX IF NOT EXISTS idx_oa_asset_scope_department
    ON spectra_oa.oa_asset (department_id, id) WHERE deleted IS NULL;
CREATE INDEX IF NOT EXISTS idx_oa_calendar_scope_owner_department
    ON spectra_oa.oa_calendar (owner_id, department_id, id) WHERE deleted IS NULL;
CREATE INDEX IF NOT EXISTS idx_oa_contract_scope_department_owner
    ON spectra_oa.oa_contract (department_id, owner_id, id) WHERE deleted IS NULL;
CREATE INDEX IF NOT EXISTS idx_oa_document_scope_department_owner
    ON spectra_oa.oa_document (department_id, owner_id, id) WHERE deleted IS NULL;
CREATE INDEX IF NOT EXISTS idx_oa_document_folder_scope_department
    ON spectra_oa.oa_document_folder (department_id, id) WHERE deleted IS NULL;
CREATE INDEX IF NOT EXISTS idx_oa_meeting_scope_department
    ON spectra_oa.oa_meeting (department_id, id) WHERE deleted IS NULL;
CREATE INDEX IF NOT EXISTS idx_oa_meeting_participant_scope
    ON spectra_oa.oa_meeting_participant (department_id, user_id, meeting_id) WHERE deleted IS NULL;
CREATE INDEX IF NOT EXISTS idx_oa_meeting_record_scope_department
    ON spectra_oa.oa_meeting_record (department_id, meeting_id, id) WHERE deleted IS NULL;
CREATE INDEX IF NOT EXISTS idx_oa_notice_scope_department
    ON spectra_oa.oa_notice (department_id, target_department_id, id) WHERE deleted IS NULL;
CREATE INDEX IF NOT EXISTS idx_oa_application_scope_department
    ON spectra_oa.oa_application (department_id, applicant_id, id) WHERE deleted IS NULL;
CREATE INDEX IF NOT EXISTS idx_oa_leave_application_scope_department
    ON spectra_oa.oa_leave_application (department_id, created_by, id) WHERE deleted IS NULL;
CREATE INDEX IF NOT EXISTS idx_oa_leave_balance_scope
    ON spectra_oa.oa_leave_balance (department_id, user_id, id) WHERE deleted IS NULL;
CREATE INDEX IF NOT EXISTS idx_oa_attendance_record_scope
    ON spectra_oa.oa_attendance_record (department_id, user_id, id) WHERE deleted IS NULL;
CREATE INDEX IF NOT EXISTS idx_oa_supply_item_scope_department
    ON spectra_oa.oa_supply_item (department_id, id) WHERE deleted IS NULL;
CREATE INDEX IF NOT EXISTS idx_oa_purchase_scope_department
    ON spectra_oa.oa_purchase (department_id, id) WHERE deleted IS NULL;
CREATE INDEX IF NOT EXISTS idx_oa_purchase_item_scope_department
    ON spectra_oa.oa_purchase_item (department_id, purchase_id, id) WHERE deleted IS NULL;
CREATE INDEX IF NOT EXISTS idx_oa_purchase_receipt_scope_purchase
    ON spectra_oa.oa_purchase_receipt (purchase_id, id) WHERE deleted IS NULL;
CREATE INDEX IF NOT EXISTS idx_oa_purchase_receipt_item_scope_purchase_item
    ON spectra_oa.oa_purchase_receipt_item (purchase_item_id, receipt_id, id) WHERE deleted IS NULL;
CREATE INDEX IF NOT EXISTS idx_oa_reimbursement_scope_department
    ON spectra_oa.oa_reimbursement (department_id, id) WHERE deleted IS NULL;
CREATE INDEX IF NOT EXISTS idx_oa_reimbursement_item_scope_department
    ON spectra_oa.oa_reimbursement_item (department_id, reimbursement_id, id) WHERE deleted IS NULL;
