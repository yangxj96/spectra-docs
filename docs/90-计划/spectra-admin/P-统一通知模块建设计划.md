---
tags:
  - plan
  - backend
  - notification
  - security
  - oa
  - workflow
created: 2026-08-11
updated: 2026-08-14
---

# P-统一通知模块建设计划

## 状态

**完成（独立模块、消息中心 Self API、可靠 Worker、收件人目录、Security/Workflow/AI 调用迁移、验证码安全契约、数据范围/受众边界、链接白名单、Mock Provider 示例、管理端脱敏运维 API、免打扰跨午夜/用户时区规则、Self API 用户 A/B 认证上下文与管理端角色矩阵回归、低基数指标/健康检查/敏感密文清理、10 项真实 PostgreSQL 事务/并发/迁移回归、Web 前端 API/Store 回归与构建、真实 HTTP 登录/Token 刷新/登出/通知隔离回归和真实浏览器交互验收均已完成；真实短信/邮件 Provider 按范围继续保持占位且默认关闭）**

> 创建时间：2026-08-11
> 最近调整：2026-08-14（完成验证码安全契约、数据范围/受众边界、链接白名单、缺失自动化测试、真实 PostgreSQL 迁移核对、真实浏览器验收，并同步完成计划收口）
> 适用范围：`spectra-admin`，由 Security、Core、OA、Workflow、AI 和后续业务模块共同使用。
> 关联计划：[[P-Security认证授权体系重构计划]]、[[P-消息中心前端实现计划]]、[[90-计划/P-运维管理中心建设计划]]。Security 只负责验证码生命周期和认证语义，通知模块负责消息中心与可靠投递；通知模板管理、受控发送和完整运维界面进入运维管理中心后续分期。

## 执行摘要

原有通知能力曾位于 `spectra-core.notification`，并由 OA 业务直接调用具体 `NotificationService`。本轮已完成通知实现迁移到 `spectra-notification`，Core 旧通知 Java/XML 映射已移除，Security、OA、Workflow 和 AI 均通过公共 `NotificationGateway` 入队；Core 仅保留收件人目录适配器。

本计划新增独立 Maven 子模块 `spectra-notification`，统一负责：

1. 消息中心：用户消息分页、详情、未读数、已读、全部已读、删除和偏好设置。
2. 统一发送：业务模块通过稳定 Gateway 提交逻辑通知，不直接操作消息表或渠道 SDK。
3. 多接收人和多渠道：一次逻辑请求可展开为多个“接收人 × 渠道”投递任务。
4. 站内信、短信、邮件：`IN_APP` 真实可用，`SMS/EMAIL` 完成标准模型、模板、任务和占位 Sender。
5. 可靠投递：持久化任务、幂等、并发领取、超时恢复、失败重试、过期和取消。
6. 数据隔离：消息中心永远按当前用户隔离；业务发送、运维查询和敏感投递记录使用不同权限边界。
7. 安全通知：验证码、绑定、重置密码和安全告警使用敏感载荷加密，不记录明文。
8. 可观测性：渠道健康、队列积压、发送耗时、失败原因和脱敏审计。

最终代码和数据所有权均归通知模块：

- Java/Maven：`spectra-modules/spectra-notification`
- Java 包：`com.devops00.spectra.notification`
- PostgreSQL schema：`spectra_notification`
- 表前缀：`ntf_`

现有 `spectra_core.sys_notification` 和 `spectra_core.sys_notification_setting` 只作为迁移来源。迁移完成后，Core 不再拥有通知 Entity、Mapper、Service、Controller 或 SQL。

本轮必须完成：

- 独立模块、公共端口和 Launch 装配。
- 专属 schema 与通知领域表。
- 旧站内消息及用户设置迁移。
- 消息中心本人数据隔离和现有 API 兼容。
- 多接收人、多渠道、模板、请求、任务、Delivery 和 Worker。
- IN_APP 真实投递及幂等。
- SMS/EMAIL 占位 Sender、地址解析、脱敏和渠道健康。
- 用户“用途 × 渠道”偏好与强制安全策略。
- Security 验证码通知联动和敏感载荷保护。
- 管理端模板、任务、重试、取消和脱敏查询接口。

本轮明确不实现：

- 不接入阿里云、腾讯云或其他真实短信 SDK。
- 不连接真实 SMTP、邮件 API 或企业邮箱。
- 不配置或提交 AccessKey、Secret、签名、邮件密码和真实供应商模板 ID。
- 不实现营销自动化、用户画像、复杂活动编排和大规模营销群发。
- 不引入 Kafka、RabbitMQ 等新基础设施，先使用 PostgreSQL Outbox Worker。
- 不实现 WebSocket/SSE 实时推送，消息中心首版继续轮询未读数。
- 不以日志、调试接口或固定验证码伪装发送成功。

外部发送步骤使用 `PlaceholderSmsSender` 和 `PlaceholderEmailSender`。占位实现必须返回 `CHANNEL_NOT_CONFIGURED`，不能把任务标记为 `SENT`。

---

## 一、现状基线与问题

### 1.1 已有能力

当前实现位于：

- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/notification/`
- `spectra-modules/spectra-core/src/main/resources/mapper/notification/`
- `spectra_core.sys_notification`
- `spectra_core.sys_notification_setting`

已有能力：

- 当前用户消息分页、未读数量、标记已读、全部已读和删除。
- 运维角色单用户发送和批量发送。
- 系统、工作流、OA、站内信、待审批类型开关及免打扰。
- OA 多个业务 Service 直接创建站内消息。

### 1.2 当前数据隔离基线

现有消息中心接口从认证上下文取得当前用户 ID，再显式添加 `receiver_id = currentUserId`：

- 列表、未读数按当前用户过滤。
- 单条已读、删除在 Service 中校验消息接收人。
- 批量删除附加当前用户条件。
- 通知设置只查询和修改当前用户记录。
- 前端不能给“我的消息”接口传入任意 `userId`。

这可以满足当前基础自服务场景，但保护来自 Service 手工条件，不来自通用 `@DataScope`。通知 Entity 没有 `@DataScope`，新增 Mapper 查询时如果遗漏所有权条件将形成横向越权。

通知收件箱也不能直接套用普通业务数据范围：

- `GLOBAL` 用户访问自己的消息中心时仍只能看本人消息。
- 部门管理员不能因为拥有 `DEPT` 范围而查看部门成员的验证码告警、审批提醒或站内信。
- 用户消息所有权是强制 `SELF`，不是角色数据范围的最大值。

因此本计划为消息中心建立独立的“当前用户所有权”规则，通用 `@DataScope` 只用于业务模块解析可发送目标，不用于扩大私人收件箱可见范围。

### 1.3 主要问题

| 编号 | 问题 | 影响 |
|---|---|---|
| NT-01 | 通知实现属于 `spectra-core` | Security、OA、Workflow 直接依赖具体 Service |
| NT-02 | 发送等于直接插入站内消息 | 无法表达短信、邮件和投递状态 |
| NT-03 | 没有逻辑请求与任务分层 | 同一业务通知无法安全展开多用户、多渠道 |
| NT-04 | 没有幂等键和任务状态机 | 事务重试可能产生重复消息 |
| NT-05 | 没有持久化 Outbox | JVM 崩溃或外部渠道超时后无法恢复 |
| NT-06 | 没有统一模板和参数白名单 | 各业务自行拼接内容，敏感策略不一致 |
| NT-07 | 没有渠道 Sender SPI | 供应商 SDK 会污染 Security 或业务模块 |
| NT-08 | 用户设置是固定布尔列 | 无法表达“用途 × 渠道”偏好 |
| NT-09 | 私人收件箱依赖手工所有权判断 | 新增查询容易遗漏 `receiver_id` 条件 |
| NT-10 | 没有运维查询权限与脱敏规则 | 任务管理可能泄露手机号、邮箱或验证码 |
| NT-11 | 当前索引与消息中心查询模式不匹配 | 收件箱和未读数增长后查询效率下降 |
| NT-12 | `extra` 的 JSONB 映射不统一 | 序列化配置、类型安全和敏感字段不可控 |

### 1.4 与异步事件的关系

```text
普通日志：请求结束 → 内存事件 → @Async 监听 → 保存日志
可靠通知：业务事务 → 同事务保存 Request/Task → 提交后 Worker → Sender
```

规则：

- 领域事件可以触发通知，但必须在 `BEFORE_COMMIT` 阶段转换为持久化请求。
- 重要通知不能把裸 `@Async @EventListener` 作为唯一入口。
- 外部网络发送只能发生在业务事务提交之后。
- 业务事务回滚时，对应通知请求和任务必须同步回滚。

---

## 二、目标与非目标

### 2.1 建设目标

1. 通知成为独立业务子模块，Core、Security、OA 和 Workflow 不再拥有通知实现。
2. 业务模块只依赖 `spectra-common.notification` 中的稳定契约。
3. 一次逻辑通知支持一个或多个接收人、一个或多个渠道。
4. 消息用途和发送渠道严格分离。
5. 消息中心只查询当前用户的站内消息，不受 `GLOBAL/DEPT/CUSTOM` 扩大。
6. 用户可以按“用途 × 渠道”配置可选通知，强制安全通知不可关闭。
7. 站内消息真实投递；短信和邮件完成投递前全流程并明确占位。
8. 重要通知至少一次处理，通过请求幂等、任务唯一约束和 Sender 幂等避免重复业务效果。
9. 每个任务可追踪、可重试、可取消、可过期、可审计。
10. 敏感内容不进入普通日志、普通 JSONB、指标标签和管理端响应。
11. 为后续真实供应商、消息队列和实时推送保留端口，不提前绑定具体实现。

### 2.2 非目标

- 不替代 Security 的验证码生成、校验、频控、次数限制和原子消费。
- 不由通知模块决定 OA、Workflow 等业务数据是否可见。
- 不允许普通用户使用通知模块绕过业务权限向任意用户发送消息。
- 不把 Delivery 任务表直接作为前端消息中心数据源。
- 不把用户“删除消息”解释为删除请求、任务或审计记录。
- 不支持匿名营销群发和任意外部联系人名单上传。

---

## 三、模块与依赖设计

### 3.1 Maven 模块

```text
spectra-admin/
├── spectra-common/
│   └── .../common/notification/        # 端口、不可变请求、枚举，不含实现
├── spectra-modules/
│   ├── spectra-notification/           # 所有通知实现
│   ├── spectra-core/                   # 用户、账号、部门、角色；实现收件人目录端口
│   ├── spectra-oa/                     # 通知生产者
│   ├── spectra-workflow/               # 通知生产者
│   └── spectra-ai/                     # 通知生产者
└── spectra-launch/                     # 装配全部模块
```

依赖方向：

```text
security-starter ─┐
spectra-core ─────┼──> spectra-common.notification <── spectra-notification
spectra-oa ───────┤                                      │
spectra-workflow ─┤                                      │ runtime ports
spectra-ai ───────┘                                      ▼
                                             CoreRecipientDirectory
```

约束：

- `spectra-notification` 不依赖 `spectra-core`、OA、Workflow 或 AI。
- `spectra-security-spring-boot-starter` 不依赖 `spectra-notification`。
- 公共端口不引用通知 Entity、Mapper、Controller、供应商 DTO 或 Spring Bean 名称。
- Core 通过公共端口实现用户、部门、角色、手机号和邮箱解析，Launch 在运行时装配。
- 通知模块不得直接查询 OA、Workflow 等业务表，只保存 `businessType/businessId/link` 等弱引用。
- 模块移除时不能破坏 Core 的编译；未装配 Gateway 时，启动应明确失败而不是静默丢通知。

### 3.2 包结构

`spectra-notification` 参考 `spectra-upload`，按简单模块扁平分层：

```text
com.devops00.spectra.notification
├── NotificationModule.java
├── configuration/
├── controller/
├── javabean/
│   ├── converter/
│   ├── domain/
│   ├── entity/
│   ├── from/
│   └── vo/
├── mapper/
├── properties/
├── service/
│   └── impl/
└── strategy/
```

Controller 统一放在 `controller`，Entity/From/VO/Converter 放在 `javabean` 对应子包，Mapper 放在 `mapper`，Service 接口与实现放在 `service`、`service/impl`，规则策略放在 `strategy`。Mapper XML 统一放在 `src/main/resources/mapper`，测试包镜像生产代码结构。

所有 Java 代码遵循项目后端规范：传统 Javadoc、瘦 Controller、Service 事务、MapStruct、项目异常和 `PgJsonbTypeHandler`。

### 3.3 公共契约

```java
public interface NotificationGateway {
    NotificationReceipt enqueue(NotificationRequest request);
    ChannelAvailability availability(NotificationChannel channel);
}
```

`NotificationRequest` 至少包含：

- `requestId`：调用方生成的请求 ID。
- `idempotencyKey`：稳定的业务幂等键。
- `purpose`：通知用途。
- `channels`：显式渠道集合；为空时按用途策略和用户偏好计算。
- `audience`：用户、地址或受控组织范围。
- `templateGroupCode`：逻辑模板组。
- `parameters`：非敏感参数。
- `sensitiveParameters`：进入模块后立即加密的敏感参数。
- `businessType/businessId`：业务弱引用。
- `sourceModule`：SECURITY/OA/WORKFLOW/AI/SYSTEM。
- `sourceDepartmentId`：业务来源部门快照，可空。
- `scheduledAt/expiresAt/priority`。
- `link`：站内消息跳转信息，必须经过允许列表校验。

Request 使用不可变 record 或只读 DTO，集合和 Map 在进入模块后复制为不可变结构。业务方不能传入 Sender Bean 名、provider 名、任务状态、重试次数或密钥 ID。

### 3.4 收件人与受众端口

公共契约定义：

- `UserAudience`：一个或多个系统用户。
- `DirectAddressAudience`：未登录验证码等场景的手机号或邮箱，只允许白名单 purpose 使用。
- `DepartmentAudience`：一个或多个部门。
- `RoleAudience`：一个或多个角色。
- `AllEnabledUsersAudience`：仅系统任务或运维专属接口允许。
- `NotificationAudienceDirectory`：由 Core 实现用户/部门/角色展开。
- `NotificationRecipientDirectory`：由 Core 实现已验证手机号、邮箱、账号状态和用户时区解析。

受众授权规则：

- 普通业务用户发起的部门/角色受众必须先经过 Core 数据范围和业务权限校验。
- SYSTEM 来源只能由内部受信任调用路径创建，HTTP 请求不能通过字段伪造为 SYSTEM。
- 管理端直接发送默认仅允许 `ROLE_DEV_OPS`，后续可拆分 `NOTIFICATION_SEND:INSERT`。
- 禁用、删除或不存在的用户不生成任务，并在 Receipt 中返回脱敏汇总。
- 普通业务模块优先提交明确用户 ID；组织广播只在确有业务需求时使用。
- `INNER_MESSAGE` 首版只允许受信任业务调用或管理端发送，不开放“任意登录用户向任意用户发站内信”的通用接口；后续若开放，必须单独设计联系人范围、反骚扰和频控。

---

## 四、核心领域模型

### 4.1 用途与渠道

```java
public enum NotificationChannel {
    IN_APP,
    SMS,
    EMAIL
}
```

```java
public enum NotificationPurpose {
    LOGIN_CODE,
    BIND_PHONE_CODE,
    BIND_EMAIL_CODE,
    RESET_PASSWORD_CODE,
    SECURITY_ALERT,
    SYSTEM_NOTICE,
    WORKFLOW_TODO,
    WORKFLOW_RESULT,
    OA_NOTICE,
    OA_REMINDER,
    INNER_MESSAGE
}
```

定义：

- `purpose` 表示“为什么通知”，决定策略、优先级、有效期、敏感性和模板。
- `channel` 表示“通过什么方式发送”。
- `INNER_MESSAGE` 是用途，`IN_APP` 是渠道；两者不能混为同一个 type。
- 前端消息中心按 purpose/category 筛选，不按底层供应商类型筛选。

### 4.2 用途策略

每个 purpose 由内置策略注册表定义：

- 默认渠道。
- 允许渠道集合。
- 是否强制送达。
- 是否允许用户关闭。
- 是否受免打扰影响。
- 默认优先级、最大重试次数和有效期。
- 是否包含敏感载荷。
- 是否允许直接地址接收人。
- 是否必须同时产生 IN_APP 消息。

首版策略：

| Purpose | 默认渠道 | 用户可关闭 | 免打扰 | 说明 |
|---|---|---:|---:|---|
| LOGIN_CODE | SMS 或 EMAIL | 否 | 否 | 仅直接地址或待认证账号 |
| BIND_PHONE_CODE | SMS | 否 | 否 | Security 强制用途 |
| BIND_EMAIL_CODE | EMAIL | 否 | 否 | Security 强制用途 |
| RESET_PASSWORD_CODE | SMS 或 EMAIL | 否 | 否 | Security 强制用途 |
| SECURITY_ALERT | IN_APP + 可用外部渠道 | 否 | 否 | 强制安全告警 |
| SYSTEM_NOTICE | IN_APP | 是 | 是 | 一般系统消息 |
| WORKFLOW_TODO | IN_APP | 是 | 是 | 可按用户偏好增加 EMAIL |
| WORKFLOW_RESULT | IN_APP | 是 | 是 | 审批结果 |
| OA_NOTICE | IN_APP | 是 | 是 | OA 公告与业务消息 |
| OA_REMINDER | IN_APP | 是 | 是 | 日程、合同等提醒 |
| INNER_MESSAGE | IN_APP | 是 | 是 | 用户间站内信 |

内置强制策略不能通过普通配置或用户偏好改成可关闭；若未来提供策略管理 API，只允许运维修改非安全用途。

### 4.3 请求与任务关系

```text
NotificationRequest（一次逻辑通知）
    ├── Recipient A × IN_APP ──> NotificationTask ──> InboxMessage
    ├── Recipient A × SMS    ──> NotificationTask ──> SmsSender
    ├── Recipient A × EMAIL  ──> NotificationTask ──> EmailSender
    ├── Recipient B × IN_APP ──> NotificationTask ──> InboxMessage
    └── Recipient B × EMAIL  ──> NotificationTask ──> EmailSender

