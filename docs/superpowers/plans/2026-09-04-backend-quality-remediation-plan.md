# 后端合并模块质量整改 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在不改变现有 API 1.0.0、数据库结构和安全语义的前提下，消除 OA 对 core 内部实现的穿透，减少关键查询链路的中间调用，完成 `spectra-framework` 包布局和不安全实现的治理，并把合并后的 Spring Boot 后端收敛到可维护、可测试的模块化结构。

**Architecture:** 保留单体模块化架构和 `launch → modules/starter → framework → common/config` 依赖方向。跨模块调用统一通过 `spectra-common` 中的稳定 Port/DTO，core 负责实现 Port；查询优化采用批量读取、递归 CTE 或统一报表仓储；复杂 Service 按用例拆分，事务入口放在独立 Spring Bean 的 public 方法上；`FrameworkModule` 是 framework 唯一自动配置入口，通过 `@ComponentScan(basePackageClasses = FrameworkModule.class)` 扫描整个 framework 根包，各能力包自持配置和运行时实现并自动装配。

**Tech Stack:** Java 25、Spring Boot 4.1.0、Maven Wrapper 3.9.12、MyBatis-Plus 3.5.15、PostgreSQL/Flyway、JUnit 5、Mockito、AssertJ、ArchUnit、Spotless、Checkstyle、PMD、SpotBugs、mise。

**Spec:** `docs/superpowers/specs/2026-09-04-backend-quality-remediation-design.md`

## Global Constraints

- 当前 API 契约版本统一为 `1.0.0`；不新增旧入口、别名、回退读取或临时兼容分支。
- 不修改 REST 路径、数据库表/字段、Mapper namespace、Flyway migration 和现有配置前缀，除非某个任务明确记录兼容性影响。
- 不读取、输出、提交 `.mise.local.toml`、数据库密码、Token、私钥、证书私钥或其他本机凭据。
- 安全 Redis 仍通过既有安全 Port/Executor 访问；连接失败、命令失败或无法确认状态时必须 fail-closed。
- Java 生产代码保持 Java 25、Apache License 2.0 文件头、Javadoc、`@author`、`@version`、`@since` 约定。
- `var` 只用于局部变量和 try-with-resources，且初始化表达式能清楚表达类型时优先使用；公共签名、字段、空值初始化、数值宽度/安全边界和复杂泛型推断保留显式类型，不进行无收益的全量机械替换。
- Controller 使用构造器注入，仅处理绑定、授权和转发；Service 使用构造器注入，写操作定义清晰事务边界；转换使用 MapStruct、`GlobalMapperConfig` 和 `TimeMapper`。
- API VO 不直接暴露 `Instant`；Entity 内部时间继续使用项目现有类型。
- 异步导入和上传验证不使用覆盖整批数据的长事务；采用分块事务、状态机和幂等键。
- `framework.configure` 生产包及其子包必须消失：配置入口、属性和装配类与运行时实现一并归位到 `framework.security`、`framework.web`、`framework.persistence`、`framework.cache`、`framework.captcha`、`framework.serialization`、`framework.assembler` 和 `framework.health` 等明确的能力包，不能形成新的配置上帝包。
- 包名迁移不得意外改变 Bean 名称、`@ConfigurationProperties` 前缀、REST 路径、Mapper namespace、Redis key、Token 不透明性或序列化契约；发现兼任装配与运行时职责的类时先拆分职责。
- Framework 仅由 `FrameworkModule` 使用 `@ComponentScan(basePackageClasses = FrameworkModule.class)` 扫描自身根包；不再维护能力级 `AssemblerAutoConfiguration`、局部扫描或重复显式导入。安全配置、异步分发、CSRF、点击劫持、请求/响应加密和 JSON 反序列化均须以失败测试锁定 fail-closed 或明确的安全例外。
- 全后端工具类按能力建立唯一归属和权威实现；不得把模块级工具简单复制到 `common.utils`，也不得让纯工具、Web 适配、安全算法和业务辅助互相越层。调用方迁移完成后删除旧工具、别名和回退入口。
- 需要 Bean、策略集合、运行时注册表或安全状态的能力必须由实际领域的 Spring 组件统一编排；只在同一领域存在真实扩展点时提取 Resolver/Registry/Policy，不创建跨领域的万能 `Assembler` 或通用 Registry。
- Service 公共契约 Javadoc 只写在接口；实现不重复接口注释，只为非显然算法、并发/事务不变量和外部约束补充必要注释。设计模式只有在至少两个真实变体且有可测收益时才落地。
- 每个任务先写或补充失败测试，再写最小实现；每个任务完成后运行该任务的聚焦测试和相关质量检查。
- 本计划文件位于 `docs/superpowers/plans/`，由现有 `.gitignore` 的 `superpowers/` 规则忽略；实施代码是否提交不改变计划文件的忽略状态。
- Maven 命令代码块从 `spectra-admin/` 执行；Git 命令代码块从工作区根目录执行，计划文件不加入任何 `git add`。

---

## 工作包 A：模块边界和 API 契约

### Task 1: 修复架构扫描假阴性

**Files:**
- Modify: `spectra-admin/spectra-launch/src/test/java/com/devops00/spectra/architecture/OptionalModuleIsolationTest.java:110`

**Interfaces:**
- Consumes: Maven 多模块根路径、OA `src/main/java` 源码、现有 common Port 和 Workflow API。
- Produces: 在 Linux/Windows 路径下都能扫描非空生产源码，为后续 OA-core 边界断言提供可信的源码集合。

- [x] **Step 1: Write the failing tests**

  在 `OptionalModuleIsolationTest` 中用 `Path` 分段筛选生产源文件，不再匹配固定反斜杠，并增加非空断言：

  ```java
  var productionSources = uncheckedJavaSources(backend).stream()
          .filter(path -> path.toString().replace('\\', '/').contains("src/main/java"))
          .toList();
  assertThat(productionSources).isNotEmpty();
  ```

- [x] **Step 2: Run the tests to verify the boundary is red**

  Run:

  ```bash
  cd spectra-admin
  mise exec -- ./mvnw -pl spectra-launch -am \
      -Dtest=OptionalModuleIsolationTest \
      -Dsurefire.failIfNoSpecifiedTests=false test
  ```

  Expected: 新增非空断言在修复前因 Linux 路径筛选为空而失败；失败信息必须明确显示扫描集合为空，而不是 Java 编译错误。

- [x] **Step 3: Implement only the test infrastructure fix**

  将源文件路径判断统一改为 `replace('\\', '/')` 后匹配 `src/main/java`，保留现有 `@Audit` 检查；不得通过删除断言或过滤全部文件使测试变绿。

- [x] **Step 4: Run the focused tests**

  Run the same Maven command. Expected: `OptionalModuleIsolationTest` 通过，并且扫描到的生产源码数量大于 0。

- [x] **Step 5: Commit only the test infrastructure change**

  ```bash
  git add spectra-admin/spectra-launch/src/test/java/com/devops00/spectra/architecture/OptionalModuleIsolationTest.java
  git commit -m "test: make module boundary scan portable"
  ```

### Task 2: 建立 Directory 和 Scheduler TimeZone Port

**Files:**
- Create: `spectra-admin/spectra-common/src/main/java/com/devops00/spectra/common/port/directory/DirectoryUserSnapshot.java`
- Create: `spectra-admin/spectra-common/src/main/java/com/devops00/spectra/common/port/directory/DirectoryDepartmentSnapshot.java`
- Create: `spectra-admin/spectra-common/src/main/java/com/devops00/spectra/common/port/directory/DirectoryContactSnapshot.java`
- Create: `spectra-admin/spectra-common/src/main/java/com/devops00/spectra/common/port/directory/DirectoryQueryPort.java`
- Create: `spectra-admin/spectra-common/src/main/java/com/devops00/spectra/common/port/scheduler/SchedulerTimeZonePort.java`
- Create: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/directory/DirectoryQueryAdapter.java`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/scheduler/service/SchedulerTimeZoneResolver.java:27`
- Test: `spectra-admin/spectra-common/src/test/java/com/devops00/spectra/common/port/directory/DirectoryPortContractTest.java`
- Test: `spectra-admin/spectra-modules/spectra-core/src/test/java/com/devops00/spectra/core/directory/DirectoryQueryAdapterTest.java`
- Test: `spectra-admin/spectra-modules/spectra-core/src/test/java/com/devops00/spectra/core/scheduler/SchedulerTimeZoneResolverTest.java`

**Interfaces:**
- Consumes: core 的 `UserMapper`、`DepartmentMapper`、`UserContactService` 和 `SchedulerTimeZoneResolver` 内部实现。
- Produces: OA 可依赖的纯 Java Port；core 内部 Adapter 负责把 Entity/Mapper 结果转换为快照 DTO。

  定义以下接口，不把 MyBatis 类型、Entity 类型或 Spring 类型暴露到 common Port：

  ```java
  public interface DirectoryQueryPort {
      List<DirectoryUserSnapshot> findUsersByIds(Collection<UUID> userIds);
      List<DirectoryDepartmentSnapshot> findDepartmentsByIds(Collection<UUID> departmentIds);
      List<DirectoryDepartmentSnapshot> listDepartments();
      Map<UUID, List<DirectoryContactSnapshot>> findActiveContactsByUserIds(Collection<UUID> userIds);
  }

  public interface SchedulerTimeZonePort {
      ZoneId resolve();
      ZoneId resolve(String configuredValue);
  }
  ```

  快照 DTO 至少包含当前 OA 转换所需的 `UUID id`、显示名称、父部门/路径、用户状态和联系方式字段；联系方式按用户 ID 分组返回，空集合返回空 Map，不返回 null。

- [x] **Step 1: Write contract tests**

  测试 `DirectoryQueryPort` 的空输入、重复 ID、结果分组和不可变快照语义；测试 `SchedulerTimeZonePort` 保持现有 `null/blank/非法值 → UTC`、合法 IANA 时区正常解析、配置数据库异常向上抛出的行为。

- [x] **Step 2: Run tests to verify the new contracts fail to compile**

  ```bash
  cd spectra-admin
  mise exec -- ./mvnw -pl spectra-common,spectra-core -am \
      -Dtest=DirectoryPortContractTest,SchedulerTimeZoneResolverTest \
      -Dsurefire.failIfNoSpecifiedTests=false test
  ```

  Expected: 新增 Port/Adapter 类型尚未存在时编译失败；已有时区测试的行为基线必须先记录。

- [x] **Step 3: Implement the Core adapter**

  `DirectoryQueryAdapter` 使用构造器注入 Mapper 和 `UserContactService`，按以下顺序执行：去重输入 ID → 空输入直接返回空集合 → 一次批量读取用户/部门 → 一次批量读取有效联系方式 → MapStruct 或专用静态映射生成快照。不得返回 core Entity。

  让 `SchedulerTimeZoneResolver` 实现 `SchedulerTimeZonePort`，保留现有两个 `resolve` 方法行为，不增加 OA 对 `ConfiguredService` 的依赖。

- [x] **Step 4: Run the adapter tests**

  Run the same command. Expected: Port contract、Adapter mock 测试和原有时区测试全部通过。

- [x] **Step 5: Commit the stable Port contract**

  ```bash
  git add spectra-admin/spectra-common/src/main/java/com/devops00/spectra/common/port/directory \
      spectra-admin/spectra-common/src/main/java/com/devops00/spectra/common/port/scheduler \
      spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/directory \
      spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/scheduler/service/SchedulerTimeZoneResolver.java \
      spectra-admin/spectra-common/src/test spectra-admin/spectra-modules/spectra-core/src/test
  git commit -m "refactor: add core directory and timezone ports"
  ```

### Task 3: 迁移 OA 调用方到 Port/DTO

**Files:**
- Modify: `spectra-admin/spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/contact/service/impl/ContactServiceImpl.java:41`
- Modify: `spectra-admin/spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/contact/javabean/converter/ContactConverter.java:19`
- Modify: `spectra-admin/spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/document/service/impl/DocumentServiceImpl.java:31`
- Modify: `spectra-admin/spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/notice/service/impl/NoticeServiceImpl.java:30`
- Modify: `spectra-admin/spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/meeting/service/impl/MeetingServiceImpl.java:30`
- Modify: `spectra-admin/spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/report/javabean/converter/DepartmentStatsConverter.java:19`
- Modify: `spectra-admin/spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/report/service/impl/DepartmentStatsServiceImpl.java:21`
- Modify: `spectra-admin/spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/contract/service/impl/ContractServiceImpl.java:31`
- Create: `spectra-admin/spectra-launch/src/test/java/com/devops00/spectra/architecture/OaCoreBoundaryTest.java`
- Test: corresponding OA Service and converter tests

**Interfaces:**
- Consumes: Task 2 的 `DirectoryQueryPort`、快照 DTO 和 `SchedulerTimeZonePort`。
- Produces: OA Service 只依赖 common Port/DTO；`OaCoreBoundaryTest` 通过；REST 输出字段和权限过滤不变。

- [x] **Step 1: Add the failing OA boundary test and service assertions**

  在 `OaCoreBoundaryTest` 中遍历 OA 生产 Java 文件，收集 `import com.devops00.spectra.core...`，断言结果为空；Workflow 只允许 `com.devops00.spectra.workflow.api...`，common Port 仍然允许。测试输出违规文件和完整 import，便于定位。

  在 Contact、Document、Notice、Meeting、DepartmentStats、Contract 的 Service 测试中，把 core Service/Mapper mock 替换为 Port mock，并增加验证：一次业务操作只调用对应 Port，不调用 core Entity 方法或 core Mapper。

