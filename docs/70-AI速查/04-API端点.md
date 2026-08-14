---
tags:
  - ai
  - api
  - reference
---

# API 端点

> 源码当前 46 个 `*Controller.java` 端点速查表。

## 认证与安全

| Controller | 路径 | 说明 |
|---|---|---|
| AuthController | `/auth/**` | 登录/登出/刷新 Token/登录验证码获取；认证后可申请绑定手机号/邮箱验证码 |
| AccountController | `/account/**` | 当前用户账号绑定列表、手机/邮箱绑定与解绑；绑定必须使用对应用途的一次性验证码 |
| AuthorizationController | `/security/authorization/**` | Role/Permission/Grantable/authorityLevel Impact Preview/Apply、RoleAssignment Boundary Preview/Apply 与只读查询；高风险写入绑定短时 token |
| SecurityContextController | `/security/context` | 返回当前用户 Permission Catalog 权限和可授予权限，不返回角色名称 |
| SecurityAuditController | `/security/audit/**` | 按 Root/SYSTEM_ADMIN/普通用户可见性策略查询、详情、CSV 导出安全审计，并查看保留策略元数据 |
| MfaController | `/security/mfa/**` | TOTP 登记/确认与 Recovery Code 单次消费；DEV_OPS 必须通过 MFA 才能创建 Root Session |

## 核心 — 公共

| Controller | 路径 | 说明 |
|---|---|---|
| CommonController | `/common/**` | 验证码生成、公共接口 |

## 核心 — 用户权限

| Controller | 路径 | 说明 |
|---|---|---|
| UserController | `/user/**` | 用户 CRUD / 分页查询 / 状态管理；旧角色覆盖写入口已冻结 |
| RoleController | `/role/**` | 角色 CRUD / 菜单 UX 配置；旧角色权限关联写入口已冻结 |
| AuthorityController | `/authority/**` | 权限 CRUD / 树形查询 |

`UserController` 生命周期写入口：`PUT /user/lock/{uid}`、`/unlock/{uid}`、`/disable/{uid}`、`/enable/{uid}`、`/depart/{uid}`、`/reinstate/{uid}`；状态变更必须经过后端状态机，不能通过普通资料更新接口绕过。

## 核心 — 系统管理

| Controller | 路径 | 说明 |
|---|---|---|
| MenuController | `/menu/**` | 菜单 CRUD / 完整管理树 / 当前用户授权树（`GET /menu/current`） |
| DepartmentController | `/department/**` | 部门树查询；旧创建/修改写入口已冻结，移动使用 AuthorizationController 的组织 Impact Preview/Apply |
| RegionController | `/region/**` | 区域查询（省/市/区县） |
| DictController | `/dict/**` | 字典组 / 字典项管理 |
| ConfiguredController | `/configured/**` | 配置表管理 |
| ServiceMonitorController | `/service/monitor/**` | 服务器状态监控（CPU/内存/磁盘） |
| CryptoController | `/system/crypto/**` | 加密配置查询 / 客户端私钥获取 / 密钥对生成 / 密钥刷新 |

## 消息中心

| Controller | 路径 | 说明 |
|---|---|---|
| NotificationController | `/notification/**`、`/notification-center/inbox/**` | 当前用户消息列表/详情/未读数/已读/删除/批量删除 |
| NotificationSettingController | `/notification/setting/**` | 兼容旧路径的当前用户消息设置查询与保存 |
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
