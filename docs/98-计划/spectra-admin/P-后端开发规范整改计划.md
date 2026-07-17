---
tags:
  - plan
  - backend
  - conventions
---

# P-后端开发规范整改计划

## 状态

**全部阶段已完成**

> 状态变更时间：2026-07-18

## 问题背景

根据 `docs/10-后端/15-后端开发规范.md` 对全部后端模块进行逐条检查，发现以下共性问题：

| 问题类型 | 影响范围 | 严重度 |
|---|---|---|
| 裸 RuntimeException | upload(23处)、workflow(22处)、core(5处)、ai(3处) | 🔴 严重 |
| 缺少 @PreAuthorize | workflow(26处)、core(13处)、oa(10处)、ai(1处) | 🔴 严重 |
| 缺少 @Slf4j | core(14处)、oa(9处)、upload(2处) | 🟡 中等 |
| 方法命名不规范 | workflow(9处)、core(7处)、oa(1处) | 🟡 中等 |
| 缺少 @Validated | workflow(8处)、oa(1处)、ai(1处) | 🟡 中等 |

## 修复目标

1. 消除所有裸 RuntimeException，统一使用项目自定义异常
2. 所有接口方法添加 @PreAuthorize 权限控制
3. 所有 Controller 和 ServiceImpl 添加 @Slf4j
4. 方法命名统一为 created/modify/deleteById/page
5. 所有写操作添加 @Validated 分组校验

---

## 详细实现步骤

### 阶段一：异常处理整改（P0）

> 消除所有裸 RuntimeException，统一使用项目自定义异常

#### 1.1 spectra-upload 模块（23 处）

**操作**：
- 将 `RuntimeException` 替换为 `FileUploadException` 或 `DataSaveException`
- 将 `IllegalArgumentException("xxx不存在")` 替换为 `DataNotExistException`
- 将 `IllegalStateException` 替换为 `DataException`

**文件**：
- `spectra-modules/spectra-upload/src/main/java/com/devops00/spectra/upload/service/impl/FileUploadFacade.java` — 3 处
- `spectra-modules/spectra-upload/src/main/java/com/devops00/spectra/upload/service/impl/FileUploadServiceLocalImpl.java` — 10 处
- `spectra-modules/spectra-upload/src/main/java/com/devops00/spectra/upload/service/impl/FileUploadServiceS3Impl.java` — 8 处
- `spectra-modules/spectra-upload/src/main/java/com/devops00/spectra/upload/service/impl/FileUploadTaskServiceImpl.java` — 1 处
- `spectra-modules/spectra-upload/src/main/java/com/devops00/spectra/upload/service/registry/FileUploadServiceRegistry.java` — 1 处

#### 1.2 spectra-workflow 模块（22 处）

**操作**：
- 将 `RuntimeException("流程定义不存在")` 替换为 `DataNotExistException("流程定义不存在")`
- 将 `RuntimeException("启动流程失败")` 替换为 `DataSaveException("启动流程失败")`
- 将 `IllegalStateException("流程已存在")` 替换为 `DataException("流程已存在")`

**文件**：
- `spectra-modules/spectra-workflow/src/main/java/com/devops00/spectra/workflow/service/impl/ProcessDefinitionServiceImpl.java` — 9 处
- `spectra-modules/spectra-workflow/src/main/java/com/devops00/spectra/workflow/service/impl/ProcessInstanceServiceImpl.java` — 10 处
- `spectra-modules/spectra-workflow/src/main/java/com/devops00/spectra/workflow/service/impl/TaskServiceImpl.java` — 4 处

#### 1.3 spectra-core 模块（5 处）

**操作**：
- 将 `RuntimeException("密钥生成失败")` 替换为 `DataSaveException("密钥生成失败")`
- 将 `IllegalArgumentException("行政区划不存在")` 替换为 `DataNotExistException("行政区划不存在")`
- 将 `IllegalArgumentException("参数转换失败")` 替换为 `DataException("参数转换失败")`

