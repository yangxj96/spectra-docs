---
tags:
  - plan
  - architecture
  - backend
  - frontend
  - database
created: 2026-07-30
status: in-progress
---

# P-菜单路由权限解耦计划

> **面向 AI 代理的工作者：** 必需子技能：使用 `subagent-driven-development`（推荐）或 `executing-plans` 逐任务实施。所有步骤使用复选框跟踪；任何 Git 写操作和数据库写操作都必须先获得用户明确确认。

**目标：** 将页面路由改为前端静态定义，将 `sys_menu` 收敛为支持任意层级的角色导航权限树，同时保留一级顶部菜单、递归侧栏、详情页 401 校验和现有角色菜单授权能力。

**架构：** Vue Router 静态注册全部页面，数据库菜单通过唯一 `route_name` 关联可点击路由。后端分别提供完整管理树和当前用户授权树；前端根据授权树渲染顶部及侧栏，并通过路由元数据校验直接访问。数据库采用 expand-contract 三阶段迁移，SQL 仅写入文件，由用户手动执行。

**技术栈：** Java 25、Spring Boot 4、MyBatis-Plus、PostgreSQL 18、Vue 3.5、Vue Router 5、Pinia、Element Plus、Vitest、JUnit 5。

---

## 状态

**已完成（2026-07-30）**

> 状态变更时间：2026-07-30

## 已确认决策

| 主题 | 决策 |
|---|---|
| 路由来源 | 页面路由全部由 spectra-ui 静态定义 |
| 菜单职责 | `sys_menu` 只保存导航树和角色菜单权限 |
| 层级 | 菜单树及侧栏支持任意层级 |
| 一级菜单 | 根节点继续渲染在顶部导航 |
| 二级及以下 | 当前顶部节点的后代递归渲染在侧栏 |
| 详情/编辑页 | 不写入 `sys_menu`，通过静态路由的 `requiredMenu` 继承所属菜单权限 |
| 未授权访问 | 路由存在但无菜单权限时以 `replace` 方式进入 `/401` |
| 未定义路由 | 进入 `/404` |
| 安全边界 | 前端菜单校验改善体验，后端 `@PreAuthorize` 仍是最终安全边界 |
| 角色关联 | 保留 `sys_rel_role_menu`，仅持久化 `MENU` 节点 ID |
| SQL 执行 | AI 只生成 SQL 文件；用户手动执行，执行后 AI 使用只读账号检查 |

## 当前问题

1. `MenuServiceImpl.tree()` 返回全部菜单，没有按登录用户角色过滤，角色菜单关联未参与运行时菜单加载。
2. `RelRoleMenuServiceImpl.grant()` 删除旧关联时错误使用 `RelRoleMenu::getRoleId` 匹配菜单 ID，取消授权不能正确删除。
3. `route-utils.ts` 根据数据库 `component` 动态加载页面，数据库记录与前端文件路径强耦合。
4. `Sidebar/index.vue` 只手写渲染一层 `item.children`，无法优雅扩展到四级及以上。
5. `Navbar/index.vue` 通过 URL 前缀判断顶部菜单，菜单层级与路径结构被隐式绑定。
6. 编辑、预览、个人中心和消息中心依赖 `hide=true` 的伪菜单记录。
7. 面包屑依赖 `metadata.crumbs` 手工维护，容易与菜单树和路由标题不一致。

## 目标数据模型

| 字段 | 约束 | 说明 |
|---|---|---|
| `id` | 主键 | 菜单 ID，继续被 `sys_rel_role_menu.menu_id` 引用 |
| `pid` | 可空、自关联 | 父菜单 ID |
| `name` | 非空 | 导航显示名称 |
| `icon` | 可空 | 导航图标 |
| `menu_type` | 非空 | `DIRECTORY` 或 `MENU` |
| `route_name` | `MENU` 必填、活动记录唯一 | Vue Router 路由名称 |
| `sort` | 非空 | 同级排序 |

规则：

- `DIRECTORY` 负责分组，可以有子节点，`route_name` 必须为空。
- `MENU` 是可点击叶子节点，`route_name` 必须非空。
- `sys_rel_role_menu` 只关联 `MENU` 节点。
- 角色选中后代菜单时，运行时接口自动补齐祖先目录，但不会把目录写入角色关联表。
- 多角色用户取所有启用角色菜单的并集。
- 旧字段 `path`、`component`、`layout`、`hide`、`metadata` 在收缩迁移前保留，稳定后删除。

## 路由元数据协议