- [x] **Step 2: Run the OA tests to expose direct dependency failures**

  ```bash
  cd spectra-admin
  mise exec -- ./mvnw -pl spectra-oa -am test
  ```

  Expected: `OaCoreBoundaryTest` 因现有 OA core import 失败；Service 测试的失败点集中在上述 8 个 OA 文件，不应扩散到 Workflow。

- [x] **Step 3: Replace direct core dependencies**

  - `ContactServiceImpl` 使用 `DirectoryQueryPort` 一次取得用户、部门和联系方式快照；删除 `UserMapper`、`DepartmentMapper`、`UserContactService` 字段和 core Entity import。
  - `DocumentServiceImpl`、`NoticeServiceImpl`、`MeetingServiceImpl` 使用 `findUsersByIds` 或按登录名查询的 Directory Port 方法；把转换器输入改为快照 DTO。
  - `DepartmentStatsServiceImpl` 用 `listDepartments()` 返回的部门快照建立名称 Map；删除 `DepartmentService`、`Department` 和 `DepartmentStatsConverter.toVO(Department)`。
  - `ContractServiceImpl` 使用 `SchedulerTimeZonePort.resolve()`；删除 `SchedulerTimeZoneResolver` 的 core 直接 import。
  - 保留 OA 自己的 Entity、Mapper、Converter；不把 common Port 反向依赖 OA 类型。

- [x] **Step 4: Run focused and boundary tests**

  ```bash
  mise exec -- ./mvnw -pl spectra-oa,spectra-launch -am \
      -Dtest='**/*ServiceImplTest,**/*ConverterTest,OaCoreBoundaryTest' \
      -Dsurefire.failIfNoSpecifiedTests=false test
  ```

  Expected: OA 测试通过，`OaCoreBoundaryTest` 不再输出 core import；响应字段、空部门、无联系方式和非法时区回退行为保持原结果。

- [x] **Step 5: Commit the OA boundary migration**

  ```bash
  git add spectra-admin/spectra-modules/spectra-oa spectra-admin/spectra-common/src/main/java/com/devops00/spectra/common/port
  git commit -m "refactor: route oa through core ports"
  ```

## 工作包 B：减少数据库往返

### Task 4: 将部门统计改为统一报表查询

**Files:**
- Modify: `spectra-admin/spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/report/service/impl/DepartmentStatsServiceImpl.java:80`
- Create: `spectra-admin/spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/report/mapper/DepartmentStatsQueryMapper.java`
- Create: `spectra-admin/spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/report/javabean/entity/DepartmentStatsRow.java`
- Create: `spectra-admin/spectra-modules/spectra-oa/src/main/resources/mapper/DepartmentStatsQueryMapper.xml`
- Modify: `spectra-admin/spectra-modules/spectra-oa/src/test/java/com/devops00/spectra/oa/report/service/DepartmentStatsServiceTest.java`

**Interfaces:**
- Consumes: 现有 `AssetMapper`、`SupplyItemMapper`、`ReimbursementMapper`、`PurchaseMapper` 的四个聚合字段和部门快照 Port。
- Produces: `DepartmentStatsQueryMapper.selectByDepartmentIds(Collection<UUID> departmentIds)` 一次返回可见部门的完整统计行；Service 只做权限范围、空数据、排序和 VO 映射。

- [x] **Step 1: Write the SQL-call-count test**

  使用 Mockito 验证 `DepartmentStatsServiceImpl.list` 只调用一次 `DepartmentStatsQueryMapper.selectByDepartmentIds`，不再调用四个业务 Mapper；使用一组包含完整字段和一组全零字段的 `DepartmentStatsRow` 验证结果过滤与排序。

- [x] **Step 2: Run the test to verify the old implementation fails**

  ```bash
  cd spectra-admin
  mise exec -- ./mvnw -pl spectra-modules/spectra-oa -am \
      -Dtest=DepartmentStatsServiceTest test
  ```

  Expected: 旧实现仍会调用 `assetMapper`、`supplyItemMapper`、`reimbursementMapper`、`purchaseMapper`，因此调用次数断言失败。

- [x] **Step 3: Implement the single query**

  把现有四个聚合的字段原样放入一个 XML 查询，统一按 `department_id` 聚合，并用 `WHERE department_id IN (...)` 限制 Task 3 传入的可见部门 ID；四个业务子查询分别只保留自己的表和过滤条件，再通过 `FULL OUTER JOIN ... USING (department_id)` 合并，输出以下列：

  ```text
  department_id,
  asset_count, asset_quantity, asset_value,
  supply_sku_count, supply_stock, supply_min_stock,
  reimbursement_count, reimbursement_amount,
  purchase_count, purchase_budget
  ```

  `departmentId != null` 时只向 Mapper 传入目标部门 ID，避免先聚合全表再过滤；保留现有“没有业务数据的部门不返回”规则。删除 `mergeAssetStats`、`mergeSupplyStats`、`mergeReimbursementStats`、`mergePurchaseStats` 和四个业务 Mapper 字段。

- [x] **Step 4: Run service and SQL contract tests**

  ```bash
  mise exec -- ./mvnw -pl spectra-modules/spectra-oa -am \
      -Dtest=DepartmentStatsServiceTest,DepartmentStatsQueryMapperSqlContractTest test
  ```

  Expected: Service 调用次数为 1，SQL 包含四组统计列和部门过滤条件；导出接口仍通过 `list(from)` 使用相同结果。

- [x] **Step 5: Commit the report query consolidation**

  ```bash
  git add spectra-admin/spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/report \
      spectra-admin/spectra-modules/spectra-oa/src/main/resources/mapper \
      spectra-admin/spectra-modules/spectra-oa/src/test
  git commit -m "perf: consolidate department statistics query"
  ```

### Task 5: 消除 Region 父链逐级查询

**Files:**
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/service/impl/RegionServiceImpl.java:94`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/mapper/RegionMapper.java`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/resources/mapper/system/RegionMapper.xml`
- Create: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/javabean/entity/RegionPathRow.java`
- Test: `spectra-admin/spectra-modules/spectra-core/src/test/java/com/devops00/spectra/core/system/service/RegionServiceImplTest.java`
- Test: Region SQL contract test under `spectra-admin/spectra-modules/spectra-core/src/test/java`

**Interfaces:**
- Consumes: `RegionService.getPath(UUID id)` 当前的路径和父节点语义。
- Produces: 一次 Mapper 调用获取完整父链；非法 ID 返回现有空/异常结果，循环引用和超过最大深度的树不会造成无限循环。

- [x] **Step 1: Write the call-count and cycle tests**

  为根节点、三级父链、缺失节点和循环引用分别建立测试；三级父链用 Mockito 验证 Mapper 调用次数为 1。输出路径必须与当前顺序一致。

- [x] **Step 2: Run the tests to verify old behavior is N+1**

  ```bash
  cd spectra-admin
  mise exec -- ./mvnw -pl spectra-modules/spectra-core -am \
      -Dtest=RegionServiceImplTest,RegionMapperSqlContractTest test
  ```

  Expected: 三级父链的旧实现调用 `selectById` 多次，调用次数断言失败。

- [x] **Step 3: Implement a recursive CTE mapper method**

  增加 `List<RegionPathRow> selectPath(UUID id, int maxDepth)`，SQL 使用 PostgreSQL `WITH RECURSIVE`，从目标节点向 `pid` 上溯，带 `depth` 和 `visited` 防循环字段；Service 按 `depth` 倒序组装原有路径。`maxDepth` 固定为 64，并在超限时抛出项目自定义数据异常，不使用 `IllegalStateException`。

- [x] **Step 4: Run unit and SQL contract tests**

  预期所有路径结果、根节点行为、缺失节点行为和循环保护测试通过，且单次 `getPath` 只触发一个 Region Mapper 查询。

- [x] **Step 5: Commit the Region query change**

  ```bash
  git add spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system \
      spectra-modules/spectra-core/src/main/resources/mapper \
      spectra-modules/spectra-core/src/test
  git commit -m "perf(core): 一次查询行政区划路径"
  ```

### Task 6: 收敛通知任务创建的 N+1 路径

**Files:**
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/notification/service/impl/NotificationGatewayImpl.java:232`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/notification/mapper/NotificationTaskMapper.java`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/notification/mapper/NotificationTemplateMapper.java`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/resources/mapper/NotificationTaskMapper.xml`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/resources/mapper/NotificationTemplateMapper.xml`
- Create: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/notification/service/NotificationTaskBatchPlanner.java`
- Test: notification gateway and task Mapper tests under `spectra-admin/spectra-modules/spectra-core/src/test/java`

**Interfaces:**
- Consumes: 当前接收人×渠道循环、任务重复检查和模板渲染流程。
- Produces: 一个批次内模板只读取一次，已有幂等键一次批量查询，新增任务批量写入；发送结果、重试和幂等语义不变。

- [x] **Step 1: Write the batch interaction tests**

  使用 3 个接收人、2 个渠道构造测试，验证模板查询次数为每个模板/渠道一次、重复任务查询为一次批量查询、任务插入为一次批量调用；测试已有任务、空模板、单渠道失败和重复请求。

- [x] **Step 2: Run the tests to capture old N+1 behavior**

  ```bash
  cd spectra-admin
  mise exec -- ./mvnw -pl spectra-modules/spectra-core -am \
      -Dtest='*NotificationGateway*Test,*NotificationTask*Test' test
  ```

  Expected: 旧实现的 `createTask`/`render` 路径会产生逐接收人、逐渠道调用，批量调用次数断言失败。

- [x] **Step 3: Implement batch planning**

  `NotificationTaskBatchPlanner` 接收去重后的 `(recipientId, channel)` 集合和模板快照 Map，生成带幂等键的任务草稿；Mapper 增加按幂等键集合查询和 `insertBatch`。数据库唯一约束作为最终幂等保证，重复插入按现有业务异常/跳过语义处理。发送动作仍由既有 Provider 执行，不在批量规划器中加入线程池。

- [x] **Step 4: Run gateway tests and verify query counts**

  预期 6 个组合最多产生 1 次模板加载、1 次幂等查询和 1 次批量插入；失败任务、重试任务和审计内容不改变。

- [x] **Step 5: Commit the notification batching change**

  ```bash
  git add spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/notification \
      spectra-modules/spectra-core/src/main/resources/mapper \
      spectra-modules/spectra-core/src/test
  git commit -m "perf(core): 批量规划通知投递任务"
  ```

## 工作包 C：Spring Boot 规范、上传和大类重构

### Task 7: 规范上传 ID、事务入口和验证 Worker