NotificationTask
    └── 1..N NotificationDelivery（每次 Sender 尝试）
```

规则：

- `requestId` 和 `idempotencyKey` 在 Request 层唯一。
- Task 唯一键为“请求 × 接收人稳定键 × 渠道”。
- Sender 幂等键使用不可变 `taskId`。
- 同一请求重复入队返回原 Receipt，不重复展开任务。
- 用户偏好只影响可选渠道，不得关闭强制用途。
- 一个渠道失败不回滚其他已成功渠道；Request 汇总为部分成功。

### 4.4 状态机

Request 状态：

```text
ACCEPTED → DISPATCHING → SUCCEEDED
                      ├→ PARTIAL
                      ├→ FAILED
                      ├→ CANCELLED
                      └→ EXPIRED
```

Task 状态：

```text
PENDING ──领取──> PROCESSING ──成功──> SENT
   │                    │
   │                    ├─临时失败──> RETRYING ──到期──> PROCESSING
   │                    ├─永久失败──> FAILED
   │                    ├─渠道未配──> BLOCKED
   │                    ├─结果未知──> UNKNOWN
   │                    └─已过期────> EXPIRED
   └─业务取消──────────> CANCELLED
```

规则：

- `SENT` 表示站内消息已落库或外部供应商已接受，不表示用户已经阅读。
- `UNKNOWN` 表示外部调用超时且无法确认供应商是否接受，不能直接无条件重发。
- Request 状态由其 Task 状态汇总，不能由单个 Worker 随意覆盖。
- 已终止状态不能回到处理中；恢复必须经过显式管理操作并记录审计。

---

## 五、数据库设计

### 5.1 schema 与表归属

新增：

```text
spectra_notification
├── ntf_template
├── ntf_request
├── ntf_task
├── ntf_delivery
├── ntf_inbox_message
└── ntf_user_preference
```

命名遵循“前缀即边界”：通知域统一使用 `NTF_`，不继续新增 `SYS_NOTIFICATION_*`。通知表不外键依赖 OA、Workflow 等业务表；业务主键只保存为弱引用。`receiver_user_id/user_id` 也是对 Core 用户的逻辑引用，不建立跨 schema 级联删除，用户停用或删除后的历史通知仍按保留策略保存。

### 5.2 模板表 `ntf_template`

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | UUID | 主键 |
| `template_group_code` | varchar(100) | 逻辑模板组 |
| `channel` | varchar(16) | IN_APP/SMS/EMAIL |
| `purpose` | varchar(50) | 通知用途 |
| `version_no` | integer | 模板业务版本 |
| `title_template` | text | 标题模板，可空 |
| `content_template` | text | 文本内容 |
| `html_template` | text | 邮件 HTML，可空 |
| `parameter_schema` | jsonb | 参数白名单、必填和敏感标记 |
| `provider_template_code` | varchar(200) | 供应商模板编码，可空 |
| `enabled` | boolean | 是否启用 |
| `created_by/created_at/updated_by/updated_at/deleted/version` | — | 继承 `BaseEntity` |

约束：

- 有效记录唯一：`(template_group_code, channel, version_no) WHERE deleted IS NULL`。
- 同一模板组和渠道只能有一个当前启用版本。
- 使用受限占位符，不执行 SpEL、脚本或任意表达式。
- 渲染前拒绝缺失参数和多余参数。
- HTML 模板必须经过允许标签与链接协议校验。
- `parameter_schema` 使用 `PgJsonbTypeHandler`。

### 5.3 逻辑请求表 `ntf_request`

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | UUID | 内部请求 ID |
| `external_request_id` | varchar(100) | 调用方 `requestId` |
| `idempotency_key` | varchar(200) | 业务幂等键 |
| `purpose` | varchar(50) | 通知用途 |
| `template_group_code` | varchar(100) | 模板组 |
| `source_module` | varchar(50) | SECURITY/OA/WORKFLOW/AI/SYSTEM |
| `business_type` | varchar(100) | 业务类型 |
| `business_id` | varchar(100) | 业务弱引用 |
| `initiator_type` | varchar(20) | SYSTEM/USER/SERVICE |
| `initiator_user_id` | UUID | 发起用户，可空 |
| `source_department_id` | UUID | 来源部门快照，可空 |
| `parameters` | jsonb | 非敏感参数 |
| `sensitive_parameters_ciphertext` | text | 敏感参数密文 |
| `encryption_key_id` | varchar(50) | 密钥版本 |
| `status` | varchar(20) | Request 状态 |
| `recipient_count` | integer | 展开后的接收人数 |
| `task_count` | integer | 任务数 |
| `scheduled_at` | timestamptz | 计划时间 |
| `expires_at` | timestamptz | 过期时间 |
| `priority` | smallint | 请求优先级 |
| `trace_id` | varchar(100) | 追踪 ID |
| `created_by/created_at/updated_by/updated_at/deleted/version` | — | 继承 `BaseEntity` |

约束：

- `external_request_id` 有效记录唯一。
- `idempotency_key` 有效记录唯一。
- 敏感参数禁止同时出现在普通 `parameters`。
- `recipient_count >= 0`、`task_count >= 0`。
- Request 不保存完整手机号、邮箱或包含大量用户 ID 的原始受众 JSON。

### 5.4 投递任务表 `ntf_task`

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | UUID | 任务 ID，同时作为 Sender 幂等键 |
| `notification_request_id` | UUID | 关联 `ntf_request.id` |
| `channel` | varchar(16) | IN_APP/SMS/EMAIL |
| `receiver_user_id` | UUID | 系统用户，可空 |
| `recipient_key_hash` | varchar(128) | 接收人稳定哈希，非空 |
| `recipient_masked` | varchar(200) | 脱敏地址 |
| `recipient_ciphertext` | text | 手机号或邮箱密文 |
| `template_id` | UUID | 锁定模板版本 |
| `purpose` | varchar(50) | 通知用途 |
| `title/content/link/extra` | — | 渲染快照；`extra` 为 JSONB |
| `status` | varchar(20) | Task 状态 |
| `priority` | smallint | 优先级 |
| `attempt_count` | integer | 已尝试次数 |
| `max_attempts` | integer | 最大尝试次数 |
| `scheduled_at` | timestamptz | 计划时间 |
| `next_retry_at` | timestamptz | 下次重试时间 |
| `expires_at` | timestamptz | 过期时间 |
| `locked_by` | varchar(100) | Worker 标识 |
| `locked_at` | timestamptz | 锁定时间 |
| `last_error_code` | varchar(100) | 最后错误码 |
| `created_by/created_at/updated_by/updated_at/deleted/version` | — | 继承 `BaseEntity` |

约束和索引：

- 有效记录唯一：`(notification_request_id, recipient_key_hash, channel) WHERE deleted IS NULL`。
- Worker 索引：`(status, next_retry_at, priority DESC, created_at)`。
- 过期清理索引：`expires_at`。
- 用户任务索引：`(receiver_user_id, created_at DESC)`。
- `attempt_count >= 0`、`max_attempts > 0`。
- IN_APP 必须有 `receiver_user_id`。
- SMS/EMAIL 必须有密文地址和脱敏地址。

### 5.5 投递记录表 `ntf_delivery`

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | UUID | 主键 |
| `notification_task_id` | UUID | 关联 `ntf_task.id` |
| `attempt_no` | integer | 尝试序号 |
| `provider` | varchar(50) | 供应商标识 |
| `provider_message_id` | varchar(200) | 供应商消息 ID |
| `started_at` | timestamptz | 开始时间 |
| `completed_at` | timestamptz | 完成时间 |
| `result_status` | varchar(20) | 结果 |
| `error_code` | varchar(100) | 标准错误码 |
| `error_message_sanitized` | text | 脱敏错误 |
| `duration_ms` | bigint | 耗时 |
| `response_summary` | jsonb | 白名单响应摘要 |
| `created_by/created_at/updated_by/updated_at/deleted/version` | — | 继承 `BaseEntity` |

约束：`(notification_task_id, attempt_no)` 有效记录唯一。禁止保存第三方完整请求、验证码、Token、密钥、完整手机号、完整邮箱和未过滤响应。

### 5.6 消息中心表 `ntf_inbox_message`

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | UUID | 消息 ID；迁移时保留旧 ID |
| `notification_task_id` | UUID | IN_APP Task，迁移历史数据时可空 |
| `notification_request_id` | UUID | 逻辑请求，迁移历史数据时可空 |
| `receiver_user_id` | UUID | 消息所有者 |
| `purpose` | varchar(50) | 用途/分类 |
| `title` | varchar(255) | 标题 |
| `content` | text | 内容 |
| `sender_user_id` | UUID | 站内信发送人，可空 |
| `sender_name` | varchar(100) | 发送人名称快照 |
| `link` | varchar(500) | 跳转路径 |
| `is_read` | boolean | 是否已读 |
| `read_at` | timestamptz | 阅读时间 |
| `extra` | jsonb | 白名单扩展信息 |
| `created_by/created_at/updated_by/updated_at/deleted/version` | — | 继承 `BaseEntity` |

约束和索引：

- `notification_task_id` 非空时有效记录唯一，保证 Worker 重试不产生两条站内消息。
- 收件箱索引：`(receiver_user_id, created_at DESC) WHERE deleted IS NULL`。
- 未读索引：`(receiver_user_id, created_at DESC) WHERE deleted IS NULL AND is_read = false`。
- Purpose 筛选索引按实际执行计划决定是否增加 `(receiver_user_id, purpose, created_at DESC)`。
- `extra` 使用 `PgJsonbTypeHandler`，禁止保存验证码、Token、完整联系方式或权限快照。

用户删除只软删除 `ntf_inbox_message`，不删除 Request、Task 或 Delivery。

### 5.7 用户偏好表 `ntf_user_preference`

| 字段 | 类型 | 说明 |
|---|---|---|
| `id` | UUID | 主键 |
| `user_id` | UUID | 当前用户 |
| `purpose` | varchar(50) | 通知用途 |
| `channel` | varchar(16) | 渠道 |
| `enabled` | boolean | 是否启用 |
| `do_not_disturb` | boolean | 是否启用免打扰 |
| `do_not_disturb_start` | timestamptz | 开始时间，按用户时区解释 |
| `do_not_disturb_end` | timestamptz | 结束时间，按用户时区解释 |
| `created_by/created_at/updated_by/updated_at/deleted/version` | — | 继承 `BaseEntity` |

约束：

- 有效记录唯一：`(user_id, purpose, channel) WHERE deleted IS NULL`。
- 没有记录表示继承用途默认策略。
- 普通用户不能为策略禁止的渠道创建偏好。
- 强制安全用途忽略用户的关闭和免打扰设置。
- 跨午夜免打扰必须按用户时区正确判断。

---

## 六、数据范围与权限模型

### 6.1 三类数据面

| 数据面 | 主要表 | 可见性 |
|---|---|---|
| 用户自服务 | `ntf_inbox_message`、`ntf_user_preference` | 永远仅当前用户 |
| 业务发送 | `ntf_request`、受众解析 | 由调用业务权限和数据范围约束 |
| 运维与审计 | template/request/task/delivery | 独立管理权限，响应强制脱敏 |

### 6.2 消息中心强制本人隔离

规则：

- Controller 从 `SecUtil.getCurrentUserId()` 获取用户 ID。
- Self API 的 From 不包含 `userId`、`receiverUserId`。
- Service/Mapper 提供专用方法，例如 `pageMine`、`markMineAsRead`、`deleteMineById`。
- 更新和删除使用单条条件 SQL：`id = ? AND receiver_user_id = currentUserId AND deleted IS NULL`。
- 不能使用“先按 ID 查询，再无条件 updateById/removeById”的两步模式。
- 未找到或不属于当前用户统一返回“消息不存在”，不泄露记录是否存在。
- `GLOBAL`、`DEPT`、`CUSTOM` 数据范围不能扩大 Self API。
- Self VO 不返回外部收件地址、Task 密文、Delivery 错误详情和其他用户 ID。

不在 `InboxMessage`、`UserPreference` 上添加普通 `@DataScope` 来替代所有权校验，因为其角色数据范围语义与私人收件箱不一致。

### 6.3 业务发送授权

- Notification 模块验证请求结构、purpose、channel、模板和接收目标，不替代业务授权。
- OA/Workflow 等用户触发操作必须先完成业务实体数据范围和操作权限校验，再调用 Gateway。
- 业务模块不能把前端提交的任意用户 UUID 未经校验地转发给 Gateway。
- 部门/角色受众由 Core 端口按当前调用上下文展开；超出数据范围时拒绝，而不是静默扩大。
- 后台定时任务使用受信任 SYSTEM 上下文，来源由代码路径确定，不接收客户端字段。
- `businessType/businessId/sourceDepartmentId` 用于审计和管理筛选，不赋予用户读取私人消息的权限。

### 6.4 运维和审计权限

建议权限：

| 权限 | 用途 |
|---|---|
| `NOTIFICATION:QUERY/UPDATE/DELETE` | 当前用户消息中心 |
| `NOTIFICATION_SETTING:QUERY/UPDATE` | 当前用户偏好 |
| `NOTIFICATION_TEMPLATE:QUERY/INSERT/UPDATE/DELETE` | 模板管理 |
| `NOTIFICATION_TASK:QUERY` | 脱敏任务查询 |
| `NOTIFICATION_TASK:UPDATE` | 重试、取消和解除 UNKNOWN |
| `NOTIFICATION_SEND:INSERT` | 管理端直接发送 |
| `NOTIFICATION_CHANNEL:QUERY` | 渠道健康查询 |

角色边界：

- `ROLE_USER`：仅本人消息和偏好。
- `ROLE_ADMIN_SYSTEM`：不默认获得全量任务正文和直接发送权限。
- `ROLE_AUDIT`：可读取脱敏 Request/Task/Delivery，不可重试、取消或查看密文。
- `ROLE_DEV_OPS`：模板、渠道、发送、重试和取消；仍不能通过 Self API 查看他人收件箱。

管理查询必须使用独立 `/notification/admin/**` API，不能给 Self API 增加可选 `userId`。

### 6.5 敏感数据输出

任何 API、日志、指标和异常禁止输出：

- 验证码、Token、密钥和敏感模板参数。
- 完整手机号和邮箱。
- `recipient_ciphertext`、`sensitive_parameters_ciphertext`。
- 第三方完整请求或未经白名单过滤的响应。

管理端只返回：

- requestId/taskId。
- channel/purpose/template code。
- 状态、错误码、尝试次数和时间。
- 脱敏接收人。
- 业务弱引用和 traceId。

---

## 七、消息中心与管理 API

### 7.1 当前用户消息中心

保持现有路径兼容，后续可统一 REST 命名：

| 方法 | 路径 | 权限 | 说明 |
|---|---|---|---|
| GET | `/notification/list` | `NOTIFICATION:QUERY` | 当前用户分页 |
| GET | `/notification/{id}` | `NOTIFICATION:QUERY` | 当前用户详情 |
| GET | `/notification/unread-count` | `NOTIFICATION:QUERY` | 当前用户未读数 |
| PUT | `/notification/{id}/read` | `NOTIFICATION:UPDATE` | 本人消息已读 |
| PUT | `/notification/read-all` | `NOTIFICATION:UPDATE` | 本人全部已读 |
| DELETE | `/notification/{id}` | `NOTIFICATION:DELETE` | 本人软删除 |
| POST | `/notification/batch-delete` | `NOTIFICATION:DELETE` | 本人批量软删除 |
| GET | `/notification/setting` | `NOTIFICATION_SETTING:QUERY` | 当前用户偏好矩阵 |
| PUT | `/notification/setting` | `NOTIFICATION_SETTING:UPDATE` | 更新当前用户偏好 |

列表支持：

- purpose/category。
- 已读状态。
- 关键词。
- 创建时间范围。
- 分页和创建时间倒序。

前端消息中心只查询 `ntf_inbox_message`，不直接查询 Task/Delivery。后续如果展示短信或邮件发送结果，由消息详情返回脱敏渠道摘要，不暴露底层表。

### 7.2 管理 API

| 方法 | 路径 | 权限 | 说明 |
|---|---|---|---|
| GET | `/notification/admin/templates` | `NOTIFICATION_TEMPLATE:QUERY` | 模板分页 |
| POST | `/notification/admin/templates` | `NOTIFICATION_TEMPLATE:INSERT` | 新建模板版本 |
| PUT | `/notification/admin/templates/{id}` | `NOTIFICATION_TEMPLATE:UPDATE` | 修改模板 |
| DELETE | `/notification/admin/templates/{id}` | `NOTIFICATION_TEMPLATE:DELETE` | 软删除模板 |
| GET | `/notification/admin/requests` | `NOTIFICATION_TASK:QUERY` | 请求汇总查询 |
| GET | `/notification/admin/tasks` | `NOTIFICATION_TASK:QUERY` | 脱敏任务查询 |
| GET | `/notification/admin/tasks/{id}/deliveries` | `NOTIFICATION_TASK:QUERY` | 脱敏尝试记录 |
| POST | `/notification/admin/tasks/{id}/retry` | `NOTIFICATION_TASK:UPDATE` | 合法状态重试 |
| POST | `/notification/admin/tasks/{id}/cancel` | `NOTIFICATION_TASK:UPDATE` | 取消未终止任务 |
| POST | `/notification/admin/send` | `NOTIFICATION_SEND:INSERT` | 受控直接发送 |
| GET | `/notification/admin/channels` | `NOTIFICATION_CHANNEL:QUERY` | 渠道健康 |

Controller 只转发参数；重试、取消、状态校验、受众授权和脱敏全部在 Service 完成。

---

## 八、模板、偏好与渠道选择

### 8.1 模板选择

- 业务只传 `templateGroupCode`，不传具体 provider 模板 ID。
- Dispatcher 按 `templateGroupCode + channel` 锁定当前启用版本。
- Task 保存 `templateId`，在途任务不受后续模板升级影响。
- 渲染参数必须先按 `parameter_schema` 校验。
- 模板缺失、渠道不匹配或参数非法属于永久失败。

### 8.2 渠道计算

计算顺序：

1. 读取 purpose 内置策略。
2. 校验调用方显式请求的渠道是否在允许集合内。
3. 未显式传渠道时使用 purpose 默认渠道。
4. 对系统用户合并其偏好。
5. 强制用途覆盖用户关闭和免打扰。
6. 检查渠道是否启用、收件地址是否存在且已验证。
7. 为每个接收人和最终渠道生成唯一 Task。

行为：

- 强制安全渠道不可用时，入队前失败，不生成不可用验证码。
- 非强制多渠道请求中，一个渠道不可用可生成 `BLOCKED` 任务，其他渠道继续。
- 用户关闭可选渠道时不生成任务，并在 Request 汇总中记录跳过数量，不把它视为发送失败。
- 免打扰期间可延迟到结束时间；如果超过 `expiresAt` 则直接 `EXPIRED`。

### 8.3 收件地址

- 系统用户手机号和邮箱通过 `NotificationRecipientDirectory` 获取，不由普通业务请求重复传递。
- 只使用已验证、启用且符合格式的联系方式。
- 登录、绑定和重置密码可使用 `DirectAddressAudience`，但 purpose 必须在安全白名单中。
- 地址进入通知模块后立即规范化、生成哈希、脱敏并加密。
- 日志只记录脱敏地址和 recipient hash 的短前缀。

---

## 九、可靠投递

### 9.1 入队事务

- `enqueue` 在同一事务内校验请求、插入 Request、展开受众并插入 Task。
- 使用数据库唯一约束处理并发幂等，不采用“先查再插”作为唯一保护。
- 相同幂等键重复调用返回原 Request Receipt。
- 业务事务回滚时 Request 和 Task 同步回滚。
- 非事务调用由通知模块开启普通事务。
- 入队成功只表示 `ACCEPTED`，不是 `SENT`。

### 9.2 Worker 领取

PostgreSQL 使用 `FOR UPDATE SKIP LOCKED` 分批领取：

- 只领取到期的 `PENDING/RETRYING`。
- 领取短事务更新 `PROCESSING/locked_by/locked_at` 后立即提交。
- 外部发送不长期持有数据库事务。
- Sender 完成后使用短事务插入 Delivery 并 CAS 更新 Task。
- 两个 Worker 不能领取同一任务。
- `PROCESSING` 超过锁超时后由恢复任务重新置为可领取状态。

### 9.3 重试

建议默认：

- 验证码最多 2 次，且必须在验证码 TTL 内。
- 普通通知最多 5 次。
- 退避：30 秒、2 分钟、10 分钟、30 分钟，并加入随机抖动。
- 网络错误、限流和明确临时供应商错误可重试。
- 模板错误、非法收件人、渠道关闭和认证失败不重试。
- 超时且结果未知进入 `UNKNOWN`，先人工或供应商查询确认。
- 手工重试必须记录操作用户、原因和原状态。

### 9.4 IN_APP 幂等

`InAppNotificationSender`：

- 使用 `notification_task_id` 插入 `ntf_inbox_message`。
- `notification_task_id` 唯一冲突视为幂等成功，返回已有消息 ID。
- 写入 title/content/purpose/link/extra 的渲染快照。
- 不依赖 Task 查询来展示历史消息。
- 用户删除收件箱消息不影响 Task 的 SENT 状态。

---

## 十、渠道 Sender

### 10.1 统一 SPI

```java
public interface NotificationSender {
    NotificationChannel channel();
    SenderAvailability availability();
    SendResult send(RenderedNotification notification);
}
```

Sender 只负责单个任务的一次发送，不负责：

- 业务授权。
- 受众展开。
- 用户偏好。
- 重试调度。
- Request 状态汇总。
- 记录敏感请求日志。

### 10.2 IN_APP

- 完整实现并默认启用。
- 写入 `ntf_inbox_message`。
- 使用 taskId 幂等。
- 支持标题、正文、purpose、发送人、link 和白名单 extra。

### 10.3 SMS

本轮：

- 定义标准短信请求模型。
- 完成手机号规范化、脱敏、加密、模板参数和长度检查。
- `PlaceholderSmsSender` 返回 `CHANNEL_NOT_CONFIGURED`。
- `CapturingSmsSender` 只存在于 test scope。
- 不引入供应商 SDK，不发送网络请求，不打印短信正文。

后续真实接入：

- provider adapter 将供应商 messageId 和错误码映射到标准 `SendResult`。
- 配置签名、区域、凭据轮换、限流、超时和健康检查。
- 尽可能把 taskId 作为供应商幂等或业务流水号。

### 10.4 EMAIL

本轮：

- 定义标准邮件请求模型。
- 完成地址校验、subject/text/html 渲染和 HTML 白名单。
- `PlaceholderEmailSender` 返回 `CHANNEL_NOT_CONFIGURED`。
- `CapturingEmailSender` 只存在于 test scope。
- 不连接 SMTP 或邮件 API。

后续真实接入：

- provider adapter 处理 messageId、退信和临时/永久失败映射。
- 配置发件人、回复地址、TLS、凭据和速率限制。

---

## 十一、验证码敏感载荷

### 11.1 职责边界

```text
Security VerificationCodeService
  ├─生成安全随机码
  ├─Redis 保存 HMAC 摘要、TTL 和尝试次数
  ├─校验并原子消费
  └─构造 NotificationRequest
             │
             ▼
Notification
  ├─检查渠道可用性
  ├─加密敏感参数和收件地址
  ├─创建 Request/Task
  ├─模板渲染与 Sender
  └─记录脱敏投递结果
```

通知模块不提供 `validateCode`；Security 不调用具体 SMS/EMAIL Sender。

### 11.2 存储规则

验证码明文只允许短暂存在于：

1. Security 生成方法局部变量。
2. 加密前的内存请求。
3. Sender 调用的局部渲染结果。

持久化规则：

- Redis 只保存 HMAC 摘要，不保存固定码或可直接使用的明文。
- Request 的验证码使用 AES-GCM 等认证加密。
- 密钥只从环境变量或密钥管理系统读取。
- 密文保存 key ID、nonce 和 ciphertext/tag，不重复 nonce。
- 成功、永久失败或过期后按保留策略清理敏感密文。
- 缺少敏感载荷密钥时 SMS/EMAIL 安全用途不能启用。

### 11.3 占位渠道

- 验证码创建前先检查目标渠道可用性。
- 渠道不可用时返回“验证码服务暂不可用”。
- 不写 Redis 验证记录，不创建伪成功 Request。
- 入队失败时删除本次 Redis 验证记录。
- 任务在发送前永久失败时发布内部失败事件，Security 按 requestId 使验证码失效。
- 不提供读取验证码的调试 HTTP API。

---

## 十二、配置与可观测性

### 12.1 配置

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
- SMS/EMAIL `enabled=true` 且 provider 仍为 placeholder 时启动失败。
- IN_APP 关闭时消息中心健康检查明确 DOWN。
- 测试配置只使用测试密钥和 Capturing Sender。

### 12.2 指标

- `notification_requests_total{purpose,status}`
- `notification_tasks_total{channel,status,purpose}`
- `notification_send_duration_seconds{channel,provider}`
- `notification_retry_total{channel,error_code}`
- `notification_queue_depth{status}`
- `notification_oldest_pending_seconds`
- `notification_channel_available{channel}`

指标标签不得包含用户 ID、手机号、邮箱、验证码、businessId 或正文，避免高基数和敏感泄露。

### 12.3 日志与审计

INFO 只记录：

- requestId/taskId。
- channel/purpose/templateGroupCode。
- status/errorCode。
- 脱敏接收人。

管理操作额外记录：

- 操作用户。
- 原状态和目标状态。
- 重试或取消原因。

禁止记录验证码、敏感参数、完整地址、密钥、Token 和完整第三方响应。

### 12.4 数据保留

首版保留策略通过配置实现：

- Inbox 由用户软删除，系统按产品策略归档或清理。
- Delivery 保存脱敏审计，不保存正文。
- 成功任务的敏感密文尽快清除。
- 失败和 UNKNOWN 任务只在排障窗口内保留密文。
- 到期验证码任务立即清理验证码密文。
- 清理任务使用批处理并记录匿名数量，不打印内容。

---

## 十三、迁移与实施步骤

### 阶段 0：冻结基线

- 记录所有 `NotificationService` 调用方和现有 API。
- 记录旧两张表的匿名行数、索引、约束和字段类型。
- 确认是否有外部系统直接查询旧表。
- 为列表、未读、已读、删除、批量删除和设置补迁移前回归测试。
- 禁止输出真实消息正文和用户信息。

### 阶段 1：公共契约与独立模块

- [x] 在 `spectra-common.notification` 新增 Gateway、Request、Receipt、Channel、Purpose、Priority、直接地址和收件人目录端口。
- [x] 新建 `spectra-modules/spectra-notification`。
- [x] 注册到 `spectra-modules/pom.xml` 和 `spectra-launch/pom.xml`。
- [x] 新增 `NotificationModule`、配置属性和模块级测试。
- [x] 验证不存在 notification → core/oa/workflow 的 Maven 反向依赖。

### 阶段 2：专属 schema 与领域模型

- [x] 新增 `docs/sql/spectra_notification/建表.sql`。
- [x] 创建 `spectra_notification` schema 和六张 `ntf_*` 表。
- [x] 实现 Template、Request、Task、Delivery、InboxMessage、UserPreference Entity/Mapper/Service/Converter。
- [x] 所有 JSONB 使用 `PgJsonbTypeHandler`。
- [x] 实现请求和任务唯一约束、收件箱复合索引、Worker 索引和检查约束。
- [x] 增加早期 `ntf_*` 表到标准字段模型的幂等规范化迁移脚本，保留旧列供发布窗口核对。

### 阶段 3：迁移消息中心

- [x] 将旧 `sys_notification` 数据复制到 `ntf_inbox_message`，保留 ID、接收人、已读状态、创建时间和软删除状态。
- [x] 将旧 type 映射为新 purpose：
  - system → SYSTEM_NOTICE
  - workflow → `extra` 可明确识别审批结果时映射 WORKFLOW_RESULT，否则映射 WORKFLOW_TODO
  - oa → OA_NOTICE
  - inner_mail → INNER_MESSAGE
  - approval → WORKFLOW_TODO
- [x] 将旧 `extra` 校验后迁移为 JSONB；非法历史值进入空对象并记录匿名计数。
- [x] 将旧固定设置展开为 `ntf_user_preference` 多行记录：system、workflow、oa、inner_mail、approval 分别映射到对应 IN_APP purpose；原免打扰复制到所有可选用途。
- [x] 旧系统没有 SMS/EMAIL 偏好，迁移时不自动生成“已启用”的外部渠道记录；非安全外部渠道继续继承默认关闭策略，避免供应商启用后突然发送历史用户未选择的邮件或短信。
- [x] 迁移脚本可重复执行且不会重复插入。
- [x] 对比迁移前后行数、用户未读数和抽样匿名校验。
- [x] 切换读写后保留旧表只读观察一个发布窗口，再由独立清理计划处理，不立即 DROP。

### 阶段 4：Self API 与数据隔离

- [x] 移动 NotificationController、SettingController 及相关 From/VO 到新模块。
- [x] 保持现有 API 路径和权限编码兼容。
- [x] 实现 `pageMine/detailMine/markMineAsRead/markAllMineAsRead/deleteMineById/deleteMineBatch`。
- [x] 所有更新和删除使用带 `receiver_user_id` 的单条条件 SQL。
- [x] Self API 不接受 userId。
- [x] 增加 Self API 用户 A/B 认证上下文切换、匿名拒绝和混合批量 ID 绑定回归。
- 增加真实数据库跨用户、GLOBAL 角色和混合批量 ID 越权测试。

### 阶段 5：请求、模板与可靠 Worker

- [x] 实现 `NotificationGateway`。
- [x] 实现 purpose 策略、模板选择、参数校验和渠道计算；用户目录展开和受限安全直接地址均由 Gateway 处理。
- [x] 实现 Request/Task 状态机和汇总。
- [x] 实现 `FOR UPDATE SKIP LOCKED` 领取、锁超时恢复、CAS 更新和指数退避。
- [x] 实现管理端 Request/Task/Delivery 脱敏查询、渠道状态、重试和取消。

### 阶段 6：渠道实现

- [x] 完整实现 `InAppNotificationSender` 和 taskId 幂等。
- [x] 实现 SMS/EMAIL 标准模型、地址解析、脱敏和密文存储。
- [x] 实现 Placeholder Sender；新增 test-scope `MockSmsSender` 和 `MockEmailSender` 示例，不进入生产运行时。
- [x] 实现渠道可用性、模块开关校验和管理端健康检查。

### 阶段 7：调用方迁移

- [x] Security、OA、Workflow、AI 改为依赖 `NotificationGateway`；Core 提供收件人目录适配器。
- [x] Security 验证码改为通过 Gateway 交付。
- [x] 禁止新增 `com.devops00.spectra.core.notification.*` import。
- 如需过渡，旧 facade 只委托新 Gateway，不复制业务逻辑。
- [x] 每迁移一个调用方都定义稳定的 idempotencyKey。

建议幂等键：

```text
security:{purpose}:{requestNonce}
workflow:todo:{taskId}:{assigneeId}
workflow:result:{processInstanceId}:{userId}:{result}
oa:meeting:{meetingId}:{userId}:{event}
oa:contract-reminder:{milestoneId}:{userId}
```

### 阶段 8：配置、监控和文档

- [x] 增加通知配置项、低基数指标、健康检查、敏感密文清理任务和脱敏日志边界。
- 更新项目总览、架构、API、ER、实体清单和 AI 速查。
- [x] 新增并同步 `docs/10-后端/75-统一通知模块.md`。
- [x] 更新前端消息中心计划中的 purpose、偏好和详情接口。
- [x] Web 前端消息中心 API/Store 自动化回归和生产构建已通过。
- [x] Maven 全量测试和 `scripts/check-docs.ps1` 最终校验已通过（64 个 Entity、42 个 Controller）。
- [x] Spotless 全量格式检查已通过。
- [x] 使用长期保留的 `codex-notify-*` 测试账号完成真实 HTTP 登录、Bearer Token、Token 刷新/登出、消息隔离、偏好隔离和管理端角色矩阵回归；真实浏览器交互验收已完成。

---

## 十四、测试计划

### 14.1 单元测试

- [x] purpose 与 channel 分离，非法组合拒绝。
- [x] 模板缺少参数、非法占位符和多余参数均拒绝。
- [x] HTML 模板不允许脚本和非法协议。
- [x] 相同幂等键返回同一 Request。
- [x] 一次请求按“接收人 × 渠道”正确展开 Task。
- [x] Worker 成功、过期、失败重试和 Delivery 任务边界回归。
- [x] 管理端地址、错误、投递摘要脱敏和 ROLE_DEV_OPS/ROLE_AUDIT 注解边界。
- [x] SQL 建表/迁移结构契约检查；真实 PostgreSQL 事务和并发基线已在显式开启的集成测试中通过。
- [x] 用户关闭可选渠道时跳过，不关闭强制安全用途。
- [x] 免打扰跨午夜和用户时区判断正确；旧设置时间按当前用户时区解析并回显。
- [x] IN_APP 重复调用不产生重复消息。
- [x] Placeholder 返回 `CHANNEL_NOT_CONFIGURED`。
- [x] Mock SMS/EMAIL Sender 仅在测试类路径可用。
- [x] 管理端 VO 不包含原始地址、验证码和密文；Worker 写入前脱敏 Provider 摘要，日志仅记录任务 ID/状态。
- [x] 指标/健康检查/清理任务开关、批量和敏感载荷清理回归。
- [x] Web 前端消息中心 API 路径、查询条件、已读/批量删除状态同步回归。

### 14.2 数据隔离测试

- [x] Self API/管理端权限注解覆盖、用户 A/B 认证上下文切换和消息中心 Service 收件人条件契约回归。
- [x] 用户 A 不能分页、详情、已读或删除用户 B 的消息（认证上下文和 Service 条件回归）。
- [x] 混合批量删除只影响当前用户记录（Controller 绑定和 Service 条件回归）。
- [x] 不属于当前用户的 ID 统一表现为“消息不存在”。
- [x] `GLOBAL` 用户通过 Self API 仍只能看到本人。
- [x] 用户不能查询或修改其他用户偏好（Controller 用户上下文绑定回归）。
- [x] 普通用户不能访问管理 Request/Task/Delivery。
- [x] ROLE_AUDIT 只能获得脱敏只读结果。
- [x] ROLE_DEV_OPS 的 Self API 不扩大为全量收件箱。
- [x] 用户发起的部门/角色受众不能超出其数据范围。

### 14.3 PostgreSQL 集成测试

- [x] 业务事务回滚时 Request/Task 不存在。
- [x] 并发相同幂等键只插入一个 Request。
- [x] Task 唯一约束允许同一 Request 多用户、多渠道，但不重复组合。
- [x] 两个 Worker 不领取同一任务。
- [x] Worker 崩溃后锁超时任务可恢复。
- [x] CAS 和乐观锁不覆盖已完成状态。
- [x] 到期任务不调用 Sender（数据库队列过滤已验证；Worker Sender 调用仍由单元测试覆盖）。
- [x] UNKNOWN 不被自动无条件重试。
- [x] taskId 唯一约束保证 IN_APP 幂等。
- [x] 收件箱和未读复合索引存在且可被查询。

### 14.4 迁移测试

- [x] 旧消息 ID、接收人、已读、时间和删除状态保持一致。
- [x] 旧设置正确展开为用途×渠道偏好。
- [x] 重复运行迁移脚本不会重复数据。
- [x] 迁移前后每个用户的消息数和未读数一致。
- [x] 非法历史 extra 不阻断整体迁移。
- [x] 回滚到旧 facade 时旧数据仍可只读核对。

### 14.5 Security 联动

- [x] 渠道关闭时验证码接口不写 Redis。
- [x] Gateway 收到随机六位验证码，Redis 只包含摘要。
- [x] Request、Task、Delivery、日志和指标均无明文验证码。
- [x] 入队失败时 Redis 验证记录被补偿删除。
- [x] 到期验证码不发送。
- [x] 同一安全请求不生成重复 Task。

### 14.6 OA/Workflow/AI 回归

- [x] 请假、报销、采购、会议、合同和公告调用统一 Gateway 生成消息中心记录（调用方迁移契约回归）。
- [x] Workflow 审批完成生成 WORKFLOW_RESULT 通知并使用稳定幂等键。
- [x] AI RAG 失败生成 SYSTEM_NOTICE 通知并使用稳定幂等键。
- [x] 业务数据范围校验发生在调用 Gateway 之前。
- [x] 用户偏好关闭可选渠道后行为正确。
- [x] 消息 link 只能跳转允许的前端内部路由。
- [x] 原消息中心列表、未读、已读和删除行为兼容。

### 14.7 真实 HTTP 与前端联调

- [x] 创建并保留两个 `ROLE_USER`、一个 `ROLE_AUDIT` 和一个 `ROLE_DEV_OPS` 通知联调账号。
- [x] 登录接口返回有效 access/refresh token，Bearer Token 可访问受保护 Self API。
- [x] 用户 A/B 消息详情、列表、未读数、已读和混合批量删除保持收件人隔离。
- [x] 用户偏好保存和查询保持用户隔离；刷新 Token 后仍可访问当前用户接口。
- [x] `ROLE_AUDIT` 可读管理接口但不能重试，`ROLE_DEV_OPS` 可读管理接口，普通用户被拒绝。
- [x] 测试结束后通过登出接口清理测试会话；账号和测试数据按用户要求保留。
- [x] 在真实登录浏览器会话中完成消息铃铛、抽屉、详情、筛选、已读、删除和偏好交互验收。

---

## 十五、实施批次与提交建议

| 批次 | 内容 | 是否阻塞 Security |
|---|---|---|
| NT-A | 公共契约、独立模块、Core 目录端口 | 是 |
| NT-B | 专属 schema、Request/Task/模板、幂等和 Worker | 是 |
| NT-C | SMS/EMAIL 占位、敏感载荷、验证码模板 | 是 |
| NT-D | Inbox/Preference 迁移与 Self API 数据隔离 | 否，但关闭计划前必须 |
| NT-E | OA/Workflow/AI 调用迁移 | 否，但关闭计划前必须 |
| NT-F | 管理 API、监控、清理、文档和完整回归 | 关闭计划前必须 |
| NT-G | 真实短信/邮件 Provider | 不在本计划 |

推荐提交拆分：

1. `feat(notification): 建立统一通知契约与独立模块`
2. `feat(notification): 增加通知领域表与可靠任务`
3. `feat(notification): 增加消息中心与用户偏好`
4. `feat(notification): 增加站内短信邮件渠道`
5. `refactor(notification): 迁移现有通知调用方`
6. `test(notification): 补充幂等投递与数据隔离测试`
7. `docs(notification): 同步统一通知模块知识库`

---

## 十六、风险与回滚

| 风险 | 预防 | 回滚 |
|---|---|---|
| 迁移后消息数不一致 | 保留 ID、可重复迁移、按用户核对计数 | 切回旧只读表和 facade |
| 多渠道生成重复任务 | Request 幂等 + Task 组合唯一 | 暂停 Worker，保留任务排查 |
| Worker 重复发送 | SKIP LOCKED、CAS、taskId Sender 幂等 | 暂停对应渠道 Worker |
| 用户横向访问 | Self 专用 Mapper + 条件 SQL + 越权测试 | 关闭新 Self API，切回旧接口 |
| 部门广播越权 | Core 受众端口执行数据范围校验 | 禁用组织受众，仅允许明确用户 |
| 敏感密钥错误 | 启动校验、key ID、测试解密 | 禁用外部渠道，不降级明文 |
| 占位渠道误开 | enabled + provider 联合启动校验 | 关闭渠道，任务置 BLOCKED |
| 外部结果未知导致重复 | UNKNOWN 状态和人工确认 | 禁止自动重试该任务 |
| 模板升级影响在途任务 | Task 锁定 templateId | 恢复旧模板版本 |
| 队列积压 | 深度、最老任务、失败率告警 | 暂停生产者或扩容 Worker |

回滚原则：

- 不删除新增 Request、Task 和 Delivery 审计数据。
- 不把短信/邮件降级为固定验证码或日志打印。
- Worker 可按渠道独立关闭。
- 消息中心查询不依赖 Worker 在线。
- 旧 Core 表在一个稳定发布窗口内保持只读，不立即 DROP。
- 数据迁移回滚不得覆盖新模块切换后产生的消息，需按切换时间和 ID 明确边界。

---

## 十七、文档同步

实施代码时必须同步：

- `docs/00-项目总览.md`：模块结构和 Entity/Controller 数量。
- `docs/10-后端/10-架构分层.md`：新增 notification 模块。
- `docs/10-后端/15-spectra-core模块.md`：移除通知所有权。
- 新增 `docs/10-后端/75-统一通知模块.md`。
- `docs/10-后端/90-API总览.md`：Self 与 Admin API。
- `docs/20-前端/10-spectra-ui.md` 和 [[P-消息中心前端实现计划]]。
- `docs/30-数据模型/10-ER图.md`。
- `docs/30-数据模型/20-实体清单.md`。
- 新增 `docs/sql/spectra_notification/建表.sql`。
- 更新 `docs/sql/spectra_core/建表.sql` 中旧表迁移说明。
- `docs/70-AI速查/02-模块清单.md`。
- `docs/70-AI速查/03-实体字典.md`。
- `docs/70-AI速查/04-API端点.md`。
- `docs/70-AI速查/05-配置清单.md`。

完成后运行 `scripts/check-docs.ps1`，确认 Entity、Controller、模块和 SQL 统计一致。

---

## 十八、完成定义

- [x] `spectra-notification` 是独立 Maven 子模块并由 Launch 装配。
- [x] 通知模块不依赖 Core、OA、Workflow 或 AI 的实现模块。
- [x] `spectra_notification` schema 和 `ntf_*` 表成为最终数据所有者。
- [x] 旧消息和设置完整迁移，历史 ID、未读数和 API 行为兼容。
- [x] Security、OA、Workflow 和 AI 通过统一 Gateway 提交通知，Core 提供收件人目录适配器。
- [x] 一次 Request 支持多接收人和多渠道 Task。
- [x] IN_APP 真实可用且 taskId 幂等。
- [x] SMS/EMAIL 模板、任务、地址保护和状态管理真实可用。
- [x] SMS/EMAIL 外部发送明确为占位，默认关闭且不报告假成功。
- [x] 当前用户消息中心和偏好通过强制本人规则隔离。
- [x] GLOBAL/DEPT/CUSTOM 不扩大私人收件箱可见范围。
- [x] 业务受众展开遵守调用方权限和数据范围。
- [x] 管理端 Request/Task/Delivery 查询完整脱敏。
- [x] 强制安全通知不能被普通用户设置关闭。
- [x] 验证码不以明文写 Redis 普通值、数据库、日志、指标或 API。
- [x] 幂等、并发领取、失败重试、UNKNOWN、过期和迁移测试通过。
- [x] Maven 全量测试、Spotless 和文档检查通过。
- [x] 文档、SQL、实体字典、API、配置和模块清单全部同步。

## 相关

- [[P-Security认证授权体系重构计划]]
- [[P-消息中心前端实现计划]]
- [[90-计划/P-运维管理中心建设计划]]
- [[P-通用OA业务建设总计划]]
- [[20-用户与权限]]
- [[25-数据权限设计]]
- [[80-基础设施]]
- [[15-spectra-core模块]]
- [[15-后端开发规范]]
- [[40-数据库命名规范]]
