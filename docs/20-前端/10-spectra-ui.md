---
tags:
  - frontend
  - web
---

# spectra-ui — Web 管理后台

> 基于 Vue 3 + Element Plus + Vite 8 的 Web 管理后台。路径：`spectra-ui/`。

## OA P0 页面

现有 `src/views/Dashboard/index.vue` 继续作为统一 OA 工作台，不新增 `/oa/workbench` 页面；通过 `GET /api/oa/workbench/summary` 接入待办、申请、公告、今日日程和会议摘要，快捷入口只保留真实存在的 OA 页面，不再展示模拟待办或无效路由。

`src/views/oa/Approval/index.vue`（`/oa/approval`）提供待办/已办、业务详情、同意和驳回；审批中心新增 `/oa/approval/finance/reimbursement`、`/oa/approval/asset/purchase` 和 `/oa/approval/hr/leave` 三个流程类型页面，统一通过 `process_definition_key` 过滤 Workflow 任务。`src/views/oa/Contact/index.vue` 提供基于 Core 用户/部门的真实组织通讯录。旧 `Attendance` 占位页面及路由已删除，请假产生的考勤影响通过请假详情和后端 `oa_attendance_record` 管理。`/oa/notice` 支持发布/撤回/已读，`/oa/calendar` 支持日程创建和删除，`/oa/meeting` 支持会议创建、邀请响应和签到。

## OA P1 页面

请假、费用报销和采购申请页统一使用 `OAApproverSelect` 选择审批人，支持草稿/驳回态编辑、提交、撤回和取消。费用报销页面为 `src/views/oa/Reimbursement/index.vue`，路由为 `/oa/reimbursement`，通过 `src/api/oa/reimbursement-api.ts` 对接报销明细、附件、审批和付款接口；凭证上传复用 `FileUpload`，上传响应中的 `file_id` 写入申请附件关联，收款账号回显使用脱敏值。

采购申请页面为 `src/views/oa/Purchase/index.vue`，路由为 `/oa/purchase`，通过 `src/api/oa/purchase-api.ts` 对接采购草稿、明细、审批、执行登记和分批收货接口，审批完成后可继续执行至 `RECEIVED`。

资产管理页面为 `src/views/OA/Asset/index.vue`，路由为 `/oa/asset`，通过 `src/api/oa/asset-api.ts` 对接资产台账、分类、采购收货转草稿及领用/归还/调拨/维修/报废操作。

办公用品库存页面为 `src/views/OA/Supply/index.vue`，路由为 `/oa/supply`，通过 `src/api/oa/supply-api.ts` 对接 SKU 台账、库存入库/领用/退库/调整和最低库存筛选。

## 技术栈

| 技术 | 版本 |
|---|---|
| Vue | 3.5.x |
| 构建工具 | Vite 8 |
| UI 框架 | Element Plus |
| 语言 | TypeScript |
| 状态管理 | Pinia |
| 路由 | Vue Router 5 |
| 包管理 | pnpm 11 |
| Node | 24.14.0 |

## 项目配置

| 文件 | 说明 |
|---|---|
| `vite.config.mts` | Vite 构建配置 |
| `tsconfig.json` | TypeScript 配置 |
| `eslint.config.ts` | ESLint 扁平配置 |
| `.prettierrc.yml` | Prettier 格式化配置 |
| `.env.example` | 已提交的环境变量模板（开发环境使用 Vite 同源代理） |
| `.env.development` | 从模板复制的本机开发配置，不提交 |
| `package.json` | 依赖与脚本 |

## 运行命令

```powershell
Copy-Item .env.example .env.development
pnpm install    # 安装依赖
pnpm start      # 启动开发服务器（:5173），自动执行 format+lint+type-check
```

## 系统设置引导

DEV_OPS 首次登录后，路由守卫调用 `GET /api/system/guide/status`；当后端返回 `required=true` 时强制进入 `/system-guide`，在完成前不加载业务菜单。引导页提交 `root_department_name`、`root_department_region_id`、`root_department_type`、`crypto_enabled`、`notification_enabled`、`copyright_enabled`、`copyright_name` 和 `copyright_url` 到 `POST /api/system/guide/complete`，其中根部门名称、区域和类型均为必填；启用版权时版权名称和 HTTP/HTTPS 跳转地址必填。后端在当前 DEV_OPS 用户上下文中创建根部门并建立主部门关系；接口加解密密钥以及通知模块所需的 AES 密钥由后端自动生成并保存到 `sys_config`，底部版权配置也保存到 `sys_config`。完成后刷新加解密配置并返回登录后的目标页面。

## 消息中心

消息中心通过静态认证路由 `/notification` 加载，不写入数据库菜单。`src/components/NotificationBell/` 在头部显示铃铛和未读数，点击后打开右侧抽屉，支持消息类型筛选、标记已读、全部已读和跳转完整消息中心；完整页面位于 `src/views/Notification/`，支持关键词/用途/已读状态筛选、分页、批量删除、详情查看和用途×渠道偏好设置。

`src/api/notification/notification-api.ts` 对接 `/api/notification/list`、详情、未读数、单条/全部已读、单条/批量删除以及 `/api/notification-center/preferences`。Self API 不接受 `userId`，查询、已读和偏好均由后端绑定当前用户；前端已覆盖 API/Store 状态同步、真实登录 Bearer Token、刷新 Token、登出、用户隔离和浏览器交互验收。

