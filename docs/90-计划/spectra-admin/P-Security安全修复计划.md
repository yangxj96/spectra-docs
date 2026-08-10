---
tags:
  - plan
  - backend
  - security
  - authentication
  - authorization
  - redis
created: 2026-08-11
---

# P-Security 安全修复计划

## 状态

**待执行（2026-08-11 已完成静态审查与测试基线，下周进入修复）**

> 创建时间：2026-08-11
> 适用范围：`spectra-admin` 的 Spring Security、认证、账号、Redis 会话、文件访问、安全配置和相关测试。
> 关联计划：[[P-统一通知模块建设计划]]。短信、邮件和站内信属于跨业务通知能力，不在 Security 内重复实现。

## 执行摘要

当前 Security 基础方向是正确的：无状态 Bearer Token、`anyRequest().authenticated()`、方法级 `@PreAuthorize`、BCrypt、统一 401/403 和 fail-closed 数据权限已经形成基础防线。

本次审查同时确认了认证和会话实现中的高风险缺口。短信、邮件验证码固定为 `1234` 是此前为快速联调主动加入的临时实现，不视为设计意图错误；但只要相关公开接口存在于可访问环境，它仍然构成直接接管账号的路径，因此必须作为修复入口彻底移除，不能改成另一个固定值或只在代码注释中标注“测试使用”。

本计划覆盖以下问题：

1. 固定验证码、验证码发送和校验缺少用途隔离、频控和原子消费。
2. 短信/邮箱 Provider 是单例却保存请求级可变字段，存在并发串号。
3. 登录没有统一检查账号禁用、未验证、过期和用户禁用状态。
4. 手机号/邮箱绑定接收 code 但没有校验。
5. 用户状态、密码、角色、权限、数据范围变化后，旧 Redis 会话继续持有旧权限。
6. Refresh Token 复用、滑动续期、旧主体快照恢复和重放检测不足。
7. 文件预览缺少资源级访问控制。
8. 登录参数校验、异常归一、频率控制和账号枚举防护不足。
9. Actuator、CORS、Frame Header、白名单和接口加解密配置需要收口。
10. 安全关键路径几乎没有有效自动化测试。

本计划不是一次性重写 Spring Security。实施策略是先封堵可直接利用的认证路径，再修复会话撤权和资源授权，最后完成配置加固、自动化测试和文档同步。

---

## 一、审查基线

### 1.1 当前安全链路

```text
HTTP Request
  → SecurityFilterChain
  → TokenAuthenticationFilter
  → RedisSecHolderStrategy 读取 SecurityUser 快照
  → Controller @PreAuthorize
  → Service / Mapper
  → DataScopeInterceptor
```

登录链路：

```text
/auth/login
  → LoginDispatcher
  → Password/SMS/Email AuthenticationToken
  → 对应 AuthenticationProvider
  → AccountService + UserService
  → SecurityUserHelper 加载角色、权限、数据范围
  → RedisSecHolderStrategy 创建 access/refresh token
```

验证码链路：

```text
/auth/sms 或 /auth/email
  → AuthServiceImpl
  → Redis 写入固定值 1234
  → LoginSmsProvider/LoginEmailProvider 读取并删除 Redis 值
```

### 1.2 已确认问题清单

| 编号 | 优先级 | 问题 | 主要影响 |
|---|---|---|---|
| SEC-01 | P0 | SMS/EMAIL 验证码固定为 `1234` | 知道手机号或邮箱即可登录 |
| SEC-02 | P0 | Provider 保存 `currentPhone/currentEmail` 单例字段 | 并发请求可能跨账号校验 |
| SEC-03 | P0 | 登录不检查 Account/User 状态 | 禁用、未验证、过期账号仍可能登录 |
| SEC-04 | P0 | 绑定手机号/邮箱不校验验证码 | 任意地址可被标记已验证 |
| SEC-05 | P0 | 权限、状态、密码变化不撤销旧会话 | 被撤权用户继续持有旧权限 |
| SEC-06 | P1 | Refresh Token 复用和滑动续期 | 泄漏后可长期重放 |
| SEC-07 | P1 | 文件预览无资源级授权 | 登录用户可能横向读取附件 |
| SEC-08 | P1 | 验证码和登录缺少系统化限流 | 可暴力尝试、短信轰炸或恶意锁号 |
| SEC-09 | P1 | DTO 校验和 Provider 空值处理不足 | 畸形请求可能变成 500，失败计数不一致 |
| SEC-10 | P1 | Actuator/CORS/Frame/白名单过宽或漂移 | 暴露内部信息，扩大浏览器攻击面 |
| SEC-11 | P2 | 全局接口加解密密钥模型不完整 | 普通客户端不可用，密钥分发边界不清 |
| SEC-12 | P2 | 权限 INFO 日志和安全日志敏感信息 | 日志放大、手机号/邮箱等元数据泄漏 |
| SEC-13 | P1 | 认证和 Token 缺少有效测试 | 回归无法证明安全边界 |
| SEC-14 | P1 | 新用户使用共享默认密码且状态值不一致 | 初始账号容易被猜测，状态语义漂移 |

### 1.3 关键代码位置

- `spectra-security-spring-boot-starter/.../SecurityConfiguration.java`
- `spectra-security-spring-boot-starter/.../TokenAuthenticationFilter.java`
- `spectra-security-spring-boot-starter/.../RedisSecHolderStrategy.java`
- `spectra-security-spring-boot-starter/.../AuthController.java`
- `spectra-security-spring-boot-starter/.../AuthServiceImpl.java`
- `spectra-security-spring-boot-starter/.../LoginDispatcher.java`
- `spectra-security-base/.../EmailAuthenticationProvider.java`
- `spectra-security-base/.../SmsAuthenticationProvider.java`
- `spectra-security-base/.../UsernamePasswordAuthenticationProvider.java`
- `spectra-core/.../LoginEmailProvider.java`
- `spectra-core/.../LoginSmsProvider.java`
- `spectra-core/.../LoginUsernamePasswordProvider.java`
- `spectra-core/.../AccountServiceImpl.java`
- `spectra-core/.../UserServiceImpl.java`
- `spectra-core/.../SecurityUserHelper.java`
- `spectra-upload/.../FileController.java`
- `spectra-upload/.../FileUploadFacade.java`

### 1.4 测试基线

2026-08-11 审查时执行后端全量测试：

