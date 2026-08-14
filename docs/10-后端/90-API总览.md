---
tags:
  - backend
  - api
  - reference
---

# API 总览

> spectra-admin 全部 REST API 控制器速查表。源码当前共 46 个 `*Controller.java`。

## 认证与安全

| Controller | 模块 | 基础路径 | 说明 |
|---|---|---|---|
| `AuthController` | security-starter | `/auth/**` | 登录/登出/刷新 Token/验证码获取；认证后可申请绑定手机号/邮箱验证码 |
| `AccountController` | spectra-core | `/account/**` | 当前用户账号绑定列表、手机/邮箱绑定与解绑；绑定必须使用对应用途的一次性验证码 |
| `AuthorizationController` | spectra-core | `/security/authorization/**` | 目标 Role 授权状态查询、Permission/Grantable/authorityLevel Impact Preview/Apply、RoleAssignment Boundary Preview/Apply 与只读查询；所有高风险写入绑定短时 token |
| `SecurityContextController` | spectra-core | `/security/context` | 返回当前用户 Permission Catalog 权限和可授予权限，不返回角色名称 |
| `SecurityAuditController` | spectra-core | `/security/audit/**` | 按可见性策略查询/详情/CSV 导出安全审计，并只读展示热存与归档保留策略 |
| `MfaController` | spectra-core | `/security/mfa/**` | TOTP 登记/确认、Recovery Code 单次消费；TOTP 密钥加密存储，Recovery Code 仅保存哈希 |

## 核心 — 公共服务

| Controller | 模块 | 基础路径 | 说明 |
|---|---|---|---|
| `CommonController` | spectra-core | `/common/**` | 验证码生成、公共接口 |

## 核心 — 用户权限

| Controller | 模块 | 基础路径 | 说明 |
|---|---|---|---|
| `UserController` | spectra-core | `/user/**` | 用户资料 CRUD / 分页查询 / 状态管理；RoleAssignment 使用 AuthorizationController 独立管理 |
| `RoleController` | spectra-core | `/role/**` | 角色 CRUD / 菜单 UX 配置；旧角色权限关联写入口已冻结 |
| `AuthorityController` | spectra-core | `/authority/tree` | 只读 Permission Catalog 资源分组树；权限编码不提供业务 CRUD |

## 核心 — 系统管理

| Controller | 模块 | 基础路径 | 说明 |
|---|---|---|---|
| `MenuController` | spectra-core | `/menu/**` | 菜单 CRUD / 完整管理树 / 当前用户授权树 |
| `DepartmentController` | spectra-core | `/department/**` | 部门树查询；旧创建/修改写入口已冻结，移动使用 AuthorizationController 的组织 Impact Preview/Apply |
| `RegionController` | spectra-core | `/region/**` | 区域查询（省/市/区县） |
| `DictController` | spectra-core | `/dict/**` | 字典组 / 字典项管理 |
| `ConfiguredController` | spectra-core | `/configured/**` | 配置表管理 |
| `ServiceMonitorController` | spectra-core | `/service/monitor/**` | 服务器状态监控（CPU/内存/磁盘） |
| `CryptoController` | spectra-core | `/system/crypto/**` | 加密配置查询 / 客户端私钥获取 / 密钥对生成 / 密钥刷新 |

## 消息中心

| Controller | 模块 | 基础路径 | 说明 |
|---|---|---|---|
| `NotificationController` | spectra-notification | `/notification/**`、`/notification-center/inbox/**` | 当前用户消息分页、详情、未读数、已读、删除与批量删除；不接收 `userId` |
| `NotificationSettingController` | spectra-notification | `/notification/setting/**` | 兼容旧 API 的当前用户消息设置查询与保存 |
| `NotificationPreferenceController` | spectra-notification | `/notification-center/preferences/**` | 当前用户用途 × 渠道偏好矩阵 |
| `NotificationAdminController` | spectra-notification | `/notification/admin/**` | `notification:admin:*` 权限保护的脱敏查询、渠道状态、重试和取消 |

消息中心 Self API 强制使用认证上下文中的当前用户，并在 Service 层附加收件人条件；全局或部门权限不能扩大私人收件箱范围。`/notification-center/inbox/**` 是 `/notification/**` 的兼容路径别名。

菜单查询：`GET /menu/tree` 需要 `MENU:QUERY` 权限并返回完整管理树；`GET /menu/current` 仅要求已认证，从认证主体读取用户 ID，供前端加载运行时导航。Permission Catalog `GET /authority/tree` 需要 `permission:read`，仅返回目标 `spectra_security.permission` 的活动资源分组树；Permission code 不提供业务 CRUD。

用户 RoleAssignment 不再作为用户资料字段或 `/user/{uid}/roles` 覆盖写入；使用 AuthorizationController 的 Assignment Preview/Apply API，逐条提交 Role、Permission-specific Access Boundary 和可选 Grant Boundary。

Role 授权管理：`GET /security/authorization/roles/{roleId}` 返回目标 Role 的 version、authorityLevel、Permission 与 GrantablePermission code；`POST /security/authorization/roles/{roleId}/impact-preview` 和带 preview token 的 `POST /security/authorization/roles/{roleId}/impact-apply` 负责高风险授权变更。旧 `/role/{id}/authorities` 写入口保持 fail-closed，菜单 UX 配置仍由 RoleController 管理。

