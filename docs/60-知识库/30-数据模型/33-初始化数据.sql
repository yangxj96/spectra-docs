-- ============================================
-- Spectra 初始化数据
-- 包含：部门、角色、权限、菜单关联、用户、账号、字典、配置
-- 执行顺序：先建表，再执行本文件
-- 测试账号密码：admin123
-- ============================================

-- ============================================
-- 部门
-- ============================================

-- 光谱平台（根部门）
INSERT INTO spectra_core.sys_department (id, name, code, sort, created_at, updated_at)
VALUES ('019bdfdd-b58d-7232-943f-af4141801ae3', '光谱平台', '5BC060C067A66715107B46D020F4471A', 1, NOW(), NOW());

-- 子部门
INSERT INTO spectra_core.sys_department (id, pid, name, code, sort, created_at, updated_at) VALUES
('019bdfdd-ee9a-7581-ab10-61319ec0753a', '019bdfdd-b58d-7232-943f-af4141801ae3', '系统运维', '8143D9BB4521ACEA166E80DB69735CC6', 0, NOW(), NOW()),
('019bdfde-1c33-77d0-a4a7-4369459486c4', '019bdfdd-b58d-7232-943f-af4141801ae3', '云南分公司', '4A07E7E44BD882D01750E6077A3ABE87', 0, NOW(), NOW()),
('019bdfde-395a-7389-8172-be898f21d020', '019bdfde-1c33-77d0-a4a7-4369459486c4', '昆明分公司', 'A14F626FFE5A56928DA137200717401A', 0, NOW(), NOW()),
('019bdfde-4fe0-7026-9c07-b5f3cdebfa38', '019bdfde-1c33-77d0-a4a7-4369459486c4', '保山分公司', '5A0C052C7A3D38102BDE26641E2F298F', 1, NOW(), NOW()),
('019bdfdf-04cb-745f-89f1-1b25e43b5698', '019bdfdd-b58d-7232-943f-af4141801ae3', '财务部', '3194B8EF87466CE3914DAA4F509E991E', 0, NOW(), NOW()),
('019bdfdf-2446-78ae-94e0-283ba2a8a563', '019bdfdd-b58d-7232-943f-af4141801ae3', '人事部', '7F9B8256D46B25C5954EC90FFAF19454', 0, NOW(), NOW()),
('019bdfdf-55c2-7d73-b92c-057c3a8c6e7a', '019bdfdd-ee9a-7581-ab10-61319ec0753a', '调度小组', 'C8BB1EAC451144A524067D24DD051CF1', 0, NOW(), NOW()),
('019bdfdf-72b0-714e-af05-78d48689864a', '019bdfdd-ee9a-7581-ab10-61319ec0753a', '测试小组', '472C6E86C39491DF9AA7614641145065', 0, NOW(), NOW());

-- ============================================
-- 角色
-- ============================================

INSERT INTO spectra_core.sys_role (id, name, code, state, builtin, created_at, updated_at) VALUES
('019bdfad-ded6-731e-b27f-c4e7ca7b0d9d', '运维管理员', 'ROLE_DEV_OPS', TRUE, TRUE, NOW(), NOW()),
('019bdfad-df4b-7c16-9f95-a68f9a38a51b', '系统管理员', 'ROLE_ADMIN_SYSTEM', TRUE, TRUE, NOW(), NOW()),
('019bdfad-df4d-7133-b6db-199c0e86b72b', '用户', 'ROLE_USER', TRUE, TRUE, NOW(), NOW()),
('019bdfad-df4f-7110-b2ce-9eecc82bf46b', '审计员', 'ROLE_AUDIT', TRUE, TRUE, NOW(), NOW());

-- ============================================
-- 权限
-- ============================================

-- 顶级权限
INSERT INTO spectra_core.sys_authority (id, pid, name, code, created_at, updated_at) VALUES
('019bdf8f-6542-7b9b-8fc7-2eae5b1a4c94', NULL, '顶级权限', '*', NOW(), NOW());

-- 一级权限
INSERT INTO spectra_core.sys_authority (id, pid, name, code, created_at, updated_at) VALUES
('019bdf8f-6563-728e-8fb4-0b6b77e87de7', '019bdf8f-6542-7b9b-8fc7-2eae5b1a4c94', '菜单权限', 'MENU:*', NOW(), NOW()),
('019bdf8f-6564-73e4-b9ad-f4f36250d4a5', '019bdf8f-6542-7b9b-8fc7-2eae5b1a4c94', '字典管理', 'DICT:*', NOW(), NOW()),
('019bdf8f-6566-7223-87cc-0a6f50434579', '019bdf8f-6542-7b9b-8fc7-2eae5b1a4c94', '部门管理', 'DEPT:*', NOW(), NOW()),
('019bdf8f-6566-7223-87cd-87dbcc2326cb', '019bdf8f-6542-7b9b-8fc7-2eae5b1a4c94', '用户管理', 'USER:*', NOW(), NOW());

