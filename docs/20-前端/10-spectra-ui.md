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
| Vue | 3.x |
| 构建工具 | Vite 8 |
| UI 框架 | Element Plus |
| 语言 | TypeScript |
| 状态管理 | Pinia |
| 路由 | Vue Router 4 |
| 包管理 | pnpm 11 |
| Node | 24.14.0 |

## 项目配置

| 文件 | 说明 |
|---|---|
| `vite.config.mts` | Vite 构建配置 |
| `tsconfig.json` | TypeScript 配置 |
| `eslint.config.ts` | ESLint 扁平配置 |
| `.prettierrc.yml` | Prettier 格式化配置（4空格/双引号/分号/120宽） |
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
│   ├── api/          # API 请求封装
│   │   └── system/
│   │       └── crypto.ts       # 加解密管理 API + getter
│   ├── assets/       # 静态资源
│   ├── components/   # 公共组件
│   ├── composables/  # 组合式函数
│   ├── directives/   # 自定义指令
│   ├── layout/       # 布局组件
│   ├── plugin/
│   │   ├── request/
│   │   │   └── http.ts         # HTTP 客户端（集成加密/解密）
│   │   └── store/modules/
│   │       └── use-crypto-store.ts  # 加解密 Pinia store
│   ├── router/       # 路由配置
│   ├── stores/       # Pinia 状态管理
│   ├── styles/       # 全局样式
│   ├── utils/        # 工具函数
│   │   └── crypto/    # 加解密工具（AES-GCM + RSA）
│   ├── views/        # 页面组件
│   ├── App.vue       # 根组件
│   └── main.ts       # 入口文件
├── public/           # 不经过编译的静态文件
├── tests/            # 测试文件
└── types/            # 类型声明
```

## 代码规范

- 缩进：4 空格
- 引号：双引号
- 分号：必须
- 行宽：120 字符
- 换行符：LF
- 尾逗号：无
- `arrowParens: avoid`
- `bracketSameLine: true`

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
| 加密工具 | `spectra-ui/src/utils/crypto/crypto-utils.ts` |
| 加解密 store | `spectra-ui/src/plugin/store/modules/use-crypto-store.ts` |
| 加解密 API | `spectra-ui/src/api/system/crypto.ts` |
| HTTP 加密拦截 | `spectra-ui/src/plugin/request/http.ts` |

## 加解密说明

密钥通过后端 API 动态获取，不再硬编码在 `.env` 中：

- 应用启动：`initCrypto()` → `GET /api/system/crypto/config` → 获取 `enabled` + `serverPublicKey`
- 登录成功：`fetchClientPrivateKey()` → `GET /api/system/keypair/client-private` → 获取 `clientPrivateKey`
- 状态存储在 `use-crypto-store`，`enabled` + `serverPublicKey` 持久化，`clientPrivateKey` 仅内存

## 相关笔记

- [[00-项目总览]]
- [[20-spectra-app]]
- [[10-环境搭建]]
- [[20-常见命令]]
- [[85-接口加解密方案]]
