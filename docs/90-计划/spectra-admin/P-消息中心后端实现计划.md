---
tags:
  - plan
  - backend
  - spectra-admin
---

# P-消息中心后端实现计划

## 状态

**进行中**

> 创建时间：2026-07-19

## 问题背景

系统需要统一的消息通知功能，支持系统通知、工作流通知、OA通知、站内信、待我审批等多种消息类型。需要实现后端API和数据库表，供前端调用。

## 实现目标

1. 创建消息表 `sys_notification` 和消息设置表 `sys_notification_setting`
2. 实现消息CRUD API（列表查询、未读数、标记已读、删除）
3. 实现消息设置API（获取设置、更新设置）
4. 实现消息发送Service（供其他模块调用）
5. 前端对接真实后端API

## 详细实现步骤

### 阶段一：数据库设计

#### 1.1 创建建表SQL

**文件**：`docs/60-知识库/30-数据模型/35-通知建表SQL.sql`

**内容**：
- `sys_notification` - 消息表
- `sys_notification_setting` - 消息设置表

### 阶段二：后端实体和Mapper

#### 2.1 创建实体类

**文件**：
- `spectra-core/.../notification/javabean/entity/Notification.java`
- `spectra-core/.../notification/javabean/entity/NotificationSetting.java`

#### 2.2 创建Mapper接口

**文件**：
- `spectra-core/.../notification/mapper/NotificationMapper.java`
- `spectra-core/.../notification/mapper/NotificationSettingMapper.java`

### 阶段三：From/VO/DTO对象

#### 3.1 创建查询参数

**文件**：
- `spectra-core/.../notification/javabean/from/NotificationQueryFrom.java`
- `spectra-core/.../notification/javabean/from/NotificationSettingFrom.java`

#### 3.2 创建响应VO

**文件**：
- `spectra-core/.../notification/javabean/vo/NotificationVO.java`
- `spectra-core/.../notification/javabean/vo/NotificationSettingVO.java`

#### 3.3 创建发送DTO

**文件**：
- `spectra-core/.../notification/javabean/dto/NotificationSendDTO.java`
- `spectra-core/.../notification/javabean/dto/NotificationBatchSendDTO.java`

### 阶段四：Converter

#### 4.1 创建MapStruct Converter

**文件**：
- `spectra-core/.../notification/javabean/converter/NotificationConverter.java`
- `spectra-core/.../notification/javabean/converter/NotificationSettingConverter.java`

### 阶段五：Service层

#### 5.1 创建Service接口

**文件**：
- `spectra-core/.../notification/service/NotificationService.java`
- `spectra-core/.../notification/service/NotificationSettingService.java`

#### 5.2 创建Service实现

**文件**：
- `spectra-core/.../notification/service/impl/NotificationServiceImpl.java`
- `spectra-core/.../notification/service/impl/NotificationSettingServiceImpl.java`

### 阶段六：Controller层

#### 6.1 创建Controller

**文件**：
- `spectra-core/.../notification/controller/NotificationController.java`
- `spectra-core/.../notification/controller/NotificationSettingController.java`

### 阶段七：前端对接

#### 7.1 更新前端API

**文件**：`spectra-ui/src/api/notification/notification-api.ts`

#### 7.2 更新前端Store

**文件**：`spectra-ui/src/plugin/store/modules/use-notification-store.ts`

## 验证方案

1. 后端编译：`./mvnw clean compile -DskipTests`
2. 前端类型检查：`pnpm run type-check`
3. 功能测试：启动后端和前端，测试消息中心功能

## 影响范围

### 新增文件

| 文件路径 | 说明 |
|---|---|
| `docs/60-知识库/30-数据模型/35-通知建表SQL.sql` | 建表SQL |
| `spectra-core/.../notification/javabean/entity/Notification.java` | 消息实体 |
| `spectra-core/.../notification/javabean/entity/NotificationSetting.java` | 设置实体 |
| `spectra-core/.../notification/mapper/NotificationMapper.java` | 消息Mapper |
| `spectra-core/.../notification/mapper/NotificationSettingMapper.java` | 设置Mapper |
| `spectra-core/.../notification/javabean/from/NotificationQueryFrom.java` | 查询参数 |
| `spectra-core/.../notification/javabean/from/NotificationSettingFrom.java` | 设置参数 |
| `spectra-core/.../notification/javabean/vo/NotificationVO.java` | 消息VO |
| `spectra-core/.../notification/javabean/vo/NotificationSettingVO.java` | 设置VO |
| `spectra-core/.../notification/javabean/dto/NotificationSendDTO.java` | 发送DTO |
| `spectra-core/.../notification/javabean/dto/NotificationBatchSendDTO.java` | 批量发送DTO |
| `spectra-core/.../notification/javabean/converter/NotificationConverter.java` | 消息Converter |
| `spectra-core/.../notification/javabean/converter/NotificationSettingConverter.java` | 设置Converter |
| `spectra-core/.../notification/service/NotificationService.java` | 消息Service |
| `spectra-core/.../notification/service/NotificationSettingService.java` | 设置Service |
| `spectra-core/.../notification/service/impl/NotificationServiceImpl.java` | 消息Service实现 |
| `spectra-core/.../notification/service/impl/NotificationSettingServiceImpl.java` | 设置Service实现 |
| `spectra-core/.../notification/controller/NotificationController.java` | 消息Controller |
| `spectra-core/.../notification/controller/NotificationSettingController.java` | 设置Controller |

### 修改文件

| 文件路径 | 说明 |
|---|---|
| `spectra-ui/src/api/notification/notification-api.ts` | 更新API地址 |
| `spectra-ui/src/plugin/store/modules/use-notification-store.ts` | 关闭模拟数据 |

## 相关

- [[15-后端开发规范]] — 后端编码规范
- [[20-实体清单]] — 现有实体参考
- [[90-API总览]] — API设计规范
