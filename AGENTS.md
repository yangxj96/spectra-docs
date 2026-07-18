# AGENTS.md

## 会话初始化（每次会话必须执行）

在本项目工作时，**每次会话开始时**必须先读取以下文件建立完整上下文：

### 1. 必读文件

首先读取 `docs/00-项目总览.md`，了解系统架构、技术栈、模块导航。

### 2. 按任务读取对应笔记

| 任务涉及 | 读取笔记 |
|---|---|
| 后端架构/分层 | `docs/10-后端/10-架构分层.md` |
| 后端编码规范 | `docs/10-后端/15-后端开发规范.md` |
| 用户/角色/权限 | `docs/10-后端/20-用户与权限.md` |
| 部门/菜单/字典/日志 | `docs/10-后端/30-系统管理.md` |
| OA 办公 | `docs/10-后端/40-OA模块.md` |
| 文件上传 | `docs/10-后端/50-文件上传.md` |
| 工作流 | `docs/10-后端/60-工作流.md` |
| AI 相关 | `docs/10-后端/70-AI模块.md` |
| 基础设施 | `docs/10-后端/80-基础设施.md` |
| API 接口 | `docs/10-后端/90-API总览.md` |
| Web 前端 | `docs/20-前端/10-spectra-ui.md` |
| 移动端 | `docs/20-前端/20-spectra-app.md` |
| 数据模型/数据库 | `docs/30-数据模型/10-ER图.md`、`docs/30-数据模型/20-实体清单.md` |

### 3. 上下文加载顺序

1. 读取 `docs/00-项目总览.md` ← 全局概览
2. 读取 `docs/10-后端/15-后端开发规范.md` ← 后端编码规范（后端任务必读）
3. 读取任务相关的模块笔记 ← 领域知识
4. 使用 `codegraph_explore` 查询具体代码 ← 实现细节
5. 三者结合形成完整上下文后再开始编码

## 知识图谱维护

本项目使用 Obsidian 知识库（`docs/`）作为跨会话长期记忆。开发过程中必须同步维护：

- **修改代码后**：更新对应笔记中的关键文件路径、API 端点、实体字段等变更
- **新增模块/功能**：从 `docs/99-模板/T-模块笔记模板.md` 创建新笔记，在 `docs/00-项目总览.md` 中添加导航链接
- **删除/重构模块**：同步归档或删除对应笔记，更新所有相关 `[[wikilink]]`
- **笔记之间用 `[[wikilink]]` 连接**，保持知识图谱完整可遍历

## 系统架构

Spectra 是一个全栈系统：一个后端 API 服务两个前端客户端。它们位于各自独立的目录中，有各自的工具链，但**在运行时协作**——两个前端都连接 `spectra-admin` 作为 API 服务器。

```
┌─────────────────┐      ┌─────────────────┐
│  spectra-ui     │      │  spectra-app    │
│  (Web Admin)    │      │  (Mobile/H5)    │
│  Vue 3 + Element│      │  Vue 3 + uni-app│
│  Plus, Vite 8   │      │  Vite 5         │
└────────┬────────┘      └────────┬────────┘
         │                        │
         │   VITE_API_URL         │   VITE_API_BASE_URL
         │                        │
         └───────────┬────────────┘
                     │
          ┌──────────▼──────────┐
          │   spectra-admin     │
          │   (Backend API)     │
          │   Spring Boot 4     │
          │   Java 25, Maven    │
          │   PostgreSQL, Redis │
          └─────────────────────┘

┌─────────────────────┐
│  logicflow-plugin-flowable │
│  (BPMN 流程建模插件) │
│  LogicFlow Plugin   │
│  TypeScript, tsup   │
└─────────────────────┘
    ↓ file: 引用
spectra-ui
```

| 目录 | 角色 | 技术栈 | 端口（开发） |
|---|---|---|---|
| `spectra-admin/` | 后端 API 服务 | Java 25, Spring Boot 4, Maven, PostgreSQL, Redis | 4004 |
| `spectra-ui/` | Web 管理后台 | Vue 3, Vite 8, Element Plus, pnpm | 5173 |
| `spectra-app/` | 移动端（H5 / 微信小程序） | Vue 3, uni-app, Vite 5, pnpm | — |
| `logicflow-flowable/` | BPMN 流程建模插件 | LogicFlow, TypeScript, tsup | — |

**每个子项目有自己的 `AGENTS.md`——进入该目录工作时先读取。** 本文件只覆盖跨项目的事实信息。

## 项目连接方式

两个前端在开发环境指向同一个后端：

