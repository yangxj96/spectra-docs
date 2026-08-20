-- ============================================
-- spectra_core schema 建表语句
-- 共 16 张表（不含 BaseEntity；旧认证/授权运行时表已不属于当前目标模型）
-- 当前物理字段顺序、种子审计元数据和完整注释由 Flyway V1 干净基线固化。
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
    username       VARCHAR(100) NOT NULL,
    avatar         VARCHAR(255),
    status         VARCHAR(16) NOT NULL DEFAULT 'ACTIVE',
    status_reason  VARCHAR(500),
    locked_until   TIMESTAMP(6) WITH TIME ZONE,
    departed_at    TIMESTAMP(6) WITH TIME ZONE,
    real_name      VARCHAR(50),
    gender         SMALLINT DEFAULT 0,
    birthday       TIMESTAMP(6) WITH TIME ZONE,
    phone          VARCHAR(20),
    email          VARCHAR(100),
    country        VARCHAR(50),
    city           VARCHAR(50),
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
COMMENT ON COLUMN spectra_core.sys_user.username IS '显示名称';
COMMENT ON COLUMN spectra_core.sys_user.avatar IS '头像';
COMMENT ON COLUMN spectra_core.sys_user.status IS '状态 (1:正常 0:禁用)';
COMMENT ON COLUMN spectra_core.sys_user.status_reason IS '状态变更原因';
COMMENT ON COLUMN spectra_core.sys_user.locked_until IS '账号锁定截止时间';
COMMENT ON COLUMN spectra_core.sys_user.departed_at IS '离职时间';
COMMENT ON COLUMN spectra_core.sys_user.real_name IS '真实姓名';
COMMENT ON COLUMN spectra_core.sys_user.gender IS '性别(从字典中获取)';
COMMENT ON COLUMN spectra_core.sys_user.birthday IS '生日';
COMMENT ON COLUMN spectra_core.sys_user.phone IS '手机号';
COMMENT ON COLUMN spectra_core.sys_user.email IS '邮箱';
COMMENT ON COLUMN spectra_core.sys_user.country IS '国家';
COMMENT ON COLUMN spectra_core.sys_user.city IS '城市';
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