```typescript
type MenuRouteMeta = {
    title: string;
    requiresAuth?: boolean;
    requiredMenu?: string;
    activeMenu?: string;
};
```

| 场景 | `requiredMenu` | `activeMenu` |
|---|---|---|
| 可见菜单页 | 等于自身路由名 | 默认等于自身路由名 |
| 详情/编辑/预览页 | 所属可见菜单路由名 | 所属可见菜单路由名 |
| 个人中心/消息中心 | 不设置 | 不设置 |
| 登录/401/404 | 不设置 | 不设置 |

```typescript
{
    path: "workflow/:id/edit",
    name: "WorkflowEdit",
    component: () => import("@/views/System/Workflow/components/WorkflowDesigner/index.vue"),
    meta: {
        title: "流程编辑",
        requiresAuth: true,
        requiredMenu: "SystemWorkflow",
        activeMenu: "SystemWorkflow"
    }
}
```

## 计划文件清单

### 后端

| 文件 | 操作 |
|---|---|
| `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/javabean/enums/MenuType.java` | 创建菜单类型枚举 |
| `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/javabean/entity/Menu.java` | 映射新字段，分阶段移除旧字段 |
| `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/javabean/from/MenuSaveFrom.java` | 校验菜单类型和路由名 |
| `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/javabean/vo/MenuVO.java` | 调整角色菜单响应 |
| `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/javabean/vo/MenuTreeVO.java` | 调整树形响应 |
| `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/javabean/converter/MenuConverter.java` | 同步字段转换 |
| `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/service/MenuService.java` | 增加当前用户菜单查询 |
| `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/service/impl/MenuServiceImpl.java` | 多角色合并、祖先补齐、裁剪和排序 |
| `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/controller/MenuController.java` | 新增 `GET /menu/current` |
| `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/javabean/from/RoleMenuFrom.java` | 允许空菜单列表 |
| `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/service/impl/RelRoleMenuServiceImpl.java` | 修复差量更新并过滤目录 |
| `spectra-admin/spectra-modules/spectra-core/src/test/java/com/devops00/spectra/core/service/MenuServiceImplTest.java` | 当前用户菜单树测试 |
| `spectra-admin/spectra-modules/spectra-core/src/test/java/com/devops00/spectra/core/service/RelRoleMenuServiceImplTest.java` | 角色菜单授权测试 |

### Web 前端

| 文件 | 操作 |
|---|---|
| `spectra-ui/src/plugin/router/routes.ts` | 聚合静态路由 |
| `spectra-ui/src/plugin/router/modules/common.ts` | 创建公共和用户路由 |
| `spectra-ui/src/plugin/router/modules/system.ts` | 创建系统管理路由 |
| `spectra-ui/src/plugin/router/modules/monitor.ts` | 创建监控路由 |
| `spectra-ui/src/plugin/router/modules/oa.ts` | 创建 OA 路由 |
| `spectra-ui/src/plugin/router/modules/example.ts` | 创建示例路由 |
| `spectra-ui/src/plugin/router/index.ts` | 实现静态路由权限守卫 |
| `spectra-ui/src/utils/menu-utils.ts` | 创建菜单树纯函数 |
| `spectra-ui/src/utils/route-utils.ts` | 移除动态组件和路由注册 |
| `spectra-ui/src/plugin/store/modules/use-app-store.ts` | 保存授权菜单和路由名集合 |
| `spectra-ui/src/layouts/components/Navbar/index.vue` | 改造顶部导航 |
| `spectra-ui/src/layouts/Default/components/Sidebar/MenuItem/index.vue` | 创建递归菜单项 |
| `spectra-ui/src/layouts/Default/components/Sidebar/index.vue` | 使用递归菜单项 |
| `spectra-ui/src/layouts/Default/index.vue` | 自动生成面包屑 |
| `spectra-ui/src/views/System/Menu/index.vue` | 调整菜单列表字段 |
| `spectra-ui/src/views/System/Menu/components/MenuEdit/index.vue` | 调整菜单表单 |
| `spectra-ui/src/views/System/RBAC/index.vue` | 只提交可点击菜单 |
| `spectra-ui/src/api/system/menu-api.ts` | 区分完整树和当前用户树 |
| `spectra-ui/types/system/menu.d.ts` | 定义新菜单类型 |
| `spectra-ui/tests/menu-utils.test.ts` | 菜单纯函数测试 |
| `spectra-ui/tests/MenuItem.test.ts` | 递归菜单测试 |
| `spectra-ui/tests/route-access.test.ts` | 401/404 测试 |

### SQL 和文档

