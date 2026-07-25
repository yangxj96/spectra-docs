---
tags:
  - plan
  - database
  - refactor
created: 2026-07-26
---

# P-数据库Schema拆分

## 状态

**进行中**

> 状态变更时间：2026-07-26

## 问题背景

项目最初设计为不同模块的表存放在 PostgreSQL 不同 schema 下，但开发过程中所有业务表都集中到了 `spectra_core` schema。当前数据库中：

- `spectra_core`：38 张业务表（sys_*、oa_*、file_*、wf_*、ai_* 全部混在一起）
- `spectra_workflow`：仅 Flowable 引擎表（act_*、flw_*）
- `spectra_rag`：仅 1 张 `ai_knowledge_chunks` 表 + pgvector 扩展

MyBatis-Plus 通过全局 `schema: spectra_core` 配置统一指定 schema，实体类 `@TableName` 中不含 schema 信息。

## 修复目标

1. 按模块拆分 schema：`sys_*` → `spectra_core`，`oa_*` → `spectra_oa`，`file_*` → `spectra_upload`，`wf_*` → `spectra_workflow`，`ai_*` → `spectra_ai`
2. 移除 MyBatis-Plus 全局 schema 配置，改为每个实体 `@TableName` 显式指定 schema
3. 将 pgvector 扩展从 `spectra_rag` 迁移到 `public`，`ai_knowledge_chunks` 表移入 `spectra_ai`，删除 `spectra_rag`
4. 修正 XML Mapper 中的 `${schema}` 占位符和 `<!--@Table-->` 注释
5. 修正 Java 硬编码的 schema 引用

## Schema 分配总览

| Schema | 表前缀 | 表数量 | 状态 |
|---|---|---|---|
| `spectra_core` | `sys_*` | 20 | 已存在，保留 |
| `spectra_oa` | `oa_*` | 11 | **新建** |
| `spectra_upload` | `file_*` | 4 | **新建** |
| `spectra_workflow` | `wf_*` + Flowable 引擎表 | 2 + 引擎表 | 已存在，追加 |
| `spectra_ai` | `ai_*` | 2 | **新建** |
| `spectra_rag` | — | 0 | **删除** |

## 详细实现步骤

### 阶段一：数据库迁移 SQL 脚本

#### 1.1 生成迁移脚本

**操作**：
- 在项目根目录生成 `migration/V20260726__split_schema.sql` 迁移脚本
- 脚本内容按以下顺序执行

**脚本内容**：

```sql
-- ============================================================
-- V20260726: 按模块拆分 PostgreSQL Schema
-- ============================================================

BEGIN;

-- 1. 新建 schema
CREATE SCHEMA IF NOT EXISTS spectra_oa;
CREATE SCHEMA IF NOT EXISTS spectra_upload;
CREATE SCHEMA IF NOT EXISTS spectra_ai;

-- 2. pgvector 扩展迁移到 public
ALTER EXTENSION vector SET SCHEMA public;

-- 3. 删除依赖 vector 操作符类的 ivfflat 索引
DROP INDEX IF EXISTS spectra_rag.ai_knowledge_chunks_embedding_idx;

-- 4. ai_knowledge_chunks 从 spectra_rag 迁移到 spectra_ai
ALTER TABLE spectra_rag.ai_knowledge_chunks SET SCHEMA spectra_ai;

-- 5. 重建 ivfflat 索引（操作符类现在在 public 下）
CREATE INDEX ai_knowledge_chunks_embedding_idx
    ON spectra_ai.ai_knowledge_chunks
    USING ivfflat (embedding vector_cosine_ops) WITH (lists = 100);

-- 6. 删除空的 spectra_rag schema
DROP SCHEMA IF EXISTS spectra_rag;

-- 7. OA 表迁移（11 张）→ spectra_oa
ALTER TABLE spectra_core.oa_asset SET SCHEMA spectra_oa;
ALTER TABLE spectra_core.oa_attendance SET SCHEMA spectra_oa;
ALTER TABLE spectra_core.oa_calendar SET SCHEMA spectra_oa;
ALTER TABLE spectra_core.oa_contact SET SCHEMA spectra_oa;
ALTER TABLE spectra_core.oa_contract SET SCHEMA spectra_oa;
ALTER TABLE spectra_core.oa_document SET SCHEMA spectra_oa;
ALTER TABLE spectra_core.oa_meeting SET SCHEMA spectra_oa;
ALTER TABLE spectra_core.oa_meeting_participant SET SCHEMA spectra_oa;
ALTER TABLE spectra_core.oa_meeting_record SET SCHEMA spectra_oa;
ALTER TABLE spectra_core.oa_notice SET SCHEMA spectra_oa;
ALTER TABLE spectra_core.oa_report SET SCHEMA spectra_oa;

-- 8. 文件表迁移（4 张）→ spectra_upload
ALTER TABLE spectra_core.file_info SET SCHEMA spectra_upload;
ALTER TABLE spectra_core.file_type SET SCHEMA spectra_upload;
ALTER TABLE spectra_core.file_upload_task SET SCHEMA spectra_upload;
ALTER TABLE spectra_core.file_upload_chunk SET SCHEMA spectra_upload;

-- 9. 工作流业务表迁移（2 张）→ spectra_workflow
ALTER TABLE spectra_core.wf_form_definition SET SCHEMA spectra_workflow;
ALTER TABLE spectra_core.wf_form_version SET SCHEMA spectra_workflow;

-- 10. AI 表迁移（1 张）→ spectra_ai
ALTER TABLE spectra_core.ai_session SET SCHEMA spectra_ai;

COMMIT;
```