消息中心 V1 已完成；模板管理已通过 `/devops/notification/template` 和 `src/views/Devops/Notification/Template/` 接入真实模板 API，支持草稿编辑、预览、发布、停用、归档、复制草稿、版本历史、版本摘要展示和两个版本并列对比。保存、预览和发布前会校验声明变量、引用变量、非法占位符以及 HTML/URL 安全，发布确认会展示渠道、版本和变量影响摘要，后端规则仍是最终门禁。通知运行概览已通过 `/devops/notification/overview` 接入真实概览 API，支持窗口选择、自动刷新、渠道状态、队列/失败/UNKNOWN 指标、投递趋势和脱敏错误；Request 运维页已通过 `/devops/notification/request` 接入真实列表、详情和关联 Task 查询；Task 运维页已通过 `/devops/notification/delivery-task` 接入真实分页、任务详情、供应商投递记录和权限保护的重试/取消；Delivery 运维页已通过 `/devops/notification/delivery-record` 接入真实分页、渠道/状态/关联 ID 筛选、供应商回执和脱敏错误详情。渠道配置已通过 `/devops/notification/provider` 和 `src/views/Devops/Notification/Provider/` 接入真实 Provider 配置、健康检查和测试发送 API，支持 `IN_APP`、`SMS`、`EMAIL` 状态展示、非敏感参数配置、Secret 覆盖/清除、启停、健康门禁和 `SEND_TEST` 确认后的明确测试地址发送；Secret 和测试地址不回显，未配置或未健康时明确阻断。普通管理查询限制最近 31 天，精确 Request/Task 关联查询不受该窗口影响。受控发送、用途/渠道兼容矩阵、具体供应商回执和 SMS/EMAIL 失败/UNKNOWN 闭环由 [[90-计划/P-通知中心运维管理与外部渠道接入计划]] 继续承接，其他运维菜单中的 Placeholder 页面仍不能视为完成。

## 运维管理中心

运维路由集中在 `src/plugin/router/modules/devops.ts`，统一使用 `/devops` 路径、`Devops` 命名路由前缀和 `src/views/Devops/` 目录。数据库菜单只负责导航可见性，叶子路由通过 `meta.requiredMenu` 绑定；未接入真实接口的预定义能力统一指向占位页，不以模拟数据冒充正式功能。后端 `ROLE_DEV_OPS` 通过 `*` 权限和全部有效菜单契约获得运维入口，页面仍通过路由守卫和后端接口权限双重保护。

## 目录结构

```
spectra-ui/
├── src/
│   ├── api/              # API 请求封装（kebab-case）
│   │   ├── auth/         # 认证相关
│   │   ├── common/       # 通用接口
│   │   ├── oa/           # OA 模块
│   │   ├── system/       # 系统管理
│   │   │   ├── dict-api.ts
│   │   │   ├── crypto-api.ts
│   │   │   └── ...
│   │   ├── user/         # 用户模块
│   │   └── workflow/     # 工作流
│   ├── assets/           # 静态资源
│   ├── components/       # 公共组件（kebab-case）
│   │   ├── DictSelect/   # 组件目录（PascalCase）
│   │   │   └── index.vue # 组件主文件
│   │   ├── DictTag/
│   │   ├── FileUpload/
│   │   ├── IconPicker/
│   │   ├── JsonEditor/
│   │   ├── NotificationBell/
│   │   ├── PDFViewer/
│   │   └── StepNavigation/
│   ├── hooks/            # 组合式函数（kebab-case）
│   │   ├── use-table.ts
│   │   └── use-file-upload.ts
│   ├── layouts/          # 布局组件
│   ├── plugin/           # 核心插件（kebab-case）
│   │   ├── request/      # HTTP 客户端
│   │   │   ├── http.ts
│   │   │   ├── api.ts
│   │   │   └── auth.ts
│   │   ├── router/       # 路由配置
│   │   │   ├── index.ts
│   │   │   └── routes.ts
│   │   └── store/        # Pinia 状态管理
│   │       ├── index.ts
│   │       └── modules/
│   │           ├── use-app-store.ts
│   │           ├── use-user-store.ts
│   │           └── ...
│   ├── utils/            # 工具函数（kebab-case）
│   │   ├── crypto/       # 加解密工具
│   │   ├── message-utils.ts
│   │   ├── route-utils.ts
│   │   └── ...
│   ├── views/            # 页面组件（PascalCase）
│   │   ├── Common/       # 通用页面（404、401、Redirect）
│   │   ├── Dashboard/
│   │   ├── Login/
│   │   ├── OA/
│   │   ├── Devops/      # 运维管理（devops 路由前缀）
│   │   │   ├── Monitor/
│   │   │   ├── Notification/   # 通知运行概览、Request/Task/Delivery、模板管理、渠道配置等通知运维页面
│   │   │   ├── Placeholder/    # 尚未接入真实接口的预定义页面
│   │   │   ├── Scheduler/
│   │   │   ├── Security/
│   │   │   └── SystemMaintenance/
│   │   ├── System/       # 系统管理
│   │   │   ├── Dict/     # 字典管理
│   │   │   │   ├── index.vue
│   │   │   │   └── components/
│   │   │   │       ├── DictGroupEdit/
│   │   │   │       │   └── index.vue
│   │   │   │       └── DictDataEdit/
│   │   │   │           └── index.vue
│   │   │   ├── Menu/
│   │   │   ├── User/
│   │   │   ├── Workflow/
│   │   │   └── ...
│   │   └── Example/
│   ├── App.vue           # 根组件
│   └── main.ts           # 入口文件
├── public/               # 不经过编译的静态文件
├── tests/                # 测试文件（扁平结构）
│   ├── setup.ts
│   ├── DictSelect.test.ts
│   └── ...
└── types/                # 全局类型声明
    ├── http.d.ts
    ├── paging.d.ts
    └── ...
```

## Prettier 代码规范

- 缩进：4 空格
- 引号：双引号
- 分号：必须
- 行宽：120 字符
- 换行符：LF
- 尾逗号：无
- `arrowParens: avoid`
- `bracketSameLine: true`

