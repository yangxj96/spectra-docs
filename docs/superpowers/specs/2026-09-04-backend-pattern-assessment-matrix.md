# 后端设计模式评估矩阵

> Task17 评估日期：2026-09-08。结论基于 Task11–16 已落地源码、调用方和现有测试；“调用方/变体”是当前代码观察值，“变更频率”在没有提交统计时标注为基于职责边界的推断。

## 采纳标准

只有同时满足以下条件才引入模式：

1. 至少存在两个真实且语义不同的变体；
2. 变体有清晰的扩展轴，且调用方不应继续承担分支选择；
3. 能用测试隔离每个变体，并验证权限、排序、异常、事务和 fail-closed 语义不变；
4. 可以量化收益，例如减少业务分支、避免重复中间调用或提升变体测试隔离度；
5. 变更可以通过保留原端口和 Spring Bean 生命周期安全回滚。

## 候选矩阵

| 候选 | 当前变体与重复分支 | 调用方/扩展轴 | 变更频率（证据） | 测试隔离 | 成本与回滚 | 可量化收益 | 决策 |
|---|---|---|---|---|---|---|---|
| Session backend Strategy/Factory | `SecuritySessionPolicyProvider` 当前只有 1 个 JDBC 实现；`SecuritySessionStore.sessionPolicy` 只有一个 Provider 端口 | `SecuritySessionStore`、签发/刷新用例；后端存储实现是部署扩展轴，但当前没有第二个真实后端 | 低；Provider 是稳定窄端口，当前源码无第二实现 | 可单测 Provider，但 Factory 目前没有第二实现可契约化 | 中；新增 Factory 会改变 Bean 选择，回滚要恢复 Provider 注入 | 0 个重复分支、0 个额外 Redis/DB 调用 | 拒绝：未达到两个真实后端变体 |
| Session operation Strategy | `SessionConcurrencyMode` 有 `ALLOW/KICK_OLD/REJECT_NEW` 3 个真实变体；`SecuritySessionIssueService` 当前用 `if/else if` 集中处理 2 个行为分支 | 仅由签发用例选择；并发模式是明确扩展轴 | 中高；会话并发策略已进入数据库策略模型，新增模式会改同一处流程 | 每个策略可隔离测试，且可保持原 `SecurityToken`、Redis 清理和异常语义 | 低中；保留 `SecuritySessionIssuer` 端口，用 Spring `@Component` 策略和解析器替换局部分支，可直接回退 | 签发用例的并发分支从 2 个降为 0；策略单测覆盖 3 个变体；不增加 Redis 调用 | **采纳**：唯一达到标准且收益可测的候选 |
| Cookie/CSRF 与 rate-limit subject Policy/Strategy | Cookie/CSRF 是一个过滤器策略；限流主体有 IP、USER、IP_AND_USER 3 个维度，但主体组合已集中在 `RateLimitPolicy.Subject.key`，过滤器只有认证用户/地址读取分支 | `WebCookiePolicy`、`RateLimitPolicy.SubjectDimension`；没有多个可替换的外部主体解析器 | 中；安全策略可能变化，但当前已有固定目录和测试 | 现有 `WebCookiePolicyTest`、`RequestRateLimitFilterTest`、`RedisRateLimiterTest` 已按维度隔离 | 中；拆分会引入过滤器 Bean/构造器和策略顺序风险 | 预计减少 1 个小分支，无法证明减少 Redis 调用或复杂度 | 拒绝：当前 Policy 已是足够的策略封装 |
| request/response security pipeline | 请求解密 1 个 `RequestBodyAdvice`；响应加密与统一包装是 2 个不同 `ResponseBodyAdvice`，依赖固定顺序和不同 Spring SPI | MVC Advice 生命周期与顺序是扩展轴，不是同一种可互换业务策略 | 中；加密状态和响应包装规则已在 Task11–15 固化 | 已有请求/响应 Advice 测试覆盖媒体类型、空值、重放和不可用状态 | 高；抽象 pipeline 容易改变 `@Order`、String/资源放行和异常映射，回滚面大 | 无可确认分支/调用/延迟收益，反而可能增加一次委托 | 拒绝：Spring SPI 边界比模式收益更重要 |
| captcha Factory/Strategy | `KaptchaTextCreator` 是唯一文本生成器；`KaptchaType` 目前只是配置值，数学表达式内部仍是一个实现 | `KaptchaConfiguration` → Kaptcha Producer；当前没有第二个生成器 Bean 或算法端口 | 低；验证码类型没有独立实现或调用方分叉 | 现有配置/登录测试可覆盖生成与消费，但没有第二策略契约 | 中；Factory 会引入 Producer 选择和配置兼容风险 | 0 个重复调用，无法测出复杂度或性能收益 | 拒绝：只有一个真实生成实现 |
| data-scope SQL Specification/Policy | `ScopeSqlPolicy` 已统一 Permission、SELF/RULES/ALL/NONE、关系子查询和 fail-closed 谓词；`DataScopeInnerInterceptor` 只负责上下文与快照接入 | `ScopeSqlPolicy` 本身就是当前 Policy 扩展轴；`DataScope` 注解是声明端 | 中；权限模式会扩展，但现有分支已经集中且有 SQL 测试 | `ScopeSqlPolicyTest`、`DataScopeIsolationTest`、拦截器测试可隔离策略 | 高；再包一层 Specification 会影响 JSqlParser 表达式和 `1 = 0` 语义 | 不能减少现有边界分支，可能增加一次对象构造 | 拒绝：已有 Policy 已承担该职责 |
| Session use-case command object | 登录/刷新/撤销分别由稳定的 `SecuritySessionIssuer/Refresher/Revoker` 端口暴露；输入对象只在核心模块策略修改处已有 From | 当前每个用例一个入口，没有可复用的命令队列、批处理或多实现执行器 | 低；Task13 刚完成用例拆分，调用方已清晰 | 现有 Session 用例测试按职责隔离 | 中高；会改变公开端口参数和错误边界，回滚需要恢复全部调用方 | 无可确认的分支或调用减少，反而增加命令对象分配 | 拒绝：没有第二个执行变体或流程编排需求 |
| Java25 `ScopedValue` 替代自维护上下文 | `RequestCorrelationContext` 与 `DataScopeContextHolder` 各自维护 `ThreadLocal`；Servlet Filter、MyBatis 拦截器和受控绕过依赖显式 finally 清理 | 请求上下文、数据权限绕过和 MDC 生命周期不同；`ScopedValue` 不能直接替代可变 bypass depth 或现有异步/框架边界 | 中；上下文是基础设施稳定点，错误影响跨请求隔离 | 已有上下文清理、嵌套绕过和 MDC 测试 | 高；需要重新验证 Servlet、MyBatis、异步 dispatch 和线程模型，且引入 Java25 API 生命周期耦合 | 当前无可测的调用或复杂度收益；迁移风险显著 | 拒绝：语义不等价，收益不足 |
| NameLookup/NameFillExecutor | `NameLookup` 是 ID→Name Adapter；当前 3 个业务调用方，`NameFillExecutor` 通过 `ApplicationContext.getBean` 取得注解指定实现 | Adapter 的实现类是功能扩展轴；Task22 再处理最小 Lookup Registry 与 ApplicationContext 问题 | 中；仅 3 个调用方，已有 Task16 文档约束，暂无频繁变化证据 | `NameFill` 反射/批量填充可单测，但重构会耦合所有 VO | 中；改为 Registry 会改变 Bean 生命周期和按类型解析，Task22 有明确后续边界 | 当前没有可证明的重复分支收益；提前迁移会与 Task22 重复 | 拒绝：保留现有 Adapter，按计划留给 Task22 |