**注意事项**：
- `ALTER TABLE ... SET SCHEMA` 会自动迁移表上的索引、约束、序列
- ivfflat 索引因引用 `spectra_rag.vector_cosine_ops` 必须先删后建
- 整个脚本包在事务中，失败自动回滚
- 执行前需确保无活跃连接访问被迁移的表

---

### 阶段二：移除 MyBatis-Plus 全局 schema 配置

#### 2.1 修改 application-dev.yml

**文件**：`spectra-admin/spectra-config/src/main/resources/application-dev.yml`

**操作**：删除以下两行

```yaml
# 删除 ↓
      schema: spectra_core          # global-config.db-config.schema（第 111 行）
# 删除 ↓
    schema: spectra_core            # configuration-properties.schema（第 113 行）
```

修改后：

```yaml
mybatis-plus:
  mapper-locations: classpath*:/mapper/**/*.xml
  type-aliases-package: com.devops00.**.entity
  type-handlers-package: com.devops00.spectra.common.mybatis.handler
  configuration:
    log-impl: org.apache.ibatis.logging.slf4j.Slf4jImpl
    local-cache-scope: statement
  global-config:
    banner: false
    db-config:
      id-type: assign_id
```

#### 2.2 修改 application-prod.yml

**文件**：`spectra-admin/spectra-config/src/main/resources/application-prod.yml`

**操作**：同样删除两行 schema 配置

修改后：

```yaml
mybatis-plus:
  mapper-locations: classpath*:/mapper/**/*.xml
  type-aliases-package: com.devops00.**.entity
  type-handlers-package: com.devops00.spectra.common.mybatis.handler
  configuration:
    log-impl: org.apache.ibatis.logging.nologging.NoLoggingImpl
    local-cache-scope: statement
  global-config:
    banner: false
    db-config:
      id-type: assign_id
      logic-delete-field: deleted
      logic-not-delete-value: "null"
      logic-delete-value: "now()"
```

---

### 阶段三：实体 @TableName 添加 schema

#### 3.1 spectra-core 模块（21 个实体 → schema = "spectra_core"）

**文件路径前缀**：`spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/`

