---
tags:
  - backend
  - api
  - reference
---

# API 总览

> spectra-admin 全部 REST API 控制器速查表。共 30 个 Controller。

## 认证与安全

| Controller | 模块 | 基础路径 | 说明 |
|---|---|---|---|
| `AuthController` | security-starter | `/auth/**` | 登录/登出/刷新 Token/验证码获取 |

## 核心 — 公共服务

| Controller | 模块 | 基础路径 | 说明 |
|---|---|---|---|
| `CommonController` | spectra-core | `/common/**` | 验证码生成、公共接口 |

## 核心 — 用户权限

| Controller | 模块 | 基础路径 | 说明 |
|---|---|---|---|
| `UserController` | spectra-core | `/user/**` | 用户 CRUD / 分页查询 / 状态管理 |
| `RoleController` | spectra-core | `/role/**` | 角色 CRUD / 分配权限 / 分配菜单 |
| `AuthorityController` | spectra-core | `/authority/**` | 权限 CRUD / 树形查询 |

## 核心 — 系统管理

| Controller | 模块 | 基础路径 | 说明 |
|---|---|---|---|
| `MenuController` | spectra-core | `/menu/**` | 菜单 CRUD / 树形查询 / 角色菜单 |
| `DepartmentController` | spectra-core | `/department/**` | 部门 CRUD / 树形查询 |
| `RegionController` | spectra-core | `/region/**` | 区域查询（省/市/区县） |
| `DictController` | spectra-core | `/dict/**` | 字典组 / 字典项管理 |
| `ConfiguredController` | spectra-core | `/configured/**` | 配置表管理 |
| `ServiceMonitorController` | spectra-core | `/monitor/**` | 服务器状态监控（CPU/内存/磁盘） |
| `CryptoController` | spectra-core | `/system/crypto/**` | 加密配置查询 / 客户端私钥获取 / 密钥对生成 / 密钥刷新 |

## OA 模块

| Controller | 模块 | 基础路径 | 说明 |
|---|---|---|---|
| `AssetController` | spectra-oa | `/asset/**` | 资产管理 |
| `AttendanceController` | spectra-oa | `/attendance/**` | 考勤管理 |
| `CalendarController` | spectra-oa | `/calendar/**` | 日历事件 |
| `ContactController` | spectra-oa | `/contact/**` | 通讯录 |
| `ContractController` | spectra-oa | `/contract/**` | 合同管理 |
| `DocumentController` | spectra-oa | `/document/**` | 文档管理 |
| `MeetingController` | spectra-oa | `/meeting/**` | 会议管理（含参会人、纪要） |
| `NoticeController` | spectra-oa | `/notice/**` | 公告通知 |
| `ReportController` | spectra-oa | `/report/**` | 报表管理 |

## 文件上传

| Controller | 模块 | 基础路径 | 说明 |
|---|---|---|---|
| `FileController` | spectra-upload | `/file/**` | 文件上传/下载/分片上传 |
| `FileInfoController` | spectra-upload | `/file/info/**` | 文件信息/类型管理 |

## 工作流

| Controller | 模块 | 基础路径 | 说明 |
|---|---|---|---|
| `ModelController` | spectra-workflow | `/workflow/model/**` | 流程模型 CRUD + 部署 |
| `ProcessDefinitionController` | spectra-workflow | `/workflow/definition/**` | 流程定义查询/挂起/激活 |
| `ProcessInstanceController` | spectra-workflow | `/workflow/instance/**` | 流程实例启动/查询/终止 |
| `TaskController` | spectra-workflow | `/workflow/task/**` | 待办/已办/签收/完成/转办 |
| `RuntimeController` | spectra-workflow | `/workflow/runtime/**` | 运行时状态查询 |
| `HistoryController` | spectra-workflow | `/workflow/history/**` | 历史记录查询 |

## AI

| Controller | 模块 | 基础路径 | 说明 |
|---|---|---|---|
| `AiAskController` | spectra-ai | `/ai/**` | AI 问答接口 |

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