## 采纳项设计与等价性要求

仅落地 Session operation Strategy：

- 每个 `SessionConcurrencyMode` 对应一个 Spring Bean，解析器在启动时检查模式覆盖和重复注册；不使用静态注册表或全局可变状态。
- `SecuritySessionIssueService` 仍负责策略读取、令牌生成、Redis 写入和失败清理；策略只负责并发会话判定，保持原 `SecuritySessionIssuer` API、异常语义和 Redis 操作顺序。
- `ALLOW` 不读取或撤销旧会话；`KICK_OLD` 只撤销同一客户端的活动会话；`REJECT_NEW` 在活动会话数达到上限时抛出原有拒绝异常。
- 等价测试覆盖三个变体、同客户端筛选、达到/未达到上限、策略解析完整性；现有 Session 生命周期、部分写入和 Redis fail-closed 测试继续运行。

## 复核指标

| 指标 | 变更前基线 | 目标/结果 |
|---|---:|---:|
| `SecuritySessionIssueService` 并发模式条件分支 | 2 | 0 |
| Session 并发 Redis/撤销调用 | 由原分支决定 | 不新增；由等价测试验证 |
| 并发模式可独立测试的变体 | 0 个独立策略类 | 3 个 |
| 被拒绝候选的理由 | 无矩阵 | 每项有真实变体、风险和收益说明 |