用户生命周期已拆分为高风险写入口：`PUT /user/lock/{uid}`、`/user/unlock/{uid}`、`/user/disable/{uid}`、`/user/enable/{uid}`、`/user/depart/{uid}`、`/user/reinstate/{uid}`；操作原因通过可选 `reason` 查询参数传入，服务层统一执行状态机、Security Audit、securityVersion 递增和全部 Session 撤销。

## OA 模块

`DocumentController` 已扩展为 `/oa/document/**`：文档分页/详情、目录、版本、发布/归档、版本恢复以及受文档可见范围保护的预览/下载。

`ContractController` 已扩展为 `/oa/contract/**`：合同台账分页/详情、草稿维护、签署/生效/终止/归档、文件版本和履约节点；`POST /reminders/run` 与每日调度使用条件更新保证节点提醒只发送一次，版本预览/下载继续经过合同可见范围校验。

| Controller | 模块 | 基础路径 | 说明 |
|---|---|---|---|
| `AssetController` | spectra-oa | `/oa/assets/**` | 资产台账、分类与生命周期 |
| `SupplyController` | spectra-oa | `/oa/supplies/**` | 办公用品 SKU、库存变动与最低库存 |
| `CalendarController` | spectra-oa | `/oa/calendar/**` | 日程查询、创建、更新、删除 |
| `ContactController` | spectra-oa | `/oa/contact/**` | 基于 Core 用户/部门的只读组织通讯录，不维护 OA 联系人表 |
| `ContractController` | spectra-oa | `/oa/contract/**` | 合同管理 |
| `DocumentController` | spectra-oa | `/oa/document/**` | 文档管理 |
| `MeetingController` | spectra-oa | `/oa/meeting/**` | 会议创建、冲突检测、参会响应、签到、纪要 |
| `NoticeController` | spectra-oa | `/oa/notice/**` | 公告发布范围、发布/撤回、已读回执 |
| `ReportController` | spectra-oa | `/oa/report/**` | 基于业务表的部门维度统计与 Excel 导出，不维护通用报表实体 |
| `ApplicationController` | spectra-oa | `/oa/applications/**` | 通用申请分页、详情、申请类型配置、撤回、取消 |
| `LeaveController` | spectra-oa | `/oa/leave/**` | 请假草稿、提交、查询、撤回、取消 |
| `ReimbursementController` | spectra-oa | `/oa/reimbursements/**` | 报销草稿、明细、附件、提交、撤回、取消、付款登记 |
| `PurchaseController` | spectra-oa | `/oa/purchases/**` | 采购草稿、明细、提交、撤回、取消、执行登记和分批收货 |
| `WorkbenchController` | spectra-oa | `/oa/workbench/summary` | OA 工作台摘要，复用 Dashboard |

## 文件上传

| Controller | 模块 | 基础路径 | 说明 |
|---|---|---|---|
| `FileController` | spectra-upload | `/file/upload/**`、`/file/preview/{id}` | 文件上传/下载/分片上传；预览接口要求 `file:read`，不再匿名开放 |
| `FileInfoController` | spectra-upload | `/file/info/**` | 文件信息/类型管理 |

## 工作流

| Controller | 模块 | 基础路径 | 说明 |
|---|---|---|---|
| `FormDefinitionController` | spectra-workflow | `/workflow/form-definitions/**` | 表单定义管理（CRUD + 版本管理） |
| `ModelController` | spectra-workflow | `/workflow/model/**` | 流程模型草稿入口（当前为空壳） |
| `ProcessDefinitionController` | spectra-workflow | `/workflow/process-definitions/**` | 流程定义查询/挂起/激活/获取资源/部署 |
| `ProcessInstanceController` | spectra-workflow | `/workflow/process-instances/**` | 流程实例启动/查询/终止 |
| `TaskController` | spectra-workflow | `/workflow/tasks/**` | 待办/已办支持 `process_definition_key` 类型筛选；审批/驳回/签收/转办/委派；写操作校验当前办理人 |
| `RuntimeController` | spectra-workflow | `/workflow/runtime/**` | 运行时控制入口（当前为空壳） |
| `HistoryController` | spectra-workflow | `/workflow/history/**` | 历史查询入口（当前为空壳） |

## AI

| Controller | 模块 | 基础路径 | 说明 |
|---|---|---|---|
| `AiAskController` | spectra-ai | `/ai/ask/**` | AI 问答接口 |
| `AiConversationController` | spectra-ai | `/ai/conversation/**` | 当前用户 AI 会话列表、消息历史与删除 |

## 全局异常处理

| Advice | 说明 |
|---|---|
| `CommonExceptionAdvice` | 通用业务异常处理 |
| `KaptchaExceptionAdvice` | 验证码异常处理 |
| `SqlExceptionAdvice` | 数据库异常处理 |
| `EncryptException` | 加解密异常处理 |

## 响应格式

所有 API 统一返回 JSON 格式：

```json
{
  "code": 200,
  "message": "success",
  "data": {},
  "timestamp": 1234567890
}
```

## 相关笔记

- [[10-架构分层]] — 各 Controller 所在模块
- [[20-用户与权限]] — 认证与权限 API
- [[30-系统管理]] — 系统管理 API
- [[85-接口加解密方案]] — 加解密密钥管理 API
- [[40-OA模块]] — OA API
- [[50-文件上传]] — 文件上传 API
- [[60-工作流]] — 工作流 API
- [[70-AI模块]] — AI API
