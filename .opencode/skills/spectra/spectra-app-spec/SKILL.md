---
name: spectra-app-spec
description: 当修改、调整或创建spectra-app前端Vue/TS代码时自动加载。包含页面、组件、API、Store、Hook、条件编译、平台抽象等核心规范。
version: "1.0.0"
license: MIT
metadata:
  hermes:
    tags: [frontend, conventions, vue, typescript, uni-app, mobile, spectra]
---

# spectra-app 前端开发规范

## 概述

spectra-app 是基于 Vue 3 + uni-app + TypeScript + Vite 5 + TDesign 的跨平台移动端应用，所有代码必须遵循统一的规范。

**核心原则：** 跨平台兼容、条件编译隔离、平台抽象封装、类型安全。

## 何时使用

当执行以下操作时自动加载：
- 修改或创建 `spectra-app/` 目录下的任何 Vue、TS 文件
- 编写页面、组件、API、Store、Hook、平台适配等
- 处理多端兼容、条件编译、原生能力调用等

## 快速参考表

### 目录命名规范

| 位置 | 命名风格 | 示例 |
|---|---|---|
| `src/pages/` | kebab-case | `login/`、`workbench/` |
| `src/subpackages/` | kebab-case | `message/chat/` |
| `src/components/` | kebab-case | `loading/` |
| `src/stores/` | kebab-case | `app.ts` |
| `src/services/api/` | kebab-case | `auth.ts` |
| `src/hooks/` | kebab-case | `useAuthGuard.ts` |
| `src/platform/` | kebab-case | `permission/` |

### 文件命名规范

| 位置 | 命名风格 | 示例 |
|---|---|---|
| 页面组件 | `index.vue` | `pages/login/index.vue` |
| 公共组件 | `组件名/index.vue` | `components/loading/index.vue` |
| API 模块 | kebab-case | `auth.ts` |
| Store 模块 | kebab-case | `app.ts` |
| Hook | kebab-case | `useAuthGuard.ts` |
| 类型定义 | kebab-case | `request.ts` |

### Prettier 配置

| 项 | 值 |
|---|---|
| 缩进 | 4 空格 |
| 引号 | 双引号 |
| 分号 | 必须 |
| 行宽 | 120 字符 |
| 换行符 | LF |
| 尾逗号 | 无 |

### ESLint 核心规则

| 规则 | 级别 | 说明 |
|---|---|---|
| `no-explicit-any` | error | 零容忍 `any` |
| `consistent-type-imports` | error | 使用 `import type` |
| `import/order` | error | 分组排序 |
| `import/no-cycle` | error | 禁止循环依赖 |
| `vue/block-order` | error | SFC: script → template → style |

## 核心规范

### 1. 页面规范（uni-app）

- **SFC 块顺序：** `<script>` → `<template>` → `<style>`
- **生命周期：** 从 `@dcloudio/uni-app` 导入（`onLoad`、`onShow`、`onReady`、`onHide`）
- **路由配置：** 在 `pages.json` 中配置，不使用 vue-router
- **导航方式：** 使用 `uni.navigateTo`、`uni.reLaunch`、`uni.switchTab`、`uni.navigateBack`

### 2. 组件规范（Vue 3.5+）

- **Props：** 使用类型声明 + `withDefaults`
- **Emits：** 使用类型声明
- **v-model：** 使用 `defineModel`
- **自动导入：** 通过 `pages.json` 的 `easycom` 配置

### 3. HTTP 客户端

- 使用 `uni.request` 封装的 `request()` 函数（`services/http.ts`），**不使用 Axios**
- 文件上传使用 `uni.uploadFile`
- 文件下载使用 `uni.downloadFile`

### 4. Pinia Store

- 文件：`app.ts`（当前仅一个 store）
- 导出：`useAppStore`
- 风格：Options API（`state` + `getters` + `actions`）
- 持久化：与 `uni.getStorageSync` 双写模式

### 5. Hook/Composable

- 文件：`use-{功能名}.ts`
- 导出：`use{功能名}`
- 生命周期：使用 uni-app 钩子（`onLoad`、`onShow` 等）
- 全局状态：使用模块级 `ref` 实现共享

### 6. 样式规范

- **CSS 命名：** BEM（Block__Element--Modifier）
- **尺寸单位：** **rpx**（响应式像素，750rpx = 屏幕宽度）
- **预处理器：** SCSS/Less
- **全局变量：** `uni.scss`

### 7. 条件编译

- **JS：** `// #ifdef H5` ... `// #endif`
- **模板：** `<!-- #ifdef H5 -->` ... `<!-- #endif -->`
- **CSS：** `/* #ifdef H5 */` ... `/* #endif */`
- **支持平台：** `H5`、`APP`、`MP-WEIXIN`

### 8. 平台抽象

uni-app 需要同时运行在 H5、Android、微信小程序等平台。当某个功能在不同平台有**不同的实现逻辑**（而非仅仅是样式差异）时，必须通过 `platform/` 目录进行抽象。

- **原则：** 平台差异代码放入 `src/platform/`
- **导入：** 业务代码从 `@/platform/{feature}` 导入
- **禁止：** 不要在业务代码中直接写 `#ifdef` 调用原生 API

#### 目录结构