- Maven 退出码：0。
- 测试总数：66。
- failure：0。
- error：0。
- skipped：17。
- DataScope 隔离测试通过。
- 认证、验证码、刷新令牌、撤权和文件越权没有形成有效覆盖。
- `AuthControllerTest` 当前是空测试壳。

因此，现有测试通过只代表已有测试未失败，不能证明认证和会话安全。

---

## 二、目标与非目标

### 2.1 修复目标

1. 任何环境都不存在固定或可预测的短信/邮件验证码。
2. 短信和邮箱认证 Provider 完全无请求级共享状态。
3. 所有登录方式经过同一套账号和用户状态守卫。
4. 验证码按渠道、用途和接收目标隔离，校验成功后只能消费一次。
5. 手机号/邮箱绑定必须证明对目标地址的控制权。
6. 密码、用户状态、角色、权限和数据范围变化后旧权限立即失效。
7. Refresh Token 每次使用轮换，具有绝对过期时间和重放检测。
8. Redis 数据泄漏时不能直接得到可用的明文 access/refresh token 或验证码。
9. 文件读取必须同时通过功能权限和资源权限。
10. 公开接口、Actuator、CORS 和安全响应头采用最小暴露原则。
11. 登录和验证码接口具备按 IP、目标和用途的原子限流。
12. 建立能够复现和阻止每个已发现漏洞的自动化测试。
13. 修复完成后文档、配置、SQL 和实际代码一致。

### 2.2 非目标

- 不将 Bearer Token 改为 Cookie Session。
- 当前无 Cookie 认证，因此不因本计划机械地重新启用 CSRF；若以后使用 Cookie，必须重新评估。
- 不在本计划实现 OAuth2/OIDC、SSO、MFA 或通行密钥。
- 不在 Security 内实现阿里云短信或邮件 SDK，见 [[P-统一通知模块建设计划]]。
- 不重做已经 fail-closed 的数据权限拦截器；其后续演进继续由 [[P-数据权限与数据隔离重构计划]] 管理。
- 不以应用层加密替代 HTTPS/TLS。
- 不在本计划保存、生成或提交任何生产密钥。

---

## 三、总体验收架构

```text
验证码发送
  AuthController
    → VerificationCodeService.issue(purpose, channel, target, context)
      → ChannelAvailability 检查
      → RedisRateLimiter 原子限流
      → SecureRandom 生成验证码
      → Redis 保存 HMAC 摘要、TTL、失败次数
      → NotificationGateway.enqueue(...)
      → 返回统一 Accepted/Unavailable 响应

验证码认证
  LoginDispatcher
    → Stateless AuthenticationProvider
      → VerificationCodeService.consume(...)
      → AccountAuthenticationGuard.check(...)
      → SecurityUserProvider.loadActive(userId)
      → 创建 Authentication

会话
  RedisSecHolderStrategy
    → token hash 查找会话
    → 校验 session family / absolute expiry / security version
    → refresh 时原子轮换 token
    → 权限变化时按 userId 撤销全部 family
```

### 3.1 新增核心端口

建议新增以下边界：

```java
public interface VerificationCodeService {
    VerificationIssueResult issue(VerificationPurpose purpose,
            VerificationChannel channel, String target, VerificationContext context);

    void consume(VerificationPurpose purpose,
            VerificationChannel channel, String target, String code);
}
```

```java
public interface SecurityUserProvider {
    SecurityUser loadActive(UUID userId);
    long currentSecurityVersion(UUID userId);
}
```

```java
public interface SessionInvalidationService {
    void revokeUser(UUID userId, SessionRevokeReason reason);
    void revokeRoleUsers(UUID roleId, SessionRevokeReason reason);
}
```

约束：

- `VerificationCodeService` 属于 Security，通知模块不负责校验验证码。
- `SecurityUserProvider` 接口放在 `spectra-security-base`，实现放在 `spectra-core`，避免 starter 依赖业务 Entity。
- 业务 Service 不直接操作 Redis session key。
- 所有会话失效调用都带标准原因并产生安全审计事件。

---

## 四、阶段 0：执行前遏制与基线保护

### SEC-0.1 暂停不可用验证码渠道

如果当前环境可能被非可信用户访问，在正式修复前应先：

- 通过配置关闭 SMS/EMAIL 登录方式。
- 从安全白名单暂时移除对应发送接口，或由 Controller 返回统一“服务暂不可用”。
- 保留密码登录，不允许通过配置恢复固定 `1234`。
- 检查日志中是否曾输出手机号、邮箱、验证码或 Token；只做范围统计，不复制敏感内容。

建议配置：

```yaml
spectra:
  security:
    login:
      password-enabled: true
      sms-enabled: false
      email-enabled: false
```

### SEC-0.2 创建漏洞回归测试骨架

正式修改实现前，先写能够在旧代码上失败的测试：

- 固定 `1234` 不能登录。
- 两个并发手机号请求不能串号。
- disabled/unverified/expired account 不能登录。
- disabled user 不能登录。
- 未校验验证码不能绑定手机号/邮箱。
- 撤权后旧 access token 不能访问。
- refresh token 重放失败并撤销 token family。
- 用户 A 不能预览用户 B 无关联的文件。

测试应先证明旧实现存在问题，再随修复变绿。

### SEC-0.3 数据审计和备份

执行只读统计：

- Account 各 status、verified、type 的数量。
- status=0 的账号数量和类型分布。
- disabled User 对应的有效 Account 数量。
- 已过期 Account 数量。
- Redis 在线 session 数和每用户 session 数。
- 文件记录、createdBy、OA 引用关系的完整度。

只保存匿名数量，禁止把账号、Token、手机号和邮箱写入计划或日志。

---

## 五、阶段 1：验证码与无状态 Provider（P0）

### SEC-1.1 删除固定验证码实现

**修改**：

- 删除 `AuthServiceImpl` 中向 Redis 写入 `"1234"` 的代码。
- `AuthService` 改为调用 `VerificationCodeService.issue`。
- SMS/EMAIL 未配置真实 Sender 时，根据通知计划返回通道不可用，不能创建可登录的固定码。
- 单元测试中使用 Capturing Sender 获取随机码，不在生产代码增加后门。

**验收**：

- 源码和配置中搜索不到固定业务验证码。
- 连续生成的验证码不是固定值。
- 测试之外没有获取当前验证码的 HTTP 接口。

### SEC-1.2 验证码生成

规则：

