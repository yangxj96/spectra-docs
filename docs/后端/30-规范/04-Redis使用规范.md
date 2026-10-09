---
tags:
  - backend
  - infrastructure
  - reference
source: https://www.devops00.com/spectra-admin/be-redis-guide
---

# Redis 使用规范

> 来源：[[00-项目总览|项目 VitePress 文档]]
>
> 适用于 spectra-admin 中作为缓存层使用 Redis。不含消息队列、分布式锁等特殊用法。安全模块的 Token、Session、验证码、防重放和请求 nonce Redis 不属于本规范中的普通缓存，见下文“安全 Redis 强依赖”。

> 故障、生命周期与多实例基线按 [[开发指南/04-工作区工程标准|工作区工程标准]] 于 2026-10-03 统一；本页具体配置与现有源码的治理状态见 [[开发指南/05-集中治理与验收|集中治理与验收]]。

## 核心原则

> **普通业务缓存可从事实源重建，数据库与缓存仍都是必需基础设施。**

- 普通业务缓存说明数据库等事实源、键范围、生命周期、失效和允许陈旧时间；安全状态按下文独立事实源规则。
- 正常缓存未命中可按既定流程查询和填充；连接、命令或无法确认状态的故障统一拒绝业务，不能降级为未命中、空结果或故障回源。
- 缓存故障不虚构数据库回滚；提交后失败区分已提交、未提交和结果未知，并按业务契约恢复。必需基础设施不意味着所有对象都增加缓存。
- 启动依赖不可用则失败退出，运行故障保持进程但业务不就绪，暂停新增依赖工作并受控校验恢复。

### 安全 Redis 强依赖

安全模块使用 Redis 作为以下状态的唯一事实源：

- Access Token / Refresh Token / Session 及 Token Family
- Refresh Token 一次性轮换声明和重放围栏
- 登录、绑定流程验证码摘要
- 加密请求 nonce 防重放状态
- 登录失败次数和锁定状态

这些状态不能使用本地缓存、旧快照或内存数据替代。安全 Redis 发生连接失败、超时、命令异常，或者 Lua 脚本未返回预期结果时，必须立即 fail-closed：

- Token 鉴权请求清理安全上下文并停止过滤器链，返回 HTTP 503；
- Controller/Service 请求由统一异常处理返回 HTTP 503 `安全会话服务暂不可用`；
- 不得将故障解释成“Token 无效”“验证码错误”“Challenge 不存在”或“已消费”；
- 不得继续传递 Token、创建/刷新会话或进入业务层。

生产代码统一使用 `SecurityRedisExecutor` 包裹安全 Redis 操作。普通业务缓存与安全事实源都不能故障降级；安全场景还必须停止继续认证、刷新或执行依赖安全事实的业务。

安全集合读取使用 `require`：Redis 正常返回空集合代表已确认不存在，`null` 代表无法确认，必须拒绝。登录失败和验证码尝试通过 `SecurityRedisCounter` 的 Lua 脚本原子创建计数及 TTL，后续递增保持首次窗口；已有计数缺少 TTL、数值畸形、命令失败或脚本返回无效计数时拒绝。登录锁定读取同样原子确认计数与 TTL，不能只凭计数值推断可登录；关闭登录锁定时不再创建永久计数。

安全运行态统一使用 `sec:*` 命名空间，Key 中只允许摘要或非敏感标识，不允许出现明文 Token：

| Key 前缀 | 用途 |
|---|---|
| `sec:sess:*` | Access Session 事实源 |
| `sec:uc:*` / `sec:ut:*` / `sec:online` | 最近 Access 指针、覆盖 Refresh 生命周期的用户会话摘要索引和在线用户集合；`sec:uc:*` 不能作为批量撤销事实源 |
| `sec:family:*` / `sec:rt:family:*` | Access/Refresh Token Family |
| `sec:rt:*` / `sec:rt:claim:*` / `sec:replay:*` | Refresh 映射、一次性消费声明和重放撤销围栏 |
| `sec:fail:*` | 登录失败锁定 |

旧 `auth:*`、`sec:v2:*` 和兼容 Key 不再由运行时读取或写入；运行时不维护双命名空间迁移逻辑。

BASE-003 的会话索引与撤销规则：`sec:ut:*` 为每个 Access 摘要保留条目，直到该 Access 及其 Refresh 都失效或被撤销；不同客户端的新会话只可延长索引 TTL，不可缩短已有 Refresh 的窗口。Access Hash 到期而 Refresh 仍有效时，撤销从 Refresh Hash 确认用户、客户端及 Family，按用户、按客户端、管理句柄和踢旧均清理该 Refresh；`ALLOW` 模式按索引覆盖同端全部会话。Refresh Hash 仍存在却缺少所属用户索引时拒绝轮换，避免先前被剔除的孤儿 Refresh 重新签发会话。索引映射或归属不一致时拒绝操作，不按状态不存在处理。此项专项验证及完整门禁边界见 [[开发指南/工程治理/2026-10-09-B02会话撤销生命周期验证|BASE-003 验证]]；B02 其余 Family 并发围栏和故障场景仍按正式台账推进。

