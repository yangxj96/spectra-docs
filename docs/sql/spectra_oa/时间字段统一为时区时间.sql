-- 将历史 DATE 字段迁移为带时区的时间戳，和 Java Instant 保持一致。
-- 历史日期没有时区信息，统一按 UTC 当日零点解释；迁移后由 TimeMapper 按用户时区展示。

ALTER TABLE spectra_oa.oa_contract
    ALTER COLUMN start_date TYPE TIMESTAMP(6) WITH TIME ZONE
        USING start_date::timestamp AT TIME ZONE 'UTC',
    ALTER COLUMN end_date TYPE TIMESTAMP(6) WITH TIME ZONE
        USING end_date::timestamp AT TIME ZONE 'UTC';

ALTER TABLE spectra_oa.oa_contract_milestone
    ALTER COLUMN due_date TYPE TIMESTAMP(6) WITH TIME ZONE
        USING due_date::timestamp AT TIME ZONE 'UTC';

ALTER TABLE spectra_oa.oa_attendance_record
    ALTER COLUMN attendance_date TYPE TIMESTAMP(6) WITH TIME ZONE
        USING attendance_date::timestamp AT TIME ZONE 'UTC';

ALTER TABLE spectra_oa.oa_asset
    ALTER COLUMN acquisition_date TYPE TIMESTAMP(6) WITH TIME ZONE
        USING acquisition_date::timestamp AT TIME ZONE 'UTC',
    ALTER COLUMN warranty_until TYPE TIMESTAMP(6) WITH TIME ZONE
        USING warranty_until::timestamp AT TIME ZONE 'UTC';

ALTER TABLE spectra_oa.oa_asset_operation
    ALTER COLUMN operation_date TYPE TIMESTAMP(6) WITH TIME ZONE
        USING operation_date::timestamp AT TIME ZONE 'UTC';

ALTER TABLE spectra_oa.oa_supply_operation
    ALTER COLUMN operation_date TYPE TIMESTAMP(6) WITH TIME ZONE
        USING operation_date::timestamp AT TIME ZONE 'UTC';

ALTER TABLE spectra_oa.oa_purchase
    ALTER COLUMN expected_date TYPE TIMESTAMP(6) WITH TIME ZONE
        USING expected_date::timestamp AT TIME ZONE 'UTC';

ALTER TABLE spectra_oa.oa_purchase_receipt
    ALTER COLUMN received_date TYPE TIMESTAMP(6) WITH TIME ZONE
        USING received_date::timestamp AT TIME ZONE 'UTC';

ALTER TABLE spectra_oa.oa_reimbursement
    ALTER COLUMN expense_start TYPE TIMESTAMP(6) WITH TIME ZONE
        USING expense_start::timestamp AT TIME ZONE 'UTC',
    ALTER COLUMN expense_end TYPE TIMESTAMP(6) WITH TIME ZONE
        USING expense_end::timestamp AT TIME ZONE 'UTC';

ALTER TABLE spectra_oa.oa_reimbursement_item
    ALTER COLUMN expense_date TYPE TIMESTAMP(6) WITH TIME ZONE
        USING expense_date::timestamp AT TIME ZONE 'UTC';