| # | 实体类 | 子包 | 当前注解 | 修改后 |
|---|---|---|---|---|
| 1 | `Account.java` | auth | `@TableName(value = "sys_account")` | `@TableName(value = "sys_account", schema = "spectra_core")` |
| 2 | `User.java` | user | `@TableName(value = "sys_user")` | `@TableName(value = "sys_user", schema = "spectra_core")` |
| 3 | `Role.java` | user | `@TableName(value = "sys_role")` | `@TableName(value = "sys_role", schema = "spectra_core")` |
| 4 | `Authority.java` | user | `@TableName(value = "sys_authority")` | `@TableName(value = "sys_authority", schema = "spectra_core")` |
| 5 | `RelUserRole.java` | user | `@TableName(value = "sys_rel_user_role")` | `@TableName(value = "sys_rel_user_role", schema = "spectra_core")` |
| 6 | `RelRoleMenu.java` | user | `@TableName(value = "sys_rel_role_menu")` | `@TableName(value = "sys_rel_role_menu", schema = "spectra_core")` |
| 7 | `RelRoleAuthority.java` | user | `@TableName(value = "sys_rel_role_authority")` | `@TableName(value = "sys_rel_role_authority", schema = "spectra_core")` |
| 8 | `UserDataScope.java` | user | `@TableName(value = "sys_user_data_scope")` | `@TableName(value = "sys_user_data_scope", schema = "spectra_core")` |
| 9 | `UserDataScopeTarget.java` | user | `@TableName(value = "sys_user_data_scope_target")` | `@TableName(value = "sys_user_data_scope_target", schema = "spectra_core")` |
| 10 | `RoleDataScope.java` | user | `@TableName(value = "sys_role_data_scope")` | `@TableName(value = "sys_role_data_scope", schema = "spectra_core")` |
| 11 | `RoleDataScopeTarget.java` | user | `@TableName(value = "sys_role_data_scope_target")` | `@TableName(value = "sys_role_data_scope_target", schema = "spectra_core")` |
| 12 | `Department.java` | system | `@TableName(value = "sys_department")` | `@TableName(value = "sys_department", schema = "spectra_core")` |
| 13 | `Menu.java` | system | `@TableName(value = "sys_menu", autoResultMap = true)` | `@TableName(value = "sys_menu", schema = "spectra_core", autoResultMap = true)` |
| 14 | `DictGroup.java` | system | `@TableName(value = "sys_dict_group")` | `@TableName(value = "sys_dict_group", schema = "spectra_core")` |
| 15 | `DictItem.java` | system | `@TableName(value = "sys_dict_item")` | `@TableName(value = "sys_dict_item", schema = "spectra_core")` |
| 16 | `Configured.java` | system | `@TableName(value = "sys_config")` | `@TableName(value = "sys_config", schema = "spectra_core")` |
| 17 | `SysConfig.java` | system | `@TableName(value = "sys_config")` | `@TableName(value = "sys_config", schema = "spectra_core")` |
| 18 | `OperationLog.java` | system | `@TableName(value = "sys_log", autoResultMap = true)` | `@TableName(value = "sys_log", schema = "spectra_core", autoResultMap = true)` |
| 19 | `Region.java` | system | `@TableName(value = "sys_region")` | `@TableName(value = "sys_region", schema = "spectra_core")` |
| 20 | `Notification.java` | notification | `@TableName(value = "sys_notification")` | `@TableName(value = "sys_notification", schema = "spectra_core")` |
| 21 | `NotificationSetting.java` | notification | `@TableName(value = "sys_notification_setting")` | `@TableName(value = "sys_notification_setting", schema = "spectra_core")` |

#### 3.2 spectra-oa 模块（11 个实体 → schema = "spectra_oa"）

**文件路径前缀**：`spectra-admin/spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/`

| # | 实体类 | 子包 | 当前注解 | 修改后 |
|---|---|---|---|---|
| 1 | `Asset.java` | asset | `@TableName(value = "oa_asset")` | `@TableName(value = "oa_asset", schema = "spectra_oa")` |
| 2 | `Attendance.java` | attendance | `@TableName(value = "oa_attendance")` | `@TableName(value = "oa_attendance", schema = "spectra_oa")` |
| 3 | `Calendar.java` | calendar | `@TableName(value = "oa_calendar")` | `@TableName(value = "oa_calendar", schema = "spectra_oa")` |
| 4 | `Contact.java` | contact | `@TableName(value = "oa_contact")` | `@TableName(value = "oa_contact", schema = "spectra_oa")` |
| 5 | `Contract.java` | contract | `@TableName(value = "oa_contract")` | `@TableName(value = "oa_contract", schema = "spectra_oa")` |
| 6 | `Document.java` | document | `@TableName(value = "oa_document")` | `@TableName(value = "oa_document", schema = "spectra_oa")` |
| 7 | `Meeting.java` | meeting | `@TableName(value = "oa_meeting")` | `@TableName(value = "oa_meeting", schema = "spectra_oa")` |
| 8 | `MeetingParticipant.java` | meeting | `@TableName(value = "oa_meeting_participant")` | `@TableName(value = "oa_meeting_participant", schema = "spectra_oa")` |
| 9 | `MeetingRecord.java` | meeting | `@TableName(value = "oa_meeting_record")` | `@TableName(value = "oa_meeting_record", schema = "spectra_oa")` |
| 10 | `Notice.java` | notice | `@TableName(value = "oa_notice")` | `@TableName(value = "oa_notice", schema = "spectra_oa")` |
| 11 | `Report.java` | report | `@TableName(value = "oa_report")` | `@TableName(value = "oa_report", schema = "spectra_oa")` |

