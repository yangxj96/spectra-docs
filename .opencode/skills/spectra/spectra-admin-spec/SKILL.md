---
name: spectra-admin-spec
description: 当修改、调整或创建spectra-admin后端Java代码时自动加载。包含Controller/Service/Entity/异常处理等核心规范。
version: "1.0.0"
license: MIT
metadata:
  hermes:
    tags: [backend, conventions, java, spring-boot, spectra]
---

# spectra-admin 后端开发规范

## 概述

spectra-admin 采用标准 Spring Boot 分层架构，所有后端代码必须遵循统一的规范。

**核心原则：** 瘦 Controller、胖 Service、规范异常、统一转换。

## 何时使用

当执行以下操作时自动加载：
- 修改或创建 `spectra-admin/` 目录下的任何 Java 文件
- 编写 Controller、Service、Mapper、Entity、From、VO、Converter 等
- 处理异常、日志、事务等业务逻辑

## 快速参考表

### 方法命名规范

| 操作 | 方法名 | 说明 |
|---|---|---|
| 创建 | `created` | 新增数据 |
| 更新 | `modify` | 修改数据 |
| 删除 | `deleteById` | 根据 ID 删除 |
| 分页查询 | `page` | 返回 `IPage<VO>` |
| 批量保存 | `saveBatch` | 批量插入 |
| 批量更新 | `updateBatch` | 批量更新 |
| 批量删除 | `deleteBatch` | 批量删除 |
| Upsert | `upsert` | 按唯一键去重的插入/更新 |

### 异常类型速查

| 异常类 | 使用场景 | 示例 |
|---|---|---|
| `DataNotExistException` | 实体不存在 | `throw new DataNotExistException("表单定义不存在")` |
| `DataSaveException` | 保存失败 | `throw new DataSaveException("创建表单定义失败")` |
| `EntityUpdateException` | 更新失败 | `throw new EntityUpdateException("实体更新异常")` |
| `BuiltinDataException` | 内置数据不可操作 | `throw new BuiltinDataException("内置角色,不可删除")` |
| `DefaultDataException` | 默认数据不可操作 | `throw new DefaultDataException("默认用户,不可删除")` |

### Controller 注解速查

| 注解 | 必须/可选 | 说明 |
|---|---|---|
| `@Slf4j` | 必须 | 使用 `log.debug()` 记录入参 |
| `@ULog` | 必须 | 所有接口方法必须加 |
| `@PreAuthorize` | 必须 | 公开接口用 `permitAll()` |
| `@Validated` | 写操作必须 | 使用 `Verify.Insert.class` 或 `Verify.Update.class` |
| `version` | 必须 | Mapping 注解中统一 `version = "1.0.0+"` |

## 核心规范

### 1. 注释规范

- 使用三斜杠（`///`）注释，而非 Javadoc 块注释
- 每个 Java 文件必须包含 Apache License 2.0 头部
- 类注释必须包含 `@author`、`@version`、`@since`

```java
/// 表单定义Service实现
///
/// @author yangxj96
/// @version 1.0
/// @since 2026/7/17
```

### 2. 包结构

**简单模块（扁平结构）：**
```
com.devops00.spectra.{module}
├── {Module}Module.java              # 模块入口
├── controller/                       # REST 端点
├── javabean/
│   ├── converter/                    # MapStruct 转换器
│   ├── entity/                       # 数据库实体
│   ├── from/                         # 请求表单对象
│   └── vo/                           # 响应视图对象
├── mapper/                           # MyBatis-Plus Mapper
└── service/                          # 业务逻辑接口
    └── impl/                         # Service 实现
```

**复杂模块（子域拆分）：**
```
com.devops00.spectra.{module}
├── {Module}Module.java
├── {subdomain}/                      # 子域（如 auth/、system/）
│   ├── controller/
│   ├── javabean/
│   ├── mapper/
│   └── service/
│       └── impl/
└── configuration/                    # 模块级配置
```

### 3. Controller 规范

