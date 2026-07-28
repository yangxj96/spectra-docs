---
tags:
  - backend
  - reference
  - guide
source: https://www.devops00.com/spectra-admin/be-mapstruct-guide
---

# MapStruct 命名规范

> 来源：[[00-项目总览|项目 VitePress 文档]]
>
> 适用于 spectra-admin 中所有 MapStruct Converter。

## 设计原则

1. **单一职责**：Converter 只做对象结构映射，禁止包含业务逻辑、权限判断、数据校验
2. **约定优于配置**：优先使用同名字段自动映射，只在字段不一致时使用 `@Mapping`
3. **命名服务于自动推断**：统一命名消除歧义，让 MapStruct "猜得到、选得对"

## Converter 接口命名

统一格式：`<Domain>Converter`

```java
UserConverter
OrderConverter
RoleConverter
ProcessDefinitionConverter
```

**禁止**：
- `XxxMapper` — 与 MyBatis Mapper 概念冲突
- `XxxAssembler` — DDD 语义，不统一
- `XxxConvertUtil` — 工具类语义，破坏 Spring 管理

## 方法命名核心规范

### 无歧义场景

格式：`to<目标类型>`

```java
UserEntity toEntity(UserCreateCmd cmd);
UserVO toVO(UserEntity entity);
UserDTO toDTO(UserEntity entity);
UserBO toBO(UserEntity entity);
```

### 存在歧义时

同一目标类型存在多个来源时：`to<目标类型>From<来源类型>`

```java
UserEntity toEntityFromCreateCmd(UserCreateCmd cmd);
UserEntity toEntityFromUpdateCmd(UserUpdateCmd cmd);
```

## 对象类型约定

| 缩写 | 全称 | 用途 |
|---|---|---|
| `DTO` | Data Transfer Object | 数据传输对象 |
| `VO` | View Object | 视图对象 |
| `BO` | Business Object | 业务对象 |
| `Cmd` | Command | 命令对象 |
| `Query` | Query | 查询对象 |

## 集合与分页

```java
// 集合
List<UserVO> toVOList(List<UserEntity> entities);

// 分页
IPage<UserVO> toVOPage(IPage<UserEntity> page);
```

## 更新场景（@MappingTarget）

```java
void updateEntity(@MappingTarget UserEntity entity, UserUpdateCmd cmd);
```

禁止使用 `merge`、`copy`、`apply`。

## 轻量对象

```java
UserSimpleVO toSimpleVO(UserEntity entity);
List<UserSimpleVO> toSimpleVOList(List<UserEntity> entities);
```

## 禁止的方法名

```
convert          # 无语义
map              # 无语义
parse            # 无语义
build            # 无语义
doConvert        # 历史遗留
entity2VO        # 不符合 Java 语义
vo2Entity        # 不符合 Java 语义
```

## 完整示例

```java
@Mapper(componentModel = "spring")
public interface UserConverter {
    UserEntity toEntity(UserCreateCmd cmd);
    UserEntity toEntityFromUpdateCmd(UserUpdateCmd cmd);
    void updateEntity(@MappingTarget UserEntity entity, UserUpdateCmd cmd);
    UserBO toBO(UserEntity entity);
    UserVO toVO(UserEntity entity);
    List<UserVO> toVOList(List<UserEntity> entities);
    UserSimpleVO toSimpleVO(UserEntity entity);
}
```

## 关键经验

- 只要存在 `UserVO toVO(UserEntity)`，MapStruct 自动复用于集合和嵌套对象
- 90% 场景不需要 `@Named/qualifiedByName`，说明命名有问题
- `expression` 是最后手段，不应承载业务计算
- 统一使用 `@Mapper(componentModel = "spring")`

## 相关笔记

- [[10-架构分层]] — 分层中 Converter 的位置
- [[10-Git提交规范]] — Git 提交 scope
