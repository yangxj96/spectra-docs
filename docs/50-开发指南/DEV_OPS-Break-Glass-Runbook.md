# DEV_OPS Break-glass Runbook

> 生效条件：`1.0.0` 发布前完成运维负责人评审、凭据分权落地和首次隔离演练。本文不保存任何真实密码、TOTP Secret、Recovery Code、私钥或数据库凭据。

Break-glass 是生产环境在正常 Root、MFA 或认证链路不可用时使用的紧急恢复 Root，不是日常管理员账号，也不是绕过 MFA 的临时开关。正式生产启用前必须完成凭据保管、分权和隔离演练。

## 1. 目的与边界

Break-glass 是 `ROLE_DEV_OPS` 的灾难恢复流程，不是日常管理员入口，也不是普通管理员绕过 MFA 的替代 API。首版 Root 策略允许多个 DEV_OPS，`maxDevOpsUsers` 默认 3，推荐配置为：

| Root 类型 | 推荐数量 | 用途 |
|---|---:|---|
| Normal DEV_OPS | 2 | 日常系统安全和运维管理；必须使用 MFA |
| Break-glass DEV_OPS | 1 | 只有明确故障或恢复事件才启用；最高等级审计和告警 |

以下不变量始终有效：

- 系统不能通过管理操作失去最后一个有效 DEV_OPS；`minEffectiveDevOpsUsers` 最低为 1。
- Break-glass 不能绕过 Security Audit。Audit 不可用时，高风险恢复操作必须 fail-closed。
- Break-glass 不能把普通业务授权、数据范围或 Root 生命周期校验变成隐式绕过。
- 双人审批首版不由应用强制实现；生产运维仍应采用独立人员复核和离线凭据分权，并在审批扩展点交付后再接入系统化审批。

## 2. 触发条件

只有下列情形之一成立时才允许进入流程：

1. 所有 Normal DEV_OPS 均不可用、锁定、离职或无法完成 MFA，且需要恢复 Root 管理能力；
2. 认证策略、MFA Provider 或 Session Policy 故障导致正常 Root 无法安全登录；
3. 发生疑似 Root 凭据泄漏，需要立即冻结会话、撤销凭据并恢复受控 Root；
4. 重大安全事件要求在正常管理面不可用时执行会话撤销或安全策略修复。

以下情况禁止使用 Break-glass：

- 日常发布、普通用户管理、业务数据查询或绕过权限边界；
- 规避审计、规避最后 Root 保护、规避账号状态校验；
- 没有事件编号、值班记录、身份核验和事后复盘材料。

## 3. 凭据与职责分离

### 3.1 离线保管

- Break-glass 密码、TOTP Secret、Recovery Code 和恢复私钥不得进入 Git、工单正文、聊天记录、镜像、环境变量样例或应用日志。
- 密码与二次认证材料分开保管；推荐由两个独立保管人持有不同凭据份额，使用时在受控终端临时组合。
- 线上系统只保存 TOTP Secret 的密文（带 key version）和 Recovery Code 的强 Hash；Runbook 只记录凭据编号/保管位置，不记录凭据值。
- TOTP 密钥轮换使用“当前版本 + 上一版本”短窗口：新登记只用当前版本加密，用户成功验证旧版本设备后自动条件迁移；确认所有 `totp_credential.key_version` 已切到当前版本后，立即移除上一版本密钥。
- Recovery Code 轮换必须调用受保护的轮换流程；旧未使用码在同一事务中原子失效，新码只显示一次，任何旧码不得恢复。
- 保管介质应具备访问告警、取用记录、轮换记录和离线备份。取用后必须立即标记为“待轮换”。

### 3.2 操作职责

至少记录以下角色，即使首版应用不强制双人审批：

- **Incident Commander**：确认触发条件、维护事件时间线和回滚决定；
- **Break-glass Operator**：在受控终端执行恢复命令；
- **Independent Reviewer**：核对身份、命令、审计事件和事后证据；
- **Security/Audit Owner**：确认 Audit 可写、告警已触发并完成复盘。

同一人不得同时无记录地承担全部角色。

## 4. Pre-flight 检查

在取用凭据前完成并记录：

- 事件编号、触发时间、影响范围、当前值班人员和独立复核人；
- 通过受控管理网络、固定运维终端和 HTTPS 访问；确认反向代理、Origin allowlist 和 CSRF 配置没有被临时放宽；
- Security Audit 数据库可连接、可插入且不可更新/删除；Audit 不可用时停止流程；
- Redis/Session 核心依赖可连接，能够执行全局 Session revoke；不可用时不得创建恢复 Session；
- 记录当前 Root policy、有效 DEV_OPS 数量、账号状态、最近安全事件和待处理告警；
- 获取目标数据库/安全配置的受控备份或快照，并确认回滚责任人；
- 核对 Break-glass 凭据的保管编号、轮换状态和上次演练时间。

