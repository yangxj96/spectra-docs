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
    CONSTRAINT ck_security_permission_code CHECK (code ~ '^[a-z][a-z0-9_-]*(\\.[a-z][a-z0-9_-]*)?:[a-z][a-z0-9_-]*$'),
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
