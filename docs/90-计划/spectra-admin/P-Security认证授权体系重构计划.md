# P-Security 认证授权体系重构计划

> 状态：核心安全决策已确认，Phase 0 已开始实施（部分封堵已完成，待完成回归门禁）
> 基线日期：2026-08-14  
> 适用范围：`spectra-admin`、`spectra-ui`、`spectra-app`、`docs/sql`  
> 相关文档：[[00-项目总览]]、[[20-用户与权限]]、[[25-数据权限设计]]、[[30-系统管理]]、[[P-数据权限与数据隔离重构计划]]、[[P-运维管理中心建设计划]]

## 0. 结论与强制不变量

当前系统已经具备 Spring Security、Opaque Token、Redis 会话、角色权限、角色菜单、部门树和 MyBatis 数据范围拦截器等基础能力，但这些能力尚未形成安全闭环。最关键的结构性问题是：权限先按用户全局合并，数据范围也先按用户全局合并，最后再组合；这会允许某个角色的权限借用另一个角色的范围。与此同时，Redis 保存完整 `SecurityUser` 快照，角色、范围、状态和密码变化后大多不会撤销旧会话。

本计划不保留上述错误抽象。目标模型必须满足：

1. 用户不能直接拥有 Permission，只能通过 RoleAssignment 获得 Role。
2. Role 不继承 Role；Role 是能力模板，RoleAssignment 是实际授权实例。
3. Access Boundary 和 Grant Boundary 都必须绑定到 `RoleAssignment + Permission`；不存在 Assignment 级或用户级全局 Scope。
4. 对权限 `P` 求访问范围时，只合并能提供 `P` 的 Assignment Permission Boundary；对 `P` 做向下授权时，只使用能提供 `P` 的 Assignment Grant Boundary。不同 Permission 绝不互借范围。
5. authorityLevel 只判断“谁能管理谁”，不推导业务 Permission，且管理判断同样不能借用无关 Assignment 的等级。
6. Menu 只负责导航与功能可见性，Permission 才是后端安全边界。
7. `ROLE_DEV_OPS` 通过一个统一 RootAuthorizationPolicy 获得全部权限、菜单和数据范围；业务代码不得散落角色特判；Root 永远不能绕过 Security Audit。
8. Access Token 和 Refresh Token 都是安全随机 Opaque Token；Redis 只保存 token 摘要，不保存明文 token。
9. Refresh Token 单次使用、强制 Rotation；检测到旧 token 重放时撤销整个 Session/Token Family。
10. 任何可能改变 Effective Authority 的操作必须统一执行 Boundary Check、Impact Analysis、Security Audit 和 Session Revocation；新请求在 revocation fence 后立即失效，高风险写事务提交前重新校验 security epoch。
11. 后端独立执行 Permission、authorityLevel、DataScope、Grant Boundary、账号状态和 Session 校验；前端隐藏不构成安全控制。
12. 普通用户删除从产品能力中移除，以 DISABLED / DEPARTED 表达生命周期并保留历史身份。
13. Web Refresh Token 使用 HttpOnly + Secure、默认 Host-only、优先 SameSite=Strict 的 Cookie，并同时实施 CSRF token、Origin/Referer 和精确 CORS 防护；只有部署拓扑确实要求跨站时才允许 SameSite=None。
14. Redis/Session 核心依赖不可用时默认 fail-closed；高风险安全写操作在 Security Audit 不可用时同样 fail-closed。
15. 首版支持多个 DEV_OPS，`maxDevOpsUsers` 默认 3 且可配置，推荐 2 个正常 Root + 1 个 break-glass Root；永远阻止管理操作使系统失去最后一个有效 Root。
16. Authentication Pipeline 首版支持多 Factor 并交付 TOTP；DEV_OPS 强制 MFA，Recovery Code 单次使用且只存 Hash，最终恢复进入独立 break-glass Runbook。WebAuthn/Passkey 后续交付；双人审批只保留扩展点，OPEN_API Service Principal 只保留主体模型扩展能力。

---

# 1. Current Security Architecture

## 1.1 Authentication

当前登录入口位于：

- `spectra-security-spring-boot-starter/.../web/controller/AuthController.java`
- `spectra-security-spring-boot-starter/.../web/dispatcher/LoginDispatcher.java`
- `spectra-security-base/.../strategy/provider/*AuthenticationProvider.java`
- `spectra-core/.../auth/service/impl/LoginUsernamePasswordProvider.java`
- `spectra-core/.../auth/service/impl/LoginSmsProvider.java`
- `spectra-core/.../auth/service/impl/LoginEmailProvider.java`
- `spectra-core/.../auth/service/impl/SecurityUserHelper.java`

现有行为：

- `/auth/login` 支持 PASSWORD、SMS、EMAIL；OTP 枚举存在但明确不支持。
- 密码登录使用 Spring Security `AuthenticationManager` 和图形验证码。
- SMS/EMAIL 验证码由 `AuthServiceImpl` 生成，Redis 保存 HMAC 摘要而非明文，这是可复用方向。
- `SecurityUserHelper` 检查 Account 状态、认证方式、验证状态、User ACTIVE 和逻辑删除状态，然后加载角色、权限及一个全局 EffectiveScope。
- 登录失败计数保存在 Redis，达到阈值后临时锁定。
- `sys_account` 同时承载密码、手机、邮箱、OpenID、UnionID 和 Provider 等多种认证标识。

## 1.2 Spring Security / Authorization

关键文件：

- `.../configuration/SecurityConfiguration.java`
- `.../filter/TokenAuthenticationFilter.java`
- `.../eval/SpectraPermissionEvaluator.java`
- `.../advice/RestAuthenticationEntryPoint.java`
- `.../advice/RestAccessDeniedHandler.java`

现有行为：

- SecurityFilterChain 使用 STATELESS，关闭 CSRF、Form Login、HTTP Basic、RememberMe 和 Servlet Logout。
- 白名单通过 `SecurityProperties.whitelists` 配置，其余请求只要求 authenticated。
- Controller 普遍通过 `@PreAuthorize("hasPermission(...)")` 做方法级校验。
- 当前 Permission 采用 `USER:QUERY`、`ROLE:UPDATE` 等大写模块动作格式。
- `SpectraPermissionEvaluator` 支持 `*`、通配符和 `ROLE_DEV_OPS` 管理员直通。
- `targetDomainObject`、`targetId/targetType` 参数没有参与对象级授权，因此它不是实际的 IDOR 防线。

## 1.3 Token / Session / Online User

关键文件：

- `.../strategy/RedisSecHolderStrategy.java`
- `spectra-security-base/.../holder/SecHolderStrategy.java`
- `spectra-security-base/.../holder/SecUtil.java`
- `spectra-security-base/.../constant/AuthRedisKey.java`
- `spectra-security-base/.../javabean/entity/SecurityUser.java`

现有模型不是 JWT，而是 UUID Opaque Token，方向与目标一致。默认 Access Token 5 分钟、Refresh Token 7 天。Redis 主要结构为：

- `auth:sess:{accessToken}`：会话 Hash，包含完整 `SecurityUser`。
- `auth:uc:{userId}:{clientType}`：用户同端唯一 Access Token。
- `auth:ut:{userId}`：用户 Access Token 集合。
- `auth:online`：在线用户 ID 集合。
- `auth:rt:{accessToken}` 与 `auth:rt:{refreshToken}`：双向 Refresh 映射。

现有 ClientType 只有 WEB、APP、MINI。创建 Token 时同端直接复用既有 Access/Refresh Token；请求经过 `TokenAuthenticationFilter` 时已不再续期 Access Session TTL。Phase 0 的 Refresh Rotation 会先通过 `SecurityUserLoader` 从当前身份源重新加载主体，未配置加载器或主体已不可用时拒绝刷新；普通 Access Session 仍暂存 `SecurityUser` 快照，待 Phase 5 的 v2 Session 聚合移除。

在线用户由 `/user/online` 查询，响应包含完整 Access Token；前端在线用户页面目前主要为 mock。

## 1.4 User / Account Lifecycle

关键实体和服务：

- `spectra-core/.../user/javabean/entity/User.java`
- `spectra-core/.../auth/javabean/entity/Account.java`
- `spectra-core/.../user/service/impl/UserServiceImpl.java`
- `spectra-core/.../auth/service/impl/AccountServiceImpl.java`

现有 User 只有 ACTIVE / DISABLED；Account 有 ACTIVE、DISABLED、UNVERIFIED、PASSWORD_RESET_REQUIRED。User 只有一个 `department_id`，不存在关联部门。

用户创建、资料修改、状态修改、角色替换、用户数据范围和登录邮箱被放在同一个宽泛 DTO/Service 中。管理员重置密码使用单独入口，但角色替换仍只要求 `USER:UPDATE`。普通删除是逻辑删除，并删除/失效账号和关系。

## 1.5 Role / Authority / Menu

当前表关系：

```text
sys_user
  -> sys_rel_user_role
  -> sys_role
  -> sys_rel_role_authority
  -> sys_authority

sys_role
  -> sys_rel_role_menu
  -> sys_menu
```

关键实现：

- `RoleServiceImpl` 创建随机角色 code，没有 `ROLE_*` 的稳定业务语义。
- `RelUserRoleServiceImpl.grant` 直接插入用户角色关系。
- `RelRoleAuthorityServiceImpl.grant` 对权限树做压缩后更新关系。
- `RelRoleMenuServiceImpl.grant` 保存叶子菜单，查询时补齐父目录。
- Menu 与 Authority 已经是两个独立实体，这是应保留的正确方向。
- `MenuServiceImpl.current(userId)` 按用户角色查询菜单，但尚未为 DEV_OPS 隐式返回全部菜单。
- Role 没有 authorityLevel，系统也没有 GrantablePermission。

## 1.6 Department / Organization

`sys_department` 使用 `pid` 邻接表和字符串 `path`。`DepartmentServiceImpl` 在内存中递归求子部门，未建立 Closure Table 或可靠的安全版本。部门移动时未执行循环检查、授权影响分析、受影响 Session 撤销或 Security Audit。

用户只有主部门；组织成员关系和安全 DataScope 在当前模型中实际发生耦合。

## 1.7 DataScope

当前 Permission-specific 范围模式为 NONE、ALL、SELF、RULES，相关实现：

- `spectra-framework/.../mybatis/security/ScopeSqlPolicy.java`
- `spectra-starter/.../security-base/authorization/AuthorizationSnapshot.java`
- `spectra-framework/.../mybatis/interceptor/DataScopeInnerInterceptor.java`
- `spectra-framework/.../mybatis/DataScopeEntityRegistry.java`
- `spectra-framework/.../mybatis/DataScopeExecutor.java`
- `AuthorizationSnapshot` 中的 Access/Grant Boundary（旧 Scope 表仅作为迁移输入）

当前算法按 Permission 读取用户有效 Assignment 的 Access Boundary，Grant Boundary 只用于授权委派，不参与业务数据可见性；同一 Permission 的多个 Boundary 取并集，缺失或无法解析时 fail-closed。MyBatis 拦截器根据实体 `@DataScope` 元数据拼接部门、本人或关联表条件，`SecurityUser` 不再保存全局 Scope 快照。

OA 中约 20 个实体使用 `@DataScope`；`Calendar`、`Notice` 显式 `ignore = true`。系统用户列表、权限管理以及未使用 MyBatis/未登记实体的路径不受该拦截器保护。

## 1.8 Operation Log / Audit

现有 `@ULog` AOP 采集请求参数、结果、IP、URL、耗时和用户，通过 Spring Event 异步写入 `spectra_core.sys_log`：

- `spectra-log-base/.../aspect/ULogAspect.java`
- `spectra-log-base/.../utils/AuditLogSanitizer.java`
- `spectra-core/.../common/listener/ulog/ULogListener.java`
- `spectra-core/.../system/javabean/entity/OperationLog.java`

`AuditLogSanitizer` 对 password、token、secret、captcha 等字段脱敏，可复用。但 `sys_log` 是普通可更新/软删除实体；安全事件与业务操作日志未分离，且异步写入失败不会阻止高风险操作。DDL、Java Entity 和 `db.dump` 中的 `sys_log` 字段还存在明显漂移。

## 1.9 Web Frontend

关键文件：

- `spectra-ui/src/views/Login/index.vue`
- `spectra-ui/src/api/auth/auth-api.ts`
- `spectra-ui/src/plugin/request/auth.ts`
- `spectra-ui/src/plugin/request/http.ts`
- `spectra-ui/src/plugin/store/modules/use-user-store.ts`
- `spectra-ui/src/plugin/directives/owner.ts`
- `spectra-ui/src/plugin/router/permission.ts`
- `spectra-ui/src/views/System/RBAC/index.vue`
- `spectra-ui/src/views/System/User/components/UserEdit/index.vue`

现有 Pinia 持久化将 Access Token、Refresh Token、roles、authorities 存入 localStorage。动态菜单通过 `/menu/current` 加载，路由以 routeName 校验；按钮 `v-owner` 和 `hasPermission` 仅做 UI 隐藏。RBAC 页面将角色权限树、菜单树、Role Scope 同屏配置；用户编辑页允许直接选择 roles、单一部门和用户级 Scope。

## 1.10 Mobile Frontend

关键文件：

- `spectra-app/src/services/http.ts`
- `spectra-app/src/helper/bootstrap/user.ts`
- `spectra-app/src/services/api/auth.ts`
- `spectra-app/src/interceptor/route.ts`
- `spectra-app/src/pages/login/index.vue`
- `spectra-app/src/platform/device/*`

App/H5/小程序支持 PASSWORD、SMS、EMAIL 登录，Access/Refresh Token 使用 `uni.setStorageSync`。启动时只要存在 Refresh Token 就调用 refresh。请求层有单飞队列，但刷新后重试将 `skipAuth` 设为 true，导致新 Access Token 不会加入重试请求。Client、Device 未可靠传给后端；现有 device adapter 还返回固定占位 ID。

## 1.11 Database / Migration / Tests

- 目标 schema 已由 `spectra-config/src/main/resources/db/migration/V1__init_target_schema.sql` 引入 Flyway 管理；`docs/sql/*` 继续作为设计/审查输入，`docs/sql/db.dump` 仅保留为 snapshot/fixture，不再是迁移事实源。
- 核心安全表多数只有主键，缺少外键、状态 CHECK、活动关系唯一索引和稳定 code 唯一约束。
- `sys_rel_role_menu` 和菜单 routeName 有部分活动唯一索引，可复用。
- 后端现有 51 个测试文件，但安全 starter 只有验证码服务测试；Token Filter、Refresh、Rotation、Replay、Session Policy、Role Boundary、authorityLevel 和账号状态矩阵没有覆盖。
- Web 有 11 个测试文件，主要覆盖菜单和通知；没有刷新并发、Store 权限、登出和 Session 失效测试。
- `spectra-app` 当前没有自动化测试。

---

# 2. Current Security Problems

## 2.1 Critical / High Risk

| 级别 | 问题 | 直接风险 | 证据位置 |
|---|---|---|---|
| Critical | Permission 与 Scope 分别全局 UNION | 跨 Assignment 数据越权 | `DataScopeResolver`、`SecurityUser` |
| Critical | 用户/角色/范围/状态变化不统一 revoke | 旧 Session 长期保留旧权限；被禁用用户可继续请求或 refresh | `UserServiceImpl`、`RoleServiceImpl`、`RedisSecHolderStrategy` |
| Critical（Phase 0 已封堵） | 旧实现不强制 Refresh Rotation、无 Replay 检测 | Refresh Token 被盗后可持续复用；当前已使用独立 claim key + 用户级 replay fence，完整 Token Family 仍待 Phase 5 | `RedisSecHolderStrategy`、`RefreshTokenRotationStore` |
| Critical（Phase 0 已封堵） | 旧实现曾使用 Redis 中旧 `SecurityUser` 重建 Refresh Session | 禁用、离职、角色撤销后可能恢复旧权限；当前已要求 `SecurityUserLoader` 从身份源重载，未配置时 fail-closed | `RedisSecHolderStrategy`、`SecurityUserLoader` |
| Critical | 手机/邮箱绑定入参 code 未校验 | 攻击者可直接绑定未证明所有权的标识 | `AccountServiceImpl.bindPhone/bindEmail` |
| High | 用户角色和角色权限没有 Grant Boundary | 普通管理员可分配自己没有的角色/权限，或修改自己依赖的角色提权 | `RelUserRoleServiceImpl`、`RelRoleAuthorityServiceImpl` |
| High | 无 authorityLevel 管理边界 | 可管理同级/上级管理员 | Role/User Service |
| High | User Scope 直接覆盖 Role Scope | 用户直接权限模型与目标冲突，且扩大面难审计 | `sys_user_data_scope*` |
| High（Phase 0 已封堵） | 旧实现 Refresh logout 不删除 Access Session 和 user-client key | 仅提交 Refresh Token 登出时 Access Token 仍可能有效；当前 logout 会清理关联 Access Session 和索引 | `deleteByRefreshToken` |
| High（Phase 0 已封堵） | 旧实现 CORS 默认 `originPatterns=*` 且 credentials=true | 任意站点可发起带凭证跨域请求；当前只允许精确部署 Origin | `SystemProperties.SpectraCors`、`MvcConfiguration` |
| High（Phase 0 已封堵） | 旧实现 `/actuator/**`、`/file/preview/**` 默认白名单 | 运维信息或文件可能被匿名访问；当前仅保留 health/info 且文件预览需认证 | `SecurityProperties.whitelists` |
| High（Phase 0 已封堵） | 旧实现在线用户响应返回完整 Access Token | 运维页面、日志或浏览器泄漏即可劫持会话；当前响应不再回显 Token | `UserOnlineConverter` / `UserOnlineVO` |

## 2.2 Medium / Structural Risk

- Token 明文出现在 Redis Key 和 Value 中；Redis 泄漏即可直接使用。
- Access Token 每次请求滑动续期，不再是固定约 5 分钟生命周期。
- “同端复用 Token”不是并发登录策略；ALLOW/KICK_OLD/REJECT_NEW 无法表达，检查与创建也不是原子操作。
- `ClientType` 依赖 Header/User-Agent 猜测，未与 AuthenticationMethod 解耦。
- Redis 多 Key 创建、刷新和撤销均非原子；并发 refresh、kick、disable、login 存在竞态。
- `SpectraPermissionEvaluator` 支持 `*` 和宽泛 pattern，且 Root 特判同时出现在 Evaluator、DataScope 和业务控制器。
- `PermissionEvaluator` 忽略对象参数；拥有 `xxx:update` 后，按 ID 更新主要依赖各 Service 自觉检查。
- `USER:UPDATE` 同时覆盖资料、状态、角色和范围；`ROLE:UPDATE` 同时覆盖角色资料、权限和菜单；风险粒度过粗。
- 角色 code 随机生成，无法作为稳定 `ROLE_*` Authority。
- 权限表可运行时任意增删改，但新 code 并不会自动产生后端执行点，容易形成“看似授权、实际无效”或通配符误授权。
- 部门移动不维护可靠层级索引，也不分析 include-descendants 授权扩张。
- `@DataScope(ignore=true)` 和 `DataScopeExecutor.withoutScope` 缺少统一审批、原因和审计。
- 数据范围主要覆盖标注的 MyBatis Entity；Native SQL、Flowable、批处理、导出、关联子表和未标注表没有统一保证。
- `sys_log` 不是 append-only，Root 也可通过数据库权限或普通 Service 路径修改/删除。
- `@ULog` 是 best-effort 异步日志；高风险变更可能成功而审计丢失。
- User 状态缺少 LOCKED/DEPARTED；Account 锁定、用户禁用和认证失败锁定概念混杂。
- 普通 User Delete 会使安全关系和组织成员关系退出正常查询，削弱历史可追溯性。

