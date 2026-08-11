-- 账号状态安全基线迁移（可重复执行、非破坏性）。
-- status=0 的历史账号不再被解释为“正常”，统一转为“必须重置密码”；
-- 用户 status=0 保持禁用，避免未经人工确认扩大登录范围。
BEGIN;

UPDATE spectra_core.sys_account
SET status = 4
WHERE deleted IS NULL
  AND status = 0;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_sys_account_status') THEN
        ALTER TABLE spectra_core.sys_account
            ADD CONSTRAINT ck_sys_account_status CHECK (status IN (1, 2, 3, 4));
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'ck_sys_user_status') THEN
        ALTER TABLE spectra_core.sys_user
            ADD CONSTRAINT ck_sys_user_status CHECK (status IN (0, 1));
    END IF;
END $$;

COMMENT ON COLUMN spectra_core.sys_account.status IS '账号状态：1-正常可登录，2-禁用，3-未验证，4-必须重置密码';
COMMENT ON COLUMN spectra_core.sys_user.status IS '用户状态：0-禁用，1-正常';

COMMIT;
