---
tags:
  - plan
  - frontend
  - spectra-ui
---

# P-消息中心前端实现计划

## 状态

**进行中**

> 创建时间：2026-07-19

## 问题背景

系统当前缺少统一的消息通知入口，用户无法及时获取系统通知、工作流审批、OA公告等信息。需要在头部导航栏添加消息中心功能，提供快速查看和完整管理两种交互方式。

## 修复目标

1. 头部导航栏显示消息铃铛图标和未读数徽章
2. 点击铃铛弹出右侧抽屉，显示最新消息列表
3. 提供完整的消息中心页面，支持搜索、筛选、批量操作
4. 消息类型可扩展，支持系统通知、工作流、OA、站内信、待我审批等
5. 消息中心页面通过数据库菜单动态加载

## 详细实现步骤

### 阶段一：基础设施（类型定义、状态管理）

#### 1.1 创建消息类型定义

**操作**：创建全局类型声明文件

**文件**：
- `types/notification.d.ts` — 新建，定义消息相关类型

**内容**：
```typescript
/** 消息类型枚举 - 可扩展 */
type NotificationType = 
  | 'system'        // 系统通知
  | 'workflow'      // 工作流通知
  | 'oa'           // OA通知（会议、公告等）
  | 'inner_mail'   // 站内信
  | 'approval'     // 待我审批
  | string;        // 支持自定义扩展类型

/** 消息实体 */
interface Notification {
  id: string;
  title: string;
  content: string;
  type: NotificationType;
  isRead: boolean;
  createdAt: string;
  link?: string;              // 点击跳转路径
  sender?: string;            // 发送者
  senderAvatar?: string;      // 发送者头像
  extra?: Record<string, unknown>;
}

/** 消息查询参数 */
interface NotificationQueryParams {
  page_num: number;
  page_size: number;
  type?: NotificationType | 'all';
  is_read?: boolean;
  keyword?: string;
  start_time?: string;
  end_time?: string;
}

/** 消息类型配置 */
interface NotificationTypeConfig {
  type: NotificationType;
  label: string;
  color: string;
  icon: string;
}
```

#### 1.2 创建通知状态管理

**操作**：创建Pinia Store管理通知状态

**文件**：
- `src/plugin/store/modules/use-notification-store.ts` — 新建

**功能**：
- `notifications`: 消息列表
- `unreadCount`: 未读数量（计算属性）
- `currentType`: 当前筛选类型
- `fetchNotifications()`: 获取消息列表
- `markAsRead(id)`: 标记单条已读
- `markAllAsRead()`: 全部标记已读
- `deleteNotification(id)`: 删除消息
- `batchDelete(ids)`: 批量删除
- `refreshUnreadCount()`: 刷新未读数

#### 1.3 创建通知API模块（预留）

**操作**：创建API模块，后续对接后端

**文件**：
- `src/api/notification/notification-api.ts` — 新建

**接口预留**：
```typescript
export const NotificationApi = {
  /** 获取消息列表 */
  list: (params: NotificationQueryParams) => get("/api/notification/list", { params }),
  /** 获取未读数量 */
  unreadCount: () => get("/api/notification/unread-count"),
  /** 标记已读 */
  markAsRead: (id: string) => put("/api/notification/{id}/read", { pathParams: { id } }),
  /** 全部标记已读 */
  markAllAsRead: () => put("/api/notification/read-all"),
  /** 删除消息 */
  delete: (id: string) => del("/api/notification/{id}", { pathParams: { id } }),
  /** 批量删除 */
  batchDelete: (ids: string[]) => post("/api/notification/batch-delete", { body: { ids } })
};
```

### 阶段二：头部组件（NotificationBell + Drawer）

#### 2.1 创建NotificationBell组件

**操作**：创建铃铛触发器组件

**文件**：
- `src/components/NotificationBell/index.vue` — 新建

**功能**：
- 显示铃铛图标（使用Element Plus图标或自定义SVG）
- 使用 `el-badge` 显示未读数（超过99显示"99+"，0时不显示）
- 点击打开右侧抽屉

**布局位置**：
```
原布局：Logo(3) + 菜单(20) + 头像(1)
新布局：Logo(3) + 菜单(19) + 铃铛(1) + 头像(1)
```

#### 2.2 创建NotificationDrawer组件

**操作**：创建右侧抽屉组件

**文件**：
- `src/components/NotificationBell/NotificationDrawer/index.vue` — 新建

**功能**：
- 右侧弹出抽屉，宽度400px
- 顶部Tab切换：全部 / 系统 / 工作流 / OA / 站内信 / 待我审批
- 消息列表：显示标题、时间、类型标签、已读状态
- 每条消息可点击，标记已读并跳转对应页面
- 底部"全部已读"按钮和"查看全部消息"链接

**交互设计**：
```
┌─────────────────────────────────────┐
│ 消息通知                    [全部已读] │
├─────────────────────────────────────┤
│ [全部] [系统] [工作流] [OA] [站内信]  │
├─────────────────────────────────────┤
│ 📢 系统维护通知              10:30  │
│    内容预览...                已读  │
├─────────────────────────────────────┤
│ 👤 张三提交了请假审批        09:15  │
│    请审批张三的请假申请...    未读  │
├─────────────────────────────────────┤
│           [查看全部消息 →]           │
└─────────────────────────────────────┘
```

