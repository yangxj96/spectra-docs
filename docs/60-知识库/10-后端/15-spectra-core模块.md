---
tags:
  - backend
  - module
  - core
---

# spectra-core 模块

> 核心能力模块：用户/角色/权限/部门/菜单/字典/区域/日志/配置。

## 模块职责

`spectra-core` 是 Spectra 后端平台的核心能力模块，提供系统运行所需的基础业务能力与公共服务。

## 目录结构

```
spectra-admin/spectra-modules/spectra-core/
└── src/main/java/com/devops00/spectra/core/
    ├── auth/           ← 认证（Account）
    ├── user/           ← 用户/角色/权限
    ├── system/         ← 部门/菜单/字典/区域/配置/日志
    ├── notification/   ← 消息中心（通知/设置）
    ├── controller/     ← REST 端点
    ├── service/        ← 业务逻辑
    │   └── impl/
    ├── mapper/         ← MyBatis-Plus Mapper
    └── javabean/
        ├── entity/     ← 数据库实体
        ├── from/       ← 请求表单对象
        └── vo/         ← 响应视图对象
```

## 提供的能力

### 用户体系

- 用户信息管理（CRUD、分页查询、状态管理）
- 用户认证（登录、Token 刷新、验证码）
- 用户扩展信息

### 组织体系

- 部门管理（树形结构）
- 区域管理（省/市/区县行政区划）
- 组织关系

### 权限体系

- 角色管理（CRUD、分配权限、分配菜单）
- 权限管理（菜单/按钮/接口三级权限）
- 数据权限（@DataScope 二维数据过滤）

### 系统管理

- 菜单管理（树形结构、路由配置）
- 字典管理（字典组 + 字典项）
- 系统配置（Key-Value 配置表）
- 操作日志（用户操作审计）

### 任务系统

- 系统任务调度
- 审批任务

### 消息中心

- 消息列表查询（分页、按类型/已读状态/关键词筛选）
- 未读消息数统计
- 消息已读/全部已读标记
- 消息删除/批量删除
- 消息发送（内部调用，支持单条和批量）
- 用户通知设置管理（系统/工作流/OA/站内信/审批通知开关）
- 免打扰模式（时间段控制）

### 通知消息

- 系统通知
- 站内消息

### 文件与附件

- 文件元数据管理
- 附件关联

## 模块关系

```
spectra-core ← 被以下模块依赖
├── spectra-oa
├── spectra-workflow
└── spectra-launch
```

## 实体清单

| Entity | 表名 | 说明 |
|---|---|---|
| Account | sys_account | 登录账号 |
| User | sys_user | 用户信息 |
| Role | sys_role | 角色 |
| Authority | sys_authority | 权限 |
| RelUserRole | sys_rel_user_role | 用户-角色关联 |
| RelRoleAuthority | sys_rel_role_authority | 角色-权限关联 |
| RelRoleMenu | sys_rel_role_menu | 角色-菜单关联 |
| Department | sys_department | 部门 |
| Menu | sys_menu | 菜单 |
| Region | sys_region | 行政区划 |
| DictGroup | sys_dict_group | 字典组 |
| DictItem | sys_dict_item | 字典项 |
| Configured | sys_configured | 系统配置 |
| SysConfig | sys_config | 系统参数 |
| OperationLog | sys_operation_log | 操作日志 |
| Notification | sys_notification | 系统通知消息 |
| NotificationSetting | sys_notification_setting | 用户通知设置 |

## API 端点

| Controller | 路径 | 说明 |
|---|---|---|
| UserController | `/user/**` | 用户 CRUD |
| RoleController | `/role/**` | 角色 CRUD |
| AuthorityController | `/authority/**` | 权限 CRUD |
| MenuController | `/menu/**` | 菜单 CRUD |
| DepartmentController | `/department/**` | 部门 CRUD |
| RegionController | `/region/**` | 区域查询 |
| DictController | `/dict/**` | 字典管理 |
| ConfiguredController | `/configured/**` | 配置管理 |
| ServiceMonitorController | `/monitor/**` | 服务器监控 |
| CryptoController | `/system/crypto/**` | 加解密配置 |
| CommonController | `/common/**` | 公共接口 |
| NotificationController | `/notification/**` | 消息列表/未读数/已读/删除/发送 |

## 相关

- [[20-用户与权限]] — 用户权限详细设计
- [[30-系统管理]] — 系统管理详细设计
- [[03-实体字典]] — 实体字段速查
- [[04-API端点]] — API 端点速查