## 2.3 Frontend-Specific Problems

- Web 的 Refresh 请求复用同一拦截器；Refresh 本身返回 401 时可能等待自己的刷新队列，形成死锁（Phase 0 已通过独立 `skipAuth/_skipRefresh` 门禁隔离）。
- Web Refresh 失败会清空等待队列但不完整 reject 所有调用路径，存在悬挂请求（Phase 0 已改为共享 Promise，失败统一返回 `null`）。
- App 刷新成功后用 `skipAuth=true` 重试，实际不携带新的 Authorization Header（Phase 0 已改为携带新 Access Token 重试）。
- Web `Token.roles` 类型声明为 `RolePageVO[]`，后端实际返回 `string[]`；角色指令可能失效。
- 路由无菜单权限时跳转 `/401`，语义应为 403；401/403/Session Revoked 未形成统一 UX。
- Web/App 开发模式源码中硬编码 DEV_OPS 示例账号、密码和验证码（Phase 0 已移除；仍需防止未来 fixture 回流）。
- Web localStorage、App 普通 storage 保存 Refresh Token；XSS、调试备份或设备数据提取后风险较大。
- 移动端路由守卫在 DEV_MODE 完全绕过，且只检查 Token 是否存在。
- App 设备 ID adapter 是固定占位值，无法作为 Session 设备索引。

---

# 3. Gap Analysis

| 目标能力 | 当前状态 | 处理结论 |
|---|---|---|
| Spring Security 基础认证/方法安全 | 已有 | KEEP + 重构边界 |
| Opaque Access Token | 已有 | KEEP 思路，REPLACE 实现 |
| Opaque Refresh Token | 部分已有 | REPLACE rotation/replay/family |
| Redis Server-side Session | 部分已有 | REPLACE 为 SecuritySession Aggregate |
| User -> RoleAssignment -> Role -> Permission | 缺失 | 新建核心领域模型 |
| User 无直接 Permission | 已满足 | 保持并加 DB/代码约束 |
| Role 无继承 | 已满足 | 保持；不引入继承 |
| Permission 稳定业务能力 | 部分已有 | MIGRATE 大写 CRUD code；删除 wildcard 语义 |
| GrantablePermission | 缺失 | 新增 Role 关系及统一 Delegation Check |
| authorityLevel | 缺失 | 新增并实施 Assignment-aware 管理边界 |
| Permission-specific Access / Grant Boundary | 缺失 | 替换现有用户/角色单 Scope |
| Scope 与 Permission 按 Assignment 绑定 | 冲突 | REMOVE 全局 EffectiveScope 算法 |
| 主部门 + 多关联部门 | 缺失 | 新增 Membership 实体 |
| 组织成员与安全范围解耦 | 冲突 | 重构 |
| 组织树 include-descendants | 部分已有 | Closure Table + Impact Analysis |
| DEV_OPS 全权限/全菜单/全范围 | 部分硬编码 | 统一 RootAuthorizationPolicy |
| 多 DEV_OPS 与最后有效 Root 保护 | 缺失 | 新增受控 Root Governance、并发计数和 LastEffectiveDevOpsGuard |
| 多 Client 与 AuthenticationMethod 解耦 | 缺失 | 新增配置模型 |
| ALLOW/KICK_OLD/REJECT_NEW | 缺失 | Redis Lua + SessionPolicy |
| 账号 ACTIVE/LOCKED/DISABLED/DEPARTED | 缺失 | 重构 User Lifecycle |
| 密码/权限变化全 Session revoke | 缺失 | SecurityChangeCoordinator |
| MFA/Challenge 架构 | 缺失 | 首版建立 Challenge/AAL/Factor Provider SPI 并实现 TOTP、单次 Recovery Code；WebAuthn/Passkey 后续接入 |
| Security Audit 独立且不可删除 | 缺失 | 新增 append-only 审计域 |
| Audit Visibility Policy | 缺失 | 新增统一策略和查询投影 |
| SELECT/UPDATE/DELETE/BATCH/EXPORT 范围控制 | 部分已有 | Permission-aware Scope Enforcement |
| IDOR 对象授权 | 缺失 | Scoped Repository + ResourceAuthorizationGuard |
| 前端 Menu/Permission 分离 | 部分已有 | KEEP 菜单；重构按钮与权限快照 |
| Session/在线设备管理 | 部分已有 | 新增 Session API/真实 UI |
| 自动化安全矩阵 | 严重不足 | Phase 0 起建立 |
| 权威数据库迁移体系 | 缺失 | 引入 Flyway，结束 DDL/dump 双事实源 |

---

# 4. Target Security Architecture

## 4.1 Bounded Responsibilities

```text
Authentication
  Primary Auth -> Optional Challenge/MFA -> Authenticated Subject
                                                |
                                                v
Session --------------------------------> AuthenticatedPrincipal
  Opaque Token / Rotation / Policy              |
                                                v
Authorization ------------------------> Permission Decision
  Assignment Grants / Root Policy                |
                         +------------------------+------------------+
                         v                                           v
Data Authorization                              Delegation
  (Assignment, Permission) AccessBoundary       (Assignment, Permission) GrantBoundary
                         |                                           |
                         +----------------------+--------------------+
                                                v
Security Relevant Change Coordinator
  Boundary -> Impact -> DB Mutation -> Audit -> Revocation Fence
                                                |
                                                v
Security Audit / Governance
```

建议不立即拆出多个 Maven 模块，以避免 `User/Department/Menu` 与安全模块之间形成循环依赖；先在 `spectra-core` 内建立清晰 package 边界：

- `core.identity`：User、Credential/Identity、生命周期、组织成员关系。
- `core.authorization`：Role、Permission、RoleAssignment、Scope、Delegation、Impact Analysis。
- `core.organization`：Department、Closure、组织变更影响。
- `core.navigation`：Menu 和 Role-Menu 可见性。
- `core.security.authentication`：登录编排、Challenge、认证方式。
- `core.security.session`：Session 应用服务和端口。
- `core.security.policy`：Client、AuthenticationMethod、Session/Password Policy。
- `core.security.audit`：Security Audit、可见性与写入策略。
- `core.security.change`：Security Relevant Change 协调器。

`spectra-security-spring-boot-starter` 只保留 Spring Security、Redis、Filter、Exception Handler 等基础设施 Adapter；登录 Controller 和安全业务规则移回业务域。`spectra-security-base` 只保留跨模块的 Principal、AuthorizationContext 和 Port，不再承载可变业务实体。

## 4.2 Request-Time Security Context

Opaque Token 只定位 SecuritySession。每个请求通过 Session 读取：

```text
AuthenticatedPrincipal
- userId
- sessionId
- clientId
- authenticationMethod
- subjectSecurityVersion
- root marker
- AuthorizationSnapshot reference/version
```

AuthorizationSnapshot 可以在服务端缓存，但必须保持 Assignment 结构：

```text
AssignmentGrant[]
- assignmentId
- roleCode
- authorityLevel
- permissions[]
- grantablePermissions[]
- permissionBoundaries: Map<Permission, AuthorizationScope>
- grantBoundaries: Map<Permission, AuthorizationScope>
```

禁止在 Snapshot 中只保留 `allPermissions + oneScope`。Session 不内嵌自描述权限；安全版本变化后旧 Session 立即失效。

## 4.3 Root Authorization

新增统一 `RootAuthorizationPolicy`：

- `ROLE_DEV_OPS` 的 active system-managed Assignment 被解析为 Root Subject。
- Root 对 Permission、Menu、Access Boundary、Grant Boundary 返回 ALL。
- Root 可绕过普通 Delegation Boundary，但不能绕过账户状态、Session 有效性、二次认证策略和 Security Audit。
- Root 判断只允许出现在 Root Policy / Authorization Engine 内，不允许业务 Service 比较角色字符串。
- 后台定时任务使用明确的 Machine/System Principal，不伪装成 DEV_OPS。

---

# 5. Domain Model

| 聚合/实体 | 主要职责与不变量 | 持久化位置 |
|---|---|---|
| User | 历史身份；ACTIVE/LOCKED/DISABLED/DEPARTED；维护 `securityVersion`；普通流程不物理删除 | PostgreSQL |
| AuthenticationIdentity | 某认证方式下的规范化标识、Provider、验证状态；不把所有方式塞进一个空字段很多的 Account | PostgreSQL |
| PasswordCredential | 密码 Hash、修改时间、过期/强制修改；与其他认证标识分离 | PostgreSQL，密钥不入日志 |
| DepartmentMembership | 主部门或关联部门；一个用户最多一个 active primary；不自动产生 DataScope | PostgreSQL |
| Role | `ROLE_*` 能力模板；无继承；authorityLevel 只用于管理边界；Root Role system-managed | PostgreSQL |
| Permission | 稳定 `resource:action` code；不等同 URL/按钮；code 部署后不可随意修改 | PostgreSQL catalog |
| RolePermission | Role 自己能做什么 | PostgreSQL |
| RoleGrantablePermission | Role 可向下授予什么；不生成第二套 permission code | PostgreSQL |
| RoleAssignment | User 获得 Role 的授权实例；有状态、有效期、版本、授权/撤销来源 | PostgreSQL |
| AssignmentPermissionBoundary | `(assignment, permission) -> accessScope`；只允许引用该 Role 实际拥有的 Permission | PostgreSQL |
| AssignmentGrantBoundary | `(assignment, permission) -> grantScope`；只允许引用该 Role 的 GrantablePermission | PostgreSQL |
| AuthorizationScope | 某一 Permission Boundary 独占或不可变引用的范围定义；`scopeMode` 仅允许 NONE/ALL/SELF/RULES，不存在用户全局 Scope | PostgreSQL |
| ScopeRule | RULES 模式下的结构化规则；首版包括部门节点 + `includeDescendants`、显式部门集合及已登记的资源归属规则 | PostgreSQL |
| DepartmentClosure | 组织祖先/后代关系；部门移动在单事务内维护 | PostgreSQL |
| Menu | 导航树/Feature Visibility；不承担后端授权 | PostgreSQL |
| SecurityClient | 首版启用 WEB/APP/WECHAT/MINI_PROGRAM；不实现 OPEN_API Client Credentials | PostgreSQL |
| AuthenticationMethod | PASSWORD/SMS/EMAIL/WECHAT/OIDC/PASSKEY 等方式及状态 | PostgreSQL；Secret 只存引用 |
| ClientAuthMethod | Client 允许的认证方式 | PostgreSQL |
| SessionPolicy | 每 Client 的 ALLOW/KICK_OLD/REJECT_NEW、maxSessions、TTL/absolute/idle 等 | PostgreSQL + 版本缓存 |
| SecuritySession | 用户、Client、Device、认证方式、Token Family、状态与版本 | Redis runtime aggregate |
| SecuritySubject | 首版只实现 HUMAN_USER；接口和值对象保留未来 SERVICE_PRINCIPAL 类型，但不提供创建、登录或授权路径 | Java domain contract |
| AuthenticationChallenge | Primary Authentication 后、Session 创建前的 Challenge 状态机；支持 MFA/step-up | Redis 短期状态，结果进 Audit |
| AuthenticationAssurance | Session 的认证时间、已完成因子和 AAL/step-up 状态 | Redis SecuritySession |
| MfaFactorProvider | 多 Factor SPI；首版交付 TOTP Provider，后续接入 WebAuthn/Passkey | Java SPI |
| MfaEnrollment | 用户已登记 Factor 的类型、状态、创建/验证/撤销时间；不保存可直接使用的秘密 | PostgreSQL |
| TotpCredential | TOTP secret 使用密钥管理支持的应用层信封加密；密钥、明文 secret 和二维码不得进入日志/Audit | PostgreSQL 密文 |
| RecoveryCode | TOTP 恢复码单次使用、逐条随机 salt + password-hash 保存；原文只在生成时展示一次 | PostgreSQL Hash |
| SecurityPolicy | 密码、锁定、Challenge/MFA 等 typed policy；避免一个万能 JSON 表 | PostgreSQL |
| SecurityAuditEvent | append-only 安全事实；before/after/reason/operator/target/client/IP/result | PostgreSQL 分区表 |
| SecurityChangeOutbox | DB 变更、Session 清理和缓存失效的可靠补偿 | PostgreSQL |

第一版直接采用 permission-specific boundary。`scopeMode` 是每个 `(RoleAssignment, Permission)` Boundary 的取值，不是 User/Role 的全局字段：`NONE` 表示该 Permission 是 capability-only、不参与数据范围；`ALL` 是显式全范围；`SELF` 只匹配当前主体拥有的数据；`RULES` 使用结构化规则集合。Permission Catalog 声明允许的模式及对应 ResourceScopePolicy。每个 active RoleAssignment 对 Role 提供的每个 Permission 必须有且只有一个 active AssignmentPermissionBoundary；每个 GrantablePermission 也必须有且只有一个 AssignmentGrantBoundary。缺失一律 fail closed，不能把缺失解释为 NONE 或 ALL。

Access Boundary 与 Grant Boundary 相互独立：操作者可以被明确授权“管理/授予某范围”，但不必因此获得该范围业务数据的读取权。系统不再施加全局或同 Permission 的 `GrantScope ⊆ AccessScope` 硬约束；任何向下授权只验证该 Permission 对应 Grant Boundary 是否包含目标 Permission Boundary。

## 5.1 Lifecycle Invariants

- LOCKED 是临时认证锁定；不等于管理员 DISABLED。
- DISABLED 立即 revoke all sessions；重新启用不恢复旧 Session。
- DEPARTED 立即 revoke、停止全部 active RoleAssignment 和 Membership；重新入职创建新授权，不恢复旧授权。
- 密码任何变化都 revoke all，包括当前 Session。
- Role 禁用、Permission/Grantable/Scope/authorityLevel 改变时，所有受影响用户 Session 失效。
- RoleAssignment 使用 REVOKED/EXPIRED 保留历史，不物理删除。
- 不存在全局 `ManagementScope ⊆ AccessScope` 约束；Grant Boundary 的合法性只在同一个 Permission 上按 operator Assignment 逐项判断。

---

# 6. Database Change Plan

## 6.1 Migration Governance

引入 Flyway 作为唯一 schema 事实源。最终物理表、字段、约束和索引由 Codex 在实现 Phase 1 时依据当前 PostgreSQL 命名、审计字段和模块分层规范完成设计与契约评审，不以旧表结构限制目标模型：

- 新环境从 `V1__init_target_schema.sql` 开始；V1 一次性创建完整目标 schema、约束和索引，不先复制旧 schema 作为 baseline。V2 建立运行时/迁移角色隔离和最小数据库权限，V3 将经审查的 Permission Catalog 固化为目标 `permission` seed。
- 默认明确设置 `baselineOnMigrate=false`。非空旧 schema 不允许被 Flyway 自动打 baseline 后假装已经符合目标模型。
- 旧环境使用独立、一次性的 export -> transform -> validate -> import/cutover 流程迁入由 V1 创建的干净目标 schema；旧表只作为受控迁移输入，不进入新运行时模型。
- V1 发布后保持不可变，后续真实 schema 变化使用 V2、V3 等 versioned migration；禁止改写已发布 migration。
- `docs/sql/db.dump` 降级为发布快照/测试夹具，不再手工维护为主迁移源。
- `docs/sql/<schema>/建表.sql` 继续作为汇总文档，由 migration 结果同步生成或核对。
- 不为旧认证、Permission、Scope 或 Session 模型长期维护兼容表、双写 Service 或 compatibility adapter。
- 当前已创建 `V1__init_target_schema.sql`、`V2__security_runtime_privileges.sql` 和 `V3__security_permission_catalog_seed.sql`；后续 migration 仍须保持 versioned、不可改写，并通过真实 PostgreSQL 门禁。

## 6.2 Target Tables / Changes

目标 schema 划分确定为：`spectra_security` 保存认证、授权、Session Policy 和 Security Audit 等高敏安全数据；`sys_user`、`sys_department`、`sys_menu` 等业务身份/组织/导航继续在 `spectra_core`。Phase 1 由 Codex 按项目 PostgreSQL snake_case、公共审计字段、ID 类型和外键规范完成最终列级 DDL。

### 修改

1. `spectra_core.sys_user`
   - status 改为显式枚举约束：ACTIVE/LOCKED/DISABLED/DEPARTED。
   - 新增 `security_version`、`locked_until`、`departed_at`、`status_reason`。
   - `department_id` 迁移到 Membership 后废弃。
   - 保留历史行；取消普通删除 API。
2. `spectra_core.sys_role`
   - 迁入/改建为 `spectra_security.role` 时新增 stable code、authority_level、state、system_managed、role_kind、version。
   - 移除旧 `scope` 字段。
3. `spectra_core.sys_department`
   - 增加 active code 唯一、parent FK、版本和移动约束；path 不再作为安全判断事实源。
4. `spectra_core.sys_rel_role_menu`
   - 保留概念，补齐 FK/RESTRICT 和活动唯一约束；Root 菜单不依赖穷举关系。

### 新增

- `spectra_core.sys_user_department_membership`
- `spectra_core.sys_department_closure`
- `spectra_core.sys_organization_version`
- `spectra_security.authentication_identity`
- `spectra_security.password_credential`
- `spectra_security.permission`
- `spectra_security.role`
- `spectra_security.role_permission`
- `spectra_security.role_grantable_permission`
- `spectra_security.role_assignment`
- `spectra_security.authorization_scope`
- `spectra_security.assignment_permission_boundary`
- `spectra_security.assignment_grant_boundary`
- `spectra_security.scope_rule`
- `spectra_security.security_client`
- `spectra_security.authentication_method`
- `spectra_security.client_auth_method`
- `spectra_security.session_policy`
- `spectra_security.password_policy`
- `spectra_security.mfa_enrollment`
- `spectra_security.totp_credential`
- `spectra_security.recovery_code`
- `spectra_security.root_policy`（singleton，含默认 1 的 `min_effective_dev_ops_users`、默认 3 且可配置的 `max_dev_ops_users` 和 version）
- `spectra_security.security_audit_event`（按时间分区）
- `spectra_security.security_change_outbox`

## 6.3 Constraints and Indexes

- Permission code：active 全局唯一，正则约束小写 `resource:action` 或必要的 `domain:resource:action`，禁止 `ROLE_` 和 `*`；Catalog 声明对应 ResourceScopePolicy 和是否允许数据边界。
- Role code：active 全局唯一，约束 `ROLE_[A-Z0-9_]+`。
- RoleAssignment：允许同一用户多 Assignment；不能用简单 `(user_id, role_id)` 唯一约束堵死未来边界实例，但相同 role + 完全相同 active boundary 应由应用防重复。
- 每个 active Assignment 的每个 RolePermission 恰有一条 active Permission Boundary；每个 RoleGrantablePermission 恰有一条 active Grant Boundary。Capability-only Permission 使用显式 NONE，缺失行仍表示配置不完整并 deny。
- Boundary 表分别以 `(assignment_id, permission_id)` 建 active unique；Boundary 引用的 Permission 必须属于该 Assignment 的 Role capability/grantable capability。
- 数据库不建立 `GrantScope ⊆ AccessScope` 约束；两类 Boundary 独立存在，包含关系在具体 Delegation Command 中按 Permission 校验。
- Boundary `scope_mode` 只允许 `NONE/ALL/SELF/RULES`；`NONE/ALL/SELF` 不允许 ScopeRule，`RULES` 至少一条合法规则。
- 同一 Scope 的组织规则 `(department_id, include_descendants)` 唯一；其他资源规则必须通过已注册 policy 的 schema 校验，不允许任意客户端 JSON 成为 SQL。
- 每用户最多一个 active primary Membership；associated Membership 唯一。
- FK 默认 `ON DELETE RESTRICT`；安全历史表不使用级联物理删除。
- `authority_level` 使用有限正整数范围；Root 保留值只允许 bootstrap/root governance 修改。
- RolePermission / GrantablePermission 建活动唯一索引及 permission、role 反向影响分析索引。
- RoleAssignment 建 user/status、role/status、validity 索引。
- Closure 建 `(ancestor_id, descendant_id)` PK 和 descendant 反向索引。
- Audit 建 timestamp、event_type、operator、target、result、correlation_id 索引；JSONB 只对批准的检索字段建立表达式索引。
- TOTP secret 使用密文列并绑定 key version；Recovery Code 只保存强 Hash、used_at 和原子消费 version，不保存可逆原文。

