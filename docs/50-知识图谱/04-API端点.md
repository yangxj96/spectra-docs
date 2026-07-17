---
tags:
  - ai
  - api
  - reference
---

# API 端点

> 30 个 Controller 端点速查表。

## 认证与安全

| Controller | 路径 | 说明 |
|---|---|---|
| AuthController | `/auth/**` | 登录/登出/刷新 Token/验证码获取 |

## 核心 — 公共

| Controller | 路径 | 说明 |
|---|---|---|
| CommonController | `/common/**` | 验证码生成、公共接口 |

## 核心 — 用户权限

| Controller | 路径 | 说明 |
|---|---|---|
| UserController | `/user/**` | 用户 CRUD / 分页查询 / 状态管理 |
| RoleController | `/role/**` | 角色 CRUD / 分配权限 / 分配菜单 |
| AuthorityController | `/authority/**` | 权限 CRUD / 树形查询 |

## 核心 — 系统管理

| Controller | 路径 | 说明 |
|---|---|---|
| MenuController | `/menu/**` | 菜单 CRUD / 树形查询 / 角色菜单 |
| DepartmentController | `/department/**` | 部门 CRUD / 树形查询 |
| RegionController | `/region/**` | 区域查询（省/市/区县） |
| DictController | `/dict/**` | 字典组 / 字典项管理 |
| ConfiguredController | `/configured/**` | 配置表管理 |
| ServiceMonitorController | `/monitor/**` | 服务器状态监控（CPU/内存/磁盘） |
| CryptoController | `/system/crypto/**` | 加密配置查询 / 客户端私钥获取 / 密钥对生成 / 密钥刷新 |

## OA 模块

| Controller | 路径 | 说明 |
|---|---|---|
| AssetController | `/asset/**` | 资产管理 |
| AttendanceController | `/attendance/**` | 考勤管理 |
| CalendarController | `/calendar/**` | 日历事件 |
| ContactController | `/contact/**` | 通讯录 |
| ContractController | `/contract/**` | 合同管理 |
| DocumentController | `/document/**` | 文档管理 |
| MeetingController | `/meeting/**` | 会议管理（含参会人、纪要） |
| NoticeController | `/notice/**` | 公告通知 |
| ReportController | `/report/**` | 报表管理 |

## 文件上传

| Controller | 路径 | 说明 |
|---|---|---|
| FileController | `/file/**` | 文件上传/下载/分片上传 |
| FileInfoController | `/file/info/**` | 文件信息/类型管理 |

## 工作流

| Controller | 路径 | 说明 |
|---|---|---|
| FormDefinitionController | `/workflow/form-definitions/**` | 表单定义管理（CRUD + 版本管理） |
| ModelController | `/workflow/model/**` | 流程模型 CRUD + 部署 |
| ProcessDefinitionController | `/workflow/process-definitions/**` | 流程定义查询/挂起/激活/获取资源/部署 |
| ProcessInstanceController | `/workflow/process-instances/**` | 流程实例启动/查询/终止 |
| TaskController | `/workflow/task/**` | 待办/已办/签收/完成/转办 |
| RuntimeController | `/workflow/runtime/**` | 运行时状态查询 |
| HistoryController | `/workflow/history/**` | 历史记录查询 |

## AI

| Controller | 路径 | 说明 |
|---|---|---|
| AiAskController | `/ai/**` | AI 问答接口 |

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