**文件**：
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/controller/CryptoController.java` — 1 处
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/service/impl/RegionServiceImpl.java` — 1 处
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/controller/RoleController.java` — 3 处

#### 1.4 spectra-ai 模块（3 处）

**操作**：
- 将 `RuntimeException("文档物理结构损坏")` 替换为 `DataException("文档物理结构损坏")`
- 将 `IllegalArgumentException` 替换为 `DataException`

**文件**：
- `spectra-modules/spectra-ai/src/main/java/com/devops00/spectra/ai/rag/parser/SpectraDocumentParser.java` — 3 处

---

### 阶段二：@PreAuthorize 权限注解补全（P0）

> 所有接口方法必须添加 @PreAuthorize，公开接口用 permitAll() 显式标注

#### 2.1 spectra-workflow 模块（26 处）

**操作**：
- GET 接口添加 `@PreAuthorize("isAuthenticated()")`
- POST/PUT/DELETE 接口添加 `@PreAuthorize("hasPermission(null, 'MODULE:ACTION')")`

**文件**：
- `spectra-modules/spectra-workflow/src/main/java/com/devops00/spectra/workflow/controller/FormDefinitionController.java` — 9 处
- `spectra-modules/spectra-workflow/src/main/java/com/devops00/spectra/workflow/controller/ProcessDefinitionController.java` — 7 处
- `spectra-modules/spectra-workflow/src/main/java/com/devops00/spectra/workflow/controller/ProcessInstanceController.java` — 5 处
- `spectra-modules/spectra-workflow/src/main/java/com/devops00/spectra/workflow/controller/TaskController.java` — 6 处

#### 2.2 spectra-core 模块（13 处）

**操作**：
- 同上规则添加 @PreAuthorize

**文件**：
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/common/controller/CommonController.java` — 1 处
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/controller/DepartmentController.java` — 1 处
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/controller/DictController.java` — 2 处
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/controller/MenuController.java` — 1 处
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/controller/RegionController.java` — 2 处
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/controller/AuthorityController.java` — 1 处
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/controller/UserController.java` — 2 处
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/controller/RoleController.java` — 4 处

#### 2.3 spectra-oa 模块（10 处）

**操作**：
- 同上规则添加 @PreAuthorize

**文件**：
- `spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/asset/controller/AssetController.java` — 1 处
- `spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/attendance/controller/AttendanceController.java` — 1 处
- `spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/calendar/controller/CalendarController.java` — 1 处
- `spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/contact/controller/ContactController.java` — 1 处
- `spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/contract/controller/ContractController.java` — 1 处
- `spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/document/controller/DocumentController.java` — 1 处
- `spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/meeting/controller/MeetingController.java` — 2 处
- `spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/notice/controller/NoticeController.java` — 1 处
- `spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/report/controller/ReportController.java` — 1 处

#### 2.4 spectra-ai 模块（1 处）

**文件**：
- `spectra-modules/spectra-ai/src/main/java/com/devops00/spectra/ai/controller/AiAskController.java` — 1 处

---

### 阶段三：@Slf4j 注解补全（P1）

> 所有 Controller 和 ServiceImpl 必须添加 @Slf4j

#### 3.1 Controller 层（22 处）

**spectra-core 模块（9 个文件）**：
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/common/controller/CommonController.java`
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/controller/ConfiguredController.java`
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/controller/DepartmentController.java`
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/controller/DictController.java`
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/controller/MenuController.java`
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/controller/RegionController.java`
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/controller/ServiceMonitorController.java`
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/controller/AuthorityController.java`
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/controller/UserController.java`

**spectra-upload 模块（1 个文件）**：
- `spectra-modules/spectra-upload/src/main/java/com/devops00/spectra/upload/controller/FileInfoController.java`

**spectra-workflow 模块（1 个文件）**：
- `spectra-modules/spectra-workflow/src/main/java/com/devops00/spectra/workflow/controller/TaskController.java`

