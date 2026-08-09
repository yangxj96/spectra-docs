---
tags:
  - backend
  - api
  - reference
---

# API 总览

> spectra-admin 全部 REST API 控制器速查表。源码当前共 40 个 `*Controller.java`。

## 认证与安全

| Controller | 模块 | 基础路径 | 说明 |
|---|---|---|---|
| `AuthController` | security-starter | `/auth/**` | 登录/登出/刷新 Token/验证码获取 |
| `AccountController` | spectra-core | `/account/**` | 当前用户账号绑定列表、手机/邮箱绑定与解绑 |

## 核心 — 公共服务

| Controller | 模块 | 基础路径 | 说明 |
|---|---|---|---|
| `CommonController` | spectra-core | `/common/**` | 验证码生成、公共接口 |

## 核心 — 用户权限

| Controller | 模块 | 基础路径 | 说明 |
|---|---|---|---|
| `UserController` | spectra-core | `/user/**` | 用户 CRUD / 分页查询 / 角色覆盖 / 状态管理 |
| `RoleController` | spectra-core | `/role/**` | 角色 CRUD / 分配权限 / 分配菜单 |
| `AuthorityController` | spectra-core | `/authority/**` | 权限 CRUD / 树形查询 |

## 核心 — 系统管理

| Controller | 模块 | 基础路径 | 说明 |
|---|---|---|---|
| `MenuController` | spectra-core | `/menu/**` | 菜单 CRUD / 完整管理树 / 当前用户授权树 |
| `DepartmentController` | spectra-core | `/department/**` | 部门 CRUD / 树形查询 |
| `RegionController` | spectra-core | `/region/**` | 区域查询（省/市/区县） |
| `DictController` | spectra-core | `/dict/**` | 字典组 / 字典项管理 |
| `ConfiguredController` | spectra-core | `/configured/**` | 配置表管理 |
| `ServiceMonitorController` | spectra-core | `/service/monitor/**` | 服务器状态监控（CPU/内存/磁盘） |
| `CryptoController` | spectra-core | `/system/crypto/**` | 加密配置查询 / 客户端私钥获取 / 密钥对生成 / 密钥刷新 |

## 消息中心

| Controller | 模块 | 基础路径 | 说明 |
|---|---|---|---|
| `NotificationController` | spectra-core | `/notification/**` | 消息分页、未读数、标记已读、删除与发送 |
| `NotificationSettingController` | spectra-core | `/notification/setting/**` | 当前用户消息接收偏好查询与保存 |

菜单查询：`GET /menu/tree` 需要 `MENU:QUERY` 权限并返回完整管理树；`GET /menu/current` 仅要求已认证，从认证主体读取用户 ID，供前端加载运行时导航。权限树 `GET /authority/tree` 需要 `AUTHORITY:QUERY`，权限树写操作仅限 `ROLE_DEV_OPS`。

用户角色覆盖：`PUT /user/{uid}/roles`，请求体需包含 `user_id` 与 `role_ids`，使用 `USER:UPDATE` 权限，并在服务层校验目标角色均为有效角色后执行全量替换。

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
| `FileController` | spectra-upload | `/file/upload/**` | 文件上传/下载/分片上传 |
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