## 6.4 DEV_OPS Concurrency

首版支持多个 DEV_OPS，不再以“系统永远只有一个 Root”为前提。`minEffectiveDevOpsUsers` 默认 1；`maxDevOpsUsers` 默认 3，由 V1/部署配置初始化并只允许经过 step-up、审计和并发校验的 Root Governance 修改，不硬编码进 Role 表。标准生产布局推荐 2 个日常使用、责任人不同的正常 Root，加 1 个凭据离线保管并受到额外监控的 break-glass Root；三者都计入上限。任何可能减少有效 DEV_OPS 数量的操作，包括 User disable/depart、DEV_OPS Assignment revoke/expire、Root Role disable、移除最后可用认证标识等，都必须进入统一 `LastEffectiveDevOpsGuard`：

1. `SELECT ... FOR UPDATE` 锁定 `root_policy` singleton。
2. 在同一事务按 User ACTIVE、Role/Assignment ACTIVE 且有效期合法、至少一个可用认证标识等条件统计 effective DEV_OPS。
3. 创建时检查可配置上限；撤销或状态变化后若有效数量小于 1，拒绝整个事务。
4. 使用行锁和 expected version 防止两个 Root 并发撤销导致计数穿透。
5. 所有 DEV_OPS 必须完成 MFA enrollment；bootstrap 首次登录只能进入受限的 TOTP enrollment 流程，未达到要求 AAL 不得获得普通 Root Session。
6. 只允许已满足 step-up/MFA assurance 的 Root Governance Command 执行；bootstrap 不能成为长期绕过入口。
7. 在同一事务写 Assignment、Security Audit 和 Outbox；Audit 或 Redis revocation fence 不可用时 fail-closed。

自动风险锁定不能因为“最后一个 Root”而被静默绕过，否则会给暴力破解留下永久豁免。最后一个 Root 因风险事件进入 LOCKED 时，应触发最高级告警并使用受控 break-glass/恢复流程；最后 Root 保护主要阻止管理和授权变更把系统置于无 Root 状态。

Break-glass 必须有独立 Runbook，覆盖凭据分权保管、启用条件、身份核验、TOTP/Recovery Code 失效后的最终恢复、Session 强制短 TTL、操作后凭据轮换与复盘。任何 break-glass 登录、失败尝试、启用、使用、恢复和轮换都记为最高风险等级 Security Audit 并触发独立告警；Break-glass 仍不能绕过 Audit，也不能降低“最后一个有效 Root”保护。

普通 ADMIN 永远没有调用该 Application Service 的权限。直接绕过应用写数据库属于数据库管理员边界，不宣称由应用 RBAC 防住，但生产应用账号不得拥有任意 DDL/角色切换权限。

## 6.5 Legacy Table Disposition

| 旧对象 | 决策 |
|---|---|
| `sys_rel_user_role` | MIGRATE 到 RoleAssignment，完成后 REMOVE |
| `sys_authority` | MIGRATE 到 Permission catalog，完成后 REMOVE/重命名 |
| `sys_rel_role_authority` | MIGRATE 到 RolePermission，完成后 REMOVE |
| `sys_user_data_scope*` | [x] REMOVE（2026-08-15，V10）；历史行不自动映射 |
| `sys_role_data_scope*` | [x] REMOVE（2026-08-15，V10）；历史行不自动映射 |
| `sys_account` | [x] REMOVE（2026-08-15，V12）；历史行不自动转换 |
| `sys_log` | KEEP 为 Business Operation Log；新建独立 Security Audit |
| `sys_rel_role_menu`、`sys_menu` | KEEP + 约束增强 |

---

# 7. Redis / Token / Session Design

## 7.1 Token Format and Storage

- Access/Refresh Token 使用 CSPRNG 生成至少 256 bit 随机值，Base64URL 编码。
- Redis Key 使用 `HMAC-SHA-256(serverPepper, token)` 摘要；Pepper 来自密钥管理/环境，不入数据库、日志和 API。
- Access Token 固定约 5 分钟，不随普通请求滑动续期。
- Refresh/Session 同时受 idle timeout 和 absolute expiry 约束，具体由 versioned SessionPolicy 管理。

Web 端 Refresh Token 只通过 Cookie 传输：

- Cookie 建议名 `__Secure-spectra_refresh`，强制 `HttpOnly; Secure`；默认不设置 Domain，形成 Host-only Cookie；默认 `SameSite=Strict`，只有经部署级威胁评审确认必须跨站时才允许 `SameSite=None; Secure`，不使用宽泛 Domain。
- 登录与每次 Refresh Rotation 都用 `Set-Cookie` 轮换；logout/replay/revoke 必须清除 Cookie。
- 同时签发随机 CSRF token，并把其摘要绑定到 SecuritySession；浏览器在 `X-CSRF-Token` Header 回传，服务端执行 double-submit/session-bound 校验。
- Refresh、Logout 及其他使用 Cookie 的安全端点同时验证 Origin，缺失时验证 Referer，并使用精确 CORS allowlist；不能只依赖 SameSite。
- Web API 不接受 body 中的 Refresh Token；APP/小程序通过平台 secure storage 在 body 中提交。
- Cookie name、Host-only/显式 Domain、Path、SameSite、允许 Origin 和反向代理 HTTPS 感知全部由 typed deployment configuration 管理；安全默认值是 Host-only + Strict，生产启动校验禁止关闭 HttpOnly/Secure、禁止通配 Origin，并拒绝 `SameSite=None` 与非 Secure 组合。

建议 Key namespace：

```text
sec:v2:access:{tokenDigest}                 -> sessionId
sec:v2:refresh:{tokenDigest}                -> sessionId,familyId,generation,state
sec:v2:refresh-used:{oldTokenDigest}        -> familyId,generation,replayedAt
sec:v2:session:{sessionId}                  -> SecuritySession
sec:v2:user-sessions:{userId}               -> ZSET(sessionId, expiresAt)
sec:v2:client-sessions:{clientId}            -> ZSET(sessionId, expiresAt)
sec:v2:user-client-sessions:{userId}:{clientId} -> ZSET
sec:v2:user-device-sessions:{userId}:{deviceIdHash} -> ZSET
sec:v2:subject-version:{userId}              -> securityVersion
sec:v2:policy-version:{clientId}             -> sessionPolicyVersion
sec:v2:login-lock:{normalizedIdentityDigest} -> attempts/lockedUntil
sec:v2:challenge:{challengeId}                -> subject/client/requiredAal/attempts/expiresAt
sec:v2:step-up-proof:{proofDigest}            -> userId/sessionId/commandHash/aal/oneTime/expiresAt
```

索引只保存 sessionId，不保存可使用的 Token。Online API 返回 sessionId、token fingerprint 后 6 位、Client、Device、IP、登录/活跃时间和状态，绝不返回 Token。

## 7.2 Atomic Operations

使用经过单元和 Redis 集成测试的 Lua Script/Redis Function 实现：

1. `createSession`
   - 清理过期索引。
   - 在单次原子操作中执行 ALLOW/KICK_OLD/REJECT_NEW 和 maxSessions。
   - KICK_OLD 删除旧 Session 的 Access/Refresh/全部索引后再发布新 Session。
   - 比较 subjectSecurityVersion，防止“登录校验后并发禁用”创建 Session。
2. `rotateRefreshToken`
   - CAS 校验 sessionId、familyId、generation 和 current refresh digest。
   - 旧 Refresh 立刻移入 used marker，生成新 Access/Refresh mapping。
   - 旧 token 再次出现即判定 Replay，原子 revoke family/session。
3. `revokeSession`
   - 幂等删除 Access、Refresh、Session 和所有反向索引。
4. `revokeUser/revokeClient/revokeDevice`
   - 以索引遍历 + 批量原子子操作执行；先提高 subject version/fence，使未清完的 Session 也立即不可用。
5. `consumeChallenge/consumeStepUpProof`
   - 原子校验 challenge/proof 的主体、Session、commandHash、AAL、尝试次数和 TTL；proof 一次使用，不能跨高风险 Command 重放。

客户端必须单飞 refresh。第一版不为并行使用旧 Refresh Token 提供宽限；并行第二次请求按 Replay 撤销 Session，避免攻击者利用 grace window。

## 7.3 Refresh-Time Checks

Refresh Endpoint 在 Rotation 前必须检查：

- Session ACTIVE、未超过 absolute/idle expiry。
- User/AuthenticationIdentity 允许登录，不是 LOCKED/DISABLED/DEPARTED。
- Session subject version 等于权威版本。
- Client、Device、AuthenticationMethod 仍受当前策略允许。
- Refresh generation 正确且不是 used/replayed token。

Refresh 不从 Redis 中反序列化旧权限快照来恢复授权；成功后从当前 server-side AuthorizationSnapshot 版本建立新 Access Token mapping。

Redis/Session 是核心安全依赖。连接超时、读取失败、Lua 执行失败或状态无法判定时，不回退到本地缓存、旧 `SecurityUser` 或“暂时放行”：

- 受保护请求返回稳定的 `503 SECURITY_SESSION_UNAVAILABLE` 并拒绝执行业务逻辑。
- Login/Refresh/Session create/revoke 全部 fail-closed。
- 客户端收到该 503 时不得把它当 401 发起 Refresh，也不得删除本地会话材料；只展示暂时不可用并允许稍后重试。
- 监控必须区分 invalid session 与 security dependency unavailable，避免故障时形成 refresh storm。

## 7.4 DB / Redis Consistency and Races

Security Relevant Change 使用“安全优先的 revocation fence”：

1. DB 事务锁定被影响的 User/Role/Assignment，完成 Boundary 和 Impact 再校验。
2. 更新业务状态、递增 `security_version`，同事务插入 Security Audit 与 Outbox。
3. 在提交前调用 Redis fence：发布新 subject version 并使旧 Session 逻辑失效；Redis 失败则回滚 DB 变更。
4. DB 提交后异步/同步清理物理 Session；Outbox 负责崩溃重试。
5. 若 Redis 成功后 DB 提交失败，只会造成多余下线，不会造成权限放大。

角色大范围变更可先发布 role/change epoch 作为立即 fence，再由 worker 枚举受影响用户、提升 subject version 并物理清理。所有旧 Session 在 epoch 不匹配时必须 fail closed。

不能保证已经通过 Filter 且正在执行的请求被“倒退取消”。已确认的语义是：revocation fence 后所有新请求立即 fail closed；高风险写操作在提交前额外执行 `AuthorizationEpochGuard`，发现安全版本变化则回滚；一般已开始的读取允许在当前请求边界结束。

---

# 8. Authorization / DataScope / Delegation Design

## 8.1 Spring Security Integration

- `TokenAuthenticationFilter` 只负责解析 Bearer、查询/验证 SecuritySession、构造 `AuthenticatedPrincipal` 和设置 SecurityContext。
- Filter 不加载业务对象、不计算 DataScope、不执行 Grant Boundary、不滑动 Access TTL。
- GrantedAuthority 包含 `ROLE_*` 和 Permission code，供粗粒度 Method Security 使用。
- `AuthorizationService` 负责 Permission Decision；`RootAuthorizationPolicy` 是唯一 Root bypass 入口。
- 401：Token 缺失、无效、过期、Session revoked、账号状态不允许。
- 403：Session 有效但缺 Permission、Scope、authorityLevel 或 Grant Boundary。
- 503：Redis/Session 核心依赖不可用，安全状态无法判定；不得降级放行，也不得触发客户端 Refresh 循环。
- Session revoked 使用稳定 error code，例如 `SECURITY_SESSION_REVOKED`，客户端清理状态并重新认证。
- Logout 调用 SessionService revoke 当前 session；Refresh logout 也必须撤销 Access。
- 业务 Service 不能直接调用 Redis/SecUtil；通过 SessionRevocationPort 和 AuthorizationContextPort。

## 8.2 Permission-Specific Scope Resolution

核心算法：

```text
resolveAccessScopes(user, permission P):
  candidates = active (assignment, P, permissionBoundary)
               whose active role provides P
  if root -> ALL
  for each candidate boundary:
    NONE  -> capability-only decision; only when P catalog declares no data boundary
    ALL   -> explicit full resource universe for P
    SELF  -> subject-owned resources for P
    RULES -> normalize and evaluate registered rules for P
  return union only among these candidates for the same P

resolveGrantBoundaries(user, grantablePermission P):
  candidates = active (assignment, P, grantBoundary)
               whose role.grantablePermissions contains P
  if root -> ALL
  else -> retain every candidate's grantScope and authorityLevel
```

Grant 候选不能先把 GrantablePermission 和 GrantScope 分别全局并集后再组合。每个被授予 Permission 都必须找到一个实际 AssignmentGrantBoundary candidate，其 grantScope 包含目标 Assignment 对同一 Permission 请求的 Access Boundary；若目标还要获得该 Permission 的再授权能力，其 Grant Boundary 也必须被同一 operator grantScope 包含。该过程不要求 operator 对该 Permission 的 Access Boundary 覆盖 Grant Boundary。

## 8.3 Scope Algebra

提供纯领域组件：

- `ScopeNormalizer`：规范化 NONE/ALL/SELF/RULES；RULES 中被父节点 include-descendants 覆盖的子规则可去重，但保留审计原始请求。
- `ScopeUnion`：只在同一 Permission 的合格 Assignment 之间使用。
- `ScopeContains(container, requested, organizationVersion)`：同 Permission Grant Boundary 对目标 Access/Grant Boundary 的包含校验。
- `ScopeMatcher(scope, resourceAttributes)`：对象授权。
- `ScopeImpactAnalyzer(before, after, orgChange)`：判断扩张/收缩及受影响主体。

`NONE` 只能用于 Catalog 明确声明为 capability-only 的 Permission；不能用 NONE 表示“缺少配置”，缺失 Boundary 始终 deny。`ALL` 必须显式授予，不能作为迁移默认值。`SELF` 通过 ResourceScopePolicy 定义的 owner subject 判断，不等价于 primaryDepartment。`RULES` 只能使用服务端登记、可验证、可编译为参数化条件的规则类型。Organization Membership 只提供 UI 候选，不参与自动授权。

## 8.4 MyBatis / Repository Enforcement

目标不是要求开发者手写 `WHERE department_id IN (...)`，而是形成 fail-closed 两层防线：

1. 应用服务授权边界
   - 新增 `@ScopedAuthorization(permission = "order:read", mode = ACCESS)` 或等价 Method Security 元注解。
   - Aspect 建立不可伪造的 `AuthorizationExecutionContext(permission, user, session, scope)`。
   - 不从 Controller DTO 接收可信 Scope。
2. Repository/SQL 边界
   - MyBatis DataPermissionInterceptor 根据当前 Permission 的 Scope 生成谓词。
   - 受保护表没有 ExecutionContext 时 fail closed；只有显式 System Job Permit 可走内部路径。
   - 数据策略注册表描述 owner column、department column、关联策略，不再允许无理由 `ignore=true`。

覆盖要求：

- SELECT：列表、详情、统计都拼接范围谓词。
- UPDATE/DELETE：执行 `... WHERE id=? AND scopePredicate`，按影响行数判定 404/403，避免先查后改 TOCTOU。
- BATCH：对全部目标在同一 SQL/事务内加 Scope，输入 ID 数与授权影响数一致，否则整体拒绝。
- EXPORT：复用查询 Permission + 独立 export Permission，并始终应用同一 Scope。
- 关联子表：从受保护主表 EXISTS/JOIN，不假定子表有 department_id。
- Flowable/Native SQL/外部存储：使用 `ResourceAuthorizationGuard` + scoped repository adapter；不得绕过 MyBatis 后失去范围。

`DataScopeExecutor.withoutScope` REMOVE。确需系统任务访问全部数据时使用有名称、有用途、可审计的 `SystemDataAccessPermit`，Root 请求不等于 System Job。

## 8.5 IDOR

拥有 `resource:update` 只完成 capability gate。任何按 ID 的 read/update/delete/download/export 必须再调用对象 Scope Policy 或由 scoped SQL 约束。文件预览、AI conversation、工作流实例/任务、通知 inbox 和用户管理都需注册资源归属策略。

## 8.6 Delegation and Authority Level

统一 `GrantBoundaryService.evaluate(command, operatorContext)`，覆盖：

- 创建/修改 Role。
- Role Permission / GrantablePermission 变化。
- 创建、替换、修改、撤销 RoleAssignment。
- 任一 Permission 的 Access Boundary / Grant Boundary 变化。
- authorityLevel 变化。
- 角色复制。
- 部门变化引起的有效边界变化。

每个请求 Permission `p` 的校验为：

```text
exists operatorAssignment a:
  p in a.role.grantablePermissions
  AND a has active grantBoundary(p)
  AND requestedTargetAccessBoundary(p) subsetOf a.grantBoundary(p)
  AND requestedTargetGrantBoundary(p), if any, subsetOf a.grantBoundary(p)
  AND targetAuthorityLevel < a.authorityLevel
```

多个 Permission 可以分别由不同 operator Assignment 覆盖，但某个 Permission 不得借另一个 Permission 或 Assignment 的 Grant Boundary/authorityLevel。不存在全局 `ManagementScope ⊆ AccessScope` 检查。普通管理员不能给自己创建/修改授权；自授权一律拒绝，Root Governance 使用单独流程。

## 8.7 Role Change Impact Analysis

Role 高风险修改采用 Preview + Apply：

1. Preview 读取 expected version，计算 before/after Permission、Grantable、authorityLevel。
2. 枚举 active RoleAssignment 和用户，计算有效权限/范围扩张、收缩、管理边界变化和 Session 数量。
3. 检查操作者对每个新增 Permission/Scope 的 Grant Boundary。
4. 生成有过期时间、绑定 operator/role/version/requestHash 的 impact token。
5. Apply 在事务中再次计算并比较 token；任何版本变化则拒绝重新 preview。
6. 变更、审计、securityVersion、revocation fence 作为一个 Security Change Command 完成。

authorityLevel 修改还必须分析现有 RoleAssignment 是否变成操作者不可管理、GrantablePermission 是否可向更高边界扩散。DEV_OPS level 不进入普通 Apply API。

## 8.8 Organization Impact Analysis

- 新增子部门到被 include-descendants 覆盖的节点，会扩大授权，必须在部门变更 preview 中列出受影响 Assignment/User。
- 显式部门集合不会因新增兄弟部门扩大。
- Move/Merge/Delete 在单 DB 事务维护 adjacency + closure + organizationVersion。
- 扩张和收缩都写 Security Audit；Effective Authority 变化的用户全部 revoke。
- 部门删除前必须处理 Membership、ScopeRule 和业务数据归属；禁止级联删除授权历史。

## 8.9 MFA, Step-up and High-risk Approval Extension

首版 Authentication 架构不能把 `Password success` 等同于 `Session created`：

```text
Primary Authentication
  -> AuthenticationRiskEvaluation
  -> zero or more AuthenticationChallenge
  -> required AuthenticationAssuranceLevel reached
  -> SecuritySession issued
```

