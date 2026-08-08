-- 将历史 DATE/TIME 字段迁移为带时区的时间戳，和 Java Instant 保持一致。
-- 历史字段没有时区信息，统一按 UTC 解释；迁移后由 TimeMapper 按用户时区展示。

ALTER TABLE spectra_core.sys_user
    ALTER COLUMN birthday TYPE TIMESTAMP(6) WITH TIME ZONE
        USING birthday::timestamp AT TIME ZONE 'UTC';

ALTER TABLE spectra_core.sys_notification_setting
    ALTER COLUMN do_not_disturb_start TYPE TIMESTAMP(6) WITH TIME ZONE
        USING (CURRENT_DATE + do_not_disturb_start) AT TIME ZONE 'UTC',
    ALTER COLUMN do_not_disturb_end TYPE TIMESTAMP(6) WITH TIME ZONE
        USING (CURRENT_DATE + do_not_disturb_end) AT TIME ZONE 'UTC';