## ESLint 规则

### 基础规则

| 规则 | 级别 | 说明 |
|---|---|---|
| `eqeqeq` | warn | 必须使用 `===` / `!==` |
| `no-empty` | error | 禁止空代码块 |
| `no-var` | error | 禁止使用 `var` |
| `prefer-const` | error | 优先使用 `const` |
| `no-debugger` | warn | 禁止留下 `debugger` |
| `use-isnan` | error | 必须使用 `isNaN()` 判断 NaN |
| `no-implicit-globals` | error | 禁止在全局作用域声明变量 |

### TypeScript 规则

| 规则 | 级别 | 说明 |
|---|---|---|
| `@typescript-eslint/no-unused-vars` | error | 禁止未使用的变量 |
| `@typescript-eslint/no-explicit-any` | error | 零容忍 `any` 类型 |
| `@typescript-eslint/no-empty-object-type` | error | 禁止空对象类型 `{}` |
| `@typescript-eslint/consistent-type-imports` | error | 使用 `import type`（内联：`import { type Foo }`） |

### Import 规则

| 规则 | 级别 | 说明 |
|---|---|---|
| `import/order` | error | 分组：builtin → external → internal → parent → sibling → index → type，组内字母排序，组间空行 |
| `import/no-cycle` | error | 禁止循环依赖 |
| `import/no-unresolved` | error | 检查 import 路径是否能解析 |
| `import/no-duplicates` | error | 禁止重复 import |
| `import/newline-after-import` | error | import 后必须空一行 |
| `import/first` | error | import 语句必须放在文件顶部 |
| `import/no-self-import` | error | 禁止导入自身文件 |

### 代码复杂度限制

| 规则 | 级别 | 配置 |
|---|---|---|
| `max-lines-per-function` | warn | 200 行 |
| `max-params` | warn | 4 个参数 |
| `no-nested-ternary` | warn | 禁止嵌套三元表达式 |

### Vue SFC 规则

| 规则 | 级别 | 说明 |
|---|---|---|
| `vue/block-order` | error | SFC 块顺序：`<script>` → `<template>` → `<style>` |
| `vue/block-tag-newline` | error | Vue block 标签前后必须换行 |
| `vue/no-unused-components` | error | 禁止注册但未使用的组件 |
| `vue/component-name-in-template-casing` | error | 模板中组件名必须使用 PascalCase |
| `vue/no-v-html` | warn | 不建议使用 `v-html`（XSS 风险） |
| `vue/multi-word-component-names` | off | views 目录下允许单词组件名 |

## 命名规范

### 核心原则

**所有组件必须使用目录 + index.vue 的结构**，为子组件预留扩展位置。

### 目录命名规则

| 位置 | 命名风格 | 示例 |
|---|---|---|
| `src/` 顶层目录 | kebab-case | `api/`、`components/`、`hooks/`、`utils/` |
| `src/views/` 一级目录 | PascalCase | `Dashboard/`、`System/`、`Login/` |
| `src/views/` 二级目录 | PascalCase | `System/Dict/`、`System/User/` |
| `src/api/` 子目录 | kebab-case | `system/`、`auth/`、`workflow/` |
| `src/plugin/` 子目录 | kebab-case | `store/`、`router/`、`request/` |

### 文件命名规则

| 位置 | 命名风格 | 示例 |
|---|---|---|
| Vue 组件 | `组件名/index.vue` | `components/DictSelect/index.vue` |
| API 模块 | kebab-case | `dict-api.ts`、`user-api.ts` |
| 工具函数 | kebab-case | `message-utils.ts`、`route-utils.ts` |
| 类型声明 | kebab-case | `http.d.ts`、`paging.d.ts` |
| Store 模块 | kebab-case | `use-user-store.ts`、`use-app-store.ts` |
| Hook | kebab-case | `use-table.ts`、`use-file-upload.ts` |

### 目录结构规范

#### 共享组件

```
src/components/{组件名}/
├── index.vue              # 组件主文件
├── SubComponent/          # 子组件（预留扩展）
│   └── index.vue
└── components/            # 更多子组件
    └── AnotherSub/
        └── index.vue
```

#### 页面组件

```
src/views/{模块}/{页面名}/
├── index.vue              # 页面主文件
└── components/            # 页面专属子组件目录
    ├── {子组件名}/
    │   └── index.vue
    └── {子组件名}/
        └── index.vue
```

## HTTP 客户端

项目使用自定义 `request()` 函数（`src/plugin/request/http.ts`），基于 `fetch` API，**不使用 Axios**。

### 核心特性

| 特性 | 说明 |
|---|---|
| Token 自动刷新 | 401 时自动刷新 Token 并重试原请求 |
| 请求去重 | 相同请求自动取消前一个进行中的重复请求 |
| 优先级队列 | `high`(10) / `normal`(6) / `low`(2) 并发限制 |
| 可选重试 | 通过 `retry: N` 指定重试次数 |
| Loading 自动管理 | 引用计数，多个并发请求只显示一个 Loading |
| 路径参数 | 模板字面量类型安全：`request("/api/users/{id}", { pathParams: { id } })` |
| 加密集成 | 自动加解密请求/响应体（AES-GCM + RSA） |

### API 辅助函数

`src/plugin/request/api.ts` 提供快捷方法：

```typescript
import { get, post, put, del } from "@/plugin/request/api";

// GET 请求
const data = await get("/api/users/{id}", {
    pathParams: { id: 123 },
    params: { fields: "name,email" }
});

// POST 请求
const result = await post("/api/users", { body: userData });

// PUT 请求
await put("/api/users/{id}", { pathParams: { id }, body: updateData });

// DELETE 请求
await del("/api/users/{id}", { pathParams: { id } });
```