- `MfaFactorProvider` SPI 统一 enroll/challenge/verify/revoke，不把 TOTP、WebAuthn/Passkey 等实现写死进 Controller/Filter；一个主体可以登记多个 Factor，Policy 决定组合和所需 AAL。
- SecuritySession 保存 `authTime`、`assuranceLevel`、已完成 factor type 和最近 step-up 时间，不保存 factor secret。
- 高风险 Command 声明 required assurance；不足时返回 `STEP_UP_REQUIRED`，完成 challenge 后使用短时、绑定 user/session/commandHash 的 proof 重试。
- 首版必须交付 TOTP enrollment、二维码/手工密钥一次性展示、首次验证码确认、登录/step-up challenge、撤销与重置流程。TOTP secret 使用带 key version 的信封加密，不可只做 Hash；WebAuthn/Passkey 作为后续 Provider 接入。
- Recovery Code 与 TOTP enrollment 一起生成，原文只展示一次，每个 code 使用独立强 Hash 保存并在单事务中原子消费；成功使用、重放和失败尝试全部审计。恢复码耗尽或无法使用时，不提供普通管理员绕过 MFA 的 API，最终恢复必须进入 break-glass Runbook。
- 所有 DEV_OPS 强制达到 MFA AAL；未登记或 Factor 不可用时不得降级为密码单因子 Root Session。普通用户是否强制 MFA 由 SecurityPolicy/Client Policy 配置。
- 双人审批首版不实现。高风险 Command 预留 `HighRiskApprovalGate`/`approvalContext` 扩展点，但首版策略仍是单操作者 + step-up + 完整 Audit，不能伪造“已双人审批”。
- `SecuritySubject` 首版只接受 HUMAN_USER。未来 SERVICE_PRINCIPAL 通过 subject type、独立 authentication flow 和独立 policy 扩展；首版不建 Client Credentials API、不签发 OPEN_API Token、不把机器主体伪装成用户。

---

# 9. API Change Plan

所有路径为 Proposed；最终采用项目 API 版本机制发布 v2，不长期保留 v1/v2 双写。

## 9.1 Authentication / Session

- `POST /auth/login`：增加 `client_id`、device metadata、认证方式；可能返回 `CHALLENGE_REQUIRED`，只有达到要求 AAL 后才返回 access token、expiresAt、sessionId。Web Refresh Token/CSRF Cookie 通过 `Set-Cookie` 下发，响应体不含 Refresh Token。
- `POST /auth/challenges/{challengeId}/verify`：通用 MFA/step-up challenge contract；首版启用 TOTP 和 Recovery Code Provider。
- `POST /auth/mfa/totp/enroll`、`POST /auth/mfa/totp/confirm`、`DELETE /auth/mfa/factors/{id}`：首版 TOTP 登记、确认和受保护撤销；撤销最后一个 DEV_OPS Factor 必须拒绝或进入 Root break-glass 治理。
- `POST /auth/mfa/recovery-codes/rotate`：达到 step-up AAL 后重新生成，旧 codes 全部失效，原文只返回一次；不提供读取原文 API。
- `POST /auth/session/refresh`：一次性 Rotation；Web 只读取限定 Path 的 HttpOnly Cookie 并校验 `X-CSRF-Token`、Origin/Referer，APP/小程序从 secure storage 在 body 提交。
- `POST /auth/session/logout`：撤销当前 Session/Family，幂等；Web 同样要求 CSRF 防护并清 Cookie。
- `GET /sessions`：用户查看自己的设备/Client Session。
- `DELETE /sessions/{sessionId}`：用户下线自己的某 Session。
- `DELETE /sessions?device_id=...`、`?client_id=...`：下线自己的设备/Client。
- `GET /security/sessions`：受 `session:read` 及该 Permission 的 Access Boundary 保护。
- `POST /security/sessions/{id}/revoke`、`POST /security/users/{id}/sessions/revoke`：管理员强制下线。

## 9.2 User / Identity

- `GET/POST /users`、`GET/PATCH /users/{id}/profile`：普通资料与安全操作拆分。
- `POST /users/{id}/disable|enable|depart|reinstate|unlock`：独立 Permission、reason 和审计。
- `POST /users/{id}/password/reset`：独立高风险权限、全 Session revoke。
- `PUT /me/password`：成功后当前及全部 Session revoke。
- `GET/POST/DELETE /users/{id}/department-memberships`：主/关联部门显式管理。
- 普通 `DELETE /users/{id}` 废弃；如未来支持“从未使用误建账号”物理删除，使用独立 Root-only API 和严格前置检查。

## 9.3 Role / Permission / Assignment / Scope

- `GET/POST/PATCH /security/roles`。
- `POST /security/roles/{id}/impact-preview` + 带 impact token 的 Apply。
- `PUT /security/roles/{id}/permissions`。
- `PUT /security/roles/{id}/grantable-permissions`。
- `POST /security/roles/{id}/authority-level/change`。
- `GET /security/permissions`：catalog 查询；普通 UI 不提供任意 code CRUD。
- `GET/POST /users/{userId}/role-assignments`。
- `GET/PATCH/DELETE /role-assignments/{id}`：修改 boundary 或 revoke。
- 每个 Permission 的 Access Boundary、每个 GrantablePermission 的 Grant Boundary 作为 Assignment Command 的一部分提交；capability-only 使用显式 NONE，其余使用 ALL/SELF/RULES；服务端逐 Permission 校验并绑定 organizationVersion。
- Role Copy 若实现，只暴露 `POST /roles/{id}/copy-preview` / apply，并走完整创建校验。

## 9.4 Menu / Organization

- `GET /menus/current` 保留；Root 隐式返回全部 active menu。
- `PUT /roles/{id}/menus` 保留为 UX 配置，不改变 Permission。
- Department 增加 move/merge/delete preview/apply，提交 expected organizationVersion。

## 9.5 Security Governance / Audit

- `GET/PUT /ops/security/clients`；首版不允许启用 OPEN_API/Client Credentials。
- `GET/PUT /ops/security/authentication-methods`。
- `GET/PUT /ops/security/session-policies/{clientId}`。
- `GET/PUT /ops/security/password-policy`。
- Provider Secret 只接受 secret reference/rotate command，不回显 secret。
- `GET /security/audit-events`、`POST /security/audit-events/export`，统一走 AuditVisibilityPolicy。
- Root 生命周期使用 `/ops/security/root-governance/*`；第一版可只通过受控 CLI/运维 Command 暴露治理入口，不急于开放 UI。Bootstrap 仅用于初始化并强制转入 TOTP enrollment，不能绕过后续 MFA、last Root Guard 或 Audit。

---

# 10. Frontend Change Plan

## 10.1 spectra-ui

- Access Token 默认只保存在内存；Web Refresh Token 使用 `__Secure-` HttpOnly + Secure Cookie，默认 Host-only + SameSite=Strict，只有部署配置明确要求时才使用 None；Path、Origin allowlist 和 CSRF 参数来自经启动校验的 typed deployment configuration。
- 新建专用、无普通 401 interceptor 的 refresh transport；所有请求共享一个可 reject 的 single-flight Promise。
- 重试只允许一次，并使用新 Access Token；Refresh 失败统一清理内存、菜单、权限和用户信息，跳登录并展示 Session expired/revoked 原因。
- `503 SECURITY_SESSION_UNAVAILABLE` 不触发 Refresh、不清除 Cookie/本地会话材料，只展示安全服务暂时不可用并退避重试。
- 统一 401（未认证/Session 失效）和 403（已认证但无权）；无菜单页面转 403。
- 登录成功后通过 `/me/security-context` 或等价端点获取 roles、permissions、menus，不把客户端快照当安全事实。
- `v-owner` 改为基于 Permission code 的 UX 指令，删除 fabricated `ROLE:${role}`；Role 判断只用于明确 UX，不替代 Permission。
- RBAC 页面拆为 Role capability、Grantable capability、authorityLevel、菜单四个区；高风险修改先显示 Impact Preview。
- 用户编辑页移除直接 user scope 和简单 role_ids；新增 RoleAssignment 列表/编辑器，按 Permission 展示 Access Boundary、按 GrantablePermission 展示 Grant Boundary，并显示有效期、来源和 Impact Preview。
- 用户组织 UI 支持主部门 + 关联部门，并明确提示“关联部门不自动授予数据权限”。
- 新建真实 Session/Online 页面：按用户、Client、Device 查询并 revoke，不显示 Token。
- 在“运维管理/安全中心”下增加 Authentication Method、Client、Session Policy、Password Policy、Security Audit；仅 Root 菜单可见且后端 Root-only。
- 增加 MFA 安全设置：TOTP enrollment/确认/撤销、Recovery Code 一次性展示/轮换和 step-up challenge；前端永不持久化 TOTP secret、二维码内容或 Recovery Code，DEV_OPS 未完成 enrollment 只能进入受限引导页。
- Security Audit 页面按策略返回的脱敏投影展示，不在前端自行隐藏敏感字段。
- 删除源码中的开发默认账号/密码/验证码。

## 10.2 spectra-app

- 修复 401 single-flight；刷新重试必须携带新 Access Token，等待队列完整 resolve/reject。
- H5 采用 HttpOnly Refresh Cookie + CSRF Header；App 使用 OS secure storage/Keychain/Keystore adapter；小程序使用平台安全能力并评估其存储边界。
- Access Token 可短期放内存；应用重启通过 Refresh 恢复，不以 storage 中 Access Token 是否存在判断登录。
- 统一传递注册的 clientId、真实 device installation id 和 device metadata；删除固定占位 ID。
- AuthenticationMethod 列表由 Client policy 驱动，后端未允许的方式不展示；前端不能自行决定可用方式。
- 支持 TOTP challenge 和 Recovery Code 输入；Enrollment 页面只在受支持 Client 开放，WebAuthn/Passkey 后续通过同一 Factor UI contract 扩展。
- Session revoked、密码变化、被禁用等 error code 统一清理和跳转。
- Redis/Session 不可用的 503 与无效 Session 的 401 分开处理，避免清凭据和 refresh storm。
- 增加 request/auth/bootstrap 单元测试；H5、MP-WEIXIN、APP 分别做集成验收。

---

# 11. Security Audit Plan

## 11.1 Event Model

`security_audit_event` 至少包含：

- eventId、eventType、eventVersion、occurredAt、result。
- operatorType、operatorUserId、operatorSessionId、operatorRoleAssignments。
- targetType、targetId、targetDisplaySnapshot。
- before/after（经过 schema 化和脱敏的 JSONB）。
- reason、correlationId、requestId、changeId。
- clientId、deviceIdHash、authenticationMethod、IP、User-Agent 摘要。
- riskLevel、rootOperation、stepUpAuthenticationId。
- errorCode，不保存异常堆栈中的秘密。

覆盖事件包括 Prompt 中列出的 Authentication、Account Lifecycle、Password、Role、Permission、Grantable、Assignment、Scope、Organization、Session、Policy 和 DEV_OPS 操作；另外增加验证码发送/校验限流、审计导出、Root Governance 尝试和 Scope Bypass/System Job Permit。

首版事件类型 catalog：

```text
AUTH_LOGIN_SUCCEEDED / AUTH_LOGIN_FAILED / AUTH_LOGOUT
TOKEN_REFRESH_SUCCEEDED / TOKEN_REFRESH_FAILED / REFRESH_TOKEN_REPLAY_DETECTED
AUTH_CHALLENGE_CREATED / AUTH_CHALLENGE_SUCCEEDED / AUTH_CHALLENGE_FAILED
ACCOUNT_LOCKED / ACCOUNT_UNLOCKED
USER_CREATED / USER_ENABLED / USER_DISABLED / USER_DEPARTED / USER_REINSTATED
PASSWORD_CHANGED / PASSWORD_RESET / PASSWORD_CHANGE_REQUIRED
ROLE_CREATED / ROLE_UPDATED / ROLE_ENABLED / ROLE_DISABLED
ROLE_AUTHORITY_LEVEL_CHANGED
ROLE_PERMISSION_CHANGED / ROLE_GRANTABLE_PERMISSION_CHANGED
ROLE_ASSIGNMENT_CREATED / ROLE_ASSIGNMENT_UPDATED / ROLE_ASSIGNMENT_REVOKED / ROLE_ASSIGNMENT_EXPIRED
ASSIGNMENT_PERMISSION_BOUNDARY_CHANGED / ASSIGNMENT_GRANT_BOUNDARY_CHANGED
PRIMARY_DEPARTMENT_CHANGED / ASSOCIATED_DEPARTMENT_CHANGED
ORGANIZATION_NODE_CREATED / ORGANIZATION_NODE_MOVED / ORGANIZATION_NODE_MERGED / ORGANIZATION_NODE_DELETED
AUTHORIZATION_IMPACT_PREVIEWED / AUTHORIZATION_IMPACT_APPLIED / AUTHORIZATION_BOUNDARY_DENIED
SESSION_CREATED / SESSION_REVOKED / DEVICE_SESSIONS_REVOKED / CLIENT_SESSIONS_REVOKED / USER_SESSIONS_REVOKED
AUTHENTICATION_METHOD_CHANGED / CLIENT_AUTH_METHOD_CHANGED
SESSION_POLICY_CHANGED / PASSWORD_POLICY_CHANGED / SECURITY_POLICY_CHANGED
DEV_OPS_HIGH_RISK_OPERATION / ROOT_ASSIGNMENT_CHANGED / ROOT_GOVERNANCE_DENIED
MFA_FACTOR_ENROLLED / MFA_FACTOR_VERIFIED / MFA_FACTOR_REVOKED / MFA_RECOVERY_CODE_USED / MFA_RECOVERY_CODE_REPLAYED
BREAK_GLASS_LOGIN_SUCCEEDED / BREAK_GLASS_LOGIN_FAILED / BREAK_GLASS_RECOVERY_STARTED / BREAK_GLASS_RECOVERY_COMPLETED / BREAK_GLASS_CREDENTIAL_ROTATED
SECURITY_AUDIT_VIEWED / SECURITY_AUDIT_EXPORTED
SECURITY_AUDIT_ARCHIVE_STARTED / SECURITY_AUDIT_ARCHIVE_COMPLETED / SECURITY_AUDIT_ARCHIVE_FAILED / SECURITY_AUDIT_ARCHIVE_VERIFIED
SYSTEM_DATA_ACCESS_PERMIT_USED
```

## 11.2 Write Guarantees

- 安全状态变更：Audit 与业务变更在同一 PostgreSQL 事务写入；写审计失败则变更失败。
- 高风险安全写操作（包括所有 Root Governance、Role/Assignment/Boundary、账号状态、密码、Session/Policy 变更）在 Audit writer 不可用、写入超时或结果不确定时一律 fail-closed；DEV_OPS 没有例外。
- Authentication success/failure：使用专用 durable writer；不能依赖普通异步 `@ULog`。
- Redis Session 操作：先产生不可伪造 changeId，操作完成后写结果；失败/重放同样记录。
- Outbox 负责外部归档/告警，不是审计事实本身的唯一存储。
- `@ULog` 继续服务普通 Business Operation Log，不能替代 Security Audit。

## 11.3 Immutability / Visibility / Redaction

- 应用写入账号对 Audit 表只有 INSERT；查询账号只读；无 UPDATE/DELETE Service/API，应用层任何用户（包括 DEV_OPS）都不能删除或篡改事件。
- 可选 PostgreSQL trigger 拒绝应用角色 UPDATE/DELETE；分区维护只允许 DBA/受控运维身份。
- DEV_OPS 读取全部脱敏审计，但不能隐藏/删除自己的事件。
- SYSTEM_ADMIN 经 `AuditVisibilityPolicy` 查看：自己账号事件、自己执行的管理操作，以及 `audit:read` 对应 Permission Access Boundary 覆盖主体的公开事件。
- DEV_OPS 身份、Provider 内部、Token/Redis 标识、核心策略秘密对非 Root 使用专用 projection 脱敏。
- 永不记录密码、Access/Refresh Token、验证码、Provider Secret、Private Key；Token 仅可记录不可逆 fingerprint。
- 复用并扩展 `AuditLogSanitizer`，对 before/after DTO 做 allowlist schema，而不是只靠黑名单。

## 11.4 Retention

默认在线热存 12 个月，默认总保留期至少 5 年，可按部署治理要求延长但不得由普通应用配置静默缩短。12 个月后的数据允许由独立归档流程迁入加密、不可变存储，并保留 manifest、记录数、时间范围、内容摘要、完整性校验/批次签名和可恢复查询索引。应用层不提供删除/篡改能力；热分区卸载或归档介质上的最终处置只能由数据库/存储治理流程按已批准保留策略执行。每次归档、校验、恢复查询和最终处置本身都必须写 Security Audit；归档失败不得造成热数据提前移除。

---

# 12. Session Revocation Matrix

| 操作 | Revoke | 范围 |
|---|---|---|
| 头像、昵称、普通展示信息 | No | — |
| 语言、时区 | No | — |
| 主动修改密码 | Yes | 用户全部 Session，含当前 |
| 管理员重置密码 | Yes | 目标用户全部 Session |
| 强制修改/密码过期修改 | Yes | 用户全部 Session |
| 登录标识绑定/解绑 | Depends | 当前认证标识被解绑或安全风险变化时全部；新增已验证备用标识可仅审计 |
| User ACTIVE -> LOCKED | Yes | 用户全部 Session |
| User ACTIVE -> DISABLED | Yes | 用户全部 Session |
| User -> DEPARTED | Yes | 用户全部 Session；撤销 active Assignment |
| DISABLED/LOCKED -> ACTIVE | No old session restored | 用户必须重新登录 |
| DEPARTED -> ACTIVE | No old assignment/session restored | 必须重新授权、重新登录 |
| RoleAssignment 创建 | Yes | 目标用户全部 Session |
| RoleAssignment Role 替换 | Yes | 目标用户全部 Session |
| RoleAssignment 任一 Permission Access/Grant Boundary 或有效期修改 | Yes | 目标用户全部 Session |
| RoleAssignment revoke/expire | Yes | 目标用户全部 Session |
| Role Permission 增删 | Yes | 所有 active Assignment 用户 |
| Role GrantablePermission 增删 | Yes | 所有 active Assignment 用户 |
| Role authorityLevel 修改 | Yes | 所有 active Assignment 用户 |
| Role enable/disable | Yes | 所有 active Assignment 用户 |
| Role 名称/备注修改 | No | — |
| Role Menu 修改 | 通常 No | 重新加载菜单；不改变后端权限 |
| Permission 展示名称修改 | No | — |
| Permission code/风险属性修改 | Yes / normally forbidden | 所有受影响用户；建议 code 不可原地改 |
| 主部门/关联部门普通成员关系变化 | Depends | 仅当 Impact Analyzer 证明 Effective Authority/SELF 语义受影响时 |
| associatedDepartments 增加 | No by itself | 不得自动扩大 Scope |
| Department 新增在 include-descendants 节点下 | Yes | 所有范围因此扩张的用户 |
| Department move/merge/delete | Depends, generally Yes | 所有 Scope/Membership/资源归属受影响用户 |
| Session Policy 修改 | Yes | 策略要求不再合规的 Session；核心 TTL 缩短可全 Client revoke |
| Client 禁用 | Yes | 该 Client 全部 Session |
| AuthenticationMethod 禁用 | Yes | 使用该方式建立的全部 Session，或按确认策略执行 |
| MFA Factor enrollment/撤销/重置 | Yes | 用户全部 Session，完成操作的受限 enrollment/step-up context 也在提交后失效 |
| Recovery Code 轮换 | Yes | 用户全部 Session；旧 codes 原子失效 |
| 单个 Recovery Code 使用 | No automatic | 当前登录继续，但提升风险标记并审计；策略可要求完成 TOTP 重登记后重建 Session |
| Password Policy 修改 | Depends | 不追溯普通复杂度；强制过期/风险策略改变时受影响用户 |
| 单 Session 下线 | Yes | 指定 Session |
| 单设备下线 | Yes | 用户该 device 全部 Session |
| 单 Client 下线 | Yes | 用户该 Client 全部 Session |
| 用户全部下线 | Yes | 用户全部 Session |
| Refresh Replay | Yes | 对应 Session/Family；高风险时可升级为用户全部 Session |
| Root Assignment 增删改 | Yes | 目标 Root 全部 Session；并对治理操作 step-up/audit |
| Break-glass 使用或恢复完成 | Yes | 命令完成后撤销该 Root 全部 Session，轮换相关凭据并重新按正常 MFA 登录 |