**Files:**
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/upload/service/FileReferenceApplicationService.java:41`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/upload/service/UploadApplicationService.java:55`
- Create: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/upload/service/UploadVerificationWorker.java`
- Create: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/upload/service/UploadSessionService.java`
- Create: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/upload/service/UploadPartService.java`
- Test: existing upload Service tests plus `UploadVerificationWorkerTest`

**Interfaces:**
- Consumes: 上传创建、分片写入、完成校验和文件引用授权流程。
- Produces: `UploadApplicationService` 只编排用例；验证由独立 Spring Worker 的 public transactional 方法执行；数据库主键由统一 MetaObjectHandler 生成，存储 Key/会话 ID 明确分离。

- [x] **Step 1: Add ID and proxy regression tests**

  测试文件引用创建时不调用 `UUID.randomUUID()` 作为 Entity 主键；上传会话和分片的数据库主键由 MetaObjectHandler 处理；上传完成后调用 `UploadVerificationWorker`，不再从 `ObjectProvider<UploadApplicationService>` 取自身实例。使用 Mockito 验证 Worker 是独立依赖。

- [x] **Step 2: Run upload tests to verify old violations**

  ```bash
  cd spectra-admin
  mise exec -- ./mvnw -pl spectra-modules/spectra-core -am \
      -Dtest='*Upload*Test,*FileReference*Test' test
  ```

  Expected: 旧实现会在主键创建或自代理调用断言处失败；如果上传会话 ID 确实同时承担存储 Key，测试必须将其改名为显式 `uploadSessionId` 并验证 Entity ID 仍由处理器生成。

- [x] **Step 3: Split upload orchestration**

  - `UploadSessionService` 负责创建/完成/失败状态转换和会话幂等。
  - `UploadPartService` 负责分片元数据和分片状态，不负责对象存储校验。
  - `UploadVerificationWorker` 负责文件流、摘要校验、对象存储确认和失败状态更新；方法使用独立 Bean 的 `@Transactional` 入口。
  - `FileReferenceApplicationService` 删除手工主键赋值，使用统一 ID 生成机制；将英文裸异常改为项目自定义异常和中文业务消息。
  - 保持外部存储调用失败时的清理和失败状态语义；不把对象存储网络调用包进长数据库事务，必要时使用“校验中/已确认/失败”状态机。

- [x] **Step 4: Run focused upload tests and full core tests**

  ```bash
  mise exec -- ./mvnw -pl spectra-modules/spectra-core -am \
      -Dtest='*Upload*Test,*FileReference*Test,UploadVerificationWorkerTest' test
  mise exec -- ./mvnw -pl spectra-modules/spectra-core -am test
  ```

  Expected: ID、状态机、失败清理、事务代理和已有上传功能测试全部通过。

- [x] **Step 5: Commit the upload boundary change**

  ```bash
  git add spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/upload \
      spectra-modules/spectra-core/src/test
  git commit -m "refactor(core): 拆分文件上传校验流程"
  ```

### Task 8: 修正 Security Audit API 和 Controller 规范

**Files:**
- Create: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/audit/javabean/vo/SecurityAuditArchiveManifestVO.java`
- Create/Modify: MapStruct converter under `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/audit/javabean/converter`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/audit/controller/SecurityAuditController.java:116`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/audit/service/SecurityAuditArchiveOrchestrator.java:140`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/security/authorization/controller/SecurityContextController.java:40`
- Test: Security Audit Controller contract tests and `SecurityContextController` tests

**Interfaces:**
- Consumes: 内部 `ManifestView`、归档 orchestrator 和现有 API annotations。
- Produces: Controller 返回 API VO，时间经过 `TimeMapper`，所有归档写操作含 `@Audit` 和 `version = "1.0.0"`；安全上下文接口补齐 API version。

- [x] **Step 1: Write contract tests**

  测试 Controller 返回类型属于 `javabean.vo`，返回对象不包含 `Instant` 字段；归档、恢复、清理接口存在 `@PreAuthorize`、`@Audit` 和 `version = "1.0.0"`；`SecurityContextController.current` 的 mapping 包含同一 version。

- [x] **Step 2: Run tests to verify old API shape fails**

  ```bash
  cd spectra-admin
  mise exec -- ./mvnw -pl spectra-launch -am \
      -Dtest='*SecurityAudit*Test,*SecurityContextController*Test' test
  ```

  Expected: 旧 `ManifestView` 含 `Instant` 且归档接口元数据不完整，契约测试失败。

- [x] **Step 3: Implement explicit API mapping**

  `SecurityAuditArchiveManifestVO` 使用项目允许的 API 时间类型和原有响应字段；新增 MapStruct 转换器，调用 `TimeMapper`。Controller 只调用 orchestrator 并转换返回，不暴露内部 record。对归档写操作补 `@Audit`，不在 Controller 中增加业务日志或数据库访问。

- [x] **Step 4: Run controller and audit tests**

  预期 API 反射契约、序列化、审计失败传播和安全上下文测试全部通过。

- [x] **Step 5: Commit the API contract cleanup**

  ```bash
  git add spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/audit \
      spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/security/authorization/controller \
      spectra-admin/spectra-modules/spectra-core/src/test
  git commit -m "refactor: normalize audit api responses"
  ```

### Task 9: 拆分高耦合 Service，并建立事务边界

**Files:**
- Modify/Create under `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/imports/service`: `UserImportServiceImpl.java`, `UserImportPreviewService.java`, `UserImportExecutionService.java`, `UserImportResultService.java`
- Modify/Create under `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/scheduler/service`: `SchedulerAdminServiceImpl.java`, `SchedulerCatalogService.java`, `SchedulerControlService.java`, `SchedulerExecutionQueryService.java`
- Modify/Create under `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/monitor`: `ServiceMonitorServiceImpl.java`, `ServiceMonitorEvaluationService.java`, `ServiceMonitorQueryService.java`
- Modify/Create under `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/security/authorization/service`: `AuthorizationAssignmentChangeServiceImpl.java`, `AuthorizationImpactService.java`, `AuthorizationAuditService.java`
- Test: existing UserImport, Scheduler, ServiceMonitor and Authorization service tests

**Interfaces:**
- Consumes: 现有 public Service 接口和 Controller 调用，不改变外部方法签名。
- Produces: 每个新 Service 只承担一个用例组；原 public Service 作为薄编排层，依赖数控制在 8 个以内；异步 Worker 和事务入口可单独测试。

- [x] **Step 1: Capture current behavior with characterization tests**

  为用户导入预览/应用/部分失败、调度创建/启停/执行记录、监控采样/规则评估、权限变更/影响分析分别补充成功、重复、异常和权限场景测试。对 `processApply` 验证每个分块的状态推进和失败行保留。

- [x] **Step 2: Run characterization tests before moving code**

  ```bash
  cd spectra-admin
  mise exec -- ./mvnw -pl spectra-core -am \
      -Dtest='*UserImport*Test,*Scheduler*Test,*ServiceMonitor*Test,*Authorization*Test' test
  ```

  Expected: 基线测试通过；任何失败先修复测试夹具，不在拆分类时改变业务行为。

- [x] **Step 3: Extract one responsibility at a time**

  按以下顺序迁移，保持旧 public Service 委托：

  1. 用户导入先拆预览和执行；执行按 100 行一块创建事务，块内用户写入、行状态和块进度原子提交，任务最终状态由结果 Service 统一计算。
  2. 调度拆目录读写、控制命令和执行记录查询；控制命令保留审计和幂等检查。
  3. 监控拆快照采集、规则评估和历史查询；规则评估禁止把每条规则的异常吞成成功，改为记录规则级失败并汇总返回。
  4. 权限拆影响分析、变更落库和审计/outbox；安全 Redis 失败仍向上抛出并 fail-closed。

  每次抽取后删除原 Service 中对应 private 方法和不再需要的依赖，禁止保留无调用的兼容转发方法。

- [x] **Step 4: Run service tests and dependency-size check**

  ```bash
  mise exec -- ./mvnw -pl spectra-core -am \
      -Dtest='*UserImport*Test,*Scheduler*Test,*ServiceMonitor*Test,*Authorization*Test' test
  rg -n "private final" spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/{user/imports,scheduler,monitor,security/authorization} -g '*.java'
  ```

  Expected: 业务测试通过；原四个入口 Service 的字段依赖不超过 8 个，拆出的类均有独立测试。

- [x] **Step 5: Commit each independently testable extraction**

  ```bash
  git add spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/imports \
      spectra-admin/spectra-modules/spectra-core/src/test
  git commit -m "refactor: split user import services"
  ```

  调度、监控、权限分别使用同样的“只暂存对应目录 + 对应测试”的方式提交，禁止把四个大域混成一个不可回滚提交。

### Task 10: 统一 Controller 注入、日志和接口元数据

**Files:**
- Modify: core Controller candidates under `spectra-admin/spectra-modules/spectra-core/src/main/java/**/controller`
- Modify: `spectra-admin/spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/asset/controller/AssetController.java`
- Modify: `spectra-admin/spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/supply/controller/SupplyController.java`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/security/authorization/controller/SecurityContextController.java`
- Create/Modify: Controller annotation contract test under `spectra-admin/spectra-launch/src/test/java/com/devops00/spectra/architecture`

**Interfaces:**
- Consumes: 现有 Controller 映射、构造器和 annotation。
- Produces: Controller 依赖全部为 final 构造器注入；真正的 endpoint 统一具备 version、授权和审计元数据；不把“缺少日志注解”误报为功能错误。

- [x] **Step 1: Write annotation inventory test**

  只扫描包含 `@GetMapping`、`@PostMapping`、`@PutMapping`、`@DeleteMapping` 的类；断言 public endpoint method 的 mapping 含 `version = "1.0.0"`，写操作含 `@Validated`（存在请求体时）、`@PreAuthorize` 和 `@Audit`；断言 Controller 的依赖字段为 `private final`。对没有日志调用的 Controller，`@Slf4j` 只作为规范检查，不作为运行时失败条件。

- [x] **Step 2: Run the inventory test**

  ```bash
  cd spectra-admin
  mise exec -- ./mvnw -pl spectra-launch -am \
      -Dtest=ControllerAnnotationContractTest \
      -Dsurefire.failIfNoSpecifiedTests=false test
  ```

  Expected: 输出缺少 version、Audit、授权、构造器注入和 `@Slf4j` 的文件清单。

- [x] **Step 3: Apply low-risk annotation cleanup**

  补齐 `SecurityContextController` 的 version；对显式构造器且依赖已是 final 的 Controller，只做风格统一；对 `AssetController`、`SupplyController` 及上传/通知/调度 Controller 补 `@Slf4j`；不为了满足注解检查在 Controller 中加入无意义日志。所有 endpoint 的 `@Audit` 事件名使用已有命名规则，不新建旧版本路径。

- [x] **Step 4: Run controller contract and module tests**

  ```bash
  mise exec -- ./mvnw -pl spectra-launch -am \
      -Dtest=ControllerAnnotationContractTest,ArchitectureTest test
  ```

  Expected: 规范测试和现有 Controller role matrix 测试通过。

- [x] **Step 5: Commit annotation cleanup**

  ```bash
  git add spectra-admin/spectra-modules/spectra-core/src/main/java spectra-admin/spectra-modules/spectra-oa/src/main/java \
      spectra-admin/spectra-launch/src/test/java
  git commit -m "style: normalize backend controller conventions"
  ```

## 工作包 D：framework 结构、安全和可维护性

### Task 11: 移除 framework.configure 并按能力归位运行时实现

**Files:**
- Create/Move: `spectra-admin/spectra-framework/src/main/java/com/devops00/spectra/framework/{security,web,persistence,cache,captcha,serialization,assembler,health}/**`
- Remove: `spectra-admin/spectra-framework/src/main/java/com/devops00/spectra/framework/configure/**` 空目录及生产包
- Create/Move: matching files under `spectra-admin/spectra-framework/src/test/java/**`
- Modify: `spectra-admin/spectra-framework/src/main/java/com/devops00/spectra/framework/FrameworkModule.java`
- Modify: `spectra-admin/spectra-framework/src/main/resources/META-INF/spring/org.springframework.boot.autoconfigure.AutoConfiguration.imports`
- Modify: `spectra-admin/config/spotbugs/exclude.xml`
- Create: `spectra-admin/spectra-launch/src/test/java/com/devops00/spectra/architecture/FrameworkPackageLayoutTest.java`
- Modify: all backend imports referring to `com.devops00.spectra.framework.configure.*`

**Interfaces:**
- Consumes: 现有 `spectra-framework` 64 个 `configure` 生产类、对应测试、自动配置入口和跨模块 import。
- Produces: `framework.configure` 无生产包；各能力配置入口和运行时实现按职责归位，类路径、Bean 装配和外部配置契约可被架构测试证明。

- [x] **Step 1: Write the failing package-layout test**

  新建 `FrameworkPackageLayoutTest`，扫描框架生产源文件的 package 声明和文件路径，断言：`com.devops00.spectra.framework.configure` 下不存在生产类；配置入口/属性类位于各自能力包；安全、Web、持久化、缓存、验证码、序列化、Assembler、Health 运行时类只能位于目标语义包；源码路径与 package 声明一致。测试同时记录当前 64 个类的迁移清单，防止漏迁或重复类名。

- [x] **Step 2: Define and review the target matrix before moving files**

  按以下规则逐类归档：

  - 每个能力包同时承载自己的 `*Configuration`、`*Properties` 和运行时实现，不再设置 `framework.configure` 汇总包；`FrameworkModule` 保持 `com.devops00.spectra.framework` 入口不变，通过 `@ComponentScan(basePackageClasses = FrameworkModule.class)` 扫描整个 framework 根包并自动装配组件，不再显式维护能力配置引用。
  - Token、Session、权限、限流、认证处理器/过滤器、密码编码、安全配置和 Redis 安全存储进入 `framework.security`。
  - MVC 配置、Advice、请求/响应过滤器、加解密和 Cookie/CSRF Web 工具进入 `framework.web`。
  - MyBatis-Plus、数据权限、MetaObjectHandler 和持久化拦截器进入 `framework.persistence`。
  - `CacheConfiguration`、`RedisConfiguration`、`StandardCacheKeyGenerator` 进入 `framework.cache`；验证码配置、creator/type 进入 `framework.captcha`；Jackson、MapStruct 和时间映射进入 `framework.serialization`。

  对同时包含 Bean 定义和运行时逻辑的类先拆成入口/实现，再按矩阵移动；评审清单必须写明每个类的原包、目标包、原因、风险和回滚点。

- [x] **Step 3: Move production and test packages atomically**

  使用可追踪的文件移动更新 package 声明、import、测试 package、SpotBugs FQCN 和自动配置类名；批量迁移后用 `rg` 确认仓库内没有旧的 `framework.configure.<子包>` 引用或 `framework.configure` 生产目录。能力配置统一使用自身的 `@Configuration`、`@Bean` 和 `@EnableConfigurationProperties` 声明，不新增能力级 `AssemblerAutoConfiguration`；由 `FrameworkModule` 的根包扫描统一发现。保留现有 Bean 名称、配置前缀、Mapper namespace、REST 路径、Redis key 和序列化格式，不新增旧包别名。

- [x] **Step 4: Run package and Spring context checks**

  ```bash
  cd spectra-admin
  mise exec -- ./mvnw -pl spectra-framework,spectra-launch -am \
      -Dtest=FrameworkPackageLayoutTest,SecurityAutoConfigurationTest \
      -Dsurefire.failIfNoSpecifiedTests=false test
  ```

  Expected: 包布局测试通过，自动配置上下文只注册一份目标 Bean；旧包、旧自动配置类名和意外重复扫描均不存在。

