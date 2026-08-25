---
name: git-execution-spec
description: 仅在用户要求 Spectra 的 Git 状态、差异、暂存、提交、分支、标签、恢复、推送或冲突处理时使用；普通代码修改不要触发。
---

# Spectra Git Skill

## 读取预算

- 只为明确的 Git 操作加载本 Skill；普通代码、测试或文档任务不要触发。
- 状态/分支/远程只读对应命令；未要求差异时不要加载完整 diff、历史或所有子仓库。
- 审查/暂存/提交先看状态，再审查目标文件的未暂存或暂存 diff。
- 推送确认分支、上游、待推送提交和工作区状态；已有审查结论时不重复加载全部 diff。
- 冲突只读冲突文件清单和相关 diff；配置诊断可用脱敏的 `git config --show-origin --name-only --list`。

## 安全边界

- 只读的 `status`、`diff`、`diff --cached`、`log`、`show`、`branch`、`tag`、`remote -v`、`submodule status` 和脱敏的 `config` 查询可以执行。
- `add`、`commit`、`amend`、分支/标签写操作、恢复、重置、清理和推送必须在用户明确授权后执行。
- 禁止 `git add -A`、`git add .` 和未审查的批量暂存；暂存必须使用具体文件或明确目录。
- 推送必须等待用户明确说“推送”或“push”，即使用户已要求提交也不能自动推送。
- 变更审查必须检查 `git diff`、暂存文件清单和敏感信息。
- 不得提交 `.env*`、`.mise.local.toml`、证书私钥、Token、密码、API Key 或其他本机凭据。

## 提交格式

使用：`<type>(<scope>): <中文描述>`。

常用 type：`feat`、`fix`、`docs`、`style`、`refactor`、`perf`、`test`、`build`、`ci`、`chore`、`revert`。

Spectra 常用 scope：`admin`、`ui`、`app`、`core`、`security`、`framework`、`project`；跨模块变更可以省略 scope。

## 操作流程

1. 按读取预算确认现有改动和目标差异。
2. 审查目标文件和敏感信息。
3. 获得写操作确认后，使用具体文件暂存。
4. 检查暂存区文件和差异。
5. 获得提交确认后使用 Conventional Commit；提交后停止，等待推送指令。
