-- Run after importing the large sys_region reference seed from db.dump.
-- Flyway V24/V25 normalize all ordinary Core/Security/OA seeds; the region import
-- happens after Flyway and therefore needs this explicit post-import step.
UPDATE spectra_core.sys_region
SET created_by = '00000000-0000-0000-0000-000000000000'::uuid,
    created_at = TIMESTAMPTZ '1996-10-15 00:00:00+08:00',
    updated_by = '00000000-0000-0000-0000-000000000000'::uuid,
    updated_at = TIMESTAMPTZ '1996-10-15 00:00:00+08:00'
WHERE created_by IS NULL AND updated_by IS NULL;
