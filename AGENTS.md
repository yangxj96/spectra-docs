<!-- CODEGRAPH_START -->
## CodeGraph

根目录存在 `.codegraph/`，需要定位源码、定义、调用链或影响范围时，先使用 CodeGraph，再使用 `rg` 补充文本检索：

- MCP 可用时优先调用 `codegraph_explore`。
- MCP 不可用且本机已把 CodeGraph 加入 PATH 时执行：`codegraph explore "符号或问题"`；CodeGraph 是可选工具，不得假设固定安装路径。
- 源码定义、调用链、影响范围和高层依赖分析统一使用 CodeGraph。
<!-- CODEGRAPH_END -->

# AGENTS.md

## 会话初始化

在本项目开始工作时按顺序建立上下文：

1. 必读 `docs/00-项目总览.md`。
2. 后端任务再读 `docs/40-规范/15-后端开发规范.md`。
3. 按任务读取下表中的领域笔记。
4. 进入子项目后读取其 `AGENTS.md`。
5. 查询具体实现时使用 CodeGraph；只有 CodeGraph 不覆盖的文本再用 `rg`。

| 任务涉及 | 领域笔记 |
|---|---|
| 后端架构/分层 | `docs/10-后端/10-架构分层.md` |
| 用户/角色/权限 | `docs/10-后端/20-用户与权限.md` |
| 部门/菜单/字典/日志 | `docs/10-后端/30-系统管理.md` |
| OA 办公 | `docs/10-后端/40-OA模块.md` |
| 文件上传 | `docs/10-后端/50-文件上传.md` |
| 工作流 | `docs/10-后端/60-工作流.md` |
| AI | `docs/10-后端/70-AI模块.md` |
| 基础设施 | `docs/10-后端/80-基础设施.md` |
| API | `docs/10-后端/90-API总览.md` |
| Web 前端 | `docs/20-前端/10-spectra-ui.md` |
| 移动端 | `docs/20-前端/20-spectra-app.md` |
| 数据库 | `docs/30-数据模型/10-ER图.md`、`docs/30-数据模型/20-实体清单.md` |

高频命令和环境故障处理统一维护在 `docs/50-开发指南/20-常见命令.md`。需要快速查看当前事实时执行：

```powershell
. .\scripts\agent-runtime.ps1 # 仅在 mise 未信任或 Agent 沙箱运行时使用
.\scripts\agent-context.ps1
.\scripts\check-docs.ps1
```

## 仓库结构与运行关系

Spectra 是一个后端服务、两个前端客户端和一个流程建模插件：

| 目录 | 角色 | 技术栈 | 开发端口 |
|---|---|---|---|
| `spectra-admin/` | 后端 API | Spring Boot 4.1、Java 25、Maven | 4004 |
| `spectra-ui/` | Web 管理后台 | Vue 3、Vite 8、Element Plus | 5173 |
| `spectra-app/` | H5/微信小程序/App | Vue 3、uni-app、Vite 5 | H5 5174 |
| `logicflow-plugin-flowable/` | BPMN 流程建模插件 | LogicFlow、TypeScript、tsup | — |

- `spectra-ui` 与 `spectra-app` 都连接 `spectra-admin`。
- `spectra-ui` 通过 `file:../logicflow-plugin-flowable` 引用本地插件；修改插件后先构建或启动监听构建。
- 默认不要因普通检查自动启动服务。只有用户明确要求，或运行时验证确有必要时才启动 PostgreSQL、Redis、后端和前端。

## 当前开发阶段与 API 兼容策略

- 项目当前处于开发阶段，所有 API 的版本号统一为 `1.0.0`。`1.0.0` 表示当前契约版本，不要求对旧实现、旧数据结构或旧调用方式保持兼容。
- 重构或架构切换时直接以新契约替换旧契约：同步修改后端、Web、App、插件、测试和文档，删除旧路由、字段、DTO、构造器、别名、适配器、回退读取、双写和临时兼容分支；不得为了所谓历史兼容保留旧入口。
- 发现旧调用方时，优先在本仓库内一并完成迁移并让旧实现失效或删除，不增加兼容窗口、版本分支或过渡 API。只有用户明确要求外部兼容时，才单独设计兼容方案并记录范围、期限和删除条件。
- 数据库重构使用新的 Flyway 增量迁移清理旧表、旧字段或旧数据；已经执行的不可变迁移不得改写。数据库迁移不等同于 API 兼容承诺。

## 安全 Redis 强依赖策略

- 安全模块使用 Redis 作为 Token、Session、Refresh Token 轮换、防重放、MFA Challenge、验证码、登录失败锁定和加密请求 nonce 的事实源；这些路径不是可降级缓存。
- 安全 Redis 连接、超时、命令执行失败或必须返回结果的脚本返回 `null` 时，必须 fail-closed：立即拒绝当前操作，不得把故障解释为 Token/Challenge/验证码不存在、校验失败或已消费，也不得继续向业务层传递 Token。
- 统一通过 `SecurityRedisExecutor` 执行安全 Redis 操作；Web 请求返回 HTTP 503（`安全会话服务暂不可用`）。禁止增加本地快照、内存回退、绕过 Redis 的兼容分支或静默吞掉 Redis 异常。
- 普通业务缓存仍按缓存规范处理；只有明确属于安全事实源的 Redis 操作适用上述强依赖策略。