```
platform/
  app/              # App 基础能力（退出、返回键、版本信息）
  device/           # 设备信息（设备ID、系统信息）
  permission/       # 运行时权限（Android 权限请求）
  {feature}/        # 新增平台差异功能放这里
    types.ts        # 类型定义（统一接口）
    base.ts         # 基础实现（可选，供各平台复用）
    index.ts        # 条件编译入口（#ifdef 导出对应平台实现）
    android.ts      # Android 原生实现
    web.ts          # Web/H5 实现
```

#### 使用方式

业务代码统一从 `@/platform/{feature}` 导入：

```typescript
// ✅ 正确：通过 platform 抽象调用
import { permission } from "@/platform/permission";
const granted = await permission.requestPermission("android.permission.CAMERA");

// ❌ 错误：在业务代码中直接写条件编译
// #ifdef APP-ANDROID
plus.android.requestPermissions(["android.permission.CAMERA"]);
// #endif
```

#### 何时使用 platform/ vs 模板内 #ifdef

| 场景 | 做法 |
|---|---|
| 调用原生 API（权限、设备、推送等） | 放入 `platform/{feature}/` |
| APP 需要 `scroll-view` 包裹而 H5 不需要 | 模板内直接用 `<!-- #ifdef APP -->` 即可 |
| 微信小程序特有的组件/逻辑 | 模板内用 `<!-- #ifdef MP-WEIXIN -->` 或放入 `platform/` |

### 9. 类型定义

- **位置：** `src/types/`
- **导入：** 使用 `import type` 导入类型
- **导出：** 统一通过 `src/types/index.ts`

### 10. i18n 国际化

- **库：** vue-i18n
- **语言文件：** `src/locales/zh.json`、`src/locales/en.json`
- **使用：** `const { t } = useI18n()`

### 11. 静态资源

- **位置：** `src/static/`
- **引用：** 使用相对路径
- **TabBar：** 使用 iconfont 图标

### 12. 路由与分包

- **主包页面：** 在 `pages.json` 的 `pages` 中配置
- **分包页面：** 在 `pages.json` 的 `subpackages` 中配置
- **预加载：** 在 `preloadRule` 中配置
- **分包限制：** 单个分包不超过 2MB

## 常见错误

### 错误 1：使用 any 类型

```typescript
// ❌ 错误
function getData(): any { return {}; }

// ✅ 正确
function getData(): Record<string, unknown> { return {}; }
```

### 错误 2：生命周期钩子导入错误

```typescript
// ❌ 错误：从 vue 导入
import { onMounted } from "vue";

// ✅ 正确：从 uni-app 导入
import { onLoad, onShow } from "@dcloudio/uni-app";
```

### 错误 3：在业务代码中直接写条件编译

```typescript
// ❌ 错误
// #ifdef APP-ANDROID
plus.android.requestPermissions(["android.permission.CAMERA"]);
// #endif

// ✅ 正确：通过 platform 抽象
import { permission } from "@/platform/permission";
const granted = await permission.requestPermission("android.permission.CAMERA");
```

### 错误 4：使用 axios 或 fetch

```typescript
// ❌ 错误
import axios from "axios";
const response = await axios.get("/api/data");

// ✅ 正确：使用 uni.request 封装
import { get } from "@/services/request";
const data = await get<Data>("/api/data");
```

### 错误 5：SFC 块顺序错误

```vue
<!-- ❌ 错误：template 在 script 前 -->
<template><div>{{ title }}</div></template>
<script setup lang="ts">const title = "test";</script>

<!-- ✅ 正确：script → template -->
<script setup lang="ts">const title = "test";</script>
<template><div>{{ title }}</div></template>
```

### 错误 6：使用 localStorage 而非 uni.storage

```typescript
// ❌ 错误
localStorage.setItem("token", token);

// ✅ 正确
uni.setStorageSync("token", token);
```

### 错误 7：使用 vue-router 而非 uni API

```typescript
// ❌ 错误
import { useRouter } from "vue-router";
const router = useRouter();
router.push("/login");

// ✅ 正确
uni.navigateTo({ url: "/pages/login/index" });
```

## 完整示例

完整的代码模板请查看 `examples/` 目录：

| 模板 | 文件 | 说明 |
|---|---|---|
| 页面组件 | `page-full.vue` | 完整页面示例（生命周期、路由、i18n） |
| 公共组件 | `component-full.vue` | 完整组件示例（Props/Emits/defineModel） |
| API 模块 | `api-full.ts` | 完整 API 模块示例（CRUD） |
| Pinia Store | `store-full.ts` | 完整 Store 示例（state/getters/actions） |
| Hook | `hook-full.ts` | 完整组合式函数示例（useNetwork） |
| 平台抽象 | `platform-full.ts` | 完整平台抽象示例（条件编译入口） |
| 类型定义 | `types-full.d.ts` | 完整类型声明示例（Entity/VO/Form） |
| 分包配置 | `subpackage-full.json` | 完整分包配置示例 |

## 详细规则查询

完整规范请查阅以下文档：

- 目录结构：`docs/20-前端/20-spectra-app.md` 第 4 节
- 页面规范：`docs/20-前端/20-spectra-app.md` 第 5 节
- 组件规范：`docs/20-前端/20-spectra-app.md` 第 6 节
- API 规范：`docs/20-前端/20-spectra-app.md` 第 7 节
- 样式规范：`docs/20-前端/20-spectra-app.md` 第 8 节
- 条件编译：`docs/20-前端/20-spectra-app.md` 第 9 节
- 平台抽象：`docs/20-前端/20-spectra-app.md` 第 10 节
- 多端适配：`docs/20-前端/20-spectra-app.md` 第 11 节