- 使用 `SecureRandom` 或等价密码学安全随机源。
- 默认 6 位数字；长度可配置但生产不得小于 6 位。
- 不使用 `Random`、时间戳、手机号后几位或 UUID 截断作为验证码。
- code 只存在于方法局部变量，不成为 singleton 字段。

建议配置：

```yaml
spectra:
  security:
    verification-code:
      length: 6
      ttl: 5m
      max-attempts: 5
      resend-cooldown: 60s
      max-per-target-hour: 5
      max-per-target-day: 20
      max-per-ip-10m: 20
```

### SEC-1.3 Redis Key 和数据结构

验证码用途枚举：

```java
public enum VerificationPurpose {
    LOGIN,
    BIND_PHONE,
    BIND_EMAIL,
    RESET_PASSWORD
}
```

Redis key 不直接拼接完整手机号/邮箱，使用规范化目标的 HMAC/摘要：

```text
security:verification:{purpose}:{channel}:{targetDigest}
security:verification:cooldown:{purpose}:{channel}:{targetDigest}
security:verification:limit:target:{purpose}:{channel}:{targetDigest}:{window}
security:verification:limit:ip:{purpose}:{channel}:{ipDigest}:{window}
```

验证记录建议保存为 Redis Hash：

- `codeHash`：`HMAC-SHA256(pepper, purpose|channel|target|code)`。
- `requestId`：通知请求 ID。
- `failedAttempts`：失败次数。
- `issuedAt`：签发时间。
- `contextHash`：可选设备/流程上下文摘要。

验证码 pepper 从环境变量读取。因为验证码空间很小，普通无盐 SHA-256 不能抵抗 Redis 数据泄漏后的离线枚举。

### SEC-1.4 原子校验与消费

使用 Redis Lua 脚本或等价原子操作完成：

1. Key 不存在：返回 `EXPIRED`。
2. HMAC 相同：删除验证码 key，返回 `CONSUMED`。
3. HMAC 不同：原子增加 `failedAttempts`。
4. 达到最大次数：删除验证码 key，返回 `LOCKED`。
5. 未达到次数：返回 `MISMATCH`。

禁止采用“GET → Java 比较 → DELETE”三个独立操作，因为两个并发请求可能同时通过。

并发验收：100 个并发消费请求中最多一个成功。

### SEC-1.5 Provider 无状态重构

删除：

- `LoginEmailProvider.currentEmail`
- `LoginSmsProvider.currentPhone`
- 为获取接收目标而覆盖的 `authenticate` 方法
- 依赖共享字段的 `kaptchaValidate/kaptchaDelete`

调整基类 Provider：

- 先检查 principal/credentials 是否为空，再调用 `toString()`。
- 非预期 Authentication 类型抛出标准 `AuthenticationServiceException` 或 `BadCredentialsException`，不抛裸 `RuntimeException`。
- 将 principal、credentials 作为局部变量传递。
- SMS/EMAIL 直接调用 `verificationCodeService.consume(LOGIN, channel, target, code)`。
- 消费成功后再进入账号状态校验。
- 所有 Provider Bean 在并发环境下无可变请求字段。

### SEC-1.6 发送接口语义

现有 v1 路径可以兼容保留：

- `POST /auth/sms` 固定表示 `LOGIN + SMS`。
- `POST /auth/email` 固定表示 `LOGIN + EMAIL`。

要求：

- 接口不能允许客户端任意传入 BIND/RESET purpose。
- 对账号不存在和存在返回相同外部响应，避免枚举账号。
- 成功入队返回 202 Accepted 或保持兼容 200，但文档必须说明只是“请求已接受”。
- 通道未配置对所有目标统一返回 503，不因账号存在与否产生差异。
- 安全日志只记录 requestId、purpose、channel、结果和脱敏目标。

---

## 六、阶段 2：账号状态和认证主体（P0）

### SEC-2.1 统一状态枚举

当前 Account 注释定义：

- 1：正常
- 2：禁用
- 3：未验证

但新建默认账号写入 status=0。修复时新增强类型 `AccountStatus`，禁止散落 short magic number。

建议状态：

```java
public enum AccountStatus {
    ACTIVE((short) 1),
    DISABLED((short) 2),
    UNVERIFIED((short) 3),
    PASSWORD_RESET_REQUIRED((short) 4)
}
```

`User.status` 也应使用常量或枚举表达 ENABLED/DISABLED。

### SEC-2.2 历史数据迁移

迁移前先统计，不直接假设所有 status=0 都应启用。

建议规则：

- status=0 且已有有效登录历史、管理员确认正常：迁移 ACTIVE。
- status=0 且 verified=false 的手机号/邮箱：迁移 UNVERIFIED。
- 无法确认的账号：迁移 DISABLED 或 PASSWORD_RESET_REQUIRED，人工恢复。
- 新增数据库 CHECK 约束，拒绝未知状态。
- SQL 必须可重复验证、不可直接删除账号。

迁移脚本和最终建表 SQL同步到 `docs/sql/spectra_core/`。

### SEC-2.3 统一认证守卫

新增 `AccountAuthenticationGuard` 或同等 Service，三个 Provider 统一调用。

检查顺序：

1. Account 存在且未逻辑删除。
2. Account.type 与当前登录方式匹配。
3. Account.status 允许登录。
4. 手机号/邮箱账号 `verified=true`。
5. `expiresAt` 为空或晚于当前时间。
6. User 存在且未逻辑删除。
7. User.status 为启用。
8. 用户至少具备符合项目策略的有效角色；是否允许无角色登录需固定决策，推荐拒绝后台访问。
9. 构建当前 SecurityUser，而不是沿用旧快照。

对外错误统一为“账号或凭证错误”或“账号当前不可用”，避免泄露账号是否存在、是否禁用和具体角色信息；具体原因进入脱敏安全审计。

### SEC-2.4 SecurityUser 状态

- `SecurityUser.enabled/accountNonExpired/accountNonLocked/credentialsNonExpired` 不再无条件默认 true。
- 从当前 User/Account 状态构建相应值。
- `SecurityUser` 增加 `securityVersion` 和可选 `sessionFamilyId`。
- Refresh 时必须重新加载主体并再次执行状态守卫。
- Token Filter 至少验证 session 是否撤销、主体版本是否一致。

### SEC-2.5 初始密码策略

停止让所有新用户共享一个可直接登录的默认密码。

建议路线：

