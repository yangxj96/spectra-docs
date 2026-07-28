---
tags:
  - plan
  - backend
  - spectra-admin
  - refactor
---

# P-Controller路径参数UUID类型统一计划

## 状态

**已完成**

> 完成时间：2026-07-19

## 问题背景

后端 Controller 中部分接口使用 @PathVariable String 接收数据库主键 ID，而实体主键类型为 UUID。这导致：
1. 需要手动调用 UUID.fromString() 进行转换
2. 类型不一致，不符合类型安全原则
3. 部分 Service 层接口也使用 String 类型，需要统一

## 修复目标

所有接收数据库 UUID 主键的路径参数统一使用 @PathVariable UUID 类型，消除手动转换。

## 详细实现步骤

### 阶段一：高优先级（删除接口 + Service 层使用 String）

#### 1.1 DepartmentController.deleteById

**文件**：
- DepartmentController.java:64
- DepartmentService.java:44
- DepartmentServiceImpl.java:88

**修改**：参数类型 String id → UUID id

#### 1.2 MenuController.deleteById

**文件**：
- MenuController.java:61
- MenuService.java:59
- MenuServiceImpl.java:98

**修改**：参数类型 String id → UUID id

### 阶段二：中优先级（Controller 层手动转换）

#### 2.1 UserController.deleteById

**文件**：UserController.java:62

**修改**：String uid → UUID uid，删除 UUID.fromString() 调用

#### 2.2 UserController.passwordResetById

**文件**：UserController.java:76

**修改**：String uid → UUID uid，删除 UUID.fromString() 调用

#### 2.3 RoleController.saveRoleRelAuthorityByRoleId

**文件**：RoleController.java:127

**修改**：String roleId → UUID roleId，删除 UUID.fromString() 调用

#### 2.4 DictController.deleteGroup

**文件**：DictController.java:66

**修改**：String id → UUID id，删除 UUID.fromString() 调用

### 阶段三：低优先级（未实现接口）

#### 3.1 AuthorityController.deleteAuthority

**修改**：参数类型 String id → UUID id

## 验证方案

1. 运行 ./mvnw clean compile -DskipTests 确保编译通过
2. 启动服务后测试删除功能
3. 检查前端调用是否受影响（前端传递的 UUID 字符串格式不变，Spring 自动转换）

## 影响范围

### 直接影响的文件（10 个）

| 文件 | 修改类型 |
|---|---|
| DepartmentController.java | 参数类型 String → UUID |
| DepartmentService.java | 接口方法参数类型 |
| DepartmentServiceImpl.java | 实现方法参数类型 |
| MenuController.java | 参数类型 String → UUID |
| MenuService.java | 接口方法参数类型 |
| MenuServiceImpl.java | 实现方法参数类型 |
| UserController.java | 参数类型 String → UUID（2处） |
| RoleController.java | 参数类型 String → UUID |
| DictController.java | 参数类型 String → UUID |
| AuthorityController.java | 参数类型 String → UUID |

### 无需修改的接口（合理使用 String）

- Flowable 工作流引擎 ID — 引擎 ID 非 UUID
- 字典编码参数 — 业务编码非主键
- 分片上传 ID — 临时会话 ID

## 相关

- [[30-系统管理]]
- [[15-后端开发规范]]
