BEGIN;
ALTER TABLE spectra_notification.ntf_task ADD COLUMN IF NOT EXISTS title VARCHAR(500);
ALTER TABLE spectra_notification.ntf_task ADD COLUMN IF NOT EXISTS content TEXT;
UPDATE spectra_notification.ntf_task SET title = COALESCE(title, ''), content = COALESCE(content, '')
WHERE title IS NULL OR content IS NULL;
ALTER TABLE spectra_notification.ntf_task ALTER COLUMN title SET NOT NULL;
ALTER TABLE spectra_notification.ntf_task ALTER COLUMN content SET NOT NULL;
COMMENT ON COLUMN spectra_notification.ntf_task.title IS '已渲染通知标题';
COMMENT ON COLUMN spectra_notification.ntf_task.content IS '已渲染通知正文';
COMMIT;