1. 管理员创建用户时，账号进入 `PASSWORD_RESET_REQUIRED`。
2. 生成一次性设置密码 Token，保存摘要和短 TTL。
3. 通过通知模块发送设置密码通知；真实邮件未接入前保持账号不可登录，由管理员走受控重置流程。
4. 如必须支持临时密码，则使用每用户独立安全随机值、仅展示一次、首次登录强制修改，并设置短过期时间。
5. 默认密码配置不得继续作为所有账号的通用有效凭证。

### SEC-2.6 登录失败统计归一

当前 Controller 只捕获 `BadCredentialsException`。调整为：

- 认证失败的 `AuthenticationException` 统一进入失败统计。
- 验证码错误、账号状态拒绝和密码错误映射到标准失败类别。
- 系统异常、Redis 不可用、数据库异常不计作用户密码错误。
- 成功登录后只清理对应维度的失败状态。
- 日志不输出用户输入的密码、验证码或 Token。

---

## 七、阶段 3：手机号/邮箱绑定（P0）

### SEC-3.1 按用途发送绑定验证码

新增或明确绑定验证码端点：

- `POST /account/bindPhone/code`
- `POST /account/bindEmail/code`

端点要求：

- 必须已登录。
- SMS 使用 `BIND_PHONE`，Email 使用 `BIND_EMAIL`。
- 与 LOGIN 验证码使用完全不同的 Redis key。
- 发送前检查格式和重复绑定，但外部错误不要泄露其他用户详情。
- 经过用户维度、目标维度和 IP 维度限流。

### SEC-3.2 绑定时原子消费

`AccountServiceImpl.bindPhone/bindEmail` 调整：

1. 规范化目标值。
2. 再次检查目标是否已经绑定，避免发送和绑定之间竞态。
3. 调用 `VerificationCodeService.consume(BIND_*, channel, target, code)`。
4. 在数据库唯一约束保护下创建 Account。
5. 只有验证码消费成功后才设置 `verified=true`、status=ACTIVE。
6. 数据库失败时验证码已经消费属于安全优先行为，用户需要重新获取；不得自动恢复已使用验证码。

数据库必须对活动手机号、邮箱建立条件唯一索引，不能只依赖 Service 的先查后写。

### SEC-3.3 解绑安全策略

- 用户不能解绑最后一个可用登录凭证，除非账号被明确禁用并由管理员处理。
- 解绑高风险账号前要求最近登录、当前密码或对应渠道验证码二次确认。
- 解绑后撤销该用户全部 session，防止旧 session 长期存在。
- 写入安全审计，不记录完整手机号/邮箱。
- 已解绑值是否允许立即绑定到其他用户，需要定义冷却期；建议保留短期安全冷却。

---

## 八、阶段 4：Session 与 Token 生命周期（P0/P1）

### SEC-4.1 Token 不以明文作为 Redis Key

Access/Refresh Token 保持高熵随机 opaque token，但 Redis 中只使用 token 的 SHA-256 摘要作为索引：

```text
security:session:access:{sha256(accessToken)}
security:session:refresh:{sha256(refreshToken)}
security:session:family:{familyId}
security:session:user:{userId}
```

随机 Token 已有足够熵，SHA-256 用于避免 Redis key/备份直接暴露可用 Bearer Token，不用 BCrypt。

### SEC-4.2 Session Family

每次初始登录创建 family：

- `familyId`
- `userId`
- `securityVersion`
- `createdAt`
- `absoluteExpiresAt`
- `lastSeenAt`
- `revokedAt/revokeReason`
- 当前 access token hash
- 当前 refresh token hash
- 客户端摘要，可选

同一用户到 family 的反向集合用于 `kick(userId)`。所有 key TTL 不得超过 family 的绝对过期时间。

### SEC-4.3 Refresh Token 每次轮换

每次成功 refresh：

1. 对 refresh token 做 hash。
2. 原子检查 token 存在、未消费、family 未撤销且未绝对过期。
3. 重新通过 `SecurityUserProvider` 加载当前用户、角色、权限和数据范围。
4. 校验 Account/User 状态和 `securityVersion`。
5. 生成新的 access token 和 refresh token。
6. 原子标记旧 refresh token 已消费，写入新 token。
7. 旧 refresh token 保留 tombstone 到 family 绝对过期，用于识别重放。

任何已消费 refresh token 再次出现：

- 判定为可能泄漏。
- 撤销整个 family。
- 记录安全告警。
- 返回统一 401，不说明内部 token 状态。

### SEC-4.4 绝对过期和续期

- Access Token：短期，例如 30 分钟。
- Refresh Token：固定绝对期限，例如 7 天。
- 普通请求可以在 `tokenRefreshInterval` 到达后节流刷新 access Redis TTL，但不得突破 family 的绝对过期时间。
- 如果不需要滑动 access TTL，删除未生效的 `tokenRefreshInterval`，避免伪配置。
- Refresh Token 的使用不能把绝对期限重新延长 7 天。
- 服务器时间使用统一 Clock，测试可注入固定时间。

### SEC-4.5 权限与账号变化立即撤销

以下操作成功后调用 `SessionInvalidationService.revokeUser`：

- 修改用户 status。
- 修改用户角色。
- 修改用户数据范围。
- 重置密码。
- 用户修改密码。
- 解绑登录账号。
- 禁用/删除 Account。
- 删除 User。

以下操作需要查出受影响用户并批量撤销：

- 角色增加/删除 Authority。
- 角色禁用或删除。
- 角色数据范围变化。
- Authority code 或语义变化。

实施规则：

- 安全优先：业务数据库写成功后立即撤销；即使事务最终回滚导致用户被多登出一次，也优于旧权限继续有效。
- 大批量角色影响使用分批撤销，记录受影响数量，不记录 token。
- `securityVersion` 每次安全身份变更递增，作为漏撤销时的第二道防线。
- Token Filter 发现版本不一致时删除当前 session 并返回 401。

### SEC-4.6 Logout 和白名单

- `/auth/logout` 要么要求有效 access token，要么允许仅凭 refresh token 做幂等撤销；当前方法标记 permitAll，建议采用后者。
- 若采用 permitAll，URL Filter 白名单必须与方法语义一致。
- Logout 响应不暴露 token 是否曾存在，重复调用仍返回成功。
- 同时传 access/refresh 时撤销同一 family；不一致时分别撤销并记录异常摘要。
- 修正 `/auth/logout` 和文件 preview 的白名单路径漂移。

### SEC-4.7 Redis 故障行为