#### 3.3 spectra-upload 模块（4 个实体 → schema = "spectra_upload"）

**文件路径前缀**：`spectra-admin/spectra-modules/spectra-upload/src/main/java/com/devops00/spectra/upload/`

| # | 实体类 | 当前注解 | 修改后 |
|---|---|---|---|
| 1 | `FileInfo.java` | `@TableName(value = "file_info")` | `@TableName(value = "file_info", schema = "spectra_upload")` |
| 2 | `FileType.java` | `@TableName(value = "file_type", autoResultMap = true)` | `@TableName(value = "file_type", schema = "spectra_upload", autoResultMap = true)` |
| 3 | `FileUploadTask.java` | `@TableName(value = "file_upload_task")` | `@TableName(value = "file_upload_task", schema = "spectra_upload")` |
| 4 | `FileUploadChunk.java` | `@TableName(value = "file_upload_chunk")` | `@TableName(value = "file_upload_chunk", schema = "spectra_upload")` |

#### 3.4 spectra-workflow 模块（2 个实体 → schema = "spectra_workflow"）

**文件路径前缀**：`spectra-admin/spectra-modules/spectra-workflow/src/main/java/com/devops00/spectra/workflow/`

| # | 实体类 | 当前注解 | 修改后 |
|---|---|---|---|
| 1 | `FormDefinition.java` | `@TableName("wf_form_definition")` | `@TableName(value = "wf_form_definition", schema = "spectra_workflow")` |
| 2 | `FormVersion.java` | `@TableName("wf_form_version")` | `@TableName(value = "wf_form_version", schema = "spectra_workflow")` |

#### 3.5 spectra-ai 模块（1 个实体 → schema = "spectra_ai"）

**文件路径前缀**：`spectra-admin/spectra-modules/spectra-ai/src/main/java/com/devops00/spectra/ai/`

| # | 实体类 | 当前注解 | 修改后 |
|---|---|---|---|
| 1 | `AiSession.java` | `@TableName(value = "ai_session")` | `@TableName(value = "ai_session", schema = "spectra_ai")` |

---

### 阶段四：XML Mapper 修改

#### 4.1 替换 `${schema}` 占位符（6 个文件 9 处）

移除 `configuration-properties.schema` 后，`${schema}` 将无值可用，需替换为硬编码 `spectra_core`（这些表全部是 `sys_*`，留在 `spectra_core`）。

**文件路径前缀**：`spectra-admin/spectra-modules/spectra-core/src/main/resources/mapper/`

| # | 文件 | 行号 | 当前内容 | 修改后 |
|---|---|---|---|---|
| 1 | `user/UserDataScopeTargetMapper.xml` | 42 | `FROM ${schema}.sys_user_data_scope_target WHERE user_id = #{userId}` | `FROM spectra_core.sys_user_data_scope_target WHERE user_id = #{userId}` |
| 2 | `user/UserDataScopeTargetMapper.xml` | 47 | `FROM ${schema}.sys_user_data_scope_target` | `FROM spectra_core.sys_user_data_scope_target` |
| 3 | `user/UserDataScopeMapper.xml` | 40 | `FROM ${schema}.sys_user_data_scope AS suds` | `FROM spectra_core.sys_user_data_scope AS suds` |
| 4 | `user/UserDataScopeMapper.xml` | 46 | `FROM ${schema}.sys_user_data_scope` | `FROM spectra_core.sys_user_data_scope` |
| 5 | `user/RoleDataScopeMapper.xml` | 40 | `FROM ${schema}.sys_role_data_scope` | `FROM spectra_core.sys_role_data_scope` |
| 6 | `user/RelRoleMenuMapper.xml` | 41 | `FROM ${schema}.sys_rel_role_menu WHERE role_id = #{roleId}` | `FROM spectra_core.sys_rel_role_menu WHERE role_id = #{roleId}` |
| 7 | `user/RelRoleAuthorityMapper.xml` | 41 | `FROM ${schema}.sys_rel_role_authority WHERE role_id = #{roleId}` | `FROM spectra_core.sys_rel_role_authority WHERE role_id = #{roleId}` |
| 8 | `system/DepartmentMapper.xml` | 57 | `FROM ${schema}.sys_department` | `FROM spectra_core.sys_department` |
| 9 | `system/DepartmentMapper.xml` | 67 | `FROM ${schema}.sys_department o` | `FROM spectra_core.sys_department o` |

#### 4.2 更新 `<!--@Table-->` 注释（37 个文件）

