---
tags:
  - plan
  - backend
  - notification
  - security
  - oa
  - workflow
created: 2026-08-11
---

# P-统一通知模块建设计划

## 状态

**待执行（已完成现状审查与目标设计，第三方渠道仅做占位）**

> 创建时间：2026-08-11
> 适用范围：`spectra-admin`，由 Security、OA、Workflow 和后续业务模块共同使用。
> 关联主计划：[[P-Security安全修复计划]]。Security 只负责验证码生命周期和认证语义，通知模块负责可靠投递。

## 执行摘要

当前项目已经在 `spectra-core.notification` 中实现站内消息和用户通知设置，OA 的会议、请假、采购、报销、合同、文档、公告等服务直接调用 `NotificationService`。这说明通知能力不是 Security 私有能力，不能把短信和邮件实现继续堆进 `AuthServiceImpl`。

本计划把现有站内消息能力从 `spectra-core` 提取为独立 Maven 模块 `spectra-notification`，并建立统一的通知请求、模板、渠道、投递任务、幂等、重试和监控机制。业务模块可以通过统一 Gateway 请求发送站内信、短信或邮件，但不会直接依赖阿里云、腾讯云或 SMTP SDK。

本轮必须可运行的能力：

1. 独立通知模块及其 Maven 依赖关系。
2. 现有站内消息完整迁移，历史数据和 API 行为不丢失。
3. 通知请求规范、模板渲染、持久化投递任务、幂等和失败重试。
4. Security 验证码所需的随机码交付接口、敏感载荷保护和 Redis 协作。
5. 短信和邮件 Sender SPI、渠道健康状态与测试替身。
6. IN_APP 站内通知真实可用。
7. SMS/EMAIL 生成到“待调用外部供应商”之前的流程真实可用。

本轮明确不实现：

- 不引入阿里云短信、腾讯云短信或其他短信 SDK。
- 不配置真实 AccessKey、Secret、签名和短信模板 ID。
- 不连接真实 SMTP、邮件 API 或企业邮箱。
- 不以日志打印验证码来伪装短信或邮件发送成功。
- 不因为暂时没有供应商而继续使用固定验证码。

外部发送步骤使用 `PlaceholderSmsSender`、`PlaceholderEmailSender` 占位。占位实现必须返回“渠道未配置”，默认关闭，不能把任务标记为 `SENT`。

---

## 一、现状基线

### 1.1 已有站内消息能力

当前实现位于：

- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/notification/`
- `spectra-modules/spectra-core/src/main/resources/mapper/notification/`
- `spectra_core.sys_notification`
- `spectra_core.sys_notification_setting`

已有能力包括：

- 用户消息分页、未读数量、标记已读、全部已读和删除。
- 单用户发送和批量发送。
- 用户通知类型开关和免打扰设置。
- OA 多个模块直接调用 `NotificationService` 创建站内消息。

### 1.2 当前不足

| 编号 | 问题 | 影响 |
|---|---|---|
| NT-01 | 通知代码属于 `spectra-core`，调用方直接依赖具体 Service | Security、OA、Workflow 无法通过稳定端口解耦 |
| NT-02 | `send` 只是直接插入站内消息表 | 无法表达短信、邮件、重试和渠道状态 |
| NT-03 | 没有请求幂等键和投递状态机 | 事务重试可能产生重复通知 |
| NT-04 | 没有 Outbox/任务表 | JVM 崩溃或外部渠道超时后无法可靠恢复 |
| NT-05 | 没有统一模板和参数校验 | 各业务容易自行拼接内容，格式和敏感信息策略不一致 |
| NT-06 | 没有渠道 SPI | 未来接入阿里云短信时会污染认证或业务模块 |
| NT-07 | 日志监听器使用 `@Async @EventListener` | 可用于解耦，但进程退出时事件可能永久丢失 |
| NT-08 | 现有 `NotificationServiceImpl` 内部临时创建 ObjectMapper | 序列化配置不统一，JSONB 和敏感字段处理不受统一约束 |
| NT-09 | 用户设置主要针对站内类型 | 尚未表达短信、邮件的用户偏好、强制安全消息和免打扰例外 |

### 1.3 与 ULog 监听模式的关系

可以复用 ULog 的“发布事件、监听处理”思路，但不能直接复制其可靠性模型：

```text
ULog：请求结束 → 内存事件 → @Async 监听 → 保存日志
通知：业务事务 → 同事务保存通知任务 → 后台 Worker → 渠道 Sender
```

原因：

- 操作日志偶发丢失已经不理想，但通常不会改变用户是否能登录。
- 验证码、审批待办和到期提醒属于业务副作用，必须可追踪、可恢复、可重试。
- `@Async @EventListener` 在事务提交后、监听执行前发生进程崩溃时无法恢复事件。

因此：

- 普通领域事件可以由监听器转换为通知请求。
- 可靠通知最终必须在原事务内写入持久化任务。
- 真正的外部发送发生在事务提交之后，由 Worker 执行。

---

## 二、目标与非目标

### 2.1 建设目标

1. 通知能力成为独立模块，不属于 Security 或 OA。
2. Security、OA、Workflow 只依赖稳定的通知请求端口。
3. 站内信真实投递；短信和邮件完成模板与任务生成，外部调用保持占位。
4. 重要通知至少一次处理，并通过幂等保证业务效果不重复。
5. 每一条通知都可查询 `PENDING/PROCESSING/SENT/RETRYING/FAILED/CANCELLED/EXPIRED/BLOCKED` 状态。
6. 外部渠道暂未配置时明确失败，不伪造成功。
7. 敏感内容不写普通日志，不以明文长期保存在数据库。
8. 支持验证码、审批、系统告警、公告、日程和站内信等用途。
9. 不要求业务模块理解供应商、重试次数或发送协议。
10. 为未来接入消息队列保留边界，但当前不强制引入 MQ。

### 2.2 非目标

- 本计划不是营销群发平台，不实现用户画像、短信营销和复杂活动编排。
- 本计划不实现完整富文本邮件编辑器。
- 本计划不引入 Kafka、RabbitMQ 等新基础设施；先使用数据库 Outbox Worker。
- 本计划不保存或输出第三方密钥。
- 本计划不允许业务模块直接调用第三方 SDK。
- 本计划不替代安全验证码的生成、校验、次数控制和原子消费。

---

## 三、核心设计决策

### 3.1 模块边界

新增 Maven 模块：

```text
spectra-admin/
├── spectra-common/
│   └── .../common/notification/       # 最小公共端口、请求 record、枚举
├── spectra-modules/
│   ├── spectra-notification/          # 通知实现、持久化、模板、渠道、Worker
│   ├── spectra-core/                  # 用户、账号，不再拥有通知实现
│   ├── spectra-oa/                    # 通知生产者
│   └── spectra-workflow/              # 通知生产者
└── spectra-launch/                    # 装配 notification 模块
```

依赖方向：

```text
security-starter ─┐
spectra-core ─────┼──> spectra-common.notification（端口）
spectra-oa ───────┤
spectra-workflow ─┘
                         ▲
                         │ implements
                  spectra-notification
