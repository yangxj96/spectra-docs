# Spectra

> Spectra 全栈项目的根工作区，同时维护项目知识库，并通过 Git submodule 引入后端、Web 管理后台和流程建模插件。

## 克隆后先看这里

首次拉取请使用包含子模块的命令：

```bash
git clone --recurse-submodules https://github.com/yangxj96/spectra-docs.git spectra
cd spectra
```

已经普通克隆过仓库时，补齐子模块：

```bash
git submodule update --init --recursive
```

然后按 [环境搭建](docs/50-开发指南/10-环境搭建.md) 完成以下事项：

1. 安装 Bash、mise、PostgreSQL 18 和 Redis。
2. 从示例文件创建本机配置；真实密码和密钥只写入 Git 已忽略的本地文件。
3. 初始化数据库，安装三个子项目的依赖。
4. 分别启动后端、Web 管理后台和流程建模插件。

最常用的构建与检查命令见 [常见命令](docs/50-开发指南/20-常见命令.md)。

## 什么能直接复用

| 类型 | 是否可直接使用 | 说明 |
|---|---|---|
| 仓库相对路径 | 是 | 文档命令均从仓库根目录或明确标注的子项目目录执行，不依赖克隆到哪个磁盘 |
| `mise.toml`、Maven Wrapper、`package.json` 脚本 | 是 | 工具版本和构建入口已随仓库提交 |
| 开发端口 4004 / 5173 | 是 | 默认本机联调约定；端口冲突时才需要覆盖 |
| `.env.example`、`.mise.local.toml.example` | 作为模板使用 | 文件本身可复用，但必须复制成被 Git 忽略的本机配置后再填写 |
| `127.0.0.1` / `localhost` | 仅默认本机拓扑可直接使用 | 数据库、Redis、后端都在同一台机器时可用；容器、局域网或远程服务必须改地址 |
| 证书、数据库密码、Redis 密码、S3 地址与密钥 | 否 | 每台机器或每套环境单独配置，仓库不提供真实值 |
| CodeGraph、Obsidian、Codex 沙箱回退脚本 | 否，均为可选工具 | 不影响项目构建和启动；需要时按本机安装位置配置 |

## 仓库结构

```text
spectra/
├── docs/                         # Markdown、Mermaid 与 Canvas 知识库
│   ├── 00-项目总览.md
│   ├── 10-后端/
│   ├── 20-前端/
│   ├── 30-数据模型/
│   ├── 40-规范/
│   ├── 50-开发指南/
│   ├── 60-部署运维/
│   ├── 70-AI速查/
├── scripts/                      # 文档检查与 Agent 环境辅助脚本
├── spectra-admin/                # submodule：Spring Boot API
├── spectra-ui/                   # submodule：Vue Web 管理后台
├── logicflow-plugin-flowable/    # submodule：LogicFlow/Flowable 插件
├── AGENTS.md                     # Agent 工作约定
└── README.md
```

三个子项目之间的运行关系：

- `spectra-ui` 调用 `spectra-admin`。
- `spectra-ui` 通过 `file:../logicflow-plugin-flowable` 使用本地流程插件。
- 只修改普通 Web 页面时不需要启动插件监听；修改插件源码时先构建插件或运行监听构建。

## 默认开发地址

| 服务 | 默认地址 | 备注 |
|---|---|---|
| spectra-admin | `https://127.0.0.1:4004/api` | 首次启动模板默认启用本地 TLS，使用 `files/ssl/keystore.p12` |
| spectra-ui | `https://localhost:5173` | 使用共享 P12 证书和 `SSL_PASSWORD`，API 地址来自本机环境文件 |
| PostgreSQL | `127.0.0.1:5432` | 数据库名、账号和密码由本机配置决定 |
| Redis | `127.0.0.1:6379` | 当前后端连接串要求配置密码 |

## 文档和可选工具

- 用普通 Markdown 阅读器即可查看 `docs/`；Obsidian 只是可选的图谱和 wikilink 阅读体验。
- `docs/00-项目总览.md` 是架构入口，`docs/50-开发指南/10-环境搭建.md` 是新机器入口。
- 修改文档后在仓库根目录运行 `./scripts/check-docs.sh`。

### CodeGraph（可选）

CodeGraph 不参与项目构建。只有已经安装 `codegraph` CLI 且希望使用源码知识图谱时，才需要在各子项目和根目录初始化索引：

```bash
(cd spectra-admin && codegraph init)
(cd spectra-ui && codegraph init)
(cd logicflow-plugin-flowable && codegraph init)
codegraph init
```

`.codegraph/` 是可重建的本机索引，已被 Git 忽略。没有安装 CodeGraph 时跳过本节即可。

## 项目技能

项目 Codex 插件提供以下规范技能：

| Skill | 用途 |
|---|---|
| `spectra-admin-spec` | 后端 Java 分层、命名、事务、权限和数据规范 |
| `spectra-ui-spec` | Web Vue/TypeScript 架构、类型、组件和测试规范 |
| `git-execution-spec` | Git 安全检查、提交规范和推送规则 |

这些技能服务于 Agent 开发流程，不是人工启动项目的前置依赖。
