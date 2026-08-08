-- P1 阶段 3 采购申请增量 SQL
-- 可重复执行；流程定义由 spectra-workflow 自动部署。

CREATE TABLE IF NOT EXISTS spectra_oa.oa_purchase (
    id                  UUID PRIMARY KEY,
    application_id      UUID NOT NULL UNIQUE,
    department_id       UUID,
    purpose             VARCHAR(2000) NOT NULL,
    expected_date       TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    budget_amount       NUMERIC(14, 2) NOT NULL,
    currency            VARCHAR(3) NOT NULL DEFAULT 'CNY',
    suggested_supplier  VARCHAR(256),
    execution_status    VARCHAR(32) NOT NULL DEFAULT 'NOT_STARTED',
    purchaser_id        UUID,
    order_no            VARCHAR(128),
    ordered_at          TIMESTAMP(6) WITH TIME ZONE,
    completed_at        TIMESTAMP(6) WITH TIME ZONE,
    execution_remark    VARCHAR(1000),
    created_by          UUID,
    created_at          TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by          UUID,
    updated_at          TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted             TIMESTAMP(6) WITH TIME ZONE,
    version             BIGINT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS spectra_oa.oa_purchase_item (
    id                    UUID PRIMARY KEY,
    purchase_id           UUID NOT NULL,
    department_id         UUID,
    item_type             VARCHAR(32) NOT NULL,
    item_name             VARCHAR(256) NOT NULL,
    specification         VARCHAR(1000),
    quantity              NUMERIC(14, 3) NOT NULL,
    estimated_unit_price  NUMERIC(14, 2) NOT NULL DEFAULT 0,
    estimated_amount      NUMERIC(14, 2) NOT NULL DEFAULT 0,
    purpose               VARCHAR(500),
    received_quantity     NUMERIC(14, 3) NOT NULL DEFAULT 0,
    created_by            UUID,
    created_at            TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by            UUID,
    updated_at            TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted               TIMESTAMP(6) WITH TIME ZONE,
    version               BIGINT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS spectra_oa.oa_purchase_receipt (
    id              UUID PRIMARY KEY,
    purchase_id     UUID NOT NULL,
    receipt_no      VARCHAR(128) NOT NULL,
    received_date   TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    receiver_id     UUID,
    status          VARCHAR(32) NOT NULL DEFAULT 'PARTIAL',
    remark          VARCHAR(1000),
    created_by      UUID,
    created_at      TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by      UUID,
    updated_at      TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted         TIMESTAMP(6) WITH TIME ZONE,
    version         BIGINT DEFAULT 0
);

CREATE TABLE IF NOT EXISTS spectra_oa.oa_purchase_receipt_item (
    id                UUID PRIMARY KEY,
    receipt_id        UUID NOT NULL,
    purchase_item_id  UUID NOT NULL,
    quantity          NUMERIC(14, 3) NOT NULL,
    accepted          BOOLEAN NOT NULL DEFAULT TRUE,
    difference_reason VARCHAR(1000),
    created_by        UUID,
    created_at        TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by        UUID,
    updated_at        TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted           TIMESTAMP(6) WITH TIME ZONE,
    version           BIGINT DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_oa_purchase_department_status
    ON spectra_oa.oa_purchase (department_id, execution_status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_oa_purchase_item_purchase
    ON spectra_oa.oa_purchase_item (purchase_id, created_at);
CREATE INDEX IF NOT EXISTS idx_oa_purchase_receipt_purchase
    ON spectra_oa.oa_purchase_receipt (purchase_id, received_date DESC);
CREATE UNIQUE INDEX IF NOT EXISTS uk_oa_purchase_receipt_no
    ON spectra_oa.oa_purchase_receipt (receipt_no)
    WHERE deleted IS NULL;
CREATE INDEX IF NOT EXISTS idx_oa_purchase_receipt_item_receipt
    ON spectra_oa.oa_purchase_receipt_item (receipt_id);

INSERT INTO spectra_oa.oa_application_type
    (id, code, name, process_definition_key, enabled, sort_order, description,
     created_at, updated_at, version)
VALUES
    ('00000000-0000-0000-0000-000000000003', 'purchase', '采购申请', 'oa_purchase_approval', TRUE, 30,
     'P1 采购申请审批', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, 0)
ON CONFLICT (code) DO NOTHING;
