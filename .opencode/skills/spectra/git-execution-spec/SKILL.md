---
name: git-execution-spec
description: 当执行任何 git 命令时自动加载。包含提交规范、安全规则、操作确认等核心规范。
version: "1.0.0"
license: MIT
metadata:
  hermes:
    tags: [git, conventions, security, spectra]
---

# Git 执行规范

## 概述

本规范定义了在 Spectra 项目中执行 git 操作时必须遵循的安全规则和提交规范。

**核心原则：** 安全第一、确认机制、GPG 签名、禁止自动推送。

## 何时使用

当执行以下操作时自动加载：
- 执行任何 git 命令（commit、push、add 等）
- 审查代码变更
- 处理敏感信息
- 解决 git 冲突

## 操作分类

### 只读命令（允许随时执行）

以下命令**不需要用户确认**，可以随时执行：

```bash
# 查看状态
git status
git diff
git diff --stat
git diff --cached
git diff --cached --name-only

# 查看历史
git log
git log --oneline
git log -n 5
git show

# 查看分支/标签
git branch          # 列出本地分支
git branch -a       # 列出所有分支
git tag             # 列出标签
git remote -v       # 查看远程

# 其他只读操作
git blame
git shortlog
```

### 写操作（必须等待用户确认）

以下命令**必须暂停并等待用户明确确认**后才能执行：

#### 提交相关

```bash
# 暂存文件（必须使用具体文件，禁止 git add -A）
git add <具体文件1> <具体文件2>
git add src/          # 添加整个目录
git add -p            # 交互式暂存

# 提交（必须 GPG 签名）
git commit -m "type(scope): 描述"
git commit --amend    # 修改最近一次提交
```

#### 推送相关（绝对禁止自动执行）

```bash
git push              # 推送到远程
git push origin main  # 推送到指定分支
git push --force      # 强制推送（危险！）
```

#### 撤回/重置相关（危险操作）

```bash
git revert            # 撤回提交
git reset             # 重置
git checkout          # 切换分支/恢复文件
git restore           # 恢复文件
git clean             # 清理未跟踪文件
git stash             # 暂存工作区
```

#### 分支/标签管理

```bash
git branch <name>     # 创建分支
git branch -d <name>  # 删除分支
git tag <name>        # 创建标签
git tag -d <name>     # 删除标签
```

## 提交规范

### Commit 格式

```
<type>(<scope>): <中文描述>

<正文（可选）>

<脚注（可选）>
```

### Type 类型

| 类型 | 说明 | 示例 |
|---|---|---|
| `feat` | 新功能 | `feat(ui): 新增用户管理页面` |
| `fix` | 修复 bug | `fix(admin): 修复登录接口返回格式问题` |
| `docs` | 文档变更 | `docs: 更新 README 安装说明` |
| `style` | 代码格式（不影响功能） | `style(ui): 格式化代码` |
| `refactor` | 重构 | `refactor(ui): 重构 HTTP 客户端` |
| `perf` | 性能优化 | `perf(admin): 优化查询性能` |
| `test` | 测试相关 | `test: 添加单元测试` |
| `build` | 构建系统 | `build: 升级 Vite 到 v8` |
| `ci` | CI 配置 | `ci: 添加 GitHub Actions` |
| `chore` | 其他杂项 | `chore: 更新依赖` |
| `revert` | 回滚 | `revert: 回滚 feat #123` |

### Scope 范围

| Scope | 说明 |
|---|---|
| `ui` | spectra-ui（Web 管理后台） |
| `app` | spectra-app（移动端） |
| `admin` | spectra-admin（后端 API） |
| `ai` | AI 相关模块 |
| `security` | 安全/认证模块 |
| `core` | 核心框架 |
| `framework` | 基础设施 |
| `log` | 日志模块 |
| `project` | 项目管理 |
| 无 scope | 跨模块变更（如 `docs`、`chore`） |

### 提交信息示例

```bash
# 好的提交信息
git commit -m "feat(ui): 新增用户管理页面"
git commit -m "fix(admin): 修复登录接口返回格式问题"
git commit -m "docs: 更新 README 安装说明"
git commit -m "chore: 更新 spectra-admin 子模块引用"

# 不好的提交信息（禁止）
git commit -m "update"
git commit -m "fix bug"
git commit -m "修改了一些东西"
```