### 阶段三：集成到Navbar

#### 3.1 修改Navbar组件

**操作**：在头部导航栏集成NotificationBell组件

**文件**：
- `src/layouts/components/Navbar/index.vue` — 修改

**修改内容**：
1. 导入NotificationBell组件
2. 调整栅格布局：将菜单列从span=20改为span=19
3. 在菜单和头像之间添加铃铛列（span=1）
4. 添加路由跳转处理（点击"查看全部"时跳转到消息中心页面）

### 阶段四：完整消息中心页面

#### 4.1 创建消息中心页面主组件

**操作**：创建消息中心页面

**文件**：
- `src/views/Notification/index.vue` — 新建

**功能**：
- 页面标题：消息中心
- 顶部操作栏：全部已读按钮
- 搜索筛选区域
- 消息列表表格
- 分页组件

#### 4.2 创建搜索筛选组件

**操作**：创建搜索筛选区域

**文件**：
- `src/views/Notification/components/NotificationSearch/index.vue` — 新建

**功能**：
- 关键词搜索
- 消息类型下拉筛选
- 已读状态下拉筛选
- 时间范围选择
- 查询/重置按钮

#### 4.3 创建消息列表组件

**操作**：创建消息列表表格

**文件**：
- `src/views/Notification/components/NotificationList/index.vue` — 新建

**功能**：
- 表格展示：勾选框、类型、标题、内容预览、时间、状态、操作
- 支持多选批量操作
- 点击行可查看详情
- 操作列：标记已读/未读、删除

#### 4.4 创建消息详情弹窗

**操作**：创建消息详情弹窗

**文件**：
- `src/views/Notification/components/NotificationDetail/index.vue` — 新建

**功能**：
- 弹窗展示消息完整内容
- 显示发送者、时间、类型
- 提供跳转链接按钮

### 阶段五：数据库菜单配置

#### 5.1 插入菜单数据

**操作**：在数据库menu表中插入消息中心菜单项

**SQL**：
```sql
INSERT INTO sys_menu (id, parent_id, path, name, component, icon, sort, visible, status, metadata)
VALUES (
  'notification-menu-id',
  '0',  -- 顶级菜单
  '/notification',
  '消息中心',
  'Notification/index',
  'icon-notification',
  10,
  '0',  -- 显示
  '0',  -- 启用
  '{"title": "消息中心", "icon": "icon-notification"}'
);
```

**注意**：
- 需要根据实际表结构调整字段名
- 需要确认icon是否存在，如不存在需要先添加图标
- 菜单位置需要与产品确认

## 验证方案

### 1. 组件功能验证

- [ ] NotificationBell组件正确显示铃铛图标和未读数
- [ ] 点击铃铛正确打开右侧抽屉
- [ ] 抽屉中消息列表正确显示
- [ ] Tab切换正确筛选消息类型
- [ ] 点击消息正确标记已读并跳转
- [ ] "全部已读"按钮正确工作
- [ ] "查看全部消息"正确跳转到消息中心页面

### 2. 消息中心页面验证

- [ ] 页面正确加载（通过数据库菜单配置）
- [ ] 搜索筛选功能正常
- [ ] 批量选择和操作正常
- [ ] 分页功能正常
- [ ] 消息详情弹窗正常

### 3. 代码质量验证

```bash
pnpm run format      # 代码格式化
pnpm run lint:fix    # ESLint检查
pnpm run type-check  # 类型检查
```

### 4. 集成测试

- [ ] 启动开发服务器 `pnpm start`
- [ ] 登录系统，检查头部铃铛显示
- [ ] 点击铃铛，检查抽屉功能
- [ ] 导航到消息中心页面，检查完整功能

## 影响范围

### 新增文件（10个）

| 文件路径 | 说明 |
|---|---|
| `types/notification.d.ts` | 消息类型定义 |
| `src/plugin/store/modules/use-notification-store.ts` | 通知状态管理 |
| `src/api/notification/notification-api.ts` | 通知API模块 |
| `src/components/NotificationBell/index.vue` | 铃铛触发器组件 |
| `src/components/NotificationBell/NotificationDrawer/index.vue` | 抽屉组件 |
| `src/views/Notification/index.vue` | 消息中心页面 |
| `src/views/Notification/components/NotificationSearch/index.vue` | 搜索筛选组件 |
| `src/views/Notification/components/NotificationList/index.vue` | 消息列表组件 |
| `src/views/Notification/components/NotificationDetail/index.vue` | 消息详情弹窗 |

### 修改文件（1个）

| 文件路径 | 修改内容 |
|---|---|
| `src/layouts/components/Navbar/index.vue` | 集成NotificationBell组件，调整布局 |

### 数据库变更

| 表 | 操作 |
|---|---|
| `sys_menu` | 插入消息中心菜单项 |

## 相关

- [[20-前端/10-spectra-ui]] — 前端开发规范
- [[30-系统管理]] — 菜单管理
- [[00-项目总览]] — 系统架构
