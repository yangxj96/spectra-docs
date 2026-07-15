---
tags:
  - moc
  - backend
---

# 后端知识地图

> spectra-admin — Java 25 + Spring Boot 4 + PostgreSQL + Redis

## 架构

| 文档 | 说明 |
|---|---|
| [[10-架构分层]] | Maven 多模块架构、模块依赖关系 |
| [[15-spectra-core模块]] | 核心模块详情 |
| [[10-项目总览]] | 系统架构图、技术栈、端口 |

## 核心业务

| 模块 | 文档 | 说明 |
|---|---|---|
| 认证安全 | [[20-用户与权限]] | Account / User / Role / Authority / Permission |
| 数据权限 | [[25-数据权限设计]] | @DataScope 二维数据过滤 |
| 系统管理 | [[30-系统管理]] | Department / Region / Dict / Menu / Config / Log |
| OA 办公 | [[35-OA模块]] | 资产 / 考勤 / 日历 / 通讯录 / 合同 / 文档 / 会议 / 公告 / 报表 |
| 文件上传 | [[40-文件上传]] | 分片上传、本地存储、S3 |
| 工作流 | [[45-工作流模块]] | Flowable 流程引擎集成 |
| AI | [[50-AI模块]] | LangChain4j + RAG 检索增强生成 |

## 基础设施

| 文档 | 说明 |
|---|---|
| [[60-基础设施]] | Redis / Jackson / MyBatis-Plus / Cache / Security |
| [[55-接口加解密方案]] | RSA + AES-GCM 接口数据加密（含密钥管理） |
| [[40-SSL证书配置]] | 本地开发 SSL 证书生成 |

## API

| 文档 | 说明 |
|---|---|
| [[90-API总览]] | 全部 30 个 Controller 端点速查 |

## 部署运维

| 文档 | 说明 |
|---|---|
| [[10-Docker部署]] | Docker 构建与部署 |
| [[20-Nginx配置]] | Nginx 反向代理配置 |
| [[30-DockerCompose]] | 容器编排配置 |

## 常用操作

| 场景 | 入口 |
|---|---|
| 新增接口 | [[90-API总览]] → [[10-架构分层]] → [[40-数据库命名规范]] |
| 新增实体 | [[20-实体清单]] → [[30-MapStruct命名规范]] → [[10-ER图]] |
| 配置加解密 | [[55-接口加解密方案]] → sys_config 表 → CryptoController |
| 权限控制 | [[20-用户与权限]] → @PreAuthorize → Authority |

## 相关

- [[HOME]] — 知识库首页
- [[10-知识图谱/00-MOC-知识图谱]] — AI 速查知识图谱
