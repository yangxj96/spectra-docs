# 工程治理台账

ledger.json（源码仓库的 `docs/开发指南/工程治理/ledger.json`） 是 [[开发指南/05-集中治理与验收|集中治理与验收]] 的结构化状态入口，按 [[开发指南/04-工作区工程标准|工作区工程标准]] 维护文件覆盖、问题、跨项目影响、复杂度例外、验证证据和检查链路工作。

该目录是正式知识库，可以随项目维护；与仅保留本地讨论记录的 `docs/superpowers/` 不同。原始工具输出、浏览器产物和临时调试文件放根 `.temp/`，不在此堆积。

## 当前状态

第一步于 2026-10-03 建立文件枚举基线；第二步于 2026-10-04 开始，2026-10-05 补齐当前源码诊断、历史证据复核与公共影响记录。当前清单纳入诊断辅助和本地报告后为 1978 个文件：1518 个 included/shared_impact 文件登记实际职责审查，438 个暂缓业务文件保留独立治理边界并另记公共引用/影响，22 个排除文件不读取、不摘要；另有 22 个排除目录。

第二步的完成记录见 `diagnosis`、issues、impacts 及 evidence；第三步的依赖排序见 `remediation_cycle`。GOV-001 仅关闭清单、诊断与风险建账职责，GOV-005 的分析已完成而统一实现仍为 `in_progress`。全局状态继续为 `inventory_complete`，**诊断和排期完成不代表问题解决、行为通过或集中治理已验收。** B00 的后端业务代码治理、GOV-002/GOV-003、例外核对、插件构建输入、Web ESLint/TypeScript 复验和已记录的浏览器/依赖证据已收口；剩余14条框架固定签名已逐项记录。下一项实质整改为 B01 与 B02；两者均仅依赖 B00，单批推进时推荐先做 B02。后续 B03–B10 仍按台账推进。新发现保持 pending，环境阻塞和静态候选明确区分；exceptions 为空不代表现有抑制已经合规。协议生成和真实依赖验收仍待实施。

GOV-007 已完成后端/Web Skill 的入口、受影响示例、修改前后场景和本地插件缓存对齐，验证摘要登记为 EV-SKILL-20261003。该证据只证明明确列出的 Skill 范围；当前会话仍需区分既有 Skill 目录快照与新安装版本，后续新会话加载状态另行核对。B00 的 GOV-002 已完成固定版本边界校准与阈值配置，证据为 EV-B00-CALIBRATION-20261005；后端 PMD 剩余 14 条已逐项核对并确认属于 Spring/框架固定签名或依赖注入构造器，不属于业务自有代码，见 EV-B00-LEGACY-20261005。GOV-002 已标记为 `resolved`；这些固定签名保留为明确记录的非业务约束。GOV-003 的自动核对器、回归测试和全部现存抑制例外登记已完成，校验器通过，见 EV-B00-EXCEPTION-20261005。Spotless、工作区级 SpotBugs、静态模块依赖方向检查、后端真实依赖测试和真实浏览器交互均有通过证据；正式架构门禁入口仍缺失，已在 EV-B00-TOOLING-20261005 中保留记录。其他待办及全量代码治理不能由此推定完成。

## 结构与字段

### 第一阶段枚举基线与复核方法

本轮使用原生 PowerShell `Get-ChildItem -LiteralPath <目录> -Force` 逐层枚举文件元数据，包含隐藏文件及被 Git 忽略的手写输入，不按 Git 跟踪状态决定范围；不读取源码、配置凭据或计算内容摘要。记录路径统一相对工作区根且使用 `/`。枚举遇到错误即终止，不静默跳过无权访问的目录，不跟随目录链接。

| 初步范围 | 文件数 | 下一步 |
|---|---:|---|
| included | 1484 | 按职责进行源码、测试、配置、脚本、构建和规则诊断 |
| shared_impact | 30 | 先核对公共导出、宿主、协议和混合迁移职责，再建立影响 |
| deferred_business | 438 | 独立业务治理暂缓；全部保留为公共影响分析候选 |
| excluded | 22 | 逐文件记录生成产物、静态二进制或私有配置排除原因 |

