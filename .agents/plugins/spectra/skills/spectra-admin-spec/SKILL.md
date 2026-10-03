---
name: spectra-admin-spec
description: 仅在修改或审查 spectra-admin 的 Java、后端接口、持久化、事务、安全或模块边界时使用；文档、配置查看和命令咨询不要触发。
---

# spectra-admin 后端 Skill

## 使用边界

- 遵循最近的 `AGENTS.md` 和用户已确认的 `docs/开发指南/04-工作区工程标准.md`，按目标职责读取相关章节；已加载的内容不重复读。领域细则、旧配置和模板有冲突时按主标准处理，改变基线需与用户明确讨论。
- 本文的 `docs/`、`spectra-admin/` 路径相对 Spectra 工作区根；`references/` 相对本 Skill，安装缓存位置不作为项目根。
- 从目标项目使用 CodeGraph 分析定义、调用及依赖，使用 rg 核对精确代码、配置、文档与遗漏。公共变更先完整分析全工作区直接、间接、数据、协议、装配及运行影响，再确定改造和验收范围。
- OA、Workflow 和流程业务的独立治理暂缓，受公共变更影响的区域仍需一致性改造及验证；不能预设只改直接调用方或只验证当前模块。
- 新增或不熟悉目标类型时只读取必要示例；示例说明结构，不证明权限、事务、并发或协议已经正确。源码和治理台账区分已实施能力与目标要求，不把旧配置通过当作新标准通过。

## 核心规则

### Java 与包结构

- 工具版本以 mise、POM 和锁定配置为准，使用 mise 与 Maven Wrapper。沿用传统 Javadoc 和 Apache License 2.0 文件头，类注释包含 `@author`、`@version`、`@since`。
- 简单模块使用 `controller/`、`javabean/{converter,entity,from,vo}/`、`mapper/`、`service/impl/`；复杂模块按子域拆分。
- 平台能力集中在 Core，新增业务功能才使用独立模块；Launch 统一装配，Common 保持公共契约，不承载 ORM、Web 或数据库实现。
- 应用 Service 统一接口 + Impl。实体 CRUD 可使用 Framework 的 BaseService/BaseServiceImpl，编排或非实体用例组合协作者，不绑定无关 Entity。内部 Policy、Worker、Adapter 按实际职责组织，不一律配置接口。
- Core 跨域使用公开 Service 或必要 Facade 的业务操作及必要 DTO，禁止直接操作对方 Mapper、Impl 或继承的通用 CRUD；跨模块通过公共契约，不依赖对方内部 Entity、Mapper 或实现。
- 抽象由真实职责、生命周期、复用或已确认扩展需要驱动，说明必要性与验证依据；行数只作线索，不制造无语义拆分。

### Controller

- 默认构造器注入，可使用 `@RequiredArgsConstructor` 与 `private final`。
- Controller 负责协议绑定、入口校验、身份和接口级粗授权及用例调用，不写业务决策，不返回 `Object`。需要审计的接口使用 `@Audit`；公开接口显式 `permitAll()`，版本保持 `1.0.0`。
- 请求对象声明输入约束，HTTP 写操作按契约使用 `@Validated(Verify.Insert.class)` / `Verify.Update.class`；内部和任务入口同样执行必要约束。
- 普通编辑完整提交可编辑字段，清空语义按字段契约；状态、密码等采用专用操作。真正局部更新明确字段存在性，不绑定 Entity。

### 用例、权限、事务与并发

- Service 是最终业务授权边界，覆盖操作权限、记录范围、列表/计数/导出/批量；范围在分页和统计前落实。非 HTTP 入口显式身份，缺少登录上下文不等于全量权限。
- Service 确定必要且短的本地原子业务单元，同库跨域调用参与该事务；数据库约束及原子条件保障并发。外部副作用按阶段、补偿或可靠持久意图处理，不假定随数据库回滚。
- 可编辑业务记录默认乐观锁，提交读取版本，条件更新并检查结果；不得用新读版本替换提交版本。冲突目标为 HTTP 409 和稳定 error_code；具体异常映射须核对当前实现并同步迁移。
- 异步按业务承诺分级，受理/可恢复/结果任务持久化并验证提交、领取、幂等及分类重试；提交后回调不等于持久可靠。不自动新建通用任务引擎。
- 运行日志用关联、操作和结果的安全字段；同步 `@Audit` 保障被审计写入与成功审计一致，失败审计独立提交需明确。避免重复日志或输出敏感入参。

