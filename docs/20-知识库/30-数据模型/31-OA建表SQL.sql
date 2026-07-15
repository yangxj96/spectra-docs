-- ============================================
-- spectra_core OA 模块建表语句
-- 共 11 张表
-- ============================================

-- OA 资产
CREATE TABLE spectra_core.oa_asset (
    id            UUID PRIMARY KEY,
    department_id UUID,
    created_by    UUID,
    created_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by    UUID,
    updated_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted       TIMESTAMP(6) WITH TIME ZONE,
    version       BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_core.oa_asset IS '资产表';
COMMENT ON COLUMN spectra_core.oa_asset.id IS '主键ID';
COMMENT ON COLUMN spectra_core.oa_asset.department_id IS '所属部门ID';
COMMENT ON COLUMN spectra_core.oa_asset.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.oa_asset.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.oa_asset.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.oa_asset.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.oa_asset.deleted IS '是否删除';
COMMENT ON COLUMN spectra_core.oa_asset.version IS '乐观锁';

-- OA 考勤
CREATE TABLE spectra_core.oa_attendance (
    id            UUID PRIMARY KEY,
    department_id UUID,
    created_by    UUID,
    created_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by    UUID,
    updated_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted       TIMESTAMP(6) WITH TIME ZONE,
    version       BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_core.oa_attendance IS '考勤表';
COMMENT ON COLUMN spectra_core.oa_attendance.id IS '主键ID';
COMMENT ON COLUMN spectra_core.oa_attendance.department_id IS '所属部门ID';
COMMENT ON COLUMN spectra_core.oa_attendance.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.oa_attendance.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.oa_attendance.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.oa_attendance.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.oa_attendance.deleted IS '是否删除';
COMMENT ON COLUMN spectra_core.oa_attendance.version IS '乐观锁';

-- OA 日历
CREATE TABLE spectra_core.oa_calendar (
    id            UUID PRIMARY KEY,
    department_id UUID,
    created_by    UUID,
    created_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by    UUID,
    updated_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted       TIMESTAMP(6) WITH TIME ZONE,
    version       BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_core.oa_calendar IS '日历表';
COMMENT ON COLUMN spectra_core.oa_calendar.id IS '主键ID';
COMMENT ON COLUMN spectra_core.oa_calendar.department_id IS '所属部门ID';
COMMENT ON COLUMN spectra_core.oa_calendar.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.oa_calendar.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.oa_calendar.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.oa_calendar.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.oa_calendar.deleted IS '是否删除';
COMMENT ON COLUMN spectra_core.oa_calendar.version IS '乐观锁';

-- OA 通讯录
CREATE TABLE spectra_core.oa_contact (
    id            UUID PRIMARY KEY,
    department_id UUID,
    created_by    UUID,
    created_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by    UUID,
    updated_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted       TIMESTAMP(6) WITH TIME ZONE,
    version       BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_core.oa_contact IS '通讯录表';
COMMENT ON COLUMN spectra_core.oa_contact.id IS '主键ID';
COMMENT ON COLUMN spectra_core.oa_contact.department_id IS '所属部门ID';
COMMENT ON COLUMN spectra_core.oa_contact.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.oa_contact.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.oa_contact.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.oa_contact.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.oa_contact.deleted IS '是否删除';
COMMENT ON COLUMN spectra_core.oa_contact.version IS '乐观锁';

-- OA 合同
CREATE TABLE spectra_core.oa_contract (
    id            UUID PRIMARY KEY,
    department_id UUID,
    created_by    UUID,
    created_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by    UUID,
    updated_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted       TIMESTAMP(6) WITH TIME ZONE,
    version       BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_core.oa_contract IS '合同表';
COMMENT ON COLUMN spectra_core.oa_contract.id IS '主键ID';
COMMENT ON COLUMN spectra_core.oa_contract.department_id IS '所属部门ID';
COMMENT ON COLUMN spectra_core.oa_contract.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.oa_contract.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.oa_contract.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.oa_contract.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.oa_contract.deleted IS '是否删除';
COMMENT ON COLUMN spectra_core.oa_contract.version IS '乐观锁';

-- OA 文档
CREATE TABLE spectra_core.oa_document (
    id            UUID PRIMARY KEY,
    department_id UUID,
    created_by    UUID,
    created_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by    UUID,
    updated_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted       TIMESTAMP(6) WITH TIME ZONE,
    version       BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_core.oa_document IS '文档表';
COMMENT ON COLUMN spectra_core.oa_document.id IS '主键ID';
COMMENT ON COLUMN spectra_core.oa_document.department_id IS '所属部门ID';
COMMENT ON COLUMN spectra_core.oa_document.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.oa_document.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.oa_document.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.oa_document.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.oa_document.deleted IS '是否删除';
COMMENT ON COLUMN spectra_core.oa_document.version IS '乐观锁';

-- OA 会议
CREATE TABLE spectra_core.oa_meeting (
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
COMMENT ON TABLE spectra_core.oa_meeting IS '会议表';
COMMENT ON COLUMN spectra_core.oa_meeting.title IS '会议标题';
COMMENT ON COLUMN spectra_core.oa_meeting.initiator_id IS '发起人ID';
COMMENT ON COLUMN spectra_core.oa_meeting.start_time IS '开始时间';
COMMENT ON COLUMN spectra_core.oa_meeting.end_time IS '结束时间';
COMMENT ON COLUMN spectra_core.oa_meeting.location IS '会议地点';
COMMENT ON COLUMN spectra_core.oa_meeting.content IS '会议内容';
COMMENT ON COLUMN spectra_core.oa_meeting.status IS '状态 draft/cancelled';
COMMENT ON COLUMN spectra_core.oa_meeting.process_instance_id IS '流程实例ID';
COMMENT ON COLUMN spectra_core.oa_meeting.approval_status IS '审批状态 draft/cancelled';

-- OA 参会人员
CREATE TABLE spectra_core.oa_meeting_participant (
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
COMMENT ON TABLE spectra_core.oa_meeting_participant IS '参会人员表';
COMMENT ON COLUMN spectra_core.oa_meeting_participant.id IS '主键ID';
COMMENT ON COLUMN spectra_core.oa_meeting_participant.meeting_id IS '会议ID';
COMMENT ON COLUMN spectra_core.oa_meeting_participant.user_id IS '用户ID';
COMMENT ON COLUMN spectra_core.oa_meeting_participant.role IS '角色 attendee/organizer';
COMMENT ON COLUMN spectra_core.oa_meeting_participant.status IS '状态 pending/accepted/declined';
COMMENT ON COLUMN spectra_core.oa_meeting_participant.check_in_at IS '签到时间';
COMMENT ON COLUMN spectra_core.oa_meeting_participant.department_id IS '所属部门ID';
COMMENT ON COLUMN spectra_core.oa_meeting_participant.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.oa_meeting_participant.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.oa_meeting_participant.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.oa_meeting_participant.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.oa_meeting_participant.deleted IS '是否删除';
COMMENT ON COLUMN spectra_core.oa_meeting_participant.version IS '乐观锁';

-- OA 会议纪要
CREATE TABLE spectra_core.oa_meeting_record (
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
COMMENT ON TABLE spectra_core.oa_meeting_record IS '会议纪要表';
COMMENT ON COLUMN spectra_core.oa_meeting_record.id IS '主键ID';
COMMENT ON COLUMN spectra_core.oa_meeting_record.meeting_id IS '会议ID';
COMMENT ON COLUMN spectra_core.oa_meeting_record.content IS '纪要内容';
COMMENT ON COLUMN spectra_core.oa_meeting_record.department_id IS '所属部门ID';
COMMENT ON COLUMN spectra_core.oa_meeting_record.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.oa_meeting_record.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.oa_meeting_record.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.oa_meeting_record.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.oa_meeting_record.deleted IS '是否删除';
COMMENT ON COLUMN spectra_core.oa_meeting_record.version IS '乐观锁';

-- OA 公告通知
CREATE TABLE spectra_core.oa_notice (
    id            UUID PRIMARY KEY,
    department_id UUID,
    created_by    UUID,
    created_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by    UUID,
    updated_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted       TIMESTAMP(6) WITH TIME ZONE,
    version       BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_core.oa_notice IS '公告通知表';
COMMENT ON COLUMN spectra_core.oa_notice.id IS '主键ID';
COMMENT ON COLUMN spectra_core.oa_notice.department_id IS '所属部门ID';
COMMENT ON COLUMN spectra_core.oa_notice.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.oa_notice.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.oa_notice.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.oa_notice.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.oa_notice.deleted IS '是否删除';
COMMENT ON COLUMN spectra_core.oa_notice.version IS '乐观锁';

-- OA 报表
CREATE TABLE spectra_core.oa_report (
    id            UUID PRIMARY KEY,
    department_id UUID,
    created_by    UUID,
    created_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by    UUID,
    updated_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted       TIMESTAMP(6) WITH TIME ZONE,
    version       BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_core.oa_report IS '报表表';
COMMENT ON COLUMN spectra_core.oa_report.id IS '主键ID';
COMMENT ON COLUMN spectra_core.oa_report.department_id IS '所属部门ID';
COMMENT ON COLUMN spectra_core.oa_report.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.oa_report.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.oa_report.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.oa_report.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.oa_report.deleted IS '是否删除';
COMMENT ON COLUMN spectra_core.oa_report.version IS '乐观锁';