- Redis 不可用时，受保护接口 fail-closed，不能构造匿名或空权限主体继续请求。
- Login/Refresh 返回统一服务不可用或 401，不能发放无 Redis 会话 token。
- Logout 可返回幂等结果但记录撤销失败告警；恢复后需要补偿或依赖短 access TTL。
- 指标区分 Redis 故障和用户凭证失败，避免错误锁号。

---

## 九、阶段 5：文件预览资源授权（P1）

### SEC-5.1 立即收口公开入口

- 删除 `FileController.preview` 的 `permitAll()`。
- 从匿名白名单删除错误的 `/file/preview/**`。
- 直接预览至少要求 `isAuthenticated()` 和资源访问校验。
- 不能只增加 `FILE:QUERY` 就结束修复，因为功能权限不代表可以读取任意文件。

### SEC-5.2 区分物理文件和业务引用

当前 `FileInfo` 有 hash、refCount 和秒传共享语义，单纯用 `createdBy` 判断会出现两个问题：

- 合法共享附件可能被错误拒绝。
- 相同物理文件被多个业务引用时，上传者不等于所有合法读取者。

目标模型：

```text
FileInfo（物理对象）
  └─ FileReference（逻辑引用）
       ├─ resourceType: OA_DOCUMENT / CONTRACT / NOTICE / ...
       ├─ resourceId
       ├─ ownerId
       ├─ visibility
       └─ createdBy
```

新增 `FileAccessAuthorizer` SPI：

```java
public interface FileAccessAuthorizer {
    boolean supports(String resourceType);
    FileAccessDecision canRead(UUID userId, FileReference reference);
}
```

OA/Workflow 根据业务对象的数据权限、参与关系和状态提供 Authorizer。Upload 模块不直接依赖 OA Entity。

### SEC-5.3 访问规则

允许读取的任一条件：

- 当前用户是文件未绑定业务前的临时上传者，且临时期未过。
- 当前用户是 DEV_OPS 且经过明确管理权限。
- 文件引用对应的业务 Authorizer 返回允许。
- 使用有效、短期、指定文件和用途的签名访问令牌。

默认拒绝：

- 无引用、非上传者、无管理权限。
- 业务资源已经删除或用户已失去数据范围。
- Authorizer 缺失或执行异常。

### SEC-5.4 公开分享

如果未来需要匿名预览：

- 业务 Service 先校验分享权限。
- 生成包含 fileId、用途、过期时间和随机 nonce 的签名 URL。
- 签名只能使用一次或短期有效。
- 支持主动撤销。
- 不把裸 UUID 当作授权凭证。

### SEC-5.5 文件内容安全

- HTML、SVG 等可执行内容默认强制下载，不在主站同源直接 inline。
- 响应设置正确 `Content-Type`、`Content-Disposition` 和 `X-Content-Type-Options: nosniff`。
- 如需预览不可信内容，使用独立域名或 CSP sandbox。
- 文件名进行响应头安全编码，防止 CRLF/header 注入。
- 不相信上传请求声明的 MIME，使用已有内容检测能力复核。

---

## 十、阶段 6：限流、校验和错误处理（P1）

### SEC-6.1 DTO 校验

补齐：

- `LoginFrom.type` 必填。
- PASSWORD：username/password 必填，captcha 按配置必填。
- SMS：手机号格式和 smsCode 长度必填。
- EMAIL：邮箱格式和 emailCode 长度必填。
- `SmsCodeFrom.phone` 格式校验。
- `EmailCodeFrom.email` 使用 `@Email` 和长度限制。
- `RefreshTokenFrom.refreshToken` 非空并限制最大长度。
- 所有字符串设置合理最大长度，避免超大请求进入 Redis、日志或数据库。

单一 LoginFrom 的条件字段使用类级校验器；如果实现复杂，可拆为三个明确端点，但需保留 v1 兼容层。

### SEC-6.2 规范化

- 邮箱使用项目固定规则 trim、域名小写；是否本地部分小写需明确并保持一致。
- 手机号按国家/地区策略标准化，当前中国大陆号码统一为稳定格式。
- 用户名 trim，但密码和验证码不得随意 trim 后改变语义，除非 API 契约明确。
- 规范化必须在生成 key、查询账号、限流和校验时使用同一实现。

### SEC-6.3 多维限流

验证码发送维度：

- IP + purpose。
- 目标摘要 + purpose。
- 用户 ID + purpose（已登录绑定场景）。
- 全局渠道保护。

登录尝试维度：

- IP。
- username/phone/email 摘要 + IP。
- 标识全局维度使用更高阈值，只用于风险升级，避免攻击者轻易锁死受害人。

要求：

- Redis Lua 原子计数和过期。
- 只信任明确配置的反向代理转发头，否则使用连接源 IP。
- 返回 429 和 `Retry-After`。
- 对同一接口的账号存在/不存在保持相同限流语义。
- 不把限流 key 的完整手机号/邮箱写进 Redis。

### SEC-6.4 错误响应

- 认证失败统一 401。
- 已认证但无权限统一 403。
- 限流统一 429。
- 验证码渠道未配置统一 503。
- DTO 校验统一 400。
- 不向客户端返回堆栈、Redis key、SQL、账号存在性和内部角色信息。
- 服务端审计保留标准 reasonCode，不记录敏感凭证。

---

## 十一、阶段 7：Security 配置加固（P1/P2）

### SEC-7.1 URL 白名单单一事实来源

- 公开 URL 使用精确路径和 HTTP Method，不使用过宽 `/**`。
- 方法级 `permitAll` 与 Filter 白名单必须一致。
- 为每个公开端点写匿名访问测试。
- 为所有非公开 Controller 写匿名 401 测试。
- 增加反射/架构测试：每个 RequestMapping 必须有类级或方法级 `@PreAuthorize`，公开接口显式标记。

建议公开范围仅包含：

- 登录、验证码发送（渠道启用时）、刷新、幂等注销。
- 必要的验证码图片接口。
- 精确的 health/liveness/readiness。
- 明确的静态资源或 API 文档，仅在允许环境启用。

### SEC-7.2 Actuator

开发环境也不应将所有 Actuator 端点匿名暴露：

- 匿名仅允许 `/actuator/health` 或更精确的 liveness/readiness。
- `show-details` 对匿名设为 never/when-authorized。
- metrics、env、configprops、beans、mappings、heapdump、threaddump 等只允许 DEV_OPS 或运维内网。
- 生产建议使用独立 management 端口并由网络层限制。
- Security 白名单不能继续使用整个 `/actuator/**`。

