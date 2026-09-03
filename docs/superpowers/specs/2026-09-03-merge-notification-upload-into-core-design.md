# 将通知与文件上传合并到 Core 设计

> 状态：已确认设计，待编写实现计划。

## 目标

将 `spectra-notification` 和 `spectra-upload` 从独立的可选 Maven 业务模块彻底合并到 `spectra-core`，作为系统始终提供的核心能力，同时保持现有 REST API、数据库表、Flyway 迁移、运行配置前缀和跨模块公共契约不变。

## 范围与非目标

### 范围

- 将通知源码、测试和 Mapper 资源迁移到 `spectra-core`。
- 将文件上传源码、测试和相关配置资源迁移到 `spectra-core`。
- 将 Java 包根分别调整为 `com.devops00.spectra.core.notification` 和 `com.devops00.spectra.core.upload`。
- 删除两个独立 Maven 模块、自动配置入口和启动层直接依赖。
- 让 `CoreModule` 成为通知和上传实现的唯一自动装配入口。
- 删除 `spectra.modules.notification.enabled` 和 `spectra.modules.upload.enabled` 装配开关。
- 清理 Core、Launch、OA、架构测试和知识库中对旧模块边界的描述。

### 非目标

- 不修改 `/notification/**`、`/file/**` REST 路径。
- 不修改 PostgreSQL schema、表名、字段、Mapper namespace 或 Flyway migration。
- 不修改 `spectra.notification.*`、`file.upload.*`、`file.upload.local.*`、`file.upload.s3.*` 配置前缀。
- 不将通知或上传实现移动到 `spectra-common` 或 `spectra-framework`。
- 不新增旧包名、旧 Maven artifact 或兼容转发类。

## 目标架构

合并后的业务模块树为：

```text
spectra-modules
├── spectra-core
│   ├── com.devops00.spectra.core.security
│   ├── com.devops00.spectra.core.user
│   ├── com.devops00.spectra.core.system
│   ├── com.devops00.spectra.core.scheduler
│   ├── com.devops00.spectra.core.notification
│   └── com.devops00.spectra.core.upload
├── spectra-workflow
└── spectra-oa
```

`spectra-core` 仍然是必选业务核心，`spectra-workflow` 和 `spectra-oa` 仍由 `spectra-launch` 可选装配。通知和上传不再属于可选装配集合，也不再由 Launch 作为独立模块引入。

`CoreModule` 负责：

- 扫描 `com.devops00.spectra.core` 下全部业务 Bean；
- 扫描 Core 原有 Mapper 以及 `core.notification`、`core.upload` 下的 Mapper；
- 注册通知配置属性和清理配置属性；
- 通过统一入口装配通知 Provider、通知 Worker、上传 Storage Provider、文件清理任务和健康贡献者。

`spectra-common` 继续提供 `common.notification` 和 `common.port.file` 契约。OA、Workflow、认证和监控只依赖这些契约，不直接引用 Core 内部 Entity、Mapper 或 Service。

## 源码与资源迁移

### 通知

将：

```text
spectra-modules/spectra-notification/src/main/java/com/devops00/spectra/notification
spectra-modules/spectra-notification/src/test/java/com/devops00/spectra/notification
```

迁移为：

```text
spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/notification
spectra-modules/spectra-core/src/test/java/com/devops00/spectra/core/notification
```

所有包声明和内部引用同步替换 `com.devops00.spectra.notification` 为 `com.devops00.spectra.core.notification`。通知 Mapper XML 迁移到 Core 的 `src/main/resources/mapper`，保持原文件名，并将 MyBatis `namespace` 同步为新的 Mapper 接口全限定名；数据库表和 SQL 语义不变。

删除 `NotificationModule` 及其 `AutoConfiguration.imports`。通知配置属性由 `CoreModule` 注册，通知组件由 Core 包扫描发现。

### 文件上传

将：

```text
spectra-modules/spectra-upload/src/main/java/com/devops00/spectra/upload
spectra-modules/spectra-upload/src/test/java/com/devops00/spectra/upload
```

迁移为：

```text
spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/upload
spectra-modules/spectra-core/src/test/java/com/devops00/spectra/core/upload
```

所有包声明和内部引用同步替换 `com.devops00.spectra.upload` 为 `com.devops00.spectra.core.upload`。上传的本地存储、S3 Provider、分片服务、文件管理接口、清理服务和健康贡献者全部属于 Core 的 upload 子域。

删除 `UploadModule` 及其 `AutoConfiguration.imports`。上传配置 Bean 随 Core 包扫描注册，保留现有文件上传配置前缀和 Bean 名称（包括 `fileUploadTaskExecutor`）。原 Upload 专用测试启动类不再作为独立模块入口，迁移后的测试统一使用 Core 测试上下文或现有单元测试装配。

## Maven 依赖与装配