## 安全规则

### 提交前检查清单

**每次提交前必须执行以下检查：**

#### 1. 审查变更内容

```bash
# 查看变更统计
git diff --stat

# 查看具体变更
git diff

# 查看暂存区变更
git diff --cached
```

#### 2. 确认不包含敏感内容

**绝对禁止提交以下内容：**

| 类型 | 示例 |
|---|---|
| 环境配置文件 | `.env`、`.env.local`、`.env.production` |
| 本地配置文件 | `.mise.local.toml`（含数据库密码） |
| 证书私钥 | `*.p12`、`*.jks`、`*.pem`、`*.key` |
| 凭据脚本 | 包含 `$env:... = "真实值"` 的 `.ps1` |
| API 密钥 | 任何包含 Token/Secret/Key 的文件 |

#### 3. 禁止 git add -A

```bash
# ❌ 错误：禁止使用
git add -A
git add .
git add --all

# ✅ 正确：使用具体文件
git add src/components/MyComponent.vue
git add src/api/user-api.ts src/types/user.d.ts
```

#### 4. 确认暂存文件清单

```bash
# 查看将要提交的文件
git diff --cached --name-only
```

### GPG 签名规则

- **绝对禁止**使用 `--no-gpg-sign` 参数
- 所有提交必须经过 GPG 签名
- 依赖全局配置 `commit.gpgsign=true` 自动生效
- 如遇签名失败，排查 GPG 密钥配置，**不得跳过签名**

```bash
# ❌ 错误：跳过 GPG 签名
git commit --no-gpg-sign -m "..."

# ✅ 正确：依赖自动签名
git commit -m "..."
```

### 推送限制

- **绝对禁止**在未经用户明确允许的情况下执行 `git push`
- 即使用户说了"提交"，也只执行 `git commit`，**不执行 `git push`**
- 推送需要用户明确说出"推送"或"push"指令后才可执行

```bash
# ❌ 错误：自动推送
git add . && git commit -m "..." && git push

# ✅ 正确：只提交，等待用户确认推送
git add src/file.ts
git commit -m "feat: 新增功能"
# 等待用户说"推送"
```

### 泄露后应急流程

如已误提交并推送敏感信息：

1. **立即轮换所有暴露的密钥/密码/Token**
   - 数据库密码
   - API 密钥
   - SSH 密钥
   - 任何凭据

2. **清理 git 历史**
   ```bash
   # 交互式 rebase 删除敏感提交
   git rebase -i HEAD~n

   # 或使用 filter-branch（更彻底）
   git filter-branch --force --index-filter \
     'git rm --cached --ignore-unmatch <敏感文件>' \
     --prune-empty --tag-name-filter cat -- --all
   ```

3. **强制推送（需用户确认）**
   ```bash
   git push --force origin main
   ```

## 快速参考

### 常用命令模板

#### 提交一个功能

```bash
# 1. 检查变更
git status
git diff --stat

# 2. 暂存具体文件
git add src/components/MyComponent/index.vue
git add src/api/user-api.ts

# 3. 确认暂存内容
git diff --cached --name-only

# 4. 提交（自动 GPG 签名）
git commit -m "feat(ui): 新增用户管理组件"

# 5. 等待用户确认后推送
# 用户说"推送"后执行：git push
```

#### 修复一个 bug

```bash
# 1. 检查变更
git status

# 2. 暂存修复文件
git fix src/plugin/request/http.ts

# 3. 提交
git commit -m "fix(ui): 修复登录 token 刷新逻辑"

# 4. 等待用户确认推送
```

#### 更新文档

```bash
# 1. 暂存文档文件
git add docs/20-前端/10-spectra-ui.md

# 2. 提交
git commit -m "docs: 更新前端开发规范"

# 3. 等待用户确认推送
```

## 相关规范

- [[10-项目总览]] — 项目架构概述
- [[20-前端/10-spectra-ui]] — 前端开发规范
- [[.opencode/skills/spectra/spectra-admin-spec/SKILL.md]] — 后端开发规范
- [[.opencode/skills/spectra/spectra-ui-spec/SKILL.md]] — 前端规范 Skill