### SEC-7.3 CORS

- dev/prod 显式配置允许 Origin。
- 生产启动时发现 `originPatterns=*` 应失败或至少拒绝启用 credentials。
- Bearer Authorization 场景默认 `allowCredentials=false`。
- 若未来使用 Cookie，只允许精确 Origin 并重新启用 CSRF 防护评估。
- 限制 allowedMethods 和 allowedHeaders 到实际使用集合。
- 增加允许 Origin、拒绝陌生 Origin 和 preflight 测试。

### SEC-7.4 安全响应头

- Frame Options 使用 SAMEORIGIN，或用 CSP `frame-ancestors 'self'` 精确控制。
- 保留 `X-Content-Type-Options: nosniff`。
- 根据部署代理配置 HSTS，只在 HTTPS 生效。
- 设置合理 Referrer-Policy。
- API 错误响应同样具有安全头。
- 不为了流程设计器 iframe 全局关闭 frame protection；如确有需求，对明确页面单独配置。

### SEC-7.5 CSRF 决策

当前无状态 Authorization Bearer Token 不由浏览器自动携带，保持 CSRF disabled 是合理的。增加架构约束测试/文档：

- 认证 Token 不写入认证 Cookie。
- 如果未来加入 Cookie、Remember-Me 或浏览器自动凭据，必须重新启用并设计 CSRF Token。
- CORS 不能被当成 CSRF 的替代品。

### SEC-7.6 安全配置校验

为 `SecurityProperties` 和通知安全配置增加 Bean Validation：

- access TTL < refresh TTL。
- token 长度满足最小熵要求。
- refresh 绝对期限为正。
- 生产环境白名单不能含危险通配符。
- SMS/EMAIL enabled 时必须存在非 placeholder Sender。
- 验证码 HMAC pepper 和敏感载荷 key 缺失时安全渠道不能启动。

---

## 十二、阶段 8：接口加解密方案收口（P2）

### SEC-8.1 当前处理原则

- HTTPS/TLS 是传输安全基础。
- 应用层 `@Encrypt` 只能用于明确威胁模型下的额外保护，不能全局默认开启后再让普通客户端无法取得正确密钥。
- 在完成协议重构前，生产默认关闭全局响应加密。

### SEC-8.2 禁止事项

- 不通过普通 API 返回服务器私钥。
- 不在生成新 client key 后，使用客户端尚未拥有的私钥对应公钥加密当前响应。
- 不使用一个全局 client key 服务所有用户和设备。
- 不把 DEV_OPS 专属密钥接口写成“普通登录用户可用”的文档。
- 不把密钥、明文或完整密文调试信息写入日志。

### SEC-8.3 若保留应用层加密

需要单独完成：

- 每设备/每 session 公钥注册或协商。
- keyId、有效期、轮换和撤销。
- 请求 nonce、时间戳和重放防护。
- AEAD 或“加密 + 完整性校验”，不能只做裸加密。
- 普通客户端完整握手测试。
- 密钥端点权限、审计和恢复流程。

如果没有明确业务需求，优先删除全局私钥分发接口，只保留 TLS 和针对特定敏感字段的标准化处理。

---

## 十三、阶段 9：日志、审计与监控（P2）

### SEC-9.1 权限日志

- `SpectraPermissionEvaluator` 成功判断从 INFO 调整为 DEBUG/TRACE。
- 权限拒绝按需记录 WARN，但需限流避免扫描导致日志洪泛。
- 不记录完整 SecurityUser、Token 或数据范围目标全集。

### SEC-9.2 安全审计事件

建立标准事件：

- LOGIN_SUCCEEDED
- LOGIN_FAILED
- LOGIN_RATE_LIMITED
- VERIFICATION_CODE_REQUESTED
- VERIFICATION_CODE_RATE_LIMITED
- VERIFICATION_CODE_CONSUMED
- SESSION_REVOKED
- REFRESH_TOKEN_REUSE_DETECTED
- ACCOUNT_STATUS_CHANGED
- PASSWORD_CHANGED/RESET
- FILE_ACCESS_DENIED

审计字段：

- eventId、时间、reasonCode、userId（可空）、requestId、traceId。
- IP/设备信息使用规范化和最小必要原则。
- 手机号、邮箱、用户名按规则脱敏。

绝对禁止：

- 密码、验证码。
- access/refresh token。
- 加密私钥和通知敏感载荷。
- 完整手机号/邮箱出现在 `@ULog` 描述字符串。

### SEC-9.3 指标和告警

- 登录成功/失败/限流计数。
- 验证码请求、失败、消费、过期计数。
- refresh 成功、失败、重放检测计数。
- 在线 session family 数。
- 会话撤销数量和失败数量。
- 文件访问拒绝数量。
- Redis 安全操作延迟和错误率。

指标标签禁止使用 userId、手机号、邮箱、token 等高基数或敏感值。

---

## 十四、数据库与 Redis 迁移

### 14.1 数据库变更候选

- Account status CHECK 约束。
- Account 活动手机号/邮箱条件唯一索引。
- User `security_version BIGINT NOT NULL DEFAULT 0`。
- 可选 Account `must_change_password` 或新增状态。
- FileReference 逻辑引用表及索引。
- 通知计划中的模板、任务和 Delivery 表。

### 14.2 Redis 切换

旧 access/refresh key 与新 session family key 不兼容，推荐采用“安全强制重新登录”迁移：

1. 发布前缩短旧 access token 的剩余有效期，若条件允许。
2. 发布新版本时更换 Redis key namespace/version，例如 `security:v2:*`。
3. 新代码不读取旧 refresh token。
4. 用户重新登录创建 v2 session family。
5. 保留旧 key 到自然过期，不执行大范围危险删除命令。
6. 观察窗口结束后按精确 namespace 使用受控清理脚本。

这样会让用户重新登录，但不会让旧 refresh token 被错误转换成新会话。

### 14.3 回滚

- 数据库只新增字段、约束和表，第一阶段不删除旧字段。
- 代码回滚时新 Redis namespace 不影响旧代码。
- 回滚不得恢复固定验证码。
- 如果新 refresh 流程异常，可以临时关闭 refresh，保留短 access token，不能重新启用旧的无限滑动逻辑。
- FileReference 尚未完整回填时，默认只允许上传者和 DEV_OPS，不允许 fail-open。