| 文件 | 操作 |
|---|---|
| `docs/sql/spectra_core/V20260730_01__expand_sys_menu.sql` | 添加并回填新字段 |
| `docs/sql/spectra_core/V20260730_02__switch_sys_menu_data.sql` | 切换首页、角色关系和隐藏菜单 |
| `docs/sql/spectra_core/V20260730_03__contract_sys_menu.sql` | 删除旧字段 |
| `docs/sql/spectra_core/建表.sql` | 更新最终建表结构和种子数据 |
| `docs/10-后端/20-用户与权限.md` | 更新角色菜单授权语义 |
| `docs/10-后端/30-系统管理.md` | 更新菜单模型和接口 |
| `docs/10-后端/90-API总览.md` | 更新菜单端点 |
| `docs/20-前端/10-spectra-ui.md` | 更新静态路由和菜单架构 |
| `docs/30-数据模型/20-实体清单.md` | 更新 Menu 字段 |
| `docs/70-AI速查/03-实体字典.md` | 同步 Menu 字段 |
| `docs/70-AI速查/04-API端点.md` | 同步菜单端点 |

---

## 阶段零：修复角色菜单取消授权

> 本阶段不依赖数据库迁移，可以独立完成。

### 任务 0.1：编写失败测试

**文件：** `spectra-admin/spectra-modules/spectra-core/src/test/java/com/devops00/spectra/core/service/RelRoleMenuServiceImplTest.java`

- [x] 构造当前菜单 `{A, B}`、目标菜单 `{B, C}`，断言删除条件使用 `menu_id=A`，新增关系为 `C`。
- [x] 构造目标菜单空集合，断言删除角色的全部菜单关系。
- [x] 运行 `./mvnw test -pl spectra-modules/spectra-core -Dtest=RelRoleMenuServiceImplTest`，确认旧实现失败。

关键断言：

```java
verify(relRoleMenuMapper).delete(argThat(wrapper ->
        wrapper.getSqlSegment().contains("menu_id")
));
verify(relRoleMenuMapper).insert(argThat(rows ->
        rows.size() == 1 && rows.getFirst().getMenuId().equals(menuC)
));
```

### 任务 0.2：实现最小修复

**文件：**

- `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/service/impl/RelRoleMenuServiceImpl.java`
- `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/javabean/from/RoleMenuFrom.java`

- [x] 将删除条件改为 `.in(RelRoleMenu::getMenuId, removeIds)`。
- [x] 删除 `RoleMenuFrom.menuIds` 的 `@Size(min = 1)`，保留 `@NotNull`。
- [x] 空目标集合只删除，不批量插入空列表。
- [x] 运行指定阶段测试；全量测试的既有环境错误记录在阶段一验收说明中。
- [x] 本轮未执行提交；如后续提交，先请求用户确认，再按具体文件暂存。

---

## 阶段一：生成三段迁移 SQL

> 本阶段只创建 SQL 文件，不执行 SQL。

### 任务 1.1：创建扩展脚本

**文件：** `docs/sql/spectra_core/V20260730_01__expand_sys_menu.sql`

- [x] 在单个事务中添加允许为空的 `menu_type varchar(16)` 和 `route_name varchar(100)`。
- [x] 将现有可见根分组回填为 `DIRECTORY`。
- [x] 将现有可见叶子回填为 `MENU` 并显式设置路由名。
- [x] 隐藏伪菜单暂不删除，确保旧前端继续运行。
- [x] 创建活动记录的 `route_name` 部分唯一索引。
- [x] 添加 `menu_type IN ('DIRECTORY', 'MENU')` 检查约束，本阶段不加 `NOT NULL`。
- [x] 使用 PostgreSQL `DO` 校验块检查未映射的可见菜单，存在时主动抛错并回滚。

路由名映射：

