---
tags:
  - plan
  - user
  - authorization
  - import
  - spectra-admin
  - spectra-ui
created: 2026-08-21
---

# P-用户开通与批量授权体验优化计划

## 状态

**进行中**

> 创建时间：2026-08-21
> 计划范围：`spectra-admin`、`spectra-ui`
> 当前核心授权模型保持不变：`User`、`Role`、`RoleAssignment`、`Permission`、`Access Boundary` 和 `Grant Boundary` 继续分别承担各自职责。

### 当前进度（2026-08-21）

- [x] 新增 `/system/user/create` 和编辑 `/system/user/:id/edit` 完整页面路由。
- [x] 用户新增/编辑从抽屉改为完整页面，编辑页可独立加载用户详情。
- [x] 完整页面按“基本信息 → 角色授权”步骤条分开展示，避免表单和授权配置连续纵向堆叠。
- [x] 增加管理员用户详情接口 `GET /api/user/{uid}`，支持编辑页刷新和直接访问。
- [x] 创建用户后返回用户 ID，并在同一开通流程中继续完成角色授权。
- [x] 用户列表返回后端计算的授权状态，并提供直接进入授权步骤的入口。
- [x] 建立授权方案、方案 Role 配置和方案 Permission Boundary 的独立数据模型，并提供版本化管理接口。
- [x] 授权方案保存时校验当前 Role/Permission/Scope/部门编码，禁止通过普通方案配置 DEV_OPS Role。
- [x] 用户授权步骤支持套用单 Role 授权方案，并在提交前继续允许调整 Boundary。
- [x] 提供授权方案列表、独立创建/修改页面、启用、停用和删除操作，并复用访问控制菜单入口。
- [x] 授权方案管理和单用户套用已完成；批量导入后端的结构化行契约、任务、校验和 Preview/Apply 已完成。
- [x] Web 端已完成带中文表头和编码下拉校验的 Excel 模板下载、CSV/TXT/Excel 上传、行编辑、Preview、Apply、错误处理和结果查看闭环。
- [x] 大批量 Apply 已改为有界后台任务，Web 端轮询任务详情展示处理进度和最终错误明细。

## 问题背景

当前新增用户和角色授权是两个相互独立的操作：

1. 管理员先填写并保存用户基本信息。
2. 用户创建接口不返回新用户 ID，前端保存成功后关闭抽屉并回到列表。
3. 管理员需要再次点击编辑用户，才能看到 RoleAssignment 授权编辑器。
4. 管理员需要先选择 Role，再逐个配置 Permission 对应的 Access Boundary。
5. RoleAssignment、Access Boundary 等内部授权模型直接暴露在界面中，普通管理员需要理解较多技术概念。
6. 后续导入用户时，如果沿用当前流程，就需要前端逐条创建用户、逐条 Preview、逐条 Apply，操作复杂、请求数量多，也难以处理部分失败和错误定位。

当前实现基线：

- `UserApi.create()` 和后端用户创建接口返回新用户 ID。
- 用户基础信息已经改为独立的完整页面；已有用户的 RoleAssignment 授权编辑器显示在编辑页的授权区域，新用户保存成功后直接切换到编辑页的角色授权步骤。
- RoleAssignment 授权已经采用 Preview/Apply 流程，授权变更由后端统一校验 Role、Permission、Access Boundary、Grant Boundary 和操作人权限。

相关实现：

- [`spectra-ui/src/api/user/user-api.ts`](../../spectra-ui/src/api/user/user-api.ts)
- [`spectra-ui/src/views/System/User/index.vue`](../../spectra-ui/src/views/System/User/index.vue)
- [`spectra-ui/src/views/System/User/components/UserEdit/index.vue`](../../spectra-ui/src/views/System/User/components/UserEdit/index.vue)
- [`spectra-ui/src/views/System/User/components/RoleAssignmentEditor/index.vue`](../../spectra-ui/src/views/System/User/components/RoleAssignmentEditor/index.vue)
- [`spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/controller/UserController.java`](../../spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/controller/UserController.java)
- [`spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/security/authorization/service/impl/AuthorizationAssignmentChangeServiceImpl.java`](../../spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/security/authorization/service/impl/AuthorizationAssignmentChangeServiceImpl.java)

