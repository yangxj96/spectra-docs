-- ============================================
-- spectra_security 目标安全 schema
--
-- 该文件是 Phase 1 的目标 DDL 契约，最终由 Flyway V1 汇总执行。
-- 不包含兼容旧 user_role、authority 或全局 data_scope 的表。
-- ============================================

CREATE SCHEMA IF NOT EXISTS spectra_security;

-- ============================================
-- Permission / Role / Assignment
-- ============================================

CREATE TABLE spectra_security.permission (
    id                 UUID PRIMARY KEY,
    code               VARCHAR(120) NOT NULL,
    name               VARCHAR(120) NOT NULL,
    resource_code      VARCHAR(80) NOT NULL,
    action_code        VARCHAR(80) NOT NULL,
    allowed_scope_modes VARCHAR(128) NOT NULL DEFAULT 'NONE',
    state              VARCHAR(16) NOT NULL DEFAULT 'ACTIVE',
    system_managed     BOOLEAN NOT NULL DEFAULT FALSE,
    created_by         UUID,
    created_at         TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by         UUID,
    updated_at         TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version            BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT ck_security_permission_code CHECK (code ~ '^[a-z][a-z0-9_-]*(:[a-z][a-z0-9_-]*){1,2}$'),
    CONSTRAINT ck_security_permission_state CHECK (state IN ('ACTIVE', 'DEPRECATED')),
    CONSTRAINT uk_security_permission_code UNIQUE (code)
);

CREATE TABLE spectra_security.role (
    id              UUID PRIMARY KEY,
    code            VARCHAR(80) NOT NULL,
    name            VARCHAR(120) NOT NULL,
    authority_level SMALLINT NOT NULL,
    state           VARCHAR(16) NOT NULL DEFAULT 'ACTIVE',
    role_kind       VARCHAR(24) NOT NULL DEFAULT 'BUSINESS',
    system_managed  BOOLEAN NOT NULL DEFAULT FALSE,
    remark          VARCHAR(500),
    created_by      UUID,
    created_at      TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_by      UUID,
    updated_at      TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version         BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT ck_security_role_code CHECK (code ~ '^ROLE_[A-Z0-9_]+$'),
    CONSTRAINT ck_security_role_authority CHECK (authority_level > 0),
    CONSTRAINT ck_security_role_state CHECK (state IN ('ACTIVE', 'DISABLED')),
    CONSTRAINT ck_security_role_kind CHECK (role_kind IN ('BUSINESS', 'DEV_OPS', 'SYSTEM_ADMIN', 'AUDITOR')),
    CONSTRAINT uk_security_role_code UNIQUE (code)
);

