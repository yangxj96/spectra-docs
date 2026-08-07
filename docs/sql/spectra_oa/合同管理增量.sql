-- 通用 OA 合同管理增量（阶段 4 合同台账首版）
-- 执行前请确认当前数据库已存在 spectra_oa.oa_contract 和通用审计字段。

ALTER TABLE spectra_oa.oa_contract
    ADD COLUMN IF NOT EXISTS contract_no VARCHAR(64) NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS title VARCHAR(255) NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS contract_type VARCHAR(64) NOT NULL DEFAULT 'OTHER',
    ADD COLUMN IF NOT EXISTS counterparty_name VARCHAR(255) NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS counterparty_contact VARCHAR(128),
    ADD COLUMN IF NOT EXISTS owner_id UUID,
    ADD COLUMN IF NOT EXISTS amount NUMERIC(18, 2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS currency VARCHAR(16) NOT NULL DEFAULT 'CNY',
    ADD COLUMN IF NOT EXISTS start_date DATE,
    ADD COLUMN IF NOT EXISTS end_date DATE,
    ADD COLUMN IF NOT EXISTS status VARCHAR(32) NOT NULL DEFAULT 'DRAFT',
    ADD COLUMN IF NOT EXISTS signing_status VARCHAR(32) NOT NULL DEFAULT 'UNSIGNED',
    ADD COLUMN IF NOT EXISTS signed_at TIMESTAMP(6) WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS visibility VARCHAR(32) NOT NULL DEFAULT 'DEPARTMENT',
    ADD COLUMN IF NOT EXISTS summary TEXT;

CREATE TABLE IF NOT EXISTS spectra_oa.oa_contract_version (
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

CREATE TABLE IF NOT EXISTS spectra_oa.oa_contract_milestone (
    id                UUID PRIMARY KEY,
    contract_id       UUID NOT NULL,
    name              VARCHAR(255) NOT NULL,
    milestone_type    VARCHAR(64) NOT NULL DEFAULT 'OTHER',
    due_date          DATE NOT NULL,
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

CREATE UNIQUE INDEX IF NOT EXISTS uk_oa_contract_no
    ON spectra_oa.oa_contract (NULLIF(contract_no, ''))
    WHERE deleted IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uk_oa_contract_version_no
    ON spectra_oa.oa_contract_version (contract_id, version_no)
    WHERE deleted IS NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uk_oa_contract_current_version
    ON spectra_oa.oa_contract_version (contract_id)
    WHERE is_current = TRUE AND deleted IS NULL;
CREATE INDEX IF NOT EXISTS idx_oa_contract_status
    ON spectra_oa.oa_contract (status, end_date);
CREATE INDEX IF NOT EXISTS idx_oa_contract_counterparty
    ON spectra_oa.oa_contract (counterparty_name);
CREATE INDEX IF NOT EXISTS idx_oa_contract_version_contract
    ON spectra_oa.oa_contract_version (contract_id, version_no DESC);
CREATE INDEX IF NOT EXISTS idx_oa_contract_milestone_due
    ON spectra_oa.oa_contract_milestone (due_date, status);
