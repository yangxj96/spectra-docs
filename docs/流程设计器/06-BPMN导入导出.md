---
tags:
  - frontend
  - bpmn
  - xml
---

# BPMN 导入导出

> 对应源码：`src/features/import/parser.ts`、`src/features/import/types.ts`、`src/features/export/builder.ts` 和 `src/features/export/types.ts`。

## 公共 API

```typescript
const xml = Flowable.toBpmnXml(lf);
const result = Flowable.fromBpmnXml(xml, lf);
```

`toBpmnXml()` 返回 XML 字符串；`fromBpmnXml()` 会直接把解析结果渲染到传入的 LogicFlow 实例，并返回：

```typescript
interface ImportResult {
  success: boolean;
  message: string;
  processName?: string;
  nodes?: LogicFlow.NodeConfig[];
  edges?: LogicFlow.EdgeConfig[];
}
```

导入接口使用浏览器 `DOMParser`，应在浏览器环境调用；它不是服务端 XML 校验器，也不会替代 Flowable 部署校验。

## 导入处理流程

`fromBpmnXml()` 按以下顺序处理：

1. 预处理 XML 开始标签，去除重复属性并保留第一次出现的值。
2. 使用 `DOMParser` 解析 XML，检查 `parsererror`。
3. 检查根元素的 localName 是否为 `definitions`。
4. 查找第一个 `process` 元素；没有 process 或没有任何节点时返回失败。
5. 读取 process 的 `id`、`name` 和 `isExecutable`，写入流程上下文并发出 `process:change`。
6. 遍历 process 的直接子元素，按 XML 标签解析节点或顺序流。
7. 读取 BPMN DI 的 `BPMNShape` 和 `BPMNEdge`。
8. 有节点坐标时恢复位置，没有任何 DI shape 时执行基础网格布局。
9. 恢复连线 `pointsList`，再将首尾点对齐到 LogicFlow 实际锚点。
10. 调用 `lf.render({ nodes, edges })`，返回成功结果。

导入只遍历 process 的直接子元素；复杂嵌套子流程中的内部 BPMN 元素不会被递归转换为独立画布节点，使用前需确认业务 XML 结构。

## XML 标签兼容映射

| XML 标签 | 画布类型 | 说明 |
|---|---|---|
| `startEvent` | `bpmn:startEvent` | 原生支持 |
| `endEvent` | `bpmn:endEvent` | 原生支持 |
| `intermediateCatchEvent` | `bpmn:intermediateCatchEvent` | 原生支持 |
| `intermediateThrowEvent` | `bpmn:intermediateThrowEvent` | 原生支持 |
| `boundaryEvent` | `bpmn:boundaryEvent` | 原生支持 |
| `subProcess` | `bpmn:subProcess` | 原生支持 |
| `expandedSubProcess` | `bpmn:subProcess` | 兼容旧/非标准类型 |
| `callActivity` | `bpmn:callActivity` | 原生支持 |
| `userTask` | `bpmn:userTask` | 原生支持 |
| `serviceTask` | `bpmn:serviceTask` | 原生支持 |
| `scriptTask` | `bpmn:scriptTask` | 原生支持 |
| `receiveTask` | `bpmn:receiveTask` | 原生支持 |
| `manualTask` | `bpmn:userTask` | 导入兼容映射，重新导出会成为 userTask |
| `businessRuleTask` | `bpmn:serviceTask` | 导入兼容映射，重新导出会成为 serviceTask |
| `exclusiveGateway` | `bpmn:exclusiveGateway` | 原生支持 |
| `parallelGateway` | `bpmn:parallelGateway` | 原生支持 |
| `inclusiveGateway` | `bpmn:inclusiveGateway` | 原生支持 |
| `sequenceFlow` | `bpmn:sequenceFlow` | 原生支持 |

命名空间前缀不影响标签识别，解析使用 `localName`。未知标签会被忽略，不会自动保留为自定义元素。

## 属性导入