补充 Root 不变量：如果 User disable/depart、认证标识移除、Root Role disable 或 Root Assignment revoke/expire 会使 effective DEV_OPS 数量降到 0，则操作在产生 revoke 前整体拒绝并审计 `ROOT_GOVERNANCE_DENIED`。自动风险 LOCKED 仍可生效，但必须触发 break-glass 告警流程。

---

# 13. Permission Catalog

本节是 Codex 扫描当前全部 Controller、`@PreAuthorize`、Service 高风险动作、菜单、前端按钮和数据资源后生成的首版 Permission Catalog，不是由旧大写 CRUD code 机械换名。实现时将其固化为机器可读 catalog/Flyway seed，并用 Controller/Scope Policy contract test 检查遗漏。业务负责人只需复核业务语义和委派策略，不负责重新人工生成 catalog。

每个 Permission 在 catalog 中声明 ResourceScopePolicy 和允许的 Boundary 模式：非数据能力只允许 `NONE`；数据能力允许按 Assignment 选择显式 `ALL`、`SELF` 或 `RULES`。实际 `scopeMode` 永远存于 permission-specific Boundary，不能存为 User/Role 全局 Scope。旧 Permission code 只在一次性 migration mapping 中出现；完成映射和差异验收后删除旧 catalog、关系和运行时 evaluator。

标记：`H` 高风险；`R` DEV_OPS Only；`D` 可被纳入 Role.grantablePermissions；`N` 不可向下委派。

## 13.1 Identity / Authorization / Governance

| Permission | 标记 | 说明 |
|---|---|---|
| `user:read` | D | 查看该 Permission Access Boundary 覆盖的用户 |
| `user:create` | H,D | 创建普通用户，不含授权 |
| `user:update-profile` | D | 修改普通资料 |
| `user:disable` / `user:enable` | H,D | 生命周期管理 |
| `user:depart` / `user:reinstate` | H,D | 离职/重新入职 |
| `user:unlock` | H,D | 解除安全锁定 |
| `user:reset-password` | H,D | 管理员重置密码 |
| `user:reset-mfa` | H,D | 普通用户 MFA 恢复；目标为 DEV_OPS 时必须转 Root Governance/break-glass，普通管理员永远拒绝 |
| `user:assign-role` | H,D | 仍需 Grant Boundary |
| `role:read` | D | 查看角色 |
| `role:create` / `role:update` | H,D | 基础定义，仍需 Boundary |
| `role:disable` | H,D | 禁用角色 |
| `role:delete` | H,D | 仅无历史/无 Assignment 时；否则禁用 |
| `role:configure-permissions` | H,D | 配置 RolePermission |
| `role:configure-grantables` | H,D | 配置 GrantablePermission |
| `role:change-authority-level` | H,D | 修改等级并执行 Impact |
| `role-assignment:read` | D | 查看授权实例 |
| `role-assignment:create` / `role-assignment:update` / `role-assignment:revoke` | H,D | 统一 Grant Boundary |
| `permission:read` | D | 读取 catalog |
| `permission:manage-catalog` | H,R,N | 部署/Root 管理元数据，不用于普通动态 CRUD |
| `department:read` / `department:create` / `department:update` | D | 组织基础操作 |
| `department:move` / `department:merge` / `department:delete` | H,D | 必须 Impact Preview |
| `menu:read` / `menu:create` / `menu:update` / `menu:delete` / `menu:assign` | D | UX 导航管理 |
| `session:read` | D | 按可见性查看 Session |
| `session:revoke` / `session:revoke-user` | H,D | 单 Session / 用户全部下线 |
| `audit:read` | D | 受 AuditVisibilityPolicy 限制 |
| `audit:export` | H,D | 导出是独立风险 |
| `security:auth-method:read` | R,N | Root 运维 |
| `security:auth-method:update` | H,R,N | Provider/登录方式管理 |
| `security:session-policy:read` / `security:session-policy:update` | H,R,N | Session 核心策略 |
| `security:password-policy:read` / `security:password-policy:update` | H,R,N | 密码核心策略 |
| `security:mfa-policy:read` / `security:mfa-policy:update` | H,R,N | MFA/AAL/Factor 核心策略；DEV_OPS 强制项不可关闭 |
| `security:client:update` | H,R,N | Client 管理 |
| `security:root:manage` | H,R,N | Root Governance，需 step-up |
| `security:audit:archive` | H,R,N | 触发受控归档/校验；不是删除权限，归档自身必须审计 |

## 13.2 System / File / Notification

| Permission | 标记 | 说明 |
|---|---|---|
| `config:read` / `config:update` | H,D | 普通业务配置；安全配置不混入 |
| `dictionary:read` / `dictionary:manage` | D | 字典查询/管理 |
| `region:read` / `region:manage` | D | 行政区划 |
| `system-monitor:read` | R,N | JVM/CPU/内存等运维信息 |
| `security:crypto-key:rotate` | H,R,N | 当前 CryptoController 高危操作 |
| `file:upload` / `file:read` | D | 必须对象归属校验 |
| `file:delete` | H,D | 删除文件 |
| `file:admin-read` | R,N | 全局文件元数据 |
| `notification:read` / `notification:mark-read` / `notification:delete-self` | D | 只允许本人 inbox |
| `notification-preference:update` | D | 本人偏好 |
| `notification-admin:read` | D | 运维监控 |
| `notification-admin:send` / `retry` / `cancel` | H,D | 独立动作 |
| `notification-template:manage` | H,D | 模板管理 |

## 13.3 Workflow

| Permission | 标记 | 说明 |
|---|---|---|
| `workflow-form:read` / `workflow-form:design` / `workflow-form:publish` / `workflow-form:delete` | D；publish/delete 为 H | 替代 WF_FORM CRUD |
| `workflow-process:read` / `workflow-process:deploy` / `workflow-process:activate` / `workflow-process:suspend` | D；后三者 H | 拆分流程高风险动作 |
| `workflow-instance:read` / `workflow-instance:start` / `workflow-instance:terminate` | D；terminate H | 实例对象范围校验 |
| `workflow-task:read` / `workflow-task:complete` / `workflow-task:reject` / `workflow-task:transfer` / `workflow-task:delegate` | D；transfer/delegate H | 任务候选人/归属校验 |

## 13.4 OA

| Resource | 建议 Permission | 风险拆分 |
|---|---|---|
| Application | `oa-application:read/create/update/submit/withdraw/cancel` | submit/cancel 作为状态动作 |
| Application Type | `oa-application-type:read/manage` | manage 为 H |
| Leave | `leave:read/create/update/submit/withdraw/cancel` | 审批由 workflow-task 控制 |
| Calendar | `calendar:read/manage` | 需明确个人/部门事件 Scope |
| Meeting | `meeting:read/create/update/respond/check-in/record` | record/update 可分配 |
| Contact | `contact:read` | 严格按组织/公开属性 |
| Document | `document:read/create/update/delete/version` | delete/version 为 H |
| Asset | `asset:read/create/update/assign/transfer/retire` | 资产状态动作拆分 |
| Supply | `supply:read/create/update/inbound/issue/return/adjust` | adjust 为 H |
| Purchase | `purchase:read/create/update/submit/withdraw/cancel/execute/receive` | execute/receive 为 H |
| Reimbursement | `reimbursement:read/create/update/submit/withdraw/cancel/pay` | pay 为 H |
| Contract | `contract:read/create/update/delete/version/sign/activate/terminate/archive/run-reminder` | sign/activate/terminate/run-reminder 为 H |
| Report | `report:read`、`report:export` | export 独立 H |
| Workbench | `workbench:read` | 聚合结果仍按各资源 Scope |

## 13.5 AI

- `ai-conversation:read/create/update/delete`：所有操作必须检查 conversation owner/scope。
- `ai:ask`：使用模型能力；独立限额/敏感数据策略，不与 conversation CRUD 混同。

当前 `QUERY/INSERT/UPDATE/DELETE` code 通过明确映射迁移，不做机械小写替换。没有独立授权意义的内部 CRUD 不创建 Permission；有独立安全风险的状态动作必须拆分。

---

# 14. Threat Model

| 威胁 | 当前攻击面 | 目标防御 |
|---|---|---|
| Vertical Privilege Escalation | 任意分配角色、修改角色权限、无 level | Assignment-aware Grant Boundary + authorityLevel + self-grant deny |
| Horizontal Privilege Escalation | 有 Permission 即可按 ID 操作 | scoped SQL + ResourceAuthorizationGuard + 影响行数校验 |
| RoleAssignment Cross-Scope | Permission/Scope 全局合并 | `scopesFor(permission)` 只过滤合格 Assignment |
| Grant Cross-Scope | grantable 与 management 全局并集 | 每 Permission 寻找同 Assignment grant candidate |
| Role Modification Self-Escalation | 修改自己使用的 Role | Impact Analysis + operator boundary + affected revoke |
| Role Copy Bypass | 来源角色合法即复制 | Copy 等价全新 Create + 全部校验 |
| authorityLevel Escalation | 当前无等级 | newLevel < qualifying operator level；Root level 单独治理 |
| Organization Change Escalation | 移动节点静默扩大 descendants | Closure + organizationVersion + preview/audit/revoke |
| associatedDepartments Escalation | 组织关系可能被当 Scope | Membership 与 Scope 严格解耦 |
| RULES Scope Escape | 任意 target IDs/客户端自由规则 | 注册型 Rule schema + ScopeContains + active department + org version + no client trust |
| Token Theft | localStorage/Redis 明文/在线页泄漏 | secure storage/cookie、token digest、短 Access TTL、fingerprint only |
| Refresh Replay | 无 rotation | CAS rotation + used marker + family revoke + audit |
| Session Fixation | 同端复用旧 token | 登录总是新 Session/Token；成功认证后 rotation |
| Concurrent Login Race | check-then-create 非原子 | Lua SessionPolicy enforcement |
| Disable/Refresh Race | Refresh 使用旧快照 | subject version fence + status check + atomic rotate |
| Role Change/In-flight Write | 请求已通过 Filter | 高风险事务提交前 epoch recheck |
| Root Abuse | 角色特判散落、审计可丢 | RootPolicy 单点 + step-up hook + durable append-only audit |
| Audit Tampering | 普通软删除日志 | 独立 insert-only schema/table、DB privilege、归档完整性校验 |
| Audit Data Leakage | args/result 可能含敏感内容 | allowlist event schema + sanitizer + visibility projection |
| Brute Force / OTP Abuse | 非原子 code、标识明文 key | purpose-bound digest key、Lua consume、rate limit、generic response |
| CORS/CSRF | wildcard credentials | 精确 origin；Web refresh cookie 配合 SameSite/Origin/CSRF token |
| File IDOR | public preview whitelist | 移除全局白名单，签名短链或对象授权 |

---

# 15. Testing Strategy

## 15.1 Unit Tests

- Permission code validator、Role code validator、RootPolicy。
- authorityLevel：同级/上级拒绝、newLevel 边界、Root 保留级别。
- ScopeNormalizer / Union / Contains / Match，覆盖 NONE/ALL/SELF/RULES、显式集合、include-descendants、组织移动；验证缺失 Boundary 不等于 NONE、ALL 不能作为默认值。
- RoleAssignment Boundary：同 Permission 合法 UNION，不同 Permission 禁止借 Scope。
- GrantablePermission + permission-specific Grant Boundary 算法。
- Access Boundary 与 Grant Boundary 可独立配置，且只能在同 Permission 内做 contains；不存在全局 subset 约束。
- Account 状态和 User 生命周期转换矩阵。
- Role Change / Organization Change Impact Analyzer。
- Audit redaction allowlist。
- SessionPolicy 决策和 token fingerprint。
- TOTP RFC 时间窗口/重放防护、Enrollment 状态机、Recovery Code Hash 与并发单次消费、DEV_OPS required AAL。

强制构造：

```text
Assignment A: Permission A + Scope A
Assignment B: Permission B + Scope B

Assignment C:
  Permission A -> Access Scope A
  Permission B -> Access Scope B

Assignment D:
  Permission A -> Access Scope SELF
  Grantable Permission A -> Grant Scope Department X
```

断言跨 Assignment 和同一 Assignment 内，Permission A 都不能得到 Permission B 的 Scope。Assignment D 的 Access/Grant 可独立存在，但向下授予 Permission A 时只能使用 Department X Grant Boundary，不能借其他 Permission 的 Grant Scope。Access 和 Delegation 两套算法都必须测试。

## 15.2 Integration Tests

- PostgreSQL/Testcontainers：所有 FK、unique、CHECK、closure move、role/assignment transaction。
- Redis Testcontainers：create、rotation、parallel refresh replay、revoke、KICK_OLD、REJECT_NEW、maxSessions、TTL、index cleanup。
- Login：PASSWORD/SMS/EMAIL、锁定、禁用、离职、Client-method allowlist、TOTP Challenge pending、DEV_OPS 未满足 MFA 不签发 Root Session。
- Refresh：rotation、旧 token 立即失败、replay 撤销、被禁用用户不能 refresh、策略变化。
- Logout：Access-only、Refresh-only、Session revoke 后 Access 不可用。
- Password change/reset：全部设备失效。
- Role/Assignment/Scope/authority change：受影响 Session 全失效。
- Department move：影响 preview 与 session revoke。
- DB commit/Redis failure/进程崩溃补偿测试。

## 15.3 API / Security Tests

- 所有管理 API 的 Permission、authorityLevel、permission-specific Grant Boundary、self-grant、同级/上级矩阵。
- IDOR：详情、更新、删除、文件、导出、批量、工作流任务、AI conversation。
- Role Copy、Role 修改间接提权、Grantable 交叉组合、RULES Scope 越界。
- Root：全权限/全菜单/全范围，但每个高风险操作都有不可删除 Audit。
- Audit Visibility：SYSTEM_ADMIN 不可看到 Root 内部和范围外事件。
- 白名单、CORS、CSRF、错误码和敏感信息不回显。
- Web Refresh Cookie 的 HttpOnly/Secure、默认 Host-only、Strict 默认值、受控 None 配置、Path、CSRF header、精确 Origin/Referer 和 rotation `Set-Cookie` 契约；生产配置拒绝 wildcard Origin 和不安全组合。
- Redis/Session 不可用时受保护请求、Login/Refresh/revoke 均 fail-closed，并验证客户端对 503 不 refresh、不清会话。
- 高风险安全写在 Audit writer 不可用时回滚；普通 Business Log 故障不冒充 Security Audit 成功。
- `maxDevOpsUsers` 默认 3/可配置边界、2 normal + 1 break-glass 布局、并发创建/撤销，以及两个 Root 并发操作不能移除最后一个 effective DEV_OPS。
- MFA Challenge 状态机、AAL、step-up proof command binding、TOTP Provider、Recovery Code 单次消费/重放和未来 Factor Provider contract。
- Break-glass 登录/失败/恢复/轮换全部产生最高等级 Audit；Audit 不可用时操作 fail-closed。

## 15.4 Frontend / E2E

- Web：并发 401 只 refresh 一次；refresh 401 不死锁；队列全部 reject；403 不 refresh；revoke 清状态。
- App：刷新后的重试携带新 Access；不同平台 secure storage adapter；启动恢复失败清理。
- Menu/按钮：只有 Permission 时显示正确动作；隐藏按钮仍用直接 API 证明后端拒绝。
- Playwright 浏览器验收：登录、rotation、超时、密码修改、多 Session、踢出、角色变化、运维三级菜单、Security Audit。
- App 端补 Vitest；H5 与 MP-WEIXIN 至少各一套自动化/手工验收清单。

## 15.5 Architecture/Contract Tests

- 禁止业务代码直接比较 `ROLE_DEV_OPS`。
- 禁止新增 `DataScopeExecutor.withoutScope`、用户直接 Permission、Role inheritance。
- 所有受保护 Repository 必须登记 Scope Policy。
- 所有 Controller 高风险动作必须映射独立 Permission 和 Security Audit Event。
- Token/Password/Secret 不得出现在 DTO `toString`、日志和 Audit JSON。
- DDL 汇总、Flyway migration 与 Entity schema contract 一致。

---

# 16. Migration Strategy

1. 建立当前行为、数据盘点和攻击回归测试，先修复可独立封堵的 Critical 漏洞。
2. Codex 按当前项目规范设计完整目标 DDL；新空数据库直接执行 `V1__init_target_schema.sql`。保持 `baselineOnMigrate=false`，不为非空旧 schema 自动建立 baseline。
3. 对旧数据库做只读 export，导入隔离 staging；一次性 transform/validate 后写入由 V1 创建的干净目标 schema。转换程序不是运行时 compatibility layer，cutover 后删除。
4. Codex 扫描生成的 Permission Catalog 作为目标 seed；维护一次性 migration mapping，把旧大写 code 映射到新稳定 code。`*` 不迁移，DEV_OPS 由 RootPolicy 取代；未映射 code 阻断 cutover。
5. 每条 `sys_rel_user_role` 生成 RoleAssignment。旧 Role Scope 按明确映射转换为该 Assignment 的逐 Permission Boundary：capability-only Permission 写显式 NONE；旧全范围映射为显式 ALL、本人映射为 SELF、部门/自定义集合转换为经过校验的 RULES；不能生成 Assignment 全局 Scope，也不能默认 ALL。
6. 旧系统没有 Grant Boundary，不能根据 Access Boundary 自动推导。迁移时不自动创建 RoleGrantablePermission；经审核新增某个 GrantablePermission 时，必须同时逐 Permission 创建合法 Grant Boundary，否则 deny。
7. 用户级 Scope 无法机械等价迁移：必须列出拥有 user override 的账号，逐项选择映射到哪些 Permission Boundary 或移除 override；禁止向所有 Permission 广播。
8. 旧 Account 拆分为 AuthenticationIdentity/PasswordCredential，规范化 identifier 后先查重，冲突阻断 cutover；TOTP/Recovery Code 不伪造迁移，DEV_OPS 首次进入受限 enrollment flow 完成 MFA 后才能建立普通 Root Session。
9. `sys_user.department_id` 迁为 primary Membership；关联部门初始为空。
10. Closure Table 从现有 Department tree 构建，检测 cycle、孤儿、重复 code；异常先修数据。
11. 在隔离迁移环境做新旧授权差异计算；任何“新模型更宽”必须显式确认，差异工具不得进入生产请求链。
12. 校验至少存在一个 effective DEV_OPS，默认最多 3；目标布局为 2 normal + 1 break-glass。导入超出配置上限或无法建立最后 Root 保护时阻断 cutover。
13. 切换窗口强制全局 logout，启用 `sec:v2:*` namespace，不迁移旧 Redis Token/Session。
14. 前后端同一发布窗口切换 v2 auth/refresh/cookie/CSRF/MFA contract；不保留长期兼容 adapter。
15. 验证与回滚观察期内旧库仅作为离线只读备份；新运行时不读取旧表。cutover 验收后删除旧表、旧 Resolver、旧 Redis key listener、旧 API 和 temporary mapping code。

Rollback 原则：V1 目标库和旧库分离，失败时保持全局下线并按受控 cutover Runbook 切回只读备份/旧应用；不恢复已撤销 Session，也不把已标记 replay/revoked 的旧 token 重新启用。Flyway 不使用 baselineOnMigrate 绕过版本校验。