**spectra-oa 模块（9 个文件）**：
- `spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/asset/controller/AssetController.java`
- `spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/attendance/controller/AttendanceController.java`
- `spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/calendar/controller/CalendarController.java`
- `spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/contact/controller/ContactController.java`
- `spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/contract/controller/ContractController.java`
- `spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/document/controller/DocumentController.java`
- `spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/meeting/controller/MeetingController.java`
- `spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/notice/controller/NoticeController.java`
- `spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/report/controller/ReportController.java`

#### 3.2 ServiceImpl 层（14 处）

**文件**：
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/service/impl/DepartmentServiceImpl.java`
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/service/impl/MenuServiceImpl.java`
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/service/impl/ConfiguredServiceImpl.java`
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/service/impl/DictGroupServiceImpl.java`
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/service/impl/DictItemServiceImpl.java`
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/service/impl/RegionServiceImpl.java`
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/service/impl/ServiceMonitorServiceImpl.java`
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/service/impl/SysConfigServiceImpl.java`
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/service/impl/AuthorityServiceImpl.java`
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/service/impl/OperationLogServiceImpl.java`
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/service/impl/LoginUsernamePasswordProvider.java`
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/service/impl/LoginEmailProvider.java`
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/service/impl/LoginSmsProvider.java`
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/service/impl/SecurityUserHelper.java`

---

### 阶段四：方法命名统一（P1）

> 方法名统一为 created/modify/deleteById/page

#### 4.1 spectra-workflow 模块

**操作**：
- `create` → `created`
- `update` → `modify`
- `remove` → `deleteById`

**文件**：
- `spectra-modules/spectra-workflow/src/main/java/com/devops00/spectra/workflow/controller/FormDefinitionController.java`
- `spectra-modules/spectra-workflow/src/main/java/com/devops00/spectra/workflow/service/FormDefinitionService.java`
- `spectra-modules/spectra-workflow/src/main/java/com/devops00/spectra/workflow/service/impl/FormDefinitionServiceImpl.java`

#### 4.2 spectra-core 模块

**操作**：
- `create` → `created`
- `updateById` → `modify`
- `delete` → `deleteById`

**文件**：
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/controller/UserController.java`
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/service/UserService.java`
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/service/impl/UserServiceImpl.java`
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/controller/RoleController.java`
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/service/RoleService.java`
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/service/impl/RoleServiceImpl.java`

#### 4.3 spectra-oa 模块

**操作**：
- `create` → `created`

**文件**：
- `spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/meeting/controller/MeetingController.java`
- `spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/meeting/service/MeetingService.java`
- `spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/meeting/service/impl/MeetingServiceImpl.java`

---

### 阶段五：@Validated 分组校验补全（P1）

> 所有写操作必须添加 @Validated(Verify.Insert.class) 或 @Validated(Verify.Update.class)

#### 5.1 spectra-workflow 模块（8 处）

**文件**：
- `spectra-modules/spectra-workflow/src/main/java/com/devops00/spectra/workflow/controller/FormDefinitionController.java` — 2 处
- `spectra-modules/spectra-workflow/src/main/java/com/devops00/spectra/workflow/controller/ProcessInstanceController.java` — 1 处
- `spectra-modules/spectra-workflow/src/main/java/com/devops00/spectra/workflow/controller/TaskController.java` — 4 处

#### 5.2 spectra-ai 模块（1 处）

**文件**：
- `spectra-modules/spectra-ai/src/main/java/com/devops00/spectra/ai/controller/AiAskController.java` — 1 处

#### 5.3 spectra-oa 模块（1 处）

**文件**：
- `spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/meeting/controller/MeetingController.java` — 1 处

---

### 阶段六：From/VO 注解统一（P2）

> 统一使用 @Data，替换 @Getter+@Setter

#### 6.1 spectra-upload 模块（7 个文件）