## 工具链与高频命令

- 后端团队模板位于 `spectra-admin/.mise.local.toml.example`，实际值写入被忽略的 `spectra-admin/.mise.local.toml`。根目录 `.mise.local.toml` 仅是维护者可选的本机上层覆盖，不是新克隆前置条件；不要读取后输出、复制或提交其中的密钥。
- 子项目 `mise.toml` 分别固定 JDK 25.0.2 或 Node 24.14.0 + pnpm 11.0.9。
- Maven 3.9.12 使用 `spectra-admin/mvnw.cmd`，不要依赖全局 Maven。
- Windows 命令统一使用 PowerShell 7.6 或更高版本的 `pwsh`；实际安装路径由 `Get-Command pwsh` 确认，不假设固定磁盘位置。不要使用 Windows PowerShell 5.1 的 `powershell.exe`。根目录脚本通过 `#requires -Version 7.6` 强制执行此约束。
- mise 信任是人工安全决策；若提示未信任，只提醒用户在对应目录执行一次 `mise trust`，Agent 不自动修改信任状态。只读检查和验证可点源 `scripts/agent-runtime.ps1`，直接使用项目固定运行时。

```powershell
# 后端（spectra-admin/）
.\mvnw.cmd spotless:check
.\mvnw.cmd spotless:apply
.\mvnw.cmd spotless:check "-Dspotless.ratchetFrom=NONE"
.\mvnw.cmd test
.\mvnw.cmd clean package -DskipTests

# Web（spectra-ui/）
pnpm run format:check
pnpm run lint
pnpm run type-check
pnpm run test
pnpm run build

# 移动端（spectra-app/）
pnpm run format:check
pnpm run lint
pnpm run type-check
pnpm run build:h5
pnpm run build:mp-weixin

# 流程建模插件（logicflow-plugin-flowable/）
pnpm run format:check
pnpm run build
```

PowerShell 中 `-Dspotless.ratchetFrom=NONE` 必须作为带引号的单个参数传入，否则可能被 Maven Wrapper 误解析。`pnpm start` 已通过 `prestart` 执行对应项目的格式化、lint 和类型检查，不要在启动命令中重复串联。

## Python 环境

- 如需执行 Python 脚本或安装 Python 依赖，必须使用工作空间根目录的 `.venv/`，不得向全局 Python 环境安装包，避免污染全局环境。
- 根目录虚拟环境不存在时，在工作空间根目录创建：`python -m venv .venv`。
- 执行脚本和安装依赖统一使用 `.\.venv\Scripts\python.exe`，例如：`.\.venv\Scripts\python.exe -m pip install <package>`、`.\.venv\Scripts\python.exe <script.py>`。

## 文档同步

代码变更后必须检查知识库是否需要同步，笔记之间使用 `[[wikilink]]`：

| 代码变更 | 更新目标 |
|---|---|
| 新增/删除 Entity | `docs/30-数据模型/20-实体清单.md`、`docs/70-AI速查/03-实体字典.md` |
| 新增/删除 Controller 或路径 | `docs/10-后端/90-API总览.md`、`docs/70-AI速查/04-API端点.md` |
| 新增模块/子模块 | `docs/00-项目总览.md` + 对应模块笔记 |
| 修改配置项/环境变量 | `docs/70-AI速查/05-配置清单.md` |
| 升级依赖版本 | `docs/70-AI速查/06-依赖版本.md` |
| 新增/修改规范 | `docs/40-规范/` 对应文件 |
| 新增/修改建表 SQL | `docs/sql/<schema>/建表.sql` |

完成后运行 `.\scripts\check-docs.ps1`，并确认 `docs/00-项目总览.md` 中的 Entity/Controller 数量仍与源码一致。新增模块笔记从 `docs/99-模板/T-模块笔记模板.md` 创建。

## 项目 Skills

- 后端 Java：`spectra:spectra-admin-spec`
- Web：`spectra:spectra-ui-spec`
- 移动端：`spectra:spectra-app-spec`
- Git：`spectra:git-execution-spec`

Skill 是工作流和规范的唯一来源；不要在多个 `AGENTS.md` 中复制整份 skill 内容。若 skill 与 `docs/40-规范/` 冲突，以当前项目文档和用户最新明确决定为准，并同步修正 skill 源文件。

## Git 与安全

- Git 操作必须遵循 `spectra:git-execution-spec`：检查敏感信息、具体文件暂存、Conventional Commits 中文消息，提交和推送按 skill 要求确认。
- `.mise.local.toml`、数据库密码、Token、私钥和本机凭据不得写入文档、日志或提交。
- 当前维护者机器若配置了只读数据库账号 `ai`，只能用于只读查询，密码只从本机配置获取；新克隆环境不得假设该账号存在，应使用自己的最小权限账号。
- 不改写用户已有的无关变更，不使用破坏性 Git 命令。