每个 Mapper XML 第 25 行的 `<!--@Table spectra_core.xxx-->` 注释需更新为正确的 schema。

**spectra-core 模块（19 个文件）— 保持 `spectra_core` 不变**：

这些文件的注释已经是 `spectra_core.sys_*`，无需修改。

**spectra-oa 模块（11 个文件）— 改为 `spectra_oa`**：

| # | 文件 | 当前注释 | 修改后 |
|---|---|---|---|
| 1 | `mapper/attendance/AttendanceMapper.xml` | `<!--@Table spectra_core.oa_attendance-->` | `<!--@Table spectra_oa.oa_attendance-->` |
| 2 | `mapper/asset/AssetMapper.xml` | `<!--@Table spectra_core.oa_asset-->` | `<!--@Table spectra_oa.oa_asset-->` |
| 3 | `mapper/calendar/CalendarMapper.xml` | `<!--@Table spectra_core.oa_calendar-->` | `<!--@Table spectra_oa.oa_calendar-->` |
| 4 | `mapper/contact/ContactMapper.xml` | `<!--@Table spectra_core.oa_contact-->` | `<!--@Table spectra_oa.oa_contact-->` |
| 5 | `mapper/contract/ContractMapper.xml` | `<!--@Table spectra_core.oa_contract-->` | `<!--@Table spectra_oa.oa_contract-->` |
| 6 | `mapper/document/DocumentMapper.xml` | `<!--@Table spectra_core.oa_document-->` | `<!--@Table spectra_oa.oa_document-->` |
| 7 | `mapper/meeting/MeetingMapper.xml` | `<!--@Table spectra_core.oa_meeting-->` | `<!--@Table spectra_oa.oa_meeting-->` |
| 8 | `mapper/meeting/MeetingRecordMapper.xml` | `<!--@Table spectra_core.oa_meeting_record-->` | `<!--@Table spectra_oa.oa_meeting_record-->` |
| 9 | `mapper/meeting/MeetingParticipantMapper.xml` | `<!--@Table spectra_core.oa_meeting_participant-->` | `<!--@Table spectra_oa.oa_meeting_participant-->` |
| 10 | `mapper/notice/NoticeMapper.xml` | `<!--@Table spectra_core.oa_notice-->` | `<!--@Table spectra_oa.oa_notice-->` |
| 11 | `mapper/report/ReportMapper.xml` | `<!--@Table spectra_core.oa_report-->` | `<!--@Table spectra_oa.oa_report-->` |

**spectra-upload 模块（4 个文件）— 改为 `spectra_upload`**：

| # | 文件 | 当前注释 | 修改后 |
|---|---|---|---|
| 1 | `mapper/FileInfoMapper.xml` | `<!--@Table spectra_core.file_info-->` | `<!--@Table spectra_upload.file_info-->` |
| 2 | `mapper/FileTypeMapper.xml` | `<!--@Table spectra_core.file_type-->` | `<!--@Table spectra_upload.file_type-->` |
| 3 | `mapper/FileUploadTaskMapper.xml` | `<!--@Table spectra_core.file_upload_task-->` | `<!--@Table spectra_upload.file_upload_task-->` |
| 4 | `mapper/FileUploadChunkMapper.xml` | `<!--@Table spectra_core.file_upload_chunk-->` | `<!--@Table spectra_upload.file_upload_chunk-->` |

**spectra-workflow 模块（2 个文件）— 改为 `spectra_workflow`**：

| # | 文件 | 当前注释 | 修改后 |
|---|---|---|---|
| 1 | `mapper/FormDefinitionMapper.xml` | `<!--@Table spectra_core.wf_form_definition-->` | `<!--@Table spectra_workflow.wf_form_definition-->` |
| 2 | `mapper/FormVersionMapper.xml` | `<!--@Table spectra_core.wf_form_version-->` | `<!--@Table spectra_workflow.wf_form_version-->` |

**spectra-ai 模块（1 个文件）— 改为 `spectra_ai` 并修复错误**：

| # | 文件 | 当前注释 | 修改后 |
|---|---|---|---|
| 1 | `mapper/AiSessionMapper.xml` | `<!--@Table spectra_core.oa_meeting-->` **（复制粘贴错误）** | `<!--@Table spectra_ai.ai_session-->` |

---

### 阶段五：Java 硬编码 schema 修改

#### 5.1 PostgresEmbeddingStore.java