---

## 十五、自动化测试矩阵

### 15.1 验证码

- [ ] 生成值不是固定 `1234`，且多次生成分布无明显固定模式。
- [ ] 不同 purpose/channel/target 的验证码不能互用。
- [ ] LOGIN code 不能用于 BIND_PHONE/BIND_EMAIL。
- [ ] 过期验证码失败。
- [ ] 错误达到最大次数后 key 失效。
- [ ] 成功验证码只能消费一次。
- [ ] 100 并发消费最多成功一次。
- [ ] Redis 中没有明文验证码和完整接收目标。
- [ ] 渠道关闭时不创建验证码。
- [ ] 通知入队失败时验证码被补偿失效。

### 15.2 Provider 并发和参数

- [ ] 两个手机号并发登录不会使用对方 target。
- [ ] 两个邮箱并发登录不会使用对方 target。
- [ ] principal/credentials/captcha 为 null 时返回 400/401，不出现 500。
- [ ] 不支持的 LoginType 返回标准错误。
- [ ] 验证码错误进入正确的失败统计。
- [ ] 系统故障不错误增加用户密码失败次数。

### 15.3 账号状态

- [ ] ACTIVE 用户和 Account 可登录。
- [ ] DISABLED Account 拒绝所有登录方式。
- [ ] UNVERIFIED 手机/邮箱 Account 拒绝登录。
- [ ] expiresAt 已过期拒绝登录。
- [ ] disabled User 拒绝登录。
- [ ] deleted Account/User 拒绝登录。
- [ ] 无效/禁用角色不会装入权限。
- [ ] PASSWORD_RESET_REQUIRED 只能进入允许的改密流程。

### 15.4 绑定

- [ ] 未发送/错误/过期 code 不能绑定。
- [ ] LOGIN code 不能绑定。
- [ ] 成功 code 只能绑定一次。
- [ ] 并发绑定同一目标只有一个成功。
- [ ] 绑定成功后 verified/status 正确。
- [ ] 不能解绑最后一个有效登录方式。
- [ ] 解绑后旧 session 失效。

### 15.5 Session 和 Token

- [ ] 登录返回高熵 access/refresh token。
- [ ] Redis key 不包含明文 token。
- [ ] access token 过期后拒绝。
- [ ] refresh 每次返回新 access 和新 refresh。
- [ ] 旧 refresh 重放撤销整个 family。
- [ ] refresh 不延长 absoluteExpiresAt。
- [ ] disabled 用户 refresh 失败。
- [ ] 权限变化后旧 access token 立即失效。
- [ ] 密码变化后所有旧 session 失效。
- [ ] 角色 Authority 变化后受影响用户旧 session 失效。
- [ ] securityVersion 不一致时 Token Filter fail-closed。
- [ ] Redis 故障时不发放 token、不匿名放行。
- [ ] logout 对不存在 token 幂等成功。

### 15.6 HTTP Security

- [ ] 未认证访问业务 API 返回 401。
- [ ] 无权限访问返回 403。
- [ ] 每个公开端点都有明确匿名访问测试。
- [ ] `/actuator/health` 匿名可用但无敏感详情。
- [ ] `/actuator/env/metrics/mappings` 匿名不可用。
- [ ] 允许 Origin 的 preflight 正常。
- [ ] 未允许 Origin 无 CORS 放行头。
- [ ] Frame/CSP/nosniff 等响应头存在。
- [ ] 公开白名单路径与真实 Controller 路径一致。

### 15.7 文件

- [ ] 上传者可以访问未绑定的临时文件。
- [ ] 无关用户不能通过 UUID 访问文件。
- [ ] OA 文档有权限用户可以预览关联文件。
- [ ] OA 文档失去数据权限后文件访问同步拒绝。
- [ ] 相同物理 hash 的不同业务引用分别授权。
- [ ] 缺少 Authorizer 时默认拒绝。
- [ ] 过期/篡改签名 URL 失败。
- [ ] HTML/SVG 不在主站同源直接执行。

### 15.8 日志和敏感信息

- [ ] 登录、验证码、绑定、refresh 日志不含凭证。
- [ ] `@ULog` 描述中手机号/邮箱已脱敏。
- [ ] 异常响应不含堆栈、Redis key 或 SQL。
- [ ] 权限成功判断不再产生每请求 INFO 日志。
- [ ] 安全指标无敏感或高基数标签。

---

## 十六、验证命令与质量门禁

每个批次至少执行：

```powershell
Set-Location spectra-admin
.\mvnw.cmd spotless:check
.\mvnw.cmd test
.\mvnw.cmd clean package -DskipTests
```

计划关闭前补充：

- Redis/PostgreSQL 集成测试。
- MockMvc 安全配置测试。
- 认证并发测试。
- 依赖漏洞扫描和 SBOM 输出；扫描结果单独审查，不自动忽略。
- `scripts/check-docs.ps1`。
- 搜索固定验证码、明文 token 日志、危险白名单和 placeholder 误启用配置。

质量门禁：

- P0/P1 测试全部通过。
- 不允许以 `@Disabled` 或 skip 方式绕过新增安全测试。
- 不允许因 Redis/Authorizer 异常而 fail-open。
- 不允许提交密钥、真实手机号/邮箱、生产 Token 或数据库密码。

---

## 十七、推荐执行批次

### 批次 A：认证紧急修复

范围：SEC-01、SEC-02、SEC-03、SEC-09、SEC-14。

- 关闭 SMS/EMAIL。
- 补测试骨架和 DTO 校验。
- Provider 无状态化。
- 账号状态守卫和状态迁移。
- 统一认证异常和失败计数。
- 处理共享默认密码策略。

### 批次 B：通知和验证码基础

依赖：[[P-统一通知模块建设计划]] 的 NT-A～NT-C。

- Notification Gateway。
- SMS/EMAIL Placeholder 和测试 Sender。
- VerificationCodeService。
- Redis HMAC、TTL、限流、原子消费。
- LOGIN/BIND 用途隔离。
- 绑定手机号/邮箱修复。

### 批次 C：会话安全

- token hash 存储。
- session family。
- refresh rotation 和 reuse detection。
- absolute expiry。
- SecurityUser 重新加载和 securityVersion。
- 用户、角色、权限、密码变更后撤销 session。

### 批次 D：资源和配置边界

