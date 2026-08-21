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
    ├── security/       ← 认证、授权、审计、策略与安全变更
    ├── user/           ← 用户资料与生命周期
    ├── authorization/  ← Role/Permission/Assignment/Boundary
    ├── system/         ← 部门/菜单/字典/区域/配置/日志
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

- 角色管理（目标 Role CRUD、菜单 UX 配置）
- Permission Catalog 与 Role capability/grantable capability 管理
- RoleAssignment 及 Permission-specific Access/Grant Boundary
- 数据权限（Permission-specific `AuthorizationSnapshot` 与 `@DataScope` 过滤）

### 系统管理

- 菜单管理（树形结构、路由配置）
- 字典管理（字典组 + 字典项）
- 系统配置（Key-Value 配置表）
- 操作日志（用户操作审计）

### 任务系统

- 系统任务调度
- 审批任务

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
| User | sys_user | 用户信息 |
| AuthenticationIdentity | spectra_security.sec_authentication_identity | 认证身份摘要 |
| PasswordCredential | spectra_security.sec_password_credential | 密码凭证 |
| SecurityRole | spectra_security.sec_role | 目标角色目录 |
| Permission | spectra_security.sec_permission | Permission Catalog |
| RoleAssignment | spectra_security.sec_role_assignment | 用户角色授权分配 |
| RolePermission | spectra_security.sec_role_permission | 角色能力 |
| RoleGrantablePermission | spectra_security.sec_role_grantable_permission | 可授予能力 |
| AssignmentPermissionBoundary | spectra_security.sec_assignment_permission_boundary | Access Boundary |
| AssignmentGrantBoundary | spectra_security.sec_assignment_grant_boundary | Grant Boundary |
| AuthorizationScope | spectra_security.sec_authorization_scope | 授权范围 |
| ScopeRule | spectra_security.sec_scope_rule | 组织范围规则 |
| SecurityRoleMenu | spectra_security.sec_role_menu | 角色菜单 UX 关系 |
| Department | sys_department | 部门 |
| OrganizationVersion | sys_organization_version | 组织树安全版本单例 |
| SystemState | sys_system_state | 系统首次初始化状态 |
| Menu | sys_menu | 菜单 |
| Region | sys_region | 行政区划 |
| DictGroup | sys_dict_group | 字典组 |
| DictItem | sys_dict_item | 字典项 |
| Configured | sys_configured | 系统配置 |
| SysConfig | sys_config | 系统参数 |
| OperationLog | sys_operation_log | 操作日志 |

## API 端点

| Controller | 路径 | 说明 |
|---|---|---|
| UserController | `/user/**` | 用户 CRUD |
| RoleController | `/role/**` | 角色 CRUD |
| AuthenticationController | `/security/authentication/**` | 登录、登出、刷新 Token、登录验证码与绑定验证码 |
| AuthenticationIdentityController | `/security/identities/**` | 认证身份绑定/解绑 |
| AuthorizationController | `/security/authorization/**` | Role capability 与 Assignment Preview/Apply |
| AuthorityController | `/authority/tree` | Permission Catalog 只读树 |
| MenuController | `/menu/**` | 菜单 CRUD |
| DepartmentController | `/department/**` | 部门 CRUD |
| RegionController | `/region/**` | 区域查询 |
| DictController | `/dict/**` | 字典管理 |
| ConfiguredController | `/configured/**` | 配置管理 |
| ServiceMonitorController | `/monitor/**` | 服务器监控 |
| CryptoController | `/system/crypto/**` | 加解密配置 |
| CommonController | `/common/**` | 公共接口 |

## 相关

- [[20-用户与权限]] — 用户权限详细设计
- [[30-系统管理]] — 系统管理详细设计
- [[03-实体字典]] — 实体字段速查
- [[04-API端点]] — API 端点速查
- [[75-统一通知模块]] — 通知模块已从 Core 独立
