-- P1 阶段 3：资产管理 MVP
ALTER TABLE spectra_oa.oa_asset
    ADD COLUMN IF NOT EXISTS category_id UUID,
    ADD COLUMN IF NOT EXISTS asset_no VARCHAR(128),
    ADD COLUMN IF NOT EXISTS name VARCHAR(256),
    ADD COLUMN IF NOT EXISTS specification VARCHAR(1000),
    ADD COLUMN IF NOT EXISTS serial_no VARCHAR(128),
    ADD COLUMN IF NOT EXISTS asset_type VARCHAR(32) NOT NULL DEFAULT 'FIXED',
    ADD COLUMN IF NOT EXISTS status VARCHAR(32) NOT NULL DEFAULT 'DRAFT',
    ADD COLUMN IF NOT EXISTS quantity NUMERIC(14, 3) NOT NULL DEFAULT 1,
    ADD COLUMN IF NOT EXISTS acquisition_date TIMESTAMP(6) WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS acquisition_amount NUMERIC(14, 2) NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS currency VARCHAR(3) NOT NULL DEFAULT 'CNY',
    ADD COLUMN IF NOT EXISTS supplier VARCHAR(256),
    ADD COLUMN IF NOT EXISTS location VARCHAR(256),
    ADD COLUMN IF NOT EXISTS custodian_id UUID,
    ADD COLUMN IF NOT EXISTS warranty_until TIMESTAMP(6) WITH TIME ZONE,
    ADD COLUMN IF NOT EXISTS source_purchase_id UUID,
    ADD COLUMN IF NOT EXISTS source_receipt_id UUID,
    ADD COLUMN IF NOT EXISTS source_purchase_item_id UUID,
    ADD COLUMN IF NOT EXISTS remark VARCHAR(1000);

CREATE TABLE IF NOT EXISTS spectra_oa.oa_asset_category (
    id          UUID PRIMARY KEY,
    pid         UUID,
    code        VARCHAR(64) NOT NULL,
    name        VARCHAR(128) NOT NULL,
    asset_type  VARCHAR(32) NOT NULL DEFAULT 'FIXED',
    sort        INTEGER NOT NULL DEFAULT 0,
    enabled     BOOLEAN NOT NULL DEFAULT TRUE,
    description VARCHAR(500),
    created_by  UUID,
    created_at  TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by  UUID,
    updated_at  TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted     TIMESTAMP(6) WITH TIME ZONE,
    version     BIGINT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS spectra_oa.oa_asset_operation (
    id                  UUID PRIMARY KEY,
    asset_id            UUID NOT NULL,
    operation_type      VARCHAR(32) NOT NULL,
    from_department_id  UUID,
    to_department_id    UUID,
    from_user_id        UUID,
    to_user_id          UUID,
    from_location       VARCHAR(256),
    to_location         VARCHAR(256),
    operation_date      TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    reason              VARCHAR(1000),
    maintenance_content VARCHAR(2000),
    maintenance_cost   NUMERIC(14, 2),
    status              VARCHAR(32) NOT NULL DEFAULT 'COMPLETE',
    created_by          UUID,
    created_at          TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by          UUID,
    updated_at          TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted             TIMESTAMP(6) WITH TIME ZONE,
    version             BIGINT DEFAULT 0
);

CREATE UNIQUE INDEX IF NOT EXISTS uk_oa_asset_asset_no
    ON spectra_oa.oa_asset (asset_no)
    WHERE deleted IS NULL AND asset_no IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS uk_oa_asset_category_code
    ON spectra_oa.oa_asset_category (code)
    WHERE deleted IS NULL;
CREATE INDEX IF NOT EXISTS idx_oa_asset_status_department
    ON spectra_oa.oa_asset (status, department_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_oa_asset_source_receipt_item
    ON spectra_oa.oa_asset (source_receipt_id, source_purchase_item_id);
CREATE INDEX IF NOT EXISTS idx_oa_asset_operation_asset_date
    ON spectra_oa.oa_asset_operation (asset_id, operation_date DESC, created_at DESC);

INSERT INTO spectra_oa.oa_asset_category
    (id, code, name, asset_type, sort, enabled, created_at, updated_at, version)
VALUES
    ('00000000-0000-0000-0000-000000000101', 'OFFICE_EQUIPMENT', '办公设备', 'FIXED', 10, TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 0),
    ('00000000-0000-0000-0000-000000000102', 'IT_EQUIPMENT', '信息设备', 'FIXED', 20, TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 0),
    ('00000000-0000-0000-0000-000000000103', 'FURNITURE', '办公家具', 'FIXED', 30, TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 0),
    ('00000000-0000-0000-0000-000000000104', 'VEHICLE', '车辆', 'FIXED', 40, TRUE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 0)
ON CONFLICT DO NOTHING;
