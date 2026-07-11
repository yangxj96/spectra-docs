---
tags:
  - reference
  - guide
source: https://www.devops00.com/spectra-admin/commit-convention
---

# Git 提交规范

> 来源：[[00-项目总览|项目 VitePress 文档]]
>
> 适用于 spectra-admin、spectra-ui、spectra-app 所有子项目。

## 格式

```
type(scope): subject
```

| 字段 | 必填 | 说明 |
|---|---|---|
| type | ✔ | 提交类型 |
| scope | 可选 | 影响模块 |
| subject | ✔ | 简要描述 |

## Type 类型

| 类型 | 说明 |
|---|---|
| `feat` | 新功能 |
| `fix` | Bug 修复 |
| `refactor` | 代码重构（不改变功能） |
| `perf` | 性能优化 |
| `docs` | 文档更新 |
| `style` | 代码格式（不影响逻辑） |
| `test` | 测试相关 |
| `build` | 构建或打包配置 |
| `ci` | CI/CD 配置 |
| `deps` | 依赖升级 |
| `chore` | 杂项维护 |
| `revert` | 回滚提交 |

## Scope 模块

### 前端（spectra-ui / spectra-app）

| scope | 说明 |
|---|---|
| `ui` | 页面 / UI |
| `components` | 公共组件 |
| `router` | 路由 |
| `store` | 状态管理 |
| `api` | 前端接口调用 |
| `layout` | 布局 |
| `vite` | 构建工具 |
| `build` | 打包构建 |

### 后端（spectra-admin）

| scope | 说明 |
|---|---|
| `core` | 核心模块 |
| `auth` | 认证授权 |
| `security` | 安全相关 |
| `api` | 接口层 |
| `db` | 数据库 |
| `cache` | 缓存 |
| `config` | 配置 |
| `job` | 定时任务 |

### 通用

| scope | 说明 |
|---|---|
| `docs` | 文档 |
| `ci` | CI/CD |
| `deps` | 依赖升级 |
| `release` | 发布 |

## Subject 规范

- 使用**动词开头**、**现在时**
- **不使用句号**
- 建议 **50 字以内**

## 示例

```bash
# 正确
feat(ui): add workflow designer
fix(auth): resolve token refresh issue
refactor(core): optimize permission check
build(vite): upgrade to vite8

# 错误
feat: added login page          # 过去时
fix: fixed bug                  # 语义不清晰
update code                     # 缺少 type
```

## 推荐粒度

- 一个 commit 只做一件事
- 不要混合多个无关修改

## 安全注意事项

### 禁止提交的文件类型

| 类型 | 示例 |
|---|---|
| 配置文件（含真实凭据） | `.env`、`.mise.local.toml` |
| 启动脚本（含环境变量） | `start-*.ps1`、包含 `$env:` 的 `.ps1` |
| 证书/私钥 | `*.p12`、`*.jks`、`*.pem`、`*.key` |
| 临时/日志文件 | `*.tmp`、`*.log` |

### 提交前流程

1. `git diff --cached --name-only` 确认暂存文件
2. 仅 `git add <具体文件>`，禁止 `git add -A`
3. 推送需用户明确指令

## 相关笔记

- [[20-常见命令]] — 开发常用命令
- [[10-前端命名规范]] — 前端文件命名规则
- [[30-MapStruct命名规范]] — 后端命名规则
