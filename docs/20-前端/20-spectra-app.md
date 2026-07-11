---
tags:
  - frontend
  - mobile
---

# spectra-app — 移动端

> 基于 Vue 3 + uni-app + Vite 5 的移动端和微信小程序应用。路径：`spectra-app/`。

## 技术栈

| 技术 | 版本 |
|---|---|
| Vue | 3.x |
| 框架 | uni-app (跨端) |
| 构建工具 | Vite 5 |
| 语言 | TypeScript |
| 包管理 | pnpm 11 |
| Node | 24.14.0 |

## 运行模式

```bash
pnpm install         # 安装依赖
pnpm start           # H5 开发（浏览器），自动 typecheck+lint+format
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
| `.env.development` | 开发环境变量（`VITE_API_BASE_URL=https://127.0.0.1:4004`） |
| `package.json` | 依赖与脚本 |

## 目录结构

```
spectra-app/
├── src/
│   ├── api/          # API 请求封装
│   ├── components/   # 公共组件
│   ├── composables/  # 组合式函数
│   ├── pages/        # 页面（uni-app 页面路由）
│   ├── static/       # 静态资源
│   ├── stores/       # Pinia 状态管理
│   ├── utils/        # 工具函数
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

开发环境通过 `.env.development` 中的 `VITE_API_BASE_URL` 指向 `spectra-admin` 的 `https://127.0.0.1:4004`。

## 关键文件路径

| 文件 | 路径 |
|---|---|
| Vite 配置 | `spectra-app/vite.config.ts` |
| ESLint 配置 | `spectra-app/eslint.config.mjs` |
| Prettier 配置 | `spectra-app/.prettierrc` |
| 环境变量 | `spectra-app/.env.development` |
| uni-app manifest | `spectra-app/src/manifest.json` |
| 页面路由 | `spectra-app/src/pages.json` |
| AGENTS.md | `spectra-app/AGENTS.md` |

## 相关笔记

- [[00-项目总览]]
- [[10-spectra-ui]]
- [[10-环境搭建]]
- [[20-常见命令]]