CREATE TABLE spectra_security.role_permission (
    role_id       UUID NOT NULL REFERENCES spectra_security.role (id) ON DELETE RESTRICT,
    permission_id UUID NOT NULL REFERENCES spectra_security.permission (id) ON DELETE RESTRICT,
    created_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE spectra_security.role_grantable_permission (
    role_id       UUID NOT NULL REFERENCES spectra_security.role (id) ON DELETE RESTRICT,
    permission_id UUID NOT NULL REFERENCES spectra_security.permission (id) ON DELETE RESTRICT,
    created_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE spectra_security.role_assignment (
    id            UUID PRIMARY KEY,
    user_id       UUID NOT NULL REFERENCES spectra_core.sys_user (id) ON DELETE RESTRICT,
    role_id       UUID NOT NULL REFERENCES spectra_security.role (id) ON DELETE RESTRICT,
    state         VARCHAR(16) NOT NULL DEFAULT 'ACTIVE',
    valid_from    TIMESTAMP(6) WITH TIME ZONE,
    valid_until   TIMESTAMP(6) WITH TIME ZONE,
    assigned_by   UUID,
    assigned_at   TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    revoked_by    UUID,
    revoked_at    TIMESTAMP(6) WITH TIME ZONE,
    version       BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT ck_security_role_assignment_state CHECK (state IN ('ACTIVE', 'REVOKED', 'EXPIRED')),
    CONSTRAINT ck_security_role_assignment_period CHECK (valid_until IS NULL OR valid_from IS NULL OR valid_until > valid_from)
);

CREATE INDEX idx_security_role_assignment_user_state
    ON spectra_security.role_assignment (user_id, state);
CREATE INDEX idx_security_role_assignment_role_state
    ON spectra_security.role_assignment (role_id, state);

-- ============================================
-- Permission-specific Access / Grant Boundary
-- ============================================

CREATE TABLE spectra_security.authorization_scope (
    id            UUID PRIMARY KEY,
    scope_mode    VARCHAR(8) NOT NULL,
    resource_code VARCHAR(80),
    created_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_security_scope_mode CHECK (scope_mode IN ('NONE', 'ALL', 'SELF', 'RULES')),
    CONSTRAINT ck_security_scope_resource CHECK (scope_mode IN ('NONE', 'SELF') OR resource_code IS NOT NULL)
);

CREATE TABLE spectra_security.assignment_permission_boundary (
    assignment_id UUID NOT NULL REFERENCES spectra_security.role_assignment (id) ON DELETE RESTRICT,
    permission_id UUID NOT NULL REFERENCES spectra_security.permission (id) ON DELETE RESTRICT,
    scope_id      UUID NOT NULL REFERENCES spectra_security.authorization_scope (id) ON DELETE RESTRICT,
    version       BIGINT NOT NULL DEFAULT 0,
    PRIMARY KEY (assignment_id, permission_id)
);

CREATE TABLE spectra_security.assignment_grant_boundary (
    assignment_id UUID NOT NULL REFERENCES spectra_security.role_assignment (id) ON DELETE RESTRICT,
    permission_id UUID NOT NULL REFERENCES spectra_security.permission (id) ON DELETE RESTRICT,
    scope_id      UUID NOT NULL REFERENCES spectra_security.authorization_scope (id) ON DELETE RESTRICT,
    version       BIGINT NOT NULL DEFAULT 0,
    PRIMARY KEY (assignment_id, permission_id)
);

CREATE TABLE spectra_security.scope_rule (
    id                  UUID PRIMARY KEY,
    scope_id             UUID NOT NULL REFERENCES spectra_security.authorization_scope (id) ON DELETE RESTRICT,
    rule_type            VARCHAR(24) NOT NULL,
    department_id        UUID REFERENCES spectra_core.sys_department (id) ON DELETE RESTRICT,
    include_descendants  BOOLEAN NOT NULL DEFAULT FALSE,
    rule_payload         JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at           TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_security_scope_rule_type CHECK (rule_type IN ('DEPARTMENT', 'RESOURCE_RULE')),
    CONSTRAINT ck_security_scope_rule_department CHECK (rule_type <> 'DEPARTMENT' OR department_id IS NOT NULL)
);

CREATE UNIQUE INDEX uk_security_scope_rule_department
    ON spectra_security.scope_rule (scope_id, department_id, include_descendants)
    WHERE rule_type = 'DEPARTMENT';
CREATE INDEX idx_security_scope_rule_department
    ON spectra_security.scope_rule (department_id, include_descendants);

-- ============================================
-- Authentication / Client / Policy
-- ============================================

CREATE TABLE spectra_security.authentication_identity (
    id             UUID PRIMARY KEY,
    user_id        UUID NOT NULL REFERENCES spectra_core.sys_user (id) ON DELETE RESTRICT,
    method_code    VARCHAR(32) NOT NULL,
    provider_code  VARCHAR(64) NOT NULL DEFAULT 'LOCAL',
    identifier_hash VARCHAR(128) NOT NULL,
    state          VARCHAR(16) NOT NULL DEFAULT 'ACTIVE',
    verified_at    TIMESTAMP(6) WITH TIME ZONE,
    last_used_at   TIMESTAMP(6) WITH TIME ZONE,
    created_at     TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version        BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT ck_security_identity_state CHECK (state IN ('ACTIVE', 'DISABLED', 'REVOKED')),
    CONSTRAINT uk_security_identity_identifier UNIQUE (method_code, provider_code, identifier_hash)
);

CREATE INDEX idx_security_identity_user_state
    ON spectra_security.authentication_identity (user_id, state);

CREATE TABLE spectra_security.password_credential (
    user_id          UUID PRIMARY KEY REFERENCES spectra_core.sys_user (id) ON DELETE RESTRICT,
    password_hash    VARCHAR(255) NOT NULL,
    changed_at       TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    expires_at       TIMESTAMP(6) WITH TIME ZONE,
    must_change      BOOLEAN NOT NULL DEFAULT FALSE,
    failed_attempts  INTEGER NOT NULL DEFAULT 0,
    locked_until     TIMESTAMP(6) WITH TIME ZONE,
    version          BIGINT NOT NULL DEFAULT 0
);

CREATE TABLE spectra_security.security_client (
    id          UUID PRIMARY KEY,
    code        VARCHAR(32) NOT NULL,
    name        VARCHAR(80) NOT NULL,
    state       VARCHAR(16) NOT NULL DEFAULT 'ACTIVE',
    created_at  TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version     BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT ck_security_client_state CHECK (state IN ('ACTIVE', 'DISABLED')),
    CONSTRAINT uk_security_client_code UNIQUE (code)
);

CREATE TABLE spectra_security.authentication_method (
    id            UUID PRIMARY KEY,
    code          VARCHAR(32) NOT NULL,
    name          VARCHAR(80) NOT NULL,
    state         VARCHAR(16) NOT NULL DEFAULT 'ACTIVE',
    secret_ref    VARCHAR(255),
    created_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version       BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT ck_security_auth_method_state CHECK (state IN ('ACTIVE', 'DISABLED')),
    CONSTRAINT uk_security_auth_method_code UNIQUE (code)
);

CREATE TABLE spectra_security.client_auth_method (
    client_id              UUID NOT NULL REFERENCES spectra_security.security_client (id) ON DELETE RESTRICT,
    authentication_method_id UUID NOT NULL REFERENCES spectra_security.authentication_method (id) ON DELETE RESTRICT,
    PRIMARY KEY (client_id, authentication_method_id)
);

CREATE TABLE spectra_security.session_policy (
    client_id          UUID PRIMARY KEY REFERENCES spectra_security.security_client (id) ON DELETE RESTRICT,
    concurrency_mode   VARCHAR(16) NOT NULL DEFAULT 'ALLOW',
    allow_concurrent   BOOLEAN NOT NULL DEFAULT TRUE,
    max_sessions       INTEGER NOT NULL DEFAULT 1,
    access_ttl_seconds INTEGER NOT NULL DEFAULT 300,
    refresh_ttl_seconds INTEGER NOT NULL DEFAULT 604800,
    absolute_ttl_seconds INTEGER,
    idle_ttl_seconds INTEGER,
    version            BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT ck_security_session_mode CHECK (concurrency_mode IN ('ALLOW', 'KICK_OLD', 'REJECT_NEW')),
    CONSTRAINT ck_security_session_limits CHECK (max_sessions > 0 AND access_ttl_seconds > 0 AND refresh_ttl_seconds > 0)
);

CREATE TABLE spectra_security.password_policy (
    policy_key          VARCHAR(32) PRIMARY KEY DEFAULT 'SYSTEM',
    min_length          INTEGER NOT NULL DEFAULT 12,
    require_uppercase   BOOLEAN NOT NULL DEFAULT TRUE,
    require_lowercase   BOOLEAN NOT NULL DEFAULT TRUE,
    require_digit       BOOLEAN NOT NULL DEFAULT TRUE,
    require_special     BOOLEAN NOT NULL DEFAULT TRUE,
    max_age_days        INTEGER,
    version             BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT ck_security_password_policy_key CHECK (policy_key = 'SYSTEM'),
    CONSTRAINT ck_security_password_policy_length CHECK (min_length >= 8)
);

-- ============================================
-- MFA / Recovery
-- ============================================

CREATE TABLE spectra_security.mfa_enrollment (
    id           UUID PRIMARY KEY,
    user_id      UUID NOT NULL REFERENCES spectra_core.sys_user (id) ON DELETE RESTRICT,
    factor_type  VARCHAR(24) NOT NULL,
    state        VARCHAR(16) NOT NULL DEFAULT 'PENDING',
    enrolled_at  TIMESTAMP(6) WITH TIME ZONE,
    revoked_at   TIMESTAMP(6) WITH TIME ZONE,
    created_at   TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    version      BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT ck_security_mfa_factor CHECK (factor_type IN ('TOTP', 'WEBAUTHN', 'PASSKEY')),
    CONSTRAINT ck_security_mfa_state CHECK (state IN ('PENDING', 'ACTIVE', 'REVOKED'))
);

CREATE UNIQUE INDEX uk_security_mfa_user_factor_active
    ON spectra_security.mfa_enrollment (user_id, factor_type)
    WHERE state = 'ACTIVE';

CREATE TABLE spectra_security.totp_credential (
    enrollment_id UUID PRIMARY KEY REFERENCES spectra_security.mfa_enrollment (id) ON DELETE RESTRICT,
    encrypted_secret BYTEA NOT NULL,
    key_version    VARCHAR(64) NOT NULL,
    created_at     TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE spectra_security.recovery_code (
    id            UUID PRIMARY KEY,
    enrollment_id UUID NOT NULL REFERENCES spectra_security.mfa_enrollment (id) ON DELETE RESTRICT,
    code_hash     VARCHAR(255) NOT NULL,
    used_at       TIMESTAMP(6) WITH TIME ZONE,
    version       BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT uk_security_recovery_code_hash UNIQUE (enrollment_id, code_hash)
);

-- ============================================
-- Root policy / immutable Security Audit / outbox
-- ============================================

CREATE TABLE spectra_security.root_policy (
    policy_key                    VARCHAR(32) PRIMARY KEY DEFAULT 'SYSTEM',
    min_effective_dev_ops_users   INTEGER NOT NULL DEFAULT 1,
    max_dev_ops_users             INTEGER NOT NULL DEFAULT 3,
    version                       BIGINT NOT NULL DEFAULT 0,
    created_at                    TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at                    TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_security_root_policy_key CHECK (policy_key = 'SYSTEM'),
    CONSTRAINT ck_security_root_policy_limits CHECK (min_effective_dev_ops_users >= 1
        AND max_dev_ops_users >= min_effective_dev_ops_users)
);

INSERT INTO spectra_security.root_policy (policy_key, min_effective_dev_ops_users, max_dev_ops_users)
VALUES ('SYSTEM', 1, 3)
ON CONFLICT (policy_key) DO NOTHING;

CREATE TABLE spectra_security.security_audit_event (
    event_id          UUID NOT NULL,
    event_type        VARCHAR(100) NOT NULL,
    operator_id       UUID,
    target_id         UUID,
    client            VARCHAR(32),
    ip                VARCHAR(64),
    user_agent        VARCHAR(500),
    before_snapshot   JSONB NOT NULL DEFAULT '{}'::JSONB,
    after_snapshot    JSONB NOT NULL DEFAULT '{}'::JSONB,
    reason            VARCHAR(500),
    occurred_at       TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    result            VARCHAR(16) NOT NULL,
    correlation_id    VARCHAR(100),
    PRIMARY KEY (event_id, occurred_at),
    CONSTRAINT ck_security_audit_result CHECK (result IN ('STARTED', 'SUCCEEDED', 'FAILED', 'DENIED'))
) PARTITION BY RANGE (occurred_at);

CREATE TABLE spectra_security.security_audit_event_default
    PARTITION OF spectra_security.security_audit_event DEFAULT;

CREATE INDEX idx_security_audit_event_time
    ON spectra_security.security_audit_event (occurred_at DESC);
CREATE INDEX idx_security_audit_event_type
    ON spectra_security.security_audit_event (event_type, occurred_at DESC);
CREATE INDEX idx_security_audit_event_operator
    ON spectra_security.security_audit_event (operator_id, occurred_at DESC);
CREATE INDEX idx_security_audit_event_target
    ON spectra_security.security_audit_event (target_id, occurred_at DESC);

CREATE OR REPLACE FUNCTION spectra_security.reject_audit_mutation()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE EXCEPTION 'security_audit_event is append-only';
END;
$$;

CREATE TRIGGER trg_security_audit_event_immutable
    BEFORE UPDATE OR DELETE ON spectra_security.security_audit_event
    FOR EACH ROW EXECUTE FUNCTION spectra_security.reject_audit_mutation();

REVOKE UPDATE, DELETE ON spectra_security.security_audit_event FROM PUBLIC;

CREATE TABLE spectra_security.security_audit_retention_policy (
    policy_key             VARCHAR(64) PRIMARY KEY,
    hot_retention_months   INTEGER NOT NULL DEFAULT 12,
    total_retention_years  INTEGER NOT NULL DEFAULT 5,
    archive_backend        VARCHAR(64) NOT NULL DEFAULT 'PENDING',
    state                  VARCHAR(32) NOT NULL DEFAULT 'ACTIVE',
    version                BIGINT NOT NULL DEFAULT 0,
    created_at             TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at             TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_security_audit_hot_retention CHECK (hot_retention_months >= 12),
    CONSTRAINT ck_security_audit_total_retention CHECK (total_retention_years >= 5),
    CONSTRAINT ck_security_audit_retention_state CHECK (state IN ('ACTIVE', 'PAUSED'))
);

INSERT INTO spectra_security.security_audit_retention_policy
    (policy_key, hot_retention_months, total_retention_years, archive_backend, state)
VALUES ('DEFAULT', 12, 5, 'PENDING', 'ACTIVE')
ON CONFLICT (policy_key) DO NOTHING;

CREATE TABLE spectra_security.security_audit_archive_manifest (
    manifest_id       UUID PRIMARY KEY,
    partition_name    VARCHAR(128) NOT NULL UNIQUE,
    range_start       TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    range_end         TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    object_uri        VARCHAR(1000),
    content_sha256    CHAR(64),
    row_count         BIGINT,
    state             VARCHAR(32) NOT NULL DEFAULT 'PLANNED',
    archived_at       TIMESTAMP(6) WITH TIME ZONE,
    verified_at       TIMESTAMP(6) WITH TIME ZONE,
    last_error        VARCHAR(2000),
    created_at        TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_security_audit_archive_range CHECK (range_end > range_start),
    CONSTRAINT ck_security_audit_archive_state CHECK (state IN ('PLANNED', 'ARCHIVED', 'VERIFIED', 'RESTORE_PENDING', 'RESTORED', 'FAILED')),
    CONSTRAINT ck_security_audit_archive_hash CHECK (content_sha256 IS NULL OR content_sha256 ~ '^[0-9a-fA-F]{64}$')
);

CREATE INDEX idx_security_audit_archive_manifest_range
    ON spectra_security.security_audit_archive_manifest (range_start, range_end);
CREATE INDEX idx_security_audit_archive_manifest_state
    ON spectra_security.security_audit_archive_manifest (state, updated_at DESC);

COMMENT ON TABLE spectra_security.security_audit_retention_policy IS '安全审计热存/总保留策略，只读展示，变更需审计运维流程';
COMMENT ON TABLE spectra_security.security_audit_archive_manifest IS '安全审计分区归档、校验、恢复清单，不代表可删除审计事实';
COMMENT ON COLUMN spectra_security.security_audit_archive_manifest.content_sha256 IS '归档对象完整性校验摘要';

CREATE TABLE spectra_security.security_change_outbox (
    id              UUID PRIMARY KEY,
    event_type      VARCHAR(100) NOT NULL,
    aggregate_type  VARCHAR(80) NOT NULL,
    aggregate_id    UUID,
    payload         JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at      TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    processed_at    TIMESTAMP(6) WITH TIME ZONE,
    attempts        INTEGER NOT NULL DEFAULT 0,
    last_error      VARCHAR(1000),
    version         BIGINT NOT NULL DEFAULT 0
);

CREATE INDEX idx_security_outbox_pending
    ON spectra_security.security_change_outbox (created_at)
    WHERE processed_at IS NULL;

-- Menu is a navigation capability and remains separate from Permission.
CREATE TABLE spectra_security.role_menu (
    role_id       UUID NOT NULL REFERENCES spectra_security.role (id) ON DELETE RESTRICT,
    menu_id       UUID NOT NULL REFERENCES spectra_core.sys_menu (id) ON DELETE RESTRICT,
    created_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (role_id, menu_id)
);

CREATE INDEX idx_security_role_menu_menu
    ON spectra_security.role_menu (menu_id);
+-- spectra_security: table and column comments
-- ============================================================================

COMMENT ON TABLE spectra_security.permission IS '权限定义表';
COMMENT ON COLUMN spectra_security.permission.id IS '主键ID';
COMMENT ON COLUMN spectra_security.permission.code IS '稳定权限编码，格式为 resource:action';
COMMENT ON COLUMN spectra_security.permission.name IS '权限名称';
COMMENT ON COLUMN spectra_security.permission.resource_code IS '资源编码';
COMMENT ON COLUMN spectra_security.permission.action_code IS '动作编码';
COMMENT ON COLUMN spectra_security.permission.allowed_scope_modes IS '允许的数据范围模式：NONE/ALL/SELF/RULES';
COMMENT ON COLUMN spectra_security.permission.state IS '权限状态：ACTIVE-启用，DEPRECATED-废弃';
COMMENT ON COLUMN spectra_security.permission.system_managed IS '是否系统维护权限';
COMMENT ON COLUMN spectra_security.permission.created_by IS '创建人';
COMMENT ON COLUMN spectra_security.permission.created_at IS '创建时间';
COMMENT ON COLUMN spectra_security.permission.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_security.permission.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_security.permission.version IS '乐观锁';

COMMENT ON TABLE spectra_security.role IS '角色能力模板表';
COMMENT ON COLUMN spectra_security.role.id IS '主键ID';
COMMENT ON COLUMN spectra_security.role.code IS '角色编码，格式为 ROLE_*';
COMMENT ON COLUMN spectra_security.role.name IS '角色名称';
COMMENT ON COLUMN spectra_security.role.authority_level IS '管理边界等级，不用于推导业务权限';
COMMENT ON COLUMN spectra_security.role.state IS '角色状态：ACTIVE-启用，DISABLED-禁用';
COMMENT ON COLUMN spectra_security.role.role_kind IS '角色类型：BUSINESS/SYSTEM_ADMIN/AUDITOR/DEV_OPS';
COMMENT ON COLUMN spectra_security.role.system_managed IS '是否系统维护角色';
COMMENT ON COLUMN spectra_security.role.remark IS '备注';
COMMENT ON COLUMN spectra_security.role.created_by IS '创建人';
COMMENT ON COLUMN spectra_security.role.created_at IS '创建时间';
COMMENT ON COLUMN spectra_security.role.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_security.role.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_security.role.version IS '乐观锁';

COMMENT ON TABLE spectra_security.role_permission IS '角色与权限关系表';
COMMENT ON COLUMN spectra_security.role_permission.role_id IS '角色ID';
COMMENT ON COLUMN spectra_security.role_permission.permission_id IS '权限ID';
COMMENT ON COLUMN spectra_security.role_permission.created_at IS '创建时间';

COMMENT ON TABLE spectra_security.role_grantable_permission IS '角色可授予权限关系表';
COMMENT ON COLUMN spectra_security.role_grantable_permission.role_id IS '角色ID';
COMMENT ON COLUMN spectra_security.role_grantable_permission.permission_id IS '可授予的权限ID';
COMMENT ON COLUMN spectra_security.role_grantable_permission.created_at IS '创建时间';

COMMENT ON TABLE spectra_security.role_assignment IS '用户角色授权实例表';
COMMENT ON COLUMN spectra_security.role_assignment.id IS '主键ID';
COMMENT ON COLUMN spectra_security.role_assignment.user_id IS '被授权用户ID';
COMMENT ON COLUMN spectra_security.role_assignment.role_id IS '角色ID';
COMMENT ON COLUMN spectra_security.role_assignment.state IS '授权状态：ACTIVE/REVOKED/EXPIRED';
COMMENT ON COLUMN spectra_security.role_assignment.valid_from IS '生效时间';
COMMENT ON COLUMN spectra_security.role_assignment.valid_until IS '失效时间';
COMMENT ON COLUMN spectra_security.role_assignment.assigned_by IS '授权操作人';
COMMENT ON COLUMN spectra_security.role_assignment.assigned_at IS '授权时间';
COMMENT ON COLUMN spectra_security.role_assignment.revoked_by IS '撤销操作人';
COMMENT ON COLUMN spectra_security.role_assignment.revoked_at IS '撤销时间';
COMMENT ON COLUMN spectra_security.role_assignment.version IS '乐观锁';

COMMENT ON TABLE spectra_security.authorization_scope IS '授权范围定义表';
COMMENT ON COLUMN spectra_security.authorization_scope.id IS '主键ID';
COMMENT ON COLUMN spectra_security.authorization_scope.scope_mode IS '范围模式：NONE/ALL/SELF/RULES';
COMMENT ON COLUMN spectra_security.authorization_scope.resource_code IS '范围对应资源编码';
COMMENT ON COLUMN spectra_security.authorization_scope.created_at IS '创建时间';

COMMENT ON TABLE spectra_security.assignment_permission_boundary IS '角色授权实例的访问边界表';
COMMENT ON COLUMN spectra_security.assignment_permission_boundary.assignment_id IS '角色授权实例ID';
COMMENT ON COLUMN spectra_security.assignment_permission_boundary.permission_id IS '权限ID';
COMMENT ON COLUMN spectra_security.assignment_permission_boundary.scope_id IS '该权限对应的数据范围ID';
COMMENT ON COLUMN spectra_security.assignment_permission_boundary.version IS '乐观锁';

COMMENT ON TABLE spectra_security.assignment_grant_boundary IS '角色授权实例的授予边界表';
COMMENT ON COLUMN spectra_security.assignment_grant_boundary.assignment_id IS '角色授权实例ID';
COMMENT ON COLUMN spectra_security.assignment_grant_boundary.permission_id IS '可授予权限ID';
COMMENT ON COLUMN spectra_security.assignment_grant_boundary.scope_id IS '该授予权限对应的管理范围ID';
COMMENT ON COLUMN spectra_security.assignment_grant_boundary.version IS '乐观锁';

COMMENT ON TABLE spectra_security.scope_rule IS '授权范围规则表';
COMMENT ON COLUMN spectra_security.scope_rule.id IS '主键ID';
COMMENT ON COLUMN spectra_security.scope_rule.scope_id IS '授权范围ID';
COMMENT ON COLUMN spectra_security.scope_rule.rule_type IS '规则类型：DEPARTMENT/RESOURCE_RULE';
COMMENT ON COLUMN spectra_security.scope_rule.department_id IS '部门ID';
COMMENT ON COLUMN spectra_security.scope_rule.include_descendants IS '是否包含下级部门';
COMMENT ON COLUMN spectra_security.scope_rule.rule_payload IS '资源规则参数';
COMMENT ON COLUMN spectra_security.scope_rule.created_at IS '创建时间';

COMMENT ON TABLE spectra_security.authentication_identity IS '认证身份标识表';
COMMENT ON COLUMN spectra_security.authentication_identity.id IS '主键ID';
COMMENT ON COLUMN spectra_security.authentication_identity.user_id IS '用户ID';
COMMENT ON COLUMN spectra_security.authentication_identity.method_code IS '认证方式编码';
COMMENT ON COLUMN spectra_security.authentication_identity.provider_code IS '认证提供方编码';
COMMENT ON COLUMN spectra_security.authentication_identity.identifier_hash IS '身份标识哈希';
COMMENT ON COLUMN spectra_security.authentication_identity.state IS '身份状态：ACTIVE/DISABLED/REVOKED';
COMMENT ON COLUMN spectra_security.authentication_identity.verified_at IS '验证时间';
COMMENT ON COLUMN spectra_security.authentication_identity.last_used_at IS '最后使用时间';
COMMENT ON COLUMN spectra_security.authentication_identity.created_at IS '创建时间';
COMMENT ON COLUMN spectra_security.authentication_identity.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_security.authentication_identity.version IS '乐观锁';

COMMENT ON TABLE spectra_security.password_credential IS '密码凭证表';
COMMENT ON COLUMN spectra_security.password_credential.user_id IS '用户ID';
COMMENT ON COLUMN spectra_security.password_credential.password_hash IS '密码哈希，不存储明文密码';
COMMENT ON COLUMN spectra_security.password_credential.changed_at IS '密码变更时间';
COMMENT ON COLUMN spectra_security.password_credential.expires_at IS '密码过期时间';
COMMENT ON COLUMN spectra_security.password_credential.must_change IS '是否必须修改密码';
COMMENT ON COLUMN spectra_security.password_credential.failed_attempts IS '连续认证失败次数';
COMMENT ON COLUMN spectra_security.password_credential.locked_until IS '凭证锁定截止时间';
COMMENT ON COLUMN spectra_security.password_credential.version IS '乐观锁';

COMMENT ON TABLE spectra_security.security_client IS '登录客户端定义表';
COMMENT ON COLUMN spectra_security.security_client.id IS '主键ID';
COMMENT ON COLUMN spectra_security.security_client.code IS '客户端编码，如 WEB/APP';
COMMENT ON COLUMN spectra_security.security_client.name IS '客户端名称';
COMMENT ON COLUMN spectra_security.security_client.state IS '客户端状态：ACTIVE/DISABLED';
COMMENT ON COLUMN spectra_security.security_client.created_at IS '创建时间';
COMMENT ON COLUMN spectra_security.security_client.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_security.security_client.version IS '乐观锁';

COMMENT ON TABLE spectra_security.authentication_method IS '认证方式定义表';
COMMENT ON COLUMN spectra_security.authentication_method.id IS '主键ID';
COMMENT ON COLUMN spectra_security.authentication_method.code IS '认证方式编码，如 PASSWORD/TOTP';
COMMENT ON COLUMN spectra_security.authentication_method.name IS '认证方式名称';
COMMENT ON COLUMN spectra_security.authentication_method.state IS '认证方式状态：ACTIVE/DISABLED';
COMMENT ON COLUMN spectra_security.authentication_method.secret_ref IS '外部密钥引用，不保存密钥明文';
COMMENT ON COLUMN spectra_security.authentication_method.created_at IS '创建时间';
COMMENT ON COLUMN spectra_security.authentication_method.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_security.authentication_method.version IS '乐观锁';

COMMENT ON TABLE spectra_security.client_auth_method IS '客户端允许的认证方式关系表';
COMMENT ON COLUMN spectra_security.client_auth_method.client_id IS '客户端ID';
COMMENT ON COLUMN spectra_security.client_auth_method.authentication_method_id IS '认证方式ID';

COMMENT ON TABLE spectra_security.session_policy IS '客户端会话策略表';
COMMENT ON COLUMN spectra_security.session_policy.client_id IS '客户端ID';
COMMENT ON COLUMN spectra_security.session_policy.concurrency_mode IS '并发策略：ALLOW/KICK_OLD/REJECT_NEW';
COMMENT ON COLUMN spectra_security.session_policy.allow_concurrent IS '是否允许并发会话';
COMMENT ON COLUMN spectra_security.session_policy.max_sessions IS '最大会话数';
COMMENT ON COLUMN spectra_security.session_policy.access_ttl_seconds IS '访问令牌有效期（秒）';
COMMENT ON COLUMN spectra_security.session_policy.refresh_ttl_seconds IS '刷新令牌有效期（秒）';
COMMENT ON COLUMN spectra_security.session_policy.absolute_ttl_seconds IS '会话绝对有效期（秒）';
COMMENT ON COLUMN spectra_security.session_policy.idle_ttl_seconds IS '会话空闲有效期（秒）';
COMMENT ON COLUMN spectra_security.session_policy.version IS '乐观锁';

COMMENT ON TABLE spectra_security.password_policy IS '密码安全策略表';
COMMENT ON COLUMN spectra_security.password_policy.policy_key IS '策略键，固定为 SYSTEM';
COMMENT ON COLUMN spectra_security.password_policy.min_length IS '密码最小长度';
COMMENT ON COLUMN spectra_security.password_policy.require_uppercase IS '是否要求大写字母';
COMMENT ON COLUMN spectra_security.password_policy.require_lowercase IS '是否要求小写字母';
COMMENT ON COLUMN spectra_security.password_policy.require_digit IS '是否要求数字';
COMMENT ON COLUMN spectra_security.password_policy.require_special IS '是否要求特殊字符';
COMMENT ON COLUMN spectra_security.password_policy.max_age_days IS '密码最长有效天数';
COMMENT ON COLUMN spectra_security.password_policy.version IS '乐观锁';

COMMENT ON TABLE spectra_security.mfa_enrollment IS '多因素认证绑定表';
COMMENT ON COLUMN spectra_security.mfa_enrollment.id IS '主键ID';
COMMENT ON COLUMN spectra_security.mfa_enrollment.user_id IS '用户ID';
COMMENT ON COLUMN spectra_security.mfa_enrollment.factor_type IS '因子类型：TOTP/WEBAUTHN/PASSKEY';
COMMENT ON COLUMN spectra_security.mfa_enrollment.state IS '绑定状态：PENDING/ACTIVE/REVOKED';
COMMENT ON COLUMN spectra_security.mfa_enrollment.enrolled_at IS '启用时间';
COMMENT ON COLUMN spectra_security.mfa_enrollment.revoked_at IS '撤销时间';
COMMENT ON COLUMN spectra_security.mfa_enrollment.created_at IS '创建时间';
COMMENT ON COLUMN spectra_security.mfa_enrollment.version IS '乐观锁';

COMMENT ON TABLE spectra_security.totp_credential IS 'TOTP 凭证表';
COMMENT ON COLUMN spectra_security.totp_credential.enrollment_id IS 'MFA 绑定ID';
COMMENT ON COLUMN spectra_security.totp_credential.encrypted_secret IS '加密后的 TOTP 密钥';
COMMENT ON COLUMN spectra_security.totp_credential.key_version IS '密钥版本';
COMMENT ON COLUMN spectra_security.totp_credential.created_at IS '创建时间';

COMMENT ON TABLE spectra_security.recovery_code IS 'MFA 恢复码表';
COMMENT ON COLUMN spectra_security.recovery_code.id IS '主键ID';
COMMENT ON COLUMN spectra_security.recovery_code.enrollment_id IS 'MFA 绑定ID';
COMMENT ON COLUMN spectra_security.recovery_code.code_hash IS '恢复码哈希，不存储明文';
COMMENT ON COLUMN spectra_security.recovery_code.used_at IS '使用时间，单次使用';
COMMENT ON COLUMN spectra_security.recovery_code.version IS '乐观锁';

COMMENT ON TABLE spectra_security.root_policy IS 'DEV_OPS 根策略表';
COMMENT ON COLUMN spectra_security.root_policy.policy_key IS '策略键，固定为 SYSTEM';
COMMENT ON COLUMN spectra_security.root_policy.min_effective_dev_ops_users IS '最少有效 DEV_OPS 数量，保护最后一个 Root';
COMMENT ON COLUMN spectra_security.root_policy.max_dev_ops_users IS '最多 DEV_OPS 数量';
COMMENT ON COLUMN spectra_security.root_policy.version IS '乐观锁';
COMMENT ON COLUMN spectra_security.root_policy.created_at IS '创建时间';
COMMENT ON COLUMN spectra_security.root_policy.updated_at IS '最后更新时间';

COMMENT ON TABLE spectra_security.security_audit_event IS '不可删除的安全审计事件表';
COMMENT ON COLUMN spectra_security.security_audit_event.event_id IS '事件ID';
COMMENT ON COLUMN spectra_security.security_audit_event.event_type IS '事件类型';
COMMENT ON COLUMN spectra_security.security_audit_event.operator_id IS '操作人ID';
COMMENT ON COLUMN spectra_security.security_audit_event.target_id IS '目标主体ID';
COMMENT ON COLUMN spectra_security.security_audit_event.client IS '客户端类型';
COMMENT ON COLUMN spectra_security.security_audit_event.ip IS '来源IP';
COMMENT ON COLUMN spectra_security.security_audit_event.user_agent IS '客户端 User-Agent';
COMMENT ON COLUMN spectra_security.security_audit_event.before_snapshot IS '变更前快照，敏感字段已脱敏';
COMMENT ON COLUMN spectra_security.security_audit_event.after_snapshot IS '变更后快照，敏感字段已脱敏';
COMMENT ON COLUMN spectra_security.security_audit_event.reason IS '操作原因';
COMMENT ON COLUMN spectra_security.security_audit_event.occurred_at IS '发生时间';
COMMENT ON COLUMN spectra_security.security_audit_event.result IS '结果：STARTED/SUCCEEDED/FAILED/DENIED';
COMMENT ON COLUMN spectra_security.security_audit_event.correlation_id IS '关联请求ID';

COMMENT ON TABLE spectra_security.security_audit_event_default IS '安全审计默认分区';
COMMENT ON COLUMN spectra_security.security_audit_event_default.event_id IS '事件ID';
COMMENT ON COLUMN spectra_security.security_audit_event_default.event_type IS '事件类型';
COMMENT ON COLUMN spectra_security.security_audit_event_default.operator_id IS '操作人ID';
COMMENT ON COLUMN spectra_security.security_audit_event_default.target_id IS '目标主体ID';
COMMENT ON COLUMN spectra_security.security_audit_event_default.client IS '客户端类型';
COMMENT ON COLUMN spectra_security.security_audit_event_default.ip IS '来源IP';
COMMENT ON COLUMN spectra_security.security_audit_event_default.user_agent IS '客户端 User-Agent';
COMMENT ON COLUMN spectra_security.security_audit_event_default.before_snapshot IS '变更前快照，敏感字段已脱敏';
COMMENT ON COLUMN spectra_security.security_audit_event_default.after_snapshot IS '变更后快照，敏感字段已脱敏';
COMMENT ON COLUMN spectra_security.security_audit_event_default.reason IS '操作原因';
COMMENT ON COLUMN spectra_security.security_audit_event_default.occurred_at IS '发生时间';
COMMENT ON COLUMN spectra_security.security_audit_event_default.result IS '结果：STARTED/SUCCEEDED/FAILED/DENIED';
COMMENT ON COLUMN spectra_security.security_audit_event_default.correlation_id IS '关联请求ID';

COMMENT ON TABLE spectra_security.security_change_outbox IS '安全变更事件发件箱表';
COMMENT ON COLUMN spectra_security.security_change_outbox.id IS '主键ID';
COMMENT ON COLUMN spectra_security.security_change_outbox.event_type IS '变更事件类型';
COMMENT ON COLUMN spectra_security.security_change_outbox.aggregate_type IS '聚合类型';
COMMENT ON COLUMN spectra_security.security_change_outbox.aggregate_id IS '聚合ID';
COMMENT ON COLUMN spectra_security.security_change_outbox.payload IS '事件载荷';
COMMENT ON COLUMN spectra_security.security_change_outbox.created_at IS '创建时间';
COMMENT ON COLUMN spectra_security.security_change_outbox.processed_at IS '处理完成时间';
COMMENT ON COLUMN spectra_security.security_change_outbox.attempts IS '处理尝试次数';
COMMENT ON COLUMN spectra_security.security_change_outbox.last_error IS '最后一次处理错误';
COMMENT ON COLUMN spectra_security.security_change_outbox.version IS '乐观锁';

COMMENT ON TABLE spectra_security.role_menu IS '角色与菜单关系表';
COMMENT ON COLUMN spectra_security.role_menu.role_id IS '角色ID';
COMMENT ON COLUMN spectra_security.role_menu.menu_id IS '菜单ID';
COMMENT ON COLUMN spectra_security.role_menu.created_at IS '创建时间';
