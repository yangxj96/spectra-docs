# Spectra 工作区 Agent 指令

## 适用范围

本文件只保存 Spectra 工作区的全局项目约束。通用 Windows、PowerShell、文件编辑和安全规则由全局 Agent 指令提供；后端、Web、移动端和插件规则由最近的子目录 `AGENTS.md` 提供。

## 仓库地图

| 目录 | 职责 | 入口 |
|---|---|---|
| `spectra-admin/` | Spring Boot 后端 API | `spectra-admin/AGENTS.md` |
| `spectra-ui/` | Vue Web 管理后台 | `spectra-ui/AGENTS.md` |
| `spectra-app/` | uni-app H5/小程序/App | `spectra-app/AGENTS.md` |
| `logicflow-plugin-flowable/` | LogicFlow BPMN 插件 | `logicflow-plugin-flowable/AGENTS.md` |
| `docs/` | 项目知识库和完整参考 | 按任务读取 |
| `scripts/` | 运行时、上下文和文档检查 | 按需执行 |

## 硬约束

- 当前 API 契约版本统一为 `1.0.0`。重构时同步迁移仓库内调用方，删除旧入口、别名、回退读取和临时兼容分支；除非用户明确要求，不承诺外部历史兼容。
- 不读取、输出、提交 `.mise.local.toml`、数据库密码、Token、私钥、证书私钥或其他本机凭据。
- 不改写用户已有的无关变更，不使用破坏性 Git 或文件操作。
- 安全 Redis 是 Token、Session、MFA、验证码、防重放和登录失败锁定的事实源；连接失败、命令失败或无法确认状态时必须 fail-closed。
- 修改代码后判断知识库是否需要同步；只在确实影响知识库时运行 `scripts/check-docs.ps1`。

## 任务路由

- 后端 Java：读取 `spectra-admin/AGENTS.md`，使用 `$spectra-admin-spec`；只读取目标领域笔记。
- Web 前端：读取 `spectra-ui/AGENTS.md`，使用 `$spectra-ui-spec`。
- 移动端：读取 `spectra-app/AGENTS.md`，使用 `$spectra-app-spec`。
- 流程插件：读取 `logicflow-plugin-flowable/AGENTS.md`；修改插件并联调 Web 时再读取对应流程建模笔记。
- Git 操作：只有任务包含 Git 状态、差异、暂存、提交、分支、标签、恢复、推送或冲突处理时，使用 `$git-execution-spec`。

只在以下情况读取 `docs/00-项目总览.md` 和架构笔记：新模块、架构调整、跨项目修改、目标区域不明确或需要分析整体影响。普通局部修改不要预加载项目总览。

领域笔记按目标路由读取：后端用户/权限、系统管理、OA、上传、工作流、AI、基础设施、API 和数据库分别对应 `docs/10-后端/`、`docs/30-数据模型/` 中的相关文件；Web、移动端和插件分别对应 `docs/20-前端/` 中的相关文件。不要读取无关领域文档。

## 源码理解与验证

- 根目录存在 `.codegraph/` 且工具可用时，源码定义、实现、调用链、依赖和影响范围优先使用 CodeGraph；精确文本、配置和文档使用 `rg`。
- 开发阶段优先目标模块或目标项目的快速检查；模块完成、交付或提交前再执行完整质量门禁。
- 后端使用 `spectra-admin/mvnw.cmd`；前端和插件使用项目固定的 Node/pnpm 与脚本。完整命令维护在 `docs/50-开发指南/20-常见命令.md`，不要复制到本文件。

## 文档同步规则

- 新增或删除 Entity：同步实体清单和 AI 实体字典。
- 新增、删除或修改 Controller/路径：同步 API 总览和 API 端点速查。
- 新增模块：同步项目总览和模块笔记。
- 修改配置项或环境变量：同步配置清单。
- 修改依赖版本：同步依赖版本速查。
- 新增或修改建表 SQL：同步对应 schema 的建表文档。

规范的完整解释、代码模板、命令和排障信息放在 `docs/` 或匹配的 Skill reference 中；不要在多个 Agent 指令文件中复制。
