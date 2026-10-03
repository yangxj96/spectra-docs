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

安全运行态统一使用 `sec:*` 命名空间，Key 中只允许摘要或非敏感标识，不允许出现明文 Token：

| Key 前缀 | 用途 |
|---|---|
| `sec:sess:*` | Access Session 事实源 |
| `sec:uc:*` / `sec:ut:*` / `sec:online` | 用户-客户端索引、用户 Token 集合和在线用户集合 |
| `sec:family:*` / `sec:rt:family:*` | Access/Refresh Token Family |
| `sec:rt:*` / `sec:rt:claim:*` / `sec:replay:*` | Refresh 映射、一次性消费声明和重放撤销围栏 |
| `sec:fail:*` | 登录失败锁定 |

旧 `auth:*`、`sec:v2:*` 和兼容 Key 不再由运行时读取或写入；运行时不维护双命名空间迁移逻辑。

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
