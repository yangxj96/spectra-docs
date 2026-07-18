# spectra-ui-spec Skill

当修改、调整或创建 `spectra-ui/` 目录下的前端代码时，此 skill 会自动加载作为开发规范指南。

## 使用场景

- 编写 Vue 组件、API 模块、Pinia Store、Hook
- 处理 HTTP 请求、类型定义、路由配置
- 编写测试用例
- 创建新的业务模块

## 核心规范

1. **组件目录化**：所有组件必须使用 `组件名/index.vue` 结构，为子组件预留位置
2. **Vue 3.5+ 语法**：使用类型声明 + `withDefaults` 定义 Props，使用类型声明定义 Emits
3. **类型安全**：零容忍 `any`，使用 `import type` 导入类型
4. **统一代码风格**：遵循 Prettier 和 ESLint 规则

## 目录结构

```
src/components/{组件名}/
├── index.vue              # 组件主文件
└── SubComponent/          # 子组件（预留扩展）
    └── index.vue
```

```
src/views/{模块}/{页面名}/
├── index.vue              # 页面主文件
└── components/            # 页面专属子组件
    └── {子组件名}/
        └── index.vue
```

## 详细规则查询

完整规范请查阅 Obsidian 文档：

- `docs/20-前端/10-spectra-ui.md` - 前端开发规范

## 快速参考

### 命名规范

| 位置 | 命名风格 | 示例 |
|---|---|---|
| `src/` 顶层目录 | kebab-case | `api/`、`components/` |
| `src/views/` 目录 | PascalCase | `Dashboard/`、`System/` |
| Vue 组件 | `组件名/index.vue` | `DictSelect/index.vue` |
| API 模块 | kebab-case | `dict-api.ts` |

### Prettier 配置

| 项 | 值 |
|---|---|
| 缩进 | 4 空格 |
| 引号 | 双引号 |
| 分号 | 必须 |
| 行宽 | 120 字符 |

### ESLint 核心规则

| 规则 | 级别 |
|---|---|
| `no-explicit-any` | error |
| `consistent-type-imports` | error |
| `import/order` | error |
| `vue/block-order` | error |