---

# 17. Phased Implementation Plan

## Phase 0 — Security Baseline and Immediate Containment

- 目标：建立攻击回归基线，先封堵与目标架构无冲突的现有 Critical 风险。
- 模块：security starter/base、core auth、framework CORS、Web/App 请求层、测试。
- 预计文件：`AuthServiceImpl.java`、`AccountServiceImpl.java`、`SecurityProperties.java`、`MvcConfiguration.java`、`RedisSecHolderStrategy.java`、`spectra-ui/src/plugin/request/*`、`spectra-app/src/services/http.ts` 及对应测试。
- 修改：验证码绑定校验与原子消费、精确 CORS/白名单、文件预览授权、在线用户去 Token、固定 Access Token TTL（移除普通请求续期）、Refresh Token 一次性 Rotation/Replay 撤销并重新加载当前身份源、logout 全量撤销和前后端开发默认凭据清理。
- 新增：Token/Refresh/disable/password change/DataScope cross-assignment characterization tests；前端 refresh queue tests。
- DB/Redis：不引入目标 schema；只允许兼容性最小 Redis 修复。
- API/前端：错误码可补齐；不先重做全部页面。
- 风险：修复现行 refresh 可能影响已登录用户；测试环境应先全量退出。
- 依赖：无。
- 当前进度（2026-08-14）：已完成登录/绑定验证码按用途隔离、绑定验证码发送入口与 Redis Lua 一次性原子消费、精确 Origin allowlist、Actuator/file preview 白名单收敛、在线用户和过期日志去 Token、普通请求不再滑动 Access TTL、Refresh Token 一次性 Rotation/Replay 用户级撤销并从当前数据库身份源重建主体、logout 清理 Access Session、密码修改/管理员重置/用户角色替换后的 Session 撤销、Redis 会话异常 fail-closed（503）、Web Refresh 请求隔离和 App 刷新后携带新 Access Token；后端验证码/Rotation/CORS/白名单回归、Web Refresh single-flight 回归及 Web 格式/lint/type/test 已通过。
- 未完成门禁：账号/角色/范围变化的统一 revoke、App Refresh single-flight 自动化回归、Redis 故障注入与完整 Phase 0 安全矩阵。当前 Rotation 仍基于旧 Redis Key 形态，Token Family、服务端 Session 聚合和 Cookie/CSRF 将在后续 Phase 5 重构。
- DoD：Critical 漏洞有失败测试再修复；CORS/白名单审计通过；无 Token 回显；现行安全测试绿。只有上述未完成门禁全部通过后，Phase 0 才可标记完成。

## Phase 1 — Complete V1 Schema, Audit Spine, Root Governance

- 目标：由 Codex 按现有规范锁定完整目标 schema，以 Flyway V1 建立新环境，并交付 append-only Security Audit、SecurityChangeOutbox 和统一 RootPolicy。
- 模块：spectra-config/core/security、security starter、docs/sql。
- 预计文件：根/模块 `pom.xml`、`spectra-config` migration 配置、Proposed `core/security/audit/*`、`core/security/change/*`、`RootAuthorizationPolicy.java`、`AuditLogSanitizer.java`、`docs/sql/*`。
- 已实现骨架（2026-08-14）：security-base 已加入 `SecurityAuditEvent`/`SecurityAuditWriter`/`AuditVisibilityPolicy`、`SecurityAuditSnapshotSanitizer`、`RootPolicy`/`RootPolicyRepository`/`LastEffectiveDevOpsGuard`/`RootAuthorizationPolicy`、`SecurityChangeExecutor`；core 已加入 JDBC Audit append writer、Root policy repository、最后 Root guard 和同事务 STARTED/RESULT 审计执行器；starter 已注册统一 Root 判定 Bean；`docs/sql/spectra_security/建表.sql` 已形成 permission-specific boundary、Root singleton、append-only Audit、Outbox 的目标 DDL 契约。
- 删除/废弃：新增代码不得使用散落 `hasRole('ROLE_DEV_OPS')`；旧点位记录迁移清单。
- DB：`V1__init_target_schema.sql` 一次性建立第 6 节全部目标表、约束和索引，`V2__security_runtime_privileges.sql` 建立运行时/迁移角色边界与 Audit 最小权限，`V3__security_permission_catalog_seed.sql` 写入 102 个目标 Permission；`V4__complete_schema_comments_and_ai_tables.sql` 补齐跨模块结构注释并创建 `spectra_ai` 的会话/记忆表，`V5__remove_legacy_core_ai_session.sql` 删除 Core 遗留 `ai_session`，`V6__seed_core_reference_data.sql` 写入 Core 必要参考种子；`baselineOnMigrate=false`，不建立旧 schema baseline。
- Redis：仅定义 Port，尚不切 v2。
- API/前端：可暂不开放 Audit UI；当前已提供审计写入与高风险事务端口，现有 Root/角色/账号写入口尚未全部接入，接入完成前不得宣称 Phase 1 完成。
- 测试：空库从 V1 可完整启动、非空无历史库拒绝自动 baseline、audit insert-only、Audit unavailable fail-closed、Root bypass 但 audit 不 bypass、默认 max=3/可配置、多 Root 并发与最后有效 DEV_OPS 保护、事务失败回滚。
- 风险：审计 fail-closed 影响可用性，需要监控/告警。
- 依赖：Phase 0。
- 当前状态：append-only Audit/Root 治理骨架、全量业务 schema 的目标 Flyway V1、V2 运行时权限边界、V3 Permission seed、V4/V5 结构注释与 AI 表清理、V6 Core 参考种子、Flyway 配置、静态 schema 契约和 Break-glass Runbook 草案已交付；开发数据库已真实启动验证 V1-V6，Flyway 历史为连续成功的 6 个版本，`sys_region` 仍由独立大批量数据流程保留。已加入默认禁用、需显式环境变量开启的真实 PostgreSQL/Flyway 集成测试（覆盖空库 V1-V3、Permission 数量和非空库拒绝自动 baseline），但尚未在 CI/部署环境实际执行。现有写入口接入、并发边界自动化测试，以及 Runbook 的运维评审/演练仍未完成。V1 明确移除旧 sys_account/sys_role/sys_authority/data_scope 表，并按无 Tenant 目标移除通知表 tenant_id，运行时切换需在后续 Phase 完成。
- DoD：新环境只需从 V1 初始化完整目标 schema；任何新安全变更必须使用 Change skeleton；应用账号不能更新/删除 Audit；默认支持 2 normal + 1 break-glass 且任何管理变更不能移除最后一个 effective DEV_OPS；独立 break-glass Runbook 完成评审。

## Phase 2 — Identity Lifecycle and Organization Membership

- 目标：User 状态、认证标识、密码凭证、主/关联部门模型到位。
- 模块：core.identity、core.organization、现有 user/auth/system package。
- 预计文件：`User.java`、`Account.java`、`UserServiceImpl.java`、`AccountServiceImpl.java`、`UserController.java`、`DepartmentServiceImpl.java`、Proposed `core/identity/*` 与 migration。
- 新增：UserLifecycleService、AuthenticationIdentity、PasswordCredential、DepartmentMembership、Closure/OrganizationVersion。
- 废弃：Account 空字段聚合、单 `department_id` 安全含义、普通 User Delete。
- DB：identity/credential/membership/closure 表及约束。
- Redis：锁定 key 规范化；User 状态变化先走 legacy revoke adapter。
- API/前端：拆分 disable/enable/depart/reinstate/unlock/reset；用户组织 UI 支持多关系。
- 测试：状态机、绑定所有权、部门 cycle/move、关联部门不扩权。
- 风险：旧 Account 数据规范化冲突。
- 依赖：Phase 1 Audit/Change skeleton。
- 当前进度（2026-08-14）：`UserStatus` 已切换为目标字符串状态模型（`ACTIVE/LOCKED/DISABLED/DEPARTED`），并提供登录允许、显式重新入职和非法状态转换契约测试；User Entity/请求/响应模型已同步该类型。用户生命周期已通过独立 lock/unlock/disable/enable/depart/reinstate 写入口统一执行状态机、Audit、securityVersion 递增和 Session revoke。密码因子已切换到目标 `authentication_identity + password_credential` 表，用户创建/改密/重置密码、用户名密码登录和通知收件人已不再依赖 `sys_account`；短信/邮箱因子与正式 RoleAssignment 历史撤销记录仍待完成。
- DoD：所有生命周期变化有 Audit + revoke；DEPARTED 不恢复旧授权。

## Phase 3 — Permission, Role, RoleAssignment and Scope Domain

- 目标：建立目标授权数据模型和 Assignment-preserving AuthorizationSnapshot。
- 模块：core.authorization、security-base contracts、core navigation。
- 预计文件：`SecurityUser.java`、`SecurityUserHelper.java`、`Role.java`、`Authority.java`、`RelUserRole.java`、`DataScopeResolver.java`、Proposed `core/authorization/*` 与 migration。
- 新增：Codex 扫描生成的 PermissionCatalog、Role、RoleAssignment、AssignmentPermissionBoundary、AssignmentGrantBoundary、NONE/ALL/SELF/RULES Scope algebra、AuthorizationSnapshotLoader。
- 废弃：随机 Role code、用户直接 Scope、全局 EffectiveScope。
- DB：使用 V1 已建立的 permission/role/relations/assignment/scope tables；如实现发现目标设计缺陷，只追加 versioned migration，不改写已发布 V1。
- Redis：授权 Snapshot cache key/version，可先不切 Session v2。
- API/前端：Role/Assignment v2 read API；旧写 API冻结。
- 测试：强制 cross-assignment invariant、scope contains/union、Root all。
- 风险：旧 Role Scope 迁移歧义。
- 依赖：Phase 2 Membership/OrganizationVersion。
- 当前进度（2026-08-14）：security-base 已建立 `ScopeMode`、`AuthorizationScope`、`PermissionBoundary`、`AuthorizationAssignment` 和 assignment-preserving `AuthorizationSnapshot`；core 已接入目标 security schema 的 `JdbcAuthorizationSnapshotLoader`，按 active RoleAssignment 加载 Role capability、GrantablePermission、permission-specific Access/Grant Boundary 和 ScopeRule，并对缺失/停用/不一致引用 fail-closed。已提供 `/security/authorization/users/{userId}/assignments` v2 只读查询，保留 Assignment 内 Access/Grant Boundary 绑定。单元测试覆盖同 Permission Scope union、跨 Permission Scope 隔离、Access/Grant Boundary 分离、组织子树规则、数据库加载器和只读查询映射。RoleAssignment 写入、正式授权上下文接入、旧 Role/Authority 运行时切换仍待完成。
- 当前准备工作（2026-08-14）：已根据全仓 Controller `@PreAuthorize` 扫描生成 `docs/security/permission-catalog.yaml`，覆盖 89 个旧 Permission code 的一次性 mapping 和 102 个目标 code 候选；其中 `user:disable`、`user:reset-password`、`role:authority-level:update`、Session/Audit/Security Policy/Root 等高风险能力已与普通 CRUD 拆开，旧 `*` 明确拒绝迁移。该初稿已在 Phase 7 完成业务动作复核，升级为 version 2 并扩展至 115 个目标 Permission，同时由 V8 migration 负责增量 seed。
- DoD：目标模型可完整计算权限但尚可 shadow；任何 Snapshot 保留 Assignment 边界。

## Phase 4 — Delegation, Authority Level and Impact Analysis

- 目标：所有增权动作统一进入 Grant Boundary 和 Impact Analysis。
- 模块：core.authorization/delegation、security.change、role/user/department API。
- 预计文件：`RoleServiceImpl.java`、`RelUserRoleServiceImpl.java`、`RelRoleAuthorityServiceImpl.java`、`RoleController.java`、`UserController.java`、`DepartmentController.java`、Proposed Impact/Boundary/Change 组件。
- 新增：GrantBoundaryService、RoleChangeImpactAnalyzer、OrganizationImpactAnalyzer、Preview/Apply token、AuthorizationEpochGuard、HighRiskApprovalGate 扩展点（首版不实现双人审批）。
- 删除/废弃：Controller/Service 内直接 grant、角色复制捷径、Role level 特判。
- DB：authorityLevel、impact metadata/version；无需独立长期 preview 表时可使用短期签名 token。
- Redis：legacy user revoke adapter + change fence prototype。
- API/前端：Role permissions/grantables/level、Assignment、Department move 使用 preview/apply UI。
- 测试：同级/上级、自授权、组合授权、并发版本变化、Root governance。
- 风险：大 Role 影响分析性能。
- 依赖：Phase 3。
- DoD：不存在绕过统一 GrantBoundary 的增权写入口；受影响用户全部下线。

## Phase 5 — SecuritySession, Token Rotation, Client and Policy

- 目标：切换到 v2 Redis SecuritySession、完整多端 Token 生命周期和首版可用 TOTP MFA。
- 模块：security starter Redis adapter、core.security.authentication/session/policy、Web/App auth client。
- 预计文件：`RedisSecHolderStrategy.java`、`AuthRedisKey.java`、`TokenAuthenticationFilter.java`、`AuthController.java`、`SecurityConfiguration.java`、`spectra-ui/src/plugin/request/*`、`spectra-app/src/services/http.ts`、Proposed Redis session/Lua 组件。
- 新增：SecuritySessionService、TokenDigest、Lua scripts、Client/AuthMethod/SessionPolicy、完整 Challenge/AAL/step-up pipeline、TOTP Factor Provider、MFA Enrollment、单次 Recovery Code；WebAuthn/Passkey 保留 Provider 扩展，首版不实现 OPEN_API Service Principal。
- 删除：RedisSecHolderStrategy 旧映射、SecurityUser Redis 快照、同端复用、TTL 滑动、Key expiration listener 旧职责。
- DB：使用 V1 已建立的 client/method/policy/mfa_enrollment/totp_credential/recovery_code 表。
- Redis：启用 `sec:v2:*`；全局 logout cutover。
- API/前端：login/refresh/logout/session v2；Web 默认 Host-only + Strict 的 HttpOnly/Secure Cookie、CSRF/App secure storage；TOTP enrollment/challenge/recovery UI；真实 Session 页面。
- 测试：rotation/replay/race/policy/revoke、Redis fail-closed、Host-only/Strict/受控 None Cookie 与 CSRF、Challenge/AAL/step-up、TOTP 时间窗口/重放、Recovery Code 单次消费、DEV_OPS 强制 MFA。
- 风险：前后端必须原子发布；并行 refresh 会触发 replay。
- 依赖：Phase 1 Audit、Phase 3 Snapshot、Phase 4 Change fence。
- DoD：旧 Token 全失效；Refresh 单次使用；Redis 不可用绝不降级放行；密码/状态/授权变化立即挡住新请求；高风险写提交前 epoch recheck；TOTP 可用于登录和 step-up，Recovery Code 单次使用且只存 Hash，DEV_OPS 无 MFA 不得获得普通 Root Session。

## Phase 6 — Permission-Aware DataScope Enforcement

- 目标：SELECT/UPDATE/DELETE/BATCH/EXPORT 和 IDOR 全面迁移到 permission-specific Access/Grant Boundary。
- 模块：framework MyBatis、core authorization、OA/workflow/upload/AI/notification 各 repository/service。
- 预计文件：`DataScopeInnerInterceptor.java`、`DataScopeEntityRegistry.java`、`DataScopeExecutor.java`、全部 `@DataScope` Entity、相关 Mapper/Service/Controller、Proposed `framework/.../mybatis/security/*`。
- 新增：ScopedAuthorization、ExecutionContext、ScopeSqlPolicy、ResourceAuthorizationGuard、Architecture tests。
- 删除：旧 DataScopeResolver、user/role scope table、`withoutScope`、无理由 `ignore=true`。
- DB：为受保护资源补 owner/department/关联查询索引，必要时修正归属字段。
- Redis：只读取 AuthorizationSnapshot，不新增 Token 语义。
- API/前端：导出和高风险动作拆 Permission；Scope 不从客户端信任。
- 测试：每个资源至少 list/detail/update/delete/export/batch 越权矩阵。
- 风险：复杂 JOIN/Flowable/native query 遗漏；以 fail-closed registry 和 contract test 控制。
- 依赖：Phase 3-5。
- DoD：所有外部数据路径登记策略；cross-assignment 攻击在集成层失败。

## Phase 7 — Permission Catalog, Menu and Frontend Authorization UX

- 目标：固化 Codex 全仓扫描生成的业务 Permission Catalog，完成旧 code 一次性 migration mapping，并使 Menu/按钮/Route 与新 Context 协调。
- 模块：所有 Controller、permission seed、spectra-ui、spectra-app。
- 预计文件：所有含 `@PreAuthorize` 的 Controller、`MenuServiceImpl.java`、`spectra-ui/src/views/System/RBAC/*`、`System/User/*`、router/store/directive、App 登录与认证 Store/API。
- 新增：catalog version、current security context API、RoleAssignment Permission/Grant Boundary UI、运维安全中心三级菜单。
- 删除：旧大写 CRUD code、前端 fabricated role permission、`Token.roles` 错误类型、开发默认凭据。
- DB：catalog/role mapping/menu seed 更新。
- Redis：Snapshot cache 失效。
- API/前端：全部 v2 Permission；DEV_OPS 默认全部菜单，SYSTEM_ADMIN 仅被授予业务菜单。
- 测试：Controller-permission contract、menu/button UX、direct API 后端拒绝。
- 风险：业务动作粒度需要产品确认。
- 依赖：Phase 6 资源策略稳定。
- DoD：Catalog 覆盖全部受保护 Controller/业务高风险动作/数据资源；旧 Permission code 和 evaluator 无运行时引用并在一次性 mapping 验收后删除；Menu != Permission 的测试成立。

## Phase 8 — Audit Visibility and Security Operations Center

- 目标：完整 Security Audit 查询、脱敏、可见性、归档和运维界面。
- 模块：core.security.audit、spectra-ui ops/security、observability。
- 预计文件：Proposed `SecurityAuditQueryService.java`、`AuditVisibilityPolicy.java`、Audit Controller/Mapper/VO、`spectra-ui/src/views/Ops/Security/*`、相应 API/types/tests。
- 新增：AuditVisibilityPolicy implementation、export、12 个月热存/至少 5 年总保留策略、未来归档编排与 manifest、告警指标、Root/break-glass high-risk view。
- 删除：安全查询对 `sys_log` 的依赖。
- DB：按 12 个月热存设计分区、只读 projection/index、至少 5 年保留元数据和未来归档 manifest；应用层不提供 UPDATE/DELETE 能力。
- Redis：无安全事实，仅可做查询缓存且短 TTL/按 viewer key。
- API/前端：audit list/detail/export、策略变更记录、Session operations。
- 测试：Root/SYSTEM_ADMIN/普通用户可见性矩阵、敏感字段扫描、热存边界、归档失败不卸载分区、归档/校验/恢复操作自身 Audit。
- 风险：JSONB before/after 可能泄密或体积膨胀。
- 依赖：Phase 1 审计 spine、Phase 7 权限 catalog。
- DoD：Prompt 事件清单均有生产者；Root 自身事件可查不可删；默认热存 12 个月、总保留至少 5 年，归档行为具有完整最高等级审计链。
- 当前进度（2026-08-14）：已交付 `DefaultAuditVisibilityPolicy`，统一 Root/break-glass、SYSTEM_ADMIN 和普通主体的审计可见性矩阵；新增 `/security/audit/page`、详情、CSV 导出和保留策略只读 API，查询侧对 JSONB 快照执行二次脱敏并限制分页/导出上限。V9 已登记热存/总保留策略、归档 manifest、完整性摘要和 runtime 只读权限，Web 已接入安全审计列表、详情、筛选、导出与策略卡片；本轮补齐登录/登出/刷新、TOTP/Recovery Code、用户创建/生命周期/密码变更、Role/Assignment/组织 Preview/Apply，以及归档 started/completed/failed/verified 的事件生产者和结果语义。策略变更生产者、部署相关归档后端选择和真实 PostgreSQL 分区/恢复演练仍需 Phase 8 门禁继续完成。