```

约束：

- `spectra-security-spring-boot-starter` 不依赖业务模块 `spectra-notification`。
- 公共端口不引用 Notification Entity、Mapper 或供应商类型。
- `spectra-notification` 可以依赖 `spectra-common`、`spectra-framework` 和必要的基础 starter，不反向依赖 OA。
- Security 通过端口提交验证码通知；运行时由 Launch 装配实现。

### 3.2 数据表归属

第一阶段保留现有表的物理位置：

- `spectra_core.sys_notification`
- `spectra_core.sys_notification_setting`

这是为了避免在 Security 修复窗口同时执行跨 schema 数据迁移。Java 包和 Maven 模块所有权先迁移到 `spectra-notification`；物理表仍在 `spectra_core` 是明确的兼容决策，不创建重复表。

新增表也先放在 `spectra_core`：

- `sys_notification_template`
- `sys_notification_task`
- `sys_notification_delivery`

如果未来要求数据库 schema 与 Maven 模块完全一致，再通过独立数据库迁移计划移动到 `spectra_notification`，不阻塞本计划关闭。

### 3.3 两类发送入口

提供统一端口：

```java
public interface NotificationGateway {
    NotificationReceipt enqueue(NotificationRequest request);
    ChannelAvailability availability(NotificationChannel channel);
}
```

使用规则：

1. 重要通知：业务 Service 直接调用 `enqueue`，在当前事务内保存任务。
2. 领域事件：监听器使用 `@TransactionalEventListener(phase = BEFORE_COMMIT)` 转换并保存任务。
3. 非事务调用：通知模块内部使用独立事务保存任务。
4. 禁止重要通知使用裸 `@Async @EventListener` 作为唯一入口。

### 3.4 渠道模型

```java
public enum NotificationChannel {
    IN_APP,
    SMS,
    EMAIL
}
```

```java
public interface NotificationSender {
    NotificationChannel channel();
    SenderAvailability availability();
    SendResult send(RenderedNotification notification);
}
```

实现：

- `InAppNotificationSender`：完整实现，写入 `sys_notification`。
- `PlaceholderSmsSender`：占位，返回 `CHANNEL_NOT_CONFIGURED`。
- `PlaceholderEmailSender`：占位，返回 `CHANNEL_NOT_CONFIGURED`。
- `CapturingSmsSender`、`CapturingEmailSender`：只存在于测试源码，捕获内容用于断言。

不得提供会在开发日志打印完整验证码的 Console Sender。

### 3.5 通知用途

渠道和用途必须分开：

```java
public enum NotificationPurpose {
    LOGIN_CODE,
    BIND_PHONE_CODE,
    BIND_EMAIL_CODE,
    RESET_PASSWORD_CODE,
    SECURITY_ALERT,
    WORKFLOW_TODO,
    WORKFLOW_RESULT,
    OA_NOTICE,
    OA_REMINDER,
    INNER_MESSAGE
}
```

用途决定：

- 是否允许用户关闭；
- 是否受免打扰控制；
- 模板参数白名单；
- 默认优先级；
- 最大有效时间；
- 是否属于敏感通知；
- 可使用的渠道集合。

验证码和安全告警属于强制安全通知，不受普通用户的营销或 OA 通知开关影响。

### 3.6 投递语义

- 系统提供“至少一次任务处理”。
- 通过 `requestId`/`idempotencyKey` 唯一约束实现业务幂等。
- Sender 必须接受同一任务可能被再次调用的事实。
- 供应商返回明确 message ID 后记录到 Delivery；未知结果不得直接重新发送，应先进入可人工核对状态。
- `SENT` 表示渠道已经接受或站内消息已经落库，不表示用户一定阅读。

---

## 四、数据模型设计

### 4.1 通知模板 `sys_notification_template`

建议字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | UUID | 主键 |
| `code` | varchar(100) | 模板唯一编码 |
| `channel` | varchar(16) | IN_APP/SMS/EMAIL |
| `purpose` | varchar(50) | 通知用途 |
| `title_template` | text | 标题模板，可空 |
| `content_template` | text | 内容模板 |
| `parameter_schema` | jsonb | 允许的参数及是否敏感 |
| `provider_template_code` | varchar(200) | 第三方模板编码，占位可空 |
| `enabled` | boolean | 是否启用 |
| `version` | bigint | 乐观锁与模板版本 |
| 审计字段 | — | 继承 BaseEntity |

模板要求：

- 使用受限占位符，不允许执行 SpEL 或任意表达式。
- 渲染前校验缺失参数和多余参数。
- 模板编码使用常量，如 `SECURITY_LOGIN_SMS_CODE`。
- 验证码模板不得把 code 之外的敏感账号信息完整输出。
- 日志只能记录模板 code、任务 ID 和脱敏接收人。

### 4.2 投递任务 `sys_notification_task`

建议字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | UUID | 任务 ID |
| `request_id` | varchar(100) | 调用方请求 ID，唯一 |
| `idempotency_key` | varchar(200) | 业务幂等键，唯一 |
| `business_type` | varchar(50) | SECURITY/WORKFLOW/OA/SYSTEM |
| `business_id` | varchar(100) | 可选业务主键 |
| `channel` | varchar(16) | 投递渠道 |
| `purpose` | varchar(50) | 通知用途 |
| `receiver_user_id` | UUID | 站内用户，可空 |
| `recipient_masked` | varchar(200) | 脱敏接收地址 |
| `recipient_ciphertext` | text | 加密后的手机号/邮箱 |
| `template_code` | varchar(100) | 模板编码 |
| `template_version` | bigint | 创建任务时锁定版本 |
| `payload` | jsonb | 非敏感模板参数 |
| `sensitive_payload_ciphertext` | text | 验证码等敏感参数密文 |
| `encryption_key_id` | varchar(50) | 密钥版本 |
| `status` | varchar(20) | 状态机 |
| `priority` | smallint | 优先级 |
| `attempt_count` | integer | 已尝试次数 |
| `max_attempts` | integer | 最大尝试次数 |
| `scheduled_at` | timestamptz | 计划发送时间 |
| `next_retry_at` | timestamptz | 下次重试时间 |
| `expires_at` | timestamptz | 过期时间 |
| `locked_by` | varchar(100) | Worker 锁持有者 |
| `locked_at` | timestamptz | 锁定时间 |
| `last_error_code` | varchar(100) | 最后错误码 |
| `trace_id` | varchar(100) | 追踪 ID |
| 审计字段 | — | 继承 BaseEntity |

索引和约束：

- `request_id` 有效记录唯一。
- `idempotency_key` 有效记录唯一。
- `(status, next_retry_at, priority, created_at)` Worker 扫描索引。
- `expires_at` 索引用于清理。
- `attempt_count >= 0`、`max_attempts > 0` 检查约束。
- 敏感任务禁止同时写入明文 `payload` 和密文载荷。

### 4.3 投递记录 `sys_notification_delivery`

每次 Sender 调用写一条记录：

- `task_id`
- `attempt_no`
- `provider`
- `provider_message_id`
- `started_at`
- `completed_at`
- `result_status`
- `error_code`
- `error_message_sanitized`
- `duration_ms`
- `response_summary`

约束：`(task_id, attempt_no)` 唯一。禁止保存第三方完整请求、验证码、Token、密钥和完整手机号/邮箱。

### 4.4 状态机

```text
PENDING ──领取──> PROCESSING ──成功──> SENT
   │                    │
   │                    ├─临时失败──> RETRYING ──到期──> PROCESSING
   │                    ├─永久失败──> FAILED
   │                    ├─渠道未配──> BLOCKED
   │                    └─已过期────> EXPIRED
   └─业务取消──────────> CANCELLED
