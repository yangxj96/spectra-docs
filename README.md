# Spectra 光谱全栈平台

Spectra 是一个由 Spring Boot 后端、Vue Web 管理后台和 LogicFlow BPMN 流程设计器组成的全栈项目工作区，提供用户与权限、系统管理、办公自动化、通知、文件、调度、工作流和流程建模等能力。

这个仓库是项目根工作区和文档事实源。后端、Web 管理后台和流程设计器以 Git submodule 的方式组织，面向使用者、开发者、部署者和贡献者提供统一入口。

## 主要组成

```text
spectra-docs/
├── spectra-admin/                 # Spring Boot 后端 API，多模块 Maven 项目
├── spectra-ui/                    # Vue 3 Web 管理后台
├── logicflow-plugin-flowable/     # LogicFlow / Flowable BPMN 2.0 流程设计器插件
├── docs/                          # 项目文档事实源
└── scripts/                       # 文档检查与网站同步工具
```

后端以 `spectra-launch` 作为应用启动模块，业务模块包括始终装配的核心能力以及可选的 OA、Workflow 模块。Web 管理后台通过 HTTP API 调用后端；流程设计器插件既可以由 Web 管理后台使用，也可以作为独立的前端依赖接入其他 LogicFlow 宿主项目。

## 能力范围

- 认证、验证码、会话、用户、角色、菜单权限和数据范围。
- 部门、区域、字典、系统配置、操作记录和应用健康检查。
- OA 办公中的申请、请假、协同办公、报销、采购、资产、考勤、日历、通讯录、合同、文档、会议和公告等模块。
- 统一通知、通知模板、通知渠道、消息中心和通知运行管理。
- 本地或 S3 对象存储、分片上传、断点续传和文件资产管理。
- Quartz 调度、任务执行记录、服务监控、缓存监控和安全审计。
- Flowable 流程引擎集成，以及基于 LogicFlow 的 BPMN 2.0 流程建模、属性编辑、导入和导出。

当前项目是单体多模块、单租户、非 SaaS 形态。使用者、组织和数据范围可以在应用中配置，但应用层不提供租户上下文、租户切换或租户隔离。

## 快速入口

- [项目总览](docs/00-项目总览.md)：了解项目定位、组成、架构和能力边界。
- [快速开始](docs/01-快速开始.md)：从克隆仓库到启动并验证服务。
- [使用指南](docs/使用指南/00-使用指南.md)：按登录、权限、办公、通知、文件和流程等业务任务阅读。
- [前端文档](docs/前端/00-前端总览.md)：Web 管理后台的页面、路由、状态和请求层。
- [后端文档](docs/后端/10-后端模块/00-架构分层.md)：后端模块、接口、数据模型和配置说明。
- [流程设计器文档](docs/流程设计器/00-流程设计器.md)：BPMN 插件的使用、扩展和宿主集成。
- [开发指南](docs/开发指南/00-环境搭建.md)：开发环境、命令、检查和网站文档同步。
- [部署运维](docs/部署运维/00-容器部署.md)：容器、反向代理、证书和生产环境运维。
- [参考文档](docs/参考文档/00-版本与支持范围.md)：版本、接口、配置和常见问题索引。
- [参与贡献](CONTRIBUTING.md)：贡献流程、提交规范、问题反馈和合并请求要求。

## 克隆与启动

首次拉取需要同时初始化子模块：

```bash
git clone --recurse-submodules https://github.com/yangxj96/spectra-docs.git spectra
cd spectra
```

已经普通克隆过根仓库时，补齐子模块：

```bash
git submodule update --init --recursive
```

完整启动流程请阅读[快速开始](docs/01-快速开始.md)。开发环境的本机配置只从示例文件复制后填写，真实数据库密码、Redis 密码、S3 密钥、SSL 密码和安全主密钥不能提交到 Git。

## 当前开发基线

下列版本来自当前仓库的配置文件和子项目清单；它们描述的是当前开发基线，不代表已经发布的兼容承诺。

| 组件 | 当前基线 |
|---|---|
| Java | 25 |
| Spring Boot | 4.1.0 |
| Maven | 使用 `spectra-admin/mvnw` |
| Node.js | 24.14.0，由 `spectra-ui/mise.toml` 管理 |
| pnpm | 11.0.9，由 `spectra-ui/mise.toml` 管理 |
| PostgreSQL | 18 |
| Redis | 当前后端配置要求密码认证 |
| 流程设计器插件 | `@yangxj96/logicflow-plugin-flowable` 0.1.2 |
| API 契约 | 1.0.0 |

根工作区当前没有独立发布版本；后端、Web 和流程设计器的版本信息以各子项目的构建文件和发布记录为准。

## 默认地址

| 服务 | 默认地址 |
|---|---|
| 后端 API | `https://127.0.0.1:4004/api` |
| Web 管理后台 | `https://localhost:5173` |
| PostgreSQL | `127.0.0.1:5432` |
| Redis | `127.0.0.1:6379` |

后端开发模板默认启用本地 HTTPS。Web 管理后台的 `VITE_API_URL` 必须与后端协议和端口一致；在容器、局域网或远程服务环境中使用时，需要根据实际拓扑修改本机配置。

## 文档结构

| 目录 | 面向读者 | 内容 |
|---|---|---|
| `docs/00-项目总览.md` | 所有读者 | 项目定位、架构和能力地图 |
| `docs/01-快速开始.md` | 新用户、开发者 | 最小可运行路径 |
| `docs/使用指南/` | 业务使用者 | 按任务说明系统使用方式 |
| `docs/前端/` | 前端开发者 | Web 管理后台实现和开发约定 |
| `docs/后端/` | 后端开发者 | API、模块、数据、配置和后端规范 |
| `docs/流程设计器/` | 流程开发者 | BPMN 插件使用和扩展 |
| `docs/开发指南/` | 项目开发者 | 环境、命令、检查和文档同步 |
| `docs/部署运维/` | 部署和运维人员 | 容器、代理、证书和生产运维 |
| `docs/参考文档/` | 所有技术读者 | 版本、接口、配置和问题索引 |
| `docs/参与贡献/` | 贡献者和维护者 | 贡献、提交、Issue 和 Pull Request |
| `docs/AI速查/` | Agent 辅助 | 源码上下文速查，不发布到网站 |

## 质量检查

修改代码或文档后，在根目录运行：

```bash
./scripts/check-docs.sh
```

源文档同步到网站前先运行 Preview；确认生成范围和博客差异无误后再 Apply：

```bash
./scripts/sync-website-docs.sh \
  --website-root /home/devops00/workspace/yangxj96-website \
  --mode Preview
```

网站仓库的构建命令为：

```bash
pnpm --dir /home/devops00/workspace/yangxj96-website run docs:build
```

## 许可证与安全

三个代码子项目均以 Apache License 2.0 发布，详情见各子项目中的 `LICENSE` 文件。根工作区的文档和脚本遵循仓库发布说明；使用、修改和分发前请同时查看对应子项目许可证及第三方依赖许可证。

- [贡献指南](CONTRIBUTING.md)
- [行为准则](CODE_OF_CONDUCT.md)
- [安全问题报告](SECURITY.md)
- [变更记录](CHANGELOG.md)

安全问题不要在公开 Issue 中披露凭据、密钥、可利用细节或生产环境信息，请按 [SECURITY.md](SECURITY.md) 的方式报告。

## AI速查的发布边界

`docs/AI速查/` 是源码仓库内部使用的 Agent 上下文资料，不属于对外项目文档，也不会通过网站同步脚本发布到网站。对外阅读请从项目总览、快速开始、使用指南或对应技术域入口开始。