导入器先根据目标类型 Schema 填充默认值，再读取 XML 覆盖：

- `inline` 字段从 XML 属性读取。
- `flowable:*` 字段优先通过 Flowable 命名空间读取，兼容直接带前缀的属性读取。
- `children` 字段读取同名子元素；`document` 映射到 `documentation`。
- 顺序流额外读取 `sourceRef`、`targetRef` 和 `conditionExpression`。
- 节点和边的 `id`、`name` 最终以 XML 元素属性和生成的合法 ID 为准。

缺失 ID 或重复 ID 时，使用 `BpmnIdGenerator` 生成 `node-` 或 `edge-` 前缀 ID；连线只在 sourceRef 和 targetRef 都存在时导入。

## DI 坐标和自动布局

### 有 DI 坐标

`BPMNShape` 的 `dc:Bounds` 使用左上角坐标，LogicFlow 节点使用中心点坐标，因此导入时转换为：

```text
logicflow.x = bounds.x + bounds.width / 2
logicflow.y = bounds.y + bounds.height / 2
```

`BPMNEdge` 下至少有两个 `di:waypoint` 时恢复到 `edge.pointsList`；随后首尾点会替换为 LogicFlow 计算的真实锚点，避免箭头落入节点内部。

### 没有 DI 坐标

基础布局把开始事件放在顶部、结束事件放在底部，其余节点按 4 列网格排列，列间距 200、行间距 120。它只用于让导入结果可见，不是流程拓扑布局算法。

## 导出处理流程

`toBpmnXml()` 直接读取 `lf.graphModel.nodes` 和 `lf.graphModel.edges` 的最新 Model 数据：

1. 获取流程上下文并规范化流程 ID。
2. 规范化节点和边 ID，建立旧节点 ID 到新节点 ID 的映射。
3. 修正顺序流的 source/target 引用。
4. 写出 BPMN、Flowable、BPMN DI、DI、DC 和 XSI 命名空间。
5. 使用 `ProcessSchema` 写出 process 属性和文档。
6. 根据元素类型找到 XML 标签和 Schema，写出节点。
7. 写出带 sourceRef/targetRef 的顺序流。
8. 写出 BPMNDiagram、BPMNPlane、BPMNShape、Bounds 和 BPMNEdge。

## 属性导出规则

- `inline` 字段输出为 XML 属性，空值、`false` 和未设置的可选值通常跳过。
- `id` 和 `name` 是必要字段，非空时优先输出。
- `flowable:*` 字段输出为 `flowable:` 命名空间属性。
- `document` 输出为 `documentation` 子元素。
- 定时、消息、信号和错误事件定义输出为空子元素。
- `terminateAll` 输出为 `terminateEventDefinition`。
- `conditionExpression` 输出 `xsi:type="tFormalExpression"`。
- `script`、条件表达式和配置为 CDATA 的内容使用 CDATA 包裹。
- 所有属性值执行 XML 转义，避免 `&`、`<`、`>`、引号破坏结构。

导出器会先按 Schema 创建完整默认 form，再用 `properties.form` 的非空用户值覆盖；这保证旧画布或缺少部分字段的画布仍能导出。

## DI 导出注意点

当前导出器为每个节点写出当前坐标和尺寸；顺序流的 BPMN DI 默认写出源节点和目标节点的几何中心作为两个 waypoint。导入时可以恢复已有折线路径，但插件当前导出不会自动生成复杂折线、泳道或池边界。

## 往返验证建议

对新增或修改的 Schema/元素，至少验证：

1. 新建画布 → 编辑属性 → 导出 XML。
2. 导出 XML → 导入新 LogicFlow 实例。
3. 比较流程 ID、名称、节点/边数量、sourceRef/targetRef 和关键 Flowable 属性。
4. 检查脚本、条件、文档中的 XML 特殊字符。
5. 检查旧 ID、重复属性、缺失 DI 和兼容映射场景。
6. 最后交给 Flowable 后端执行真实部署校验。