### 文件上传与下载

**上传和下载需要使用 XHR（XMLHttpRequest）实现**，因为 `fetch` API 不支持上传/下载进度监听。

```typescript
// 上传文件（带进度监听）
export function uploadWithProgress(
    url: string,
    file: File,
    onProgress?: (percent: number) => void
): Promise<unknown> {
    return new Promise((resolve, reject) => {
        const xhr = new XMLHttpRequest();
        xhr.open("POST", url);

        xhr.upload.onprogress = (e) => {
            if (e.lengthComputable && onProgress) {
                onProgress(Math.round((e.loaded / e.total) * 100));
            }
        };

        xhr.onload = () => {
            if (xhr.status === 200) {
                resolve(JSON.parse(xhr.responseText));
            } else {
                reject(new Error(`上传失败: ${xhr.status}`));
            }
        };

        xhr.onerror = () => reject(new Error("网络错误"));

        const formData = new FormData();
        formData.append("file", file);
        xhr.send(formData);
    });
}

// 下载文件（带进度监听）
export function downloadWithProgress(
    url: string,
    filename: string,
    onProgress?: (percent: number) => void
): Promise<void> {
    return new Promise((resolve, reject) => {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", url);
        xhr.responseType = "blob";

        xhr.onprogress = (e) => {
            if (e.lengthComputable && onProgress) {
                onProgress(Math.round((e.loaded / e.total) * 100));
            }
        };

        xhr.onload = () => {
            if (xhr.status === 200) {
                const blob = xhr.response;
                const a = document.createElement("a");
                a.href = URL.createObjectURL(blob);
                a.download = filename;
                a.click();
                URL.revokeObjectURL(a.href);
                resolve();
            } else {
                reject(new Error(`下载失败: ${xhr.status}`));
            }
        };

        xhr.onerror = () => reject(new Error("网络错误"));
        xhr.send();
    });
}
```

### RequestOptions 类型

```typescript
interface RequestOptions<T extends string> {
    body?: unknown;           // 请求体
    params?: Record<string, unknown>;  // URL 查询参数
    loading?: boolean;        // 是否显示 Loading
    retry?: number;           // 重试次数
    dedupe?: boolean;         // 是否启用请求去重
    priority?: HttpPriority;  // 并发优先级
    pathParams?: PathParams<T>;  // 路径参数（类型安全）
    headers?: Record<string, string>;  // 自定义请求头
}
```

## 全局类型定义

项目在 `types/` 目录下定义全局类型，通过 `tsconfig.app.json` 的 `types` 字段自动引入。

### HTTP 相关类型

```typescript
// types/http.d.ts

// 响应体结构
type IResult<T = unknown> = {
    code: number;    // 状态码
    msg: string;     // 消息
    data?: T;        // 响应内容
};

// 基础实体（所有业务实体继承）
type BaseEntity = {
    id: string;
    created_by?: string;
    created_at?: string;
    updated_by?: string;
    updated_at?: string;
};

// 请求优先级
type HttpPriority = "high" | "normal" | "low";

// 请求选项（泛型 T 用于路径参数类型推断）
interface RequestOptions<T extends string> {
    params?: Record<string, unknown>;
    loading?: boolean;
    retry?: number;
    dedupe?: boolean;
    priority?: HttpPriority;
    fetchPriority?: RequestPriority;
    pathParams?: PathParams<T>;
    headers?: Record<string, string>;
    _retry?: boolean;
}

// 路径参数提取（类型安全）
type ExtractPathParams<T extends string> = T extends `${string}{${infer Param}}${infer Rest}`
    ? Param | ExtractPathParams<Rest>
    : never;

type PathParams<T extends string> =
    ExtractPathParams<T> extends never ? undefined : Record<ExtractPathParams<T>, string | number>;
```

### 分页相关类型

```typescript
// types/paging.d.ts

// 分页响应实体
type Page<T = never> = {
    current: number;
    records: T[];
    size: number;
    total: number;
    pages: number;
};

// 分页参数实体
type Pagination = {
    size: number;
    page: number;
    page_sizes: Array<number>;
    default_page_size: number;
    total: number;
};

// 基础分页请求参数
type BasePageParams = {
    page_size: number;
    page_num: number;
    orders?: OrderItem[];
};

// 排序字段
type OrderItem = {
    column: string;
    asc: boolean;
};
```

## Pinia Store 规范

项目使用 Pinia + `pinia-plugin-persistedstate` 进行状态管理。

### 目录结构

```
src/plugin/store/
├── index.ts              # Pinia 初始化（注入 persistedstate 插件）
└── modules/              # Store 模块
    ├── use-app-store.ts      # 应用状态
    ├── use-crypto-store.ts   # 加解密状态
    ├── use-dict-store.ts     # 字典缓存
    ├── use-props-store.ts    # 全局属性
    └── use-user-store.ts     # 用户状态
```

### 命名规范

- 文件名：`use-{模块名}-store.ts`（kebab-case）
- 导出函数：`use{模块名}Store`（PascalCase）
- Store ID：与模块名一致（如 `"user"`、`"app"`）

### 编写模式

```typescript
// src/plugin/store/modules/use-xxx-store.ts
import { defineStore } from "pinia";

export const useXxxStore = defineStore("xxx", {
    state: (): XxxState => ({
        // 初始状态
    }),
    getters: {
        // 计算属性
    },
    actions: {
        // 方法
    },
    // 可选：启用持久化
    persist: true
});
```

## Hook/Composable 规范

项目在 `src/hooks/` 目录下存放可复用的组合式函数。

### 命名规范

- 文件名：`use-{功能名}.ts`（kebab-case）
- 导出函数：`use{功能名}`（PascalCase）