## 修复目标

### 主要目标

1. 将新增用户和角色授权编排为一个连续的“用户开通流程”。
2. 让普通管理员主要操作“角色”和“数据范围”，不要求直接理解 RoleAssignment 内部结构。
3. 选择 Role 后支持按常用范围一键生成多个 Permission 的 Access Boundary。
4. 保留按 Permission 高级配置 Access Boundary 和 Grant Boundary 的能力。
5. 用户列表可以直接看出授权状态，并能直接进入“配置授权”。
6. 引入可复用的授权方案，减少重复配置，并为批量导入提供稳定的业务入口。
7. 批量导入采用“上传、校验、预览、应用”流程，不由前端循环调用单用户接口。
8. 批量导入继续执行当前 Grant Boundary、Preview/Apply、审计、版本和幂等校验，不降低安全边界。

### 设计原则

- **运行时模型不改变**：授权方案只是生成运行时授权实例的模板，不替代 RoleAssignment。
- **用户感知简单，内部模型完整**：前端隐藏不必要的 `assignment_id`、`scope_id` 等内部字段。
- **默认配置优先，高级配置可用**：覆盖常见部门授权场景，同时支持复杂 Permission 级差异。
- **一次预览，一次应用**：单用户和批量导入都必须在应用前完成影响预览。
- **安全校验集中在后端**：前端只负责交互和展示，不能绕过后端授权范围校验。
- **不自动授予过大权限**：不因为简化操作而默认授予 `ALL` 或 `GLOBAL`。
- **错误可定位、可修复、可重试**：导入错误必须精确到行和字段，应用结果必须可查询。

## 非目标

- 本计划不重做 `Role`、`Permission`、`RoleAssignment` 的核心关系。
- 本计划不把 Access Boundary 直接移动到 Role 上。
- 本阶段不引入兼容旧接口的双轨流程；项目当前开发阶段直接使用新的 1.0.0 契约。
- 本阶段不要求实现任意格式的 Excel 自动映射；优先提供固定模板和明确字段。
- 本阶段不允许导入接口绕过 Grant Boundary 或安全审计。

## 目标用户流程

### 单用户开通

```text
新增用户
  ↓
填写基本信息
  ↓
保存并继续配置授权
  ↓
选择角色或授权方案
  ↓
选择默认数据范围
  ↓
按需展开高级 Permission 配置
  ↓
Preview
  ↓
Apply
  ↓
完成
```

同时提供次要操作：

```text
保存并稍后配置
```

如果用户暂时没有角色授权，列表中必须显示“未配置授权”，而不是让管理员以为流程已经全部完成。

### 已有用户授权

用户列表提供独立入口：

```text
编辑信息
配置授权
```

不要求管理员进入完整用户编辑抽屉后再寻找角色设置。

### 批量导入

```text
下载模板
  ↓
填写用户信息和授权方案编码
  ↓
上传文件
  ↓
解析并校验
  ↓
查看错误、修复并重新上传
  ↓
查看新增用户和授权影响
  ↓
批量 Apply
  ↓
查看导入结果和失败明细
```

## 详细实现步骤

### 阶段一：确认现状与交互契约

#### 1.1 盘点现有用户创建链路

**操作**：

- 确认用户创建、修改、列表回显和抽屉关闭逻辑。
- 确认用户创建成功后返回 ID 的接口契约。
- 确认用户没有 RoleAssignment 时的授权状态定义。
- 确认“保存并继续配置”和“保存并稍后配置”的业务差异。

**文件**：

- `spectra-ui/src/api/user/user-api.ts`
- `spectra-ui/src/views/System/User/index.vue`
- `spectra-ui/src/views/System/User/components/UserEdit/index.vue`
- `spectra-admin/.../core/user/controller/UserController.java`
- `spectra-admin/.../core/user/service/UserService.java`
- `spectra-admin/.../core/user/service/impl/UserServiceImpl.java`

#### 1.2 盘点现有授权提交链路