### 模型、API 与时间

- Entity、请求 From/Query、响应 VO、必要 DTO 按职责区分，不机械复制层次。复用持久化基类；普通业务软删除，特殊生命周期有依据。主键和审计字段按已有填充约定。
- 结构映射使用已有 MapStruct 或必要的明确手写转换，业务校验和数据库访问不塞入映射；保护身份/系统字段，验证版本和清空值真正写入。
- 后端定义及实际序列化是契约事实源，目标为 OpenAPI 导出、TS 类型生成及漂移核对；保持真实 HTTP 状态，code 为状态，Java errorCode 在线为 `error_code`，稳定值采用 DOMAIN_REASON，msg 只用于安全展示。
- JSON/生成协议字段 snake_case，Java 成员 camelCase；响应省略和空值保持当前行为，不统一补 null、空数组或 data:null。API 1.0.0 的仓库内调用方同步迁移，不保留旧入口或回退兼容。
- 绝对时刻按 Instant/UTC 保存，由后端按有效用户或显式系统默认时区转换并输出偏移；日期、纯时间保留自身语义。严格解析，不猜格式、不自动补今天、不依赖操作系统时区；后台携带明确上下文，业务时间源可控。
- From 沿用普通 class、Bean Validation 及中文 message，时间字段的具体绑定遵循字段契约；封闭状态使用枚举。静态配置强类型可验证，已在共享/正式环境应用的 Flyway migration 只追加。

### 基础设施与复杂度

- 数据库与缓存必需，连接/命令故障拒绝业务，不故障回源。安全 Redis 经 SecurityRedisExecutor 且 fail-closed；启动依赖失败退出，运行故障不就绪、受控恢复。支持多实例，缓存、领取、调度及文件按全局/实例范围验证。
- 普通方法圈复杂度 >15、Java NPath >200、嵌套 >3、显式参数 >5 必须处理或登记具体可验证例外；DI 构造器及生成/映射/装配/测试按职责处理，手写业务控制仍适用。
- 使用固定 PMD 口径并校准边界；旧阈值不能当目标。例外记录符号、规则、实测值、必要性、风险、证据与复评条件，自动核对范围和引用，理由由评审判断。

## Reference 路由

- 目标类型示例：[references/examples/](references/examples/)，按需选 `*-full.java`，异常定义/抛出分别用 `exception-full.java` / `exception-data.java`。不确定时先 rg 列文件，先核对依赖和契约再采用。
- JSONB：[references/jsonb.md](references/jsonb.md)；认证、验证码、Token、Session、防重放：[references/security.md](references/security.md)。
- 后端细则：`docs/后端/30-规范/01-后端开发规范.md`；治理与例外：`docs/开发指南/05-集中治理与验收.md`、`docs/开发指南/工程治理/ledger.json`；领域按 AGENTS 路由，不预加载全部笔记。

## 验证

- 开发中在 spectra-admin 经 mise + `.\mvnw.cmd` 做目标 compile/test；交付执行完整影响范围的 verify，集中治理使用全量格式检查。检查与 spotless:apply 分开，不跳过必要测试。
- 行为与风险决定验证；真实隔离 DB/Redis 验证事务、并发、故障恢复和多实例，实际协议及生成漂移另验，关键 Web 路径浏览器验收。不设每类每行测试或统一覆盖率要求。
- 命令见 `docs/开发指南/01-常见命令.md`。同步受影响 API、Entity、配置、迁移、版本及领域文档，交付区分已验证、未执行及目标尚未实施的能力。