BASE-004 的重放围栏规则：Refresh Hash、所属用户索引、一次性 claim 与 Family 围栏在单条 Redis Lua 命令内判定；重复消费先原子立围栏，再清理整个 Family。已轮换旧 Refresh 即使不在用户索引中仍按重放处理，正常孤儿 Refresh 则拒绝。签发前后与 Reader 认证均核对围栏，因此交错写入的 Session Hash 不构成可用 Access。围栏 TTL 覆盖尚存 Family 与当前 Access/Refresh 的较长有效期；Redis 未知结果拒绝操作。隔离 Redis 的可控交错、失败与策略收缩证据及双进程、恢复边界见 [[开发指南/工程治理/2026-10-09-B02重放围栏并发验证|BASE-004 验证]]。

BASE-007 的安全集合读取规则：`SecuritySessionStore.members` 对 Redis `members` 返回的 `null`、超时及连接/命令异常一律拒绝，只有 Redis 确认返回的空 Set 才代表索引为空。按用户撤销、Family 清理、在线查询和会话签发不得把未知集合当成空集合继续执行。当前源码、撤销调用方测试和隔离 Redis 正常空集合证据见 [[开发指南/工程治理/2026-10-09-B02安全集合事实源验证|BASE-007 验证]]。

BASE-018 的安全计数规则：首次计数与 TTL 必须在同一条 Redis 脚本内写入；原先独立 `expire=false` 可留下无 TTL 键的路径已消除。遗留无 TTL 计数拒绝使用并需受控清理，回包丢失时不得把结果未知解释为未计数；后续递增保留首次窗口。隔离 Redis 并发、故障注入和完整门禁边界见 [[开发指南/工程治理/2026-10-09-B02安全计数TTL验证|BASE-018 验证]]。

## Key 设计

### cacheNames 结构（强制）

```text
{system}:{domain}:{object}:{action}
```

| 字段 | 含义 | 示例 |
|---|---|---|
| system | 子系统 | `core` / `auth` |
| domain | 业务域 | `dept` / `user` |
| object | 业务对象 | `tree` / `profile` |
| action | 业务行为 | `descendants` / `detail` |

### 示例

```text
core:dept:tree:descendants
core:user:profile:detail
core:role:permission:list
```

### 禁止的 cacheNames

```
getUserById                        # 不可读
DepartmentService#getDescendantIds  # 与 Java 强绑定
user_cache                         # 无语义
```

## Key 生成策略

### 统一 KeyGenerator

```java
@Bean("standardCacheKeyGenerator")
public KeyGenerator standardCacheKeyGenerator() {
    return (target, method, params) -> {
        return DigestUtils.md5DigestAsHex(
            (target.getClass().getName()
                + "#" + method.getName()
                + Arrays.deepToString(params))
                .getBytes(StandardCharsets.UTF_8)
        );
    };
}
```

**原则**：方法名必须参与、参数顺序必须固定、禁止手写 key 字符串。

## TTL（过期时间）

### 必须设置 TTL（强制）

禁止永不过期缓存。

### 建议分级

| 类型 | TTL |
|---|---|
| 字典/树结构 | 30 min – 2 h |
| 用户信息 | 5 – 15 min |
| 权限/菜单 | 10 – 30 min |
| 高频列表 | 1 – 5 min |

## Spring Cache 注解

### @Cacheable（读缓存）

```java
@Cacheable(cacheNames = "core:dept:tree:descendants")
public Set<String> getSelfAndDescendantIds(String deptId) { ... }
```

### @CacheEvict（写后清理）

```java
@CacheEvict(cacheNames = "core:dept:tree:descendants", allEntries = true)
public void updateDepartment(...) { ... }
```

> 修改数据 → 清缓存，不要尝试"精准更新缓存"。

### @CachePut（慎用）

仅用于需要强制刷新缓存且返回值就是缓存值的场景。

## 序列化规范

- 推荐 JSON（Jackson）`GenericJackson2JsonRedisSerializer`
- 禁止 JDK 默认序列化

## Null 值策略

- 不缓存 null
- 不缓存 Optional.empty()
- 允许缓存空集合（List/Set）
- 配置 `.disableCachingNullValues()`

## 并发策略

- 一致性及可接受陈旧时间按具体业务契约定义，安全判断不能使用无法确认有效的旧授权。
- 验证写入提交后的失效、并发回填、多实例及会话隔离；不能仅凭清理注解或一次健康检查认定正确。
- 高并发缓存的同步选项按提供方及行为验证确定，不能把单个同步设置当作跨实例一致性验收。

```java
@Cacheable(cacheNames = "core:dept:tree:descendants", sync = true)
```

## 禁止事项

| 禁止 | 原因 |
|---|---|
| 普通业务缓存代替业务事实源 | 可重建缓存不承担唯一业务事实；安全状态另按事实源规则 |
| 缓存故障回源降级或伪装未命中 | 数据库和缓存均必需，故障统一拒绝 |
| cacheNames 随意命名 | 无法运维 |
| 永不过期 Key | 内存泄漏 |
| 手写 key 字符串 | 冲突风险 |
| Controller 层使用缓存 | 违反分层 |

## 相关笔记

- [[12-基础设施]] — Redis 配置与集成
- [[03-数据库命名规范]] — 数据库相关规范
- [[00-架构分层]] — 分层架构中缓存放置位置