- [x] **Step 5: Commit the package relocation as an isolated change**

  ```bash
  git add spectra-admin/spectra-framework spectra-admin/spectra-launch/src/test \
      spectra-admin/spectra-modules spectra-admin/spectra-config \
      spectra-admin/config/spotbugs/exclude.xml
  git commit -m "refactor: reorganize framework packages"
  ```

### Task 12: 收敛 Spring 装配、注入和框架生命周期

**Files:**
- Modify: `spectra-admin/spectra-framework/src/main/java/com/devops00/spectra/framework/FrameworkModule.java`
- Modify: `spectra-admin/spectra-framework/src/main/java/com/devops00/spectra/framework/security/configuration/SecurityAutoConfiguration.java`
- Modify: `spectra-admin/spectra-framework/src/main/java/com/devops00/spectra/framework/security/configuration/session/SecuritySessionPortConfiguration.java`
- Modify: `spectra-admin/spectra-framework/src/main/java/com/devops00/spectra/framework/persistence/configuration/MyBatisPlusConfiguration.java`
- Modify: `spectra-admin/spectra-framework/src/main/java/com/devops00/spectra/framework/persistence/scope/authorization/DataScopeInnerInterceptor.java`
- Modify: `spectra-admin/spectra-framework/src/main/java/com/devops00/spectra/framework/persistence/scope/authorization/ResourceAuthorizationGuard.java`
- Modify: `spectra-admin/spectra-framework/src/main/java/com/devops00/spectra/framework/cache/configuration/RedisConfiguration.java`
- Create/Modify: framework context and bean lifecycle tests under `spectra-admin/spectra-framework/src/test/java/**`

**Interfaces:**
- Consumes: Task 11 的目标包、Spring Boot AutoConfiguration 和 MyBatis/Redis Bean 图。
- Produces: 显式、可审计的 Framework Bean 装配；构造器注入；生产构造路径不携带空安全依赖；Redis Client/ClientResources 有确定的关闭生命周期。

- [x] **Step 1: Write assembly and lifecycle regression tests**

  增加测试断言 `FrameworkModule` 和 `SecurityAutoConfiguration` 不依赖扁平化后失效的正则扫描；安全 Advice、Converter、Store、Configuration 各只注册一次；`MyBatisPlusConfiguration` 和 `ResourceAuthorizationGuard` 通过构造器注入；Redis Client 和 ClientResources 在 Context close 时关闭。增加 `assertBatchAllowed` 只读取一次授权快照的调用次数测试。

- [x] **Step 2: Replace broad scans and field injection**

  保持 `FrameworkModule` 作为唯一 framework 自动配置入口，并使用单一 `@ComponentScan(basePackageClasses = FrameworkModule.class)` 扫描根包；`SecurityAutoConfiguration` 不再维护局部 `@ComponentScan` 或显式 `@Import`，安全配置由自身注解在根扫描中发现。将 `MyBatisPlusConfiguration` 的 `@Resource` 字段改为 final 构造器参数，保留必要的 `@Lazy` 方法参数；`ResourceAuthorizationGuard` 移除显式 `@Autowired`，生产路径只保留完整依赖构造器。

- [x] **Step 3: Separate production construction from test fixtures**

  `DataScopeInnerInterceptor` 只保留一个完整生产构造器；测试所需的简化依赖通过 package-private `@VisibleForTesting` 工厂或测试 fixture 提供，不允许生产对象以 `null` 安全依赖运行。批量授权检查先取得一次不可变 snapshot，再在内存中评估所有查询，任何加载/解析失败仍拒绝访问。

- [x] **Step 4: Manage Redis resources and verify startup behavior**

  为 `ClientResources` 和 `RedisClient` 声明明确的 Spring Bean 销毁方法或专用生命周期 Bean；应用关闭时验证连接资源被释放。启动测试覆盖安全 Redis contract 缺失、TTL/尝试次数非法、核心数据权限实体缺失时的明确失败，不允许通过吞掉 `ClassNotFoundException` 静默省略必需能力。

- [x] **Step 5: Run focused framework checks**

  ```bash
  cd spectra-admin
  mise exec -- ./mvnw -pl spectra-framework -Dtest='*ConfigurationTest,*LifecycleTest,DataScopeIsolationTest' \
      -Dsurefire.failIfNoSpecifiedTests=false test
  ```

  Expected: Context、构造器、批量授权和资源关闭测试通过；Checkstyle/SpotBugs 不因新增生命周期或注入路径产生新的违规。

### Task 13: 重写安全 Redis Session 和数据解析链路

**Files:**
- Modify/Delete: `spectra-admin/spectra-framework/src/main/java/com/devops00/spectra/framework/security/RedisSecuritySessionRepository.java`
- Create: `spectra-admin/spectra-framework/src/main/java/com/devops00/spectra/framework/security/{SecuritySessionIssueService,SecuritySessionRefreshService,SecuritySessionRevocationService,SecurityOnlineUserQueryService,SecurityLoginFailureStore}.java`
- Create/Modify: typed Redis operations, value parsers and Lua scripts under `spectra-admin/spectra-framework/src/main/java/com/devops00/spectra/framework/security/**`
- Modify: existing `RefreshTokenRotationStore` and `SecurityRedisExecutor` after package relocation
- Test: unit and integration tests under `spectra-admin/spectra-framework/src/test/java/com/devops00/spectra/framework/security/**`

**Interfaces:**
- Consumes: 当前 Session Port、Redis key/namespace、Token digest、refresh rotation 和 online user contract。
- Produces: 按用例拆分的 Session 实现；原子索引更新；统一 typed Redis 访问；脏数据、解析错误、并发竞态和 Redis 故障全部保持 fail-closed。

- [x] **Step 1: Capture the current security contract with failing tests**

  先为签发、刷新、当前用户读取、单 Token/用户/设备撤销、在线用户查询、登录失败锁定和 refresh replay 建立测试。固定 key 名称、TTL、opaque token、返回字段和撤销 family 语义；增加 malformed count/hash/JSON、脚本异常、Redis timeout 和 partial write 的失败用例。

- [x] **Step 2: Introduce typed operations and fail-closed parsing**

  所有安全 Redis 读写经 `SecurityRedisExecutor`/typed adapter；集中处理 `DataAccessException`、脚本返回值、空值和数字/时间/枚举解析。`Long.parseLong` 等解析失败转换为安全 Redis 不可用/数据损坏异常，禁止以 `0`、匿名用户或允许访问作为默认值。任何异常日志仅带 request/correlation ID 和 key 类型，不带 Token、密钥和原始 payload。

- [x] **Step 3: Split issue, refresh, revoke, query and failure use cases**

  将原 800 行级别仓储拆为独立 Spring Bean，每个 public 方法只负责一个用例并声明事务/原子性边界；通过稳定接口继续向 `SecuritySessionIssuer`、`Query`、`Reader`、`Revoker` 和 `SecurityLoginFailureTracker` 提供能力。签发、刷新、撤销的多 key 索引变更复用 `RefreshTokenRotationStore` 的 Lua/Executor 模式，在脚本中保证 compare-and-delete、rotation/replay 和 family revoke 的原子性。

- [x] **Step 4: Remove N+1 online queries and test concurrency**

  在线用户查询批量读取 session 摘要或使用一次批量 Redis 操作，不逐用户逐 Token 读取完整 hash；保留排序、过滤、分页和脱敏语义。用并发测试验证同一 refresh token 只有一个成功旋转者、重复 token 不能恢复会话、部分撤销不会误删其他设备，以及任一安全 Redis 不确定状态都拒绝继续。

- [x] **Step 5: Run Redis contract and security quality checks**

  ```bash
  cd spectra-admin
  mise exec -- ./mvnw -pl spectra-framework \
      -Dtest='*Security*Test,*Session*Test,*Redis*Test' \
      -Dsurefire.failIfNoSpecifiedTests=false test
  ```

  Expected: Redis contract、Lua 集成、脏数据、重放、并发和 fail-closed 测试通过；原有 Port 调用方无需感知内部拆分。

### Task 14: 重写 Web 加解密、CSRF、响应安全和异常边界

**Files:**
- Modify: `spectra-admin/spectra-framework/src/main/java/com/devops00/spectra/framework/web/RequestDecryptAdvice.java`
- Modify: `spectra-admin/spectra-framework/src/main/java/com/devops00/spectra/framework/web/ResponseEncryptAdvice.java`
- Modify: `spectra-admin/spectra-framework/src/main/java/com/devops00/spectra/framework/web/CryptoKeyManager.java`
- Modify: `spectra-admin/spectra-framework/src/main/java/com/devops00/spectra/framework/security/configuration/authentication/SecurityConfiguration.java`
- Modify: `spectra-admin/spectra-framework/src/main/java/com/devops00/spectra/framework/security/properties/SecurityProperties.java`
- Modify: `spectra-admin/spectra-framework/src/main/java/com/devops00/spectra/framework/web/CommonExceptionAdvice.java`
- Create: `spectra-admin/spectra-framework/src/main/java/com/devops00/spectra/framework/web/WebCookieCsrfFilter.java` or an equivalent narrowly matched Spring Security policy
- Test: crypto, CSRF, header, exception and configuration tests under `spectra-admin/spectra-framework/src/test/java/**`

**Interfaces:**
- Consumes: 现有加密信封、`CryptoKeyManager`、Cookie/Header Token 客户端、Spring Security matcher 和错误响应契约。
- Produces: 有界请求体、不可静默降级的必须加密响应、集中 CSRF 校验、同源点击劫持防护、最小授权异步分发和安全错误响应。

- [x] **Step 1: Write security regression tests before changing behavior**

  覆盖超出最大 body、缺少 signature/nonce/timestamp/IV、非法 Base64/IV、时间窗过期、nonce 重放、Redis 不可用、密钥不可用、资源/二进制响应绕过、匿名 ASYNC redispatch、Cookie unsafe 请求缺失 CSRF、Header Token 请求保持可用、非同源 iframe 被拒绝和消息体不可读返回 400 等场景。

- [x] **Step 2: Bound and validate request decryption**

  用配置化上限和 bounded stream 替代 `readAllBytes()`；校验 Content-Length 与实际读取长度；强制加密信封必需字段和时间窗口，nonce 通过安全 Redis 原子消费。区分客户端格式错误、重放、依赖不可用和服务端配置错误，映射到既有错误响应模型，不输出密文、密钥或异常原文。

- [x] **Step 3: Make crypto state explicit and fail closed**

  `CryptoKeyManager` 使用 `DISABLED`、`READY`、`UNAVAILABLE` 状态和类型化配置异常；初始化/刷新失败不再通过“清空 keys”静默放行。对 `@Encrypt(response = true)` 等显式要求加密的响应，在密钥不可用时返回安全错误；只有明确标记为不加密或全局关闭时才允许明文。保留 key 刷新不泄密和旧 key 轮换语义。

- [x] **Step 4: Centralize web security policies**

  在 Cookie-bearing unsafe web 请求上使用集中 CSRF matcher/filter，保留 Header Token 客户端；删除 `DispatcherType.ASYNC` 的宽泛 `permitAll`，只允许经过认证链的异步分发。将 frame options 改为 same-origin 或等价的 `frame-ancestors 'self'`；给 `SecurityProperties` 增加 `@Validated` 和 TTL/次数/会话数/白名单路径约束，禁止 `/**`。`CommonExceptionAdvice` 将不可读请求映射为 400，未分类异常对外返回通用消息并通过 correlation ID 关联内部日志。

- [x] **Step 5: Run focused web security and quality checks**

  ```bash
  cd spectra-admin
  mise exec -- ./mvnw -pl spectra-framework \
      -Dtest='*Crypto*Test,*Csrf*Test,*SecurityConfiguration*Test,CommonExceptionAdviceTest' \
      -Dsurefire.failIfNoSpecifiedTests=false test
  ```

  Expected: 安全边界测试通过，已有浏览器 Cookie、移动端 Header Token、上传和加密 API 契约不被破坏；SpotBugs/Checkstyle 对输入边界和异常处理无新增问题。

### Task 15: 收敛 Framework JSON、缓存序列化和可变状态

**Files:**
- Modify: `spectra-admin/spectra-framework/src/main/java/com/devops00/spectra/framework/cache/configuration/CacheConfiguration.java`
- Modify: `spectra-admin/spectra-framework/src/main/java/com/devops00/spectra/framework/security/configuration/redis/SecJacksonConfiguration.java`
- Modify: `spectra-admin/spectra-framework/src/main/java/com/devops00/spectra/framework/serialization/jackson/JacksonConfiguration.java`
- Modify: `spectra-admin/spectra-framework/src/main/java/com/devops00/spectra/framework/security/properties/SecurityProperties.java`
- Create/Modify: serializer compatibility and cache mapper tests under `spectra-admin/spectra-framework/src/test/java/**`

**Interfaces:**
- Consumes: 当前 API 时间格式、缓存内容、Redis 安全对象和既有配置属性。
- Produces: 线程安全的时间处理；显式或窄范围类型序列化；API mapper 与缓存 mapper 的风险隔离；缓存空值/旧值行为可测试。

- [x] **Step 1: Inventory serialization contracts**

  列出 API JSON 时间格式、缓存 key/serializer、security Redis value 格式和可被反序列化的类型；为每项增加快照/反序列化测试。确认迁移期间是否允许自然缓存失效，禁止把未验证的宽泛 typing 当作兼容方案。

