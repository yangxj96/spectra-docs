---
name: spectra-app-spec
description: 仅在修改或审查 spectra-app 的 Vue、TypeScript、uni-app 页面、组件、API、Pinia、Hook、条件编译或平台抽象代码时使用；不要用于 Web、插件、文档或命令咨询。
---

# spectra-app 移动端 Skill

## 使用边界

- 最近的 `AGENTS.md` 已提供项目约束；已加载的规则不要重复读取。先查看目标目录附近的既有实现。
- 先判断是否存在平台差异；只有涉及平台实现或边界时才读取 `references/platform-abstraction.md`。
- 仅在新增或不熟悉目标类型时读取一个示例；先定位，再读对应文件，不预加载整个 `references/examples/`。
- 保持 H5、微信小程序和 App 的共同契约，优先运行受影响平台的类型检查或构建。
- 后端 API 变化时检查 `spectra-admin` 和 Web/App 调用方。

## 核心规则

- 使用 uni-app、Vue 3 和 TypeScript；页面路由在 `pages.json`，导航使用 uni API，不使用 vue-router。
- SFC 块顺序为 `<script>` → `<template>` → `<style>`；uni 生命周期从 `@dcloudio/uni-app` 导入。
- 请求使用项目 `uni.request` 封装，上传/下载使用 `uni.uploadFile` / `uni.downloadFile`；不要引入 Axios 或 fetch。
- 平台行为差异放在 `src/platform/`；业务代码不要直接调用原生 API 或散落条件编译。仅模板结构差异才在模板中使用条件编译。
- 使用严格类型、`import type`、既有 Pinia、存储、i18n 和 Hook 抽象；不要用 `any` 绕过约束。
- 页面、组件、API、Store、Hook 和类型遵循项目现有 kebab-case 与目录结构。

## Reference 路由

- 平台差异：读取 `references/platform-abstraction.md`，需要代码形状时再读取 `references/examples/platform-full.ts`；不要同时预加载普通示例。
- 普通示例按目标类型选择一个：在 `references/examples/` 中查找 `page`、`component`、`api`、`store`、`hook` 或 `types` 对应的 `*-full` 文件。
- 完整项目说明：`docs/20-前端/20-spectra-app.md`，只在目标规则未覆盖或任务明确要求时读取。

## 验证

- 开发中优先执行目标平台类型检查或测试。
- 交付前按需执行 `format:check`、`lint`、`type-check`、`build:h5` 和 `build:mp-weixin`。
- 修改平台抽象时至少验证受影响的平台，并检查条件编译边界。
