# git-execution-spec Skill

当执行任何 git 命令时，此 skill 会自动加载作为执行规范指南。

## 使用场景

- 提交代码（git commit）
- 推送代码（git push）
- 暂存文件（git add）
- 撤回/重置操作
- 处理敏感信息
- 解决 git 冲突

## 核心规范

1. **操作分类**：只读命令可随时执行，写操作必须等待用户确认
2. **提交格式**：`type(scope): 中文描述`
3. **安全规则**：禁止自动推送、GPG 签名强制、禁止 git add -A
4. **泄露应急**：立即轮换密钥、清理历史、强制推送

## 操作分类速查

### 只读命令（无需确认）

| 命令 | 说明 |
|---|---|
| `git status` | 查看状态 |
| `git diff` | 查看变更 |
| `git log` | 查看历史 |
| `git branch` | 列出分支 |
| `git tag` | 列出标签 |
| `git remote -v` | 查看远程 |

### 写操作（必须确认）

| 命令 | 说明 |
|---|---|
| `git add <文件>` | 暂存文件（禁止 -A） |
| `git commit -m "..."` | 提交（必须 GPG 签名） |
| `git push` | 推送（绝对禁止自动执行） |
| `git revert` | 撤回提交 |
| `git reset` | 重置 |
| `git stash` | 暂存工作区 |

## Commit 格式

```
<type>(<scope>): <中文描述>
```

### Type

| 类型 | 说明 |
|---|---|
| `feat` | 新功能 |
| `fix` | 修复 bug |
| `docs` | 文档变更 |
| `style` | 代码格式 |
| `refactor` | 重构 |
| `perf` | 性能优化 |
| `test` | 测试相关 |
| `chore` | 其他杂项 |

### Scope

| Scope | 说明 |
|---|---|
| `ui` | spectra-ui |
| `app` | spectra-app |
| `admin` | spectra-admin |

## 详细规则查询

完整规范请查阅 `SKILL.md` 文件。