上表为第一阶段历史基线：当时共有 1514 个纳入/公共候选文件待审查，468 个公共/暂缓候选文件待影响分析；两组相互重叠，不能相加作为文件总数。当前数量以 `inventory.scope_counts` 为准，待审查列表筛选 `coverage` 中 `scope` 为 `included` 或 `shared_impact` 且 `state != reviewed`；公共影响待分析列表筛选 `impact_state == pending_analysis`。不另建平行状态表。

范围依据是第一阶段路径及职责候选分类，并非已经分析调用链：后端 OA/Workflow 的 `src/`、Web 对应业务页面/API/类型、插件 elements/features 和流程示例记为 `deferred_business`；模块 POM、启动装配、公共配置、测试入口和规则仍登记。插件公共导出/类型/辅助/宿主面板、Web 流程宿主候选及 Launch 混合数据库迁移记为 `shared_impact`。知识库、本地 Skill 及历史报告作为规则或证据输入纳入；不由历史报告推定当前源码 reviewed。第二阶段按实际定义、调用和职责复核这些初步边界，必要时提升暂缓文件为公共一致性范围。

`inventory.directory_exclusions` 记录实际遇到的排除目录、原因及 `applies_to: all_descendant_files`；该目录下每个文件继承 `excluded/enumerated`，不展开巨大的依赖和生成树。这不是整业务目录排除。排除目录名集合为 `.git`、`node_modules`、`.venv`、`.codegraph`、`.idea`、`.obsidian`、`.temp`、`.playwright-mcp`、`target`、`dist`、`dist-ssr`、`build`、`coverage`、`.cache`、`.mise-data`、`.maven-repository`、`.pnpm-store`、`.npm`、`.yarn`、`logs`、`out`、`test-results`、`playwright-report`、`docker-data`、`docker-volumes`、`.codex-tmp`。新增同名手写目录时必须复核排除合理性，不自动认为其治理已通过。

依赖目录、包缓存、Git 内部数据库、CodeGraph 索引、构建/测试产物和运行临时状态分别排除，原始生成链路、POM、锁文件、构建配置另行纳入。私有 `.mise.local.toml`、实际 `.env` 文件、密钥/密钥库及可能含凭据的本机配置仅枚举路径，禁止读取或摘要；example/template 示例配置继续纳入。二进制静态资源不套用手写源码规则，其引用和打包入口仍待审查。

可重复核对方法：再次枚举相同目录边界，并以 `rg --files --hidden --no-ignore` 独立枚举，每个排除目录名追加 `-g '!**/<目录名>/**'`；归一化路径后使用 `Compare-Object -CaseSensitive` 与 `coverage.path` 双向比对。差集必须为空，且路径唯一、每条记录有职责与范围、排除原因存在、证据引用有效。本阶段核对还要求所有记录为 `enumerated`，`content_sha256` 为 null，`reviewed_rules` 和 `issue_ids` 为空。任何新增或删除文件均需更新清单；内容变化后的审查失效由第二阶段建立的内容摘要复核。

历史证据为 EV-INVENTORY-20261003。本地辅助脚本 `docs/superpowers/plans/2026-10-03-全量覆盖核对.ps1` 不带参数可输出新枚举；其 `-Verify` 专用于“全部 enumerated、摘要为空”的第一阶段快照，不能用于已升级为 reviewed 的当前台账。辅助文件不纳入 Git 跟踪，也不作为长期唯一复现依据。枚举核对只证明范围记录一致，不证明源码、工具门禁或业务行为通过。

### 第二阶段诊断与内容复核

纳入文件登记具体职责、适用规则、发现及阅读限制，`reviewed` 只表示已审查当前输入。知识库按结构、引用及高影响声明核对，不能由此推断每句业务说明已验证。CodeGraph 用作定义/调用导航，裁剪和未命中由当前源码及 rg 补查。

暂缓文件继续为 `enumerated`，公共影响使用独立的 `impact_content_sha256`、`shared_dependency_refs`、`behavior_candidates`、`impact_review_kind`、`impact_review_summary`、`impact_review_limits`、`impact_ids`。`shared_reference_scan_only` 是全文件输入的机械导入/候选扫描，`shared_boundary_source_review` 是人工公共边界核对；二者均不表示独立业务治理完成，也不以未命中证明没有间接影响。影响链接注明确定关系或潜在间接边界，关键调用和完整共同范围由 impacts 描述。

