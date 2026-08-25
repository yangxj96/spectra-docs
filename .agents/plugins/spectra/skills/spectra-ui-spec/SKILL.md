---
name: spectra-ui-spec
description: 仅在修改或审查 spectra-ui Web 的 Vue、TypeScript、API、Pinia、Hook、路由、组件、类型或 Vitest 代码时使用；不要用于 spectra-app、插件、文档或命令咨询。
---

# spectra-ui Web Skill

## 使用边界

- 最近的 `AGENTS.md` 已提供项目约束；已加载的规则不要重复读取。先查看目标文件附近的既有实现。
- 跨文件关系、路由、API 或影响范围使用 CodeGraph；配置和精确文本使用 `rg`。
- 仅在新增或不熟悉目标类型时读取一个示例；先定位，再读对应文件，不预加载整个 `references/examples/`。
- 保持既有抽象，修改后优先执行目标测试或类型检查。
- 后端 API 变化时检查 `spectra-admin` 和相关前端调用方。

## 核心规则

- 使用 Vue 3.5+、TypeScript 和项目既有目录命名：页面/组件目录使用 PascalCase，API、Store 和 Hook 文件使用 kebab-case。
- SFC 块顺序为 `<script>` → `<template>` → `<style>`。
- Props、Emits 和 `v-model` 使用类型声明、`withDefaults` 和 `defineModel`；禁止用 `any` 绕过类型检查。
- 业务请求必须经过 `src/plugin/request/` 的自定义客户端；不要新增 Axios 或在业务代码中直接调用 fetch。上传/下载使用项目封装。
- Store、Hook、API 和类型放在已有目录，遵循当前命名和导出约定；不要为局部需求引入平行状态或请求抽象。
- 测试使用 Vitest、`@vue/test-utils` 和项目既有 mock/Pinia 测试模式。
- `pnpm start` 已通过 `prestart` 执行启动前检查，不要重复串联这些检查。

## Reference 路由

- 示例按目标类型选择一个：在 `references/examples/` 中查找 `component`、`api`、`store`、`hook`、`test`、`types` 或 `routes` 对应的 `*-full` 文件；测试示例同时参考目标组件真实的 Store/API 导入路径。
- 完整项目说明：`docs/20-前端/10-spectra-ui.md`，只在目标规则未覆盖或任务明确要求时读取。

## 验证

- 开发中优先执行目标测试或 `pnpm run type-check`。
- 交付前按需执行 `format:check`、`lint`、`type-check`、`test` 和 `build`。
- 修改 API、路由、权限或文件上传时检查后端契约和跨端调用方。
