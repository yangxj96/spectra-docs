# 后端安全 Redis 参考

安全 Redis 是 Token、Session、Refresh Token 轮换、防重放、MFA Challenge、验证码和登录失败锁定的事实源，不是普通缓存。

- 所有安全 Redis 操作通过 `SecurityRedisExecutor`。
- 连接失败、超时、命令异常、Lua 返回 `null` 或状态无法确认时，拒绝当前操作。
- 不得将 Redis 故障解释为 Token、Challenge 或验证码不存在。
- 不得增加本地快照、内存回退、静默吞异常、绕过 Redis 或继续向业务层传递 Token 的分支。
- Web 请求按项目统一映射为 HTTP 503 和“安全会话服务暂不可用”。

修改过滤器、认证、MFA、验证码、Refresh Token、Nonce 或安全 Key 命名空间时，检查 fail-closed 行为、敏感值脱敏和测试覆盖。
