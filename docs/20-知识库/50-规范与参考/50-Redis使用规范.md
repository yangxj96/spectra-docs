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
> 适用于 spectra-admin 中作为缓存层使用 Redis。不含消息队列、分布式锁等特殊用法。

## 核心原则

> **Redis 是性能工具，不是业务工具**

- 只作为缓存，不作为唯一数据源
- 任何 Redis 数据都允许丢失
- Redis ≠ 数据库

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

- 采用**最终一致性**
- 允许短时间脏读
- 高并发方法开启 `sync = true`

```java
@Cacheable(cacheNames = "core:dept:tree:descendants", sync = true)
```

## 禁止事项

| 禁止 | 原因 |
|---|---|
| Redis 当数据库 | 数据允许丢失 |
| 业务强依赖 Redis | 缓存穿透风险 |
| cacheNames 随意命名 | 无法运维 |
| 永不过期 Key | 内存泄漏 |
| 手写 key 字符串 | 冲突风险 |
| Controller 层使用缓存 | 违反分层 |

## 相关笔记

- [[80-基础设施]] — Redis 配置与集成
- [[40-数据库命名规范]] — 数据库相关规范
- [[10-架构分层]] — 分层架构中缓存放置位置