**操作**：

- 确认新增 RoleAssignment 和更新已有 RoleAssignment 的请求差异。
- 确认 Role 的 Permission 列表、Access Boundary 范围模式和 Grant Boundary 能力来源。
- 确认 Preview Token、请求 Hash、Assignment version 和目标用户安全版本的校验规则。
- 确认批量授权时可以复用的领域校验和持久化逻辑。

**验收**：

- 形成单用户新增、单用户授权、已有用户授权和批量导入四种流程图。
- 明确哪些字段属于用户输入，哪些字段只能由后端生成。

### 阶段二：优化单用户新增流程

#### 2.1 创建用户接口返回新用户 ID

**操作**：

- 新增 `UserCreatedVO` 或等价的具体响应类型。
- 用户创建成功后返回用户 ID、用户名和必要的展示信息。
- 保留用户创建、身份标识、密码凭证和审计的一致性。
- 前端 API 类型从 `Promise<void>` 改为具体响应类型。

**接口方向**：

```text
POST /api/user
response: { id, username }
```

#### 2.2 将用户新增改为两步向导

**操作**：

- 第一步只处理用户基本信息。
- 新增主按钮“保存并继续配置授权”。
- 创建成功后保留用户 ID，直接进入角色授权步骤。
- 提供次要按钮“保存并稍后配置”。
- 用户编辑时保留“编辑信息”和“配置授权”两个明确入口。
- 避免因切换步骤重复请求或重复挂载权限树。

**前端状态**：

```typescript
type UserProvisionStep = "profile" | "authorization" | "completed";
```

#### 2.3 增加授权状态展示

**操作**：

- 用户列表增加授权状态列。
- 区分“未配置”“授权不完整”“已生效”“部分失效”等状态。
- 用户创建成功但未配置授权时明确提示。
- 不自动为新用户授予高权限 Role。

**后端支持**：

- 用户列表或用户详情返回有效 RoleAssignment 授权状态摘要。
- 授权状态由后端根据有效 Assignment、Permission Boundary 和 Role 状态计算，前端不自行推断。

**当前实现**：

- `UserPageVO.authorizationStatus` 返回 `UNCONFIGURED`、`INCOMPLETE`、`ACTIVE` 或 `PARTIAL`。
- 用户列表以标签和说明展示授权状态；“配置授权”入口直接打开用户编辑页的角色授权步骤。
- 授权状态计算使用 Assignment 生效时间、Assignment 状态、Role 状态、Role Permission 数量和 Access Boundary 数量；前端不通过角色列表自行推断。

### 阶段三：优化角色授权编辑体验

#### 3.1 隐藏内部授权实例细节

**操作**：

- 普通界面使用“角色授权”作为主标题。
- `RoleAssignment` 作为高级详情或审计信息展示。
- 已有多个授权实例时显示角色卡片列表。
- 提供“添加角色授权”“编辑角色授权”“撤销角色授权”等明确动作。
- 展示角色名称、角色编码、状态、生效时间和授权状态。

#### 3.2 选择 Role 后展示权限摘要

**操作**：

- 选择 Role 后展示 Permission 数量和权限分类。
- 展示当前 Role 是否允许 Grantable Permission。
- 过滤停用 Role、无效 Permission 和当前操作人不可授予的角色。
- 角色变化时清理不再属于新 Role 的 Boundary 草稿。
- 角色变化后重新执行后端校验，不能只依赖前端缓存。

#### 3.3 增加默认访问范围

**操作**：

- 提供常用范围预设：仅本人、所属部门、所属部门及下级部门、全部组织、自定义。
- 根据 Permission 允许的 Scope Mode 过滤或禁用不适用选项。
- 选择预设后，为可配置 Permission 自动生成 Access Boundary 草稿。
- 允许管理员查看生成结果后再 Preview/Apply。
- 不把无法适用统一范围的 Permission 静默扩大为 `ALL`。

#### 3.4 保留高级 Permission 级配置

**操作**：

