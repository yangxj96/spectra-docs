-- ============================================
-- spectra_core schema 建表语句
-- 共 21 张表（不含 BaseEntity；旧认证/授权运行时表已不属于当前目标模型）
-- 当前物理字段顺序、种子审计元数据和完整注释由 Flyway 基线及增量迁移固化。
-- ============================================

CREATE SCHEMA IF NOT EXISTS spectra_core;

-- ============================================
-- 认证
-- ============================================

-- ============================================
-- 用户权限
-- ============================================

-- 用户表
CREATE TABLE spectra_core.sys_user (
    id             UUID PRIMARY KEY,
    employee_no    VARCHAR(64) NOT NULL,
    avatar         VARCHAR(255),
    status         VARCHAR(16) NOT NULL DEFAULT 'ACTIVE',
    status_reason  VARCHAR(500),
    departed_at    TIMESTAMP(6) WITH TIME ZONE,
    real_name      VARCHAR(50),
    phone          VARCHAR(20),
    email          VARCHAR(100),
    language       VARCHAR(10) DEFAULT 'zh-CN',
    timezone       VARCHAR(40) DEFAULT 'Asia/Shanghai',
    primary_department_id UUID,
    security_version BIGINT NOT NULL DEFAULT 0,
    created_by     UUID,
    created_at     TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by     UUID,
    updated_at     TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted        TIMESTAMP(6) WITH TIME ZONE,
    version        BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_core.sys_user IS '用户表';
COMMENT ON COLUMN spectra_core.sys_user.id IS '主键ID';
COMMENT ON COLUMN spectra_core.sys_user.employee_no IS '工号/员工编号';
COMMENT ON COLUMN spectra_core.sys_user.avatar IS '头像';
COMMENT ON COLUMN spectra_core.sys_user.status IS '账号生命周期状态：ACTIVE-正常，LOCKED-锁定，DISABLED-禁用，DEPARTED-离职';
COMMENT ON COLUMN spectra_core.sys_user.status_reason IS '状态变更原因';
COMMENT ON COLUMN spectra_core.sys_user.departed_at IS '离职时间';
COMMENT ON COLUMN spectra_core.sys_user.real_name IS '姓名';
COMMENT ON COLUMN spectra_core.sys_user.phone IS '手机号';
COMMENT ON COLUMN spectra_core.sys_user.email IS '邮箱';
COMMENT ON COLUMN spectra_core.sys_user.language IS '语言';
COMMENT ON COLUMN spectra_core.sys_user.timezone IS '时区';
COMMENT ON COLUMN spectra_core.sys_user.primary_department_id IS '主部门ID；完整组织关系由用户部门成员关系表维护';
COMMENT ON COLUMN spectra_core.sys_user.security_version IS '安全版本号，用于权限变更和会话失效';
COMMENT ON COLUMN spectra_core.sys_user.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.sys_user.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.sys_user.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.sys_user.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.sys_user.deleted IS '删除时间';
COMMENT ON COLUMN spectra_core.sys_user.version IS '乐观锁';

-- ============================================
-- 系统管理
-- ============================================

-- 部门表
CREATE TABLE spectra_core.sys_department (
    id         UUID PRIMARY KEY,
    pid        UUID,
    name       VARCHAR(100) NOT NULL,
    code       VARCHAR(100) NOT NULL,
    type       VARCHAR(50),
    path       VARCHAR(255),
    remark     VARCHAR(255),
    region_id  UUID,
    sort       INTEGER DEFAULT 0,
    created_by UUID,
    created_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by UUID,
    updated_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted    TIMESTAMP(6) WITH TIME ZONE,
    version    BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_core.sys_department IS '部门表';
COMMENT ON COLUMN spectra_core.sys_department.id IS '主键ID';
COMMENT ON COLUMN spectra_core.sys_department.pid IS '上级ID';
COMMENT ON COLUMN spectra_core.sys_department.name IS '名称';
COMMENT ON COLUMN spectra_core.sys_department.code IS '编码';
COMMENT ON COLUMN spectra_core.sys_department.type IS '公司类型';
COMMENT ON COLUMN spectra_core.sys_department.path IS '组织机构路径';
COMMENT ON COLUMN spectra_core.sys_department.remark IS '备注';
COMMENT ON COLUMN spectra_core.sys_department.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.sys_department.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.sys_department.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.sys_department.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.sys_department.deleted IS '是否删除';
COMMENT ON COLUMN spectra_core.sys_department.version IS '乐观锁';
COMMENT ON COLUMN spectra_core.sys_department.region_id IS '所属行政区划ID';
COMMENT ON COLUMN spectra_core.sys_department.sort IS '排序,默认0';

-- 用户部门关系表
CREATE TABLE spectra_core.sys_user_department_membership (
    id              UUID DEFAULT uuidv7() PRIMARY KEY,
    user_id         UUID NOT NULL REFERENCES spectra_core.sys_user (id) ON DELETE RESTRICT,
    department_id   UUID NOT NULL REFERENCES spectra_core.sys_department (id) ON DELETE RESTRICT,
    membership_type VARCHAR(16) NOT NULL,
    created_by      UUID,
    created_at      TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by      UUID,
    updated_at      TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted         TIMESTAMP(6) WITH TIME ZONE,
    version         BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT uk_sys_user_department_membership_pair UNIQUE (user_id, department_id),
    CONSTRAINT ck_sys_user_department_membership_type
        CHECK (membership_type IN ('PRIMARY', 'ASSOCIATED'))
);

-- 组织闭包关系表
CREATE TABLE spectra_core.sys_department_closure (
    id           UUID DEFAULT uuidv7() PRIMARY KEY,
    ancestor_id  UUID NOT NULL REFERENCES spectra_core.sys_department (id) ON DELETE CASCADE,
    descendant_id UUID NOT NULL REFERENCES spectra_core.sys_department (id) ON DELETE CASCADE,
    depth        INTEGER NOT NULL,
    created_by   UUID,
    created_at   TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by   UUID,
    updated_at   TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted      TIMESTAMP(6) WITH TIME ZONE,
    version      BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT uk_sys_department_closure_pair UNIQUE (ancestor_id, descendant_id),
    CONSTRAINT ck_sys_department_closure_depth CHECK (depth >= 0)
);

-- 组织树安全版本单例
CREATE TABLE spectra_core.sys_organization_version (
    id                   UUID DEFAULT uuidv7() PRIMARY KEY,
    singleton_key        VARCHAR(16) NOT NULL DEFAULT 'SYSTEM',
    organization_version BIGINT NOT NULL DEFAULT 0,
    changed_at           TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_by           UUID,
    created_at           TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by           UUID,
    updated_at           TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted              TIMESTAMP(6) WITH TIME ZONE,
    version              BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT uk_sys_organization_version_key UNIQUE (singleton_key),
    CONSTRAINT ck_sys_organization_version_key CHECK (singleton_key = 'SYSTEM'),
    CONSTRAINT ck_sys_organization_version_value CHECK (organization_version >= 0)
);

INSERT INTO spectra_core.sys_organization_version
    (id, singleton_key, organization_version, created_by, created_at, updated_by, updated_at, version)
VALUES
    ('00000000-0000-0000-0000-000000000000', 'SYSTEM', 0,
     '00000000-0000-0000-0000-000000000000', TIMESTAMPTZ '1996-10-15 00:00:00+08:00',
     '00000000-0000-0000-0000-000000000000', TIMESTAMPTZ '1996-10-15 00:00:00+08:00', 0)
ON CONFLICT (singleton_key) DO NOTHING;

-- 菜单表
CREATE TABLE spectra_core.sys_menu (
    id          UUID PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    pid         UUID,
    icon        VARCHAR(100),
    menu_type   VARCHAR(16) NOT NULL,
    route_name  VARCHAR(100),
    sort        INTEGER NOT NULL DEFAULT 0,
    created_by  UUID,
    created_at  TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by  UUID,
    updated_at  TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted     TIMESTAMP(6) WITH TIME ZONE,
    version     BIGINT DEFAULT 0,
    CONSTRAINT ck_sys_menu_type
        CHECK (menu_type IN ('DIRECTORY', 'MENU')),
    CONSTRAINT ck_sys_menu_route_binding
        CHECK (deleted IS NOT NULL
            OR (menu_type = 'DIRECTORY' AND route_name IS NULL)
            OR (menu_type = 'MENU' AND route_name IS NOT NULL))
);
COMMENT ON TABLE spectra_core.sys_menu IS '菜单表';
COMMENT ON COLUMN spectra_core.sys_menu.id IS '主键ID';
COMMENT ON COLUMN spectra_core.sys_menu.name IS '名称';
COMMENT ON COLUMN spectra_core.sys_menu.pid IS '父级ID';
COMMENT ON COLUMN spectra_core.sys_menu.icon IS '图标';
COMMENT ON COLUMN spectra_core.sys_menu.menu_type IS '菜单类型：DIRECTORY-目录，MENU-可点击菜单';
COMMENT ON COLUMN spectra_core.sys_menu.route_name IS '对应 Vue Router 的唯一命名路由';
COMMENT ON COLUMN spectra_core.sys_menu.sort IS '排序';
COMMENT ON COLUMN spectra_core.sys_menu.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.sys_menu.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.sys_menu.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.sys_menu.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.sys_menu.deleted IS '是否删除';
COMMENT ON COLUMN spectra_core.sys_menu.version IS '乐观锁';
CREATE UNIQUE INDEX uk_sys_menu_route_name_active
    ON spectra_core.sys_menu (route_name)
    WHERE deleted IS NULL AND route_name IS NOT NULL;

-- 区域表
CREATE TABLE spectra_core.sys_region (
    id         UUID PRIMARY KEY,
    pid        UUID,
    name       VARCHAR(100),
    full_name  VARCHAR(255),
    short_name VARCHAR(100),
    code       VARCHAR(100),
    path       VARCHAR(255),
    level      INTEGER,
    status     BOOLEAN NOT NULL DEFAULT TRUE,
    sort       INTEGER,
    created_by UUID,
    created_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by UUID,
    updated_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted    TIMESTAMP(6) WITH TIME ZONE,
    version    BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_core.sys_region IS '行政区划表';
COMMENT ON COLUMN spectra_core.sys_region.id IS '主键ID';
COMMENT ON COLUMN spectra_core.sys_region.pid IS '上级ID';
COMMENT ON COLUMN spectra_core.sys_region.name IS '区域名称';
COMMENT ON COLUMN spectra_core.sys_region.full_name IS '区域全称，如 北京市/北京市/东城区';
COMMENT ON COLUMN spectra_core.sys_region.short_name IS '简称';
COMMENT ON COLUMN spectra_core.sys_region.code IS '区域编码';
COMMENT ON COLUMN spectra_core.sys_region.path IS '区域路径，如 /110000/110100/110101';
COMMENT ON COLUMN spectra_core.sys_region.level IS '行政区划层级:1省 2地级市 3县级 4乡级 5村级';
COMMENT ON COLUMN spectra_core.sys_region.status IS '状态：true-启用 false-停用';
COMMENT ON COLUMN spectra_core.sys_region.sort IS '排序';
COMMENT ON COLUMN spectra_core.sys_region.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.sys_region.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.sys_region.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.sys_region.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.sys_region.deleted IS '删除标识';
COMMENT ON COLUMN spectra_core.sys_region.version IS '乐观锁';

-- 系统首次初始化状态
CREATE TABLE spectra_core.sys_system_state (
    id                UUID DEFAULT uuidv7() PRIMARY KEY,
    state_key         VARCHAR(32) NOT NULL,
    state             VARCHAR(32) NOT NULL DEFAULT 'UNINITIALIZED',
    initialization_id UUID,
    initialized_at    TIMESTAMP(6) WITH TIME ZONE,
    initialized_by    UUID,
    created_by        UUID,
    created_at        TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by        UUID,
    updated_at        TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted           TIMESTAMP(6) WITH TIME ZONE,
    version           BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT uk_sys_system_state_key UNIQUE (state_key),
    CONSTRAINT ck_sys_system_state_key CHECK (state_key IN ('SYSTEM', 'SYSTEM_GUIDE')),
    CONSTRAINT ck_sys_system_state_value CHECK (
        (state_key = 'SYSTEM' AND state IN ('UNINITIALIZED', 'INITIALIZING', 'INITIALIZED'))
            OR (state_key = 'SYSTEM_GUIDE' AND state IN ('PENDING', 'COMPLETED'))
    )
);

INSERT INTO spectra_core.sys_system_state
    (id, state_key, state, created_by, created_at, updated_by, updated_at, version)
VALUES
    ('00000000-0000-0000-0000-000000000000', 'SYSTEM', 'UNINITIALIZED',
     '00000000-0000-0000-0000-000000000000', TIMESTAMPTZ '1996-10-15 00:00:00+08:00',
     '00000000-0000-0000-0000-000000000000', TIMESTAMPTZ '1996-10-15 00:00:00+08:00', 0)
ON CONFLICT (state_key) DO NOTHING;

INSERT INTO spectra_core.sys_system_state
    (id, state_key, state, created_by, created_at, updated_by, updated_at, version)
VALUES
    ('00000000-0000-0000-0000-000000000001', 'SYSTEM_GUIDE', 'PENDING',
     '00000000-0000-0000-0000-000000000000', TIMESTAMPTZ '1996-10-15 00:00:00+08:00',
     '00000000-0000-0000-0000-000000000000', TIMESTAMPTZ '1996-10-15 00:00:00+08:00', 0)
ON CONFLICT (state_key) DO NOTHING;

-- 字典组
CREATE TABLE spectra_core.sys_dict_group (
    id         UUID PRIMARY KEY,
    pid        UUID,
    name       VARCHAR(100),
    code       VARCHAR(100),
    state      BOOLEAN NOT NULL DEFAULT TRUE,
    remark     VARCHAR(255),
    builtin    BOOLEAN NOT NULL DEFAULT FALSE,
    hide       BOOLEAN NOT NULL DEFAULT FALSE,
    created_by UUID,
    created_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by UUID,
    updated_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted    TIMESTAMP(6) WITH TIME ZONE,
    version    BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_core.sys_dict_group IS '字典组';
COMMENT ON COLUMN spectra_core.sys_dict_group.id IS '主键ID';
COMMENT ON COLUMN spectra_core.sys_dict_group.pid IS '上级字典组 ID';
COMMENT ON COLUMN spectra_core.sys_dict_group.name IS '字典组名称';
COMMENT ON COLUMN spectra_core.sys_dict_group.code IS '字典组编码';
COMMENT ON COLUMN spectra_core.sys_dict_group.state IS '是否启用';
COMMENT ON COLUMN spectra_core.sys_dict_group.remark IS '备注';
COMMENT ON COLUMN spectra_core.sys_dict_group.builtin IS '是否内置字典组';
COMMENT ON COLUMN spectra_core.sys_dict_group.hide IS '是否隐藏';
COMMENT ON COLUMN spectra_core.sys_dict_group.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.sys_dict_group.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.sys_dict_group.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.sys_dict_group.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.sys_dict_group.deleted IS '是否删除';
COMMENT ON COLUMN spectra_core.sys_dict_group.version IS '乐观锁';

-- 字典项
CREATE TABLE spectra_core.sys_dict_item (
    id           UUID PRIMARY KEY,
    gid          UUID NOT NULL,
    label        VARCHAR(100) NOT NULL,
    value        VARCHAR(100) NOT NULL,
    sort         SMALLINT NOT NULL DEFAULT 0,
    state        SMALLINT NOT NULL,
    remark       VARCHAR(255),
    default_flag BOOLEAN DEFAULT FALSE,
    created_by   UUID,
    created_at   TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by   UUID,
    updated_at   TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted      TIMESTAMP(6) WITH TIME ZONE,
    version      BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_core.sys_dict_item IS '字典项';
COMMENT ON COLUMN spectra_core.sys_dict_item.id IS '主键ID';
COMMENT ON COLUMN spectra_core.sys_dict_item.gid IS '字典组ID';
COMMENT ON COLUMN spectra_core.sys_dict_item.label IS '标签';
COMMENT ON COLUMN spectra_core.sys_dict_item.value IS '值';
COMMENT ON COLUMN spectra_core.sys_dict_item.sort IS '排序';
COMMENT ON COLUMN spectra_core.sys_dict_item.state IS '状态';
COMMENT ON COLUMN spectra_core.sys_dict_item.remark IS '备注';
COMMENT ON COLUMN spectra_core.sys_dict_item.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.sys_dict_item.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.sys_dict_item.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.sys_dict_item.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.sys_dict_item.deleted IS '是否删除';
COMMENT ON COLUMN spectra_core.sys_dict_item.version IS '乐观锁';
COMMENT ON COLUMN spectra_core.sys_dict_item.default_flag IS '是否默认';

-- 系统配置
CREATE TABLE spectra_core.sys_config (
    id         UUID PRIMARY KEY,
    key        VARCHAR(100) NOT NULL,
    value      TEXT NOT NULL,
    type       INTEGER NOT NULL,
    dict_code  VARCHAR(255),
    remarks    VARCHAR(255),
    created_by UUID,
    created_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by UUID,
    updated_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted    TIMESTAMP(6) WITH TIME ZONE,
    version    BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_core.sys_config IS '系统配置表';
COMMENT ON COLUMN spectra_core.sys_config.id IS '主键ID';
COMMENT ON COLUMN spectra_core.sys_config.key IS '配置key';
COMMENT ON COLUMN spectra_core.sys_config.value IS '配置VALUE';
COMMENT ON COLUMN spectra_core.sys_config.type IS '值类型';
COMMENT ON COLUMN spectra_core.sys_config.dict_code IS '字典组CODE';
COMMENT ON COLUMN spectra_core.sys_config.remarks IS '备注说明';
COMMENT ON COLUMN spectra_core.sys_config.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.sys_config.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.sys_config.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.sys_config.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.sys_config.deleted IS '删除时间';
COMMENT ON COLUMN spectra_core.sys_config.version IS '乐观锁版本号,默认0';

-- 操作日志
CREATE TABLE spectra_core.sys_log (
    id          UUID PRIMARY KEY,
    user_id     UUID,
    module      VARCHAR(100),
    action      VARCHAR(100),
    target      VARCHAR(255),
    ip          VARCHAR(50),
    user_agent  VARCHAR(500),
    request_params  TEXT,
    response_result TEXT,
    duration    BIGINT,
    type        INTEGER,
    explain     TEXT,
    status      SMALLINT,
    method      VARCHAR(32),
    url         VARCHAR(1000),
    args        JSONB,
    result      JSONB,
    time_cost   BIGINT,
    created_by  UUID,
    created_at  TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by  UUID,
    updated_at  TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted     TIMESTAMP(6) WITH TIME ZONE,
    version     BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_core.sys_log IS '操作日志表';
COMMENT ON COLUMN spectra_core.sys_log.id IS '主键ID';
COMMENT ON COLUMN spectra_core.sys_log.type IS '日志类型：0 常规，1 安全，2 系统异常，3 自动化';
COMMENT ON COLUMN spectra_core.sys_log.explain IS '日志说明';
COMMENT ON COLUMN spectra_core.sys_log.status IS '请求响应状态码';
COMMENT ON COLUMN spectra_core.sys_log.ip IS '操作IP';
COMMENT ON COLUMN spectra_core.sys_log.method IS '请求方法';
COMMENT ON COLUMN spectra_core.sys_log.url IS '请求 URL';
COMMENT ON COLUMN spectra_core.sys_log.args IS '脱敏后的请求参数 JSON';
COMMENT ON COLUMN spectra_core.sys_log.result IS '脱敏后的响应结果 JSON';
COMMENT ON COLUMN spectra_core.sys_log.time_cost IS '请求耗时（毫秒）';
COMMENT ON COLUMN spectra_core.sys_log.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.sys_log.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.sys_log.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.sys_log.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.sys_log.deleted IS '是否删除';
COMMENT ON COLUMN spectra_core.sys_log.version IS '乐观锁';
COMMENT ON COLUMN spectra_core.sys_log.user_id IS 'V1 兼容字段：旧操作用户ID';
COMMENT ON COLUMN spectra_core.sys_log.module IS 'V1 兼容字段：旧操作模块';
COMMENT ON COLUMN spectra_core.sys_log.action IS 'V1 兼容字段：旧操作类型';
COMMENT ON COLUMN spectra_core.sys_log.target IS 'V1 兼容字段：旧操作对象';
COMMENT ON COLUMN spectra_core.sys_log.user_agent IS 'V1 兼容字段：旧客户端信息';
COMMENT ON COLUMN spectra_core.sys_log.request_params IS 'V1 兼容字段：旧请求参数';
COMMENT ON COLUMN spectra_core.sys_log.response_result IS 'V1 兼容字段：旧响应结果';
COMMENT ON COLUMN spectra_core.sys_log.duration IS 'V1 兼容字段：旧执行耗时（毫秒）';

-- ============================================
-- 文件管理
-- ============================================

-- 文件信息
CREATE TABLE spectra_core.file_info (
    id             UUID PRIMARY KEY,
    filename       VARCHAR(255) NOT NULL,
    original_name  VARCHAR(255),
    content_type   VARCHAR(100),
    size           BIGINT NOT NULL,
    hash           VARCHAR(64) NOT NULL,
    storage_type   VARCHAR(20) NOT NULL,
    status         VARCHAR(20) NOT NULL,
    ref_count      INTEGER DEFAULT 1,
    created_by     UUID,
    created_at     TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by     UUID,
    updated_at     TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted        TIMESTAMP(6) WITH TIME ZONE,
    version        BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_core.file_info IS '文件信息表';
COMMENT ON COLUMN spectra_core.file_info.id IS '主键ID';
COMMENT ON COLUMN spectra_core.file_info.filename IS '存储文件名(系统生成)';
COMMENT ON COLUMN spectra_core.file_info.original_name IS '原始文件名';
COMMENT ON COLUMN spectra_core.file_info.content_type IS '文件类型(MIME)';
COMMENT ON COLUMN spectra_core.file_info.size IS '文件大小(字节)';
COMMENT ON COLUMN spectra_core.file_info.hash IS '文件哈希(MD5/SHA256，用于秒传)';
COMMENT ON COLUMN spectra_core.file_info.storage_type IS '存储类型(LOCAL/S3/OSS)';
COMMENT ON COLUMN spectra_core.file_info.status IS '文件状态(ACTIVE/DELETED)';
COMMENT ON COLUMN spectra_core.file_info.ref_count IS '引用计数(用于秒传共享文件)';
COMMENT ON COLUMN spectra_core.file_info.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.file_info.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.file_info.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.file_info.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.file_info.deleted IS '是否删除';
COMMENT ON COLUMN spectra_core.file_info.version IS '乐观锁';

-- 文件类型
CREATE TABLE spectra_core.file_type (
    id              UUID PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    extension       JSONB NOT NULL,
    mime            JSONB NOT NULL,
    magic_rules     JSONB,
    max_size        BIGINT NOT NULL,
    previewable     BOOLEAN DEFAULT FALSE,
    allowed_upload  BOOLEAN DEFAULT TRUE,
    dangerous       BOOLEAN DEFAULT FALSE,
    remark          TEXT,
    created_by      UUID,
    created_at      TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by      UUID,
    updated_at      TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted         TIMESTAMP(6) WITH TIME ZONE,
    version         BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_core.file_type IS '文件类型表';
COMMENT ON COLUMN spectra_core.file_type.id IS '主键ID';
COMMENT ON COLUMN spectra_core.file_type.name IS '类型名称';
COMMENT ON COLUMN spectra_core.file_type.extension IS '允许的扩展名(JSON数组)';
COMMENT ON COLUMN spectra_core.file_type.mime IS 'MIME类型(JSON数组)';
COMMENT ON COLUMN spectra_core.file_type.magic_rules IS '文件魔数规则(JSON)';
COMMENT ON COLUMN spectra_core.file_type.max_size IS '最大文件大小(字节)';
COMMENT ON COLUMN spectra_core.file_type.previewable IS '是否可预览';
COMMENT ON COLUMN spectra_core.file_type.allowed_upload IS '是否允许上传';
COMMENT ON COLUMN spectra_core.file_type.dangerous IS '是否危险文件';
COMMENT ON COLUMN spectra_core.file_type.remark IS '备注';
COMMENT ON COLUMN spectra_core.file_type.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.file_type.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.file_type.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.file_type.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.file_type.deleted IS '是否删除';
COMMENT ON COLUMN spectra_core.file_type.version IS '乐观锁';

-- 文件上传任务
CREATE TABLE spectra_core.file_upload_task (
    id               UUID PRIMARY KEY,
    status           VARCHAR(20) NOT NULL,
    total_chunks     INTEGER NOT NULL,
    completed_chunks INTEGER DEFAULT 0,
    created_by       UUID,
    created_at       TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by       UUID,
    updated_at       TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted          TIMESTAMP(6) WITH TIME ZONE,
    version          BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_core.file_upload_task IS '文件上传任务表';
COMMENT ON COLUMN spectra_core.file_upload_task.id IS '主键ID';
COMMENT ON COLUMN spectra_core.file_upload_task.status IS '任务状态';
COMMENT ON COLUMN spectra_core.file_upload_task.total_chunks IS '总分片数';
COMMENT ON COLUMN spectra_core.file_upload_task.completed_chunks IS '已完成分片数';
COMMENT ON COLUMN spectra_core.file_upload_task.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.file_upload_task.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.file_upload_task.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.file_upload_task.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.file_upload_task.deleted IS '是否删除';
COMMENT ON COLUMN spectra_core.file_upload_task.version IS '乐观锁';

-- 文件上传分片
CREATE TABLE spectra_core.file_upload_chunk (
    id          UUID PRIMARY KEY,
    task_id     UUID NOT NULL,
    chunk_index INTEGER NOT NULL,
    chunk_size  BIGINT NOT NULL,
    status      VARCHAR(20) NOT NULL,
    created_by  UUID,
    created_at  TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by  UUID,
    updated_at  TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted     TIMESTAMP(6) WITH TIME ZONE,
    version     BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_core.file_upload_chunk IS '文件上传分片表';
COMMENT ON COLUMN spectra_core.file_upload_chunk.id IS '主键ID';
COMMENT ON COLUMN spectra_core.file_upload_chunk.task_id IS '所属任务ID';
COMMENT ON COLUMN spectra_core.file_upload_chunk.chunk_index IS '分片序号';
COMMENT ON COLUMN spectra_core.file_upload_chunk.chunk_size IS '分片大小(字节)';
COMMENT ON COLUMN spectra_core.file_upload_chunk.status IS '分片状态';
COMMENT ON COLUMN spectra_core.file_upload_chunk.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.file_upload_chunk.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.file_upload_chunk.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.file_upload_chunk.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.file_upload_chunk.deleted IS '是否删除';
COMMENT ON COLUMN spectra_core.file_upload_chunk.version IS '乐观锁';

-- AI 会话和消息记忆统一由 spectra_ai schema 管理，core 不再创建会话表。

-- 消息中心已迁移到 spectra_notification.ntf_*。
-- 旧 sys_notification* 仅在不可变历史迁移和离线数据迁移脚本中出现，
-- 当前 V1 基线不属于 spectra_core 运行库结构。

-- 当前 V1 基线包含完整的表及字段注释。
COMMENT ON TABLE spectra_core.sys_user_department_membership IS '用户与部门成员关系表';
COMMENT ON COLUMN spectra_core.sys_user_department_membership.id IS '主键ID';
COMMENT ON COLUMN spectra_core.sys_user_department_membership.user_id IS '用户ID';
COMMENT ON COLUMN spectra_core.sys_user_department_membership.department_id IS '部门ID';
COMMENT ON COLUMN spectra_core.sys_user_department_membership.membership_type IS '成员关系：PRIMARY-主部门，ASSOCIATED-关联部门';
COMMENT ON COLUMN spectra_core.sys_user_department_membership.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.sys_user_department_membership.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.sys_user_department_membership.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.sys_user_department_membership.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_core.sys_user_department_membership.version IS '乐观锁版本号';

COMMENT ON TABLE spectra_core.sys_department_closure IS '部门层级闭包关系表';
COMMENT ON COLUMN spectra_core.sys_department_closure.id IS '主键ID';
COMMENT ON COLUMN spectra_core.sys_department_closure.ancestor_id IS '祖先部门ID';
COMMENT ON COLUMN spectra_core.sys_department_closure.descendant_id IS '后代部门ID';
COMMENT ON COLUMN spectra_core.sys_department_closure.depth IS '层级深度，0表示部门自身';
COMMENT ON COLUMN spectra_core.sys_department_closure.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.sys_department_closure.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.sys_department_closure.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.sys_department_closure.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.sys_department_closure.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_core.sys_department_closure.version IS '乐观锁版本号';

COMMENT ON TABLE spectra_core.sys_organization_version IS '组织结构版本单例表';
COMMENT ON COLUMN spectra_core.sys_organization_version.id IS '主键ID';
COMMENT ON COLUMN spectra_core.sys_organization_version.singleton_key IS '单例键，固定为 SYSTEM';
COMMENT ON COLUMN spectra_core.sys_organization_version.organization_version IS '组织结构版本号';
COMMENT ON COLUMN spectra_core.sys_organization_version.changed_at IS '最近变更时间';
COMMENT ON COLUMN spectra_core.sys_organization_version.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.sys_organization_version.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.sys_organization_version.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.sys_organization_version.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.sys_organization_version.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_core.sys_organization_version.version IS '乐观锁版本号';

COMMENT ON TABLE spectra_core.sys_system_state IS '系统初始化与系统设置引导状态表；每个状态键只保留一条记录';
COMMENT ON COLUMN spectra_core.sys_system_state.id IS '主键ID';
COMMENT ON COLUMN spectra_core.sys_system_state.state_key IS '状态机键：SYSTEM=首次系统初始化；SYSTEM_GUIDE=系统设置引导';
COMMENT ON COLUMN spectra_core.sys_system_state.state IS '状态值按状态机解释：SYSTEM=UNINITIALIZED/INITIALIZING/INITIALIZED；SYSTEM_GUIDE=PENDING/COMPLETED';
COMMENT ON COLUMN spectra_core.sys_system_state.initialization_id IS '首次系统初始化流程ID，仅 SYSTEM 状态机使用';
COMMENT ON COLUMN spectra_core.sys_system_state.initialized_at IS '首次系统初始化完成时间，仅 SYSTEM 状态机使用';
COMMENT ON COLUMN spectra_core.sys_system_state.initialized_by IS '完成首次系统初始化的用户ID，仅 SYSTEM 状态机使用';
COMMENT ON COLUMN spectra_core.sys_system_state.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.sys_system_state.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.sys_system_state.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.sys_system_state.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.sys_system_state.deleted IS '删除时间（NULL表示未删除）';
COMMENT ON COLUMN spectra_core.sys_system_state.version IS '乐观锁版本号';

-- ============================================
-- 用户批量导入（Flyway V9/V10）
-- ============================================

CREATE TABLE spectra_core.sys_user_import_task (
    id                   UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    operator_id          UUID NOT NULL REFERENCES spectra_core.sys_user (id),
    idempotency_key      VARCHAR(120) NOT NULL,
    file_name            VARCHAR(255) NOT NULL,
    file_hash            VARCHAR(128) NOT NULL,
    skip_existing        BOOLEAN NOT NULL DEFAULT FALSE,
    status               VARCHAR(20) NOT NULL,
    request_hash         VARCHAR(64) NOT NULL,
    profile_version_hash VARCHAR(64) NOT NULL,
    preview_token_hash   VARCHAR(64),
    preview_expires_at   TIMESTAMP(6) WITH TIME ZONE,
    expires_at           TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    total_rows           INTEGER NOT NULL DEFAULT 0,
    valid_rows           INTEGER NOT NULL DEFAULT 0,
    error_rows           INTEGER NOT NULL DEFAULT 0,
    skipped_rows         INTEGER NOT NULL DEFAULT 0,
    applied_rows         INTEGER NOT NULL DEFAULT 0,
    completed_rows       INTEGER NOT NULL DEFAULT 0,
    assignment_count     INTEGER NOT NULL DEFAULT 0,
    access_boundary_count INTEGER NOT NULL DEFAULT 0,
    grant_boundary_count INTEGER NOT NULL DEFAULT 0,
    preview_consumed_at  TIMESTAMP(6) WITH TIME ZONE,
    created_by           UUID,
    created_at           TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by           UUID,
    updated_at           TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted              TIMESTAMP(6) WITH TIME ZONE,
    version              BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT ck_sys_user_import_task_status CHECK (status IN (
        'UPLOADED', 'VALIDATING', 'PREVIEWED', 'APPLYING',
        'SUCCEEDED', 'PARTIAL_FAILED', 'FAILED', 'EXPIRED'
    )),
    CONSTRAINT ck_sys_user_import_task_counts CHECK (
        total_rows >= 0 AND valid_rows >= 0 AND error_rows >= 0
        AND skipped_rows >= 0 AND applied_rows >= 0
        AND completed_rows >= 0
        AND assignment_count >= 0 AND access_boundary_count >= 0 AND grant_boundary_count >= 0
    )
);

CREATE UNIQUE INDEX uk_sys_user_import_task_idempotency
    ON spectra_core.sys_user_import_task (operator_id, idempotency_key)
    WHERE deleted IS NULL;

CREATE INDEX idx_sys_user_import_task_operator_created
    ON spectra_core.sys_user_import_task (operator_id, created_at DESC)
    WHERE deleted IS NULL;

CREATE TABLE spectra_core.sys_user_import_row (
    id               UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    task_id          UUID NOT NULL REFERENCES spectra_core.sys_user_import_task (id) ON DELETE CASCADE,
    row_number       INTEGER NOT NULL,
    row_key          VARCHAR(120) NOT NULL,
    raw_data         JSONB NOT NULL,
    normalized_data  JSONB NOT NULL,
    state            VARCHAR(16) NOT NULL,
    errors           JSONB,
    user_id          UUID REFERENCES spectra_core.sys_user (id),
    created_by       UUID,
    created_at       TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by       UUID,
    updated_at       TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted          TIMESTAMP(6) WITH TIME ZONE,
    version          BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT ck_sys_user_import_row_number CHECK (row_number > 0),
    CONSTRAINT ck_sys_user_import_row_state CHECK (state IN ('VALID', 'ERROR', 'APPLIED', 'SKIPPED'))
);

CREATE UNIQUE INDEX uk_sys_user_import_row_number
    ON spectra_core.sys_user_import_row (task_id, row_number)
    WHERE deleted IS NULL;

CREATE INDEX idx_sys_user_import_row_task_state
    ON spectra_core.sys_user_import_row (task_id, state, row_number)
    WHERE deleted IS NULL;

COMMENT ON TABLE spectra_core.sys_user_import_task IS '用户批量导入 Preview/Apply 任务';
COMMENT ON TABLE spectra_core.sys_user_import_row IS '用户批量导入暂存行及校验结果';
COMMENT ON COLUMN spectra_core.sys_user_import_task.file_hash IS '上传文件摘要，不保存文件内容';
COMMENT ON COLUMN spectra_core.sys_user_import_task.request_hash IS '规范化导入请求摘要，防止 Preview/Apply 参数漂移';
COMMENT ON COLUMN spectra_core.sys_user_import_task.profile_version_hash IS '导入引用授权方案版本摘要';
COMMENT ON COLUMN spectra_core.sys_user_import_task.completed_rows IS 'Apply 阶段已处理行数，包含预览阶段已发现的错误行';
COMMENT ON COLUMN spectra_core.sys_user_import_row.raw_data IS '固定模板原始字段；接口错误响应不回传';
COMMENT ON COLUMN spectra_core.sys_user_import_row.normalized_data IS '校验后的结构化字段；接口错误响应不回传';

-- 单体服务监控历史采样（Flyway V19/V20）
CREATE TABLE spectra_core.sys_service_monitor_sample (
    id                          UUID DEFAULT uuidv7() PRIMARY KEY,
    collected_at                TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    cpu_usage                   DOUBLE PRECISION NOT NULL DEFAULT 0,
    cpu_logical_cores           INTEGER NOT NULL DEFAULT 0,
    system_memory_usage         DOUBLE PRECISION NOT NULL DEFAULT 0,
    system_memory_total_bytes  BIGINT NOT NULL DEFAULT 0,
    system_memory_used_bytes   BIGINT NOT NULL DEFAULT 0,
    system_memory_available_bytes BIGINT NOT NULL DEFAULT 0,
    jvm_heap_usage              DOUBLE PRECISION NOT NULL DEFAULT 0,
    jvm_heap_used_bytes         BIGINT NOT NULL DEFAULT 0,
    jvm_heap_max_bytes          BIGINT NOT NULL DEFAULT 0,
    jvm_non_heap_used_bytes     BIGINT NOT NULL DEFAULT 0,
    live_thread_count            INTEGER NOT NULL DEFAULT 0,
    peak_thread_count            INTEGER NOT NULL DEFAULT 0,
    gc_count                    BIGINT NOT NULL DEFAULT 0,
    qps                         DOUBLE PRECISION NOT NULL DEFAULT 0,
    error_rate                  DOUBLE PRECISION NOT NULL DEFAULT 0,
    p95_response_ms             DOUBLE PRECISION NOT NULL DEFAULT 0,
    request_metrics_available   BOOLEAN NOT NULL DEFAULT FALSE,
    status                      VARCHAR(16) NOT NULL DEFAULT 'DOWN',
    created_by                  UUID,
    created_at                  TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by                  UUID,
    updated_at                  TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted                     TIMESTAMP(6) WITH TIME ZONE,
    version                     BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT ck_sys_service_monitor_sample_status CHECK (status IN ('HEALTHY', 'WARNING', 'DEGRADED', 'DOWN')),
    CONSTRAINT ck_sys_service_monitor_sample_values CHECK (
        cpu_usage >= 0 AND cpu_usage <= 100
        AND system_memory_usage >= 0 AND system_memory_usage <= 100
        AND jvm_heap_usage >= 0 AND jvm_heap_usage <= 100
        AND cpu_logical_cores >= 0
        AND system_memory_total_bytes >= 0
        AND system_memory_used_bytes >= 0
        AND system_memory_available_bytes >= 0
        AND jvm_heap_used_bytes >= 0
        AND jvm_heap_max_bytes >= 0
        AND jvm_non_heap_used_bytes >= 0
        AND live_thread_count >= 0
        AND peak_thread_count >= 0
        AND gc_count >= 0
        AND qps >= 0
        AND error_rate >= 0
        AND p95_response_ms >= 0
    )
);

CREATE INDEX idx_sys_service_monitor_sample_collected_at
    ON spectra_core.sys_service_monitor_sample (collected_at DESC);

COMMENT ON TABLE spectra_core.sys_service_monitor_sample IS '单体服务监控历史采样表';
COMMENT ON COLUMN spectra_core.sys_service_monitor_sample.id IS '主键ID';
COMMENT ON COLUMN spectra_core.sys_service_monitor_sample.collected_at IS '监控采集时间';
COMMENT ON COLUMN spectra_core.sys_service_monitor_sample.cpu_usage IS 'CPU 使用率（百分比）';
COMMENT ON COLUMN spectra_core.sys_service_monitor_sample.cpu_logical_cores IS 'CPU 逻辑核心数';
COMMENT ON COLUMN spectra_core.sys_service_monitor_sample.system_memory_usage IS '系统内存使用率（百分比）';
COMMENT ON COLUMN spectra_core.sys_service_monitor_sample.system_memory_total_bytes IS '系统内存总量（字节）';
COMMENT ON COLUMN spectra_core.sys_service_monitor_sample.system_memory_used_bytes IS '系统已使用内存（字节）';
COMMENT ON COLUMN spectra_core.sys_service_monitor_sample.system_memory_available_bytes IS '系统可用内存（字节）';
COMMENT ON COLUMN spectra_core.sys_service_monitor_sample.jvm_heap_usage IS 'JVM 堆内存使用率（百分比）';
COMMENT ON COLUMN spectra_core.sys_service_monitor_sample.jvm_heap_used_bytes IS 'JVM 已使用堆内存（字节）';
COMMENT ON COLUMN spectra_core.sys_service_monitor_sample.jvm_heap_max_bytes IS 'JVM 堆内存上限（字节）';
COMMENT ON COLUMN spectra_core.sys_service_monitor_sample.jvm_non_heap_used_bytes IS 'JVM 已使用非堆内存（字节）';
COMMENT ON COLUMN spectra_core.sys_service_monitor_sample.live_thread_count IS '当前活动线程数';
COMMENT ON COLUMN spectra_core.sys_service_monitor_sample.peak_thread_count IS '线程峰值数量';
COMMENT ON COLUMN spectra_core.sys_service_monitor_sample.gc_count IS '垃圾回收次数';
COMMENT ON COLUMN spectra_core.sys_service_monitor_sample.qps IS '最近采样周期的请求速率（QPS）';
COMMENT ON COLUMN spectra_core.sys_service_monitor_sample.error_rate IS '最近采样周期的 HTTP 5xx 错误率（百分比）';
COMMENT ON COLUMN spectra_core.sys_service_monitor_sample.p95_response_ms IS '最近采样周期的请求响应时间 P95（毫秒）';
COMMENT ON COLUMN spectra_core.sys_service_monitor_sample.request_metrics_available IS '是否采集到 HTTP 请求指标';
COMMENT ON COLUMN spectra_core.sys_service_monitor_sample.status IS '采样时的服务状态：HEALTHY-健康，WARNING-警告，DEGRADED-降级，DOWN-不可用';
COMMENT ON COLUMN spectra_core.sys_service_monitor_sample.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.sys_service_monitor_sample.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.sys_service_monitor_sample.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.sys_service_monitor_sample.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.sys_service_monitor_sample.deleted IS '删除时间';
COMMENT ON COLUMN spectra_core.sys_service_monitor_sample.version IS '乐观锁版本';
-- 第三阶段服务监控增量结构（与 spectra-config V21 一致）。
ALTER TABLE spectra_core.sys_service_monitor_sample
    ADD COLUMN IF NOT EXISTS database_status VARCHAR(16) NOT NULL DEFAULT 'UNKNOWN',
    ADD COLUMN IF NOT EXISTS redis_status VARCHAR(16) NOT NULL DEFAULT 'UNKNOWN';

CREATE TABLE IF NOT EXISTS spectra_core.sys_service_monitor_alert_rule (
    id UUID DEFAULT uuidv7() PRIMARY KEY,
    code VARCHAR(80) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    metric_code VARCHAR(80) NOT NULL,
    operator_code VARCHAR(16) NOT NULL DEFAULT 'GTE',
    threshold_value DOUBLE PRECISION,
    expected_value VARCHAR(80),
    severity VARCHAR(16) NOT NULL DEFAULT 'WARNING',
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    consecutive_failures INTEGER NOT NULL DEFAULT 1,
    cooldown_seconds INTEGER NOT NULL DEFAULT 300,
    remark VARCHAR(500),
    created_by UUID,
    created_at TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by UUID,
    updated_at TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted TIMESTAMP(6) WITH TIME ZONE,
    version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT ck_sys_service_monitor_alert_rule_operator CHECK (operator_code IN ('GTE', 'GT', 'LTE', 'LT', 'EQ', 'NE')),
    CONSTRAINT ck_sys_service_monitor_alert_rule_severity CHECK (severity IN ('WARNING', 'CRITICAL')),
    CONSTRAINT ck_sys_service_monitor_alert_rule_values CHECK (consecutive_failures BETWEEN 1 AND 10 AND cooldown_seconds BETWEEN 0 AND 86400)
);

COMMENT ON TABLE spectra_core.sys_service_monitor_alert_rule IS '单体服务监控告警规则表';
COMMENT ON COLUMN spectra_core.sys_service_monitor_alert_rule.code IS '稳定规则编码';
COMMENT ON COLUMN spectra_core.sys_service_monitor_alert_rule.metric_code IS '监控指标编码';
COMMENT ON COLUMN spectra_core.sys_service_monitor_alert_rule.operator_code IS '比较运算符';
COMMENT ON COLUMN spectra_core.sys_service_monitor_alert_rule.threshold_value IS '数值指标阈值';
COMMENT ON COLUMN spectra_core.sys_service_monitor_alert_rule.expected_value IS '状态指标期望值';
COMMENT ON COLUMN spectra_core.sys_service_monitor_alert_rule.severity IS '告警级别：WARNING/CRITICAL';
COMMENT ON COLUMN spectra_core.sys_service_monitor_alert_rule.enabled IS '是否启用';
COMMENT ON COLUMN spectra_core.sys_service_monitor_alert_rule.consecutive_failures IS '连续触发次数';
COMMENT ON COLUMN spectra_core.sys_service_monitor_alert_rule.cooldown_seconds IS '通知冷却时间（秒）';

CREATE TABLE IF NOT EXISTS spectra_core.sys_service_monitor_alert_event (
    id UUID DEFAULT uuidv7() PRIMARY KEY,
    rule_id UUID NOT NULL,
    rule_code VARCHAR(80) NOT NULL,
    rule_name VARCHAR(100) NOT NULL,
    metric_code VARCHAR(80) NOT NULL,
    severity VARCHAR(16) NOT NULL,
    state VARCHAR(16) NOT NULL DEFAULT 'ACTIVE',
    current_value VARCHAR(120),
    threshold_value DOUBLE PRECISION,
    expected_value VARCHAR(80),
    message VARCHAR(500) NOT NULL,
    first_occurred_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    last_occurred_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    recovered_at TIMESTAMP(6) WITH TIME ZONE,
    occurrence_count INTEGER NOT NULL DEFAULT 1,
    last_notified_at TIMESTAMP(6) WITH TIME ZONE,
    created_by UUID,
    created_at TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by UUID,
    updated_at TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted TIMESTAMP(6) WITH TIME ZONE,
    version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT ck_sys_service_monitor_alert_event_severity CHECK (severity IN ('WARNING', 'CRITICAL')),
    CONSTRAINT ck_sys_service_monitor_alert_event_state CHECK (state IN ('ACTIVE', 'RECOVERED')),
    CONSTRAINT ck_sys_service_monitor_alert_event_occurrence CHECK (occurrence_count >= 1)
);

COMMENT ON TABLE spectra_core.sys_service_monitor_alert_event IS '单体服务监控告警事件表';
COMMENT ON COLUMN spectra_core.sys_service_monitor_alert_event.rule_id IS '告警规则ID';
COMMENT ON COLUMN spectra_core.sys_service_monitor_alert_event.state IS '事件状态：ACTIVE/RECOVERED';
COMMENT ON COLUMN spectra_core.sys_service_monitor_alert_event.message IS '脱敏告警说明';
COMMENT ON COLUMN spectra_core.sys_service_monitor_alert_event.last_notified_at IS '最近通知时间';
CREATE UNIQUE INDEX IF NOT EXISTS uk_sys_service_monitor_alert_event_active_rule
    ON spectra_core.sys_service_monitor_alert_event (rule_id) WHERE state = 'ACTIVE' AND deleted IS NULL;
CREATE INDEX IF NOT EXISTS idx_sys_service_monitor_alert_event_state_time
    ON spectra_core.sys_service_monitor_alert_event (state, last_occurred_at DESC);

CREATE TABLE IF NOT EXISTS spectra_core.sys_service_monitor_diagnostic_task (
    id UUID DEFAULT uuidv7() PRIMARY KEY,
    task_type VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    file_name VARCHAR(120),
    display_name VARCHAR(200),
    file_size BIGINT,
    error_message VARCHAR(300),
    requested_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    started_at TIMESTAMP(6) WITH TIME ZONE,
    completed_at TIMESTAMP(6) WITH TIME ZONE,
    expires_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    created_by UUID,
    created_at TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by UUID,
    updated_at TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    deleted TIMESTAMP(6) WITH TIME ZONE,
    version BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT ck_sys_service_monitor_diagnostic_task_type CHECK (task_type IN ('THREAD_DUMP', 'HEAP_DUMP')),
    CONSTRAINT ck_sys_service_monitor_diagnostic_task_status CHECK (status IN ('PENDING', 'RUNNING', 'SUCCEEDED', 'FAILED', 'EXPIRED')),
    CONSTRAINT ck_sys_service_monitor_diagnostic_task_size CHECK (file_size IS NULL OR file_size >= 0)
);

COMMENT ON TABLE spectra_core.sys_service_monitor_diagnostic_task IS '单体服务监控诊断任务表';
COMMENT ON COLUMN spectra_core.sys_service_monitor_diagnostic_task.task_type IS '诊断类型：THREAD_DUMP/HEAP_DUMP';
COMMENT ON COLUMN spectra_core.sys_service_monitor_diagnostic_task.status IS '任务状态';
COMMENT ON COLUMN spectra_core.sys_service_monitor_diagnostic_task.file_name IS '系统生成的相对文件名';
COMMENT ON COLUMN spectra_core.sys_service_monitor_diagnostic_task.error_message IS '脱敏失败原因';
COMMENT ON COLUMN spectra_core.sys_service_monitor_diagnostic_task.expires_at IS '文件过期时间';
CREATE INDEX IF NOT EXISTS idx_sys_service_monitor_diagnostic_task_status_time
    ON spectra_core.sys_service_monitor_diagnostic_task (status, requested_at DESC);
CREATE INDEX IF NOT EXISTS idx_sys_service_monitor_diagnostic_task_expires_at
    ON spectra_core.sys_service_monitor_diagnostic_task (expires_at);

INSERT INTO spectra_security.sec_permission
    (id, code, name, resource_code, action_code, allowed_scope_modes, state, system_managed,
     created_by, created_at, updated_by, updated_at, deleted, version)
SELECT uuidv7(), permission.code, permission.name, 'system:monitor', permission.action, 'NONE', 'ACTIVE', TRUE,
       '00000000-0000-0000-0000-000000000000', CURRENT_TIMESTAMP,
       '00000000-0000-0000-0000-000000000000', CURRENT_TIMESTAMP, NULL, 0
FROM (VALUES
    ('system:monitor:alert', '服务监控告警查看', 'alert'),
    ('system:monitor:configure', '服务监控告警配置', 'configure'),
    ('system:monitor:diagnose', '服务监控诊断', 'diagnose')
) AS permission(code, name, action)
WHERE NOT EXISTS (
    SELECT 1 FROM spectra_security.sec_permission existing WHERE existing.code = permission.code
);

INSERT INTO spectra_core.sys_service_monitor_alert_rule
    (code, name, metric_code, operator_code, threshold_value, expected_value, severity, enabled,
     consecutive_failures, cooldown_seconds, remark)
SELECT rule.code, rule.name, rule.metric_code, rule.operator_code, rule.threshold_value, rule.expected_value,
       rule.severity, TRUE, 1, 300, rule.remark
FROM (VALUES
    ('CPU_USAGE', 'CPU 使用率过高', 'CPU_USAGE', 'GTE', 80::DOUBLE PRECISION, NULL::VARCHAR, 'WARNING', '超过阈值时通知运维管理员'),
    ('SYSTEM_MEMORY_USAGE', '系统内存使用率过高', 'SYSTEM_MEMORY_USAGE', 'GTE', 80::DOUBLE PRECISION, NULL::VARCHAR, 'WARNING', '超过阈值时通知运维管理员'),
    ('JVM_HEAP_USAGE', 'JVM 堆内存使用率过高', 'JVM_HEAP_USAGE', 'GTE', 75::DOUBLE PRECISION, NULL::VARCHAR, 'WARNING', '超过阈值时通知运维管理员'),
    ('ERROR_RATE', 'HTTP 5xx 错误率过高', 'ERROR_RATE', 'GTE', 1::DOUBLE PRECISION, NULL::VARCHAR, 'CRITICAL', '有请求指标时生效'),
    ('P95_RESPONSE_MS', '请求响应时间过长', 'P95_RESPONSE_MS', 'GTE', 500::DOUBLE PRECISION, NULL::VARCHAR, 'WARNING', '有请求指标时生效'),
    ('DATABASE_STATUS', 'PostgreSQL 不可用', 'DATABASE_STATUS', 'NE', NULL::DOUBLE PRECISION, 'UP', 'CRITICAL', '数据库连通性检查异常时通知运维管理员'),
    ('REDIS_STATUS', 'Redis 不可用', 'REDIS_STATUS', 'NE', NULL::DOUBLE PRECISION, 'UP', 'CRITICAL', 'Redis 连通性检查异常时通知运维管理员')
) AS rule(code, name, metric_code, operator_code, threshold_value, expected_value, severity, remark)
WHERE NOT EXISTS (
    SELECT 1 FROM spectra_core.sys_service_monitor_alert_rule existing WHERE existing.code = rule.code
);
