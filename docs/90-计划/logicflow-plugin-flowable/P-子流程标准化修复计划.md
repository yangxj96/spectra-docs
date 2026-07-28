---
tags:
  - plan
  - logicflow
  - completed
---

# P-子流程标准化修复计划

## 状态

**已完成** - 2026-07-15 执行完毕

## 问题背景

当前逻辑流程图插件中，子流程组件的实现不符合 BPMN 2.0 标准：

1. **`EXPANDED_SUB_PROCESS` 类型不存在于 BPMN 2.0 规范**
   - BPMN 2.0 只定义 `<subProcess>` 元素
   - 展开/折叠是视图层面的行为，不是类型区别
   - 当前实现将"展开子流程"作为独立类型 `bpmn:expandedSubProcess`

2. **导入/导出兼容性问题**
   - 导入标准 BPMN 文件时，`expandedSubProcess` 类型无法正确识别
   - 导出时生成非标准的 `<expandedSubProcess>` 标签

3. **视觉样式问题**
   - SubProcess 使用 `DynamicGroupNode`（无明确边框）
   - BPMN 标准要求加粗边框（与普通任务区分）

4. **Schema 属性不完整**
   - SubProcess 缺少 `flowable:exclusive`、`flowable:multiInstanceType` 等属性

## 修复目标

1. 删除不符合 BPMN 2.0 标准的 `EXPANDED_SUB_PROCESS` 类型
2. 统一使用 `SUB_PROCESS` 类型
3. 保持旧数据兼容（通过导入映射自动转换）
4. 改进 SubProcess 视觉样式
5. 补充 SubProcess Schema 属性

## 详细实现步骤

### 阶段一：删除 EXPANDED_SUB_PROCESS 类型

#### 1.1 修改 `src/core/constants.ts`

**操作**：
- 删除 `EXPANDED_SUB_PROCESS: bpmn("expandedSubProcess")` 常量
- 删除 `NODE_TYPE_NAMES` 中的 `[NODE_TYPES.EXPANDED_SUB_PROCESS]: "展开子流程"`
- 删除 `NODE_ICONS` 中的 `EXPANDED_SUB_PROCESS` 图标定义

#### 1.2 删除 Schema 文件

**操作**：
- 删除 `src/features/schema/nodes/subprocess/expanded-sub-process.ts`
- 修改 `src/features/schema/index.ts`：
  - 删除 `ExpandedSubProcessSchema` 的导入和导出
  - 删除 `schemaRegistry` 中的 `[NODE_TYPES.EXPANDED_SUB_PROCESS]: ExpandedSubProcessSchema`

#### 1.3 删除节点实现文件

**操作**：
- 删除 `src/elements/nodes/subprocess/expanded-sub-process/` 整个目录

#### 1.4 修改行为规则

**操作**：
- 修改 `src/features/behaviors/index.ts`：
  - 删除 `NODE_BEHAVIORS` 中的 `EXPANDED_SUB_PROCESS` 条目

### 阶段二：修复导入映射

#### 2.1 修改 `src/features/import/types.ts`

**操作**：
- 将 `expandedSubProcess: "bpmn:expandedSubProcess"` 改为 `expandedSubProcess: "bpmn:subProcess"`

**效果**：导入包含 `<expandedSubProcess>` 的旧 BPMN 文件时，会自动映射为 `SUB_PROCESS` 类型。

### 阶段三：修复导出映射

#### 3.1 修改 `src/features/export/types.ts`

**操作**：
- 删除 `"bpmn:expandedSubProcess": "expandedSubProcess"` 映射

**效果**：导出时所有子流程统一生成 `<subProcess>` 标签。

### 阶段四：改进 SubProcess 视觉样式

#### 4.1 修改 `src/elements/nodes/subprocess/sub-process/view.ts`

**操作**：
- 将 `DynamicGroupNode` 改为 `RectNode` 或自定义带边框的 Group
- 添加 BPMN 标准的加粗边框样式

### 阶段五：补充 Schema 属性

#### 5.1 修改 `src/features/schema/nodes/subprocess/sub-process.ts`

**操作**：
- 添加 `flowable:exclusive` 属性
- 添加 `flowable:multiInstanceType` 属性
- 添加 `flowable:sequential` 属性

## 验证方案

1. **导入测试**：导入包含 `<expandedSubProcess>` 的旧 BPMN 文件，验证自动转换
2. **导出测试**：导出流程图，验证生成标准 `<subProcess>` 标签
3. **视觉测试**：检查 SubProcess 节点显示加粗边框
4. **属性测试**：检查属性面板显示完整 Schema 属性

## 影响范围

- `src/core/constants.ts`
- `src/features/schema/index.ts`
- `src/features/schema/nodes/subprocess/expanded-sub-process.ts`（删除）
- `src/features/behaviors/index.ts`
- `src/features/import/types.ts`
- `src/features/export/types.ts`
- `src/elements/nodes/subprocess/sub-process/view.ts`
- `src/features/schema/nodes/subprocess/sub-process.ts`
- `src/elements/nodes/subprocess/expanded-sub-process/`（删除）

## 相关

- [[30-流程建模插件]] — 流程建模插件文档