- 增加“高级配置每个权限的访问范围”折叠区。
- 每个 Permission 单独显示 Access Boundary。
- Grant Boundary 仅在 Role 声明 Grantable Permission 时显示。
- 明确区分“当前用户访问范围”和“可向下授权范围”。
- 提供边界摘要，避免管理员必须打开多个表单才能确认最终范围。

### 阶段四：建设可复用授权方案

#### 4.1 定义授权方案边界

**授权方案不是运行时授权对象**，而是生成授权实例的模板：

```text
授权方案
  ├── Role
  ├── Permission-specific Access Boundary
  └── 可选 Grant Boundary
       ↓ 应用到用户
RoleAssignment + AssignmentPermissionBoundary + AssignmentGrantBoundary
```

#### 4.2 设计授权方案数据

**建议字段**：

- 方案编码；
- 方案名称；
- 方案说明；
- 一个或多个 RoleAssignment 配置；
- 每个 Role 下的 Permission Boundary 配置；
- 可选 Grant Boundary 配置；
- 状态；
- 版本号；
- 创建人、更新时间和审计信息。

**设计要求**：

- 方案引用 Role、Permission 的稳定业务编码，不让导入文件携带内部 UUID。
- 方案发布后使用版本快照，避免修改方案导致历史导入语义不明确。
- 方案不能绕过当前操作人的 Grant Boundary。
- 方案只作为默认配置来源，应用时仍需重新校验目标用户、Role、Permission 和 Boundary。

**当前已实现**：

- `sec_authorization_profile` 保存方案元数据、状态和版本；
- `sec_authorization_profile_assignment` 保存 Role 业务编码与 Role version 快照；
- `sec_authorization_profile_boundary` 使用 JSONB 保存 Permission-specific Access/Grant Boundary，RULES 使用部门业务编码；
- `/security/authorization/profiles` 已提供列表、详情、创建、修改、停用和删除接口；
- Web 端授权方案列表采用系统管理页布局，新建和编辑使用独立页面；授权方案编辑采用“基本信息 → 选择角色 → 权限范围设置”三步流程，角色支持多选并为每个角色生成独立 Assignment，权限支持多选添加，并可勾选多个权限批量应用访问组织、子部门和授权范围，最后一步统一提交；批量设置遵循选中 Permission 的共同 `allowed_scope_modes`，右侧提供“全选权限”“清空选择”“选中按组织规则”“选中按仅当前主体数据”快捷操作，避免把 `RULES` 与 `SELF` 权限混在一起配置；仅支持 `NONE` 的权限不会显示组织选择；页面明确区分授权方案与运行时 RoleAssignment，套用后仍须按当前用户完成 Preview/Apply，停用或删除方案不会撤销已生效授权；
- 单用户流程已支持选择单 Role 方案并通过 RoleAssignment Preview/Apply；多 Role 方案和批量导入后端仍待实现。

#### 4.3 建设授权方案管理界面

**操作**：

- 新增、编辑、启用、停用、删除授权方案。
- 从现有用户授权复制为授权方案。
- 预览方案会生成哪些 Permission Boundary。
- 查看使用中的用户数和最近应用记录。
- 方案停用后不能用于新建用户或导入，但不影响已经生成的 RoleAssignment；删除方案模板也不影响已生成的 RoleAssignment。

#### 4.4 接入单用户开通流程

**操作**：

- 角色授权步骤优先展示授权方案。
- 选择方案后自动填充 Role 和 Boundary。
- 允许在应用前针对当前用户临时调整。
- 明确提示“本次调整不会修改授权方案本身”。

### 阶段五：设计批量导入后端

#### 5.1 导入任务和暂存数据

> 状态：已完成。后端当前接受固定模板的结构化行和文件摘要，Excel/CSV 文件解析放在阶段六；正式 User、RoleAssignment 和 Boundary 只在 Apply 阶段写入。

**操作**：

- 创建导入任务，保存上传文件摘要、操作人、状态和过期时间。
- 解析后的行数据写入暂存结构，不直接写入正式 User 和授权表。
- 每一行保存原始行号、规范化字段、校验状态和错误信息。
- 导入任务具备幂等键，重复提交相同文件和参数不能重复创建用户。