**文件**：`spectra-admin/spectra-modules/spectra-ai/src/main/java/com/devops00/spectra/ai/configuration/rag/store/PostgresEmbeddingStore.java`

| 行号 | 当前内容 | 修改后 | 说明 |
|---|---|---|---|
| 46 | `"spectra_rag.ai_knowledge_chunks"` | `"spectra_ai.ai_knowledge_chunks"` | 表迁移到 spectra_ai |
| 47 | `"::spectra_rag.vector"` | `"::vector"` | 扩展在 public，无需 schema 限定 |
| 48 | `"OPERATOR(spectra_rag.<=>)"` | `"OPERATOR(public.<=>)"` | 操作符随扩展迁移到 public |

#### 5.2 CryptoKeyManager.java — 无需修改

**文件**：`spectra-admin/spectra-framework/src/main/java/com/devops00/spectra/framework/configure/mvc/crypto/CryptoKeyManager.java`

第 158 行 `spectra_core.sys_config` — `sys_config` 表留在 `spectra_core`，无需修改。

---

### 阶段六：更新文档笔记

#### 6.1 更新实体清单

**文件**：`docs/30-数据模型/20-实体清单.md`

- 为每个实体补充 schema 信息

#### 6.2 更新基础设施笔记

**文件**：`docs/10-后端/80-基础设施.md`（如存在 schema 相关描述）

- 更新 schema 分配说明

#### 6.3 更新项目总览

**文件**：`docs/00-项目总览.md`

- 在导航中添加本计划链接（如尚未添加）

---

## 验证方案

### 编译验证

```bash
cd spectra-admin && ./mvnw clean compile -DskipTests
```

### 数据库验证（迁移后）

```sql
-- 确认各 schema 下的表数量
SELECT table_schema, COUNT(*) AS table_count
FROM information_schema.tables
WHERE table_schema IN ('spectra_core', 'spectra_oa', 'spectra_upload', 'spectra_workflow', 'spectra_ai')
  AND table_type = 'BASE TABLE'
GROUP BY table_schema
ORDER BY table_schema;

-- 预期结果：
-- spectra_core     | 20
-- spectra_oa       | 11
-- spectra_upload   |  4
-- spectra_workflow | 30+（含 Flowable 引擎表）
-- spectra_ai       |  2

-- 确认 spectra_rag 已删除
SELECT schema_name FROM information_schema.schemata WHERE schema_name = 'spectra_rag';
-- 预期：0 行

-- 确认 vector 扩展在 public
SELECT extname, nspname FROM pg_extension e JOIN pg_namespace n ON e.extnamespace = n.oid WHERE extname = 'vector';
-- 预期：vector | public

-- 确认 ivfflat 索引已重建
SELECT indexname, indexdef FROM pg_indexes WHERE schemaname = 'spectra_ai' AND tablename = 'ai_knowledge_chunks';
-- 预期：2 个索引（pkey + embedding_idx）
```

### 运行时验证

1. 启动后端：`./mvnw spring-boot:run -pl spectra-launch`
2. 验证登录接口正常（sys_account 查询）
3. 验证 OA 模块接口正常（oa_* 表查询）
4. 验证文件上传接口正常（file_* 表查询）
5. 验证 AI 会话接口正常（ai_session 查询）

## 影响范围

### 修改文件统计

| 类别 | 文件数 | 说明 |
|---|---|---|
| SQL 迁移脚本 | 1（新建） | `migration/V20260726__split_schema.sql` |
| YML 配置 | 2 | application-dev.yml、application-prod.yml |
| Java 实体 | 39 | 全部 @TableName 注解 |
| XML Mapper | 24 | 6 个替换 ${schema} + 18 个更新注释 |
| Java 硬编码 | 1 | PostgresEmbeddingStore.java |
| 文档 | 2-3 | 实体清单、基础设施笔记 |
| **合计** | **~69** | |

### 不受影响的文件

- `CryptoKeyManager.java` — `spectra_core.sys_config` 不变
- `PostgresEmbeddingStore.java` 以外的 AI 模块代码 — 不直接引用 schema
- Flowable 引擎配置 — `flowable.database-schema: spectra_workflow` 不变
- 前端代码 — 不涉及 schema
- `BaseMapper.xml` — 不含表名引用

## 相关

- [[20-实体清单]] — 全部实体字典
- [[10-ER图]] — 实体关系图
- [[80-基础设施]] — MyBatis-Plus / PostgreSQL 配置
- [[40-数据库命名规范]] — 表/字段/索引命名约定