- [x] **Step 2: Replace unsafe or mutable serializer setup**

  用 Java Time/线程安全 formatter 和显式 serializer 替代共享 `SimpleDateFormat`；API mapper 与内部缓存 mapper 分离，避免全局关闭未知字段造成安全边界模糊。移除或收窄 `DefaultTyping` 的包前缀 allow-list，优先使用明确 DTO/serializer；不把未经验证的 Redis/cache payload 反序列化为任意项目类型。

- [x] **Step 3: Preserve external formats deliberately**

  保持既有 API 时间和业务字段序列化结果，针对空缓存、缓存 miss、自然过期和旧缓存内容选择明确的失效/拒绝策略；security Redis 解析失败必须 fail-closed。若确需序列化迁移，先记录影响范围和清理窗口，不增加隐式回退读取。

- [x] **Step 4: Verify cache and API mapper behavior**

  ```bash
  cd spectra-admin
  mise exec -- ./mvnw -pl spectra-framework \
      -Dtest='*Jackson*Test,*Cache*Test,*Serialization*Test' \
      -Dsurefire.failIfNoSpecifiedTests=false test
  ```

  Expected: API 快照、缓存序列化和安全数据拒绝测试通过；多线程 formatter/mapper 测试没有状态串扰。

- [x] **Step 5: Document intentional compatibility boundaries**

  仅在确实影响知识库时同步配置清单、依赖/序列化说明并运行 `bash scripts/check-docs.sh`；不在文档中记录密钥、环境值或真实 Redis 内容。

### Task 16: 补全注释并建立接口唯一契约规则

**Files:**
- Modify: `spectra-admin/spectra-framework/src/main/java/**`
- Modify: `spectra-admin/spectra-common/src/main/java/**/Service.java`
- Modify: `spectra-admin/spectra-modules/**/src/main/java/**/service/*Service.java`
- Modify: `spectra-admin/spectra-modules/**/src/main/java/**/service/impl/*ServiceImpl.java`
- Create: `spectra-admin/spectra-launch/src/test/java/com/devops00/spectra/architecture/ServiceDocumentationContractTest.java`
- Create: `docs/superpowers/specs/2026-09-04-java-language-usage-matrix.md`
- Create/Modify: documentation inventory script or test under `spectra-admin/spectra-launch/src/test/java/com/devops00/spectra/architecture`
- Create: `spectra-admin/spectra-launch/src/test/java/com/devops00/spectra/architecture/JavaLanguageUsageContractTest.java`

**Interfaces:**
- Consumes: Service 接口/实现、framework 公共类型、过滤器、Advice、Port 和安全存储类的现有注释。
- Produces: 公共契约可从接口和框架 API 注释中读懂；实现不复制接口 Javadoc；关键安全/并发/事务不变量有准确短注释。

- [x] **Step 1: Write the documentation inventory test**

  扫描 Service 接口的 public 方法、Framework public 类型/方法、配置 Bean、Port、Filter、Advice 和安全 Redis 操作，输出缺少契约注释的文件/成员。检查 ServiceImpl 方法不会重复接口的整段公共 Javadoc；private/helper 方法不作为无意义的注释覆盖目标。

- [x] **Step 2: Complete Service interface contracts**

  在每个 `*Service` 接口中补齐用途、参数、返回值、异常、权限前置条件、幂等性、分页/排序、事务或异步语义。使用项目统一的中文 Javadoc 和既有 `@author`/`@version`/`@since` 约定，不把实现细节写进接口契约。

- [x] **Step 3: Remove duplicate implementation comments and add only essential rationale**

  删除 `*ServiceImpl` 中逐字重复接口方法说明；实现中仅保留解释算法复杂度、锁/幂等键、分块事务、Redis 原子性、fail-closed 或外部系统限制的注释。Framework 公开配置和安全组件补齐线程安全、生命周期、输入上限、失败方向和敏感信息处理说明。

- [x] **Step 4: Run documentation and static checks**

  ```bash
  cd spectra-admin
  mise exec -- ./mvnw -pl spectra-launch -am \
      -Dtest=ServiceDocumentationContractTest \
      -Dsurefire.failIfNoSpecifiedTests=false test
  mise exec -- ./mvnw -pl spectra-framework,spectra-launch -am spotless:check checkstyle:check
  ```

  Expected: 接口注释缺口和实现重复注释均为 0；注释不包含过期包名、旧 API 版本、敏感值或与代码行为矛盾的承诺。

- [x] **Step 5: Audit Java 25 language usage and record the `var` policy**

  `var` 已由 Java 10 提供，只能用于局部变量类型推断；本步骤不把它误写成 JDK 25 新特性，也不要求所有局部变量都改成 `var`。扫描生产源码并把结果写入 `docs/superpowers/specs/2026-09-04-java-language-usage-matrix.md`，至少记录 `var`、record、pattern matching、switch expression、sequenced collection API 的现状、候选迁移点、保留显式类型的理由和行为风险。

  固定以下编码规则：初始化器直接暴露具体类型的局部变量、集合构造、资源变量和 fluent builder 可使用 `var`；公共 API、成员字段、`null` 初始化、容易混淆的数字类型、复杂条件表达式、跨多行远距离阅读或涉及安全/事务不变量的变量保留显式类型。`JavaLanguageUsageContractTest` 至少断言根 POM 和各模块使用 Java 25、生产源码存在已编译的 `var` 局部变量、没有把 `var` 放进字段/方法签名，并输出按模块的使用清单；不以“var 使用率 100%”作为质量指标。

  ```bash
  cd spectra-admin
  mise exec -- ./mvnw -pl spectra-launch -am \
      -Dtest=JavaLanguageUsageContractTest \
      -Dsurefire.failIfNoSpecifiedTests=false test
  rg -n '\bvar\s+[A-Za-z_][A-Za-z0-9_]*\s*=' \
      spectra-common/src/main/java spectra-framework/src/main/java \
      spectra-modules/*/src/main/java spectra-launch/src/main/java --glob '*.java'
  ```

  Expected: Java 25 编译级别和 `var` 使用事实均有测试证据；代码风格只在可读性和类型语义明确的地方收敛，不引入由于推断类型不明显造成的维护或安全风险。

- [x] **Step 6: Synchronize only affected knowledge-base documents**

  若注释补全改变了公共能力说明、分层或安全约束，更新对应领域笔记后执行 `bash scripts/check-docs.sh`；普通实现注释不制造无关文档变更。

### Task 17: 评估并选择性落地设计模式

**Files:**
- Create: `spectra-admin/spectra-launch/src/test/java/com/devops00/spectra/architecture/FrameworkPatternAssessmentTest.java`
- Create: pattern assessment matrix under `docs/superpowers/specs/` or the implementation task notes
- Modify: selected framework/session/captcha/data-scope classes only after assessment
- Test: selected pattern variants and old/new behavior equivalence under `spectra-admin/spectra-framework/src/test/java/**`

**Interfaces:**
- Consumes: Task 11–16 形成的职责边界、重复条件分支、调用次数、扩展轴和测试结果。
- Produces: 有证据的模式采纳/拒绝决策；采纳项减少分支或中间调用并保持 Spring Bean 生命周期、错误语义和 API 契约稳定。

- [x] **Step 1: Build the pattern candidate matrix**

  对每个候选记录现有变体数量、重复条件分支、变化频率、调用方数量、测试隔离难度、引入成本、回滚方式和可测收益。至少评估：Session backend 的 Strategy/Factory、Cookie/CSRF 与限流主体的 Policy/Strategy、请求/响应安全 pipeline、验证码类型 Factory/Strategy、数据权限 SQL Specification/Policy、Session 用例的 command object，以及 Java 25 `ScopedValue` 对自维护请求/数据权限上下文的替代价值；`NameLookup`/`NameFillExecutor` 保持 Adapter 语义，不把它们泛化为 common 工具，但针对当前 VO 绑定完整 Service 和 `ApplicationContext.getBean()` 查找问题，由 Task 22 落地最小的 Lookup Registry 与 feature Adapter。

- [x] **Step 2: Set adoption criteria and write equivalence tests**

  只有至少两个真实变体、存在明确扩展轴并能通过调用次数、圈复杂度、依赖数或测试隔离性证明收益时才采纳。先为现有行为写参数化/契约测试，覆盖权限、排序、异常、事务和 fail-closed 语义；不因为类名“看起来适合模式”就拆分。

- [x] **Step 3: Implement the smallest beneficial pattern**

  优先评估 Task 13 已拆分的 Session operation strategy 和 Task 14 的安全匹配策略；Session backend、验证码和数据权限只有在矩阵达到“至少两个真实变体、明确扩展轴、可测收益”的门槛时才实施。模式对象使用构造器注入，避免静态注册表、隐式全局状态和额外 Service 自调用；旧入口迁移完成后删除重复分支和临时适配层。

- [x] **Step 4: Measure and review the result**

  对采纳项比较迁移前后调用次数、圈复杂度、类依赖数、Bean 数量和关键路径耗时；对拒绝项记录保持现状的原因。确认没有为了模式引入额外数据库/Redis 往返、循环依赖或安全策略绕过。

- [x] **Step 5: Run pattern contract tests and record the decision**

  ```bash
  cd spectra-admin
  mise exec -- ./mvnw -pl spectra-framework,spectra-launch -am \
      -Dtest=FrameworkPatternAssessmentTest,*Security*Test,*ConfigurationTest \
      -Dsurefire.failIfNoSpecifiedTests=false test
  ```

  Expected: 每个采纳模式都有变体等价性测试和收益记录，每个拒绝项都有理由；不存在仅为套用模式而增加的中间调用。

### Task 18: 按整体后端项目收敛工具类和横向辅助能力

**Files:**
- Create: `docs/superpowers/specs/2026-09-04-backend-utility-convergence-matrix.md`
- Create: `spectra-admin/spectra-launch/src/test/java/com/devops00/spectra/architecture/BackendUtilityArchitectureTest.java`
- Create/Modify: `spectra-admin/spectra-common/src/test/java/com/devops00/spectra/common/tree/TreeContractTest.java`
- Create/Modify: `spectra-admin/spectra-framework/src/test/java/com/devops00/spectra/framework/assembler/NameFillExecutorTest.java`
- Create/Modify: `spectra-admin/spectra-common/src/main/java/com/devops00/spectra/common/foundation/**`
- Modify/Move: `spectra-admin/spectra-common/src/main/java/com/devops00/spectra/common/utils/{AESUtils,CollUtils,IpUtils,ObjUtils,RSAUtils,SHA256Utils,StrUtils,TreeBuilder,TreeUtils}.java`
- Modify/Move: `spectra-admin/spectra-framework/src/main/java/com/devops00/spectra/framework/{security,web,assembler,serialization}/**`
- Modify/Move: core authentication/notification helper classes under `spectra-admin/spectra-modules/spectra-core/src/main/java/**`
- Modify/Move: OA `support` and application helper classes under `spectra-admin/spectra-modules/spectra-oa/src/main/java/**`
- Modify: all backend call sites and tests importing the old utility/helper/support packages

**Interfaces:**
- Consumes: 全部 backend `utils`/`util`/`helper`/`support`/`tools` 包、`*Utils`/`*Helper`/`*Support`、静态方法集合、framework assembler/converter 和各模块 MapStruct converter 的调用图。
- Produces: 一个按能力归属的工具类矩阵和唯一权威实现；纯基础能力、Web 适配、安全算法、需要注入 Bean 的 framework assembler、业务辅助和 feature converter 不再互相越层或重复实现。

- [x] **Step 1: Write the failing whole-backend utility architecture test**

  新建 `BackendUtilityArchitectureTest`，扫描 `spectra-admin` 全部 `src/main/java`，收集 `utils`/`util`/`helper`/`support`/`tools` 包、工具类后缀、public static 方法和 converter/assembler。测试先固定当前盘点结果并断言：通用工具只能位于 canonical foundation 包；Servlet/Spring/数据库类型不能进入 `spectra-common` foundation；安全算法不能被业务模块直接依赖；领域 helper 不得被迁移为全局 common 工具；需要注入 Bean、配置或生命周期的能力不能被标记为 static utility；同一 canonical 能力只能有一个生产实现。

- [x] **Step 2: Build the project-wide convergence matrix before moving classes**

  将每个候选写入 `2026-09-04-backend-utility-convergence-matrix.md`，至少记录原路径、目标路径、所有调用方、重复实现、输入/输出和异常语义、线程安全、敏感数据风险、是否保留、合并方案、迁移顺序和删除旧入口的影响。重点核对 `common/utils` 的字符串/集合/对象/树/加解密/IP 类，framework assembler/converter，core 的认证上下文/标识摘要/通知脱敏、上传权限/存储/通知发送注册表，OA 的文件引用和流程辅助，以及各 feature 的 MapStruct converter；没有跨模块复用的业务 helper 保持在对应 feature，而不是继续泛化。对 `NameFill`、`NameLookup`、`NameFillExecutor` 单独记录“注解契约 / Bean 扩展点 / 注入式执行器”三层职责，不能因为执行器提供通用方法就将其并入 common 工具；同时把 `DepartmentServiceImpl`、`RegionServiceImpl` 这类当前 Lookup 实现评估为独立 feature Lookup 适配 Bean，避免 VO 注解绑定完整 Service 实现。P1/P2 的横向能力由 Task 19–23 分别记录真实调用方、拒绝语义和启动期校验，不得只在矩阵中登记而不迁移调用方。