| 现有组件 | 路由名 |
|---|---|
| `/Dashboard/index` | `Dashboard` |
| `/Monitor/Task/index` | `MonitorTask` |
| `/Monitor/Server/index` | `MonitorServer` |
| `/Monitor/Online/index` | `MonitorOnline` |
| `/Monitor/Cache/index` | `MonitorCache` |
| `/System/User/index` | `SystemUser` |
| `/System/RBAC/index` | `SystemRBAC` |
| `/System/Dept/index` | `SystemDept` |
| `System/Configured/index` | `SystemConfigured` |
| `/System/Dict/index` | `SystemDict` |
| `/System/Menu/index` | `SystemMenu` |
| `/System/Storage/index` | `SystemStorage` |
| `/System/Workflow/index` | `SystemWorkflow` |
| `/System/Region/index` | `SystemRegion` |
| `/OA/Asset/index` | `OAAsset` |
| `/OA/Attendance/index` | `OAAttendance` |
| `/OA/Calendar/index` | `OACalendar` |
| `/OA/Contact/index` | `OAContact` |
| `/OA/Contract/index` | `OAContract` |
| `/OA/Document/index` | `OADocument` |
| `/OA/Meeting/index` | `OAMeeting` |
| `/OA/Notice/index` | `OANotice` |
| `/OA/Report/index` | `OAReport` |
| `/Example/Form/index` | `ExampleForm` |
| `/Example/Table/index` | `ExampleTable` |
| `/Example/Echarts/index` | `ExampleEcharts` |
| `/Example/Markdown/index` | `ExampleMarkdown` |

### 任务 1.2：创建数据切换脚本

**文件：** `docs/sql/spectra_core/V20260730_02__switch_sys_menu_data.sql`

- [x] 将“首页默认”的角色关联迁移到“首页”根节点，再将首页设置为 `MENU -> Dashboard`。
- [x] 先删除隐藏菜单的角色关联，再软删除流程编辑、表单编辑、表单预览、个人中心、消息中心和“首页默认”。
- [x] 删除目录类型的角色关联，只保留 `MENU` 关联。
- [x] 将剩余活动菜单的 `menu_type` 设置为非空。
- [x] 添加目录路由名必须为空、菜单路由名必须非空的检查约束。
- [x] 添加迁移后断言，异常时回滚整个事务。

### 任务 1.3：创建收缩脚本和最终建表 SQL

**文件：**

- `docs/sql/spectra_core/V20260730_03__contract_sys_menu.sql`
- `docs/sql/spectra_core/建表.sql`

- [x] 收缩脚本删除 `path`、`component`、`layout`、`hide`、`metadata`。
- [x] 收缩脚本执行前断言所有活动菜单均已使用新模型。
- [x] 最终建表 SQL 直接创建新结构、索引和约束；当前建表文件没有种子数据。
- [x] 新环境执行建表 SQL 后无需执行三个迁移脚本。

### 阶段一验收

- [x] 只审查 SQL 文本，不连接写账号，不执行 DDL/DML。
- [x] 使用只读查询核对当前菜单组件和映射清单一一对应。
- [x] 状态切换为“等待用户执行扩展 SQL”。
- [x] 指定单元测试 3/3 通过，完整 `package -DskipTests` 构建成功。
- [x] 全量 reactor 测试存在既有环境错误：`spectra-framework/GuoMiUtilTest` 的测试运行时缺少 PostgreSQL 驱动；本次阶段测试不依赖 Spring 容器。

> [!danger] 人工数据库关卡 A
> 暂停后续实施。用户手动执行 `V20260730_01__expand_sys_menu.sql` 并通知 AI。AI 只能使用只读账号检查字段、索引、约束和回填结果。

---

## 阶段二：后端切换为导航权限模型

> 前置条件：人工数据库关卡 A 已通过只读检查。

### 任务 2.1：映射和校验新字段

**文件：**

- `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/javabean/enums/MenuType.java`
- `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/javabean/entity/Menu.java`
- `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/javabean/from/MenuSaveFrom.java`
- `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/javabean/vo/MenuVO.java`
- `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/javabean/vo/MenuTreeVO.java`
- `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/javabean/converter/MenuConverter.java`

- [x] 定义 `MenuType { DIRECTORY, MENU }`。
- [x] 添加 `menuType` 和 `routeName`，本阶段继续映射旧字段。
- [x] 校验 `DIRECTORY.routeName == null`、`MENU.routeName` 非空。
- [x] 校验 `MENU` 不能拥有活动子节点。
- [x] 校验父级不是自身或后代，防止菜单环。
- [x] 添加保存校验测试并运行 spectra-core 测试。

### 任务 2.2：实现当前用户菜单树

**文件：**

- `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/service/MenuService.java`
- `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/service/impl/MenuServiceImpl.java`
- `spectra-admin/spectra-modules/spectra-core/src/test/java/com/devops00/spectra/core/service/MenuServiceImplTest.java`

```java
List<MenuTreeVO> current(UUID userId);
```

- [x] 先写单角色测试：只返回关联菜单和祖先目录。
- [x] 再写多角色测试：取并集且不重复。
- [x] 编写禁用角色、无菜单、空目录裁剪和同级排序测试。
- [x] 实现用户启用角色查询、角色菜单并集、祖先补齐和树构建。
- [x] 自动补齐的目录只用于导航，不加入可访问路由集合。
- [x] 运行 `./mvnw test -pl spectra-modules/spectra-core -Dtest=MenuServiceImplTest`。

