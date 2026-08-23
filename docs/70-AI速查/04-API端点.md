---
tags:
  - ai
  - api
  - reference
---

# API 端点

> 源码当前 52 个 `*Controller.java` 端点速查表。

当前所有 REST Mapping 统一使用 API 版本 `1.0.0`。开发阶段不保留旧接口兼容别名；部门、Role 和 RoleAssignment 等高风险写入必须走 Preview/Apply API。

## 认证与安全

| Controller | 路径 | 说明 |
|---|---|---|
| AuthenticationController（spectra-core.security.authentication） | `/security/authentication/**` | 登录/登出/刷新 Token/登录验证码获取；DEV_OPS 密码登录支持二阶段 MFA challenge |
| AuthenticationIdentityController | `/security/identities/**` | 当前用户目标认证身份列表、手机/邮箱绑定与撤销；绑定必须使用对应用途的一次性验证码 |
| AuthorizationController | `/security/authorization/**` | Role 授权状态查询、Permission/Grantable/authorityLevel Impact Preview/Apply、RoleAssignment Boundary Preview/Apply、组织结构版本查询与部门新增/编辑/移动 Preview/Apply；高风险写入绑定短时 token |
| AuthorizationProfileController | `/security/authorization/profiles` | 可复用授权方案列表、详情、创建、修改、启用、停用和删除 |
| SecurityContextController | `/security/context` | 返回当前用户 Permission Catalog 权限和可授予权限，不返回角色名称 |
| SecurityAuditController | `/security/audit/**` | 按 Root/SYSTEM_ADMIN/普通用户可见性策略查询、详情、CSV 导出安全审计，并查看保留策略元数据 |
| MfaController | `/security/mfa/**` | TOTP 登记/确认、Recovery Code 单次消费/轮换；首次登录通过受限 setup challenge 登记 TOTP |
| SecurityPolicyController | `/security/policy/**` | 查询/修改各登录端 Session 策略与系统密码策略；修改使用 version 乐观锁并写入 Security Audit |
| SystemInitializationController | `/system/initialization/**` | 首次保存六项系统基础配置、创建 DEV_OPS 用户、密码凭证、TOTP MFA、Recovery Code 和 RoleAssignment；启动需要初始化令牌，MFA 挑战依赖 Redis |
| SystemGuideController | `/system/guide/**` | DEV_OPS 首次登录后查询并完成系统设置；提交根部门名称、区域、类型并保存接口加解密、通知模块和底部版权策略 |

## 核心 — 公共

| Controller | 路径 | 说明 |
|---|---|---|
| CommonController | `/common/**` | 验证码生成、公共接口 |

二阶段 MFA 登录接口：`POST /security/authentication/login` 在密码阶段成功但需要 MFA 时返回 `mfa_required=true` 和短期 `mfa_challenge_id`；已有 TOTP 账号调用 `POST /security/authentication/mfa/verify`，首次账号依次调用 `POST /security/mfa/setup/totp/enroll`、`POST /security/mfa/setup/totp/confirm`、`POST /security/authentication/mfa/complete`。challenge 成功消费、过期或达到失败次数上限后失效。

 Web 启动配置接口：`GET /system/bootstrap` 一次返回系统公开信息、加解密配置和初始化状态；该接口面向未登录页面开放，只返回系统名称、简称、Logo、默认语言、默认时区、版权开关、版权名称、版权跳转地址、加解密开关、服务端公钥和初始化状态，不返回安全策略或任何私钥。首次系统初始化接口：未初始化时使用 `X-Spectra-Initialization-Token` 调用 `POST /system/initialization/start`，请求同时提交 `system_name`、`system_short_name`、`system_logo`、`default_locale`、`default_timezone` 和 `security_profile`，后端将六项非敏感配置写入 `spectra_core.sys_config`，只创建 DEV_OPS 用户及其认证材料，不创建部门。再调用 `POST /system/initialization/mfa/confirm` 完成 TOTP 登记并离线保存 Recovery Code，最后调用 `POST /system/initialization/complete` 激活用户并创建 `ROLE_DEV_OPS` Assignment。完成接口不签发登录 Token，客户端应返回登录页并通过正常登录流程建立会话。初始化状态和引导状态分别使用 `sys_system_state` 的 `SYSTEM` 与 `SYSTEM_GUIDE` 种子行；Redis 不可用时挑战和最终初始化均 fail-closed。DEV_OPS 首次登录后调用 `GET /system/guide/status`，必须通过 `POST /system/guide/complete` 提交 `root_department_name`、`root_department_region_id`、`root_department_type`、`crypto_enabled`、`notification_enabled`、`copyright_enabled`、`copyright_name` 和 `copyright_url`，其中根部门名称、区域和类型均必填；启用版权时版权名称和 HTTP/HTTPS 跳转地址必填。后端在当前用户上下文中创建根部门、建立 DEV_OPS 主部门关系并自动生成所需密钥，版权设置同时写入 `sys_config`。

