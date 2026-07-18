---
tags:
  - frontend
  - web
---

# spectra-ui — Web 管理后台

> 基于 Vue 3 + Element Plus + Vite 8 的 Web 管理后台。路径：`spectra-ui/`。

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
| `.env.development` | 开发环境变量（`VITE_API_URL=https://127.0.0.1:4004/`） |
| `package.json` | 依赖与脚本 |

## 运行命令

```bash
pnpm install    # 安装依赖
pnpm start      # 启动开发服务器（:5173），自动执行 format+lint+typecheck
```

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
│   │   └── PDFViewer/
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
│   │   ├── Monitor/
│   │   ├── OA/
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

### 动态菜单路由

业务菜单由后端接口动态加载（`@/utils/route-utils.ts`），不手动配置在 `routes.ts` 中。

### 路由守卫逻辑

1. **白名单**（如 `/login`）直接放行
2. **无 token** 跳转登录页
3. **有 token 但访问登录页** 重定向到主页
4. **菜单未加载** 验证 token 并加载菜单
5. **路由未匹配** 跳转 404

### 页面组件组织

```
src/views/
├── Login/                  # 登录页
├── Dashboard/              # 仪表盘
├── Common/                 # 通用页面
│   ├── 404/
│   ├── 401/
│   └── Redirect/
├── Monitor/                # 监控模块
├── OA/                     # OA 办公
├── System/                 # 系统管理
│   ├── Configured/
│   ├── Dept/
│   ├── Dict/
│   │   ├── index.vue
│   │   └── components/
│   │       ├── DictGroupEdit/
│   │       └── DictDataEdit/
│   ├── Menu/
│   ├── RBAC/
│   ├── Region/
│   ├── Storage/
│   ├── User/
│   └── Workflow/
│       ├── index.vue
│       └── components/
│           ├── FormDesigner/
│           ├── FormList/
│           ├── FormPreview/
│           ├── WorkflowDesigner/
│           └── WorkflowList/
└── Example/                # 示例页
```

## Commit 规范

项目使用 Conventional Commits + commitlint 进行提交信息规范。

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

### commitlint 规则

| 规则 | 配置 |
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
  - 引用方式：`file:../logicflow-plugin-flowable`（本地开发）
  - 版本：0.0.5
  - 用途：工作流流程设计、BPMN XML 导入/导出
  - 文档：[[30-流程建模插件]]

### 使用方式

```vue
<script setup>
import LogicFlow from '@logicflow/core';
import Flowable from '@yangxj96/logicflow-plugin-flowable';

const lf = new LogicFlow({ container: graphEl });
lf.use(Flowable.Plugin, {
    panel: {
        dnd: dndPanelEl,
        property: propertyPanelEl
    }
});

// 导出 BPMN XML
const xml = Flowable.toBpmnXml(lf);

// 导入 BPMN XML
const result = Flowable.fromBpmnXml(xmlString, lf);
</script>
```

## 与后端连接

开发环境通过 `.env.development` 中的 `VITE_API_URL` 指向 `spectra-admin` 的 `https://127.0.0.1:4004/`。

## 关键文件路径

| 文件 | 路径 |
|---|---|
| Vite 配置 | `spectra-ui/vite.config.mts` |
| ESLint 配置 | `spectra-ui/eslint.config.ts` |
| Prettier 配置 | `spectra-ui/.prettierrc.yml` |
| 环境变量 | `spectra-ui/.env.development` |
| AGENTS.md | `spectra-ui/AGENTS.md` |
| HTTP 客户端 | `spectra-ui/src/plugin/request/http.ts` |
| API 辅助函数 | `spectra-ui/src/plugin/request/api.ts` |
| 加密工具 | `spectra-ui/src/utils/crypto/crypto-utils.ts` |
| 加解密 store | `spectra-ui/src/plugin/store/modules/use-crypto-store.ts` |
| 加解密 API | `spectra-ui/src/api/system/crypto-api.ts` |
| 全局类型 | `spectra-ui/types/http.d.ts` |
| 分页类型 | `spectra-ui/types/paging.d.ts` |
| 工作流 API | `spectra-ui/src/api/workflow/workflow-api.ts` |
| 表单 API | `spectra-ui/src/api/workflow/form-api.ts` |
| 工作流页面 | `spectra-ui/src/views/System/Workflow/index.vue` |
| 表单列表 | `spectra-ui/src/views/System/Workflow/components/FormList/index.vue` |
| 表单设计器 | `spectra-ui/src/views/System/Workflow/components/FormDesigner/index.vue` |
| 表单预览 | `spectra-ui/src/views/System/Workflow/components/FormPreview/index.vue` |
| 流程列表 | `spectra-ui/src/views/System/Workflow/components/WorkflowList/index.vue` |
| 流程设计器 | `spectra-ui/src/views/System/Workflow/components/WorkflowDesigner/index.vue` |

## 加解密说明

密钥通过后端 API 动态获取，不再硬编码在 `.env` 中：

- 应用启动：`initCrypto()` → `GET /api/system/crypto/config` → 获取 `enabled` + `serverPublicKey`
- 登录成功：`fetchClientPrivateKey()` → `GET /api/system/keypair/client-private` → 获取 `clientPrivateKey`
- 状态存储在 `use-crypto-store`，`enabled` + `serverPublicKey` 持久化，`clientPrivateKey` 仅内存

## 相关笔记

- [[00-项目总览]]
- [[20-spectra-app]]
- [[30-流程建模插件]]
- [[10-环境搭建]]
- [[20-常见命令]]
- [[85-接口加解密方案]]
