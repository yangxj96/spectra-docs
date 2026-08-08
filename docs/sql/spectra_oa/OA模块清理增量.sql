-- 通用 OA 模块收敛：移除无数据、无业务字段、已被真实能力替代的旧脚手架表。
-- 执行前已确认本地开发库三张表均为 0 行。
DROP TABLE IF EXISTS spectra_oa.oa_attendance;
DROP TABLE IF EXISTS spectra_oa.oa_contact;
DROP TABLE IF EXISTS spectra_oa.oa_report;