## 核心 — 用户权限

| Controller | 路径 | 说明 |
|---|---|---|
| UserController | `/user/**` | 用户资料查询、`POST /user/onboarding` 新增用户及多角色 RoleAssignment、`PUT /user/onboarding` 编辑用户并增改/移除多个 RoleAssignment、`GET /user/{uid}` 详情、分页查询 / 状态管理（无普通物理删除）；提交接口在同一事务内完成资料和授权 |
| UserImportController | `/user/imports/**` | 用户批量导入 Preview/Apply、异步任务进度、任务详情和错误行查询；以固定模板行和文件摘要为后端契约 |
| RoleController | `/role/**` | `POST /role/editor` 原子提交角色新增或编辑（基础信息、权限、可授予权限、授权等级和菜单），`GET /role/{id}` 详情、`PUT /role/{id}/enable`、`PUT /role/{id}/disable`、逻辑删除和菜单查询；旧角色创建、修改和菜单独立写入路由已移除 |
| AuthorityController | `/authority/tree` | 只读 Permission Catalog 资源分组树；权限编码不提供业务 CRUD |

`PUT /user/password/reset/{uid}` 返回一次性 `UserPasswordResetVO`（临时密码、`expires_at`、`must_change`）。临时密码 24 小时有效，只在本次响应返回明文，服务端只保存哈希；临时会话必须先修改密码。

Role 授权管理：`GET /security/authorization/roles/{roleId}` 返回目标 Role（包括 DISABLED Role）的 version、authorityLevel、Permission 与 GrantablePermission code；授权变更必须先调用 `POST /security/authorization/roles/{roleId}/impact-preview`，再携带 preview token 调用 `POST /security/authorization/roles/{roleId}/impact-apply`，且仅允许对 ACTIVE 业务角色执行。旧 `/role/{id}/authorities` 路由已移除，菜单 UX 配置仍由 RoleController 管理。

组织结构管理：先调用 `GET /security/authorization/departments/organization-version` 获取 organizationVersion；新增部门调用无 ID 的 `POST /security/authorization/departments/impact-preview`，再携带 Preview 返回的 `department_id` 和 token 调用 `POST /security/authorization/departments/impact-apply`；已有部门编辑或移动调用 `/departments/{departmentId}/impact-preview` 与 `/impact-apply`。请求必须携带完整部门属性和 expected organizationVersion，Apply 会重新校验请求摘要和版本，并在事务内维护闭包表、递增 organizationVersion、撤销受影响会话。

授权方案管理：`GET /security/authorization/profiles` 查询方案列表，`GET /security/authorization/profiles/{id}` 查询详情，`POST` 创建，`PUT /security/authorization/profiles/{id}` 按 `expected_version` 修改，`PUT /security/authorization/profiles/{id}/enable` 启用，`PUT /security/authorization/profiles/{id}/disable` 停用，`DELETE /security/authorization/profiles/{id}` 删除方案模板。删除采用逻辑删除，并同步移除方案下的角色配置和边界模板，不影响已经生成的运行时授权；方案保存 Role/Permission/部门业务编码和版本快照，后续应用仍需经过 RoleAssignment Preview/Apply。

`UserController` 生命周期写入口：`PUT /user/lock/{uid}`、`/unlock/{uid}`、`/disable/{uid}`、`/enable/{uid}`、`/depart/{uid}`、`/reinstate/{uid}`；状态变更必须经过后端状态机，不能通过普通资料更新接口绕过。

管理员用户编辑页通过 `GET /user/{uid}` 加载完整用户详情，前端页面路由为 `/system/user/create` 和 `/system/user/:id/edit`；编辑页使用 `activeMenu: SystemUser` 继承用户管理菜单高亮。