- 统一 `@RequiredArgsConstructor` + `private final` 构造器注入
- 瘦 Controller：只做请求转发，不包含任何业务逻辑
- 禁止返回 `Object`，必须返回具体类型
- 统一方法命名：`created`/`modify`/`deleteById`/`page`

### 4. Service 规范

- 接口继承 `BaseService<Entity>`（**禁止直接继承 MyBatis-Plus 的 `IService`**）
- 实现类继承 `BaseServiceImpl<Mapper, Entity>` 并实现对应接口
- 必须加 `@Slf4j`、`@Service`
- 写操作必须加 `@Transactional`
- 异常消息统一中文

### 5. 异常处理

- 统一使用项目自定义异常，**禁止裸 RuntimeException**
- 异常消息统一中文（用户友好）
- 示例：`"表单定义不存在"`、`"创建表单定义失败"`

### 6. 实体规范

- UUID 主键：`@TableId(type = IdType.INPUT)`
- 审计字段：继承 `BaseEntity`（`createdBy`/`createdAt`/`updatedBy`/`updatedAt`）
- 软删除：继承 `BaseEntity`（`Instant deleted`，null = 未删除）
- 乐观锁：继承 `BaseEntity`（`@Version`）
- 表名注解：`@TableName("xxx")`
- 字段注解：`@TableField("xxx")`

### 7. From 对象规范

- 统一后缀 `From`（**非 Form**）
- 包路径：`javabean/from/`
- 必填字段必须加 `@NotBlank`/`@NotNull` 等校验注解
- 使用 `@Data` 注解
- 提供清晰的中文 `message` 参数

### 8. VO 对象规范

- 统一后缀 `VO`
- 包路径：`javabean/vo/`
- 使用 `@Data` 注解
- 分页查询返回 `IPage<XxxVO>`
- 时间字段使用 `LocalDateTime`、`LocalDate`、`LocalTime`（MapStruct 会自动转换）

### 9. Converter 规范（MapStruct）

- 所有模块必须使用 MapStruct Converter 进行对象转换，禁止手动 setter
- 统一放在 `javabean/converter/`
- 引用 `GlobalMapperConfig.class` 和 `TimeMapper.class`

```java
@Mapper(uses = TimeMapper.class, config = GlobalMapperConfig.class)
public interface FormConverter {
    FormDefinitionVO toVO(FormDefinition source);
    FormDefinition toEntity(FormDefinitionSaveFrom source);
    void updateEntity(FormDefinitionSaveFrom source, @MappingTarget FormDefinition target);
}
```

### 10. 日志规范

| 级别 | Controller 层 | Service 层 |
|---|---|---|
| `log.debug()` | 记录请求入参 | 查询条件、参数详情 |
| `log.info()` | — | 关键业务节点（创建成功、部署成功等） |
| `log.warn()` | — | 业务校验失败、降级处理 |
| `log.error()` | — | 异常捕获、系统错误 |

## 代码模板

完整的代码模板请查看 `examples/` 目录：

