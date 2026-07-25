# npm 发布准备 实现计划

> **面向 AI 代理的工作者：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实现此计划。步骤使用复选框（`- [ ]`）语法来跟踪进度。

**目标：** 修复 `@yangxj96/logicflow-plugin-flowable` 的包配置、类型、文档问题，使其达到 npm 发布标准。

**架构：** 纯配置/文档修复，不涉及业务逻辑变更。修改范围：package.json、源码类型签名、README、exports 映射。CSS 导出路径从 `./dist/index.css` 迁移到 `./style.css`（保留旧路径兼容）。

**技术栈：** npm pack 验证、tsup 构建、TypeScript 类型

---

## 文件结构

| 文件 | 操作 | 职责 |
|---|---|---|
| `logicflow-plugin-flowable/package.json` | 修改 | 修复 files/peerDeps/devDeps/exports/sideEffects/engines |
| `logicflow-plugin-flowable/src/features/import/parser.ts` | 修改 | `fromBpmnXml` 参数类型 `any` → `LogicFlow` |
| `logicflow-plugin-flowable/src/index.ts` | 修改 | 版权头版本号更新 |
| `logicflow-plugin-flowable/README.md` | 修改 | 添加安装、使用示例、CSS 引入说明 |
| `spectra-ui/src/views/System/Workflow/components/WorkflowDesigner/index.vue` | 修改 | CSS 导入路径更新 |

---

### 任务 1：修复 package.json 配置

**文件：**
- 修改：`logicflow-plugin-flowable/package.json`

- [ ] **步骤 1：修复 `files` 字段——精确列出产物，排除 sourcemap**

将 `files` 从：

```json
"files": [
    "dist",
    "types",
    "README.md",
    "LICENSE"
]
```

改为：

```json
"files": [
    "dist/index.js",
    "dist/index.cjs",
    "dist/index.d.ts",
    "dist/index.d.cts",
    "dist/index.css",
    "README.md",
    "LICENSE"
]
```

这同时修复了两个问题：移除不存在的 `types` 目录、排除 `.map` 文件（~413kB）。

- [ ] **步骤 2：移除 `preact` peerDependency 和 devDependency**

`preact` 是 `@logicflow/core` 的直接依赖（非 peer），插件源码未直接 import preact。

从 `peerDependencies` 中删除：
```json
"preact": "^10.17.1"
```

从 `devDependencies` 中删除：
```json
"preact": "^10.17.1"
```

- [ ] **步骤 3：移除未使用的 `xml-formatter` devDependency**

源码中无任何 `xml-formatter` 引用，从 `devDependencies` 中删除：
```json
"xml-formatter": "^3.7.0"
```

- [ ] **步骤 4：添加 `sideEffects` 字段**

在 `package.json` 顶层（`"type": "module"` 之后）添加：

```json
"sideEffects": [
    "*.css"
]
```

确保 webpack/Rollup tree-shaking 不会丢弃样式文件。

- [ ] **步骤 5：添加 `engines` 字段**

```json
"engines": {
    "node": ">=18"
}
```

- [ ] **步骤 6：更新 `exports`——添加 `./style.css` 语义化路径**

将 `exports` 从：

```json
"exports": {
    ".": {
        "types": "./dist/index.d.ts",
        "import": "./dist/index.js",
        "require": "./dist/index.cjs"
    },
    "./dist/index.css": "./dist/index.css"
}
```

改为：

```json
"exports": {
    ".": {
        "types": "./dist/index.d.ts",
        "import": "./dist/index.js",
        "require": "./dist/index.cjs"
    },
    "./style.css": "./dist/index.css",
    "./dist/index.css": "./dist/index.css"
}
```

`./style.css` 为推荐路径，`./dist/index.css` 保留向后兼容。

- [ ] **步骤 7：验证 package.json 合法性**

运行：`node -e "JSON.parse(require('fs').readFileSync('package.json','utf8')); console.log('OK')"`
预期：输出 `OK`

- [ ] **步骤 8：Commit**

```bash
git add package.json
git commit -m "fix: 修复 package.json 发布配置（files/peerDeps/exports/sideEffects/engines）"
```

---

### 任务 2：修复 `fromBpmnXml` 类型签名

**文件：**
- 修改：`logicflow-plugin-flowable/src/features/import/parser.ts:1,13`

- [ ] **步骤 1：添加类型导入并修改函数签名**

在 `parser.ts` 顶部（第 1 行之前）添加：

```typescript
import type LogicFlow from "@logicflow/core";
```

将第 13 行：

```typescript
export function fromBpmnXml(xmlString: string, lf: any): ImportResult {
```

改为：

```typescript
export function fromBpmnXml(xmlString: string, lf: LogicFlow): ImportResult {
```

依据：`getProcessContext(lf)` 已接受 `LogicFlow` 类型（见 `context/process.ts:24`），`lf.render()` 是 LogicFlow 的公共方法。

- [ ] **步骤 2：构建验证类型正确**

运行：`pnpm run build`
预期：构建成功，无类型错误

- [ ] **步骤 3：检查 dist/index.d.ts 中 `fromBpmnXml` 签名**