### useTable 示例

```typescript
// src/hooks/use-table.ts
import { onMounted, ref } from "vue";

export function useTable<T>(
    request: (params?: BasePageParams) => Promise<Page<T>>,
    parameters: BasePageParams
) {
    const pagination = ref<Pagination>({
        size: 10,
        page: 1,
        page_sizes: [10, 15, 50, 100, 150, 300],
        default_page_size: 10,
        total: 0
    });

    const table_data = ref<T[]>([]);

    onMounted(() => {
        pagination.value.page = parameters.page_num;
        pagination.value.size = parameters.page_size;
        handleCurrentChange(pagination.value.page);
    });

    async function handleCurrentChange(value: number) {
        parameters.page_num = value;
        parameters.page_size = pagination.value.size;
        const result = await request(parameters);
        handleRequestResult(result);
    }

    async function handleSizeChange(value: number) {
        parameters.page_num = pagination.value.page;
        parameters.page_size = value;
        const result = await request(parameters);
        handleRequestResult(result);
    }

    async function handlerConditionQuery() {
        parameters.page_num = pagination.value.page;
        parameters.page_size = pagination.value.size;
        const result = await request(parameters);
        handleRequestResult(result);
    }

    function handleRequestResult(response: Page<T>) {
        table_data.value = response.records ?? [];
        pagination.value.total = response.total ?? 0;
    }

    return {
        table_data,
        pagination,
        handleCurrentChange,
        handleSizeChange,
        handlerConditionQuery
    };
}
```

## 组件规范

### SFC 块顺序

Vue SFC 必须按以下顺序组织：

```vue
<script setup lang="ts">
// 1. 脚本在最前
</script>

<template>
    <!-- 2. 模板居中 -->
</template>

<style scoped>
/* 3. 样式在最后 */
</style>
```

### Props 定义（类型声明 + withDefaults）

使用 Vue 3.5+ 推荐的类型声明方式，通过 `withDefaults` 设置默认值：

```typescript
interface Props {
    /** 标题（必填） */
    title: string;
    /** 计数器（可选，默认值 0） */
    count?: number;
    /** 数据列表（可选，默认值空数组） */
    items?: string[];
    /** 状态（可选，默认值 'idle'） */
    status?: "idle" | "loading" | "success" | "error";
}

const props = withDefaults(defineProps<Props>(), {
    count: 0,
    items: () => [],
    status: "idle"
});
```

**Props 详细说明：**

| 语法 | 说明 |
|---|---|
| `title: string` | 必填项，父组件必须传递 |
| `count?: number` | 可选项 |
| `default: 0` | 设置默认值 |
| `default: () => []` | 引用类型必须使用工厂函数返回默认值 |
| `/** 注释 */` | 使用 JSDoc 注释说明属性用途 |

### Emits 定义（类型声明）

使用 Vue 3.5+ 的类型声明方式：

```typescript
const emit = defineEmits<{
    /** 值变化时触发 */
    change: [value: string];
    /** 更新 v-model 时触发 */
    "update:modelValue": [value: string];
}>();
```

### v-model 定义（defineModel）

使用 Vue 3.5+ 的 `defineModel`：

```typescript
// 简单双向绑定
const model = defineModel<string>({ required: true });

// 带默认值的双向绑定
const model = defineModel<string>({ default: "" });

// 多个 v-model
const modelValue = defineModel<string>("value", { required: true });
const visible = defineModel<boolean>("visible", { default: false });
```

### 组件定义完整示例

```vue
<script setup lang="ts">
import { ref } from "vue";

defineOptions({
    name: "MyComponent"
});

interface Props {
    /** 标题（必填） */
    title: string;
    /** 计数器（可选，默认值 0） */
    count?: number;
    /** 数据列表（可选，默认值空数组） */
    items?: string[];
}

const props = withDefaults(defineProps<Props>(), {
    count: 0,
    items: () => []
});

const emit = defineEmits<{
    /** 值变化时触发 */
    change: [value: string];
}>();

const model = defineModel<string>({ required: true });

const internalState = ref<string>("");
</script>

<template>
    <div class="my-component">
        <h3>{{ title }}</h3>
        <p>Count: {{ count }}</p>
        <ul>
            <li v-for="(item, index) in items" :key="index">{{ item }}</li>
        </ul>
        <input v-model="model" />
        <button @click="emit('change', internalState)">触发</button>
    </div>
</template>

<style scoped>
.my-component {
    padding: 16px;
}
</style>
```

## 测试规范

项目使用 Vitest + @vue/test-utils + happy-dom 进行测试。

### 配置

```typescript
// vite.config.mts 中的 test 配置
test: {
    environment: "happy-dom",
    silent: false,
    reporters: "default",
    include: ["tests/**/*.{test,spec}.{js,mjs,cjs,ts,mts,cts,jsx,tsx}"],
    globals: true,
    setupFiles: "./tests/setup.ts",
    alias: {
        "@": srcPath
    },
    coverage: {
        provider: "v8",
        reporter: ["text", "json", "html"]
    }
}
```

### 目录结构

```
tests/
├── setup.ts                 # 全局 setup（stub 全局组件等）
├── DictSelect.test.ts       # 字典选择器测试
├── DictTag.test.ts          # 字典标签测试
├── Icons.test.ts            # 图标测试
└── crypto-utils.test.ts     # 加解密工具测试
```

### 命名规范

- 测试文件：`{功能名}.test.ts`（扁平结构，无子目录）
- 测试描述：`describe("组件名/功能名", () => {...})`
- 测试用例：`it("应该...", () => {...})` 或 `it("should ...", () => {...})`

### 编写模式