**建议状态**：

```text
UPLOADED
  → VALIDATING
  → PREVIEWED
  → APPLYING
  → SUCCEEDED / PARTIAL_FAILED / FAILED / EXPIRED
```

#### 5.2 固定模板和字段

> 状态：固定字段契约已完成，文件上传和 Excel/CSV 解析尚未接入。

**普通模板**：

```text
用户信息 Sheet
  username
  real_name
  phone
  email
  department_code
  language
  timezone
  authorization_profile_code
```

如果后续需要支持一个用户多个 Role，可增加授权 Sheet：

```text
授权 Sheet
  user_key
  authorization_profile_code
```

不允许普通导入模板直接填写：

- `role_id`；
- `assignment_id`；
- `permission_id`；
- `scope_id`；
- 内部数据库 UUID。

#### 5.3 导入校验

> 状态：已完成。后端校验必填字段、手机号/邮箱/用户名重复、部门、语言、时区、授权方案、已存在用户策略；Apply 继续复用 RoleAssignment Preview/Apply 完成 Role、Permission、Scope 和 Grant Boundary 校验。

**校验内容**：

- 必填字段；
- 手机号码格式和重复；
- 邮箱格式和重复；
- 用户名重复；
- 已存在用户处理策略；
- 部门编码是否存在；
- 语言和时区是否有效；
- 授权方案是否存在且处于可用状态；
- Role 和 Permission 是否仍然有效；
- Access Boundary 是否符合 Permission 的范围规则；
- 当前操作人是否拥有足够 Grant Boundary；
- 导入任务是否过期或重复应用。

所有授权校验必须由后端完成，不能因为是批量接口而只做前端校验。

#### 5.4 批量 Preview/Apply

> 状态：已完成。任务响应包含行数、跳过数、错误数、预计授权实例/Access Boundary/Grant Boundary 数量、短时 Preview Token 和过期时间。

**接口方向**：

```text
POST /api/user/imports/preview
POST /api/user/imports/{importId}/apply
GET  /api/user/imports/{importId}
GET  /api/user/imports/{importId}/errors
```

**Preview 结果至少包含**：

- 总行数；
- 可创建用户数；
- 可创建 RoleAssignment 数；
- Access Boundary 数量；
- Grant Boundary 数量；
- 将跳过的记录数；
- 错误记录数；
- 授权影响摘要；
- 预览令牌和过期时间。

**安全要求**：

- Preview Token 绑定操作人、导入任务、文件摘要、授权方案版本和请求 Hash。
- Apply 时重新校验令牌、请求 Hash、授权方案版本和安全版本。
- 文件内容、授权方案或目标数据发生变化时必须重新 Preview。
- 不能由前端按用户循环调用单用户 Preview/Apply。

#### 5.5 批量写入和失败处理

> 状态：已完成。Apply 在服务端逐行处理，每行使用独立事务并记录 `APPLIED`、`SKIPPED` 或 `ERROR`；用户创建与该用户授权方案应用处于同一行事务内。导入文件解析和结果下载仍属于阶段六。

**操作**：

- 复用现有用户创建、身份标识、密码凭证和授权变更领域服务。
- 每个用户及其授权实例至少保证行级一致性：用户创建、RoleAssignment 和 Boundary 要么全部成功，要么该行失败。
- 批量任务记录每一行的成功、跳过或失败原因。
- 默认先修复全部授权安全错误后再 Apply。
- 对普通数据错误提供明确的失败行结果；是否允许“仅应用通过行”必须由管理员明确确认。
- 应用过程产生用户创建、RoleAssignment、Boundary 变更和导入任务审计记录。

### 阶段六：实现批量导入前端

> 状态：已完成。Web 端支持固定 CSV/TXT/Excel 结构化行闭环、错误明细处理和大批量 Apply 进度轮询。

#### 6.1 模板和上传

**操作**：

