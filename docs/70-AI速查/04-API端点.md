---
tags:
  - ai
  - api
  - reference
---

# API 端点

> 源码当前 47 个 `*Controller.java` 端点速查表。

当前所有 REST Mapping 统一使用 API 版本 `1.0.0`。开发阶段不保留旧接口兼容别名；部门、Role 和 RoleAssignment 等高风险写入必须走 Preview/Apply API。

## 认证与安全

| Controller | 路径 | 说明 |
|---|---|---|
| AuthController | `/auth/**` | 登录/登出/刷新 Token/登录验证码获取；DEV_OPS 密码登录支持二阶段 MFA challenge |
| AuthenticationIdentityController | `/security/identities/**` | 当前用户目标认证身份列表、手机/邮箱绑定与撤销；绑定必须使用对应用途的一次性验证码 |
| AuthorizationController | `/security/authorization/**` | Role 授权状态查询、Permission/Grantable/authorityLevel Impact Preview/Apply、RoleAssignment Boundary Preview/Apply、组织结构版本查询与部门新增/编辑/移动 Preview/Apply；高风险写入绑定短时 token |
| SecurityContextController | `/security/context` | 返回当前用户 Permission Catalog 权限和可授予权限，不返回角色名称 |
| SecurityAuditController | `/security/audit/**` | 按 Root/SYSTEM_ADMIN/普通用户可见性策略查询、详情、CSV 导出安全审计，并查看保留策略元数据 |
| MfaController | `/security/mfa/**` | TOTP 登记/确认、Recovery Code 单次消费/轮换；首次登录通过受限 setup challenge 登记 TOTP |
| SecurityPolicyController | `/security/policy/**` | 查询/修改各登录端 Session 策略与系统密码策略；修改使用 version 乐观锁并写入 Security Audit |
| SystemInitializationController | `/system/initialization/**` | 首次创建 DEV_OPS 用户、密码凭证、TOTP MFA、Recovery Code 和 RoleAssignment；启动需要初始化令牌，MFA 挑战依赖 Redis |

## 核心 — 公共

| Controller | 路径 | 说明 |
|---|---|---|
| CommonController | `/common/**` | 验证码生成、公共接口 |

二阶段 MFA 登录接口：`POST /auth/login` 在密码阶段成功但需要 MFA 时返回 `mfa_required=true` 和短期 `mfa_challenge_id`；已有 TOTP 账号调用 `POST /auth/mfa/verify`，首次账号依次调用 `POST /security/mfa/setup/totp/enroll`、`POST /security/mfa/setup/totp/confirm`、`POST /auth/mfa/complete`。challenge 成功消费、过期或达到失败次数上限后失效。

首次系统初始化接口：先调用 `GET /system/initialization/status`；未初始化时使用 `X-Spectra-Initialization-Token` 调用 `POST /system/initialization/start`，再调用 `POST /system/initialization/mfa/confirm` 完成 TOTP 登记并离线保存 Recovery Code，最后调用 `POST /system/initialization/complete` 激活用户并创建 `ROLE_DEV_OPS` Assignment。完成接口不签发登录 Token，客户端应返回登录页并通过正常登录流程建立会话。初始化状态写入 `spectra_core.sys_system_state`，Redis 不可用时挑战和最终初始化均 fail-closed。

## 核心 — 用户权限

| Controller | 路径 | 说明 |
|---|---|---|
| UserController | `/user/**` | 用户资料维护 / 分页查询 / 状态管理（无普通物理删除）；RoleAssignment 使用 AuthorizationController 独立管理 |
| RoleController | `/role/**` | 角色 CRUD / 菜单 UX 配置；旧角色权限关联路由已移除 |
| AuthorityController | `/authority/tree` | 只读 Permission Catalog 资源分组树；权限编码不提供业务 CRUD |

Role 授权管理：`GET /security/authorization/roles/{roleId}` 返回目标 Role 的 version、authorityLevel、Permission 与 GrantablePermission code；授权变更必须先调用 `POST /security/authorization/roles/{roleId}/impact-preview`，再携带 preview token 调用 `POST /security/authorization/roles/{roleId}/impact-apply`。旧 `/role/{id}/authorities` 路由已移除，菜单 UX 配置仍由 RoleController 管理。

组织结构管理：先调用 `GET /security/authorization/departments/organization-version` 获取 organizationVersion；新增部门调用无 ID 的 `POST /security/authorization/departments/impact-preview`，再携带 Preview 返回的 `department_id` 和 token 调用 `POST /security/authorization/departments/impact-apply`；已有部门编辑或移动调用 `/departments/{departmentId}/impact-preview` 与 `/impact-apply`。请求必须携带完整部门属性和 expected organizationVersion，Apply 会重新校验请求摘要和版本，并在事务内维护闭包表、递增 organizationVersion、撤销受影响会话。

`UserController` 生命周期写入口：`PUT /user/lock/{uid}`、`/unlock/{uid}`、`/disable/{uid}`、`/enable/{uid}`、`/depart/{uid}`、`/reinstate/{uid}`；状态变更必须经过后端状态机，不能通过普通资料更新接口绕过。

用户 RoleAssignment 不再通过用户资料的 `role_ids` 或 `/user/{uid}/roles` 覆盖写入；使用 AuthorizationController 的 Assignment Preview/Apply API，逐条提交 Role、Permission-specific Access Boundary 和可选 Grant Boundary。

用户分页资料与当前用户资料的角色展示读取活动 `spectra_security.sec_role_assignment`；`GET /security/authorization/users/{userId}/assignments` 返回 Assignment/Role version、Role 名称、系统托管标记及分离的 Access/Grant Boundary，旧 `sys_rel_user_role` 不再作为展示来源。`GET /authority/tree` 的 Permission 叶子同时返回 `allowed_scope_modes`，用于 Boundary 编辑器限制可选模式。