| 模板 | 文件 | 说明 |
|---|---|---|
| Controller | `controller-full.java` | 完整 Controller 示例 |
| Service 接口 | `service-full.java` | 完整 Service 接口示例 |
| Service 实现 | `service-impl-full.java` | 完整 Service 实现示例 |
| 实体 | `entity-full.java` | 完整实体示例 |
| From 对象 | `from-full.java` | 完整 From 对象示例 |
| VO 对象 | `vo-full.java` | 完整 VO 对象示例（时间字段使用 LocalDateTime） |
| Converter | `converter-full.java` | 完整 MapStruct 转换器示例 |
| Module 入口 | `module-full.java` | 完整模块入口类示例 |
| Mapper | `mapper-full.java` | 完整 MyBatis-Plus Mapper 示例 |
| Exception | `exception-full.java` | 完整自定义异常示例 |
| 配置类 | `configuration-full.java` | 完整配置类示例 |
| 属性类 | `properties-full.java` | 完整属性类示例 |
| 工具类 | `util-full.java` | 完整工具类示例 |
| 常量类 | `constant-full.java` | 完整常量类示例 |
| 枚举类 | `enum-full.java` | 完整枚举类示例 |
| DTO | `dto-full.java` | 完整 DTO 示例 |
| BO | `bo-full.java` | 完整 BO 示例 |
| Query | `query-full.java` | 完整 Query 示例 |
| 树形 VO | `tree-full.java` | 完整树形 VO 示例 |
| 列表 VO | `list-full.java` | 完整列表 VO 示例 |
| 详情 VO | `response-full.java` | 完整详情 VO 示例 |
| 分页参数 | `page-full.java` | 完整分页参数示例 |
| 基类 | `base-full.java` | 完整基类示例 |
| Runner | `runner-full.java` | 完整 Runner 示例 |
| 日志 | `log-full.java` | 完整日志示例 |
| 事务 | `transaction-full.java` | 完整事务示例 |
| 权限 | `security-full.java` | 完整权限示例 |
| 版本控制 | `version-full.java` | 完整版本控制示例 |
| 校验 | `validator-full.java` | 完整校验示例 |
| 异常数据 | `exception-data.java` | 异常类型示例 |

## 常见错误

### 错误 1：使用 RuntimeException

```java
// ❌ 错误：禁止裸 RuntimeException
if (entity == null) {
    throw new RuntimeException("表单定义不存在");
}

// ✅ 正确：使用自定义异常
if (entity == null) {
    throw new DataNotExistException("表单定义不存在");
}
```

### 错误 2：Controller 包含业务逻辑

```java
// ❌ 错误：Controller 包含业务逻辑
public void created(@RequestBody FormDefinitionSaveFrom from) {
    var entity = new FormDefinition();
    entity.setName(from.getName());
    // ... 业务逻辑
    this.save(entity);
}

// ✅ 正确：瘦 Controller，只做转发
public void created(@Validated(Verify.Insert.class) @RequestBody FormDefinitionSaveFrom from) {
    formDefinitionService.created(from);
}
```

### 错误 3：缺少注解

```java
// ❌ 错误：缺少必要注解
@GetMapping("/page")
public IPage<FormDefinitionVO> page(PageFrom page, FormPageFrom params) {
    return formDefinitionService.page(page, params);
}

// ✅ 正确：完整注解
@ULog("'查询表单列表'")
@GetMapping(value = "/page", version = "1.0.0+")
@PreAuthorize("isAuthenticated()")
public IPage<FormDefinitionVO> page(PageFrom page, FormPageFrom params) {
    return formDefinitionService.page(page, params);
}
```

### 错误 4：手动 setter 转换对象

```java
// ❌ 错误：手动 setter
var vo = new FormDefinitionVO();
vo.setId(entity.getId());
vo.setName(entity.getName());

// ✅ 正确：使用 Converter
var vo = formConverter.toVO(entity);
```

## 详细规则查询

完整规范请查阅以下文档：

- 注释规范：`docs/10-后端/15-后端开发规范.md` 第 1 节
- 包结构：`docs/10-后端/15-后端开发规范.md` 第 2 节
- Controller 规范：`docs/10-后端/15-后端开发规范.md` 第 3 节
- Service 规范：`docs/10-后端/15-后端开发规范.md` 第 4 节
- 异常处理：`docs/10-后端/15-后端开发规范.md` 第 5 节
- 实体规范：`docs/10-后端/15-后端开发规范.md` 第 6 节
- From 对象规范：`docs/10-后端/15-后端开发规范.md` 第 7 节
- VO 对象规范：`docs/10-后端/15-后端开发规范.md` 第 8 节
- Converter 规范：`docs/10-后端/15-后端开发规范.md` 第 9 节
- 方法命名规范：`docs/10-后端/15-后端开发规范.md` 第 10 节
- 日志规范：`docs/10-后端/15-后端开发规范.md` 第 11 节
- 架构分层：`docs/10-后端/10-架构分层.md`
- 用户与权限：`docs/10-后端/20-用户与权限.md`
- 系统管理：`docs/10-后端/30-系统管理.md`
