---
tags:
  - frontend
  - bpmn
  - elements
---

# BPMN 元素与节点模型

> 当前实际注册清单来自 `src/core/constants.ts`、`src/elements/index.ts` 和 `src/panel/dnd/index.ts`。导入兼容标签另见 [[06-BPMN导入导出]]。

## 实际注册矩阵

| 分类 | 中文名称 | LogicFlow 类型 | 基类/特点 |
|---|---|---|---|
| 事件 | 开始事件 | `bpmn:startEvent` | `CircleNodeModel`，禁止入线，默认半径 26 |
| 事件 | 结束事件 | `bpmn:endEvent` | `CircleNodeModel`，禁止出线 |
| 事件 | 中间捕获事件 | `bpmn:intermediateCatchEvent` | `CircleNodeModel` |
| 事件 | 中间抛出事件 | `bpmn:intermediateThrowEvent` | `CircleNodeModel` |
| 事件 | 边界事件 | `bpmn:boundaryEvent` | `CircleNodeModel`，用于附着活动 |
| 任务 | 接收任务 | `bpmn:receiveTask` | `TaskBaseModel`，矩形任务 |
| 任务 | 脚本任务 | `bpmn:scriptTask` | `TaskBaseModel`，矩形任务 |
| 任务 | 服务任务 | `bpmn:serviceTask` | `TaskBaseModel`，矩形任务 |
| 任务 | 用户任务 | `bpmn:userTask` | `TaskBaseModel`，矩形任务 |
| 网关 | 排他网关 | `bpmn:exclusiveGateway` | `GatewayBaseModel`，菱形 + X |
| 网关 | 包容网关 | `bpmn:inclusiveGateway` | `GatewayBaseModel`，菱形 + 圆 |
| 网关 | 并行网关 | `bpmn:parallelGateway` | `GatewayBaseModel`，菱形 + + |
| 子流程 | 嵌入式子流程 | `bpmn:subProcess` | `DynamicGroupNodeModel`，可缩放容器 |
| 子流程 | 调用活动 | `bpmn:callActivity` | 矩形调用节点 |
| 连线 | 顺序流 | `bpmn:sequenceFlow` | `PolylineEdgeModel`，默认边类型 |

总计为 5 个事件、4 个任务、3 个网关、2 个子流程/调用活动和 1 个顺序流。当前没有原生注册手工任务、业务规则任务、事件网关、Pool、Lane 或 Message Flow。

## 任务节点

`TaskBaseModel` 统一设置宽 120、高 70、圆角 8、不可缩放，并从 `NODE_BEHAVIORS` 应用入线/出线规则。`TaskBaseView` 将节点绘制为蓝色头部和白色正文：

- 头部显示节点类型文本和节点图标。
- 正文优先显示 `properties.form.name`，其次显示 `properties.name`，最后使用 LogicFlow `text.value`。
- 修改属性面板的 `name` 会立即调用 `lf.updateText()`，因此画布标题和 XML 名称保持同步。

## 网关节点

`GatewayBaseModel` 继承 `DiamondNodeModel`，关闭缩放并应用连接规则；`GatewayBaseView` 按选中状态绘制蓝色菱形和子类内部符号。网关的条件和默认路径字段属于 Schema/导出层，而不是单独的网关运行时引擎。

## 子流程容器

`SubProcessModel` 继承 `DynamicGroupNodeModel`，默认宽 200、高 160，可缩放并允许容纳子节点。插件初始化 `DynamicGroup` 扩展时将 `cascadeDeleteChildren` 设为 `false`，并由子流程模型恢复缩放手柄和锚点样式。

`SubProcessView` 在折叠状态隐藏缩放控件。`expandedSubProcess` 不是独立模型，导入时映射为 `bpmn:subProcess`。

## DND 面板分组

`DND_ITEMS` 的用户可拖拽清单为：

| 分组 | 条目 |
|---|---|
| 事件 | 开始、结束、中间捕获、中间抛出、边界 |
| 任务 | 接收、脚本、服务、用户 |
| 网关 | 排他、包容、并行 |
| 子流程 | 嵌入式子流程、调用活动 |

拖拽时文本作为 LogicFlow 节点文本初始值，节点 Model 再根据 Schema 建立 `properties.form`。

## ID 和显示名称

默认 ID 使用 `process-`、`node-` 和 `edge-` 前缀加 UUID，保证不会以数字开头。Spectra 宿主还通过 LogicFlow `idGenerator` 使用 `crypto.randomUUID()`，顺序流前缀为 `edge`，其他节点前缀为 `node`。导出时会再次规范化旧画布 ID，并同步修正边的 source/target 引用。

不要把显示名称当成稳定 ID；流程 Key、用户 ID、表单编码等业务引用应存入对应 BPMN 属性字段。