**From 对象**：
- `spectra-modules/spectra-upload/src/main/java/com/devops00/spectra/upload/javabean/from/FileUploadChunkFrom.java` — `@Getter`+`@Setter` → `@Data`
- `spectra-modules/spectra-upload/src/main/java/com/devops00/spectra/upload/javabean/from/FileUploadFrom.java` — `@Getter`+`@Setter` → `@Data`
- `spectra-modules/spectra-upload/src/main/java/com/devops00/spectra/upload/javabean/from/FileUploadPreFrom.java` — `@Getter`+`@Setter` → `@Data`

**VO 对象**：
- `spectra-modules/spectra-upload/src/main/java/com/devops00/spectra/upload/javabean/vo/FileUploadChunkVO.java` — `@Getter`+`@Setter` → `@Data`
- `spectra-modules/spectra-upload/src/main/java/com/devops00/spectra/upload/javabean/vo/FileUploadPreVO.java` — `@Getter`+`@Setter` → `@Data`
- `spectra-modules/spectra-upload/src/main/java/com/devops00/spectra/upload/javabean/vo/FileUploadStatusVO.java` — `@Getter`+`@Setter` → `@Data`
- `spectra-modules/spectra-upload/src/main/java/com/devops00/spectra/upload/javabean/vo/FileUploadVO.java` — `@Getter`+`@Setter` → `@Data`

#### 6.2 spectra-ai 模块（1 个文件）

**操作**：
- 重命名 `AiAskForm` → `AiAskFrom`
- 移动目录 `javabean/form/` → `javabean/from/`
- 添加 `@NotBlank` 校验注解

**文件**：
- `spectra-modules/spectra-ai/src/main/java/com/devops00/spectra/ai/javabean/form/AiAskForm.java` → 重命名+移动

#### 6.3 spectra-oa 模块（1 个文件）

**操作**：
- 添加 `@NotBlank` 校验注解

**文件**：
- `spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/meeting/javabean/from/MeetingCreateFrom.java` — title、startTime、endTime 字段添加 `@NotBlank`

---

### 阶段七：Service 继承结构整改（P2）

> ServiceImpl 统一继承 BaseServiceImpl

#### 7.1 spectra-core 模块（3 处）

**操作**：
- 将 `extends ServiceImpl<XxxMapper, Xxx>` 改为 `extends BaseServiceImpl<XxxMapper, Xxx>`

**文件**：
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/service/impl/DepartmentServiceImpl.java`
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/service/impl/MenuServiceImpl.java`
- `spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/service/impl/OperationLogServiceImpl.java`

---

## 验证方案

- [ ] 全局搜索 `throw new RuntimeException` 返回 0 结果
- [ ] 全局搜索 `throw new IllegalArgumentException` 返回 0 结果（业务代码）
- [ ] 全局搜索 `throw new IllegalStateException` 返回 0 结果（业务代码）
- [ ] 所有 Controller 类均有 `@Slf4j` 注解
- [ ] 所有 ServiceImpl 类均有 `@Slf4j` 注解
- [ ] 所有接口方法均有 `@PreAuthorize` 注解
- [ ] 所有写操作均有 `@Validated` 注解
- [ ] 方法命名符合 created/modify/deleteById/page 规范
- [ ] 编译通过：`./mvnw clean compile -DskipTests`

## 影响范围

| 模块 | 变更文件数 | 主要变更 |
|---|---|---|
| spectra-ai | ~5 | 异常替换、@PreAuthorize、From 重命名 |
| spectra-upload | ~12 | 异常替换、@Data 统一、@Slf4j |
| spectra-workflow | ~15 | 异常替换、@PreAuthorize、方法命名、@Validated |
| spectra-core | ~25 | @RequiredArgsConstructor、@Slf4j、@PreAuthorize、方法命名 |
| spectra-oa | ~15 | @Slf4j、@PreAuthorize、方法命名、@Validated |

## 相关

- [[15-后端开发规范]] — 后端开发规范文档
- [[98-计划/spectra-admin/P-工作流模块完整实现计划]] — 工作流模块计划
