---
tags:
  - backend
  - module
  - core
---

# spectra-core 模块

> 必选系统核心模块：用户/认证/角色/权限/组织/系统配置/统一审计/健康聚合/单体调度。

## 模块职责

`spectra-core` 是 Spectra 后端平台的必选业务核心，提供系统运行所需的基础能力与核心编排。Core 不承载 Web、Redis、MyBatis 等纯技术实现，也不依赖 OA、Workflow、Notification、Upload 或未来 ERP 的业务实现；可选能力通过 common/framework 的稳定端口接入。

## 目录结构

```
spectra-admin/spectra-modules/spectra-core/
└── src/main/java/com/devops00/spectra/core/
    ├── security/       ← 认证、授权、审计、策略与安全变更
    ├── user/           ← 用户资料与生命周期
    ├── authorization/  ← Role/Permission/Assignment/Boundary
    ├── system/         ← 部门/菜单/字典/区域/配置/日志
    ├── scheduler/      ← 统一调度内核、LOOP 会话和运维管理
    ├── common/         ← Core 公共接口和 Core-only 辅助能力
    ├── system/         ← 系统管理、服务监控、统一健康聚合
    ├── scheduler/      ← 统一调度内核、LOOP 会话和运维管理
    ├── security/       ← 认证、授权、安全审计和安全策略
    └── user/           ← 用户、角色和批量导入
```

领域包内按 `controller`、`service`、`mapper`、`javabean` 等职责继续分层；目录树中的领域归属优先于历史顶层技术包名。模块入口由 `CoreModule` 注册到 `spectra-launch`，Mapper 资源随 Core 发布。

## 提供的能力

### 用户体系

- 用户信息管理（CRUD、分页查询、状态管理）
- 用户认证（登录、Token 刷新、验证码）
- 用户扩展信息

### 组织体系

- 部门管理（树形结构）
- 区域管理（省/市/区县/乡镇街道/村级行政区划）
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
- 统一健康聚合、服务监控、告警和受控诊断

### 任务系统

- OPS、SYSTEM、LOOP 三类统一调度
- PostgreSQL 唯一事实源、租约 CAS、UNKNOWN 结果和 LOOP 错误聚合
- 调度管理 API 与 Web 运维页面
- 审批任务

### 服务运行基础设施

- 服务监控采样、健康聚合和告警规则/事件
- 统一调度内核负责服务监控采样和核心运维任务
- `CoreHealthRegistry` 收集各已装配模块的 `DependencyHealthContributor`，`CoreHealthAggregator` 统一输出状态；Actuator 由 framework 适配

### 审计边界

- 业务代码统一使用 common 的 `@Audit` 或 `AuditService`，不直接依赖日志表或 Mapper。
- `CoreAuditService` 负责脱敏后的事件路由：普通操作事件在当前事务进入 PostgreSQL outbox，安全事件进入安全审计 sink。
- `AuditAspect` 和 `AuditConfiguration` 位于 core，`@Audit`/`AuditService` 是唯一业务入口；普通日志由 outbox worker 租约消费并幂等写入 `sys_log`，安全审计仍保持同步写入和失败阻断。
- 安全事实写入与安全变更 outbox 是两条明确链路：`SecurityAuditWriter` 同步写入不可变事实表，成功的用户、角色、权限、组织、MFA 和策略变更再在同一事务中进入 `sec_security_change_outbox`，由可选处理器异步消费；outbox 失败不能替代或掩盖安全事实写入失败。
- 安全审计归档状态由 `sec_security_audit_archive_manifest` 管理，Core 负责计划、归档 worker、对象完整性校验、恢复申请和指标；对象存储实现通过 `common.port.audit.SecurityAuditArchiveBackend` 由可选 Upload 模块提供。开发环境后端策略为 `PENDING` 时不执行归档，生产必须显式配置匹配的 Object Lock 后端。

文件资产、分片上传和业务附件引用属于可选的 `spectra-upload` 模块；Core 只通过公共能力契约参与需要的跨模块调用，不持有文件存储实现。

## 模块关系