### 任务 2.3：拆分管理树和当前用户树接口

**文件：**

- `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/controller/MenuController.java`
- `spectra-ui/src/api/system/menu-api.ts`

```text
GET /menu/tree     完整管理树，需要 MENU:* 权限
GET /menu/current  当前登录用户授权树，只要求已认证
```

- [x] `/menu/current` 从认证主体读取用户 ID，不接收客户端用户 ID。
- [x] 新前端稳定后将 `/menu/tree` 从迁移期 `isAuthenticated()` 收紧为 `MENU:*`；RBAC 页面继续使用完整树。
- [x] 使用异常映射测试和运行时请求覆盖匿名、普通用户和菜单管理员。

### 任务 2.4：规范角色菜单保存

**文件：**

- `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/service/impl/RelRoleMenuServiceImpl.java`
- `spectra-admin/spectra-modules/spectra-core/src/test/java/com/devops00/spectra/core/service/RelRoleMenuServiceImplTest.java`

- [x] 后端加载请求菜单，只保留活动 `MENU` 节点。
- [x] 不存在的菜单 ID 返回中文数据异常。
- [x] 目录 ID由后端过滤，不写入关系表。
- [x] 路径 `roleId` 与请求体 `roleId` 不一致时拒绝请求。
- [x] 覆盖空列表、重复 ID、目录 ID、不存在 ID和正常差量更新测试。

### 阶段二验收

```bash
./mvnw test -pl spectra-modules/spectra-core
./mvnw clean package -DskipTests
```

- [x] `/menu/tree` 返回完整新模型菜单树。
- [x] `/menu/current` 按当前登录用户角色过滤。
- [x] 后端定向测试和完整跳过测试构建通过。

---

## 阶段三：前端静态路由和权限守卫

### 任务 3.1：建立模块化静态路由

**文件：**

- `spectra-ui/src/plugin/router/routes.ts`
- `spectra-ui/src/plugin/router/modules/common.ts`
- `spectra-ui/src/plugin/router/modules/system.ts`
- `spectra-ui/src/plugin/router/modules/monitor.ts`
- `spectra-ui/src/plugin/router/modules/oa.ts`
- `spectra-ui/src/plugin/router/modules/example.ts`

- [x] 保留现有 URL，避免书签和站内消息链接失效。
- [x] 为每个数据库 `route_name` 创建同名静态路由。
- [x] 流程编辑、表单编辑、表单预览继承 `SystemWorkflow`。
- [x] 个人中心、消息中心只要求登录，不要求菜单。
- [x] 保留 401 自动后退和 404 页面。
- [x] 添加 catch-all 路由并运行类型检查。

### 任务 3.2：实现菜单纯函数

**文件：**

- `spectra-ui/src/utils/menu-utils.ts`
- `spectra-ui/tests/menu-utils.test.ts`
- `spectra-ui/src/plugin/store/modules/use-app-store.ts`
- `spectra-ui/types/system/menu.d.ts`

```typescript
export function collectAuthorizedRouteNames(menus: Menu[]): Set<string>;
export function findMenuByRouteName(menus: Menu[], routeName: string): Menu | undefined;
export function findMenuPath(menus: Menu[], routeName: string): Menu[];
export function findFirstRoutableMenu(menu: Menu): Menu | undefined;
```

- [x] 测试三层、四层查找和空目录。
- [x] 测试路由名集合去重。
- [x] Store 保存菜单树和授权路由名集合，删除 URL 前缀状态。

### 任务 3.3：切换菜单加载和路由守卫

**文件：**

- `spectra-ui/src/utils/route-utils.ts`
- `spectra-ui/src/plugin/router/index.ts`
- `spectra-ui/src/api/system/menu-api.ts`
- `spectra-ui/tests/route-access.test.ts`

- [x] 运行时改用 `MenuApi.current()`。
- [x] 删除 `import.meta.glob`、组件加载、菜单转路由和 `router.addRoute()`。
- [x] 首次导航先加载菜单，再解析静态路由。
- [x] `requiredMenu` 不在授权集合时 `replace` 到 `/401`。
- [x] 401、404 不重复校验菜单权限。
- [x] 未定义路由进入 404。
- [x] 测试详情页继承权限、401 和 404。

### 阶段三验收

```bash
pnpm run format
pnpm run lint:fix
pnpm run type-check
pnpm run test
pnpm run build
```

