-- 通用 OA 文档管理增量（P4 首个纵切）
-- 执行前请确认当前数据库已存在 spectra_oa.oa_document 和通用审计字段。

ALTER TABLE spectra_oa.oa_document
    ADD COLUMN IF NOT EXISTS folder_id UUID,
    ADD COLUMN IF NOT EXISTS title VARCHAR(255) NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS summary TEXT,
    ADD COLUMN IF NOT EXISTS status VARCHAR(32) NOT NULL DEFAULT 'DRAFT',
    ADD COLUMN IF NOT EXISTS visibility VARCHAR(32) NOT NULL DEFAULT 'DEPARTMENT',
    ADD COLUMN IF NOT EXISTS owner_id UUID,
    ADD COLUMN IF NOT EXISTS published_at TIMESTAMP(6) WITH TIME ZONE;

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
CREATE INDEX IF NOT EXISTS idx_oa_document_version_document ON spectra_oa.oa_document_version (document_id, version_no DESC);
