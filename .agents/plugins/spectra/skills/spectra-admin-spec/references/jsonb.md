# PostgreSQL JSONB 参考

PostgreSQL `jsonb` 列必须使用项目自定义的 `PgJsonbTypeHandler`。它通过 `PGobject` 显式声明 `jsonb` 类型，避免 JDBC 将 JSON 字符串作为 `varchar` 发送。

实体字段示例：

```java
@TableField(value = "metadata", typeHandler = PgJsonbTypeHandler.class,
        updateStrategy = FieldStrategy.ALWAYS)
private Map<String, Object> metadata;
```

不要使用 MyBatis-Plus 的 `Jackson3TypeHandler` 处理 PostgreSQL `jsonb`。它可能将 Map 作为字符串传递，导致 `jsonb` 与 `character varying` 类型不匹配。

修改 JSONB Entity、TypeHandler、Mapper 或迁移 SQL 时，同时确认字段为空值、更新策略、索引和 Flyway/建表文档。