```

规则：

- 验证码任务过期后不得继续发送。
- 占位 Sender 产生 `BLOCKED`，不进行无限重试。
- 网络超时等可重试异常使用指数退避并加随机抖动。
- 参数错误、模板缺失和渠道禁用属于永久失败。
- Worker 崩溃留下的 `PROCESSING` 超过锁超时后可重新领取。

---

## 五、验证码敏感载荷方案

### 5.1 职责边界

```text
Security VerificationCodeService
  ├─生成安全随机码
  ├─Redis 保存摘要、TTL、尝试次数
  ├─校验并原子消费
  └─构造 NotificationRequest
             │
             ▼
Notification 模块
  ├─模板渲染
  ├─任务入库
  ├─敏感载荷加密
  ├─调用渠道 Sender
  └─记录投递结果
```

通知模块不得提供 `validateCode`，Security 不得调用具体 SMS/EMAIL Sender。

### 5.2 敏感内容存储

验证码明文只允许短暂存在于：

1. Security 生成方法的局部变量。
2. 加密前的通知请求内存对象。
3. Sender 调用的局部渲染结果。

持久化规则：

- Redis 验证记录保存 HMAC 摘要，不保存固定码或可直接使用的明文码。
- 通知任务中的验证码使用 AES-GCM 等认证加密保存。
- 加密密钥只从环境变量或密钥管理系统读取，不写 YAML、SQL、文档和日志。
- 密文保存 key ID、nonce 和 ciphertext/tag，不重复使用 nonce。
- 任务成功、失败终止或过期后清理敏感密文。
- 缺少敏感载荷加密密钥时，SMS/EMAIL 安全通知渠道不得启用。

### 5.3 占位渠道行为

当前没有第三方供应商时：

- `spectra.notification.channels.sms.enabled=false`
- `spectra.notification.channels.email.enabled=false`
- 发送验证码接口在创建验证码前检查渠道可用性。
- 渠道不可用时统一返回“验证码服务暂不可用”，不写 Redis 验证码，不创建伪成功任务。
- 单元测试通过 test-scope Capturing Sender 验证模板内容和调用次数。
- 不提供读取验证码的调试 HTTP API。
- 不在 INFO/DEBUG 日志中输出验证码。

---

## 六、详细实施步骤

### 阶段 0：冻结边界与备份基线

#### NT-0.1 记录现有调用方

**操作**：

- 固定当前 `NotificationService` 公共方法签名和 API 行为。
- 列出 OA、Workbench、Controller 对 `NotificationService` 的所有调用。
- 记录现有 `sys_notification`、`sys_notification_setting` 行数和索引，仅保存匿名统计。
- 确认是否存在外部系统直接查询这两张表。

**验收**：

- 形成迁移调用清单。
- 不输出任何真实消息内容或用户信息。

### 阶段 1：创建独立模块和公共端口

#### NT-1.1 新建 `spectra-notification`

**文件**：

- `spectra-admin/spectra-modules/pom.xml` — 注册模块，放在 `spectra-core` 之前。
- `spectra-admin/spectra-modules/spectra-notification/pom.xml` — 新建模块。
- `spectra-admin/spectra-modules/spectra-notification/src/main/java/com/devops00/spectra/notification/NotificationModule.java` — 模块入口。
- `spectra-admin/spectra-launch/pom.xml` — 装配通知模块。

#### NT-1.2 新增最小公共 API

**目录**：

- `spectra-common/.../notification/NotificationGateway.java`
- `spectra-common/.../notification/NotificationRequest.java`
- `spectra-common/.../notification/NotificationReceipt.java`
- `spectra-common/.../notification/NotificationChannel.java`
- `spectra-common/.../notification/NotificationPurpose.java`
- `spectra-common/.../notification/NotificationPriority.java`
- `spectra-common/.../notification/ChannelAvailability.java`

**约束**：

- Request 使用不可变 record 或只读 DTO。
- 必须包含 `requestId`、`idempotencyKey`、`channel`、`purpose`、接收目标、模板 code 和参数。
- 不允许业务传入任意 Sender Bean 名称或供应商 code。
- 参数 Map 在进入模块后复制为不可变结构。

### 阶段 2：迁移现有站内消息

#### NT-2.1 移动 Java 包和 Mapper

**操作**：

- 将 `core.notification` 的 Entity、Mapper、Converter、Service、Controller、From 和 VO 移至 `spectra-notification`。
- 保持现有 API 路径和权限 code 不变。
- 使用注入的项目 ObjectMapper；移除方法内 `new ObjectMapper()`。
- `extra` 后续改用项目 `PgJsonbTypeHandler` 映射 JSONB；迁移前确认数据库列类型。
- 保留 `receiverId` 所有权校验。

#### NT-2.2 迁移调用方

**操作**：

- OA、Workflow、Workbench 改为依赖公共 `NotificationGateway`。
- 查询消息、已读和设置等管理能力依赖 notification 模块 Service。
- 禁止新业务继续 import `com.devops00.spectra.core.notification.*`。
- 如需平滑迁移，保留一个版本的 deprecated facade，内部只委托新模块，不复制逻辑。

#### NT-2.3 数据兼容

**操作**：

- 第一阶段不移动现有数据库表。
- 新 Entity 继续显式声明 `schema = "spectra_core"`。
- 对比迁移前后分页、未读数量、已读和删除结果。

### 阶段 3：模板与可靠任务

#### NT-3.1 新增 Entity、Mapper、Service

**新增**：

- `NotificationTemplate`
- `NotificationTask`
- `NotificationDelivery`
- `NotificationTemplateService`
- `NotificationTaskService`
- `NotificationDispatcher`
- `NotificationWorker`

写操作遵循项目规范使用事务和项目异常类型。

#### NT-3.2 入队事务

**规则**：

- `enqueue` 先校验渠道、用途、模板和参数。
- 使用数据库唯一约束处理并发幂等，不做“先查再插”的脆弱判断。
- 同一幂等键再次调用返回原任务 Receipt。
- 业务事务回滚时任务同步回滚。
- 入队成功只表示 `ACCEPTED`，不是 `SENT`。

#### NT-3.3 Worker 领取

PostgreSQL 使用 `FOR UPDATE SKIP LOCKED` 分批领取任务：

- 每批数量可配置。
- 领取时设置 `PROCESSING/locked_by/locked_at`。
- 发送不得长期持有数据库事务。
- 发送完成后使用短事务更新结果。
- 更新时校验状态和版本，避免两个 Worker 同时覆盖。

#### NT-3.4 重试策略

建议默认：

- 验证码：最多 2 次，必须在验证码 TTL 内完成。
- 普通通知：最多 5 次。
- 退避：30 秒、2 分钟、10 分钟、30 分钟，并加入随机抖动。
- `CHANNEL_NOT_CONFIGURED`、模板错误和非法接收人不重试。
- 超时且供应商结果未知时标记专用错误码，避免无条件重复发送。

### 阶段 4：渠道实现与占位

#### NT-4.1 IN_APP Sender

**必须完成**：

- 将渲染结果写入现有 `sys_notification`。
- 使用任务 ID 或幂等键避免重复插入。
- 尊重用户通知设置和免打扰规则。
- 安全告警类站内通知不允许用户关闭。

#### NT-4.2 SMS 占位 Sender

**必须完成**：

- 定义 `SmsNotificationSender` 接口和标准请求模型。
- 生成最终短信内容或供应商模板参数。
- 对手机号规范化和脱敏。
- `PlaceholderSmsSender` 返回 `CHANNEL_NOT_CONFIGURED`。
- 不引入阿里云 SDK，不发送网络请求。

**后续真实接入占位**：

```text
TODO(provider): 根据 providerTemplateCode、手机号和模板参数调用短信供应商。
TODO(provider): 将供应商 messageId 和标准错误码映射到 SendResult。
TODO(provider): 配置供应商限流、签名、区域与凭据轮换。
```

#### NT-4.3 EMAIL 占位 Sender

**必须完成**：

- 定义 `EmailNotificationSender` 接口和标准请求模型。
- 完成 subject/text/html 模板渲染和地址校验。
- `PlaceholderEmailSender` 返回 `CHANNEL_NOT_CONFIGURED`。
- 不连接 SMTP 或邮件 API。

### 阶段 5：Security 验证码接入

本阶段与 [[P-Security安全修复计划]] 的 SEC-01～SEC-04 联动。

**通知模块负责**：

- 渠道可用性查询。
- 接收验证码通知请求。
- 验证模板参数并创建加密任务。
- 使用占位或测试 Sender 处理任务。
- 返回可追踪 request/task ID。

**Security 负责**：

- 生成随机验证码。
- Redis 保存 HMAC 摘要和 TTL。
- 发送频控。
- 按用途校验并原子消费。
- 登录、绑定、重置密码的业务校验。

**失败补偿**：

- 入队失败：删除本次 Redis 验证记录，并返回通道不可用。
- 任务在发送前永久失败：通知模块发布内部失败事件；Security 可按 request ID 使验证码失效。
- 任务过期：不得继续发送已经接近或超过有效期的验证码。

### 阶段 6：配置与可观测性

#### NT-6.1 配置项

建议配置：

```yaml
spectra:
  notification:
    worker:
      enabled: true
      batch-size: 50
      lock-timeout: 2m
      poll-interval: 1s
    channels:
      in-app:
        enabled: true
      sms:
        enabled: false
        provider: placeholder
      email:
        enabled: false
        provider: placeholder
    sensitive-payload:
      key-id: ${SPECTRA_NOTIFICATION_KEY_ID:}
      key: ${SPECTRA_NOTIFICATION_KEY:}