```
spectra-core ← 被以下模块依赖
├── spectra-oa
└── spectra-launch

`spectra-upload`、`spectra-workflow` 和 `spectra-notification` 均为独立可选模块；它们不通过生产依赖反向依赖 Core。需要组合时由 `spectra-launch` 显式装配。
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
| OperationLog | sys_log | 操作日志 |
| OperationLogOutbox（支撑表） | spectra_core.sys_operation_log_outbox | 普通操作日志事务 outbox、租约、重试和死信状态 |
| SecurityChangeOutbox（支撑表） | spectra_security.sec_security_change_outbox | 安全变更外部动作 outbox、幂等、租约、重试和死信状态；不替代安全事实表 |
| SecurityAuditArchiveManifest（支撑表） | spectra_security.sec_security_audit_archive_manifest | 安全审计分区归档、完整性校验和恢复状态；不代表可删除审计事实 |
| SchedulerJobEntity | spectra_core.scheduler_job | 任务定义和调度策略 |
| SchedulerExecutionEntity | spectra_core.scheduler_execution | 离散执行、租约和结果 |
| SchedulerLoopRuntimeEntity | spectra_core.scheduler_loop_runtime | LOOP 运行会话和心跳 |
| SchedulerControlCommandEntity | spectra_core.scheduler_control_command | LOOP 控制命令 |
| SchedulerLoopErrorEntity | spectra_core.scheduler_loop_error | LOOP 错误聚合 |
| SchedulerOperationAuditEntity | spectra_core.scheduler_operation_audit | OPS/SYSTEM 调度操作审计 |

## API 端点

| Controller | 路径 | 说明 |
|---|---|---|
| UserController | `/user/**` | 用户查询、用户资料、生命周期和角色授权提交 |
| UserImportController | `/user/imports/**` | 用户批量导入 Preview/Apply 和任务查询 |
| RoleController | `/role/**` | 角色编辑、启停、删除和查询 |
| AuthenticationController | `/security/authentication/**` | 登录、登出、刷新 Token、登录验证码与绑定验证码 |
| AuthenticationIdentityController | `/security/identities/**` | 认证身份绑定/解绑 |
| AuthorizationController | `/security/authorization/**` | Role、组织和 Assignment Preview/Apply |
| AuthorizationProfileController | `/security/authorization/profiles` | 授权方案管理 |
| SecurityContextController | `/security/context` | 当前用户权限目录和可授予权限 |
| SecurityAuditController | `/security/audit/**` | 安全审计查询、详情、导出、保留策略，以及归档计划/状态/重试/恢复申请/校验；归档运维接口要求 `ROLE_DEV_OPS` |
| MfaController | `/security/mfa/**` | TOTP MFA、Recovery Code 和状态 |
| SecurityPolicyController | `/security/policy/**` | Session 和密码策略 |
| AuthorityController | `/authority/tree` | Permission Catalog 只读树 |
| MenuController | `/menu/**` | 菜单 CRUD |
| SchedulerAdminController | `/scheduler/admin/**` | 调度目录、任务、执行、统一操作记录、LOOP 会话和控制命令 |
| DepartmentController | `/department/**` | 部门 CRUD |
| RegionController | `/region/**` | 区域查询 |
| DictController | `/dict/**` | 字典管理 |
| ConfiguredController | `/configured/**` | 配置管理 |
| ServiceMonitorController | `/service/monitor/**` | 服务器监控、健康聚合、告警和诊断 |
| SystemInitializationController | `/system/initialization/**` | 首次系统初始化 |
| SystemBootstrapController | `/system/bootstrap` | 前端启动公开配置和初始化状态 |
| SystemGuideController | `/system/guide/**` | 系统设置引导 |
| CryptoController | `/system/crypto/**` | 加解密配置 |
| CommonController | `/common/**` | 公共接口 |

## 相关

- [[20-用户与权限]] — 用户权限详细设计
- [[30-系统管理]] — 系统管理详细设计
- [[03-实体字典]] — 实体字段速查
- [[04-API端点]] — API 端点速查
- [[75-统一通知模块]] — 通知模块已从 Core 独立
