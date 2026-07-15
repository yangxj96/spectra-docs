-- ============================================
-- spectra_core schema 建表语句
-- 共 34 张表（不含 BaseEntity）
-- ============================================

CREATE SCHEMA IF NOT EXISTS spectra_core;

-- ============================================
-- 认证
-- ============================================

-- 账号表
CREATE TABLE spectra_core.sys_account (
    id           UUID PRIMARY KEY,
    user_id      UUID NOT NULL,
    type         INTEGER NOT NULL,
    login_name   VARCHAR(100),
    password     VARCHAR(255),
    phone        VARCHAR(20),
    email        VARCHAR(100),
    openid       VARCHAR(100),
    unionid      VARCHAR(100),
    provider     VARCHAR(50),
    status       SMALLINT NOT NULL DEFAULT 1,
    verified     SMALLINT DEFAULT 0,
    expires_at   TIMESTAMP(6) WITH TIME ZONE,
    created_by   UUID,
    created_at   TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by   UUID,
    updated_at   TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted      TIMESTAMP(6) WITH TIME ZONE,
    version      BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_core.sys_account IS '账号表';
COMMENT ON COLUMN spectra_core.sys_account.id IS '主键ID';
COMMENT ON COLUMN spectra_core.sys_account.user_id IS '用户ID';
COMMENT ON COLUMN spectra_core.sys_account.type IS '账号类型';
COMMENT ON COLUMN spectra_core.sys_account.login_name IS '用户名（用于账号密码登录）';
COMMENT ON COLUMN spectra_core.sys_account.password IS '密码(仅用作账号密码登录)';
COMMENT ON COLUMN spectra_core.sys_account.phone IS '手机号（用于短信登录）';
COMMENT ON COLUMN spectra_core.sys_account.email IS '邮箱（用于邮箱验证码登录）';
COMMENT ON COLUMN spectra_core.sys_account.openid IS '微信 openid';
COMMENT ON COLUMN spectra_core.sys_account.unionid IS '微信 unionid（跨应用唯一）';
COMMENT ON COLUMN spectra_core.sys_account.provider IS '第三方来源：WECHAT, ALIPAY, APPLE 等';
COMMENT ON COLUMN spectra_core.sys_account.status IS '1:正常 2:禁用 3:未验证';
COMMENT ON COLUMN spectra_core.sys_account.verified IS '0:未验证 1:已验证';
COMMENT ON COLUMN spectra_core.sys_account.expires_at IS '用于临时账号（如扫码未确认）';
COMMENT ON COLUMN spectra_core.sys_account.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.sys_account.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.sys_account.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.sys_account.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.sys_account.deleted IS '删除标识';
COMMENT ON COLUMN spectra_core.sys_account.version IS '乐观锁';

-- ============================================
-- 用户权限
-- ============================================

-- 用户表
CREATE TABLE spectra_core.sys_user (
    id             UUID PRIMARY KEY,
    username       VARCHAR(100) NOT NULL,
    avatar         VARCHAR(255),
    status         SMALLINT NOT NULL DEFAULT 1,
    real_name      VARCHAR(50),
    gender         SMALLINT DEFAULT 0,
    birthday       DATE,
    phone          VARCHAR(20),
    email          VARCHAR(100),
    country        VARCHAR(50),
    city           VARCHAR(50),
    language       VARCHAR(10) DEFAULT 'zh-CN',
    timezone       VARCHAR(40) DEFAULT 'Asia/Shanghai',
    department_id  UUID NOT NULL,
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
COMMENT ON COLUMN spectra_core.sys_user.real_name IS '真实姓名';
COMMENT ON COLUMN spectra_core.sys_user.gender IS '性别(从字典中获取)';
COMMENT ON COLUMN spectra_core.sys_user.birthday IS '生日';
COMMENT ON COLUMN spectra_core.sys_user.phone IS '手机号';
COMMENT ON COLUMN spectra_core.sys_user.email IS '邮箱';
COMMENT ON COLUMN spectra_core.sys_user.country IS '国家';
COMMENT ON COLUMN spectra_core.sys_user.city IS '城市';
COMMENT ON COLUMN spectra_core.sys_user.language IS '语言';
COMMENT ON COLUMN spectra_core.sys_user.timezone IS '时区';
COMMENT ON COLUMN spectra_core.sys_user.department_id IS '组织机构ID';
COMMENT ON COLUMN spectra_core.sys_user.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.sys_user.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.sys_user.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.sys_user.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.sys_user.deleted IS '删除时间';
COMMENT ON COLUMN spectra_core.sys_user.version IS '乐观锁';

-- 角色表
CREATE TABLE spectra_core.sys_role (
    id         UUID PRIMARY KEY,
    name       VARCHAR(100),
    code       VARCHAR(100),
    state      BOOLEAN DEFAULT TRUE,
    scope      INTEGER,
    builtin    BOOLEAN DEFAULT FALSE,
    remark     TEXT,
    created_by UUID,
    created_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by UUID,
    updated_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted    TIMESTAMP(6) WITH TIME ZONE,
    version    BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_core.sys_role IS '角色表';
COMMENT ON COLUMN spectra_core.sys_role.id IS '主键ID';
COMMENT ON COLUMN spectra_core.sys_role.name IS '名称';
COMMENT ON COLUMN spectra_core.sys_role.code IS '编码';
COMMENT ON COLUMN spectra_core.sys_role.state IS '状态';
COMMENT ON COLUMN spectra_core.sys_role.scope IS '范围';
COMMENT ON COLUMN spectra_core.sys_role.builtin IS '是否内置';
COMMENT ON COLUMN spectra_core.sys_role.remark IS '备注';
COMMENT ON COLUMN spectra_core.sys_role.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.sys_role.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.sys_role.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.sys_role.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.sys_role.deleted IS '是否删除';
COMMENT ON COLUMN spectra_core.sys_role.version IS '乐观锁';

-- 权限表
CREATE TABLE spectra_core.sys_authority (
    id         UUID PRIMARY KEY,
    pid        UUID,
    name       VARCHAR(100) NOT NULL,
    code       VARCHAR(100) NOT NULL,
    created_by UUID,
    created_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by UUID,
    updated_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted    TIMESTAMP(6) WITH TIME ZONE,
    version    BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_core.sys_authority IS '权限表';
COMMENT ON COLUMN spectra_core.sys_authority.id IS '主键ID';
COMMENT ON COLUMN spectra_core.sys_authority.pid IS '父级ID,用于构建树形结构';
COMMENT ON COLUMN spectra_core.sys_authority.name IS '权限名称';
COMMENT ON COLUMN spectra_core.sys_authority.code IS '权限编码';
COMMENT ON COLUMN spectra_core.sys_authority.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.sys_authority.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.sys_authority.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.sys_authority.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.sys_authority.deleted IS '是否删除';
COMMENT ON COLUMN spectra_core.sys_authority.version IS '乐观锁';

-- 用户-角色关联
CREATE TABLE spectra_core.sys_rel_user_role (
    id         UUID PRIMARY KEY,
    user_id    UUID NOT NULL,
    role_id    UUID NOT NULL,
    created_by UUID,
    created_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by UUID,
    updated_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted    TIMESTAMP(6) WITH TIME ZONE,
    version    BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_core.sys_rel_user_role IS '用户-角色关联表';
COMMENT ON COLUMN spectra_core.sys_rel_user_role.id IS '主键ID';
COMMENT ON COLUMN spectra_core.sys_rel_user_role.user_id IS '用户ID';
COMMENT ON COLUMN spectra_core.sys_rel_user_role.role_id IS '角色ID';
COMMENT ON COLUMN spectra_core.sys_rel_user_role.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.sys_rel_user_role.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.sys_rel_user_role.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.sys_rel_user_role.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.sys_rel_user_role.deleted IS '是否删除';
COMMENT ON COLUMN spectra_core.sys_rel_user_role.version IS '乐观锁';

-- 角色-权限关联
CREATE TABLE spectra_core.sys_rel_role_authority (
    id            UUID PRIMARY KEY,
    role_id       UUID NOT NULL,
    authority_id  UUID NOT NULL,
    created_by    UUID,
    created_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by    UUID,
    updated_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted       TIMESTAMP(6) WITH TIME ZONE,
    version       BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_core.sys_rel_role_authority IS '角色-权限关联表';
COMMENT ON COLUMN spectra_core.sys_rel_role_authority.id IS '主键ID';
COMMENT ON COLUMN spectra_core.sys_rel_role_authority.role_id IS '角色ID';
COMMENT ON COLUMN spectra_core.sys_rel_role_authority.authority_id IS '权限ID';
COMMENT ON COLUMN spectra_core.sys_rel_role_authority.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.sys_rel_role_authority.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.sys_rel_role_authority.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.sys_rel_role_authority.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.sys_rel_role_authority.deleted IS '是否删除';
COMMENT ON COLUMN spectra_core.sys_rel_role_authority.version IS '乐观锁';

-- 角色-菜单关联
CREATE TABLE spectra_core.sys_rel_role_menu (
    id         UUID PRIMARY KEY,
    role_id    UUID NOT NULL,
    menu_id    UUID NOT NULL,
    created_by UUID,
    created_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by UUID,
    updated_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted    TIMESTAMP(6) WITH TIME ZONE,
    version    BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_core.sys_rel_role_menu IS '角色-菜单关联表';
COMMENT ON COLUMN spectra_core.sys_rel_role_menu.id IS '主键ID';
COMMENT ON COLUMN spectra_core.sys_rel_role_menu.role_id IS '角色ID';
COMMENT ON COLUMN spectra_core.sys_rel_role_menu.menu_id IS '菜单ID';
COMMENT ON COLUMN spectra_core.sys_rel_role_menu.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.sys_rel_role_menu.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.sys_rel_role_menu.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.sys_rel_role_menu.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.sys_rel_role_menu.deleted IS '是否删除';
COMMENT ON COLUMN spectra_core.sys_rel_role_menu.version IS '乐观锁';

-- 角色数据权限范围
CREATE TABLE spectra_core.sys_role_data_scope (
    id         UUID PRIMARY KEY,
    role_id    UUID NOT NULL,
    scope      INTEGER,
    created_by UUID,
    created_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by UUID,
    updated_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted    TIMESTAMP(6) WITH TIME ZONE,
    version    BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_core.sys_role_data_scope IS '角色数据权限范围';
COMMENT ON COLUMN spectra_core.sys_role_data_scope.id IS '主键ID';
COMMENT ON COLUMN spectra_core.sys_role_data_scope.role_id IS '角色ID';
COMMENT ON COLUMN spectra_core.sys_role_data_scope.scope IS '数据权限范围';
COMMENT ON COLUMN spectra_core.sys_role_data_scope.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.sys_role_data_scope.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.sys_role_data_scope.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.sys_role_data_scope.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.sys_role_data_scope.deleted IS '是否删除';
COMMENT ON COLUMN spectra_core.sys_role_data_scope.version IS '乐观锁';

-- 角色数据权限目标
CREATE TABLE spectra_core.sys_role_data_scope_target (
    id         UUID PRIMARY KEY,
    scope_id   UUID NOT NULL,
    target_id  UUID NOT NULL,
    created_by UUID,
    created_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by UUID,
    updated_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted    TIMESTAMP(6) WITH TIME ZONE,
    version    BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_core.sys_role_data_scope_target IS '角色数据权限目标';
COMMENT ON COLUMN spectra_core.sys_role_data_scope_target.id IS '主键ID';
COMMENT ON COLUMN spectra_core.sys_role_data_scope_target.scope_id IS '权限范围ID';
COMMENT ON COLUMN spectra_core.sys_role_data_scope_target.target_id IS '目标ID';
COMMENT ON COLUMN spectra_core.sys_role_data_scope_target.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.sys_role_data_scope_target.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.sys_role_data_scope_target.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.sys_role_data_scope_target.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.sys_role_data_scope_target.deleted IS '是否删除';
COMMENT ON COLUMN spectra_core.sys_role_data_scope_target.version IS '乐观锁';

-- 用户数据权限范围
CREATE TABLE spectra_core.sys_user_data_scope (
    id         UUID PRIMARY KEY,
    user_id    UUID NOT NULL,
    scope      INTEGER,
    created_by UUID,
    created_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by UUID,
    updated_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted    TIMESTAMP(6) WITH TIME ZONE,
    version    BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_core.sys_user_data_scope IS '用户数据权限范围';
COMMENT ON COLUMN spectra_core.sys_user_data_scope.id IS '主键ID';
COMMENT ON COLUMN spectra_core.sys_user_data_scope.user_id IS '用户ID';
COMMENT ON COLUMN spectra_core.sys_user_data_scope.scope IS '数据权限范围';
COMMENT ON COLUMN spectra_core.sys_user_data_scope.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.sys_user_data_scope.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.sys_user_data_scope.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.sys_user_data_scope.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.sys_user_data_scope.deleted IS '是否删除';
COMMENT ON COLUMN spectra_core.sys_user_data_scope.version IS '乐观锁';

-- 用户数据权限目标
CREATE TABLE spectra_core.sys_user_data_scope_target (
    id         UUID PRIMARY KEY,
    scope_id   UUID NOT NULL,
    target_id  UUID NOT NULL,
    created_by UUID,
    created_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by UUID,
    updated_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted    TIMESTAMP(6) WITH TIME ZONE,
    version    BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_core.sys_user_data_scope_target IS '用户数据权限目标';
COMMENT ON COLUMN spectra_core.sys_user_data_scope_target.id IS '主键ID';
COMMENT ON COLUMN spectra_core.sys_user_data_scope_target.scope_id IS '权限范围ID';
COMMENT ON COLUMN spectra_core.sys_user_data_scope_target.target_id IS '目标ID';
COMMENT ON COLUMN spectra_core.sys_user_data_scope_target.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.sys_user_data_scope_target.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.sys_user_data_scope_target.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.sys_user_data_scope_target.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.sys_user_data_scope_target.deleted IS '是否删除';
COMMENT ON COLUMN spectra_core.sys_user_data_scope_target.version IS '乐观锁';

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
    created_by UUID,
    created_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by UUID,
    updated_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted    TIMESTAMP(6) WITH TIME ZONE,
    version    BIGINT DEFAULT 0,
    region_id  UUID,
    sort       INTEGER DEFAULT 0
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

-- 菜单表
CREATE TABLE spectra_core.sys_menu (
    id         UUID PRIMARY KEY,
    name       VARCHAR(100) NOT NULL,
    pid        UUID,
    icon       VARCHAR(100),
    path       VARCHAR(255) NOT NULL,
    component  VARCHAR(100) NOT NULL,
    layout     VARCHAR(100),
    sort       INTEGER DEFAULT 0,
    hide       BOOLEAN DEFAULT FALSE,
    metadata   JSONB DEFAULT '{}'::jsonb,
    created_by UUID,
    created_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by UUID,
    updated_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted    TIMESTAMP(6) WITH TIME ZONE,
    version    BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_core.sys_menu IS '菜单表';
COMMENT ON COLUMN spectra_core.sys_menu.id IS '主键ID';
COMMENT ON COLUMN spectra_core.sys_menu.name IS '名称';
COMMENT ON COLUMN spectra_core.sys_menu.pid IS '父级ID';
COMMENT ON COLUMN spectra_core.sys_menu.icon IS '图标';
COMMENT ON COLUMN spectra_core.sys_menu.path IS '请求路径';
COMMENT ON COLUMN spectra_core.sys_menu.component IS '组件路径,为空则使用布局组件';
COMMENT ON COLUMN spectra_core.sys_menu.layout IS '布局';
COMMENT ON COLUMN spectra_core.sys_menu.sort IS '排序';
COMMENT ON COLUMN spectra_core.sys_menu.hide IS '是否显示再菜单(默认不显示)';
COMMENT ON COLUMN spectra_core.sys_menu.metadata IS '元数据';
COMMENT ON COLUMN spectra_core.sys_menu.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.sys_menu.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.sys_menu.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.sys_menu.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.sys_menu.deleted IS '是否删除';
COMMENT ON COLUMN spectra_core.sys_menu.version IS '乐观锁';

-- 区域表
CREATE TABLE spectra_core.sys_region (
    id         UUID PRIMARY KEY,
    pid        UUID,
    name       VARCHAR(100),
    code       VARCHAR(100),
    level      VARCHAR(50),
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

-- 字典组
CREATE TABLE spectra_core.sys_dict_group (
    id         UUID PRIMARY KEY,
    name       VARCHAR(100),
    code       VARCHAR(100),
    created_by UUID,
    created_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by UUID,
    updated_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted    TIMESTAMP(6) WITH TIME ZONE,
    version    BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_core.sys_dict_group IS '字典组';
COMMENT ON COLUMN spectra_core.sys_dict_group.id IS '主键ID';
COMMENT ON COLUMN spectra_core.sys_dict_group.name IS '字典组名称';
COMMENT ON COLUMN spectra_core.sys_dict_group.code IS '字典组编码';
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
    created_by   UUID,
    created_at   TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by   UUID,
    updated_at   TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted      TIMESTAMP(6) WITH TIME ZONE,
    version      BIGINT DEFAULT 0,
    default_flag BOOLEAN DEFAULT FALSE
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
    id         UUID PRIMARY KEY,
    user_id    UUID,
    module     VARCHAR(100),
    action     VARCHAR(100),
    target     VARCHAR(255),
    ip         VARCHAR(50),
    user_agent VARCHAR(500),
    request_params TEXT,
    response_result TEXT,
    duration   BIGINT,
    created_by UUID,
    created_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by UUID,
    updated_at TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted    TIMESTAMP(6) WITH TIME ZONE,
    version    BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_core.sys_log IS '操作日志表';
COMMENT ON COLUMN spectra_core.sys_log.id IS '主键ID';
COMMENT ON COLUMN spectra_core.sys_log.user_id IS '操作用户ID';
COMMENT ON COLUMN spectra_core.sys_log.module IS '操作模块';
COMMENT ON COLUMN spectra_core.sys_log.action IS '操作类型';
COMMENT ON COLUMN spectra_core.sys_log.target IS '操作对象';
COMMENT ON COLUMN spectra_core.sys_log.ip IS '操作IP';
COMMENT ON COLUMN spectra_core.sys_log.user_agent IS '客户端信息';
COMMENT ON COLUMN spectra_core.sys_log.request_params IS '请求参数';
COMMENT ON COLUMN spectra_core.sys_log.response_result IS '响应结果';
COMMENT ON COLUMN spectra_core.sys_log.duration IS '执行耗时(ms)';
COMMENT ON COLUMN spectra_core.sys_log.created_by IS '创建人';
COMMENT ON COLUMN spectra_core.sys_log.created_at IS '创建时间';
COMMENT ON COLUMN spectra_core.sys_log.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_core.sys_log.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_core.sys_log.deleted IS '是否删除';
COMMENT ON COLUMN spectra_core.sys_log.version IS '乐观锁';

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

-- ============================================
-- AI 模块
-- ============================================

-- AI 会话状态
CREATE TABLE spectra_core.ai_session (
    id          UUID PRIMARY KEY,
    session_id  VARCHAR(255) NOT NULL,
    state_key   VARCHAR(255) NOT NULL,
    item_index  INTEGER DEFAULT 0 NOT NULL,
    state_data  TEXT NOT NULL,
    created_by  UUID,
    created_at  TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by  UUID,
    updated_at  TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted     TIMESTAMP(6) WITH TIME ZONE,
    version     BIGINT DEFAULT 0
);
COMMENT ON TABLE spectra_core.ai_session IS 'AI-Agent会话状态存储表';
COMMENT ON COLUMN spectra_core.ai_session.session_id IS 'session id';
COMMENT ON COLUMN spectra_core.ai_session.state_key IS 'state key';
COMMENT ON COLUMN spectra_core.ai_session.item_index IS 'item_index';
COMMENT ON COLUMN spectra_core.ai_session.state_data IS 'state_data';