```typescript
import { createTestingPinia } from "@pinia/testing";
import { mount } from "@vue/test-utils";
import { describe, expect, it, vi } from "vitest";

import MyComponent from "../src/components/MyComponent/index.vue";

// Mock 外部依赖（文件顶部，vitest 自动 hoist）
vi.mock("@/api/some-api", () => ({
    someApi: {
        getData: vi.fn().mockResolvedValue({ code: 200, data: [] })
    }
}));

describe("MyComponent 组件", () => {
    it("应该正确渲染标题", () => {
        const wrapper = mount(MyComponent, {
            props: {
                title: "测试标题"
            }
        });

        expect(wrapper.find("h3").text()).toBe("测试标题");
    });

    it("应该触发 change 事件", async () => {
        const wrapper = mount(MyComponent, {
            props: {
                title: "测试"
            }
        });

        await wrapper.find("button").trigger("click");

        expect(wrapper.emitted("change")).toBeTruthy();
    });
});
```

### Mock Store

```typescript
import { createTestingPinia } from "@pinia/testing";

const wrapper = mount(MyComponent, {
    global: {
        plugins: [
            createTestingPinia({
                stubActions: false  // 不拦截 actions
            })
        ]
    }
});
```

### 运行测试

```bash
# 单次运行
pnpm run test

# 监听模式
pnpm run test:watch

# 运行单个测试文件
pnpm run test -- DictSelect
```

## 路由规范

项目使用 Vue Router 5，采用 Hash 模式。

### 配置文件

```
src/plugin/router/
├── index.ts    # 路由实例、守卫配置
└── routes.ts   # 通用路由定义
```

### 路由模式

```typescript
const router = createRouter({
    history: createWebHashHistory(),
    routes,
    scrollBehavior() {
        return { top: 0 };
    }
});
```

### 路由定义格式

```typescript
import { type RouteRecordRaw } from "vue-router";

export default [
    {
        path: "/login",
        name: "login",
        component: () => import("@/views/Login/index.vue"),
        meta: {
            title: "登录"
        }
    }
] as Array<RouteRecordRaw>;
```

### 静态路由与授权菜单

- 页面路由在 `src/plugin/router/modules/` 中按 `common/system/devops/oa/example` 静态定义，由 `routes.ts` 聚合。
- 登录后调用 `GET /menu/current` 获取当前用户授权导航树，不再根据数据库组件路径动态注册路由。
- `MenuApi` 在 API 边界将后端 `menu_type/route_name` 递归归一化为前端 `menuType/routeName`，内部菜单工具统一使用 camelCase。
- 可见页面通过 `meta.requiredMenu` 绑定数据库 `routeName`；详情和编辑页用 `activeMenu` 继承所属菜单权限和高亮。
- 用户管理的新增和编辑使用完整页面路由 `/system/user/create`、`/system/user/:id/edit`，不使用抽屉；编辑页通过用户详情接口独立加载数据，刷新或直接访问地址仍可正常回显。页面按“基本信息 → 授权方案 → 角色授权”步骤展示：第 02 步加载已有角色并负责角色的移除、新增和快速套用多角色授权方案，重复角色会提示并跳过；第 03 步在左侧按 `3.1`、`3.2` 等子节点切换角色，并在内容区分别配置访问范围，不能在第 03 步增删角色，至少保留一个角色；每一步只在页面内暂存，最后通过 `POST/PUT /api/user/onboarding` 一次性提交用户资料、多角色授权和撤销列表；后端事务失败时不会留下半成品用户。
- 用户管理的“重置密码”使用一次性临时密码弹窗展示接口响应，支持复制并显示 24 小时有效期；关闭弹窗后不再保留明文，遗失时重新执行重置。使用临时密码登录的用户会被引导到修改密码页。
- 用户批量导入使用完整页面路由 `/system/user/import`，挂在用户管理菜单下；页面采用与用户编辑一致的左侧编号步骤、中间滚动内容、右侧提示和底部固定操作栏，支持下载只包含真实姓名、手机号码和邮箱的中文 Excel 模板、CSV/TXT/Excel 上传、选择文件后自动解析、行编辑、在数据预览上方统一选择部门/语言/时区/授权方案、后端 Preview、Apply、错误分类筛选、带中文表头的错误明细下载和结果查看。工号由后端在 Preview 阶段自动生成，任务有效期按 `yyyy-MM-dd HH:mm:ss` 展示，固定配置会在 Preview 提交时合并到每一行，不再要求管理员在 Excel 中重复填写。Apply 返回后台任务后，页面轮询任务详情展示已处理行数和进度，完成后加载错误明细；API 封装位于 `src/api/user/user-import-api.ts`，文件解析与摘要工具位于 `src/utils/user-import.ts`。
- 授权方案列表使用 `/system/authorization-profiles` 页面，采用系统管理页的查询区/数据区布局；新建和编辑分别使用 `/system/authorization-profiles/create`、`/system/authorization-profiles/:id/edit` 独立页面，不再使用弹窗。方案编辑采用“基本信息 → 选择角色 → 权限范围设置”三步流程，角色支持多选并为每个角色生成独立 Assignment，权限选择支持多选后一次性加入，已加入的权限支持勾选后批量应用访问组织、子部门和授权范围，最后一步统一提交；批量设置遵循所选 Permission 的共同 `allowed_scope_modes`，右侧提供“全选权限”“清空选择”“选中按组织规则”“选中按仅当前主体数据”快捷操作，避免把 `RULES` 与 `SELF` 权限混在一起配置；仅支持 `NONE` 的权限不会显示组织选择。用户授权步骤可以套用单角色方案作为初始值，最终仍走当前用户对应的 Preview/Apply；授权方案支持启用、停用和删除，停用或删除不会撤销已经生效的运行时授权实例。
- 一级授权节点显示在顶部导航，后代由递归 `MenuItem` 显示在侧栏，支持任意层级。
- 未授权的已定义路由进入 `/401`，未定义地址由 catch-all 路由进入 `/404`。