- [x] 提供带中文表头和“名称｜编码”下拉校验的 Excel 模板下载。
- [x] 展示中文模板表头、字段说明、授权方案编码和部门编码填写说明；错误明细导出使用中文表头，访问边界和授权边界使用中文展示。
- [x] 支持 CSV、TXT 和 Excel 上传，选择文件后自动解析并展示文件名、行数和结果。
- [x] 限制文件大小为 5 MB。
- [x] 接入 Excel 解析，默认读取第一个工作表并复用固定表头校验。

#### 6.2 校验结果

**操作**：

- [x] 按行展示后端错误结果，支持返回本地行编辑后重新 Preview。
- [x] 支持按错误类型筛选和下载错误明细。
- [x] 修复后使用新的幂等键重新 Preview，不重复应用旧任务。
- [x] 存在错误行时禁止进入 Apply。

#### 6.3 影响预览和应用

**操作**：

- [x] 展示新增用户、跳过用户、授权实例和 Boundary 数量。
- [x] 展示文件、已有用户处理策略和 Preview 有效期。
- [x] 应用前明确提示这是批量授权变更。
- [x] Apply 返回 `APPLYING` 任务，由有界后台执行器逐行处理；前端轮询任务详情展示已处理行数、成功、跳过和失败统计。
- [x] 应用完成后提供成功、跳过和失败明细。

### 阶段七：测试、文档和验收

#### 7.1 前端测试

- 新增用户保存并继续配置授权。
- 保存并稍后配置后的授权状态展示。
- Role 变化后 Boundary 草稿清理。
- 默认范围生成多个 Permission Boundary。
- 高级 Permission 级范围覆盖默认范围。
- Grant Boundary 仅在角色允许时可用。
- 授权方案选择、复制以及启用、停用和删除状态。
- [x] 批量导入文件解析支持 CSV/TXT/Excel，错误分类和错误明细导出已覆盖工具测试。
- [x] 批量导入进度计算覆盖零总量、正常比例和超过总量的边界。
- [x] 批量导入 API 契约覆盖 Preview、Apply、任务详情和错误明细查询，并校验统一 API 版本头。
- [x] 授权实例和授权方案的 Boundary 转换、未知部门编码拒绝及非 RULES 范围清理已覆盖工具测试。
- 导入文件校验、错误下载、Preview、Apply 和结果展示。

#### 7.2 后端测试

- 创建用户接口返回具体用户 ID。
- 用户创建失败时不返回可继续授权的假 ID。
- 新建 RoleAssignment 和更新已有 RoleAssignment。
- Role、Permission 和 Boundary 不一致时拒绝。
- Grant Boundary 越权时拒绝。
- 授权方案版本变化时要求重新 Preview。
- [x] 批量导入 Apply 返回 `APPLYING`，重复 Apply 不重复派发后台任务，预览错误行计入完成进度。
- 批量导入幂等和重复应用拒绝。
- 单行用户和授权事务一致性。
- 导入错误精确定位到文件行和字段。
- Preview Token、请求 Hash、操作人和安全版本校验。
- 用户创建、授权实例、Boundary 和导入任务审计完整。

#### 7.3 文档同步

实施代码变更后同步：

- `docs/00-项目总览.md`；
- `docs/10-后端/20-用户与权限.md`；
- `docs/10-后端/90-API总览.md`；
- `docs/20-前端/10-spectra-ui.md`；
- `docs/30-数据模型/10-ER图.md`；
- `docs/30-数据模型/20-实体清单.md`；
- `docs/70-AI速查/03-实体字典.md`；
- `docs/70-AI速查/04-API端点.md`；
- `docs/70-AI速查/05-配置清单.md`（如果新增配置项）。

批量导入本轮 API、实体、SQL、后端和 Web 领域文档已同步，`check-docs.ps1` 已通过；其余流程和安全验收仍待继续补齐。

本轮验证结果：`spectra-core` 全量测试 115 个通过、11 个 PostgreSQL 集成测试因环境条件跳过；Web 端 54 个测试、格式检查、lint、类型检查和生产构建均通过。后端 `spotless:check` 尚未完成，当前受本机 Spotless Eclipse/P2 依赖缓存缺失影响。

## 推荐实施顺序

