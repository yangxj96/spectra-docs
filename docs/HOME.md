---
tags:
  - entry
  - home
---

# Spectra 知识库

> 光谱平台 — 一个后端 API 服务两个前端客户端的全栈系统。

## 从这里开始

| 文档 | 说明 |
|---|---|
| [[00-项目总览]] | 系统架构、技术栈、目录结构、端口 |
| [[10-环境搭建]] | JDK / Node / pnpm / 数据库 安装配置 |
| [[20-常见命令]] | Maven / npm / pnpm 常用命令速查 |

## 后端开发

[[MOC-后端]]

- [[10-架构分层]] — Maven 多模块架构设计
- [[20-用户与权限]] — Account / User / Role / Authority / Permission
- [[30-系统管理]] — Department / Region / Dict / Menu / Config / Log
- [[85-接口加解密方案]] — RSA + AES-GCM 接口数据加密
- [[90-API总览]] — 全部 REST API 端点速查表

## 前端开发

[[20-前端/00-前端总览]]

- [[10-spectra-ui]] — Web 管理后台（Vue 3 + Element Plus）
- [[20-spectra-app]] — 移动端 / 小程序（Vue 3 + uni-app）

## 数据模型

- [[10-ER图]] — 实体关系总览
- [[20-实体清单]] — 25 个 Entity 完整字段字典
- [[30-数据库随笔]] — PostgreSQL 实用备忘（UUID v7 / pg_dump）

## 规范与参考

| 文档 | 说明 |
|---|---|
| [[10-Git提交规范]] | Conventional Commits 完整规范 |
| [[20-前端命名规范]] | kebab-case / PascalCase 命名约定 |
| [[30-MapStruct命名规范]] | Converter 命名与方法约定 |
| [[40-数据库命名规范]] | 表 / 字段 / 索引命名规范 |
| [[50-Redis使用规范]] | Key 设计 / TTL / 缓存策略 |

## 按任务查找

| 任务 | 推荐入口 |
|---|---|
| 新增后端接口 | [[90-API总览]] → [[10-架构分层]] |
| 新增前端页面 | [[10-spectra-ui]] → [[20-前端命名规范]] |
| 修改数据库 | [[10-ER图]] → [[20-实体清单]] → [[40-数据库命名规范]] |
| 配置加解密 | [[85-接口加解密方案]] |
| 部署上线 | [[12-Docker部署]] |
| AI 集成 | [[70-AI模块]] |