- [x] 前端不再根据数据库组件路径注册路由。
- [x] 静态详情页声明继承菜单权限并通过守卫测试。
- [x] 无菜单权限直接输入 URL 时进入 401。

---

## 阶段四：顶部导航、递归侧栏和面包屑

### 任务 4.1：改造顶部一级菜单

**文件：** `spectra-ui/src/layouts/components/Navbar/index.vue`

- [x] 根节点作为顶部菜单来源。
- [x] 根 `MENU` 按路由名跳转。
- [x] 根 `DIRECTORY` 跳转第一个可访问 `MENU` 后代。
- [x] 根据 `activeMenu ?? requiredMenu` 的祖先链确定顶部高亮。
- [x] 删除 URL 前缀匹配和 `currentMenusPrefix`。

### 任务 4.2：实现递归侧栏

**文件：**

- `spectra-ui/src/layouts/Default/components/Sidebar/MenuItem/index.vue`
- `spectra-ui/src/layouts/Default/components/Sidebar/index.vue`
- `spectra-ui/tests/MenuItem.test.ts`

- [x] `DIRECTORY` 渲染 `el-sub-menu` 并递归子节点。
- [x] `MENU` 渲染 `el-menu-item` 并使用命名路由跳转。
- [x] 使用菜单 ID 作为 key。
- [x] 测试四级菜单渲染和末级跳转。
- [x] 一级根节点为 `MENU` 时不显示侧栏。

### 任务 4.3：自动生成面包屑

**文件：**

- `spectra-ui/src/layouts/Default/index.vue`
- `spectra-ui/src/utils/menu-utils.ts`
- `spectra-ui/tests/menu-utils.test.ts`

- [x] 普通页使用授权菜单祖先链。
- [x] 详情页使用 `activeMenu` 祖先链并追加 `meta.title`。
- [x] 删除 `metadata.crumbs` 读取逻辑。
- [x] 验证“系统管理 / 工作流 / 流程管理 / 流程编辑”。

### 阶段四验收

- [x] 根菜单由顶部导航渲染，根 `MENU` 不显示侧栏。
- [x] 系统管理、系统监控、OA 等一级菜单继续位于顶部。
- [x] 二级至四级目录和菜单递归展开并按命名路由跳转。
- [x] 面包屑不依赖数据库 JSON。

---

## 阶段五：菜单管理和角色授权页面

### 任务 5.1：改造菜单管理

**文件：**

- `spectra-ui/src/views/System/Menu/index.vue`
- `spectra-ui/src/views/System/Menu/components/MenuEdit/index.vue`

- [x] 类型选择为目录或菜单。
- [x] 目录隐藏路由名，菜单要求路由名。
- [x] 移除组件路径、布局、隐藏状态和 JSON 元数据输入。
- [x] 父级候选排除当前节点及其后代。
- [x] 菜单节点不能创建子节点。
- [x] 路由名从静态路由注册表选择，避免自由输入拼写错误。

### 任务 5.2：改造角色菜单授权

**文件：** `spectra-ui/src/views/System/RBAC/index.vue`

- [x] RBAC 页面继续调用完整 `/menu/tree`。
- [x] 保存时只提取 `MENU` 节点 ID。
- [x] 空集合正常提交。
- [x] 回显只设置关联菜单 ID，父目录自然半选或全选。
- [x] 角色切换时清理旧勾选和半选状态。

### 阶段五验收

- [x] 菜单表单支持任意层级目录和静态路由选择。
- [x] 角色只关联可点击菜单。
- [x] 取消单个菜单和清空全部菜单均受前后端支持。
- [x] 当前用户菜单接口和前端加载只使用所属启用角色菜单。

> [!note] 滚动发布兼容
> SQL 02 执行前，`/menu/tree` 暂时保留原有认证权限并返回旧节点，旧前端仍可运行；新菜单管理和 RBAC 页面在客户端过滤 `menu_type IS NULL` 节点。新前端稳定后再收紧管理树权限。

---

## 阶段六：数据切换和完整回归

> 前置条件：阶段二至五的测试和构建全部通过，新前端不再依赖隐藏菜单和旧字段。

> [!danger] 人工数据库关卡 B
> 暂停实施。用户手动执行 `V20260730_02__switch_sys_menu_data.sql` 并通知 AI。AI 使用只读账号检查首页关系迁移、隐藏菜单清理、目录关系清理、约束和角色菜单数量。

### 任务 6.1：迁移后只读检查

