---
tags:
  - plan
  - frontend
  - spectra-ui
---

# P-前端规范性修复计划

## 状态

**待执行**

> 创建时间：2026-07-18

## 问题背景

根据新创建的 `spectra-ui-spec` 规范（Vue 3.5+ 最新语法），检测发现项目中存在 15 处不符合规范的代码。主要问题集中在：

1. 部分目录命名不符合 PascalCase 规范
2. 组件 Props/Emits 使用了旧语法（运行时声明/数组声明）
3. 部分组件目录结构不完整

## 修复目标

- 所有目录命名符合 kebab-case/PascalCase 规范
- 所有 Vue 组件使用 Vue 3.5+ 最新语法（类型声明 Props/Emits）
- 所有公共组件使用 `组件名/index.vue` 结构

## 详细实现步骤

### 阶段一：Props/Emits 类型声明修复（高优先级）

#### 1.1 修复 defineProps 旧语法（2 处）

**操作**：将运行时声明改为类型声明 + withDefaults

**文件**：
- `src/components/ComponentsIcons/index.vue` — 将 `defineProps({ prefix: { type: String }, name: { type: String, required: true } })` 改为类型声明
- `src/components/PDFViewer/index.vue` — 将 `defineProps({ src: { type: String, required: true } })` 改为类型声明

#### 1.2 修复 defineEmits 旧语法（9 处）

**操作**：将数组声明改为类型声明

**文件**：
- `src/views/System/Configured/components/ConfiguredEdit/index.vue` — `defineEmits(["close"])` → `defineEmits<{ close: [] }>()`
- `src/views/System/Dept/components/DeptEdit/index.vue` — `defineEmits(["close"])` → `defineEmits<{ close: [] }>()`
- `src/views/System/Dict/components/DictDataEdit/index.vue` — `defineEmits(["close"])` → `defineEmits<{ close: [] }>()`
- `src/views/System/Dict/components/DictGroupEdit/index.vue` — `defineEmits(["close"])` → `defineEmits<{ close: [] }>()`
- `src/views/System/Menu/components/MenuEdit/index.vue` — `defineEmits(["close"])` → `defineEmits<{ close: [] }>()`
- `src/views/System/RBAC/components/RoleEdit/index.vue` — `defineEmits(["close"])` → `defineEmits<{ close: [] }>()`
- `src/views/System/Region/components/RegionEdit/index.vue` — `defineEmits(["close"])` → `defineEmits<{ close: [] }>()`
- `src/views/System/Storage/components/FileUpload/index.vue` — `defineEmits(["close", "success"])` → `defineEmits<{ close: []; success: [] }>()`
- `src/views/System/User/components/UserEdit/index.vue` — `defineEmits(["close"])` → `defineEmits<{ close: [] }>()`

### 阶段二：目录命名修复（中优先级）

#### 2.1 修复 401/404 目录命名

**操作**：重命名目录以符合 PascalCase 规范

**文件**：
- `src/views/Common/401/` → `src/views/Common/NoAccess/`
- `src/views/Common/404/` → `src/views/Common/NotFound/`

**注意**：需要同步更新路由配置和所有引用这些组件的地方。

#### 2.2 修复 Login/config 目录命名

**操作**：重命名目录

**文件**：
- `src/views/Login/config/` → `src/views/Login/Config/`

### 阶段三：组件结构修复（低优先级）

#### 3.1 评估 Props 组件结构

**操作**：评估是否需要为 Props 组件添加 index.vue

**文件**：
- `src/components/Props/` — 当前目录下无 index.vue，仅有子目录 ChangePassword/、PersonalDetails/

**决策**：如果 Props 是一个容器组件（仅包含子组件），可能不需要 index.vue。需要评估后决定。

## 验证方案

1. **命名规范验证**：
   - 检查 `src/views/Common/` 下所有目录是否为 PascalCase
   - 检查 `src/views/Login/config/` 是否已重命名

2. **Props/Emits 验证**：
   - 运行 `pnpm run type-check` 确保类型检查通过
   - 运行 `pnpm run lint` 确保 ESLint 检查通过

3. **组件结构验证**：
   - 检查所有公共组件目录是否都包含 index.vue

4. **功能验证**：
   - 启动开发服务器 `pnpm start`
   - 手动测试受影响的页面（字典管理、菜单管理、用户管理等）

## 影响范围

### 直接影响的文件（15 个）

| 文件 | 修改类型 |
|---|---|
| `src/components/ComponentsIcons/index.vue` | Props 类型声明 |
| `src/components/PDFViewer/index.vue` | Props 类型声明 |
| `src/views/System/Configured/components/ConfiguredEdit/index.vue` | Emits 类型声明 |
| `src/views/System/Dept/components/DeptEdit/index.vue` | Emits 类型声明 |
| `src/views/System/Dict/components/DictDataEdit/index.vue` | Emits 类型声明 |
| `src/views/System/Dict/components/DictGroupEdit/index.vue` | Emits 类型声明 |
| `src/views/System/Menu/components/MenuEdit/index.vue` | Emits 类型声明 |
| `src/views/System/RBAC/components/RoleEdit/index.vue` | Emits 类型声明 |
| `src/views/System/Region/components/RegionEdit/index.vue` | Emits 类型声明 |
| `src/views/System/Storage/components/FileUpload/index.vue` | Emits 类型声明 |
| `src/views/System/User/components/UserEdit/index.vue` | Emits 类型声明 |
| `src/views/Common/401/` | 目录重命名 |
| `src/views/Common/404/` | 目录重命名 |
| `src/views/Login/config/` | 目录重命名 |
| `src/plugin/router/routes.ts` | 路由路径更新（401/404 重命名后） |

### 间接影响的文件

- 路由配置中引用 401/404 组件的地方
- 任何 import 这些组件的文件

## 相关

- [[20-前端/10-spectra-ui]] — 前端开发规范
- [[.opencode/skills/spectra/spectra-ui-spec/SKILL.md]] — 前端规范 Skill