-- 二级权限
INSERT INTO spectra_core.sys_authority (id, pid, name, code, created_at, updated_at) VALUES
('019bdf8f-656c-7b4b-aa6f-f05ae97ff563', '019bdf8f-6563-728e-8fb4-0b6b77e87de7', '菜单新增', 'MENU:INSERT', NOW(), NOW()),
('019bdf8f-656d-7592-8ab1-ffe539bb695e', '019bdf8f-6563-728e-8fb4-0b6b77e87de7', '菜单修改', 'MENU:UPDATE', NOW(), NOW()),
('019bdf8f-656e-74b6-ab1a-41ce6ce22cf2', '019bdf8f-6563-728e-8fb4-0b6b77e87de7', '菜单删除', 'MENU:DELETE', NOW(), NOW()),
('019bdf8f-656f-7346-a28b-8bf16af555f3', '019bdf8f-6564-73e4-b9ad-f4f36250d4a5', '字典新增', 'DICT:INSERT', NOW(), NOW()),
('019bdf8f-6572-7480-a8f9-21d5c04482c1', '019bdf8f-6564-73e4-b9ad-f4f36250d4a5', '字典删除', 'DICT:DELETE', NOW(), NOW()),
('019bdf8f-6575-7f1f-af89-9c8962284585', '019bdf8f-6564-73e4-b9ad-f4f36250d4a5', '字典修改', 'DICT:UPDATE', NOW(), NOW()),
('019bdf8f-6578-7934-835f-95dabf4e16d0', '019bdf8f-6566-7223-87cc-0a6f50434579', '部门新增', 'DEPT:INSERT', NOW(), NOW()),
('019bdf8f-657b-72a2-9667-3fc36dcc701b', '019bdf8f-6566-7223-87cc-0a6f50434579', '部门删除', 'DEPT:DELETE', NOW(), NOW()),
('019bdf8f-657d-7e14-96c5-33b987552a24', '019bdf8f-6566-7223-87cc-0a6f50434579', '部门修改', 'DEPT:UPDATE', NOW(), NOW()),
('019bdf8f-6580-779d-922d-5c318eb945d8', '019bdf8f-6566-7223-87cd-87dbcc2326cb', '用户新增', 'USER:INSERT', NOW(), NOW()),
('019bdf8f-6583-7f1f-939e-3768f6da693b', '019bdf8f-6566-7223-87cd-87dbcc2326cb', '用户删除', 'USER:DELETE', NOW(), NOW()),
('019bdf8f-6585-7ba3-b71c-f04590393627', '019bdf8f-6566-7223-87cd-87dbcc2326cb', '用户修改', 'USER:UPDATE', NOW(), NOW());

-- ============================================
-- 角色-权限关联
-- ============================================

-- 运维管理员：拥有所有权限
INSERT INTO spectra_core.sys_rel_role_authority (id, role_id, authority_id, created_at, updated_at) VALUES
('019bdfb6-fd8e-7823-ba61-5727e999b7ca', '019bdfad-ded6-731e-b27f-c4e7ca7b0d9d', '019bdf8f-6542-7b9b-8fc7-2eae5b1a4c94', NOW(), NOW());

-- 系统管理员：拥有所有权限
INSERT INTO spectra_core.sys_rel_role_authority (id, role_id, authority_id, created_at, updated_at) VALUES
('019bdfef-b0fb-7e21-a7c6-d218c51fa808', '019bdfad-df4b-7c16-9f95-a68f9a38a51b', '019bdf8f-6542-7b9b-8fc7-2eae5b1a4c94', NOW(), NOW());

-- 审计员：拥有所有权限
INSERT INTO spectra_core.sys_rel_role_authority (id, role_id, authority_id, created_at, updated_at) VALUES
('019bdff0-134d-7ace-b8db-e5ce5f306084', '019bdfad-df4f-7110-b2ce-9eecc82bf46b', '019bdf8f-6542-7b9b-8fc7-2eae5b1a4c94', NOW(), NOW());

