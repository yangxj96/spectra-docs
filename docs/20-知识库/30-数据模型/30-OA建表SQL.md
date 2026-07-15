---
tags:
  - database
  - sql
  - oa
---

# OA 建表 SQL

> spectra-admin/document/db/oa/ 中的 SQL 文件整合。

## 文件说明

| 文件 | 用途 |
|---|---|
| `01-create-tables.sql` | OA 模块全部建表语句 |
| `02-insert-menus.sql` | OA 模块菜单数据初始化 |

## OA 表结构

所有 OA 表位于 `spectra_core` schema 下，继承 BaseEntity 公共字段：

```sql
-- 公共字段（所有 OA 表均包含）
id          UUID PRIMARY KEY,
created_by  UUID,
created_at  TIMESTAMP(6) WITH TIME ZONE NOT NULL,
updated_by  UUID,
updated_at  TIMESTAMP(6) WITH TIME ZONE NOT NULL,
deleted     TIMESTAMP(6) WITH TIME ZONE,
version     BIGINT DEFAULT 0,
department_id UUID
```

## OA 表清单

| 表名 | 说明 |
|---|---|
| `oa_asset` | 资产 |
| `oa_attendance` | 考勤 |
| `oa_calendar` | 日历 |
| `oa_contact` | 通讯录 |
| `oa_contract` | 合同 |
| `oa_document` | 文档 |
| `oa_meeting` | 会议 |
| `oa_meeting_participant` | 参会人员 |
| `oa_meeting_record` | 会议纪要 |
| `oa_notice` | 公告通知 |
| `oa_report` | 报表 |

## 菜单初始化

`02-insert-menus.sql` 通过 CTE 生成父菜单 UUID，插入 OA 办公一级菜单和 9 个子模块二级菜单。

执行顺序：先执行 `01-create-tables.sql` 建表，再执行 `02-insert-menus.sql` 插入菜单。

## 相关

- [[35-OA模块]] — OA 模块功能说明
- [[03-实体字典]] — 实体字段速查
- [[40-数据库命名规范]] — 表/字段命名规范
