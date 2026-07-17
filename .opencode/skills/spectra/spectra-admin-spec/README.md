# spectra-admin-spec Skill

当修改、调整或创建 `spectra-admin/` 目录下的 Java 代码时，此 skill 会自动加载作为开发规范指南。

## 使用场景

- 编写 Controller、Service、Mapper、Entity、From、VO、Converter 等
- 处理异常、日志、事务等业务逻辑
- 创建新的业务模块

## 核心规范

1. **瘦 Controller、胖 Service**：Controller 只做请求转发，不包含业务逻辑
2. **规范异常**：统一使用项目自定义异常，禁止裸 RuntimeException
3. **统一转换**：所有模块必须使用 MapStruct Converter 进行对象转换

## 示例文件

`examples/` 目录包含完整的代码模板：

| 文件 | 说明 |
|---|---|
| `controller-full.java` | 完整 Controller 示例 |
| `service-full.java` | 完整 Service 接口示例 |
| `service-impl-full.java` | 完整 Service 实现示例 |
| `entity-full.java` | 完整实体示例 |
| `from-full.java` | 完整 From 对象示例 |
| `vo-full.java` | 完整 VO 对象示例（时间字段使用 LocalDateTime） |
| `converter-full.java` | 完整 MapStruct 转换器示例 |
| `module-full.java` | 完整模块入口类示例 |
| `mapper-full.java` | 完整 MyBatis-Plus Mapper 示例 |
| `exception-full.java` | 完整自定义异常示例 |
| `configuration-full.java` | 完整配置类示例 |
| `properties-full.java` | 完整属性类示例 |
| `util-full.java` | 完整工具类示例 |
| `constant-full.java` | 完整常量类示例 |
| `enum-full.java` | 完整枚举类示例 |
| `dto-full.java` | 完整 DTO 示例 |
| `bo-full.java` | 完整 BO 示例 |
| `query-full.java` | 完整 Query 示例 |
| `tree-full.java` | 完整树形 VO 示例 |
| `list-full.java` | 完整列表 VO 示例 |
| `response-full.java` | 完整详情 VO 示例 |
| `page-full.java` | 完整分页参数示例 |
| `base-full.java` | 完整基类示例 |
| `runner-full.java` | 完整 Runner 示例 |
| `log-full.java` | 完整日志示例 |
| `transaction-full.java` | 完整事务示例 |
| `security-full.java` | 完整权限示例 |
| `version-full.java` | 完整版本控制示例 |
| `validator-full.java` | 完整校验示例 |
| `exception-data.java` | 异常类型示例 |

## 详细规则查询

完整规范请查阅 Obsidian 文档：

- `docs/10-后端/15-后端开发规范.md` - 后端开发规范
- `docs/10-后端/10-架构分层.md` - 架构分层
- `docs/10-后端/20-用户与权限.md` - 用户与权限
- `docs/10-后端/30-系统管理.md` - 系统管理

## 快速参考

### 方法命名规范

| 操作 | 方法名 |
|---|---|
| 创建 | `created` |
| 更新 | `modify` |
| 删除 | `deleteById` |
| 分页查询 | `page` |

### 异常类型

| 异常类 | 使用场景 |
|---|---|
| `DataNotExistException` | 实体不存在 |
| `DataSaveException` | 保存失败 |
| `EntityUpdateException` | 更新失败 |
| `BuiltinDataException` | 内置数据不可操作 |
| `DefaultDataException` | 默认数据不可操作 |

### Controller 注解

| 注解 | 必须/可选 |
|---|---|
| `@Slf4j` | 必须 |
| `@ULog` | 必须 |
| `@PreAuthorize` | 必须 |
| `@Validated` | 写操作必须 |
| `version` | 必须 |