-- 用户角色：拥有用户管理权限
INSERT INTO spectra_core.sys_rel_role_authority (id, role_id, authority_id, created_at, updated_at) VALUES
('019da4a2-9f47-75ec-aa7a-356c47e9a978', '019bdfad-df4d-7133-b6db-199c0e86b72b', '019bdf8f-6566-7223-87cd-87dbcc2326cb', NOW(), NOW());

-- ============================================
-- 用户
-- ============================================

-- 运维人员
INSERT INTO spectra_core.sys_user (id, username, real_name, department_id, status, language, timezone, created_at, updated_at)
VALUES ('019bdfa5-e3fc-7ec8-b49f-b2738e64ff21', '运维人员', '运维人员', '019bdfdd-ee9a-7581-ab10-61319ec0753a', 0, 'zh-CN', 'Asia/Shanghai', NOW(), NOW());

-- 系统管理员
INSERT INTO spectra_core.sys_user (id, username, real_name, department_id, status, language, timezone, created_at, updated_at)
VALUES ('019bdfec-3202-764d-a1fc-d44c05c72db2', '系统管理员', '系统管理员', '019bdfdd-b58d-7232-943f-af4141801ae3', 0, 'zh-CN', 'Asia/Shanghai', NOW(), NOW());

-- 普通用户
INSERT INTO spectra_core.sys_user (id, username, real_name, department_id, status, language, timezone, created_at, updated_at)
VALUES ('019bdfec-d334-7278-985c-44cfaa9b1a68', '普通用户', '普通用户', '019bdfde-1c33-77d0-a4a7-4369459486c4', 0, 'zh-CN', 'Asia/Shanghai', NOW(), NOW());

-- 审计用户
INSERT INTO spectra_core.sys_user (id, username, real_name, department_id, status, language, timezone, created_at, updated_at)
VALUES ('019bdfed-7ef5-7026-a8f0-c0c987653bee', '审计用户', '审计用户', '019bdfdd-b58d-7232-943f-af4141801ae3', 0, 'zh-CN', 'Asia/Shanghai', NOW(), NOW());

-- ============================================
-- 账号（密码均为 admin123）
-- ============================================

INSERT INTO spectra_core.sys_account (id, user_id, type, login_name, password, status, created_at, updated_at) VALUES
('019bdfa5-e4cc-7f46-bc0c-8559c2a2f3d2', '019bdfa5-e3fc-7ec8-b49f-b2738e64ff21', 1, 'devops@devops00.com', '$2a$10$EqKcp1WFKVQISheBxnFOheYMKMeFSmVPfaAJMRPIlVtMVaKMr8yLq', 0, NOW(), NOW()),
('019bdfec-3275-7032-9bd9-c854be37aad4', '019bdfec-3202-764d-a1fc-d44c05c72db2', 1, 'admin@devops00.com', '$2a$10$EqKcp1WFKVQISheBxnFOheYMKMeFSmVPfaAJMRPIlVtMVaKMr8yLq', 0, NOW(), NOW()),
('019bdfec-d39e-7cda-874e-fe410ff4783d', '019bdfec-d334-7278-985c-44cfaa9b1a68', 1, 'user@devops00.com', '$2a$10$EqKcp1WFKVQISheBxnFOheYMKMeFSmVPfaAJMRPIlVtMVaKMr8yLq', 0, NOW(), NOW()),
('019bdfed-7f69-7d3a-86e5-d442f990bc61', '019bdfed-7ef5-7026-a8f0-c0c987653bee', 1, 'audit@devops00.com', '$2a$10$EqKcp1WFKVQISheBxnFOheYMKMeFSmVPfaAJMRPIlVtMVaKMr8yLq', 0, NOW(), NOW());

-- ============================================
-- 用户-角色关联
-- ============================================

INSERT INTO spectra_core.sys_rel_user_role (id, user_id, role_id, created_at, updated_at) VALUES
('019bdfa5-e4f5-7134-b894-a6e6401e3b32', '019bdfa5-e3fc-7ec8-b49f-b2738e64ff21', '019bdfad-ded6-731e-b27f-c4e7ca7b0d9d', NOW(), NOW()),
('019bdfec-3287-70f2-9f02-ac22040035dd', '019bdfec-3202-764d-a1fc-d44c05c72db2', '019bdfad-df4b-7c16-9f95-a68f9a38a51b', NOW(), NOW()),
('019bdfec-d3a6-7f41-b394-7382a4ca71bc', '019bdfec-d334-7278-985c-44cfaa9b1a68', '019bdfad-df4d-7133-b6db-199c0e86b72b', NOW(), NOW()),
('019bdfed-7f70-7bd0-a607-226070dca099', '019bdfed-7ef5-7026-a8f0-c0c987653bee', '019bdfad-df4f-7110-b2ce-9eecc82bf46b', NOW(), NOW());