## Phase 9 — Cutover, Legacy Removal and Hardening

- 阶段补充（2026-08-15）：`DataScopeInnerInterceptor` 已切换为只读取 Permission-specific `AuthorizationSnapshot`，旧 `DataScopeProvider`/`DataScopeResolver` 全局范围解析端口已删除，通知收件人目录已按 `user:read` Boundary 执行组织影响检查；本阶段框架/核心定向测试、后端全量回归与数据库安全契约核对均已通过。旧 Account/Role/Authority/DataScope 模型、Controller、Mapper 和其他模块旧调用，旧 Redis/表清理及最终端到端验收仍待完成。
- 阶段补充（2026-08-15）：用户/角色创建和编辑接口已移除旧 DataScope 参数及旧 `sys_role.scope` 映射，User/Role service 不再读取或写入旧范围表，`SecurityUser` 不再携带全局 DataScope；Web 用户/角色表单、列表和转换器已同步删除旧范围字段。旧范围实体、Mapper、DTO、枚举及 DDL 尚待独立清理，历史 user-level Scope 不自动映射到新 Permission Boundary。
- 阶段补充（2026-08-15）：旧 DataScope 实体、Mapper/XML、DTO 和枚举已删除；`V10__remove_legacy_data_scope.sql` 以不带 `CASCADE` 的幂等 DDL 下线四张旧 Scope 表并删除 `sys_role.scope`，schema 文档和实体字典已同步。迁移不自动转换历史 user/role Scope，需在显式 Assignment Boundary 变更中人工消歧。
- 阶段补充（2026-08-15）：角色目录 CRUD 已切换到 `spectra_security.role`，补齐稳定 `ROLE_*` 编码、`authorityLevel`、`roleKind` 和 `systemManaged` 映射；角色菜单授权读写及当前菜单树已切换到 `spectra_security.role_menu` + `AuthorizationSnapshot`，不再从旧 `sys_rel_role_menu` 或 `sys_user_role` 回退读取。本批角色目录、菜单关系、菜单树和 V1–V10 数据库契约测试均已通过并独立提交；旧 Permission/Authority 目录、用户 RoleAssignment 写入口及旧角色模型清理已在后续阶段完成。
- 阶段补充（2026-08-15）：`/authority/tree` 已切换为只读 Permission Catalog 适配器，从 `spectra_security.permission` 按资源分组返回活动权限；旧 Authority CRUD 路由已移除。角色权限查询和撤销清理已切换到目标 `role_permission`/`role_grantable_permission`，旧角色权限写入口已删除，Permission Preview/Apply 前端已接入。
- 阶段补充（2026-08-15）：AuthorizationController 新增目标 Role 当前授权状态查询，返回 role version、authorityLevel、Permission code 与 GrantablePermission code；spectra-ui RBAC 已移除旧角色权限覆盖写 API，改为分别编辑 Role capability 与 Grantable capability，提交前执行 Impact Preview，确认后携带短时 token Apply，菜单仍作为独立 UX 配置保存。
- 阶段补充（2026-08-15）：用户资料保存已移除 `role_ids`，`UserController` 删除旧 `/user/{uid}/roles` 覆盖写路由；用户资料与 RoleAssignment 写入彻底解耦，Assignment 必须通过 AuthorizationController 的 Preview/Apply 逐条提交 Boundary。Web RoleAssignment 编辑器已完成接入。
- 阶段补充（2026-08-15）：用户分页资料与当前用户资料的角色展示已切换到活动 `spectra_security.role_assignment`；只读 Assignment 查询补充 Role/Assignment version、Role 名称、系统托管标记及分离的 Access/Grant Boundary。旧 `sys_rel_user_role` 已不再作为运行时来源，并由 V11 迁移下线。
- 阶段补充（2026-08-15）：Permission Catalog 叶子节点已返回 `allowed_scope_modes`；Web 用户编辑器已接入 RoleAssignment 新增/修改，明确编辑 Permission-specific Access/Grant Boundary，RULES 必须选择组织，保存前执行 Assignment Preview 并携带短时 token Apply。数据库安全契约、后端目录测试与 Web format/lint/type/test 均已通过。
- 阶段补充（2026-08-15）：旧 `Authority`/`Role`/`RelUserRole`/`RelRoleAuthority` 运行时实体、Mapper、Service、监听器和旧 `RoleController` 权限路由已删除；User 生命周期回收改为将活动 RoleAssignment 标记为 `REVOKED` 并保留 version/validUntil。V11 以无 `CASCADE` 幂等 DDL 下线旧授权表。
- 阶段补充（2026-08-15）：绑定/解绑已切换到 `authentication_identity` 目标表，新增 `AuthenticationIdentityController` 与 `/security/identities/**`；旧 Account 实体、Mapper、Service、Controller、XML 和 `sys_account` 已删除，V12 以无 `CASCADE` 幂等 DDL 下线旧表。目标身份只返回 method/provider/state/verifiedAt 元数据，不返回原始标识；Redis 旧键核对和真实数据库验收仍待后续。

- 目标：删除新旧双体系，完成真实数据库和浏览器/多端验收。
- 模块：全仓库、SQL、docs、CI。
- 预计文件：第 18 节全部 REMOVE/MIGRATE 文件、V1 后必要的增量 Flyway migration、一次性旧数据 mapping 工具、`docs/sql/*`、API/实体清单文档、CI/Playwright/App 验收配置。
- 删除：旧表、旧 API、旧 Redis keys、SecUtil 业务用法、旧 Authority/DataScope/Account 类。
- DB：最终迁移、constraint validation、真实数据库只读核对、备份/回滚演练。
- Redis：确认 `auth:*` 无活跃会话后清理；保留 v2。
- API/前端：移除 compatibility adapter/mock online page；生产请求链不读取旧表或旧 Permission/Scope 模型。
- 测试：全量后端/Web/App、DAST、Playwright、多端手工、性能/故障注入。
- 风险：残留调用链和隐蔽 native SQL。
- 依赖：前述全部 Phase。
- DoD：REMOVE 清单为零引用；全局 logout 后新模型唯一生效；文档/DDL/API/实体一致。
- 当前进度（2026-08-15）：已开始切断旧认证运行时：短信/邮箱登录和绑定/解绑改读写 `authentication_identity` 与 `password_credential`，`SecurityUserHelper` 已删除旧 Account/DataScope 构造路径；新增 `SecurityContextAccessor`、`SecuritySessionQueryPort`、`SecuritySessionRevocationPort`、`SecurityAuthenticationPort`、`SecurityUserLookupPort` 窄端口并由 security starter 提供 Redis 适配，core、notification、AI、workflow、framework 与 log 业务/框架层已清零 `SecUtil` 静态调用，OA 申请/日程/会议/公告、资产/合同/文档/请假/采购/报销/物资/工作台也已迁移至窄端口，认证控制器、Token 过滤器和 AI token 工具已完成适配，同时删除 core 内旧会话撤销适配器。旧 Account/Role/Authority/DataScope 运行时实体、Controller、Mapper 和其他模块旧调用已清理，V11/V12 旧表迁移已补齐；Redis 旧键核对及多端/浏览器/真实数据库验收尚未完成；本批后端全量回归与数据库安全契约核对已通过。

---

# 18. File-level Change Plan

## 18.1 Existing Files

| 文件/目录 | 当前职责 | 计划 |
|---|---|---|
| `spectra-security-base/.../javabean/entity/SecurityUser.java` | 用户、权限、单 Scope 快照 | REPLACE 为最小 `AuthenticatedPrincipal` + Assignment-preserving context；不再 Redis 序列化完整用户 |
| `spectra-security-base/.../holder/SecUtil.java` | 全局认证/Token/踢人工具 | REPLACE 为窄 Port；业务代码移除静态调用 |
| `spectra-security-base/.../holder/SecHolderStrategy.java` | Token/在线用户大接口 | SPLIT 为 SessionReader、SessionIssuer、SessionRevoker、ContextAccessor |
| `spectra-security-base/.../constant/AuthRedisKey.java` | 旧明文 Token Key | REMOVE after v2 cutover |
| `spectra-security-base/.../constant/ClientType.java` | WEB/APP/MINI enum | REPLACE 为数据库 SecurityClient code/value object |
| `.../strategy/provider/*AuthenticationProvider.java` | Spring Authentication provider | KEEP adapter pattern；移除验证码消费和 Session 创建业务 |
| `.../properties/SecurityProperties.java` | 白名单/TTL/root/验证码配置 | SPLIT；Session Policy 迁 DB，bootstrap secret/白名单保留 typed config |
| `.../configuration/SecurityConfiguration.java` | FilterChain | MODIFY 精确 public endpoints、CORS/CSRF/header、注入 Filter Bean |
| `.../filter/TokenAuthenticationFilter.java` | Redis 用户快照认证和续期 | REPLACE：验证 SecuritySession/版本，绝不计算业务 Scope/续 TTL |
| `.../eval/SpectraPermissionEvaluator.java` | wildcard + root permission | REPLACE 为 AuthorizationService adapter；删除 `*` 和散落 Root 判断 |
| `.../strategy/RedisSecHolderStrategy.java` | 旧 Token/Refresh/在线模型 | REMOVE after v2；由 RedisSecuritySessionRepository/Lua scripts 替代 |
| `.../web/controller/AuthController.java` | 登录/刷新/登出/验证码 | MOVE 到 `core.security.authentication.web` 并改为 application orchestration |
| `.../web/service/impl/AuthServiceImpl.java` | 验证码发送 | MIGRATE 到 purpose-bound VerificationChallengeService |
| `core/auth/service/impl/SecurityUserHelper.java` | 加载全部权限和单 Scope | REPLACE 为 IdentityStatusLoader + AuthorizationSnapshotLoader |
| `core/auth/service/impl/AccountServiceImpl.java` | 旧账号绑定 | [x] REMOVE（2026-08-15）；AuthenticationIdentityBindingService 替代 |
| `core/auth/javabean/entity/Account.java` | 旧多认证字段聚合 | [x] REMOVE（2026-08-15）；AuthenticationIdentity/PasswordCredential 替代 |
| `core/user/javabean/entity/User.java` | 用户与单部门/二状态 | MODIFY lifecycle/securityVersion；成员关系拆表 |
| `core/user/javabean/entity/Role.java` | 旧角色模型 | [x] REMOVE（2026-08-15）；目标角色使用 `SecurityRole` |
| `core/user/javabean/entity/Authority.java` | 旧权限树 | [x] REMOVE（2026-08-15）；目标权限使用 `Permission` Catalog |
| `core/user/javabean/entity/RelUserRole.java` | 旧用户角色 M:N | [x] REMOVE（2026-08-15）；使用 `RoleAssignment` |
| `core/user/javabean/entity/UserDataScope*.java` | 用户直接 Scope | REMOVE |
| `core/user/javabean/entity/RoleDataScope*.java` | 角色 Scope | REMOVE after Assignment migration |
| `core/user/service/impl/DataScopeResolver.java` | 全局 Scope 合并 | [x] REMOVE（2026-08-15）；Permission-specific AuthorizationSnapshot 替代 |
| `core/user/service/impl/UserServiceImpl.java` | 资料/状态/角色/范围/密码混合 | SPLIT 到 Profile、Lifecycle、Credential、Assignment Application Services |
| `core/user/service/impl/RoleServiceImpl.java` | Role CRUD | REPLACE 为 RoleCommandService + Impact/Boundary orchestration |
| `RelUserRoleServiceImpl.java` | 旧直接 grant | [x] REMOVE（2026-08-15）；RoleAssignment Application Service 替代 |
| `RelRoleAuthorityServiceImpl.java` | 旧权限树关系更新 | [x] REMOVE（2026-08-15）；RolePermissionCommandService 替代 |
| `RelRoleMenuServiceImpl.java` | 菜单关系 | KEEP/MODIFY，明确只负责 UX |
| `core/user/controller/UserController.java` | 宽泛用户 API/online | SPLIT，删除普通 delete 和 mock-like online contract |
| `core/user/controller/RoleController.java` | Role/权限/菜单混合 | [x] 已移除旧权限路由；保留 Role CRUD 与菜单 UX 配置 |
| `core/user/controller/AuthorityController.java` | Permission CRUD/tree | REPLACE 为只读 PermissionCatalogController；Root catalog 治理另设 |
| `core/system/service/impl/DepartmentServiceImpl.java` | 邻接树 CRUD | REPLACE move/closure/impact transactional service |
| `core/system/service/impl/MenuServiceImpl.java` | 当前角色菜单 | MODIFY：Root 全菜单、其他 Role menu union |
| `framework/.../DataScopeInnerInterceptor.java` | 单全局 Scope SQL 拼接 | REPLACE 为 permission-aware ScopeSqlInterceptor |
| `framework/.../DataScopeEntityRegistry.java` | Entity 注解注册 | MIGRATE 为 fail-closed ResourceScopePolicyRegistry |
| `framework/.../DataScopeExecutor.java` | 全局跳过 Scope | REMOVE |
| `framework/.../MvcConfiguration.java` | CORS | MODIFY 为环境精确 allowlist；禁止 wildcard+credentials |
| `log-base/.../AuditLogSanitizer.java` | 日志脱敏 | KEEP/EXTEND；Security Audit 使用 allowlist schema |
| `log-base/.../ULogAspect.java` | 普通操作日志 | KEEP 作为 Business Log；不用于强制 Security Audit |
| `core/common/listener/ulog/ULogListener.java` | 异步写 sys_log | KEEP business log |
| `docs/sql/spectra_core/建表.sql` | 汇总 DDL | MIGRATE 为 Flyway 结果汇总并修复漂移 |
| `docs/sql/db.dump` | 数据库快照 | KEEP 为 snapshot/fixture，取消迁移事实源地位 |
| `spectra-ui/src/plugin/request/auth.ts` | Web refresh queue | REPLACE 为独立 refresh transport + single-flight Promise |
| `spectra-ui/src/plugin/store/modules/use-user-store.ts` | localStorage Token/权限 | REPLACE 为内存 Access + server context；Refresh 不进 JS |
| `spectra-ui/src/plugin/directives/owner.ts` | 按角色/权限隐藏 DOM | MODIFY 为纯 Permission UX，修复类型 |
| `spectra-ui/src/views/System/RBAC/index.vue` | Role/权限/菜单树 | REPLACE 为 capability/grantable/level/impact 及逐 Permission Boundary UI |
| `spectra-ui/src/views/System/User/components/UserEdit/index.vue` | roles + user scope | REPLACE 为 Profile；Assignment 使用独立 UI |
| `spectra-ui/src/views/Monitor/Online/index.vue` | mock 在线用户 | REPLACE 为真实 SecuritySession UI |
| `spectra-app/src/services/http.ts` | App refresh/401 | REPLACE single-flight 和 secure token adapter |
| `spectra-app/src/helper/bootstrap/user.ts` | 启动 refresh | MODIFY，按 Client/Device 恢复 Session |
| `spectra-app/src/interceptor/route.ts` | Token 存在性守卫 | MODIFY 为 store/session 状态 UX；不写 JWT 解析假设 |
| `spectra-app/src/platform/device/*` | 固定占位 Device ID | REPLACE 为 installation identity adapter |

## 18.2 Proposed Backend Files

以下路径尚不存在，均为 Proposed：

```text
spectra-core/src/main/java/com/devops00/spectra/core/identity/
  domain/UserLifecycle.java
  domain/AuthenticationIdentity.java
  domain/DepartmentMembership.java
  application/UserLifecycleService.java
  application/CredentialService.java

spectra-core/src/main/java/com/devops00/spectra/core/authorization/
  domain/Role.java
  domain/Permission.java
  domain/RoleAssignment.java
  domain/AssignmentGrant.java
  domain/AssignmentPermissionBoundary.java
  domain/AssignmentGrantBoundary.java
  domain/AuthorizationScope.java
  domain/ScopeMode.java
  domain/ScopeRule.java
  application/AuthorizationService.java
  application/PermissionScopeResolver.java
  application/GrantBoundaryService.java
  application/RoleChangeImpactAnalyzer.java
  application/OrganizationImpactAnalyzer.java
  application/AuthorizationSnapshotLoader.java

spectra-core/src/main/java/com/devops00/spectra/core/security/change/
  DefaultSecurityChangeExecutor.java                 # Phase 1 已实现
  SecurityChangeCoordinator.java
  AuthorizationEpochGuard.java
  HighRiskApprovalGate.java
  SecurityChangeOutboxProcessor.java

spectra-core/src/main/java/com/devops00/spectra/core/security/audit/
  JdbcSecurityAuditWriter.java                       # Phase 1 已实现
  SecurityAuditQueryService.java

spectra-core/src/main/java/com/devops00/spectra/core/security/session/
  SecuritySessionService.java
  SessionRevocationService.java
  SessionPolicyService.java

spectra-core/src/main/java/com/devops00/spectra/core/security/authentication/
  SecuritySubject.java
  AuthenticationChallengeService.java
  AuthenticationAssurance.java
  MfaFactorProvider.java
  TotpFactorProvider.java
  MfaEnrollmentService.java
  RecoveryCodeService.java

spectra-core/src/main/java/com/devops00/spectra/core/security/root/
  JdbcRootPolicyRepository.java                      # Phase 1 已实现
  JdbcLastEffectiveDevOpsGuard.java                  # Phase 1 已实现
  BreakGlassAuditPolicy.java

spectra-starter/spectra-security-base/src/main/java/com/devops00/spectra/security/base/
  audit/SecurityAuditEvent.java                      # Phase 1 已实现
  audit/SecurityAuditWriter.java                     # Phase 1 已实现
  audit/AuditVisibilityPolicy.java                   # Phase 1 已实现
  root/RootPolicy.java                               # Phase 1 已实现
  root/RootPolicyRepository.java                     # Phase 1 已实现
  root/LastEffectiveDevOpsGuard.java                 # Phase 1 已实现
  root/RootAuthorizationPolicy.java                 # Phase 1 已实现
  change/SecurityChangeExecutor.java                 # Phase 1 已实现

spectra-security-base/src/main/java/com/devops00/spectra/security/base/holder/
  SecurityUserLoader.java                         # Phase 0 已实现

spectra-core/src/main/java/com/devops00/spectra/core/auth/service/impl/
  DatabaseSecurityUserLoader.java                 # Phase 0 已实现

spectra-security-spring-boot-starter/src/main/java/.../session/redis/
  RedisSecuritySessionRepository.java
  TokenDigestService.java
  RedisSessionScripts.java
  RedisSessionIndexRepository.java

spectra-framework/src/main/java/.../mybatis/security/
  ScopedAuthorization.java
  AuthorizationExecutionContext.java
  ScopeSqlInterceptor.java
  ResourceScopePolicyRegistry.java
  ResourceAuthorizationGuard.java

spectra-config/src/main/resources/db/migration/
  V1__init_target_schema.sql                       # Phase 1 已实现；Flyway 唯一迁移事实源
  V2__security_runtime_privileges.sql              # Phase 1 已实现；runtime/migrator/Audit DB 权限
  V3__security_permission_catalog_seed.sql         # 102 个目标 Permission seed
  V4__complete_schema_comments_and_ai_tables.sql   # 结构注释与 spectra_ai 目标表
  V5__remove_legacy_core_ai_session.sql            # 删除 Core 遗留 AI 表
  V6__seed_core_reference_data.sql                 # Core 字典、文件类型、有效菜单种子

docs/50-开发指南/
  DEV_OPS-Break-Glass-Runbook.md
```