Web 用户编辑器对已有用户提供 RoleAssignment 新增/修改：先调用 `/security/authorization/users/{userId}/assignments/preview`，确认影响后再调用 `/apply`；Access Boundary 与 Grant Boundary 独立提交，不从一个边界推导另一个边界。

## 核心 — 系统管理

| Controller | 路径 | 说明 |
|---|---|---|
| MenuController | `/menu/**` | 菜单 CRUD / 完整管理树 / 当前用户授权树（`GET /menu/current`） |
| DepartmentController | `/department/**` | 部门树查询；旧创建/修改写入口已冻结，新增/编辑/移动使用 AuthorizationController 的组织 Impact Preview/Apply |
| RegionController | `/region/**` | 区域查询（省/市/区县） |
| DictController | `/dict/**` | 字典组 / 字典项管理 |
| ConfiguredController | `/configured/**` | 配置表管理 |
| ServiceMonitorController | `/service/monitor/**` | 服务器状态监控（CPU/内存/磁盘） |
| CryptoController | `/system/crypto/**` | 加密配置查询 / 客户端私钥获取 / 密钥对生成 / 密钥刷新 |

## 消息中心

| Controller | 路径 | 说明 |
|---|---|---|
| NotificationController | `/notification/**` | 当前用户消息列表/详情/未读数/已读/删除/批量删除 |
| NotificationPreferenceController | `/notification-center/preferences/**` | 当前用户用途 × 渠道偏好查询与保存 |
| NotificationAdminController | `/notification/admin/**` | 运维/审计脱敏查询、渠道状态、任务重试和取消 |

`POST /notification/batch-delete` 使用 `NotificationBatchDeleteFrom` 请求体：`{"ids":["消息ID"]}`。

## OA 模块

`DocumentController`：`/oa/document/**`，包含分页/详情、目录、版本、发布/归档、版本恢复、预览和下载。

`ContractController`：`/oa/contract/**`，包含台账、签署/生效/终止/归档、文件版本、履约节点、一次性临期提醒和受鉴权保护的文件访问。

| Controller | 路径 | 说明 |
|---|---|---|
| AssetController | `/oa/assets/**` | 资产台账、分类、生命周期和采购收货转草稿 |
| SupplyController | `/oa/supplies/**` | 办公用品台账、入库、领用、退库、调整和最低库存 |
| CalendarController | `/oa/calendar/**` | 日程查询、创建、更新、删除 |
| ContactController | `/oa/contact/**` | 基于 Core 用户/部门的只读组织通讯录 |
| ContractController | `/oa/contract/**` | 合同管理 |
| DocumentController | `/oa/document/**` | 文档管理 |
| MeetingController | `/oa/meeting/**` | 会议创建、冲突检测、参会响应、签到、纪要 |
| NoticeController | `/oa/notice/**` | 公告发布范围、发布/撤回、已读回执 |
| ReportController | `/oa/report/**` | 基于业务表的部门维度统计与 Excel 导出（`/department`、`/department/export`） |
| ApplicationController | `/oa/applications/**` | 通用申请分页、详情、申请类型配置、撤回、取消 |
| LeaveController | `/oa/leave/**` | 请假草稿、提交、审批状态查询、撤回、取消 |
| ReimbursementController | `/oa/reimbursements/**` | 报销草稿、明细、附件、提交、撤回、取消、付款登记 |
| PurchaseController | `/oa/purchases/**` | 采购草稿、明细、提交、撤回、取消、执行登记和分批收货 |
| WorkbenchController | `/oa/workbench/summary` | 复用 Dashboard 的 OA 工作台摘要 |

## 文件上传

| Controller | 路径 | 说明 |
|---|---|---|
| FileController | `/file/upload/**`、`/file/preview/{id}` | 文件上传/下载/分片上传；预览接口要求 `FILE:QUERY`，不再匿名开放 |
| FileInfoController | `/file/info/**` | 文件信息/类型管理 |

## 工作流

| Controller | 路径 | 说明 |
|---|---|---|
| FormDefinitionController | `/workflow/form-definitions/**` | 表单定义管理（CRUD + 版本管理） |
| ModelController | `/workflow/model/**` | 流程模型草稿入口（当前为空壳） |
| ProcessDefinitionController | `/workflow/process-definitions/**` | 流程定义查询/挂起/激活/获取资源/部署 |
| ProcessInstanceController | `/workflow/process-instances/**` | 流程实例启动/查询/终止 |
| TaskController | `/workflow/tasks/**` | 待办/已办支持 `process_definition_key` 类型筛选；审批/驳回/签收/转办/委派；任务动作校验当前办理人 |
| RuntimeController | `/workflow/runtime/**` | 运行时状态查询（待实现） |
| HistoryController | `/workflow/history/**` | 历史记录查询（待实现） |

## AI

| Controller | 路径 | 说明 |
|---|---|---|
| AiAskController | `/ai/ask/**` | AI 问答接口 |
| AiConversationController | `/ai/conversation/**` | 当前用户 AI 会话列表、消息历史与删除 |

## 全局异常处理

| Advice | 说明 |
|---|---|
| CommonExceptionAdvice | 通用业务异常处理 |
| KaptchaExceptionAdvice | 验证码异常处理 |
| SqlExceptionAdvice | 数据库异常处理 |
| EncryptException | 加解密异常处理 |

## 响应格式

```json
{
  "code": 200,
  "message": "success",
  "data": {},
  "timestamp": 1234567890
}
```

## 相关

- [[03-实体字典]] — 实体字段
- [[02-模块清单]] — 模块职责