-- ============================================
-- 字典组
-- ============================================

INSERT INTO spectra_core.sys_dict_group (id, name, code, created_at, updated_at) VALUES
('019bdfd1-02a5-73f1-be0f-4bd3c53306e0', 'OA相关', 'oa', NOW(), NOW()),
('019bdfd1-01ca-7fc2-81df-45019d3b1672', '系统配置', 'sys', NOW(), NOW()),
('019bdfd1-02e9-7570-a250-d3c48bd15fff', '用户状态', 'sys_user_state', NOW(), NOW()),
('019bdfd1-02ec-7305-bb8b-ab958b70b6c7', '通用状态', 'sys_common_state', NOW(), NOW()),
('019bdfd1-02ee-7a8c-b71c-fdebcfd30441', '组织机构类型', 'sys_organization_type', NOW(), NOW()),
('019bdfd1-02f2-74ee-aa27-116d0ae87c42', '用户性别', 'sys_user_gender', NOW(), NOW()),
('019bdfd1-02f5-7fbd-9ad6-bec21e763338', '时区', 'sys_timezone', NOW(), NOW()),
('019bdfd1-02f9-74a3-a177-b07ba13b2f8d', '语言', 'sys_language', NOW(), NOW()),
('019bdfd1-02fc-7881-870d-91e9b209218c', '邮箱后缀', 'sys_email_suffix', NOW(), NOW()),
('019bdfd1-02ff-746e-a7b2-df0bfa44e659', '水印类型', 'sys_watermark', NOW(), NOW()),
('019bdfd1-02e3-7a4f-a6cf-826d04d5a4cb', '流程分类', 'dict_workflow_type', NOW(), NOW()),
('019f2d5d-88a9-76e4-ba98-1ece06cbcf08', '行政区划级别', 'sys_region_level', NOW(), NOW());

-- ============================================
-- 字典项
-- ============================================

-- 用户状态
INSERT INTO spectra_core.sys_dict_item (id, gid, label, value, sort, state, created_at, updated_at) VALUES
('019bdfdc-92dd-789f-bf23-78a6a309c61f', '019bdfd1-02e9-7570-a250-d3c48bd15fff', '正常', '0', 1, 0, NOW(), NOW()),
('019bdfdc-92e3-7199-b91b-a730bea38304', '019bdfd1-02e9-7570-a250-d3c48bd15fff', '冻结', '1', 2, 0, NOW(), NOW()),
('019bdfdc-92e5-7647-9ca7-3df8f956928e', '019bdfd1-02e9-7570-a250-d3c48bd15fff', '封禁', '2', 3, 0, NOW(), NOW());

-- 通用状态
INSERT INTO spectra_core.sys_dict_item (id, gid, label, value, sort, state, created_at, updated_at) VALUES
('019bdfdc-92e9-7e06-bec2-94323686d9be', '019bdfd1-02ec-7305-bb8b-ab958b70b6c7', '启用', '0', 1, 0, NOW(), NOW()),
('019bdfdc-92ec-78dc-bf95-f9fbb122adb5', '019bdfd1-02ec-7305-bb8b-ab958b70b6c7', '禁用', '1', 2, 0, NOW(), NOW());

-- 用户性别
INSERT INTO spectra_core.sys_dict_item (id, gid, label, value, sort, state, created_at, updated_at) VALUES
('019bdfdc-92fe-7799-97cc-46a6004ce2b7', '019bdfd1-02f2-74ee-aa27-116d0ae87c42', '未知', '1', 1, 0, NOW(), NOW()),
('019bdfdc-9301-7451-850c-6b0b15149ca0', '019bdfd1-02f2-74ee-aa27-116d0ae87c42', '男性', '2', 2, 0, NOW(), NOW()),
('019bdfdc-9303-7fbe-9647-25f7ed0008c9', '019bdfd1-02f2-74ee-aa27-116d0ae87c42', '女性', '3', 3, 0, NOW(), NOW());