### 路由守卫逻辑

1. **白名单**（如 `/login`）直接放行
2. **无 token** 跳转登录页
3. **有 token 但访问登录页** 重定向到主页
4. **菜单未加载** 验证 token 并加载当前用户授权树
5. **菜单权限不足** 以 replace 方式跳转 401
6. **路由未匹配** 由 catch-all 路由跳转 404

### 页面组件组织

```
src/views/
├── Login/                  # 登录页
├── Dashboard/              # 仪表盘
├── Common/                 # 通用页面
│   ├── 404/
│   ├── 401/
│   └── Redirect/
├── OA/                     # OA 办公
├── Devops/                 # 运维管理（/devops，Devops* 命名路由）
│   ├── Monitor/             # 服务监控、缓存监控
│   ├── Notification/        # 通知运行概览、Request/Task/Delivery、模板管理
│   ├── Placeholder/         # 应用健康、调度、安全等预定义占位页
│   ├── Scheduler/           # 定时任务
│   ├── Security/            # 安全上下文、安全审计、在线用户
│   └── SystemMaintenance/   # 系统配置、文件管理
├── System/                 # 系统管理
│   ├── Dept/
│   ├── Dict/
│   │   ├── index.vue
│   │   └── components/
│   │       ├── DictGroupEdit/
│   │       └── DictDataEdit/
│   ├── Menu/
│   ├── RBAC/
│   ├── AuthorizationProfile/
│   │   ├── index.vue
│   │   └── components/AuthorizationProfileEdit/
│   ├── Region/
│   ├── User/
│   └── Workflow/
│       ├── index.vue
│       └── components/
│           ├── FormDesigner/
│           ├── FormList/
│           ├── FormPreview/
│           ├── pickers/          # 流程设计器选择弹框（Form/User/Group/JavaClass/Process）
│           ├── WorkflowDesigner/
│           └── WorkflowList/
└── Example/                # 示例页
```

### 服务监控总览

`DevopsMonitorServer` 使用 `ServiceMonitorApi.getOverview()` 和 `ServiceMonitorApi.getHistory()` 接入 `/api/service/monitor/overview`、`/api/service/monitor/history`，页面只消费后端真实采样数据，不生成模拟指标。总览包含服务状态、监控数据新鲜度、CPU/系统内存/JVM 堆使用率、请求速率、错误率、响应时间 P95、线程/GC、PostgreSQL/Redis 依赖状态、应用健康组件以及 30 分钟/6 小时/24 小时趋势。

页面支持 5、10、30 秒自动刷新和手动刷新；首次加载失败显示错误状态，已有数据时刷新失败保留上一份数据。后端未提供 HTTP 请求指标时，QPS、错误率、P95 和请求趋势显示“暂无请求指标”，不以 0 误导使用者。

第三阶段在同一页面增加“告警”和“运行时诊断”页签：告警页查询摘要、活动事件和规则配置，规则更新使用后端版本号；诊断页展示内存池、GC、线程状态、连接池、Redis 延迟和慢接口，并通过异步任务轮询线程/堆转储状态，只允许下载成功且未过期的文件。刷新和诊断请求均使用局部 loading，不阻塞总览自动刷新。

## Commit 规范

项目提交信息遵循 Conventional Commits 约定。为兼容 Windows 开发环境，`spectra-ui` 和 `spectra-app` 不再配置 Husky、lint-staged 或 commitlint 提交钩子，提交时按以下格式人工遵循。

### 提交格式

```
<type>(<scope>): <subject>

<body>

<footer>
```

### 类型说明

| 类型 | 说明 |
|---|---|
| `feat` | 新功能 |
| `fix` | 修复 bug |
| `docs` | 文档变更 |
| `style` | 代码格式（不影响功能） |
| `refactor` | 重构（不新增功能/修复 bug） |
| `perf` | 性能优化 |
| `test` | 测试相关 |
| `chore` | 构建/工具/依赖变更 |
| `ci` | CI 配置变更 |

### Scope 说明

| Scope | 说明 |
|---|---|
| `ui` | spectra-ui 项目 |
| `app` | spectra-app 项目 |
| `admin` | spectra-admin 后端 |

### 提交信息建议

| 约束项 | 建议 |
|---|---|
| `header-max-length` | 120 字符 |
| `body-max-line-length` | 200 字符 |
| `footer-max-line-length` | 200 字符 |
| `subject-case` | 不限制大小写 |

### 示例

```bash
feat(ui): 新增用户管理页面
fix(admin): 修复登录接口返回格式问题
docs: 更新 README 安装说明
refactor(ui): 重构 HTTP 客户端
```

## 第三方依赖

### 本地插件

- **@yangxj96/logicflow-plugin-flowable** — BPMN 2.0 流程建模插件
  - 引用方式：`file:../logicflow-plugin-flowable`（本地开发），`vite.config.mts` 中配置 alias 指向插件 `src/` 源码（HMR 直连）
  - 版本：0.1.0
  - 用途：工作流流程设计、BPMN XML 导入/导出
  - 文档：[[30-流程建模插件]]

### 使用方式

```vue
<script setup>
import LogicFlow from '@logicflow/core';
import Flowable from '@yangxj96/logicflow-plugin-flowable';

const lf = new LogicFlow({
    container: graphEl,
    plugins: [Flowable.Plugin],
    pluginsOptions: {
        flowable: {
            panel: {
                dnd: dndPanelEl,
                property: propertyPanelEl
            },
            // 声明已实现的选择器，未列出的字段降级为手动输入
            pickers: ['form', 'user', 'group', 'javaClass', 'process']
        }
    }
});

// 监听选择器事件，按类型弹出对应弹框，选择后 resolve 回填
lf.on('property:picker', payload => {
    // payload.pickerType / payload.multiple / payload.resolve(value, label)
});

// 导出 BPMN XML
const xml = Flowable.toBpmnXml(lf);

// 导入 BPMN XML
const result = Flowable.fromBpmnXml(xmlString, lf);
</script>
```