- [x] **Step 3: Consolidate pure foundation utilities and remove duplicate wrappers**

  将 `StrUtils`、`CollUtils`、`ObjUtils` 收敛到明确的 `spectra-common` foundation/lang/collection 能力包；将 `TreeBuilder`、`TreeUtils` 收敛到 foundation/tree，明确它们不需要 Bean 注入，但 `TreeBuilder` 构树时可能回填节点 children，必须记录输入复制深度、重复调用、缺失父节点和排序比较器契约。统一 null/blank、Unicode 字节截断、集合大小、树排序/根节点/选中节点压缩和异常语义；删除只有单一调用方的泛化包装，能用 JDK 的地方不再依赖 Guava。先用行为等价测试锁定旧结果，再迁移所有调用方并删除 `common.utils` 旧类。

- [x] **Step 4: Move security, Web and domain-specific helpers to their owning layers**

  将 AES/RSA/SHA-256/HMAC/nonce 按调用图收敛到 `framework.security.crypto` 或明确的 `common.security.crypto` Port/Adapter：保持现有 AES-GCM、RSA-OAEP/签名、编码和 Token/密钥不透明性，统一随机数、密钥长度、常量时间校验和异常 fail-closed；业务模块不得直接复制算法。将 `IpUtils` 迁入 `framework.web`，对代理头解析和非法输入建立边界策略；将认证上下文、标识摘要、通知脱敏、OA 文件引用和流程辅助分别移入其 feature 的 application/domain/policy 包；各 feature 的 MapStruct converter 保持领域隔离，只共享 mapper 配置和时间转换。`NameFill`、`NameLookup` 和 `NameFillExecutor` 保持在 `framework.assembler`：前两者是注解/SPI 契约，后者是构造器注入的 Spring 组件；其当前状态主要是每次调用的局部集合，不得引入未定义的 singleton 可变状态。Task 22 只增加按 Lookup 类型解析的显式 Registry 和 feature Adapter，不引入缓存；如果以后增加反射元数据缓存或其他长期状态，必须补充并发、生命周期和失效测试。将 `DepartmentServiceImpl`、`RegionServiceImpl` 中的名称查询能力拆成独立 feature Lookup 适配 Bean，再让注解绑定适配 Bean 类型；所有旧包、别名和回退读取在调用方迁移完成后删除。P1/P2 的文件权限、审计脱敏、通知发送和文件存储注册表按 Task 19–23 的领域归属落地，不能上移为 framework/common 的横向万能组件。

- [x] **Step 5: Run whole-backend utility checks and record the migration**

  ```bash
  cd spectra-admin
  mise exec -- ./mvnw -pl spectra-launch -am \
      -Dtest=BackendUtilityArchitectureTest,TreeContractTest,NameFillExecutorTest,FrameworkPackageLayoutTest,ServiceDocumentationContractTest \
      -Dsurefire.failIfNoSpecifiedTests=false test
  rg -n 'com\.devops00\.spectra\.common\.utils|\.(utils|util|helper|support|tools)\.' \
      --glob '*.java' spectra-common spectra-framework spectra-modules spectra-launch
  ```

  Expected: 工具架构测试、纯工具行为/安全回归、assembler Bean 生命周期测试和模块编译全部通过；旧全局工具入口、重复实现、common 反向技术依赖和不合理 feature helper 残留均有明确结果，矩阵中的每个类都标记为保留、迁移、合并或删除。

## 工作包 E：注入式横向能力收敛

### Task 19: [P1] 提取文件引用权限解析器

**Files:**
- Create: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/upload/security/FileReferencePermissionResolver.java`
- Create: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/upload/security/DefaultFileReferencePermissionResolver.java`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/upload/service/FileReferenceApplicationService.java:30,80-90`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/upload/service/FileAssetApplicationService.java:50,140-159`
- Test: `spectra-admin/spectra-modules/spectra-core/src/test/java/com/devops00/spectra/core/upload/security/FileReferencePermissionResolverTest.java`
- Test: `spectra-admin/spectra-modules/spectra-core/src/test/java/com/devops00/spectra/core/upload/service/FileReferenceApplicationServiceTest.java`

**Interfaces:**
- Consumes: `FileReferencePermissionChecker` 列表、`FileUploadException`/`FILE_UPLOAD_PERMISSION_DENIED`、文件引用注册和下载的现有权限语义。
- Produces: core 内唯一的文件引用权限解析能力，供 `FileReferenceApplicationService` 和 `FileAssetApplicationService` 注入使用，不向 common 暴露 OA Entity、Mapper 或 Service 实现。

  定义以下接口；`canRead` 只返回权限结果，`requireReadable` 在权限不足时抛出现有文件上传权限异常：

  ```java
  public interface FileReferencePermissionResolver {
      boolean canRead(String referenceType, UUID referenceId, UUID userId);

      void requireReadable(String referenceType, UUID referenceId, UUID userId);
  }
  ```

- [ ] **Step 1: Write the failing resolver contract tests**

  使用测试用 Checker 覆盖空 `referenceType`、空 `referenceId`、空 `userId`、没有支持者、所有支持者拒绝和至少一个支持者允许的情况；覆盖 Checker 抛出运行时异常时不能转为允许，并断言 `requireReadable` 使用 `FILE_UPLOAD_PERMISSION_DENIED`。验证允许路径只调用支持当前类型的 Checker，不新增 Mapper/数据库调用。

- [ ] **Step 2: Run the focused test to verify the new contract is red**

  ```bash
  cd spectra-admin
  mise exec -- ./mvnw -pl spectra-core -am \
      -Dtest=FileReferencePermissionResolverTest \
      -Dsurefire.failIfNoSpecifiedTests=false test
  ```

  Expected: 新接口和实现尚不存在时测试无法通过；失败原因应指向 Resolver 契约缺失，而不是测试配置没有发现。

- [ ] **Step 3: Implement the domain-owned Resolver**

  由 `DefaultFileReferencePermissionResolver` 构造器注入 `List<FileReferencePermissionChecker>`，集中完成支持者选择、拒绝默认和现有异常映射；未知类型、空主体、无匹配 Checker、全部拒绝和 Checker 异常均不得产生允许结果。保持 Checker 的 `supports`/`canRead` 调用顺序，不在 Resolver 中增加并行调用、缓存或额外数据库访问。

- [ ] **Step 4: Migrate both upload application services**

  删除两个应用服务对 `List<FileReferencePermissionChecker>` 的注入和重复循环，改为调用 Resolver；保留 `FileReferenceApplicationService` 的当前登录用户取得逻辑、`FileAssetApplicationService` 的引用存在性检查、管理员分支、创建者临时访问规则和上下文用户一致性校验。不得把管理员权限错误地交给业务引用 Checker。

- [ ] **Step 5: Run resolver and upload regression tests**

  ```bash
  mise exec -- ./mvnw -pl spectra-core -am \
      -Dtest=FileReferencePermissionResolverTest,FileReferenceApplicationServiceTest,FileAssetApplicationServiceTest \
      -Dsurefire.failIfNoSpecifiedTests=false test
  rg -n 'List<FileReferencePermissionChecker>|permissionCheckers|checker\.supports' \
      spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/upload/service
  ```

  Expected: 两个应用服务不再持有权限 Checker 列表或重复遍历；未知引用类型、无登录用户和权限异常继续 fail-closed，原有上传下载行为不变。

### Task 20: [P1] 完成审计脱敏的注入式收敛

