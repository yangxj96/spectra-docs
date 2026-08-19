---
tags:
  - frontend
  - mobile
---

# spectra-app — 移动端

> 基于 Vue 3 + uni-app + Vite 5 的移动端和微信小程序应用。路径：`spectra-app/`。

## OA 页面

移动端复用既有 `pages/workbench/index.vue` 工作台，通过 `services/api/oa.ts` 加载真实待办、公告、日程和会议摘要；已经移除无页面路径的模拟模块和硬编码待办数量。请假、报销、采购、公告、日程、会议页面分别为 `pages/leave/index.vue`、`pages/reimbursement/index.vue`、`pages/purchase/index.vue`、`pages/notice/index.vue`、`pages/calendar/index.vue`、`pages/meeting/index.vue`。

`pages/approval/index.vue` 提供待办/已办、申请详情、同意和驳回，并提供“全部、财务相关、资产相关、行政人事”审批分类；分类通过 `process_definition_key` 调用 Workflow 类型过滤接口。`pages/contacts/index.vue` 使用后端真实组织通讯录。请假、报销、采购均支持审批人选择、草稿编辑、提交、撤回和取消；报销覆盖驳回后的取消和审批后的付款状态，采购覆盖审批后的执行登记与分批收货，不再停留在“只能提交”的页面壳。

办公用品页面为 `pages/supplies/index.vue`，从工作台“办公用品”入口进入，通过 `services/api/oa.ts` 对接库存查询、入库、领用、退库和库存调整，并支持最低库存筛选。

资产管理页面为 `pages/assets/index.vue`，从工作台行政管理分类进入；通过 `services/api/oa.ts` 对接资产台账、分类、手工建账以及领用、归还、维修、报废操作。

## 技术栈

| 技术 | 版本 |
|---|---|
| Vue | 3.4.21 |
| 框架 | uni-app 3.0.0-5010420260703001 |
| 构建工具 | Vite 5.2.8 |
| 语言 | TypeScript 5.4.5 |
| 包管理 | pnpm 11.0.9 |
| Node | 24.14.0 |
| H5 端口 | 5174 |

## 运行模式

```powershell
Copy-Item .env.example .env.development
pnpm install         # 安装依赖
pnpm start           # H5 开发（http://localhost:5174），自动 type-check+lint+format
pnpm dev:mp-weixin   # 微信小程序开发
```

## 项目配置

| 文件 | 说明 |
|---|---|
| `vite.config.ts` | Vite 构建配置 |
| `vue.config.js` | uni-app 的 Vue CLI 配置 |
| `tsconfig.json` | TypeScript 配置 |
| `eslint.config.mjs` | ESLint 扁平配置 |
| `.prettierrc` | Prettier 格式化配置（与 spectra-ui 一致） |
| `.env.example` | 已提交的环境变量模板（默认 HTTPS 4004） |
| `.env.development` | 从模板复制的本机开发配置，不提交 |
| `package.json` | 依赖与脚本 |

## 目录结构

```
spectra-app/
├── src/
│   ├── components/   # 公共组件
│   ├── config/
│   │   └── env.ts          # 环境变量统一导出（含 CRYPTO_ENABLED）
│   ├── helper/       # 通用辅助函数
│   ├── hooks/        # uni-app 组合式逻辑
│   ├── interceptor/  # 请求/路由拦截器
│   ├── locales/      # i18n 语言包
│   ├── pages/        # 页面（uni-app 页面路由）
│   ├── platform/     # H5/小程序/App 平台能力抽象
│   ├── services/
│   │   └── http.ts         # HTTP 客户端（H5 平台集成加密/解密）
│   ├── static/       # 静态资源
│   ├── stores/       # Pinia 状态管理
│   ├── styles/       # 全局样式
│   ├── subpackages/  # 小程序分包页面
│   ├── types/        # 全局与业务类型
│   ├── utils/        # 工具函数
│   │   └── crypto/    # 加解密工具（H5 平台可用，#ifdef 条件编译）
│   ├── App.vue       # 根组件
│   ├── main.ts       # 入口文件
│   ├── manifest.json # uni-app 配置
│   └── pages.json    # 页面路由配置
├── dist/             # 构建输出
└── unpackage/        # uni-app 编译输出
```

## 代码规范

与 `spectra-ui` 完全一致：
- 缩进：4 空格 / 双引号 / 分号 / 120 行宽 / LF / 无尾逗号
- `arrowParens: avoid` / `bracketSameLine: true`

## 与后端连接

仓库只提交 `.env.example`。新克隆先复制为 `.env.development`；模板中的 `VITE_API_BASE_URL=https://127.0.0.1:4004` 连接后端首次 HTTPS 启动。H5 开发服务器仍使用 `http://localhost:5174`，修改 API 端口或连接远程后端时，只修改本机环境文件。

> **环境变量命名约定**：spectra-app 使用 `VITE_API_BASE_URL`（无尾部 `/`），spectra-ui 使用 `VITE_API_URL`（带尾部 `/`）。这是两个项目的既定约定，不强制统一。

> 接口加解密（`VITE_CRYPTO_ENABLED`）基于 Web Crypto API，仅 H5 平台可用。密钥通过后端 API 动态获取（`initCrypto` + `fetchClientPrivateKey`），不再硬编码在 `.env` 中。

> ⚠️ **技术债务**：`utils/crypto/` 下的 `aes-utils.ts`、`rsa-utils.ts`、`crypto-utils.ts` 与 spectra-ui 中完全重复。未来应抽取为共享包 `@spectra/crypto`。

## 关键文件路径

| 文件 | 路径 |
|---|---|
| Vite 配置 | `spectra-app/vite.config.ts` |
| ESLint 配置 | `spectra-app/eslint.config.mjs` |
| Prettier 配置 | `spectra-app/.prettierrc` |
| 环境变量 | `spectra-app/.env.development` |
| 环境变量模板 | `spectra-app/.env.example` |
| uni-app manifest | `spectra-app/src/manifest.json` |
| 页面路由 | `spectra-app/src/pages.json` |
| AGENTS.md | `spectra-app/AGENTS.md` |
| 环境配置 | `spectra-app/src/config/env.ts` |
| 加密工具 | `spectra-app/src/utils/crypto/crypto-utils.ts` |
| HTTP 加密拦截 | `spectra-app/src/services/http.ts` |

## 相关笔记

- [[00-项目总览]]
- [[10-spectra-ui]]
- [[10-环境搭建]]
- [[20-常见命令]]
- [[85-接口加解密方案]]