运行：`Select-String -Path dist/index.d.ts -Pattern "fromBpmnXml"`
预期：输出包含 `lf: LogicFlowCore`（不再是 `any`）

- [ ] **步骤 4：Commit**

```bash
git add src/features/import/parser.ts
git commit -m "fix: fromBpmnXml 参数类型 any → LogicFlow"
```

---

### 任务 3：更新 spectra-ui CSS 导入路径

**文件：**
- 修改：`spectra-ui/src/views/System/Workflow/components/WorkflowDesigner/index.vue:7`

- [ ] **步骤 1：更新 CSS 导入**

将第 7 行：

```typescript
import "@yangxj96/logicflow-plugin-flowable/dist/index.css";
```

改为：

```typescript
import "@yangxj96/logicflow-plugin-flowable/style.css";
```

- [ ] **步骤 2：Commit**

```bash
git add spectra-ui/src/views/System/Workflow/components/WorkflowDesigner/index.vue
git commit -m "refactor: 更新 logicflow-plugin-flowable CSS 导入路径为 ./style.css"
```

---

### 任务 4：完善 README

**文件：**
- 修改：`logicflow-plugin-flowable/README.md`

- [ ] **步骤 1：在"支持的 BPMN 元素"章节之前插入安装和使用章节**

在 `## 支持的 BPMN 元素` 之前插入以下内容：

```markdown
## 安装

```bash
npm install @yangxj96/logicflow-plugin-flowable
# 或
pnpm add @yangxj96/logicflow-plugin-flowable
```

### 对等依赖

本插件需要以下对等依赖，请确保项目中已安装：

| 包 | 版本 |
|---|---|
| `@logicflow/core` | ^2.1.11 |
| `@logicflow/extension` | ^2.1.11 |
| `element-plus` | ^2.13.5 |
| `vue` | ^3.5.30 |

## 快速开始

```typescript
import LogicFlow from "@logicflow/core";
import Flowable from "@yangxj96/logicflow-plugin-flowable";
import "@logicflow/core/dist/index.css";
import "@yangxj96/logicflow-plugin-flowable/style.css";

const lf = new LogicFlow({
    container: document.querySelector("#graph")!,
    plugins: [Flowable.Plugin],
    pluginsOptions: {
        [Flowable.Plugin.pluginName]: {
            panel: {
                dnd: document.querySelector("#dnd-panel")!,
                property: document.querySelector("#property-panel")!
            }
        }
    }
});

lf.render();

// 导出 BPMN XML
const xml = Flowable.toBpmnXml(lf);

// 导入 BPMN XML
const result = Flowable.fromBpmnXml(xmlString, lf);
```
```

- [ ] **步骤 2：Commit**

```bash
git add README.md
git commit -m "docs: README 添加安装说明和使用示例"
```

---

### 任务 5：版本升级 + 最终验证

**文件：**
- 修改：`logicflow-plugin-flowable/package.json:3`（version 字段）
- 修改：`logicflow-plugin-flowable/src/index.ts:2`（版权头版本号）

- [ ] **步骤 1：升级版本到 0.1.0**

`package.json` 第 3 行：`"version": "0.0.5"` → `"version": "0.1.0"`

`src/index.ts` 第 2 行：`logicflow-plugin-flowable v0.0.5` → `logicflow-plugin-flowable v0.1.0`

- [ ] **步骤 2：运行 format 检查**

运行：`pnpm run format:check`
预期：`All matched files use Prettier code style!`

- [ ] **步骤 3：运行构建**

运行：`pnpm run build`
预期：ESM + CJS + DTS 构建成功

- [ ] **步骤 4：npm pack 干跑验证包内容**

运行：`npm pack --dry-run`
预期：
- 总文件数 8（无 `.map` 文件）
- 包含：`dist/index.js`、`dist/index.cjs`、`dist/index.d.ts`、`dist/index.d.cts`、`dist/index.css`、`README.md`、`LICENSE`、`package.json`
- 包大小约 55-60kB（从 118kB 下降）

- [ ] **步骤 5：验证 exports 解析**

运行：`node -e "const p = require('./package.json'); console.log(Object.keys(p.exports))"`
预期：`[ '.', './style.css', './dist/index.css' ]`

- [ ] **步骤 6：Commit**

```bash
git add package.json src/index.ts
git commit -m "chore: bump version to 0.1.0"
```

---

## 验证清单

完成所有任务后，逐项确认：

- [ ] `npm pack --dry-run` 无 `.map` 文件，体积 ~55kB
- [ ] `dist/index.d.ts` 中 `fromBpmnXml` 参数为 `LogicFlowCore`（非 `any`）
- [ ] `package.json` 无 `preact` peerDependency
- [ ] `package.json` 无 `xml-formatter` devDependency
- [ ] `package.json` 有 `sideEffects`、`engines` 字段
- [ ] `exports` 包含 `./style.css` 和 `./dist/index.css`
- [ ] README 包含安装命令 + 使用示例 + CSS 引入
- [ ] spectra-ui CSS 导入路径已更新为 `./style.css`
- [ ] 构建成功，format 通过
