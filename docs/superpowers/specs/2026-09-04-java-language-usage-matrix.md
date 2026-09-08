# Java 语言使用矩阵

## 审计范围

本矩阵记录 2026-09-08 对 `spectra-admin` 生产源码的审计结果。扫描范围为：

- `spectra-common/src/main/java`
- `spectra-framework/src/main/java`
- `spectra-modules/spectra-core/src/main/java`
- `spectra-modules/spectra-oa/src/main/java`
- `spectra-modules/spectra-workflow/src/main/java`
- `spectra-launch/src/main/java`

计数用于识别现状和迁移候选，不把某种语法的使用率当成质量指标。生产源码中的注释和字符串不计入 `var` 清单；`var` 的实际位置由 `JavaLanguageUsageContractTest` 编译后扫描并按模块输出。

## 编译基线

根 POM、`spectra-config`、`spectra-common`、`spectra-framework`、`spectra-modules`、`spectra-launch` 以及三个业务子模块的 `java.version`、`maven.compiler.source` 和 `maven.compiler.target` 均为 `25`。因此工程统一以 Java 25 编译，不把某个语言构造错误归因于 JDK 25。

| 模块 | Java 编译级别 | 生产源码 | `var` 局部声明 |
|---|---:|---:|---:|
| 根 POM | 25 | — | — |
| `spectra-config` | 25 | 无 Java 源码 | 0 |
| `spectra-common` | 25 | 有 | 29 |
| `spectra-framework` | 25 | 有 | 82 |
| `spectra-modules` | 25 | 聚合 POM | 0 |
| `spectra-modules/spectra-core` | 25 | 有 | 1451 |
| `spectra-modules/spectra-oa` | 25 | 有 | 412 |
| `spectra-modules/spectra-workflow` | 25 | 有 | 56 |
| `spectra-launch` | 25 | 有 | 3 |
| **合计** | **25** | — | **2033** |

## 语言特性现状

以下数量来自同一批生产源码的只读检索，属于源代码行命中数；多行构造按命中行计数，后续新增代码不要求维持固定数量。

| 特性 | 当前现状 | 审计结果与迁移判断 |
|---|---|---|
| `var` | 2033 个局部声明 | 仅用于有明确初始化器或增强 `for` 迭代变量的局部推断；不得用于成员字段、方法返回值、方法参数或 `null` 初始化。它是 Java 10 引入的局部变量语法，不是 Java 25 新特性。 |
| `record` | 138 个声明行命中 | 已用于快照、请求、响应、策略和领域值对象等数据载体；这些类型依赖紧凑不可变语义，继续使用显式字段类会增加样板代码，暂无统一迁移收益。 |
| `instanceof` 模式匹配 | 49 个模式匹配行命中 | 已用于异常、权限和输入分支中的类型判断；绑定变量只在判断成功后的分支内使用，避免重复强制转换。 |
| switch expression / arrow case | 118 个 `case ->` 或 `yield` 行命中 | 已用于状态、渠道、调度和安全策略映射；表达式结果直接对应业务值，保留现状，不为“全部改写”制造行为风险。 |
| Sequenced Collection API | 15 个 `.getFirst()`、`.getLast()` 或 `.reversed()` 调用 | 仅在顺序语义明确的列表/集合操作中使用；迁移前必须确认具体集合实现、空集合行为和返回视图/副本语义。 |
| 文本块 | 36 个 `"""` 分隔符命中 | 主要用于 SQL、JSON、请求体和测试数据；继续使用以保持多行内容可读，变更时必须保留缩进和换行语义。 |

## `var` 编码规则

允许使用 `var` 的场景：

- 初始化器直接暴露具体类型，例如 `new ArrayList<>()`、`new LambdaQueryWrapper<>()`；
- 集合构造、增强 `for` 的迭代变量和资源变量；
- fluent builder 链式构造，显式类型不能增加业务含义；
- 局部变量在短范围内使用，读取者可以从初始化器直接确认类型。

必须保留显式类型的场景：

- 公共 API、方法参数、返回值、成员字段和构造器契约；
- `null` 初始化、数字类型容易混淆的计算；
- 复杂条件表达式、跨多行或跨较远代码区域使用的变量；
- 安全认证、Redis fail-closed、事务边界、锁/幂等键和权限范围等不变量；
- 类型本身表达业务约束，或初始化器不能让调用方快速确认类型。

规则不要求把现有显式类型全部改成 `var`，也不以 `var` 使用率 100% 为目标。新增 `var` 后必须能说明它提高了局部可读性；如果推断类型会隐藏安全、事务或数值语义，应使用显式类型。

## 自动约束

`JavaLanguageUsageContractTest` 至少验证：

- 根 POM 和每个 Maven 模块声明 Java 25；
- 生产源码存在已编译的 `var` 局部变量，并输出按模块的清单；
- 源码中出现的 `var` 只能是带初始化器或增强 `for` 迭代变量的局部声明，不得出现在字段或方法签名位置。

该测试不限制 record、模式匹配、switch expression 或 Sequenced Collection API 的数量；这些构造是否使用，取决于类型安全、空值/异常行为、集合语义和业务可读性。