- [x] 活动菜单不存在 `menu_type IS NULL`。
- [x] `DIRECTORY.route_name` 全为空。
- [x] `MENU.route_name` 全部非空且唯一。
- [x] 角色菜单没有关联目录、软删除菜单或不存在菜单。
- [x] 首页根节点为 `MENU -> Dashboard`，“首页默认”已软删除。
- [x] 隐藏页面菜单均已软删除。

> [!success] 人工数据库关卡 B 已通过（2026-07-30）
> 活动菜单共 31 个（4 个 `DIRECTORY`、27 个 `MENU`），活动角色菜单关系 40 条；系统管理员、运维管理员、审计员和用户角色均保留 1 条 Dashboard 授权。未发现空类型、非法路由绑定、重复路由名、目录/悬空角色关系或拥有活动子节点的 `MENU`。

> [!bug] 关卡 B 首次运行时回归修复
> 首次登录发现后端 snake_case 菜单字段未在前端 API 边界归一化，导致授权路由集合为空并进入 401；同时发现当前菜单查询混入软删除节点。已增加递归字段归一化、显式 `deleted IS NULL` 条件和回归测试，重启后复验通过。

> [!success] 运行时完整回归已通过（2026-07-30）
> 四类账号登录和 `/menu/current` 均成功，授权树分别为管理员 17 个菜单、运维管理员 17 个、审计员 1 个、普通用户 5 个，均只有一个 Dashboard 且无重复或缺失路由名。Edge 实际浏览器验证首页、授权页面、个人中心、消息中心、401 三秒安全回退和 404 均通过。首次导航出现的 `/auth/refresh` 是 `validateToken()` 主动刷新会话，不是 401 重试。

> [!success] 收缩前代码审查问题已关闭（2026-07-30）
> 补齐用户角色关系与角色的软删除过滤，角色授权拒绝软删除菜单，清理 `MenuMapper.xml` 中全部旧列，并为方法级权限拒绝补充 HTTP/业务码 403 映射和回归测试。

> [!success] 人工数据库关卡 C 已开放（2026-07-30）
> 最终复审补齐菜单修改、删除、父节点和子节点查询的显式软删除过滤，清理消息中心计划中的旧菜单 SQL，并增强 Mapper 旧列契约测试。后端 24 个相关测试、17 模块干净构建及前端格式、Lint、类型检查、25 个测试和生产构建均通过；最新后端产物已启动并监听 4004。用户可以手动执行关卡 C SQL。

> [!success] 人工数据库关卡 C 已通过（2026-07-30）
> `path`、`component`、`layout`、`hide`、`metadata` 五个旧列已全部删除；`menu_type` 和 `sort` 为非空，两个检查约束和两个活动唯一索引均已验证生效。活动菜单仍为 31 个（4 个 `DIRECTORY`、27 个 `MENU`），活动角色菜单关系仍为 40 条；非法菜单、非法角色菜单关系、重复路由名和非法父节点均为 0。

```sql
SELECT id, name FROM spectra_core.sys_menu
WHERE deleted IS NULL AND menu_type IS NULL;

SELECT id, name, menu_type, route_name FROM spectra_core.sys_menu
WHERE deleted IS NULL
  AND ((menu_type = 'DIRECTORY' AND route_name IS NOT NULL)
    OR (menu_type = 'MENU' AND route_name IS NULL));

SELECT route_name, COUNT(*) FROM spectra_core.sys_menu
WHERE deleted IS NULL AND route_name IS NOT NULL
GROUP BY route_name HAVING COUNT(*) > 1;

SELECT rrm.role_id, rrm.menu_id, m.name, m.menu_type
FROM spectra_core.sys_rel_role_menu rrm
LEFT JOIN spectra_core.sys_menu m ON m.id = rrm.menu_id AND m.deleted IS NULL
WHERE rrm.deleted IS NULL AND (m.id IS NULL OR m.menu_type <> 'MENU');
```

### 任务 6.2：完整回归

```bash
# spectra-admin
./mvnw test
./mvnw clean package -DskipTests

# spectra-ui
pnpm run format
pnpm run lint:fix
pnpm run type-check
pnpm run test
pnpm run build
```

- [x] 分别使用系统管理员、运维管理员、审计员和普通用户登录。
- [x] 验证顶部菜单和侧栏符合角色关联。
- [x] 验证多角色菜单并集（数据库无多角色测试账号，由 `MenuServiceImplTest` 覆盖）。
- [x] 验证无权限详情地址进入 401，自动后退不循环。
- [x] 验证未知地址进入 404。
- [x] 验证消息中心和个人中心仍可进入。

