# Spectra Docs

> Spectra 全栈项目的知识图谱仓库。使用 [Obsidian](https://obsidian.md/) 作为知识管理工具，
> 以 git submodule 形式引入三个子项目。

## 仓库结构

```
spectra-docs/
├── .obsidian/        ← Obsidian vault 配置（图谱着色/工作区布局/插件）
├── docs/             ← 结构化知识笔记（Markdown + Mermaid 图表 + Canvas）
│   ├── 00-项目总览.md
│   ├── 10-后端/      ← 架构分层/用户权限/系统管理/OA/文件/工作流/AI/API
│   ├── 20-前端/      ← spectra-ui / spectra-app
│   ├── 30-数据模型/   ← ER 图 / 25个实体清单
│   ├── 40-开发指南/   ← 环境搭建 / 常用命令
│   └── 99-模板/
├── plugins/spectra/  ← Codex 项目插件（规范、graphify 与 CodeGraph MCP）
│   └── skills/       ← Spectra 专用 Codex skills
├── .codex/config.toml ← 项目级 Codex MCP 配置
├── AGENTS.md         ← 根级 Agent 指令
├── spectra-admin/    → git submodule → spectra-admin (Spring Boot 4 + Java 25)
├── spectra-ui/       → git submodule → spectra-ui (Vue 3 + Element Plus + Vite 8)
└── spectra-app/      → git submodule → spectra-app (Vue 3 + uni-app + Vite 5)
```

## 快速开始

```bash
# 克隆仓库（含子模块）
git clone --recurse-submodules git@github.com:yangxj96/spectra-docs.git

# 用 Obsidian 打开
# 文件 → 打开文件夹 → 选择 spectra-docs 目录
# 按 Ctrl+G 查看知识图谱

# 更新子模块到最新
git submodule update --remote
```

## CodeGraph 代码索引

本项目使用 CodeGraph 为代码库建立结构索引，通过 MCP 协议提供代码智能查询，Codex 可通过索引快速理解代码架构。

### 初始化索引

索引需要按顺序创建：**先子项目，后根项目** —— 根索引会引用子项目的索引数据。

```bash
# 1. 进入每个子项目，创建各自的索引
cd spectra-admin && codegraph init && cd ..
cd spectra-ui && codegraph init && cd ..
cd spectra-app && codegraph init && cd ..

# 2. 回到根目录，创建覆盖全部三个子项目的伞形索引
codegraph init
```

### 索引说明

| 索引位置 | 覆盖范围 | 是否提交到 Git |
|---|---|---|
| `spectra-admin/.codegraph/` | 后端 Java 代码 | 子项目自行决定 |
| `spectra-ui/.codegraph/` | Web 前端代码 | 子项目自行决定 |
| `spectra-app/.codegraph/` | 移动端代码 | 子项目自行决定 |
| `./codegraph/` | 全部三个子项目 + docs | ❌ 不提交（自动生成，可重建） |

> 根目录的 `.codegraph/` 已加入 `.gitignore`，因为它是自动生成的可重建数据。
> 每次 `git clone` 后需要重新运行 `codegraph init` 生成。

## MCP 服务器

本项目通过 Codex 的 MCP（Model Context Protocol）协议集成以下工具：

| MCP Server | 工具 | 用途 |
|---|---|---|
| **CodeGraph** | `codegraph_explore` | 代码智能查询 —— 输入自然语言问题或符号名，返回相关源码 + 调用路径 + 影响范围分析。比 grep 更快更准，可追踪运行时动态分发。 |

## 项目技能（Skills）

`plugins/spectra/skills/` 目录定义了项目专用 Codex skills：

| Skill | 用途 |
|---|---|
| `spectra-admin-spec` | 后端 Java 分层、命名、事务、权限和数据规范 |
| `spectra-ui-spec` | Web Vue/TypeScript 架构、类型、组件和测试规范 |
| `spectra-app-spec` | 移动端 uni-app 跨平台、接口和类型规范 |
| `git-execution-spec` | Git 安全检查、提交规范和推送规则 |
| `graphify` | 架构级图谱构建、查询、路径和社区分析 |

## 用途

- **知识图谱** — Obsidian 的 Graph View 可视化项目全貌
- **CodeGraph 索引** — AI Agent 查询代码结构，比 grep 更快更准
- **跨会话记忆** — AI Agent 开发时读取笔记 + CodeGraph 索引建立上下文，修改代码后更新笔记
- **团队共享** — Markdown 文件可直接在 GitHub 上浏览，也可用 Obsidian 离线查看
- **技能驱动开发** — Codex 插件提供项目规范、Git 安全和架构图谱能力

## 维护方式

1. 新会话开始 → 读取 `docs/00-项目总览.md` + CodeGraph 索引建立上下文
2. 修改代码前 → 读取相关模块笔记，了解现有架构
3. 修改代码后 → 更新对应笔记（路径变更、新 API 等）
4. 新增模块 → 从 `docs/99-模板/` 创建新笔记，更新总览链接

## 技术栈速览

| 层级 | 技术 |
|---|---|
| 后端 | Spring Boot 4 + Java 25 + Maven + PostgreSQL + Redis |
| Web 前端 | Vue 3 + Element Plus + Vite 8 + pnpm |
| 移动端 | Vue 3 + uni-app + Vite 5 |
| AI | LangChain4j + RAG |
| 工作流 | Flowable |
| 代码索引 | CodeGraph (MCP) |
| 知识管理 | Obsidian |
| AI Agent | Codex + Spectra plugin skills |
