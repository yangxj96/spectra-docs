---
tags:
  - frontend
  - bpmn
  - schema
---

# 属性 Schema 与编辑面板

> 对应源码：`src/features/schema/`、`src/panel/property/` 和 `src/core/domain-types.ts`。

## Schema 模型

每个属性由 `Property` 描述：

| 字段 | 说明 |
|---|---|
| `field` | LogicFlow form 字段名，也是导出时的 BPMN 属性或子元素名 |
| `label` | 面板展示名称 |
| `default` | 新节点或缺失字段的默认值，当前以字符串保存 |
| `type` | `inline` 输出为 BPMN 属性，`children` 输出为 XML 子元素 |
| `component` | `string`、`textarea`、`number`、`boolean`、`select`、`expression` 或 `picker` |
| `rules` | 必填、长度、正则和提示定义；当前面板主要使用必填提示 |
| `options` | `select` 的选项 |
| `cdata` | 脚本和表达式等内容是否使用 CDATA |
| `pickerType` / `pickerMultiple` | 宿主 Picker 类型及单多选设置 |

Schema 注册表 `getSchemaByType(type)` 通过 BPMN 类型返回属性数组。元素初始化和 XML 导入都会使用同一份 Schema，避免面板字段和 XML 字段分叉。

## 基础和流程属性

所有节点和边都继承 `BaseSchema`：`id`、`name`。流程级 `ProcessSchema` 另外提供：

| 字段 | XML 形态 | 控件 |
|---|---|---|
| `id` | `<process id>` | 文本，必填 |
| `name` | `<process name>` | 文本，必填 |
| `category` | `definitions.targetNamespace` | 文本 |
| `documentation` | `<documentation>` | 多行文本 |
| `isExecutable` | `isExecutable` | 布尔开关 |

流程属性保存在插件的流程上下文中，不放在某个节点的 `properties.form`。

## 节点属性清单

| 元素 | 主要字段 |
|---|---|
| 开始事件 | `flowable:initiator`、`flowable:formKey`、`document` |
| 结束事件 | `terminateAll`、`document` |
| 中间捕获/抛出事件 | `timerEventDefinition`、`messageEventDefinition`、`signalEventDefinition`、`document` |
| 边界事件 | `attachedToRef`、`cancelActivity`、定时/消息/信号/错误事件定义、`document` |
| 用户任务 | `flowable:assignee`、`flowable:candidateUsers`、`flowable:candidateGroups`、`flowable:formKey`、`flowable:dueDate`、`flowable:priority`、`flowable:category`、`flowable:async`、`flowable:skipExpression`、`document` |
| 服务任务 | `flowable:class`、`flowable:delegateExpression`、`flowable:expression`、`flowable:resultVariable`、`flowable:async`、`flowable:skipExpression`、`document` |
| 脚本任务 | `scriptFormat`、`script`、`flowable:resultVariable`、`flowable:async`、`document` |
| 接收任务 | `flowable:messageRef`、`flowable:async`、`document` |
| 排他网关 | `default`、`document` |
| 包容网关 | `default`、`document` |
| 并行网关 | `document` |
| 嵌入式子流程 | `flowable:async`、`flowable:exclusive`、`flowable:multiInstanceType`、`document` |
| 调用活动 | `calledElement`、`flowable:calledElementType`、`flowable:async`、`document` |
| 顺序流 | `sourceRef`、`targetRef`、`conditionExpression`、`skipExpression`、`document` |

其中 `flowable:*` 字段输出到 Flowable 命名空间；`document` 在导入导出时映射为 `documentation`。

## 面板状态和事件

属性面板 `usePropertyPanel()` 维护：

- `mode`：`process`、`node`、`edge`。
- `process`：流程上下文的响应式快照。
- `currentNode` / `currentEdge`：当前选中元素。
- `formKey`：切换对象时强制重建 Element Plus 表单。
- `pickers`：宿主声明的 Picker 类型。

事件处理规则：

| LogicFlow 事件 | 面板动作 |
|---|---|
| `node:click` | 切换到节点模式，补全 Schema 默认 form |
| `edge:click` | 切换到连线模式，补全 Schema 默认 form |
| `blank:click` | 切换到流程模式 |
| `node:add` / `node:dnd-add` | 选中新节点并初始化属性 |
| `edge:add` | 选中新连线并初始化属性 |
| `node:delete` / `edge:delete` | 删除当前对象时重置到流程模式 |
| `process:change` | 从真实流程上下文刷新流程表单快照 |

首次选中元素时，`ensureAndSyncForm()` 从 Schema 建立默认值，并调用 `lf.setProperties()` 持久化到真实 Model。编辑节点或边时使用 200ms 防抖再次写回 `properties.form`；流程字段则直接同步到流程上下文。

## 控件行为

- `string`：可清空单行文本。
- `textarea`：三行多行输入。
- `number`：Element Plus 数字输入。
- `boolean`：开关，最终写入字符串形式的布尔值。
- `select`：根据 `options` 渲染下拉选项。
- `expression`：单行文本，提示支持表达式。
- `picker`：配置了宿主 Picker 时显示选择器，否则降级为普通输入框。

脚本、条件表达式和文档字段最终是否输出，由导出器根据字段名和 `cdata` 处理；面板本身不直接拼 XML。

## Picker 事件协议

```typescript
interface PickerRequestPayload {
  pickerType: "form" | "user" | "group" | "javaClass" | "process";
  field: string;
  currentValue: string;
  multiple: boolean;
  nodeId?: string;
  nodeType?: string;
  resolve: (value: string, label?: string) => void;
}
```

面板点击选择时通过 `lf.emit("property:picker", payload)` 委托给宿主。宿主回调 `resolve(value, label)` 后：

- `value` 写入真实 BPMN 字段。
- `label` 写入 `${field}Label`，仅用于展示，不导出为 BPMN 属性。
- 多选使用逗号分隔的 value 和 label，并支持逐项移除或全部清空。

## 增加属性的要求

1. 在对应 `features/schema/` 文件加入字段和默认值。
2. 判断字段是 `inline` 还是 `children`，需要特殊 XML 标签时同步导入导出逻辑。
3. 如果是表达式、脚本或 XML 特殊字符内容，设置 `cdata` 并验证转义。
4. 如果需要业务选择，新增 `PickerType`、宿主接入和回填标签处理。
5. 更新本页属性矩阵、插件 README 和宿主流程文档。
