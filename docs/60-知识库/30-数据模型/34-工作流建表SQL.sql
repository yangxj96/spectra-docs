-- ============================================
-- spectra_workflow 工作流模块建表语句
-- 共 2 张表（自定义表单）
-- ============================================

-- 工作流-表单定义主表
-- 存储表单的元数据信息，每个表单一条记录
CREATE TABLE spectra_core.wf_form_definition (
    id              UUID PRIMARY KEY,
    name            VARCHAR(200) NOT NULL,
    code            VARCHAR(100) NOT NULL UNIQUE,
    current_version INTEGER DEFAULT 1,
    active          BOOLEAN DEFAULT TRUE,
    description     TEXT,
    created_by      UUID,
    created_at      TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by      UUID,
    updated_at      TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted         TIMESTAMP(6) WITH TIME ZONE,
    version         BIGINT DEFAULT 0
);

COMMENT ON TABLE spectra_core.wf_form_definition IS '表单定义表';
COMMENT ON COLUMN spectra_core.wf_form_definition.id IS '主键ID';
COMMENT ON COLUMN spectra_core.wf_form_definition.name IS '表单名称';
COMMENT ON COLUMN spectra_core.wf_form_definition.code IS '表单编码（唯一，用于程序引用）';
COMMENT ON COLUMN spectra_core.wf_form_definition.current_version IS '当前版本号';
COMMENT ON COLUMN spectra_core.wf_form_definition.active IS '是否启用';
COMMENT ON COLUMN spectra_core.wf_form_definition.description IS '描述';
COMMENT ON COLUMN spectra_core.wf_form_definition.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.wf_form_definition.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.wf_form_definition.updated_by IS '最后修改人';
COMMENT ON COLUMN spectra_core.wf_form_definition.updated_at IS '最后修改时间';
COMMENT ON COLUMN spectra_core.wf_form_definition.deleted IS '是否删除（null=未删除）';
COMMENT ON COLUMN spectra_core.wf_form_definition.version IS '乐观锁版本号';

-- 工作流-表单版本表
-- 每次保存表单设计器内容时生成新版本，旧版本保留用于历史追溯
CREATE TABLE spectra_core.wf_form_version (
    id                 UUID PRIMARY KEY,
    form_definition_id UUID NOT NULL,
    form_version       INTEGER NOT NULL,
    rule_json          TEXT,
    options_json       TEXT,
    form_json          TEXT,
    created_by         UUID,
    created_at         TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by         UUID,
    updated_at         TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted            TIMESTAMP(6) WITH TIME ZONE,
    version            BIGINT DEFAULT 0,
    UNIQUE(form_definition_id, form_version)
);

COMMENT ON TABLE spectra_core.wf_form_version IS '表单版本表';
COMMENT ON COLUMN spectra_core.wf_form_version.id IS '主键ID';
COMMENT ON COLUMN spectra_core.wf_form_version.form_definition_id IS '关联表单定义ID';
COMMENT ON COLUMN spectra_core.wf_form_version.form_version IS '版本号（同一表单下唯一）';
COMMENT ON COLUMN spectra_core.wf_form_version.rule_json IS 'form-create规则JSON（组件定义）';
COMMENT ON COLUMN spectra_core.wf_form_version.options_json IS 'form-create配置JSON（表单属性）';
COMMENT ON COLUMN spectra_core.wf_form_version.form_json IS 'form-create getJson()完整输出';
COMMENT ON COLUMN spectra_core.wf_form_version.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.wf_form_version.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.wf_form_version.updated_by IS '最后修改人';
COMMENT ON COLUMN spectra_core.wf_form_version.updated_at IS '最后修改时间';
COMMENT ON COLUMN spectra_core.wf_form_version.deleted IS '是否删除（null=未删除）';
COMMENT ON COLUMN spectra_core.wf_form_version.version IS '乐观锁版本号';
