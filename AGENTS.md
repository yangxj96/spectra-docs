# AGENTS.md

## 会话初始化（每次会话必须执行）

在本项目工作时，**每次会话开始时**必须先读取以下文件建立完整上下文：

### 1. 必读文件

首先读取 `docs/00-项目总览.md`，了解系统架构、技术栈、模块导航。

### 2. 按任务读取对应笔记

| 任务涉及 | 读取笔记 |
|---|---|
| 后端架构/分层 | `docs/10-后端/10-架构分层.md` |
| 后端编码规范 | `docs/40-规范/15-后端开发规范.md` |
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
2. 读取 `docs/40-规范/15-后端开发规范.md` ← 后端编码规范（后端任务必读）
3. 读取任务相关的模块笔记 ← 领域知识
4. 使用 CodeGraph MCP（或 `codegraph` CLI）查询具体代码 ← 实现细节
5. 三者结合形成完整上下文后再开始编码

## 知识图谱维护

本项目使用 Obsidian 知识库（`docs/`）作为跨会话长期记忆。开发过程中必须同步维护：

- **修改代码后**：更新对应笔记中的关键文件路径、API 端点、实体字段等变更
- **新增模块/功能**：从 `docs/99-模板/T-模块笔记模板.md` 创建新笔记，在 `docs/00-项目总览.md` 中添加导航链接
- **删除/重构模块**：同步归档或删除对应笔记，更新所有相关 `[[wikilink]]`
- **笔记之间用 `[[wikilink]]` 连接**，保持知识图谱完整可遍历

## 文档同步规则（强制）

编码任务完成后，**必须**按以下对照表检查是否需要更新文档。如有更新，与代码变更一起提交。

| 代码变更 | 更新目标 |
|---|---|
| 新增/删除 Entity | `docs/30-数据模型/20-实体清单.md`、`docs/70-AI速查/03-实体字典.md` |
| 新增/删除 Controller | `docs/10-后端/90-API总览.md`、`docs/70-AI速查/04-API端点.md` |
| 新增模块/子模块 | `docs/00-项目总览.md` 导航 + 创建模块笔记 |
| 修改配置项/环境变量 | `docs/70-AI速查/05-配置清单.md` |
| 升级依赖版本 | `docs/70-AI速查/06-依赖版本.md` |
| 新增/修改规范 | `docs/40-规范/` 对应文件 |
| 新增/修改建表 SQL | `docs/sql/<schema>/建表.sql` |

**验证**：完成编码后，检查 `docs/00-项目总览.md` 中的数字（Entity/Controller 数量）是否仍准确。

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

## mise 与本地启动约定

本仓库根目录（包含 `docs/`）以及各可运行子项目都使用 mise 管理本地开发环境。当前 PowerShell 配置通过以下内容激活 mise：

```powershell
(&mise activate pwsh) | Out-String | Invoke-Expression
```

正常打开的开发终端已经加载上述配置时，不需要每次手动重复执行；进入对应目录后直接使用该项目的命令即可。若新开的终端没有加载 PowerShell profile，先执行上面的激活命令。

如果 mise 提示 `.mise.local.toml` 未被信任，在对应项目目录执行一次 `mise trust`；仅信任本机配置，不要把其中的密钥复制到代码或文档中。

| 目录 | mise 配置 | 管理内容 |
|---|---|---|
| 根目录（含 `docs/`） | `.mise.local.toml` | 本地开发环境变量；不在文档中展开敏感值 |
| `spectra-admin/` | `mise.toml` | Temurin JDK 25.0.2；Maven 使用项目自带 wrapper |
| `spectra-ui/` | `mise.toml` | Node 24.14.0、pnpm 11.0.9 |
| `spectra-app/` | `mise.toml` | Node 24.14.0、pnpm 11.0.9 |
| `logicflow-plugin-flowable/` | `mise.toml` | Node 24.14.0、pnpm 11.0.9 |

### 后端启动顺序

默认不因为代码检查或普通开发任务自动启动服务；只有用户明确要求启动，或任务确实需要运行时验证时才执行下面流程。

后端必须先编译打包，再运行 `spectra-launch` 生成的 Spring Boot 可执行 JAR：

```powershell
Set-Location D:\Develop\Projects\spectra\spectra-admin

# 完整构建后端（跳过测试执行）
.\mvnw.cmd clean package -DskipTests

# 运行当前构建产物；不要选择 *.jar.original
$jar = Get-ChildItem .\spectra-launch\target\spectra-launch-*.jar -File | Select-Object -First 1
java --add-modules ALL-SYSTEM --enable-native-access=ALL-UNNAMED `
    -Dspring.profiles.active=dev `
    -jar $jar.FullName
```

项目 wrapper 已修复 PowerShell 在普通 `.m2` 目录上访问空 `Target[0]` 导致的 `Cannot index into a null array` 问题。正常用户终端不需要额外参数；如果 Codex/CI 沙箱把 Java 的 `user.home` 指向不可写目录，则将 Maven 本地仓库显式指向可写的临时目录：

```powershell
$mavenRepo = Join-Path $env:TEMP 'spectra-maven-repository'
.\mvnw.cmd "-Dmaven.repo.local=$mavenRepo" clean package -DskipTests
```

`spectra-launch/pom.xml` 配置了 Spring Boot `repackage`，因此上述 `package` 会生成可直接运行的 fat JAR。当前版本产物名为 `spectra-launch-0.0.18.jar`，版本变更后以 `target/` 中实际的 `.jar` 为准。构建和运行依赖本地 PostgreSQL、Redis 以及 `spectra-admin/.mise.local.toml` 中的环境变量。

