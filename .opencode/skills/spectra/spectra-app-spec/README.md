# spectra-app-spec

spectra-app 前端开发规范技能

## 概述

本技能定义了 spectra-app（基于 uni-app 的跨平台移动端应用）的开发规范，包括页面、组件、API、Store、Hook、条件编译、平台抽象等核心规范。

## 何时使用

当执行以下操作时自动加载：
- 修改或创建 `spectra-app/` 目录下的任何 Vue、TS 文件
- 编写页面、组件、API、Store、Hook、平台适配等
- 处理多端兼容、条件编译、原生能力调用等

## 规范内容

### 核心规范

1. **页面规范**：uni-app 生命周期、路由配置、导航方式
2. **组件规范**：Vue 3.5+ 语法、Props/Emits 类型声明
3. **API 调用**：uni.request 封装、文件上传下载
4. **Pinia Store**：Options API 风格、双写模式
5. **Hook/Composable**：uni-app 生命周期、模块级共享状态
6. **样式规范**：BEM 命名、rpx 单位
7. **条件编译**：JS/模板/CSS 三端条件编译
8. **平台抽象**：platform/ 目录封装平台差异

### 示例文件

| 模板 | 文件 | 说明 |
|---|---|---|
| 页面组件 | `examples/page-full.vue` | 完整页面示例（生命周期、路由、i18n） |
| 公共组件 | `examples/component-full.vue` | 完整组件示例（Props/Emits/defineModel） |
| API 模块 | `examples/api-full.ts` | 完整 API 模块示例（CRUD） |
| Pinia Store | `examples/store-full.ts` | 完整 Store 示例（state/getters/actions） |
| Hook | `examples/hook-full.ts` | 完整组合式函数示例（useNetwork） |
| 平台抽象 | `examples/platform-full.ts` | 完整平台抽象示例（条件编译入口） |
| 类型定义 | `examples/types-full.d.ts` | 完整类型声明示例（Entity/VO/Form） |

## 相关文件

- **主规范文档**：`SKILL.md`
- **项目文档**：`docs/20-前端/20-spectra-app.md`
- **项目配置**：`spectra-app/AGENTS.md`

## 与 spectra-ui-spec 的区别

| 维度 | spectra-ui | spectra-app |
|---|---|---|
| 框架 | Vue 3 + Vite 8 | Vue 3 + uni-app + Vite 5 |
| 平台 | Web | 跨平台（H5/APP/小程序） |
| UI 库 | Element Plus | TDesign |
| 生命周期 | onMounted 等 | onLoad/onShow 等（uni-app） |
| 路由 | vue-router | uni.navigateTo 等 |
| HTTP | fetch 封装 | uni.request 封装 |
| 存储 | localStorage | uni.getStorageSync |
| CSS 单位 | px/rem | rpx |
| 条件编译 | 无 | #ifdef 支持 |
| 平台抽象 | 无 | platform/ 目录 |