```

规则：

- 文档只记录变量名，不记录密钥值。
- SMS/EMAIL enabled=true 且仍为 placeholder 时启动失败，或健康检查明确 DOWN；两种行为需择一固定，推荐启动失败。
- 测试配置使用测试密钥和 Capturing Sender。

#### NT-6.2 指标

- `notification_tasks_total{channel,status,purpose}`
- `notification_send_duration_seconds{channel,provider}`
- `notification_retry_total{channel,error_code}`
- `notification_queue_depth{status}`
- `notification_oldest_pending_seconds`
- `notification_channel_available{channel}`

指标不得包含手机号、邮箱、用户 ID、验证码或业务正文。

#### NT-6.3 日志与审计

INFO 只记录：

- taskId/requestId
- channel/purpose/templateCode
- status/errorCode
- 脱敏接收人

禁止记录：

- 验证码和敏感模板参数
- 完整手机号或邮箱
- AccessKey、Token 和完整第三方响应
- 加密前敏感载荷

### 阶段 7：清理与文档同步

- 删除或 deprecated 旧 `core.notification` 包。
- 更新 `docs/10-后端/15-spectra-core模块.md`。
- 新增 `docs/10-后端/75-统一通知模块.md`。
- 更新 `docs/10-后端/90-API总览.md`。
- 更新 `docs/30-数据模型/20-实体清单.md`。
- 更新 `docs/70-AI速查/03-实体字典.md`。
- 更新 `docs/70-AI速查/04-API端点.md`。
- 更新 `docs/70-AI速查/05-配置清单.md`。
- 更新 `docs/00-项目总览.md` 中模块和 Entity 数量。
- 更新 `docs/sql/spectra_core/建表.sql`。
- 运行 `scripts/check-docs.ps1`。

---

## 七、测试计划

### 7.1 单元测试

- [ ] 模板缺少必填参数时拒绝入队。
- [ ] 多余参数、非法模板占位符不能执行表达式。
- [ ] 相同幂等键返回同一任务，不重复创建。
- [ ] IN_APP Sender 重复调用不产生两条消息。
- [ ] Placeholder Sender 返回 `CHANNEL_NOT_CONFIGURED`，不返回成功。
- [ ] 测试 Sender 能捕获验证码，但生产类路径不存在该能力。
- [ ] 敏感任务不把 code 写入普通 payload。
- [ ] 日志格式不包含原始接收人和验证码。
- [ ] 免打扰跨午夜时间段判断正确。
- [ ] 强制安全通知不被普通用户设置关闭。

### 7.2 PostgreSQL 集成测试

- [ ] 业务事务回滚时通知任务不存在。
- [ ] 业务事务提交时通知任务一定存在。
- [ ] 并发相同幂等键只插入一条任务。
- [ ] 两个 Worker 使用 `SKIP LOCKED` 不领取同一任务。
- [ ] Worker 崩溃后超时任务可恢复。
- [ ] 乐观锁冲突不会覆盖已完成状态。
- [ ] 到期验证码任务进入 EXPIRED，不调用 Sender。
- [ ] 历史 `sys_notification` 数据迁移后可查询、已读和删除。

### 7.3 Security 联动测试

- [ ] 渠道关闭时验证码发送接口不写 Redis，不返回伪成功。
- [ ] Capturing Sender 收到随机验证码，Redis 仅包含摘要。
- [ ] 任务入队失败时 Redis 验证码被补偿删除。
- [ ] 同一 requestId 不会生成两条短信任务。
- [ ] 验证码日志、任务表和 Delivery 表均无明文码。

### 7.4 OA/Workflow 回归

- [ ] 请假、报销、采购和会议通知仍能写入站内消息。
- [ ] 工作流待办重复回调不会重复创建消息。
- [ ] 未读数、已读和删除 API 行为不变。
- [ ] 用户通知设置仍生效。

---

## 八、实施批次与依赖

| 批次 | 内容 | 是否阻塞 Security |
|---|---|---|
| NT-A | 公共端口、独立模块、渠道可用性、测试 Sender | 是 |
| NT-B | 模板、任务表、幂等、Worker、敏感载荷加密 | 是 |
| NT-C | SMS/EMAIL Placeholder、验证码模板 | 是 |
| NT-D | 现有站内消息迁移和 OA 调用迁移 | 否，可在 Security 后继续 |
| NT-E | 监控、管理查询、文档与完整回归 | 关闭计划前必须 |
| NT-F | 阿里云短信/真实邮件 Sender | 不在本计划，后续独立实施 |

推荐提交拆分：

1. `feat(notification): 建立统一通知端口与独立模块`
2. `feat(notification): 增加模板和可靠投递任务`
3. `feat(notification): 增加短信邮件占位渠道与敏感载荷保护`
4. `refactor(notification): 迁移现有站内消息能力`
5. `test(notification): 补充幂等重试与安全联动测试`
6. `docs(notification): 同步通知模块知识库`

---

## 九、风险与回滚

| 风险 | 预防 | 回滚 |
|---|---|---|
| 迁移后 OA 消息丢失 | 保留兼容 facade，逐调用方迁移 | 恢复旧 facade 路由到原表 |
| Worker 重复发送 | 数据库幂等键、任务状态 CAS、Sender 幂等 | 暂停 Worker，保留任务排查 |
| 敏感载荷密钥错误 | 启动校验、key ID、测试解密 | 禁用 SMS/EMAIL，不降级到明文 |
| 占位渠道被误开 | enabled+provider 联合启动校验 | 关闭渠道并将任务标记 BLOCKED |
| 任务积压 | 指标、队列深度告警、批量领取 | 暂停生产者或扩容 Worker |
| 模板升级影响在途任务 | 保存 templateVersion | 使用任务创建时版本渲染 |

回滚原则：

- 回滚不能把 SMS/EMAIL 降级成固定验证码或日志打印验证码。
- 回滚代码时保留新增任务表和数据，不执行破坏性删除。
- Worker 可以独立关闭，站内消息查询不应依赖 Worker。

---

## 十、完成定义

- [ ] `spectra-notification` 成为独立 Maven 模块并由 Launch 装配。
- [ ] Security、OA、Workflow 可通过统一端口提交通知。
- [ ] 现有站内消息和通知设置行为完整保留。
- [ ] IN_APP Sender 真实可用。
- [ ] SMS/EMAIL 模板、任务生成和状态管理真实可用。
- [ ] SMS/EMAIL 外部发送明确为占位，默认关闭且不会报告假成功。
- [ ] 验证码敏感载荷不以明文写 Redis 普通值、数据库或日志。
- [ ] 重要通知通过持久化任务可靠处理，不依赖裸异步监听器。
- [ ] 幂等、并发领取、失败重试和过期测试通过。
- [ ] Maven 全量测试、Spotless 和文档检查通过。
- [ ] 文档、SQL、实体字典、API 和配置清单全部同步。

## 相关

- [[P-Security安全修复计划]]
- [[P-通用OA业务建设总计划]]
- [[20-用户与权限]]
- [[80-基础设施]]
- [[15-spectra-core模块]]
- [[15-后端开发规范]]