- 从 `spectra-modules/pom.xml` 删除 `spectra-notification` 和 `spectra-upload` 两个 module entry。
- 删除两个模块的 `pom.xml` 和模块目录。
- 将 `spring-boot-starter-mail`、AWS SDK S3 依赖和 `tika-core` 迁移到 `spectra-core/pom.xml`；版本沿用当前父 POM 或原 Upload POM 的明确版本。
- 保留 Core 已有的 Flyway、Testcontainers 和配置测试依赖，不重复引入已存在的依赖。
- 从 `spectra-launch/pom.xml` 删除两个独立 artifact 依赖；Launch 通过 Core 获得通知和上传运行时能力。
- 从 `spectra-oa/pom.xml` 删除 `spectra-upload` 依赖；OA 继续使用 `common.port.file`。
- 不改变 Workflow/OA 对 `common.notification`、`common.port.file` 的调用方式。

## 运行时配置与行为

### 装配开关

`ModuleAssembly` 只识别 `core`、`workflow`、`oa`。删除 Notification/Upload 常量、已知可选模块条目和相关必需 adapter 约束。OA 仍要求 Workflow；通知和上传不再作为外部 adapter 检查。

以下配置不再控制 Bean 是否注册：

```text
spectra.modules.notification.enabled
spectra.modules.upload.enabled
```

### 通知业务开关

保留 `spectra.notification.enabled` 及其 `sys_config` 动态读取语义。它是通知业务功能开关，而不是模块装配开关：

- 通知 Bean 始终存在；
- 关闭时通知投递按既有语义被阻断；
- 通知健康贡献者返回 `UNKNOWN` 和安全摘要；
- 系统设置引导继续维护通知开关、AES 密钥和清理开关。

通知和上传相关的 `ConditionalOnProperty` 装配条件移除；通知健康贡献者和上传健康贡献者始终由 Core 注册。Core 内原先为“通知未装配”准备的 nullable 注入、Optional setter 和错误分支改为必需的构造器注入，避免能力已经成为 Core 后仍保留不可达的可选模块语义。

## 测试策略

采用先红后绿的 TDD 流程。

### 红灯契约

先在 Launch 架构测试中增加或调整契约，断言：

- Core 存在 `core.notification` 和 `core.upload` 包；
- 独立模块目录、artifact 和自动配置入口不存在；
- Core POM 拥有邮件、S3、Tika 依赖；
- Launch 不再依赖两个已删除 artifact；
- Core 自动配置能够发现通知和上传 Bean、Mapper；
- `ModuleAssembly` 不再读取或返回 Notification/Upload 可选模块；
- OA、Workflow 的生产源码不直接引用 Core 内部实现；
- 源码中不存在旧包根引用。

在旧结构下运行该测试，确认失败原因是模块仍未合并，而不是测试自身错误。

### 迁移后的验证

- 移动后的通知单元测试、Provider 测试、健康检查和 SQL 契约测试全部在 Core 测试源集中运行；
- 移动后的上传单元测试、Storage Provider 测试、健康检查和 SQL 契约测试全部在 Core 测试源集中运行；
- Core 原有认证、监控、调度、审计测试继续通过；
- Launch 架构和组合装配测试通过；
- 全量 `verify` 通过；
- 使用 dev profile 启动后，HTTPS `4004` 可接受请求，并确认通知/上传能力已装配。

## 文档同步

同步以下事实来源：

- `docs/00-项目总览.md`；
- `docs/10-后端/10-架构分层.md`；
- `docs/10-后端/11-模块边界清单.md`；
- `docs/10-后端/12-能力归属矩阵.md`；
- `docs/10-后端/15-spectra-core模块.md`；
- `docs/10-后端/30-系统管理.md`；
- `docs/10-后端/50-文件上传.md`；
- `docs/10-后端/75-统一通知模块.md`；
- `docs/10-后端/80-基础设施.md`；
- `docs/30-数据模型/20-实体清单.md` 及 ER/数据库说明中模块归属；
- `docs/70-AI速查/01-架构概览.md`、`02-模块清单.md`、`05-配置清单.md`、`06-依赖版本.md`；
- 其他由全局搜索发现的旧模块路径、旧包根和可选装配描述。

由于实体、Controller、配置前缀和数据库表结构不变，不新增数据库迁移；完成后运行 `scripts/check-docs.sh`。

## 验收标准

1. `spectra-modules` 聚合中只保留 Core、Workflow、OA 三个业务模块。
2. Core 包含通知和上传全部实现、测试、Mapper 资源和配置 Bean。
3. 生产源码中不存在旧 `com.devops00.spectra.notification`、`com.devops00.spectra.upload` 包根引用。
4. 不存在独立 `spectra-notification`、`spectra-upload` Maven artifact 或自动配置入口。
5. REST API、数据库表、迁移链、公共契约和运行配置前缀保持不变。
6. Core、Launch、OA、Workflow 的目标测试和全量构建通过。
7. dev profile 启动成功，HTTPS `4004` 可接受请求。
8. 文档检查通过，主仓库和 `spectra-admin` 子仓库无未提交的实现残留（设计文档提交除外的后续代码变更按实现阶段处理）。