---

## 阶段七：收缩旧模型并同步文档

### 任务 7.1：移除后端旧字段

**文件：**

- `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/javabean/entity/Menu.java`
- `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/javabean/from/MenuSaveFrom.java`
- `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/javabean/vo/MenuVO.java`
- `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/javabean/vo/MenuTreeVO.java`
- `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/javabean/converter/MenuConverter.java`

- [x] 删除 `path`、`component`、`layout`、`hide`、`metadata`。
- [x] 删除 Menu 不再需要的 JSONB 类型处理器配置。
- [x] 确认全仓库不存在旧字段业务引用。
- [x] 后端测试和构建通过。

### 任务 7.2：同步知识库

**文件：**

- `docs/10-后端/20-用户与权限.md`
- `docs/10-后端/30-系统管理.md`
- `docs/10-后端/90-API总览.md`
- `docs/20-前端/10-spectra-ui.md`
- `docs/30-数据模型/20-实体清单.md`
- `docs/70-AI速查/03-实体字典.md`
- `docs/70-AI速查/04-API端点.md`
- `docs/00-项目总览.md`

- [x] 更新菜单字段、API、权限流和静态路由说明。
- [x] 使用 `[[wikilink]]` 连接本计划、系统管理、用户权限和前端笔记。
- [x] 检查 Entity 数量未变化，Controller 数量未变化。

> [!success] 人工数据库关卡 C 已完成（2026-07-30）
> 用户已手动执行 `V20260730_03__contract_sys_menu.sql`，AI 已使用只读账号确认旧列删除、最终约束和索引生效、数据保持一致。关卡 C 后 `/menu/current` 与 `/menu/tree` 的真实认证请求均返回 200，系统管理员菜单管理页面正常显示。

### 任务 7.3：最终验证

- [x] 查询 `information_schema.columns`，确认旧列已删除。
- [x] 查询 `pg_indexes` 和 `pg_constraint`，确认唯一索引和检查约束存在。
- [x] 后端成功查询 `/menu/tree`、`/menu/current`。
- [x] 前端登录、导航、401、404 和角色授权回归通过。
- [x] 将本计划状态改为“已完成”并记录日期。

---

## 阶段关卡汇总

| 关卡 | 执行者 | SQL | 通过条件 |
|---|---|---|---|
| A：扩展 | 用户 | `V20260730_01__expand_sys_menu.sql` | 新字段、索引、回填只读检查通过 |
| B：切换 | 用户 | `V20260730_02__switch_sys_menu_data.sql` | 角色关系和隐藏菜单迁移只读检查通过 |
| C：收缩 | 用户 | `V20260730_03__contract_sys_menu.sql` | 旧字段删除、最终约束和运行时回归通过 |

任一关卡未通过时：

- 停止后续代码阶段。
- AI 不尝试数据库修复写入。
- AI 根据只读查询结果修订 SQL 文件。
- 用户重新执行修订后的 SQL 或人工回滚。

## 最终验收标准

- [x] 数据库不再保存前端组件路径和隐藏页面路由。
- [x] 页面路由全部静态注册，构建期能发现组件缺失。
- [x] `sys_menu` 支持任意层级目录和菜单。
- [x] 一级菜单保持顶部展示，后代菜单递归展示在侧栏。
- [x] 角色菜单关联真实控制运行时菜单树。
- [x] 多角色菜单正确合并，禁用角色不生效。
- [x] 详情、编辑和预览页继承所属菜单权限。
- [x] 无菜单权限直接访问时进入 401，未知路由进入 404。
- [x] 401 自动后退不产生导航循环。
- [x] 菜单管理和角色授权支持清空、取消和四级以上层级。
- [x] 后端和前端全部验证命令通过。
- [x] 三个 SQL 均由用户手动执行，并由 AI 使用只读账号完成迁移后检查。

## 不纳入本计划

| 项目 | 原因 |
|---|---|
| 用菜单权限替代接口权限 | 前端权限不能作为安全边界 |
| spectra-app 菜单改造 | 当前动态菜单实现位于 spectra-ui |
| 引入独立 `sys_route` 表 | 静态路由已经消除数据库页面路由需求 |
| 菜单结果缓存 | 先保证授权正确性，避免增加失效复杂度 |
| 运营人员无发版新增页面 | 静态页面必须随前端代码发布 |

## 相关

- [[00-项目总览]]
- [[20-用户与权限]]
- [[30-系统管理]]
- [[10-spectra-ui]]
- [[20-实体清单]]
- [[15-后端开发规范]]