## 与后端连接

### 首次系统初始化

Web 管理端提供 `/initialization` 首次初始化页面，用于设置系统名称、简称、Logo 标识、默认语言、默认时区和安全策略，创建 DEV_OPS 用户、绑定 TOTP MFA、保存 Recovery Code 并完成初始化。系统名称会作为新 MFA 登记的 TOTP issuer。应用启动阶段先调用 `/api/system/bootstrap`，一次获取系统公开信息、加解密配置和初始化状态，并写入应用 store；只有启动聚合接口失败时，登录页或初始化页才回退调用 `/api/system/initialization/status`。初始化完成后页面返回登录页，由用户通过正常登录流程建立会话；登录页会在后端返回 `UNINITIALIZED` 时自动跳转到初始化页面。初始化流程不属于 `spectra-app` 移动端范围。应用首次启动时会把初始化令牌输出到受控的后端控制台，启动请求使用用户手工输入的 `X-Spectra-Initialization-Token`，令牌只保存在当前页面内存中。

仓库只提交 `.env.example`。新克隆先复制为 `.env.development`；开发环境的 `VITE_API_URL=https://127.0.0.1:4004/` 直接连接后端 4004。Vite 通过 `SSL_PASSWORD` 加载后端同一份 `files/ssl/keystore.p12`，因此 Web 使用 `https://localhost:5173` 访问，浏览器才能正常携带 Secure Cookie 和读取 CSRF Cookie。修改后端端口或连接远程后端时，只修改本机环境文件。

> **环境变量命名约定**：spectra-ui 使用 `VITE_API_URL`（带尾部 `/`），spectra-app 使用 `VITE_API_BASE_URL`（无尾部 `/`）。这是两个项目的既定约定，不强制统一（Vite SPA 和 uni-app 的 base URL 处理逻辑不同）。

## 关键文件路径

| 文件 | 路径 |
|---|---|
| Vite 配置 | `spectra-ui/vite.config.mts` |
| ESLint 配置 | `spectra-ui/eslint.config.ts` |
| Prettier 配置 | `spectra-ui/.prettierrc.yml` |
| 环境变量 | `spectra-ui/.env.development` |
| 环境变量模板 | `spectra-ui/.env.example` |
| AGENTS.md | `spectra-ui/AGENTS.md` |
| HTTP 客户端 | `spectra-ui/src/plugin/request/http.ts` |
| API 辅助函数 | `spectra-ui/src/plugin/request/api.ts` |
| 加密工具 | `spectra-ui/src/utils/crypto/crypto-utils.ts` |
| 加解密 store | `spectra-ui/src/plugin/store/modules/use-crypto-store.ts` |
| 加解密 API | `spectra-ui/src/api/system/crypto-api.ts` |
| 全局类型 | `spectra-ui/types/http.d.ts` |
| 分页类型 | `spectra-ui/types/paging.d.ts` |
| 工作流 API | `spectra-ui/src/api/workflow/workflow-api.ts` |
| 静态路由模块 | `spectra-ui/src/plugin/router/modules/` |
| 菜单树工具 | `spectra-ui/src/utils/menu-utils.ts` |
| 递归侧栏菜单 | `spectra-ui/src/layouts/Default/components/Sidebar/MenuItem/index.vue` |
| 表单 API | `spectra-ui/src/api/workflow/form-api.ts` |
| 工作流页面 | `spectra-ui/src/views/System/Workflow/index.vue` |
| 表单列表 | `spectra-ui/src/views/System/Workflow/components/FormList/index.vue` |
| 表单设计器 | `spectra-ui/src/views/System/Workflow/components/FormDesigner/index.vue` |
| 表单预览 | `spectra-ui/src/views/System/Workflow/components/FormPreview/index.vue` |
| 流程列表 | `spectra-ui/src/views/System/Workflow/components/WorkflowList/index.vue` |
| 流程设计器 | `spectra-ui/src/views/System/Workflow/components/WorkflowDesigner/index.vue` |
| 选择弹框目录 | `spectra-ui/src/views/System/Workflow/components/pickers/` |

## 加解密说明

密钥通过后端 API 动态获取，不再硬编码在 `.env` 中：

- 应用启动：`initBootstrap()` → `GET /api/system/bootstrap` → 获取系统公开信息、初始化状态以及 `enabled` + `serverPublicKey`
- 密钥管理页刷新：`initCrypto()` → `GET /api/system/crypto/config` → 仅刷新 `enabled` + `serverPublicKey`
- 登录成功：`fetchClientPrivateKey()` → `GET /api/system/crypto/keypair/client-private` → 获取 `clientPrivateKey`
- 系统信息和初始化状态存储在 `use-app-store`；加解密状态存储在 `use-crypto-store`，`enabled` + `serverPublicKey` 持久化，`clientPrivateKey` 仅内存

> ⚠️ **技术债务**：`utils/crypto/` 下的 `aes-utils.ts`、`rsa-utils.ts`、`crypto-utils.ts` 与 spectra-app 中完全重复。未来应抽取为共享包 `@spectra/crypto`。

## 相关笔记

- [[00-项目总览]]
- [[20-spectra-app]]
- [[30-流程建模插件]]
- [[10-环境搭建]]
- [[20-常见命令]]
- [[85-接口加解密方案]]
