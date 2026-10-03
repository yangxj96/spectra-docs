# Spectra 工作区 Agent 指令

## 适用范围

本文件只保存 Spectra 工作区的全局项目约束。通用 Bash、文件编辑和安全规则由全局 Agent 指令提供；后端、Web 和插件规则由最近的子目录 `AGENTS.md` 提供。

## 仓库地图

| 目录 | 职责 | 入口 |
|---|---|---|
| `spectra-admin/` | Spring Boot 后端 API | `spectra-admin/AGENTS.md` |
| `spectra-ui/` | Vue Web 管理后台 | `spectra-ui/AGENTS.md` |
| `logicflow-plugin-flowable/` | LogicFlow BPMN 插件 | `logicflow-plugin-flowable/AGENTS.md` |
| `docs/` | 项目知识库和完整参考 | 按任务读取 |
| `scripts/` | 行政区划数据导入和网站文档同步 | 按需执行 |

## 硬约束

- 人工与 AI 统一遵循 `docs/开发指南/04-工作区工程标准.md`；改变已确认的架构、协议或验收基线需重新与用户明确讨论。领域文档、Skill 和旧模板冲突时按该标准同步修正，不以旧检查配置推断目标已达标。
- 当前 API 契约版本统一为 `1.0.0`。重构时同步迁移仓库内调用方，删除旧入口、别名、回退读取和临时兼容分支；除非用户明确要求，不承诺外部历史兼容。
- 不读取、输出、提交 `.mise.local.toml`、数据库密码、Token、私钥、证书私钥或其他本机凭据。
- 安全 Redis 是 Token、Session、验证码、防重放和登录失败锁定的事实源；连接或命令失败、无法确认状态时必须 fail-closed，不能降级为“状态不存在”。
- 数据库和缓存均为必需基础设施；缓存连接或命令失败拒绝业务，不故障回源降级。启动依赖失败退出，运行故障保持进程但业务不就绪，校验恢复后再服务。
- 修改代码后判断知识库是否需要同步，并更新受影响的知识库文档。

## 工程标准与治理范围

- 实现或审查代码时按目标职责读取工程主标准的相关章节；全量建账、定点例外、门禁和整体验收见 `docs/开发指南/05-集中治理与验收.md` 及 `docs/开发指南/工程治理/ledger.json`。
- 当前集中治理暂缓 OA、Workflow 和流程业务的独立重构；公共变更先分析整个工作区直接与间接影响，再决定必要的一致性改造和验证范围，受影响的暂缓区域不能遗漏。
- 9/28 计划已完成且文件由用户移除，不因文件缺失重建旧计划或判为未完成。标准已确认不代表全量治理或验证已完成。

## 任务路由

- 后端 Java：读取 `spectra-admin/AGENTS.md`，使用 `$spectra-admin-spec`。
- Web 前端：读取 `spectra-ui/AGENTS.md`，使用 `$spectra-ui-spec`。
- `spectra-app-spec` 保留供独立的远程 app 仓库使用；本工作区已解除 app 子仓库关联，不路由或使用该 skill。
- 流程插件：读取 `logicflow-plugin-flowable/AGENTS.md`；修改插件并联调 Web 时再读取对应流程建模笔记。
- Git 操作：只有任务包含 Git 状态、差异、暂存、提交、分支、标签、恢复、推送或冲突处理时，使用 `$git-execution-spec`。

只在以下情况读取 `docs/00-项目总览.md` 和架构笔记：新模块、架构调整、跨项目修改、目标区域不明确或需要分析整体影响。普通局部修改不要预加载项目总览。

领域笔记按目标路由读取：后端用户/权限、系统管理、OA、上传、工作流、基础设施和 API 对应 `docs/后端/10-后端模块/`，配置对应 `docs/后端/40-配置说明/`，数据库对应 `docs/后端/20-数据模型/`；Web 对应 `docs/前端/`，流程插件对应 `docs/流程设计器/`。不要读取无关领域文档。

## 源码理解与验证

- 根仓库和三个子项目均有独立 CodeGraph 索引：`.codegraph/`、`spectra-admin/.codegraph/`、`spectra-ui/.codegraph/`、`logicflow-plugin-flowable/.codegraph/`。
- 需要分析源码定义、实现、调用链、依赖或影响范围时，从目标项目目录运行 `codegraph explore "..."`；跨项目任务逐个查询受影响项目。精确文本、配置和文档使用 `rg`。
- 开发阶段优先目标模块或项目的快速检查；完成、交付或提交前再执行完整质量门禁。后端使用 `spectra-admin/mvnw.cmd`，前端和插件使用 mise 管理的 Node/pnpm 与项目脚本。

## 文档同步规则

- 新增或删除 Entity：同步实体清单和实体字典。
- 新增、删除或修改 Controller/路径：同步 API 总览和 API 端点速查。
- 新增模块：同步项目总览和模块笔记。
- 修改配置项或环境变量：同步配置清单。
- 修改依赖版本：同步依赖版本速查。
- 新增或修改 Flyway migration：同步实体清单和对应 schema 的数据模型文档。

完整命令见 `docs/开发指南/01-常见命令.md`；规范说明、代码模板和排障信息放在 `docs/` 或对应 Skill reference。Agent 指令只保留项目约束，不重复这些内容。