问题和影响使用稳定 ID。共同影响归并保留 `diagnosis.impact_aliases`；互有关联的前后端问题保留各自具体事实，通过 `related_impact_ids` 联结，不合成模糊问题。R1–R6 和旧发现的当前归属、反证、暂缓及未验证范围登记在 `diagnosis.historical_reconciliation`。待行为场景见 `diagnosis.behavior_checks`，`not_run` 不可记作 passed。

交付核对重新枚举实际路径，检查唯一性、纳入 reviewed、摘要变化、问题位置和所有问题/影响/证据引用。普通审查输入的 `content_sha256` 是原文件 SHA256；暂缓影响摘要同样关联当前原文件。台账自身无法保存自身原字节摘要，唯一特殊记录使用 `digest_mode: canonical_json_with_self_digest_null`：原生 PowerShell 7.6 中 `ConvertFrom-Json -DateKind String` 解析，置自身 `content_sha256` 为 null，经 `ConvertTo-Json -Depth 100 -Compress` 序列化后计算 UTF-8 SHA256。写回该摘要后按同法核对。凭据及 excluded 内容始终不摘要。

本地核对入口为 `docs/superpowers/plans/2026-10-04-诊断台账核对.ps1`，交付记录为 EV-DIAG-VERIFY-20261005。它只核对本次诊断台账，不处理源码抑制、复杂度计数、例外失效或真实业务行为，不是 GOV-003 或整体验收门禁已实现的证据。长期复现依据为上述字段、枚举边界及摘要方法，原始输出在 `.temp/`。

路径相对工作区根，使用 `/`；ID 全工作区唯一且稳定。记录按实际分析更新，不自动从旧报告或类名推断完成。文件内容摘要在实际分析时保存；本文不要求读取凭据。

| 集合 | 每项字段 |
|---|---|
| coverage | `path`, `role`, `scope`, `state`, `content_sha256`, `reviewed_rules`, `issue_ids`, `evidence_ids` |
| issues | `id`, `rule`, `locations`, `finding`, `impact`, `priority`, `disposition`, `state`, `exception_ids`, `evidence_ids` |
| impacts | `id`, `change_source`, `direct`, `indirect`, `data_protocol_runtime`, `required_changes`, `deferred_boundary`, `state`, `evidence_ids` |
| exceptions | `id`, `path`, `symbol`, `rule`, `measured_value`, `tool_version`, `necessity`, `risk`, `verification`, `owner_area`, `reevaluate_when`, `state`, `evidence_ids` |
| evidence | `id`, `scope`, `command_or_scenario`, `environment`, `tool_versions`, `checked_at`, `result`, `artifacts`, `limits` |
| work_items | `id`, `area`, `requirement`, `state`, `resolution`, `evidence_ids` |

`remediation_cycle` 是正式整改顺序：每批记录 `id`、`depends_on`、`issue_ids`、`impact_ids`、`work_item_ids`、`change_scope`、`prerequisites`、`checks`、`done_when`。问题恰归属一个主批次；共同影响和治理工作可跨批出现。B00–B10 的 `scheduled` 仅表示排期，不能作为整改或验证通过的证据。已解决的 GOV-001/007 不再作为待整改项分派。

`locations` 可以包含多个明确的路径、符号或行号；行号只用于定位，不能作为例外符号的唯一身份。`verification` 描述例外需要的验证，`evidence_ids` 指向实际记录；填了验证要求不表示验证已完成。

## 状态约定

- 范围：`included`、`deferred_business`、`shared_impact`、`excluded`，排除原因必须可核对。
- 文件：`enumerated`、`reviewed`、`stale`；行为验证单独引用证据，不能混为一类。
- 问题/工作：`pending`、`in_progress`、`resolved`、`excepted`、`deferred`、`blocked`。
- 例外：`active`、`review_required`、`retired`；只有理由充分、范围有效及所需证据具备的 active 记录可用于验收。
- 证据：`passed`、`failed`、`not_run`、`inconclusive`；未执行不能写 passed。
- 全局：`not_started`、`inventory_in_progress`、`inventory_complete`、`unification_in_progress`、`acceptance_pending`、`accepted`。

结构版本管理只约束本台账格式，不改变 API 1.0.0。本次诊断已有本地覆盖与引用核对；正式例外/源码抑制/指标和失效自动核对仍登记为待实施，不能将本 README 或本地辅助当作已经落地的完整门禁。