用户 RoleAssignment 不再通过用户资料的 `role_ids` 或 `/user/{uid}/roles` 覆盖写入；独立授权编辑使用 AuthorizationController 的 Assignment Preview/Apply API，逐条提交 Role、Permission-specific Access Boundary 和可选 Grant Boundary。用户新增/编辑页面按“基本信息 → 授权方案 → 角色授权”流转，最后一步调用 `POST/PUT /user/onboarding`，一次提交多个角色授权和移除列表，由后端在同一事务中保存用户资料、逐条复用 Assignment Preview/Apply 并撤销被移除角色。

用户批量导入端点：`POST /user/imports/preview` 创建或幂等重放 Preview 任务，`GET /user/imports/{id}` 查询任务摘要和 `completed_rows`，`GET /user/imports/{id}/errors` 查询错误行，`POST /user/imports/{id}/apply` 校验通过后返回 `APPLYING` 任务并异步应用通过校验的行。请求字段为 `real_name`、`phone`、`email`、`department_code`、`language`、`timezone`、`authorization_profile_code`，另带 `file_hash` 和 `idempotency_key`；工号由后端在 Preview 阶段按任务幂等键和行号生成并保存，任务有效期字段以 `LocalDateTime` 响应，Web 页面统一格式化为 `yyyy-MM-dd HH:mm:ss`；Web Excel 模板只包含用户基本信息，部门、语言、时区和授权方案由页面统一选择后合并到每一行 Preview 请求；后端不接收内部授权 UUID，Excel/CSV 文件解析由前端负责。

用户分页资料与当前用户资料的角色展示读取 `spectra_security.sec_role_assignment`；用户分页和详情的 `UserPageVO` 返回后端计算的 `authorization_status`（`UNCONFIGURED`、`INCOMPLETE`、`ACTIVE`、`PARTIAL`）。`GET /security/authorization/users/{userId}/assignments` 返回 Assignment/Role version、Role 状态、Role Permission 数量、Role 名称、系统托管标记及分离的 Access/Grant Boundary，旧 `sys_rel_user_role` 不再作为展示来源。`GET /authority/tree` 的 Permission 叶子同时返回 `allowed_scope_modes`，用于 Boundary 编辑器限制可选模式。

Web 用户编辑器对已有用户提供多个 RoleAssignment 的新增、修改和移除：第 02 步加载已有活动角色，也可以套用多 Role 授权方案；方案中的重复角色会跳过并提示。第 03 步按角色分别调整 Access Boundary 与 Grant Boundary，至少保留一个角色，最后调用 `/user/onboarding` 一次性提交；独立授权页面仍可调用 `/security/authorization/users/{userId}/assignments/preview` 和 `/apply`。Access Boundary 与 Grant Boundary 独立提交，不从一个边界推导另一个边界。

## 核心 — 系统管理

| Controller | 路径 | 说明 |
|---|---|---|
| MenuController | `/menu/**` | 菜单 CRUD / 完整管理树 / 当前用户授权树（`GET /menu/current`） |
| DepartmentController | `/department/**` | 部门树查询；旧创建/修改写入口已冻结，新增/编辑/移动使用 AuthorizationController 的组织 Impact Preview/Apply |
| RegionController | `/region/**` | 区域查询（省/市/区县） |
| DictController | `/dict/**` | 字典组 / 字典项管理 |
| ConfiguredController | `/configured/**` | 配置表管理 |
| ServiceMonitorController | `/service/monitor/**` | 服务监控总览/历史趋势、告警摘要/规则/事件、运行时诊断和受控诊断任务；分别使用 `system:monitor:read`、`system:monitor:alert`、`system:monitor:configure`、`system:monitor:diagnose` 权限 |
| CryptoController | `/system/crypto/**` | 加密配置查询 / 客户端私钥获取 / 密钥对生成 / 密钥刷新 |
| SystemBootstrapController | `/system/bootstrap` | Web 启动阶段一次性获取系统公开信息、加解密配置和初始化状态 |
| SystemGuideController | `/system/guide/**` | DEV_OPS 系统设置引导状态查询与完成 |

## 消息中心

| Controller | 路径 | 说明 |
|---|---|---|
| NotificationController | `/notification/**` | 当前用户消息列表/详情/未读数/已读/删除/批量删除 |
| NotificationPreferenceController | `/notification-center/preferences/**` | 当前用户用途 × 渠道偏好查询与保存 |
| NotificationAdminController | `/notification/admin/**` | 运维/审计脱敏查询、渠道状态、任务重试和取消 |
| NotificationTemplateAdminController | `/notification/admin/templates/**` | 模板分页/详情、草稿创建/编辑、发布/停用/归档、版本历史、回滚和安全预览；按 `notification:template:*` 权限保护 |

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