IDEA 中看到的 `java ... @C:\Users\yangx\AppData\Local\Temp\idea_arg_file... com.devops00.spectra.launch.LaunchApplication` 是 IDEA 已编译 classpath 后的类启动命令；`idea_arg_file` 是 IDEA 临时生成的参数文件，不是项目编译命令，也不应复制到终端中使用。终端中的等价流程就是上面的 Maven `package` + JAR 启动。

当前 `LaunchApplication` 不需要额外的 `@Import`。`spectra-security-spring-boot-starter` 的 `SecurityAutoConfiguration` 会扫描 `com.devops00.spectra.security.starter.web`，因此 `UserOnlineConverter` 放在该 starter 的扫描范围内即可。

IDEA 命令中的 `-Dhttp.proxyHost/-Dhttp.proxyPort/-Dhttps.proxyHost/-Dhttps.proxyPort` 是本机代理参数；只有需要通过该代理访问外部服务时才补充，不作为本地 API 启动的固定前提。

### 前端与移动端启动顺序

后端启动并监听 4004 后，分别在各目录中执行 pnpm 脚本：

```powershell
# Web 管理后台，端口 5173
Set-Location D:\Develop\Projects\spectra\spectra-ui
pnpm start

# 移动端 H5
Set-Location D:\Develop\Projects\spectra\spectra-app
pnpm start
```

`pnpm start` 已由各项目的 `prestart` 钩子负责格式化、代码检查和类型检查，不要在启动命令中再次手动串联这些检查。微信小程序开发使用 `pnpm dev:mp-weixin`，详见对应子项目的 `AGENTS.md`。

## 项目连接方式

两个前端在开发环境指向同一个后端：

- `spectra-ui/.env` → `VITE_API_URL=https://127.0.0.1:4004/`
- `spectra-app/.env.development` → `VITE_API_BASE_URL=https://127.0.0.1:4004`

后端默认端口为 **4004**（通过 `.mise.local.toml` 中的 `SERVER_PORT` 设置）。

`spectra-ui` 通过 `file:` 引用本地 `logicflow-plugin-flowable`（`file:../logicflow-plugin-flowable`），修改插件代码后需在 `logicflow-plugin-flowable/` 执行 `pnpm run build` 或 `pnpm run dev`（监听模式）。

跨前后端功能开发且用户明确要求启动时：
1. 在已激活 mise 的终端中进入 `spectra-admin/`，执行 Maven `package` 并运行 `spectra-launch` JAR。
2. 再进入 `spectra-ui/` 或 `spectra-app/` 执行 `pnpm start`。

## 通用工具链

- **Node**: 24.14.0, **pnpm**: 11.0.9 — 通过 [mise](https://mise.jdx.dev/) 管理（`mise.toml` / `.mise.local.toml`）
- **Java**: JDK 25 (Temurin), **Maven**: 3.9.12 — 项目自带 wrapper（`mvnw` / `mvnw.cmd`）
- **npm 镜像**: 淘宝镜像（`registry.npmmirror.com`），配置在 Vue 项目的 `.npmrc` 中

## 常用命令速查

```powershell
# spectra-admin（在 spectra-admin/ 下执行）
.\mvnw.cmd clean package -DskipTests      # 编译并打包
# 然后按上面的 JAR 启动命令运行 API 服务

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
| 密码 | 使用本机 `.mise.local.toml` 中的本地值 |

对应 `.mise.local.toml` 配置：
```toml
DB_URL="jdbc:postgresql://127.0.0.1:5432/devops00_spectra_db"
DB_USERNAME="ai"
DB_PASSWORD="<填写本机 .mise.local.toml 中的值>"
```

## 代码规范

编码规范由 Codex 插件 `spectra` 内的 skills 控制，不再在 AGENTS.md 中内联。插件安装后在 Codex Skills 列表中显示为 `spectra:<skill-name>`，显式触发时可使用 `$<skill-name>`。

- **后端**：`spectra:spectra-admin-spec`（显式 `$spectra-admin-spec`）— 修改 spectra-admin 代码时自动加载
- **Web 前端**：`spectra:spectra-ui-spec`（显式 `$spectra-ui-spec`）— 修改 spectra-ui 代码时自动加载
- **移动端**：`spectra:spectra-app-spec`（显式 `$spectra-app-spec`）— 修改 spectra-app 代码时自动加载

## Git 约定

Git 提交规范详见 Codex skill：`spectra:git-execution-spec`（显式 `$git-execution-spec`，执行 git 命令时自动加载）。

## CodeGraph（源码级查询——日常开发首选）

根目录有 `.codegraph/` 索引，覆盖全部三个子项目。

- Codex 插件 `spectra` 已配置 CodeGraph MCP：`codegraph serve --mcp`
- 查函数定义、调用链、blast radius 等源码级问题，优先使用 CodeGraph MCP 暴露的查询工具；若当前任务尚未加载该插件/MCP，可退回 `codegraph` CLI
- 数据实时同步（文件保存后 ~1s），零维护成本

## graphify（架构级查询——补充工具）

`graphify-out/` 是基于知识图谱的架构全景视图，含 god nodes、社区检测、跨模块关联。**仅用于架构全景类问题**（模块间关系、社区结构、高层依赖），日常源码级问题请走 CodeGraph。

用法：
- 显式触发 Codex 插件 skill `$graphify`，再执行完整构建管线
- `graphify query "<问题>"` / `graphify path "<A>" "<B>"` / `graphify explain "<概念>"` 对已有图谱进行查询
- `graphify-out/GRAPH_REPORT.md` 仅用于宏观架构审查
- 修改代码后执行 `graphify update .` 保持图谱更新（仅 AST，无 API 费用）
