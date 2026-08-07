-- P1 阶段 3：办公用品库存 MVP
CREATE TABLE IF NOT EXISTS spectra_oa.oa_supply_item (
    id            UUID PRIMARY KEY,
    category      VARCHAR(128),
    sku           VARCHAR(128) NOT NULL,
    name          VARCHAR(256) NOT NULL,
    specification VARCHAR(1000),
    unit          VARCHAR(32) NOT NULL DEFAULT '件',
    current_stock NUMERIC(14, 3) NOT NULL DEFAULT 0,
    min_stock     NUMERIC(14, 3) NOT NULL DEFAULT 0,
    status        VARCHAR(32) NOT NULL DEFAULT 'ACTIVE',
    supplier      VARCHAR(256),
    location      VARCHAR(256),
    department_id UUID,
    remark        VARCHAR(1000),
    created_by    UUID,
    created_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by    UUID,
    updated_at    TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted       TIMESTAMP(6) WITH TIME ZONE,
    version       BIGINT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS spectra_oa.oa_supply_operation (
    id                     UUID PRIMARY KEY,
    supply_id              UUID NOT NULL,
    operation_type         VARCHAR(32) NOT NULL,
    quantity               NUMERIC(14, 3) NOT NULL,
    before_stock           NUMERIC(14, 3) NOT NULL,
    after_stock            NUMERIC(14, 3) NOT NULL,
    department_id          UUID,
    user_id                UUID,
    location               VARCHAR(256),
    operation_date         DATE NOT NULL,
    reason                 VARCHAR(1000),
    source_purchase_id     UUID,
    source_receipt_id      UUID,
    source_purchase_item_id UUID,
    status                 VARCHAR(32) NOT NULL DEFAULT 'COMPLETE',
    created_by             UUID,
    created_at             TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by             UUID,
    updated_at             TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted                TIMESTAMP(6) WITH TIME ZONE,
    version                BIGINT DEFAULT 0
);

CREATE UNIQUE INDEX IF NOT EXISTS uk_oa_supply_item_sku
    ON spectra_oa.oa_supply_item (sku)
    WHERE deleted IS NULL;
CREATE INDEX IF NOT EXISTS idx_oa_supply_item_stock
    ON spectra_oa.oa_supply_item (status, current_stock, min_stock, name);
CREATE INDEX IF NOT EXISTS idx_oa_supply_operation_supply_date
    ON spectra_oa.oa_supply_operation (supply_id, operation_date DESC, created_at DESC);
