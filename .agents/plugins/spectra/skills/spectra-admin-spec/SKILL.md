---
name: spectra-admin-spec
description: 仅在修改或审查 spectra-admin 的 Java、后端接口、持久化、事务、安全或模块边界时使用；文档、配置查看和命令咨询不要触发。
---

# spectra-admin 后端 Skill

## 使用边界

- 最近层级的 `AGENTS.md` 已提供项目路由和硬约束；已在上下文中的文件不要重复读取。
- 结构、定义、调用链和影响范围优先使用 CodeGraph；配置、文档和精确文本使用 `rg`。
- 只在新增或不熟悉目标类型时读取一个对应示例；先定位文件，再读取必要内容，不预加载 `references/examples/`。
- 先实现，再做目标模块的 `compile` 或 `test`；模块完成或交付时才格式化和执行适用的 `verify`。
- 只有确实影响知识库时才同步文档。

## 核心规则

### Java 与包结构

- 使用 Java 25、传统 Javadoc 和 Apache License 2.0 文件头；类注释包含 `@author`、`@version`、`@since`。
- 简单模块使用 `controller/`、`javabean/{converter,entity,from,vo}/`、`mapper/`、`service/impl/`；复杂模块按子域拆分。
- `service/` 只放应用服务；Provider、Sender、Worker、Client、Adapter、Validator 等按职责使用独立包。
- 业务模块之间不直接引用对方内部 Entity、Mapper 或实现类；使用明确 Facade、Port 或事件。

### Controller

- 使用 `@RequiredArgsConstructor` 和 `private final` 构造器注入。
- Controller 只做参数绑定、权限和 Service 转发，不写业务逻辑，不返回 `Object`。
- 接口方法统一使用 `@ULog`、`@PreAuthorize` 和 `version = "1.0.0"`；公开接口显式使用 `permitAll()`。
- 写接口的请求对象使用 `@Validated(Verify.Insert.class)` 或 `Verify.Update.class`。
- 方法命名优先使用 `created`、`modify`、`deleteById`、`page`。

### Service、异常与事务

- Service 接口继承项目 `BaseService<Entity>`，禁止直接继承 MyBatis-Plus `IService`。
- 实现类继承 `BaseServiceImpl<Mapper, Entity>`，使用 `@Service` 和 `@Slf4j`。
- 写操作使用 `@Transactional`；关键业务节点记录必要的 `info` 日志。
- 禁止裸 `RuntimeException`；使用项目自定义异常，例如 `DataNotExistException`、`DataSaveException`、`EntityUpdateException`、`BuiltinDataException` 和 `DefaultDataException`。
- 异常消息使用清晰、可展示给用户的中文，不输出凭据、Token 或原始外部异常细节。

### Entity、From、VO 与转换

- Entity 遵循目标模块现有的 `BaseEntity`、UUID v7、审计字段、软删除和乐观锁约定；不要在 Service/Controller 手动生成主键。
- From 使用 `From` 后缀、普通 `class`、Bean Validation 和中文 message；时间入参使用 ISO 8601 `String`。
- VO 使用 `VO` 后缀；API 展示时间使用 `LocalDate`、`LocalTime` 或 `LocalDateTime`，不要直接暴露 `Instant`。
- 对象转换统一使用 MapStruct，放在 `javabean/converter/`，配置 `GlobalMapperConfig` 和 `TimeMapper`；禁止手写重复 setter 转换。
- 受系统控制的状态、类型和动作使用枚举，不使用散落魔法字符串。

### PostgreSQL JSONB 与安全

- PostgreSQL `jsonb` 必须使用项目自定义 `PgJsonbTypeHandler`，不要使用 `Jackson3TypeHandler`；需要细节时读取 `references/jsonb.md`。
- 安全 Redis 操作必须通过 `SecurityRedisExecutor`；连接失败、命令失败、超时或无法确认状态时立即 fail-closed，不得以内存、本地快照或“数据不存在”降级。
- 修改认证、MFA、验证码、Token、Session、防重放或安全 Redis 时读取 `references/security.md`。

## Reference 路由

- 完整模板只读一个：在 `references/examples/` 中按目标类型选择对应示例；常规类型使用 `*-full.java`，异常场景另有 `exception-full.java`（异常定义）和 `exception-data.java`（抛出位置），不确定文件名时先用 `rg --files references/examples`。
- JSONB 映射：`references/jsonb.md`。
- 安全 Redis、认证和 fail-closed：`references/security.md`。
- 项目完整后端规范：`docs/40-规范/15-后端开发规范.md`，只在本 Skill 未覆盖或任务明确要求时读取。
- 领域知识由 `spectra-admin/AGENTS.md` 路由，按目标模块读取，不要一次加载全部领域笔记。

## 验证

- Java 文件修改：按目标模块执行 `compile` 或 `test`。
- 模块交付：执行目标模块 `spotless:apply` 和适用的 `verify`。
- 全项目交付：执行全项目格式化和质量门禁。
- 发现 API、Entity、配置或 SQL 变化时，按根仓库规则同步文档。
