---
name: spectra-ui-spec
description: 当修改、调整或创建spectra-ui前端Vue/TS代码时自动加载。包含组件、API、Store、测试等核心规范。
version: "1.0.0"
license: MIT
metadata:
  hermes:
    tags: [frontend, conventions, vue, typescript, spectra]
---

# spectra-ui 前端开发规范

## 概述

spectra-ui 是基于 Vue 3.5+ + Element Plus + Vite 8 的 Web 管理后台，所有前端代码必须遵循统一的规范。

**核心原则：** 组件目录化、类型安全、Vue 3.5+ 最新语法、统一代码风格。

## 何时使用

当执行以下操作时自动加载：
- 修改或创建 `spectra-ui/` 目录下的任何 Vue、TS 文件
- 编写组件、API、Store、Hook、路由、测试等
- 处理 HTTP 请求、类型定义、状态管理等

## 快速参考表

### 目录命名规范

| 位置 | 命名风格 | 示例 |
|---|---|---|
| `src/` 顶层目录 | kebab-case | `api/`、`components/`、`hooks/` |
| `src/views/` 目录 | PascalCase | `Dashboard/`、`System/` |
| `src/api/` 子目录 | kebab-case | `system/`、`auth/` |

### 文件命名规范

| 位置 | 命名风格 | 示例 |
|---|---|---|
| Vue 组件 | `组件名/index.vue` | `DictSelect/index.vue` |
| API 模块 | kebab-case | `dict-api.ts` |
| Store 模块 | kebab-case | `use-user-store.ts` |
| Hook | kebab-case | `use-table.ts` |

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

### 1. 组件规范（Vue 3.5+）

- **SFC 块顺序：** `<script>` → `<template>` → `<style>`
- **Props：** 使用类型声明 + `withDefaults`
- **Emits：** 使用类型声明
- **v-model：** 使用 `defineModel`

### 2. HTTP 客户端

- 使用自定义 `request()` 函数（`fetch` API），**不使用 Axios**
- 文件上传/下载必须使用 **XHR**（支持进度监听）

### 3. Pinia Store

- 文件：`use-{模块名}-store.ts`
- 导出：`use{模块名}Store`

### 4. Hook/Composable

- 文件：`use-{功能名}.ts`
- 导出：`use{功能名}`

### 5. 测试规范

- 文件：`{功能名}.test.ts`
- 使用 Vitest + @vue/test-utils + happy-dom

## 常见错误

### 错误 1：使用 any 类型

```typescript
// ❌ 错误
function getData(): any { return {}; }

// ✅ 正确
function getData(): Record<string, unknown> { return {}; }
```

### 错误 2：Props 使用旧语法

```typescript
// ❌ 错误：运行时声明
const props = defineProps({ title: { type: String, required: true } });

// ✅ 正确：类型声明 + withDefaults
interface Props { title: string; count?: number; }
const props = withDefaults(defineProps<Props>(), { count: 0 });
```

### 错误 3：Emits 使用旧语法

```typescript
// ❌ 错误：数组声明
const emit = defineEmits(["change", "update:modelValue"]);

// ✅ 正确：类型声明
const emit = defineEmits<{ change: [value: string]; }>();
```

### 错误 4：组件目录缺少 index.vue

```
// ❌ 错误
src/components/DictSelect.vue

// ✅ 正确
src/components/DictSelect/index.vue
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

## 完整示例

完整的代码模板请查看 `examples/` 目录：

| 模板 | 文件 | 说明 |
|---|---|---|
| Vue 组件 | `component-full.vue` | 完整组件示例（Props/Emits/defineModel） |
| API 模块 | `api-full.ts` | 完整 API 模块示例（CRUD） |
| Pinia Store | `store-full.ts` | 完整 Store 示例（state/getters/actions） |
| Hook | `hook-full.ts` | 完整组合式函数示例（useTable） |
| 测试文件 | `test-full.ts` | 完整测试示例（Mock/Mount/断言） |
| 类型声明 | `types-full.d.ts` | 完整类型声明示例（Entity/VO/From） |
| 路由配置 | `routes-full.ts` | 完整路由配置示例 |

## 详细规则查询

完整规范请查阅以下文档：

- 命名规范：`docs/20-前端/10-spectra-ui.md` 第 3 节
- ESLint 规则：`docs/20-前端/10-spectra-ui.md` 第 2 节
- HTTP 客户端：`docs/20-前端/10-spectra-ui.md` 第 4 节
- 类型定义：`docs/20-前端/10-spectra-ui.md` 第 5 节
- Pinia Store：`docs/20-前端/10-spectra-ui.md` 第 6 节
- Hook/Composable：`docs/20-前端/10-spectra-ui.md` 第 7 节
- 组件规范：`docs/20-前端/10-spectra-ui.md` 第 8 节
- 测试规范：`docs/20-前端/10-spectra-ui.md` 第 9 节
- 路由规范：`docs/20-前端/10-spectra-ui.md` 第 10 节
- Commit 规范：`docs/20-前端/10-spectra-ui.md` 第 11 节