-- 组织机构类型
INSERT INTO spectra_core.sys_dict_item (id, gid, label, value, sort, state, created_at, updated_at) VALUES
('019bdfdc-92f1-7a96-b602-c820e6a1efbc', '019bdfd1-02ee-7a8c-b71c-fdebcfd30441', '集团总部', '1', 1, 0, NOW(), NOW()),
('019bdfdc-92f4-7d7d-9868-c7387336c9d1', '019bdfd1-02ee-7a8c-b71c-fdebcfd30441', '省级公司', '2', 2, 0, NOW(), NOW()),
('019bdfdc-92f6-7ce0-9876-b265f6dba3ae', '019bdfd1-02ee-7a8c-b71c-fdebcfd30441', '市级公司', '3', 3, 0, NOW(), NOW()),
('019bdfdc-92f8-7a70-aa29-864107dea7dc', '019bdfd1-02ee-7a8c-b71c-fdebcfd30441', '县级公司', '4', 4, 0, NOW(), NOW()),
('019bdfdc-92fa-76cf-87a3-5b030e71a57c', '019bdfd1-02ee-7a8c-b71c-fdebcfd30441', '部门', '5', 5, 0, NOW(), NOW()),
('019bdfdc-92fc-7017-855c-fc0655ac2324', '019bdfd1-02ee-7a8c-b71c-fdebcfd30441', '科室/小组', '6', 6, 0, NOW(), NOW()),
('019bdfdc-92ef-706b-aebb-e9a8865e7e0d', '019bdfd1-02ee-7a8c-b71c-fdebcfd30441', '系统运维', '0', 999, 0, NOW(), NOW());

-- 语言
INSERT INTO spectra_core.sys_dict_item (id, gid, label, value, sort, state, created_at, updated_at) VALUES
('019bdfdc-9337-77aa-a8dc-3042514400c1', '019bdfd1-02f9-74a3-a177-b07ba13b2f8d', '中文（简体）', 'zh-CN', 1, 0, NOW(), NOW()),
('019bdfdc-933a-7755-b511-9a18c352f209', '019bdfd1-02f9-74a3-a177-b07ba13b2f8d', '中文（繁体）', 'zh-TW', 2, 0, NOW(), NOW()),
('019bdfdc-933d-7f5e-b9f4-d1a20824476e', '019bdfd1-02f9-74a3-a177-b07ba13b2f8d', '英语', 'en', 3, 0, NOW(), NOW());

-- 邮箱后缀
INSERT INTO spectra_core.sys_dict_item (id, gid, label, value, sort, state, created_at, updated_at) VALUES
('019bdfdc-9363-7ece-8500-b710a4681417', '019bdfd1-02fc-7881-870d-91e9b209218c', 'devops', 'devops00.com', 1, 0, NOW(), NOW()),
('019bdfdc-9365-7e3b-abab-8965e099d6e0', '019bdfd1-02fc-7881-870d-91e9b209218c', '谷歌邮箱', 'gmail.com', 2, 0, NOW(), NOW()),
('019bdfdc-9366-7a1f-a36f-5661d435593c', '019bdfd1-02fc-7881-870d-91e9b209218c', 'QQ邮箱', 'qq.com', 3, 0, NOW(), NOW());

-- 行政区划级别
INSERT INTO spectra_core.sys_dict_item (id, gid, label, value, sort, state, created_at, updated_at) VALUES
('019f2d60-d310-77dc-b392-d6428a075c51', '019f2d5d-88a9-76e4-ba98-1ece06cbcf08', '省级', 'PROVINCES', 0, 0, NOW(), NOW()),
('019f2d61-17d0-7bfa-9b2a-8e9650e65c89', '019f2d5d-88a9-76e4-ba98-1ece06cbcf08', '市级', 'CITIES', 1, 0, NOW(), NOW()),
('019f2d61-ba2b-795e-8de9-8e6969f2e49d', '019f2d5d-88a9-76e4-ba98-1ece06cbcf08', '县级', 'AREAS', 2, 0, NOW(), NOW()),
('019f2d62-5fd4-7800-bc53-564c95a1e28e', '019f2d5d-88a9-76e4-ba98-1ece06cbcf08', '乡镇街道', 'STREETS', 3, 0, NOW(), NOW()),
('019f2d61-66b5-7b9c-832b-c1f3b9a0dc6f', '019f2d5d-88a9-76e4-ba98-1ece06cbcf08', '村委会', 'VILLAGES', 4, 0, NOW(), NOW());

-- ============================================
-- 系统配置（不含 RSA 密钥对，需通过应用生成）
-- ============================================

INSERT INTO spectra_core.sys_config (id, key, value, type, remarks, created_at, updated_at) VALUES
('019f5a38-0e74-7148-814b-9f0c2ef0597b', 'crypto.enabled', 'true', 0, 'RSA密钥对自动生成', NOW(), NOW());
