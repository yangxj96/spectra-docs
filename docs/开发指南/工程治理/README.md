# 工程治理台账

ledger.json（源码仓库的 `docs/开发指南/工程治理/ledger.json`） 是 [[开发指南/05-集中治理与验收|集中治理与验收]] 的结构化状态入口，按 [[开发指南/04-工作区工程标准|工作区工程标准]] 维护文件覆盖、问题、跨项目影响、复杂度例外、验证证据和检查链路工作。

该目录是正式知识库，可以随项目维护；与仅保留本地讨论记录的 `docs/superpowers/` 不同。原始工具输出、浏览器产物和临时调试文件放根 `.temp/`，不在此堆积。

## 当前状态

全量代码治理状态仍是 `not_started`，coverage、issues、impacts、exceptions 尚为空；**空集合不代表零问题、零例外或已扫描通过。** 完整覆盖、检查配置和自动核对尚未实施。

GOV-007 已完成后端/Web Skill 的入口、受影响示例、修改前后场景和本地插件缓存对齐，验证摘要登记为 EV-SKILL-20261003。该证据只证明明确列出的 Skill 范围；当前会话仍需区分既有 Skill 目录快照与新安装版本，后续新会话加载状态另行核对。其他待办及全量代码治理不能由此推定完成。

## 结构与字段

路径相对工作区根，使用 `/`；ID 全工作区唯一且稳定。记录按实际分析更新，不自动从旧报告或类名推断完成。文件内容摘要在实际分析时保存；本文不要求读取凭据。

| 集合 | 每项字段 |
|---|---|
| coverage | `path`, `role`, `scope`, `state`, `content_sha256`, `reviewed_rules`, `issue_ids`, `evidence_ids` |
| issues | `id`, `rule`, `locations`, `finding`, `impact`, `priority`, `disposition`, `state`, `exception_ids`, `evidence_ids` |
| impacts | `id`, `change_source`, `direct`, `indirect`, `data_protocol_runtime`, `required_changes`, `deferred_boundary`, `state`, `evidence_ids` |
| exceptions | `id`, `path`, `symbol`, `rule`, `measured_value`, `tool_version`, `necessity`, `risk`, `verification`, `owner_area`, `reevaluate_when`, `state`, `evidence_ids` |
| evidence | `id`, `scope`, `command_or_scenario`, `environment`, `tool_versions`, `checked_at`, `result`, `artifacts`, `limits` |
| work_items | `id`, `area`, `requirement`, `state`, `resolution`, `evidence_ids` |

`locations` 可以包含多个明确的路径、符号或行号；行号只用于定位，不能作为例外符号的唯一身份。`verification` 描述例外需要的验证，`evidence_ids` 指向实际记录；填了验证要求不表示验证已完成。

## 状态约定

- 范围：`included`、`deferred_business`、`shared_impact`、`excluded`，排除原因必须可核对。
- 文件：`enumerated`、`reviewed`、`stale`；行为验证单独引用证据，不能混为一类。
- 问题/工作：`pending`、`in_progress`、`resolved`、`excepted`、`deferred`、`blocked`。
- 例外：`active`、`review_required`、`retired`；只有理由充分、范围有效及所需证据具备的 active 记录可用于验收。
- 证据：`passed`、`failed`、`not_run`、`inconclusive`；未执行不能写 passed。
- 全局：`not_started`、`inventory_in_progress`、`inventory_complete`、`unification_in_progress`、`acceptance_pending`、`accepted`。

结构版本管理只约束本台账格式，不改变 API 1.0.0。当前尚无已落地的自动校验器；核对字段、引用、抑制及失效的实现登记为待实施，不能将本 README 当作已实现的检查。