## 18.3 Permission Catalog Artifact

```text
docs/security/permission-catalog.yaml
  # Phase 3 初稿：89 个旧 code mapping、102 个目标 code 候选；seed 前必须通过业务复核和覆盖率测试。
```

## 18.4 Proposed Frontend Files

```text
spectra-ui/src/plugin/security/auth-session.ts
spectra-ui/src/plugin/security/refresh-transport.ts
spectra-ui/src/plugin/security/permission.ts
spectra-ui/src/views/Profile/Security/Mfa/
spectra-ui/src/views/System/Security/RoleAssignment/
spectra-ui/src/views/Ops/Security/Session/
spectra-ui/src/views/Ops/Security/AuthenticationMethod/
spectra-ui/src/views/Ops/Security/Policy/
spectra-ui/src/views/Ops/Security/Audit/

spectra-app/src/platform/secure-storage/
spectra-app/src/platform/device/installation-id.ts
spectra-app/src/services/auth-session.ts
spectra-app/src/pages/security/mfa/
spectra-app/tests/auth-session.test.ts
spectra-app/tests/http-refresh.test.ts
```

---

# 19. Confirmed Decisions / Remaining Design Concerns

## 19.1 已确认的架构决策

| 决策 | 确认结果 |
|---|---|
| Web Refresh Token | HttpOnly + Secure；默认 Host-only；优先 SameSite=Strict，确有跨站需要时才允许 None；全部通过安全 typed 部署配置管理，配套 session-bound CSRF token 和精确 Origin allowlist |
| DataScope 粒度 | 首版直接使用 `(RoleAssignment, Permission)` permission-specific Access Boundary |
| Delegation 范围 | 首版直接使用 `(RoleAssignment, Permission)` Grant Boundary |
| Scope 模式 | permission-specific Boundary 仅允许 NONE / ALL / SELF / RULES；缺失不等于 NONE，ALL 必须显式授予 |
| Access/Grant 关系 | 删除全局 `ManagementScope ⊆ AccessScope`；只校验同 Permission Grant Boundary 对目标边界的 contains |
| Security Relevant Change | fence 后新请求立即失效；高风险写提交前重新验证 security epoch |
| Security Audit | 应用层不可删除/篡改，默认热存 12 个月、总保留至少 5 年并允许未来归档；归档自身审计；高风险安全写在 Audit 不可用时 fail-closed |
| Redis/Session 故障 | 核心依赖不可用时 fail-closed，不回退旧快照/本地缓存 |
| DEV_OPS | 首版支持多个；maxDevOpsUsers 默认 3 且可配置；推荐 2 normal + 1 break-glass；永远保护最后一个 effective Root；break-glass 进入独立 Runbook 和最高等级 Audit |
| MFA | 架构支持多个 Factor；首版实现 TOTP；DEV_OPS 强制 MFA；Recovery Code 单次使用且只存 Hash；WebAuthn/Passkey 后续实现，最终恢复进入 break-glass |
| Database/Flyway | Codex 按现有规范设计完整目标 schema；新环境从 V1 开始；默认 baselineOnMigrate=false；不长期维护旧模型兼容层 |
| Permission Catalog | Codex 扫描全项目生成；旧 Permission/Scope 只做一次性 mapping，验收后删除旧体系 |
| 双人审批 | 首版不实现，只保留 HighRiskApprovalGate 扩展点 |
| OPEN_API | 首版不实现 Service Principal/Client Credentials，只保留 SecuritySubject 类型扩展能力 |

## Concern 1 — RULES Policy Coverage

**Current Requirement**  
Scope 使用 NONE/ALL/SELF/RULES，且必须绑定到具体 Permission。

**Risk**  
不同资源的归属字段、关联表、工作流候选人和文件对象模型不同；如果 RULES 接受自由 JSON 或缺少 ResourceScopePolicy，容易出现 SQL 注入、策略遗漏或 fail-open。

**Recommended Adjustment**  
Codex 在 Phase 0/3 的项目扫描中为每个 scope-aware Permission 生成机器可读 ResourceScopePolicy；RULES 只允许已注册 rule type 和 schema，Repository contract test 保证每个外部数据路径都有策略。未登记、无法解析或无法编译的规则统一 deny。

**Impact**  
不是待选架构项，而是实现完整性门禁；会增加各业务模块的 Policy 与测试工作量。

## Concern 2 — Break-glass Operational Readiness

**Current Requirement**  
推荐 2 normal + 1 break-glass DEV_OPS，永远保护最后一个有效 Root，最终 MFA 恢复进入 break-glass。

**Risk**  
如果只有代码路径而没有凭据保管、身份核验、告警、轮换和演练，真实故障中仍可能永久失去 Root，或把 break-glass 变成常用后门。

**Recommended Adjustment**  
Phase 1 必须同时交付独立 Runbook、离线凭据分权保管方案、最高等级告警、定期演练、使用后 TOTP/Recovery Code/密码轮换和复盘模板。Runbook 未演练前不得宣称 Root 恢复能力就绪。

**Impact**  
需要运维治理配合，但不改变应用授权模型。

## Concern 3 — Archive Backend and Final Disposition

**Current Requirement**  
Security Audit 默认热存 12 个月、总保留至少 5 年，允许未来归档，归档行为自身必须审计。

**Risk**  
归档介质、WORM/对象锁、加密密钥、恢复查询 SLA 和超过最低期限后的最终处置取决于部署环境，不能在应用代码中假装统一解决。

**Recommended Adjustment**  
首版先交付分区、保留元数据、archive manifest 与接口；Phase 8 按实际基础设施选择不可变归档 backend，并验证归档、校验、恢复和失败回滚。任何最终处置必须在不少于 5 年且符合外部治理批准后执行。

**Impact**  
默认期限已确定；仍需在 Phase 8 选择部署相关基础设施并估算存储成本。

---

# Implementation Readiness Checklist

## 已可直接实施，无需再决定原则

- [x] 保持 Opaque Token，不切 JWT。
- [x] 删除 Permission/Scope 全局重组，采用 Assignment-preserving 解析。
- [x] DataScope 首版使用 permission-specific Access Boundary，不使用 Assignment-wide Scope；scopeMode 固定为 NONE/ALL/SELF/RULES。
- [x] Delegation 首版使用 permission-specific Grant Boundary，删除全局 `ManagementScope ⊆ AccessScope`。
- [x] User 只通过 RoleAssignment 获得 Role/Permission；Role 不继承。
- [x] Permission 与 Menu 分离，Root 默认全部菜单。
- [x] DEV_OPS 使用统一 RootPolicy，禁止业务代码散落角色特判。
- [x] 首版支持多个 DEV_OPS，maxDevOpsUsers 默认 3 且可配置，推荐 2 normal + 1 break-glass，并使用 LastEffectiveDevOpsGuard 保护最后一个有效 Root。
- [x] Root 不绕过 Security Audit。
- [x] Access 固定短 TTL；Refresh rotation + replay revoke。
- [x] Web Refresh Token 使用 HttpOnly/Secure、默认 Host-only、优先 Strict 且仅必要时 None 的 Cookie，并实施 CSRF、精确 Origin/Referer 和 CORS 防护；属性全部进入安全部署配置。
- [x] Security Relevant Change 统一 Audit/Impact/Revocation。
- [x] fence 后新请求立即失效；高风险写事务提交前重新验证 security epoch。
- [x] Security Audit 应用层不可删除/篡改，默认热存 12 个月、总保留至少 5 年，允许未来归档且归档自身审计；高风险安全写在 Audit 不可用时 fail-closed。
- [x] Redis/Session 核心安全依赖不可用时 fail-closed。
- [x] MFA 支持多个 Factor，首版实现 TOTP；DEV_OPS 强制 MFA；Recovery Code 单次使用且只存 Hash；WebAuthn/Passkey 后续扩展，最终恢复进入 break-glass。
- [x] 双人审批首版不实现，只保留扩展点。
- [x] OPEN_API Service Principal 首版不实现，只保留主体模型扩展能力。
- [x] ACTIVE/LOCKED/DISABLED/DEPARTED 生命周期和普通 User 不删除。
- [x] 主部门 + 关联部门与安全 Scope 解耦。
- [x] 使用 Closure/OrganizationVersion 做组织影响分析。
- [x] 后端 Permission + Scope 双校验，覆盖 IDOR/批量/导出。
- [x] Flyway 从完整目标 V1 管理新环境，默认 baselineOnMigrate=false；最终表结构由 Codex 按现有规范设计，不长期维护旧模型兼容层。
- [x] Permission Catalog 由 Codex 全仓扫描生成；旧 Permission/Scope 只做一次性 migration mapping 后删除。
- [x] Web/App 统一 single-flight refresh，在线用户永不回显 Token。
- [x] Phase 0 先建立攻击回归测试和封堵现行 Critical 漏洞。

## 剩余 Phase-specific 实施项

- [x] Phase 1 由 Codex依据现有 PostgreSQL/项目规范完成目标安全表、字段、约束、索引、全量业务表汇总和 V2 运行时权限边界的第一版文件级设计；真实部署账号授权核对仍待完成。
- [x] Phase 1 已交付 SecurityAuditWriter、AuditVisibilityPolicy、RootPolicy/LastEffectiveDevOpsGuard、SecurityChangeExecutor 契约与 fail-closed 单元回归。
- [x] Phase 1 已将目标 DDL 汇总为不可变 `V1__init_target_schema.sql`，配置 `baselineOnMigrate=false`、`validate-on-migrate=true`、`clean-disabled=true`，并加入静态 schema 契约测试和默认禁用的真实 PostgreSQL/Flyway 集成测试；集成测试通过专用环境变量显式开启，不会默认触碰本机数据库。
- [~] Phase 1 已使用临时 PostgreSQL 验证空库从 V1 初始化、审计 append-only trigger 和 Root policy 基本 DDL；新增的空库/非空库 Flyway 门禁尚未在 CI/部署隔离数据库实际执行，并发边界自动化仍待补齐。
- [x] Phase 1 已交付 `V2__security_runtime_privileges.sql`，应用运行时角色不能更新/删除 Security Audit；实际部署登录角色的 membership 和 owner/runtime 分离仍需上线前核对。
- [~] Phase 1 已编写 2 normal + 1 break-glass 的独立 Runbook 草案；凭据分权保管、最高等级告警、轮换流程评审和演练仍待完成。
- [x] Phase 2 已将 User 生命周期状态契约切换为目标字符串状态，并覆盖 ACTIVE/LOCKED/DISABLED/DEPARTED、显式重新入职和非法转换测试；已接入专用生命周期写入口、Audit、securityVersion 和 Session revoke。
- [x] Phase 2 已接入 `authentication_identity`、`password_credential` Entity/Mapper/Service；用户名密码登录、用户创建、密码修改/重置、通知地址解析以及短信/邮箱绑定切换到目标模型；旧 Account 已由后续 Phase 删除。
- [x] Phase 3 已交付 assignment-preserving AuthorizationSnapshot 纯领域契约、目标 schema 数据库加载器和 cross-assignment/Grant Boundary 单元测试；RoleAssignment 写入、旧 Role/Authority 删除和正式授权上下文接入已在后续 Phase 完成。
- [x] Phase 3 已提供目标 RoleAssignment/Boundary 只读 API；写入继续冻结到 Phase 4 GrantBoundary 流程。
- [x] Phase 4 已交付 Assignment 与 Role 的 Grant Boundary/authorityLevel 校验、Impact Preview/Apply token、并发 version/securityVersion 门禁、统一 Audit/Session revoke；旧用户角色、旧角色权限和旧 DataScope 写入口已冻结。
- [x] Phase 5 已交付 `sec:v2:*` Redis Session、Token Digest、Token Family Rotation/Replay 撤销、并发策略、Web HttpOnly Host-only Refresh Cookie + CSRF、App Token 存储/设备 ID 适配，以及 TOTP/AAL2/Recovery Code MFA 核心和 DEV_OPS 强制 MFA。
- [x] Phase 6 已交付 Permission-Aware DataScope 基础门禁：Permission-specific `ScopeSqlPolicy`、`ScopedAuthorization`/`ExecutionContext`、资源授权 Guard、OA 资源策略标注、V7 归属索引及数据库契约测试；真实 PostgreSQL cross-assignment 集成验收仍需部署环境凭据后执行。
- [x] Phase 3 Permission Catalog 初稿、旧 code mapping 扫描和 V3 seed 已交付；Phase 7 已完成 Controller/ResourceScopePolicy 覆盖复核、旧大写运行时引用清理，并通过 115 条 Catalog、Controller 权限契约和 Menu != Permission 门禁。
- [x] Phase 7 已完成 Permission Catalog version 2、V8 Permission/Menu seed、RoleAssignment 驱动菜单树、`/security/context`、Web/App 权限上下文迁移和安全运维三级菜单；后端全量回归、前端 type/lint/test、文档检查及数据库静态契约核对均已通过，并已独立提交。
- [~] Phase 8 已完成审计查询/详情/导出、可见性矩阵、查询侧二次脱敏、V9 保留策略与 archive manifest、runtime 只读权限、Web 安全审计页面，以及登录/登出/刷新、MFA、用户生命周期/密码、Role/Assignment/组织 Preview/Apply、归档状态事件生产者；策略变更生产者、真实 PostgreSQL 分区/归档介质选择和恢复演练仍待完成。
- [~] Phase 9 已开始认证身份运行时迁移：SMS/Email provider、身份绑定/解绑不再读取旧 Account 表，统一使用目标 `authentication_identity`；Context、Session 查询/撤销、认证生命周期和 token 主体查询窄端口已接入，core/notification/AI/workflow/framework/log 的 SecUtil 业务/框架调用已清零，OA 申请/日程/会议/公告、资产/合同/文档/请假/采购/报销/物资/工作台以及认证控制器、Token 过滤器、AI token 工具已完成迁移；旧 Role/Authority/RoleAssignment/Account 运行时迁移和 V11/V12 旧表清理已完成，Redis 旧键和最终端到端验收仍待完成。
- [x] Phase 9 数据范围运行时切换：`DataScopeInnerInterceptor` 仅消费 Permission-specific `AuthorizationSnapshot`，`DataScopeProvider`/`DataScopeResolver` 已移除，通知收件人已迁移到 `user:read` Boundary；相关定向测试、后端全量回归和数据库安全契约核对已通过。
- [x] Phase 9 已切断用户/角色直接 DataScope API：用户/角色 DTO、VO、服务写入路径和 `SecurityUser` 旧范围字段已移除，Web 表单与转换器已同步；后端全量回归、Web format/lint/type/test 和数据库安全契约核对已通过。
- [x] Phase 9 已清理旧 DataScope 孤儿模型与数据库契约：删除旧实体、Mapper/XML、DTO/枚举，新增 V10 下线迁移并同步 `docs/sql`、实体清单、ER 图和 AI 实体字典；数据库安全契约测试已覆盖 V10 的幂等 DROP 与无自动迁移约束。
- [x] Phase 9 已完成目标角色目录与菜单关系切换：Role CRUD 使用 `spectra_security.role`，菜单授权和当前菜单树使用 `spectra_security.role_menu` 与目标 AuthorizationSnapshot；角色、菜单关系、菜单树和数据库安全契约测试通过并已独立提交。
- [x] Phase 9 已完成 Permission Catalog 只读切换：`/authority/tree` 不再提供旧 Authority CRUD，目标 Permission 按资源分组展示；角色 Permission 读取/撤销使用目标关系表，Catalog、关系服务和数据库安全契约测试通过并已独立提交。
- [x] Phase 9 已完成 Web Role capability 迁移：RBAC 读取目标 Role 授权状态和 version，分别维护 Permission/GrantablePermission，授权写入使用 Impact Preview/Apply，旧角色权限写 API 已从前端移除；后端目标测试、Web format/type/lint/test 和数据库安全契约核对通过并已独立提交。
- [x] Phase 9 已完成用户资料与授权解耦：UserSaveFrom、UserService 和 Web 用户表单不再接受 `role_ids`，旧用户角色覆盖路由已删除；后端编译、Web format/type/lint/test 和数据库安全契约核对通过并已独立提交。
- [x] Phase 9 已完成 RoleAssignment 只读角色展示迁移：用户分页/当前资料从活动 `spectra_security.role_assignment` 读取角色，并暴露 Role/Assignment version 与独立 Boundary 元数据；查询服务、后端编译、Web format/type/lint/test 和数据库安全契约核对通过并已独立提交。
- [x] Phase 9 已完成 Web RoleAssignment Preview/Apply 编辑器：用户编辑器读取目标 Role/Permission Catalog/组织树，支持显式 Access/Grant Boundary 和 Scope 模式校验，并通过短时 Preview token Apply；后端 Permission Catalog 定向测试、Web format/lint/type/test 和数据库安全契约核对通过并已独立提交。
- [x] Phase 9 已完成旧授权运行时清理：删除旧 Authority/Role/RelUserRole/RelRoleAuthority 模型、Mapper、Service、监听器和旧 Role 权限路由，User 生命周期回收切换为撤销活动 RoleAssignment；V11 数据库迁移、后端定向/全量回归和文档检查通过并已独立提交。
- [x] Phase 9 已完成旧 Account 认证因子清理：绑定/解绑切换到 `authentication_identity`，删除旧 Account 实体/Mapper/Service/Controller/XML，新增 V12 下线 `sys_account`；后端认证身份定向测试、全量回归、Web format/lint/type/test、数据库契约和文档检查通过并已独立提交。
- [ ] 数据迁移前逐账号确认旧 user-level Scope 应映射到哪些 Permission Boundary；不自动生成 GrantablePermission/Grant Boundary。
- [ ] 部署前填写 Cookie Host/Path、是否确需 SameSite=None、精确 Origin allowlist、反向代理 HTTPS 感知和 CSRF 传输配置；未填或不安全组合启动失败。
- [ ] Phase 5 完成 TOTP/Recovery Code 密钥管理、设备迁移和 Root break-glass 恢复演练。
- [ ] Phase 8 选择满足 12 个月热存、至少 5 年总保留的归档介质、WORM/完整性校验和恢复查询方案。

## 真正开始重构前的门禁

- [x] 人工批准目标 Authorization/Session/Audit 核心行为模型。
- [x] 明确目标物理模型由 Codex 依据项目规范设计，Flyway 从完整 V1 开始且不启用 baselineOnMigrate。
- [x] 明确 Permission Catalog 由 Codex 扫描生成，scopeMode 为 NONE/ALL/SELF/RULES，旧 code 只做一次性 mapping。
- [ ] 建立现有管理员、Root、角色、用户 Scope 数据盘点报告。
- [ ] 建立当前数据库备份、恢复、全局 logout 和回滚演练方案。
- [~] 已提交独立 break-glass Runbook 草案；仍需完成首版 TOTP/Recovery Code 运维流程评审和隔离环境演练。
- [ ] 为 Phase 0/1 建立独立 PR 边界，不把架构迁移和漏洞修复混在一个提交。
- [ ] 每个 Phase 评审 Definition of Done 后再进入下一阶段。

核心安全决策已经确认，实施按 Phase 门禁推进。本轮已完成 Phase 0 提交后的 Phase 1 审计/Root 治理骨架、完整目标数据库 V1 migration 和目标安全 DDL 契约，以及 Phase 4 的 Assignment/Role Grant Boundary 与 Impact Preview/Apply 骨架；数据库运行时角色权限、V2 Redis Session、MFA、组织变更 Preview/Apply 和完整业务 ResourceScopePolicy 仍按后续 Phase 继续交付。每个 Phase 必须完成代码测试、数据库契约核对并独立提交后再进入下一阶段。
