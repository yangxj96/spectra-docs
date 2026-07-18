---
tags:
  - plan
  - frontend
  - spectra-ui
  - bugfix
---

# P-字典数据删除功能修复计划

## 状态

**已完成**

> 完成时间：2026-07-19

## 问题背景

前端 `/system/dict` 页面的字典数据（DictItem）删除按钮点击无反应。根本原因：删除按钮已渲染且有权限控制（`v-owner="'DICT:DELETE'"`），但**未绑定 `@click` 事件**。

后端删除接口已完整实现（Controller + Service），API 层也已定义 `deleteDataById(id)` 方法，唯独前端事件绑定缺失。

## 修复目标

- 字典数据删除按钮点击后弹出确认框
- 确认后调用删除 API 并刷新列表

## 详细实现步骤

### 阶段一：添加删除处理函数

#### 1.1 新增 handleDictDataDelete 函数

**操作**：在 script 部分的 `handleDialogClose` 函数之后添加删除处理函数

**文件**：
- `src/views/System/Dict/index.vue` — 新增 `handleDictDataDelete` 函数

**实现代码**：
```typescript
// 字典数据删除
const handleDictDataDelete = (row: DictItem) => {
    MessageUtils.box.confirm(`是否要删除字典项[${row.label}]`, "提示").then(async () => {
        try {
            await DictApi.deleteDataById(row.id);
            MessageUtils.success("删除成功");
        } finally {
            await handleGetDictData();
        }
    });
};
```

### 阶段二：绑定删除按钮事件

#### 2.1 绑定 @click 事件

**操作**：给删除按钮添加点击事件处理

**文件**：
- `src/views/System/Dict/index.vue` — 第174行删除按钮添加 `@click`

**修改前**：
```vue
<el-button v-owner="'DICT:DELETE'" link type="primary">删除</el-button>
```

**修改后**：
```vue
<el-button v-owner="'DICT:DELETE'" link type="primary" @click="handleDictDataDelete(scope.row)">删除</el-button>
```

## 验证方案

1. 启动 spectra-ui 开发服务器
2. 访问 `/system/dict`，选择一个非内置字典组
3. 点击字典项的删除按钮，确认弹窗出现
4. 点击确认，验证删除成功且列表刷新
5. 运行 `pnpm run type-check` 确认无类型错误

## 影响范围

### 直接影响的文件（1 个）

| 文件 | 修改类型 |
|---|---|
| `src/views/System/Dict/index.vue` | 新增删除函数 + 绑定事件 |

## 相关

- [[30-系统管理]] — 字典管理模块说明
- [[10-spectra-ui]] — 前端开发规范