**Files:**
- Modify: `spectra-admin/spectra-common/src/main/java/com/devops00/spectra/common/audit/AuditSanitizer.java`
- Modify: `spectra-admin/spectra-common/src/main/java/com/devops00/spectra/common/audit/DefaultAuditSanitizer.java`
- Modify: `spectra-admin/spectra-common/src/test/java/com/devops00/spectra/common/audit/DefaultAuditSanitizerTest.java`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/audit/AuditConfiguration.java`
- Create: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/audit/SecurityAuditEventFactory.java`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/security/audit/SecurityAuditEvent.java`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/security/audit/service/SecurityAuditQueryService.java`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/audit/CoreAuditService.java`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/security/policy/service/impl/JdbcSecurityPolicyService.java`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/security/authentication/service/impl/LoginServiceImpl.java`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/security/authorization/service/impl/RoleAuthorizationChangeServiceImpl.java`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/security/authorization/service/impl/AuthorizationAssignmentChangeServiceImpl.java`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/security/authorization/service/impl/OrganizationChangeServiceImpl.java`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/service/impl/UserServiceImpl.java`
- Test: `spectra-admin/spectra-modules/spectra-core/src/test/java/com/devops00/spectra/core/audit/AuditSanitizerBeanContractTest.java`
- Test: `spectra-admin/spectra-modules/spectra-core/src/test/java/com/devops00/spectra/core/audit/SecurityAuditEventFactoryTest.java`
- Test: `spectra-admin/spectra-modules/spectra-core/src/test/java/com/devops00/spectra/core/security/audit/service/SecurityAuditQueryServiceTest.java`

**Interfaces:**
- Consumes: common 的 `AuditSanitizer` 契约、默认递归脱敏实现、Core 审计事件和查询/写入路径。
- Produces: 一个由 Spring 注入的审计脱敏策略，以及一个统一创建 `SecurityAuditEvent` 的 Core Factory；业务服务和查询服务不再直接依赖 `DefaultAuditSanitizer.INSTANCE` 或自行维护敏感字段规则。

  `AuditSanitizer` 的方法签名保持不变；`SecurityAuditEventFactory` 至少提供以下能力：

  ```java
  public SecurityAuditEvent create(
          UUID eventId,
          String eventType,
          UUID operatorId,
          UUID targetId,
          String client,
          String ip,
          String userAgent,
          Map<String, ?> before,
          Map<String, ?> after,
          String reason,
          Instant occurredAt,
          AuditResult result,
          String correlationId);
  ```

- [ ] **Step 1: Write the failing Bean and policy-boundary tests**

  测试默认 Bean 只有一个 `AuditSanitizer`，实现对输入 Map、嵌套 Map、集合、数组、URL 凭据、Bearer Token 和空值的行为保持不变；测试 Factory 使用注入的 mock sanitizer；测试 Core 查询路径使用注入的 `AuditSanitizer`，而不是静态默认实例。增加源码扫描断言：除 `SecurityAuditEvent` 的构造安全兜底外，Core 生产代码不得出现 `DefaultAuditSanitizer.INSTANCE`。

- [ ] **Step 2: Run the focused tests to verify the boundary is red**

  ```bash
  cd spectra-admin
  mise exec -- ./mvnw -pl spectra-common,spectra-core -am \
      -Dtest=DefaultAuditSanitizerTest,AuditSanitizerBeanContractTest,SecurityAuditEventSanitizationTest \
      -Dsurefire.failIfNoSpecifiedTests=false test
  ```

  Expected: 在 Factory、Bean 注入和静态调用清理完成前，新增的注入边界测试失败；既有脱敏行为测试仍能区分实现回归和装配边界失败。

- [ ] **Step 3: Make the sanitizer a single stateless default Bean**

  保留 `AuditSanitizer` 在 common 作为纯契约，`DefaultAuditSanitizer` 只保留一个无状态实现；由 `AuditConfiguration` 显式构造并注册唯一 Bean。移除业务代码对公开静态共享实例的依赖；若 `SecurityAuditEvent` 仍需在 Jackson 反序列化或脱离 Spring 的值对象构造阶段保留最后一道脱敏兜底，必须将其限定在值对象边界、写清原因，并不得让服务层或查询层绕过注入策略。

- [ ] **Step 4: Migrate event creation and query sanitization**

  由 `SecurityAuditEventFactory` 注入 `AuditSanitizer`，先对原始 before/after 快照脱敏，再创建不可变事件；迁移 Core 生产代码中的所有直接事件构造调用。`SecurityAuditEvent.started()`/`withResult()` 只复用已脱敏快照，不重复读取 Bean；`SecurityAuditQueryService.parseSnapshot` 改用构造器注入的 `AuditSanitizer`。保留无效 JSON → `_redacted=invalid_snapshot`、不可变副本和不泄漏原始快照的语义。

- [ ] **Step 5: Run audit security regression and static scans**

  ```bash
  mise exec -- ./mvnw -pl spectra-common,spectra-core -am \
      -Dtest=DefaultAuditSanitizerTest,AuditSanitizerBeanContractTest,SecurityAuditEventFactoryTest,SecurityAuditEventSanitizationTest,SecurityAuditQueryServiceTest \
      -Dsurefire.failIfNoSpecifiedTests=false test
  rg -n 'DefaultAuditSanitizer\.INSTANCE|SENSITIVE_KEYS|REDACTED_VALUE' \
      spectra-admin/spectra-common spectra-admin/spectra-modules/spectra-core --glob '*.java'
  ```

  Expected: 只有一个生产脱敏策略；业务服务不再绕过 Bean，审计事件、查询结果、Outbox 序列化和无效快照处理仍 fail-closed，不输出敏感原文。

### Task 21: [P2] 提取通知发送器解析 Registry

**Files:**
- Create: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/notification/sender/NotificationSenderRegistry.java`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/notification/service/impl/NotificationGatewayImpl.java:124,150-155`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/notification/dispatch/NotificationTaskWorker.java:92` and its sender selection path
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/notification/health/NotificationHealthIndicator.java:43`
- Test: `spectra-admin/spectra-modules/spectra-core/src/test/java/com/devops00/spectra/core/notification/sender/NotificationSenderRegistryTest.java`
- Modify: existing Gateway、Worker、Health 测试中的 `List<NotificationSender>` 构造参数

**Interfaces:**
- Consumes: `NotificationSender` 策略集合、`NotificationChannel`、发送可用性和现有不可用错误语义。
- Produces: 按 `NotificationChannel` 解析发送器的单一 Core 组件；`NotificationProviderRuntime` 继续只负责 Provider 配置/健康状态，不与发送器 Registry 合并。

  Registry 至少提供以下方法：

  ```java
  public NotificationSender require(NotificationChannel channel);

  public Optional<NotificationSender> find(NotificationChannel channel);
  ```

- [ ] **Step 1: Write registry contract tests**

  覆盖空渠道、未注册渠道、已注册渠道、重复渠道实现和发送器 `available()` 为 false 的情况；重复渠道必须在 Bean 创建阶段失败，未注册渠道不得被静默降级或触发额外 Provider/数据库查询。

- [ ] **Step 2: Run the focused test to verify it is red**

  ```bash
  cd spectra-admin
  mise exec -- ./mvnw -pl spectra-core -am \
      -Dtest=NotificationSenderRegistryTest \
      -Dsurefire.failIfNoSpecifiedTests=false test
  ```

  Expected: Registry 尚未存在时测试失败，且现有通知发送测试仍能独立暴露迁移前的列表扫描路径。

- [ ] **Step 3: Build an immutable channel registry**

  构造器注入 `List<NotificationSender>`，启动时复制为不可变 `EnumMap`/Map；对 null、重复渠道和非法声明直接失败。`require` 对 null/未知渠道抛出现有通知不可用异常，`find` 返回 `Optional.empty()`；不得使用静态注册表或运行期可变全局状态。

- [ ] **Step 4: Migrate Gateway, Worker and Health**

  三个调用方只依赖 Registry：Gateway 的 `availability` 和发送选择、Worker 的任务投递选择、Health 的渠道探测均调用同一解析入口。保持通知幂等、重试、投递记录、Provider 健康检查和不可用原因的现有语义；不要把 Registry 的职责扩展为 Provider 配置或健康缓存。

- [ ] **Step 5: Run notification regression tests and compare lookup paths**

  ```bash
  mise exec -- ./mvnw -pl spectra-core -am \
      -Dtest=NotificationSenderRegistryTest,NotificationGatewayImplTest,NotificationTaskWorkerTest,NotificationHealthIndicatorTest,NotificationProviderRuntimeTest \
      -Dsurefire.failIfNoSpecifiedTests=false test
  rg -n 'senders\.stream\(\)|List<NotificationSender>' \
      spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/notification
  ```

  Expected: 生产代码只在 Registry 内接收并索引发送器列表；Gateway、Worker、Health 不再重复查找，通知 Provider Runtime 的状态逻辑没有被复制。

### Task 22: [P2] 将 NameFill 改为显式 Lookup Registry 和 feature Adapter

**Files:**
- Create: `spectra-admin/spectra-framework/src/main/java/com/devops00/spectra/framework/assembler/NameLookupRegistry.java`
- Create: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/lookup/DepartmentNameLookup.java`
- Create: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/lookup/RegionNameLookup.java`
- Modify: `spectra-admin/spectra-framework/src/main/java/com/devops00/spectra/framework/assembler/NameFillExecutor.java`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/javabean/vo/UserPageVO.java:116`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/javabean/vo/DepartmentTreeVo.java:79`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/service/impl/DepartmentServiceImpl.java`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/service/impl/RegionServiceImpl.java`
- Test: `spectra-admin/spectra-framework/src/test/java/com/devops00/spectra/framework/assembler/NameLookupRegistryTest.java`
- Modify: `spectra-admin/spectra-framework/src/test/java/com/devops00/spectra/framework/assembler/NameFillExecutorTest.java`
- Test: `spectra-admin/spectra-modules/spectra-core/src/test/java/com/devops00/spectra/core/system/lookup/DepartmentNameLookupTest.java`
- Test: `spectra-admin/spectra-modules/spectra-core/src/test/java/com/devops00/spectra/core/system/lookup/RegionNameLookupTest.java`

**Interfaces:**
- Consumes: `NameFill` 注解、`NameLookup` 批量查询 SPI、现有部门/区域名称查询 SQL 和 VO 回填行为。
- Produces: 显式解析 Lookup 类型的 framework Registry，以及不依赖完整 Service 实现的 `DepartmentNameLookup`、`RegionNameLookup` Adapter；`NameFillExecutor` 不再通过 `ApplicationContext.getBean()` 进行隐式查找。

  `NameLookupRegistry` 以 Lookup 实现类型为 key，至少提供：

  ```java
  public NameLookup<?> require(Class<? extends NameLookup<?>> lookupType);
  ```

  `DepartmentNameLookup` 和 `RegionNameLookup` 保持现有 `NameLookup<UUID>` 批量查询契约，直接复用对应 Mapper/读模型，不调用完整 `DepartmentServiceImpl` 或 `RegionServiceImpl`，避免增加 Service 自调用。

- [ ] **Step 1: Write the failing registry and assembler tests**

  测试 Registry 能解析已注册 Lookup、未知类型失败、同一 Lookup 类型重复注册失败；测试 Executor 通过 Registry 批量收集 ID、一次调用每个 Lookup、正确处理 String/UUID key 和空输入，并验证不再依赖 `ApplicationContext`。

- [ ] **Step 2: Run the focused tests to verify the old lookup path is exposed**

  ```bash
  cd spectra-admin
  mise exec -- ./mvnw -pl spectra-framework,spectra-core -am \
      -Dtest=NameLookupRegistryTest,NameFillExecutorTest \
      -Dsurefire.failIfNoSpecifiedTests=false test
  ```

  Expected: Registry 构造器和 Executor 新依赖尚未接入时测试失败；失败信息必须能区分 Bean 解析失败、批量查询次数错误和字段回填错误。

- [ ] **Step 3: Implement the explicit Registry without adding mutable singleton state**

  Registry 构造器注入所有 `NameLookup<?>` Bean，使用不可变类型索引并在启动时校验重复类型；Executor 构造器只注入 Registry，保留现有注解字段扫描、源字段读取、批量 ID 去重、ID 类型转换、目标字段写入和空集合快速返回。不得加入未经需求验证的缓存、静态注册表或请求级状态。

- [ ] **Step 4: Extract feature-owned Lookup Adapters and migrate annotations**

  从 `DepartmentServiceImpl`、`RegionServiceImpl` 移除 `NameLookup` 扩展职责，将查询逻辑迁移到对应 feature Adapter；把 `UserPageVO` 和 `DepartmentTreeVo` 的 `@NameFill.lookup` 分别改为 `DepartmentNameLookup.class` 和 `RegionNameLookup.class`。调用方迁移完成后删除 Service 作为 Lookup 的旧入口，不保留别名或回退查找。

- [ ] **Step 5: Run assembler, feature and package-boundary tests**

  ```bash
  mise exec -- ./mvnw -pl spectra-framework,spectra-core -am \
      -Dtest=NameLookupRegistryTest,NameFillExecutorTest,DepartmentNameLookupTest,RegionNameLookupTest \
      -Dsurefire.failIfNoSpecifiedTests=false test
  rg -n 'ApplicationContext\.getBean|@NameFill\(lookup = (DepartmentServiceImpl|RegionServiceImpl)\.class|implements NameLookup' \
      spectra-admin/spectra-framework spectra-admin/spectra-modules/spectra-core --glob '*.java'
  ```

  Expected: Executor 只通过显式 Registry 解析 Lookup；VO 不再绑定完整 Service 实现；部门/区域名称回填结果、批量调用次数和空值语义保持不变。

### Task 23: [P2] 完善文件存储 Provider Registry 并统一健康检查入口

**Files:**
- Move: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/upload/configure/FileStorageProviderRegistry.java` → `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/upload/storage/FileStorageProviderRegistry.java`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/upload/service/FileAssetApplicationService.java:27,47`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/upload/service/UploadApplicationService.java`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/upload/service/FileUploadCleanupService.java`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/upload/health/FileStorageHealthIndicator.java:23,44,70`
- Test: `spectra-admin/spectra-modules/spectra-core/src/test/java/com/devops00/spectra/core/upload/storage/FileStorageProviderRegistryTest.java`
- Modify: existing upload service and health tests importing `core.upload.configure.FileStorageProviderRegistry`

**Interfaces:**
- Consumes: `FileStorageProvider`、`StorageProviderType`、上传默认 Provider 配置、对象存储健康检查和现有 `FILE_STORAGE_UNAVAILABLE` 异常。
- Produces: `core.upload.storage` 下的单一 Provider Registry；业务服务和健康检查共用同一不可变 Provider 索引，不再各自注入并遍历 Provider 列表。

  Registry 至少提供：

  ```java
  public FileStorageProvider require(StorageProviderType type);

  public Optional<FileStorageProvider> find(StorageProviderType type);
  ```

- [ ] **Step 1: Write the failing Registry and health reuse tests**

  覆盖 Provider 列表为空、默认 Provider 缺失、重复 `StorageProviderType`、已注册 Provider、`require(null)` 和 Provider 健康检查异常；测试 `FileStorageHealthIndicator` 只能通过 Registry 查询默认 Provider，不能再注入 `List<FileStorageProvider>`。

- [ ] **Step 2: Run the focused tests to verify the old configuration path is red**

  ```bash
  cd spectra-admin
  mise exec -- ./mvnw -pl spectra-core -am \
      -Dtest=FileStorageProviderRegistryTest,FileStorageHealthIndicatorTest \
      -Dsurefire.failIfNoSpecifiedTests=false test
  ```

  Expected: Registry 新包和 `find` 契约尚未完成时测试失败；失败不能通过放宽缺失 Provider 的断言来规避。

- [ ] **Step 3: Move and harden the existing Registry**

  将 Registry 归位到 `upload.storage`，构造器注入 Provider 列表并复制为不可变索引；重复类型在启动阶段抛出明确异常，null 类型和未注册类型统一走现有存储不可用错误。保持 `require` 不返回 null，不引入动态替换、静态全局状态或缓存失效问题。

- [ ] **Step 4: Make all upload consumers use the Registry**

  迁移 `FileAssetApplicationService`、`UploadApplicationService`、`FileUploadCleanupService` 和 `FileStorageHealthIndicator` 的导入及依赖；健康检查使用 `find(defaultStorage)`，Provider 自身的 `health()` 失败继续转换为 DOWN 结果，业务存储不可用继续 fail-closed。

- [ ] **Step 5: Run storage regression tests and residual scans**

  ```bash
  mise exec -- ./mvnw -pl spectra-core -am \
      -Dtest=FileStorageProviderRegistryTest,FileStorageHealthIndicatorTest,FileAssetApplicationServiceTest,FileUploadCleanupServiceTest,UploadApplicationServiceWiringTest \
      -Dsurefire.failIfNoSpecifiedTests=false test
  rg -n 'core\.upload\.configure\.FileStorageProviderRegistry|List<FileStorageProvider>' \
      spectra-admin/spectra-modules/spectra-core/src/main/java --glob '*.java'
  ```

  Expected: 生产代码只有 Registry 接收 Provider 列表；旧 `configure` 包入口、重复选择逻辑和直接列表遍历均清除，文件上传、清理和健康检查行为保持不变。

## 工作包 F：Java 25 现代化落地

### Task 24: [P2] 落地 Java 25 稳定特性并替换自维护线程上下文