```text
阶段一：现状与契约确认
  ↓
阶段二：单用户新增向导
  ↓
阶段三：角色授权体验
  ↓
阶段四：授权方案
  ↓
阶段五：批量导入后端
  ↓
阶段六：批量导入前端
  ↓
阶段七：测试、文档和验收
```

第一阶段和第二阶段可以优先落地，不需要等待批量导入完成；授权方案应在批量导入之前确定，避免先实现一套无法复用的导入字段。

## 验证方案

### 功能验收

- [ ] 新增用户后可以直接进入角色授权，不需要回到列表重新编辑。
- [ ] 用户可以选择“保存并稍后配置”，列表显示未配置授权。
- [ ] 用户可以从列表直接进入“配置授权”。
- [ ] 选择 Role 后可以查看权限摘要和默认范围预览。
- [ ] 默认范围可以生成合法的 Permission-specific Access Boundary。
- [ ] 高级模式可以单独修改某个 Permission 的范围。
- [ ] Grant Boundary 和 Access Boundary 的界面含义清晰且互不混淆。
- [ ] 授权方案可以复用、启用、停用、删除和复制。
- [ ] 导入可以完成上传、校验、预览、应用和结果下载。

### 安全验收

- [ ] 前端不能绕过后端 Role、Permission 和 Grant Boundary 校验。
- [ ] 普通操作人不能通过授权方案或导入获得超出自身 Grant Boundary 的授权。
- [ ] Preview Token 与文件内容、授权方案版本和请求 Hash 绑定。
- [ ] 重复 Apply 不会重复创建用户或授权实例。
- [ ] 应用过程保留完整审计记录。
- [ ] 授权变更后的会话、Epoch 和安全版本处理保持现有规则。

### 代码质量验证

```powershell
# 根目录
.\scripts\check-docs.ps1

# 后端
Set-Location spectra-admin
.\mvnw.cmd spotless:check
.\mvnw.cmd test

# Web
Set-Location ..\spectra-ui
pnpm run format:check
pnpm run lint
pnpm run type-check
pnpm run test
pnpm run build
```

## 影响范围

### 后端

- 用户创建 Controller、Service、From/VO 和 Converter；
- 用户列表授权状态查询；
- RoleAssignment 授权查询和变更服务；
- Access Boundary、Grant Boundary 和授权方案服务；
- 用户导入任务、暂存数据、校验、Preview/Apply 和结果查询；
- 授权与导入审计、幂等和版本校验；
- 相关数据库表、索引和迁移脚本。

### Web 前端

- 用户新增/编辑向导；
- 用户列表授权状态和操作入口；
- RoleAssignmentEditor 交互和文案；
- 授权方案管理与选择；
- 批量导入页面、模板、校验、预览和结果展示；
- 用户、授权和导入相关 API、类型和测试。

### 数据库和文档

- 可能新增授权方案、授权方案明细、导入任务和导入行暂存表；
- 新增表必须同步实体清单、ER 图、实体字典和 SQL 文档；
- 新增 Controller 或 API 路径必须同步 API 总览和 API 端点速查。

## 完成定义

- [ ] 单用户新增已经成为连续的用户开通流程。
- [ ] 用户列表可以直接识别未配置授权的用户。
- [ ] 普通管理员不需要直接操作 RoleAssignment 内部字段。
- [ ] 角色权限支持默认范围快速配置和 Permission 级高级配置。
- [ ] 授权方案可以复用并安全应用到用户。
- [x] 批量导入后端不再依赖前端循环调用单用户接口。
- [x] 批量导入后端具备校验、Preview、Apply、幂等、版本校验和错误追踪能力。
- [x] Web 端具备固定 CSV/TXT/Excel 的上传、校验、预览、应用和结果展示闭环。
- [ ] 前后端测试和文档检查全部通过。
- [ ] 文档、API、实体和项目总览与实际源码一致。

## 相关

- [[../10-后端/20-用户与权限]]
- [[../10-后端/90-API总览]]
- [[../20-前端/10-spectra-ui]]
- [[../30-数据模型/10-ER图]]
- [[../30-数据模型/20-实体清单]]
- [[../40-规范/15-后端开发规范]]
- [[../00-项目总览]]