- `spectra-ui/.env` → `VITE_API_URL=https://127.0.0.1:4004/`
- `spectra-app/.env.development` → `VITE_API_BASE_URL=https://127.0.0.1:4004`

后端默认端口为 **4004**（通过 `.mise.local.toml` 中的 `SERVER_PORT` 设置）。

`spectra-ui` 通过 `file:` 引用本地 `logicflow-plugin-flowable`（`file:../logicflow-plugin-flowable`），修改插件代码后需在 `logicflow-plugin-flowable/` 执行 `pnpm run build` 或 `pnpm run dev`（监听模式）。

跨前后端功能开发时：
1. 先启动 `spectra-admin`（`./mvnw spring-boot:run -pl spectra-launch`）
2. 再启动对应的前端（在 `spectra-ui` 或 `spectra-app` 中执行 `pnpm start`）

## 通用工具链

- **Node**: 24.14.0, **pnpm**: 11.0.9 — 通过 [mise](https://mise.jdx.dev/) 管理（`mise.toml` / `.mise.local.toml`）
- **Java**: JDK 25 (Temurin), **Maven**: 3.9.12 — 项目自带 wrapper（`mvnw` / `mvnw.cmd`）
- **npm 镜像**: 淘宝镜像（`registry.npmmirror.com`），配置在 Vue 项目的 `.npmrc` 中

## 常用命令速查

```bash
# spectra-admin（在 spectra-admin/ 下执行）
./mvnw clean package -DskipTests          # 构建
./mvnw spring-boot:run -pl spectra-launch # 启动 API 服务

# spectra-ui（在 spectra-ui/ 下执行）
pnpm install && pnpm start                # 开发服务器（自动 format+lint+typecheck）

# spectra-app（在 spectra-app/ 下执行）
pnpm install && pnpm start                # H5 开发（自动 typecheck+lint+format）
pnpm dev:mp-weixin                        # 微信小程序开发

# logicflow-plugin-flowable（在 logicflow-plugin-flowable/ 下执行）
pnpm run build                            # 构建插件
pnpm run dev                              # 开发监听模式（自动重新构建）
```

## 环境配置

运行前需配置本地环境：

- **spectra-admin**: 复制 `.mise.local.toml.example` 为 `.mise.local.toml`，填入数据库/Redis/S3/AI 凭据
- **spectra-ui**: 创建 `.env`，设置 `VITE_API_URL`（默认 `https://127.0.0.1:4004/`）
- **spectra-app**: 创建 `.env` 或使用 `.env.development`（默认 `https://127.0.0.1:4004`）

需要运行的服务：**PostgreSQL** + **Redis**（供 spectra-admin 使用）。

## 本地开发数据库（只读）

以下账号只有**只读权限**，可以放心用于查询和调试：

| 配置项 | 值 |
|---|---|
| 数据库类型 | PostgreSQL 18 |
| 地址 | `127.0.0.1` |
| 用户名 | `ai` |
| 密码 | `QuVsKppcWvwwX2Vv` |

对应 `.mise.local.toml` 配置：
```toml
DB_URL="jdbc:postgresql://127.0.0.1:5432/devops00_spectra_db"
DB_USERNAME="ai"
DB_PASSWORD="QuVsKppcWvwwX2Vv"
```

## 代码规范（Vue 项目共享）

`spectra-ui` 和 `spectra-app` 使用相同的 Prettier 配置：
- 4 空格缩进，双引号，分号，120 字符行宽，LF 换行符
- 无尾逗号，`arrowParens: avoid`，`bracketSameLine: true`

## Git 约定

Git 提交规范详见：`spectra/git-execution-spec` Skill（执行 git 命令时自动加载）。

## CodeGraph

根目录有 `.codegraph/` 索引，覆盖全部三个子项目（spectra-admin、spectra-ui、spectra-app）。使用 `codegraph_explore` 前先确认目标文件是否在索引范围内。

<!-- CODEGRAPH_START -->
## CodeGraph

In repositories indexed by CodeGraph (a `.codegraph/` directory exists at the repo root), reach for it BEFORE grep/find or reading files when you need to understand or locate code:

- **MCP tool** (when available): `codegraph_explore` answers most code questions in one call — the relevant symbols' verbatim source plus the call paths between them, including dynamic-dispatch hops grep can't follow. Name a file or symbol in the query to read its current line-numbered source. If it's listed but deferred, load it by name via tool search.
- **Shell** (always works): `codegraph explore "<symbol names or question>"` prints the same output.

If there is no `.codegraph/` directory, skip CodeGraph entirely — indexing is the user's decision.
<!-- CODEGRAPH_END -->