所有检查结果写入事件记录；不要把 Token、密码、TOTP Secret 或 Recovery Code 写入记录。

## 5. 启用与最小化操作

1. 由 Incident Commander 宣布进入 Break-glass 状态，并由 Reviewer 完成身份核验和凭据取用登记。
2. 使用一次性、短 TTL、绑定事件和受控客户端的恢复 Session。不得复用旧 Access Token 或 Refresh Token；不得把 Refresh Token 放入普通业务请求。
3. 进入系统后第一件事是确认 Audit 写入和最高等级告警；任何高风险写操作必须先产生 `STARTED` 审计事实，提交后产生 `SUCCEEDED`/`FAILED` 事实。
4. 仅执行恢复所需的最小动作，优先顺序为：
   - 撤销疑似泄漏用户、设备和 Client 的全部 Session；
   - 修复或替换不可用的 Normal DEV_OPS MFA/认证身份；
   - 创建或恢复一个新的受控 Normal DEV_OPS（不得超过 `maxDevOpsUsers`）；
   - 为后续正常运维设置强制 MFA、短期密码和最小 Session Policy。
5. 任何 Root/Role/Permission/Scope/Session Policy 变化都必须经过统一 SecurityChangeExecutor、Impact Analysis、security epoch fence 和审计；不得直接修改业务表绕过领域服务。
6. 如果发现数据库或 Redis 状态无法满足上述门禁，停止写操作，保持系统下线或只读，升级到数据库/平台恢复流程。

## 6. 恢复完成与退出

恢复目标满足以下条件后，才允许退出 Break-glass：

- 至少一个新的有效 Normal DEV_OPS 已完成 MFA，并能独立登录；
- 最后一个有效 Root 保护仍成立，Root 数量和 `maxDevOpsUsers` 符合策略；
- 所有疑似泄漏的 Access/Refresh Token、Session、MFA Factor 和旧 Recovery Code 已撤销；
- Break-glass Session 已主动 logout 并由服务端 revoke；
- Break-glass 密码、TOTP、Recovery Code 和任何临时恢复密钥已轮换/作废；
- 高风险审计事件、告警、数据库变更和 Session revoke 记录齐全；
- Normal DEV_OPS 已接管后续修复，Incident Commander 明确关闭事件。

退出后不得恢复旧 Session，也不得重新启用被标记为 replay/revoked 的 Token。

## 7. 审计与告警要求

以下事件使用最高风险等级并触发独立告警：

- Break-glass 凭据取用、启用、登录成功、登录失败和 MFA 失败；
- Break-glass Session 创建、续期、强制下线和全部 revoke；
- Root 创建、撤销、状态变化、authorityLevel 或 Root policy 变化；
- 密码、TOTP、Recovery Code、AuthenticationMethod 和 SessionPolicy 轮换；
- Audit/Redis 不可用、恢复失败、回滚和事件关闭。

每条 Security Audit 至少包含 operator、target、event type、before/after（脱敏）、reason、timestamp、client、IP、result、correlation ID 和事件编号。不得记录密码、Token、Provider Secret、Private Key 或 TOTP Secret 原文。

## 8. 演练与复盘

- 首次上线前完成一次全流程演练，使用测试 Root 和隔离环境，不接触生产凭据。
- 至少每季度演练一次；Normal DEV_OPS 轮换、MFA Provider 变更或安全事故后必须追加演练。
- 演练必须验证：Audit fail-closed、Redis fail-closed、最后 Root 保护、全局 Session revoke、Recovery Code 单次消费、凭据轮换和告警到达。
- 演练结束后记录耗时、失败点、告警延迟、恢复证据和改进项；未演练通过前，不得在服务级别目标中宣称“Root 可恢复”。

## 9. 事件证据清单

关闭事件前归档以下元数据（不归档敏感凭据）：

- 事件编号、触发原因、时间线、参与人员和身份核验结果；
- Break-glass 凭据编号、取用/归还/轮换记录；
- Audit event ID、Session ID 摘要、revoke 结果和告警编号；
- Root policy、DEV_OPS 数量、MFA 状态和 Session Policy 的脱敏前后快照；
- 数据库/Redis 健康检查、备份/恢复结果和回滚决定；
- 复盘结论、遗留风险、责任人和整改截止时间。