- 文件预览 ACL 和 FileReference。
- Actuator 白名单。
- CORS、安全响应头和 Logout 路径。
- 权限日志和安全审计。
- 接口加解密方案默认关闭/收口。

### 批次 E：回归、扫描和文档

- 完成自动化测试矩阵。
- 依赖扫描和敏感信息扫描。
- 全量 Maven 验证。
- SQL、配置、API、实体和领域文档同步。
- 灰度与回滚演练。

推荐提交拆分：

1. `test(security): 建立认证与会话漏洞回归基线`
2. `fix(security): 移除固定验证码并重构无状态认证`
3. `fix(security): 统一账号状态校验与绑定验证`
4. `feat(security): 实现验证码限流和原子消费`
5. `fix(security): 实现会话撤销与刷新令牌轮换`
6. `fix(upload): 增加文件资源级访问控制`
7. `chore(security): 收口白名单和安全响应头`
8. `test(security): 补齐集成并发与配置测试`
9. `docs(security): 同步安全与通知方案`

---

## 十八、下周参考排期

> 这是按依赖关系给出的实施顺序，不是强制工期；通知模块完整迁移可跨出本周，但 Security 阻塞部分必须优先。

| 时段 | 主任务 | 退出条件 |
|---|---|---|
| 第 1 天 | 批次 A：测试骨架、Provider、账号状态、共享默认密码决策 | P0 认证状态测试通过，SMS/EMAIL 默认关闭 |
| 第 2 天 | 通知 NT-A～NT-C + VerificationCodeService | 随机码、Redis 摘要、限流、原子消费测试通过 |
| 第 3 天 | 绑定修复 + session family/refresh rotation | 绑定用途隔离、refresh 重放测试通过 |
| 第 4 天 | 权限变更撤销 + 文件 ACL + 配置加固 | 撤权即时生效，文件横向访问被拒绝 |
| 第 5 天 | 全量回归、并发、扫描、文档、灰度准备 | Maven/文档检查通过，P0/P1 清零或有明确延期记录 |

如果时间不足，优先顺序不可打乱：

```text
固定码/Provider/账号状态
  > 绑定验证码
  > 权限变化会话撤销
  > refresh rotation
  > 文件 ACL
  > 配置和日志加固
  > 非阻塞的通知完整迁移
```

---

## 十九、上线和灰度

### 19.1 上线前

- 确认 SMS/EMAIL 仍为 disabled 或已经配置真实非 placeholder Sender。
- 确认验证码和 Token 密钥从环境注入。
- 检查生产 CORS Origin 和 Actuator 暴露列表。
- 执行账号状态迁移预览 SQL并人工确认数量。
- 通知用户发布后需要重新登录。
- 备份数据库；Redis 不做危险全库删除。

### 19.2 上线顺序

1. 数据库向前兼容变更。
2. 通知模块和新配置，但渠道保持关闭。
3. Security 新代码和 `security:v2` namespace。
4. 验证密码登录、权限、refresh 和 Logout。
5. 使用测试/真实渠道验证后，分别开启 SMS、EMAIL。
6. 开启 Worker 和安全告警。

### 19.3 观察指标

- 401/403/429/5xx 比例。
- 登录成功率和验证码消费率。
- refresh 失败和 reuse detection 数量。
- Redis 延迟和错误。
- session 撤销失败。
- 通知 BLOCKED/FAILED/积压。
- 文件访问拒绝突增。

### 19.4 回滚触发

- 合法密码登录大面积失败。
- 新 session 无法 refresh。
- 权限错误放大或出现 fail-open。
- 通知敏感载荷无法解密。
- 文件 Authorizer 大面积误拒绝且无法快速修复。

回滚后仍需保持：

- 固定验证码不能恢复。
- SMS/EMAIL 保持关闭。
- 旧 refresh token 不自动迁移。
- 文件无法确认权限时默认拒绝。

---

## 二十、文档同步清单

代码实施后需要更新：

- `docs/10-后端/20-用户与权限.md`
- `docs/10-后端/25-数据权限设计.md`（仅会话中的数据范围快照失效部分）
- `docs/10-后端/50-文件上传.md`
- `docs/10-后端/75-统一通知模块.md`（新增）
- `docs/10-后端/80-基础设施.md`
- `docs/10-后端/85-接口加解密方案.md`
- `docs/10-后端/90-API总览.md`
- `docs/30-数据模型/20-实体清单.md`
- `docs/70-AI速查/03-实体字典.md`
- `docs/70-AI速查/04-API端点.md`
- `docs/70-AI速查/05-配置清单.md`
- `docs/00-项目总览.md`
- `docs/sql/spectra_core/建表.sql`
- Upload/Notification 新表对应 SQL。

新增/删除 Controller、Entity、配置项或模块时，按根目录 `AGENTS.md` 同步计数和速查文档。

---

## 二十一、计划完成定义

### P0 关闭条件

- [ ] 固定验证码从所有运行代码和配置中移除。
- [ ] SMS/EMAIL Provider 无共享可变请求字段。
- [ ] Account/User 禁用、未验证、过期状态在所有登录方式生效。
- [ ] 手机号/邮箱绑定真实校验专用验证码。
- [ ] 密码、状态、角色、权限和数据范围变化后旧 session 失效。
- [ ] 新账号不再共享一个可直接登录的默认密码。

### P1 关闭条件

- [ ] Refresh Token 每次轮换并检测重放。
- [ ] Token 有绝对有效期，Redis 不存明文 token key。
- [ ] 验证码有用途隔离、HMAC、TTL、频控、失败次数和原子消费。
- [ ] 文件预览具有资源级访问控制。
- [ ] Actuator、CORS、白名单和安全响应头完成收口。
- [ ] 认证、会话、文件和配置测试矩阵通过。

### 计划最终关闭条件

- [ ] P0/P1 全部完成。
- [ ] P2 未完成项有独立计划、负责人和明确风险接受，不得静默遗漏。
- [ ] 完整 Maven 测试、Spotless、构建和文档检查通过。
- [ ] 依赖和敏感信息扫描已审查。
- [ ] 发布、强制重新登录、监控和回滚演练完成。
- [ ] 代码、SQL、配置和知识库一致。

## 相关

- [[P-统一通知模块建设计划]]
- [[P-数据权限与数据隔离重构计划]]
- [[20-用户与权限]]
- [[25-数据权限设计]]
- [[50-文件上传]]
- [[80-基础设施]]
- [[85-接口加解密方案]]
- [[15-后端开发规范]]