**Files:**
- Modify: `spectra-admin/spectra-common/src/main/java/com/devops00/spectra/common/audit/RequestCorrelationContext.java`
- Modify: `spectra-admin/spectra-common/src/main/java/com/devops00/spectra/common/mybatis/DataScopeContextHolder.java`
- Modify: `spectra-admin/spectra-framework/src/main/java/com/devops00/spectra/framework/web/filter/RequestCorrelationFilter.java`
- Modify: `spectra-admin/spectra-framework/src/main/java/com/devops00/spectra/framework/persistence/scope/context/DataScopeContextFilter.java`
- Modify: `spectra-admin/spectra-framework/src/main/java/com/devops00/spectra/framework/persistence/scope/context/DataScopeExecutor.java`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/audit/AuditAspect.java`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/notification/dispatch/NotificationTaskWorker.java`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/outbox/OperationLogOutboxWorker.java`
- Modify: `spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/security/audit/outbox/SecurityChangeOutboxWorker.java`
- Create: `spectra-admin/spectra-common/src/test/java/com/devops00/spectra/common/context/ScopedValueContextContractTest.java`
- Modify: `spectra-admin/spectra-framework/src/test/java/com/devops00/spectra/framework/web/filter/RequestCorrelationFilterTest.java`
- Modify: `spectra-admin/spectra-framework/src/test/java/com/devops00/spectra/framework/DataScopeIsolationTest.java`
- Modify: context-sensitive Core tests under `spectra-admin/spectra-modules/spectra-core/src/test/java/**`
- Modify: `docs/superpowers/specs/2026-09-04-java-language-usage-matrix.md`

**Interfaces:**
- Consumes: 当前 `RequestCorrelationContext`、`DataScopeContextHolder` 的 `ThreadLocal` 和可关闭 Scope API，以及已有 worker/filter/MDC 清理边界。
- Produces: 基于 Java 25 `ScopedValue` 的不可变、词法作用域上下文；请求链路、任务链路和数据权限绕过均在 callback 作用域内传播，Spring `SecurityContextHolder` 和 MDC 的既有安全/日志语义不被无条件替换。

  `RequestCorrelationContext` 的新内部调用入口固定为：

  ```java
  public static Context current();
  public static <T> T callWithMdc(Context context, Callable<T> action) throws Exception;
  public static void runWithMdc(Context context, Runnable action);
  public static <T> T callTask(String taskId, Callable<T> action) throws Exception;
  ```

  `DataScopeContextHolder` 保留 `isBypassed` 和 `withBypass` 的业务语义，新增请求作用域入口：

  ```java
  public static <T> T callWithRequest(Callable<T> action) throws Exception;
  public static boolean isBypassed();
  public static <T> T withBypass(Supplier<T> action);
  public static void withBypass(Runnable action);
  ```

- [ ] **Step 1: Write failing ScopedValue contract tests**

  覆盖 Request correlation 的空上下文、嵌套作用域恢复、异常后恢复、MDC 恢复、任务上下文 requestId 为空和并发任务互不泄漏；覆盖 DataScope 的请求作用域、嵌套 bypass 深度、异常后清理和虚拟线程并发隔离。增加源码约束断言：两个自维护 Context Holder 不得继续声明 `ThreadLocal`，不得保留 `open`/`beginRequest`/`endRequest` 作为兼容别名。

- [ ] **Step 2: Run the focused tests to verify the new context contract is red**

  ```bash
  cd spectra-admin
  mise exec -- ./mvnw -pl spectra-common,spectra-framework,spectra-core -am \
      -Dtest=ScopedValueContextContractTest,RequestCorrelationFilterTest,DataScopeIsolationTest \
      -Dsurefire.failIfNoSpecifiedTests=false test
  ```

  Expected: `ScopedValue` 新入口和无泄漏契约尚未实现时测试失败；失败必须能区分 API 缺失、作用域恢复错误和并发串值。

- [ ] **Step 3: Replace RequestCorrelationContext storage with `ScopedValue`**

  使用 `java.lang.ScopedValue<RequestCorrelationContext.Context>` 存储不可变 `Context`；`current()` 使用未绑定时的空上下文，`callWithMdc`/`runWithMdc` 在 `ScopedValue.where(...).call/run` 内设置 MDC，并在 finally 中恢复之前的 MDC。删除跨调用方持有的 `Scope`、`open`、`openWithMdc` 和 `openTask`，不把 ScopedValue 暴露到 common Port 签名中。

- [ ] **Step 4: Replace DataScopeContextHolder storage with lexical immutable depth**

  使用 `ScopedValue<Integer>` 表示当前 bypass 深度；`withBypass` 通过嵌套绑定深度实现递归调用，`callWithRequest` 在请求期间绑定深度 0，回调结束后自动解除绑定。删除 `beginRequest`/`endRequest` 和可变 `Context`；`DataScopeInnerInterceptor` 仍只读取 `isBypassed()`，数据权限绕过仍只能从 `DataScopeExecutor` 进入。

- [ ] **Step 5: Migrate servlet, aspect and worker boundaries**

  将 `RequestCorrelationFilter`、`AuditAspect`、`NotificationTaskWorker`、`OperationLogOutboxWorker` 和 `SecurityChangeOutboxWorker` 的 try-with-resources Scope 改为 callback 作用域，并正确转译 Filter 的 checked exception；将 `DataScopeContextFilter` 改为 `callWithRequest`，保留 finally 等价的作用域自动清理。保留异步任务中的显式 task correlationId，不假设任意 Executor 会自动传播上下文；需要跨线程时由任务边界显式建立上下文。

- [ ] **Step 6: Apply stable Java 25 features only where they have a concrete benefit**

  在 `java-language-usage-matrix.md` 中完成 Java 25 稳定特性盘点：`ScopedValue` 已由本任务落地；record、pattern matching、switch expression、Sequenced Collection API 和 `var` 只补齐明确提高可读性的遗漏。当前 `SHA256Utils` 只有 SHA-256、HMAC-SHA256 和 nonce，不把普通摘要/HMAC 误改为 `javax.crypto.KDF`；只有发现明确的“主密钥派生子密钥”路径时才使用 JDK 25 KDF API，并为 HKDF 参数、输出长度和旧结果等价性增加测试。`module import`、compact source/instance main 不用于 Spring Boot 生产类，预览/实验特性不启用；JFR 方法计时作为诊断配置评估，不把业务计时逻辑隐式改掉。

- [ ] **Step 7: Run Java 25 context, concurrency and regression tests**

  ```bash
  mise exec -- ./mvnw -pl spectra-launch -am \
      -Dtest=ScopedValueContextContractTest,JavaLanguageUsageContractTest,RequestCorrelationFilterTest,DataScopeIsolationTest,AuditAspectContractTest,NotificationTaskWorkerTest,OperationLogOutboxWorkerTest,SecurityChangeOutboxWorkerTest \
      -Dsurefire.failIfNoSpecifiedTests=false test
  rg -n 'ThreadLocal|RequestCorrelationContext\.(open|openWithMdc|openTask)|DataScopeContextHolder\.(beginRequest|endRequest)' \
      spectra-admin/spectra-common/src/main/java spectra-admin/spectra-framework/src/main/java \
      spectra-admin/spectra-modules/spectra-core/src/main/java --glob '*.java'
  ```

  Expected: 自维护请求/数据权限上下文不再依赖 `ThreadLocal`；嵌套、异常、虚拟线程并发和 MDC 恢复测试通过，旧 Scope/Request API 无残留；未采用的 Java 25 特性在矩阵中有具体的 Spring 运行模型或适用性理由。

## 工作包 G：common 技术依赖

### Task 25: 收敛 common 中的技术依赖

**Files:**
- Modify: `spectra-admin/spectra-common/pom.xml`
- Modify: `spectra-admin/spectra-common/src/main/java/com/devops00/spectra/common/response/R.java`
- Modify: `spectra-admin/spectra-common/src/main/java/com/devops00/spectra/common/properties/SystemProperties.java`
- Modify: `spectra-admin/spectra-common/src/main/java/com/devops00/spectra/common/base/BaseEntity.java`
- Modify: `spectra-admin/spectra-common/src/main/java/com/devops00/spectra/common/base/BaseService.java`
- Modify: `spectra-admin/spectra-common/src/main/java/com/devops00/spectra/common/base/BaseServiceImpl.java`
- Modify: `spectra-admin/spectra-common/src/main/java/com/devops00/spectra/common/base/javabean/from/PageFrom.java`
- Modify: `spectra-admin/spectra-common/src/main/java/com/devops00/spectra/common/mybatis/PgJsonbNodeTypeHandler.java`
- Modify: `spectra-admin/spectra-common/src/main/java/com/devops00/spectra/common/mybatis/PgJsonbTypeHandler.java`
- Modify: `spectra-admin/spectra-common/src/main/java/com/devops00/spectra/common/event/FileUploadFinishEvent.java`
- Create: `spectra-admin/spectra-launch/src/test/java/com/devops00/spectra/architecture/CommonLayerDependencyTest.java`

**Interfaces:**
- Consumes: 当前 common 的 Spring、MyBatis-Plus、PostgreSQL、Servlet 和 Spring Event 依赖。
- Produces: common 契约包不再新增技术实现依赖；已有技术桥接被放到明确的 framework/config/persistence 模块，所有调用方迁移完成后删除旧入口。

- [ ] **Step 1: Write the dependency boundary test**

  扫描 `spectra-common/src/main/java` 的 import，允许 JDK、Jakarta 基础注解和项目纯契约包；禁止新增 `org.springframework`、`com.baomidou`、`org.postgresql`、`jakarta.servlet` 生产 import。现有白名单在测试中逐个记录迁移前的 12 个文件，迁移完成后白名单必须为空。

- [ ] **Step 2: Move one technical group at a time**

  - 将 `SystemProperties` 和 `R` 的 Spring Boot/Web 类型移动到 config/framework-web，并保留同一 API 字段和序列化结果。
  - 将 `BaseEntity`、`BaseService`、`BaseServiceImpl`、`PageFrom` 和 PgJsonb Handler 移到明确的 persistence 基础模块；所有 core/OA Mapper 和 Service 依赖新包。
  - 与 Task 18 的工具归属迁移衔接：`IpUtils` 等 Web 适配已进入 framework-web；本任务只清理 common 中剩余的 Servlet 技术 import，不让领域服务重新依赖 Servlet。
  - 将 `FileUploadFinishEvent` 变为 common Port 中的纯事件数据，事件发布适配器放入 framework/core。
  - `ConfiguredValueType`、`RegionLevel` 等 MyBatis 枚举在迁移对应 Entity 后一并迁移，禁止只移动一半导致 common 反向依赖业务模块。

- [ ] **Step 3: Run dependency and module tests**

  ```bash
  mise exec -- ./mvnw -pl spectra-launch -am \
      -Dtest=CommonLayerDependencyTest,ArchitectureTest test
  ```

  Expected: common 生产源码没有被禁止的技术 import，所有模块仍能编译和通过架构测试。

- [ ] **Step 4: Run documentation synchronization only if architecture docs changed**

  如果模块边界、能力归属或 common 分层发生变化，更新：

  - `docs/10-后端/10-架构分层.md`
  - `docs/10-后端/11-模块边界清单.md`
  - `docs/10-后端/12-能力归属矩阵.md`
  - `docs/10-后端/15-spectra-core模块.md`
  - `docs/40-规范/15-后端开发规范.md`

  然后从仓库根目录运行：

  ```bash
  bash scripts/check-docs.sh
  ```

- [ ] **Step 5: Commit the common layer migration**

  ```bash
  git add spectra-admin/spectra-common spectra-admin/spectra-config spectra-admin/spectra-framework \
      spectra-admin/spectra-modules spectra-admin/spectra-launch docs/10-后端 docs/40-规范
  git commit -m "refactor: isolate common technical dependencies"
  ```

## 工作包 H：最终门禁

### Task 26: 执行完整质量门禁并确认计划文件未被跟踪

**Files:**
- Test: all backend source and test modules
- Verify: `docs/superpowers/specs/2026-09-04-backend-quality-remediation-design.md`
- Verify: `docs/superpowers/plans/2026-09-04-backend-quality-remediation-plan.md`

**Interfaces:**
- Consumes: Task 1–25 的代码、测试、架构规则和文档更新。
- Produces: 完整测试和静态质量证据；`docs/superpowers` 下的计划/设计文件继续被忽略。

- [ ] **Step 1: Run all default tests**

  ```bash
  cd spectra-admin
  mise exec -- ./mvnw -pl spectra-launch -am test -Dstyle.color=never
  ```

  Expected: 全部模块 `BUILD SUCCESS`，Failures=0，Errors=0；任何 Skipped 必须来自项目既有分类并在交付说明中记录。

- [ ] **Step 2: Run architecture and module checks**

  ```bash
  mise exec -- ./mvnw -pl spectra-launch -am \
      -Dtest='ArchitectureTest,CrossModulePortBoundaryTest,OaCoreBoundaryTest,OptionalModuleIsolationTest,ControllerAnnotationContractTest,CommonLayerDependencyTest,FrameworkPackageLayoutTest,BackendUtilityArchitectureTest,ServiceDocumentationContractTest,FrameworkPatternAssessmentTest,FileReferencePermissionResolverTest,AuditSanitizerBeanContractTest,NotificationSenderRegistryTest,NameLookupRegistryTest,FileStorageProviderRegistryTest,JavaLanguageUsageContractTest,ScopedValueContextContractTest' \
      -Dsurefire.failIfNoSpecifiedTests=false test
  bash scripts/check-module-boundaries.sh
  ```

  Expected: 架构测试、OA 边界、Controller 契约、Framework 包布局、全后端工具收敛、Service 注释和模式评估测试全部通过，模块边界脚本的 forbidden_matches 和 architecture_violations 均为 0。

- [ ] **Step 3: Run the full quality gate**

  ```bash
  mise exec -- ./mvnw -pl spectra-launch -am verify -Dstyle.color=never
  ```

  交付时同时记录 Checkstyle、PMD、SpotBugs、Spotless、Enforcer 和测试结果；不要使用 `-Dmaven.test.skip=true` 作为唯一验证。

- [ ] **Step 4: Verify the ignored plan artifacts**

  从仓库根目录执行：

  ```bash
  git check-ignore -v docs/superpowers/specs/2026-09-04-backend-quality-remediation-design.md \
      docs/superpowers/plans/2026-09-04-backend-quality-remediation-plan.md
  ```

  Expected: 两个文件均由根目录 `.gitignore` 的 `superpowers/` 规则命中；实施代码提交时不得将这两个计划文件加入暂存区。

- [ ] **Step 5: Produce the handoff report**

  在交付说明中列出：已完成的任务、每个任务的测试命令和结果、统计/通知/Region 的调用次数变化、工具类收敛前后的调用方和重复实现变化、仍保留的架构债务，以及未修改的 API/数据库/安全 Redis 约束。计划文件本身保持在 ignored `docs/superpowers/` 目录中。
