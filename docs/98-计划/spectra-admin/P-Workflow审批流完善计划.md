---
tags:
  - plan
  - workflow
  - backend
---

# P-Workflow审批流完善计划

## 状态

**进行中**

> 状态变更时间：2026-07-17

### 已完成

- [x] 阶段一：TaskController任务管理（P0）
- [x] 阶段二：流程变量与状态查询（P0）
- [x] 阶段三：OA审批流程定义（P0）
- [x] 阶段四：审批回调机制（P1）
- [x] 阶段五：流程图状态查询（P1）

## 问题背景

`spectra-workflow`模块已集成Flowable引擎，但功能严重不足，无法支撑OA模块的审批需求。

### 当前状态

| 组件 | 状态 | 说明 |
|---|---|---|
| `ProcessInstanceService` | 部分可用 | 仅有`start()`方法，缺少流程状态查询 |
| `ProcessInstanceController` | 空壳 | `start()`方法为空，未实现 |
| `TaskController` | 空壳 | 注释说明了功能但未实现 |
| `ProcessDefinitionController` | 部分可用 | 只有查询流程定义API |
| `WorkflowService` | 空接口 | 无任何方法定义 |
| `WorkflowConfiguration` | 空配置 | 无任何配置 |

### 关键缺失

1. **任务管理** — 无待办/已办/完成/驳回/转办/委派API
2. **流程变量** — 启动流程时无法传递业务数据（申请人、审批人等）
3. **流程定义** — 无OA审批相关的BPMN流程定义
4. **审批回调** — 审批通过/驳回后无法回调业务模块
5. **流程状态** — 无法查询流程进度、当前节点

## 目标

1. 完善TaskController，实现任务管理全套API
2. 扩展ProcessInstanceService，支持流程变量传递和状态查询
3. 设计并部署OA审批流程BPMN定义
4. 实现审批回调机制，支持业务模块接入
5. 为OA模块提供完整的审批流能力

---

## 详细实现步骤

### 阶段一：TaskController任务管理（P0）

#### 1.1 定义TaskService接口

**操作**：
- 创建`TaskService`接口，定义任务管理方法
- 实现`TaskServiceImpl`，基于Flowable TaskService实现

**文件**：
- `spectra-modules/spectra-workflow/src/main/java/com/devops00/spectra/workflow/service/TaskService.java` — 新建接口
- `spectra-modules/spectra-workflow/src/main/java/com/devops00/spectra/workflow/service/impl/TaskServiceImpl.java` — 新建实现

**方法定义**：
```java
public interface TaskService {
    // 查询待办任务
    IPage<TaskVO> todo(PageFrom page, String assignee);
    
    // 查询已办任务
    IPage<TaskVO> done(PageFrom page, String assignee);
    
    // 完成任务（审批通过）
    void complete(String taskId, boolean approved, String comment);
    
    // 驳回任务
    void reject(String taskId, String comment);
    
    // 转办任务
    void transfer(String taskId, String targetUserId);
    
    // 委派任务
    void delegate(String taskId, String targetUserId);
}
```

#### 1.2 实现TaskController

**操作**：
- 实现TaskController，注入TaskService
- 实现待办/已办/完成/驳回/转办/委派API

**文件**：
- `spectra-modules/spectra-workflow/src/main/java/com/devops00/spectra/workflow/controller/TaskController.java` — 实现API

**API端点**：
| 方法 | 端点 | 说明 |
|---|---|---|
| GET | `/workflow/tasks/todo` | 查询待办任务 |
| GET | `/workflow/tasks/done` | 查询已办任务 |
| POST | `/workflow/tasks/{id}/complete` | 完成任务（审批通过） |
| POST | `/workflow/tasks/{id}/reject` | 驳回任务 |
| POST | `/workflow/tasks/{id}/transfer` | 转办任务 |
| POST | `/workflow/tasks/{id}/delegate` | 委派任务 |

#### 1.3 创建Task相关VO/From

**操作**：
- 创建TaskVO（任务响应对象）
- 创建TaskCompleteFrom（完成任务入参）
- 创建TaskTransferFrom（转办入参）
- 创建TaskDelegateFrom（委派入参）

**文件**：
- `spectra-modules/spectra-workflow/src/main/java/com/devops00/spectra/workflow/javabean/vo/TaskVO.java` — 新建
- `spectra-modules/spectra-workflow/src/main/java/com/devops00/spectra/workflow/javabean/from/TaskCompleteFrom.java` — 新建
- `spectra-modules/spectra-workflow/src/main/java/com/devops00/spectra/workflow/javabean/from/TaskTransferFrom.java` — 新建
- `spectra-modules/spectra-workflow/src/main/java/com/devops00/spectra/workflow/javabean/from/TaskDelegateFrom.java` — 新建

---

### 阶段二：流程变量与状态查询（P0）

#### 2.1 扩展ProcessInstanceService

**操作**：
- 添加流程状态查询方法
- 添加流程变量获取方法
- 添加流程历史查询方法

**文件**：
- `spectra-modules/spectra-workflow/src/main/java/com/devops00/spectra/workflow/service/ProcessInstanceService.java` — 扩展接口
- `spectra-modules/spectra-workflow/src/main/java/com/devops00/spectra/workflow/service/impl/ProcessInstanceServiceImpl.java` — 扩展实现

**新增方法**：
```java
// 查询流程状态
ProcessInstanceVO getStatus(String processInstanceId);

// 获取流程变量
Map<String, Object> getVariables(String processInstanceId);

// 终止流程
void terminate(String processInstanceId, String reason);
```

#### 2.2 实现ProcessInstanceController

**操作**：
- 实现启动流程API（带流程变量）
- 实现查询流程状态API
- 实现终止流程API

**文件**：
- `spectra-modules/spectra-workflow/src/main/java/com/devops00/spectra/workflow/controller/ProcessInstanceController.java` — 实现API

**API端点**：
| 方法 | 端点 | 说明 |
|---|---|---|
| POST | `/workflow/process-instances/start` | 启动流程（带变量） |
| GET | `/workflow/process-instances/{id}` | 查询流程状态 |
| GET | `/workflow/process-instances/{id}/variables` | 获取流程变量 |
| POST | `/workflow/process-instances/{id}/terminate` | 终止流程 |

#### 2.3 创建ProcessInstance相关VO/From

**操作**：
- 创建ProcessInstanceVO（流程实例响应）
- 创建ProcessInstanceStartFrom（启动流程入参）

**文件**：
- `spectra-modules/spectra-workflow/src/main/java/com/devops00/spectra/workflow/javabean/vo/ProcessInstanceVO.java` — 新建
- `spectra-modules/spectra-workflow/src/main/java/com/devops00/spectra/workflow/javabean/from/ProcessInstanceStartFrom.java` — 新建

---

### 阶段三：OA审批流程定义（P0）

#### 3.1 设计通用审批流程BPMN

**操作**：
- 设计通用的单级审批流程（适用于大多数OA场景）
- 设计多级审批流程（适用于合同、采购等复杂场景）
- 编写BPMN XML文件

**文件**：
- `spectra-modules/spectra-workflow/src/main/resources/processes/oa-single-approval.bpmn20.xml` — 单级审批流程
- `spectra-modules/spectra-workflow/src/main/resources/processes/oa-multi-approval.bpmn20.xml` — 多级审批流程

**流程设计**：
```
单级审批流程：
开始 → 申请人提交 → 审批人审批 → [通过/驳回] → 结束

多级审批流程：
开始 → 申请人提交 → 部门主管审批 → [通过/驳回] → 
→ 总监审批 → [通过/驳回] → 
→ 总经理审批 → [通过/驳回] → 结束
```

#### 3.2 部署流程定义

**操作**：
- 在`WorkflowConfiguration`中配置流程部署
- 启动时自动部署BPMN流程定义

**文件**：
- `spectra-modules/spectra-workflow/src/main/java/com/devops00/spectra/workflow/configure/WorkflowConfiguration.java` — 配置流程部署

#### 3.3 实现ProcessDefinitionController

**操作**：
- 实现查询流程定义列表API
- 实现查询流程定义详情API
- 实现挂起/激活流程定义API

**文件**：
- `spectra-modules/spectra-workflow/src/main/java/com/devops00/spectra/workflow/controller/ProcessDefinitionController.java` — 实现API

**API端点**：
| 方法 | 端点 | 说明 |
|---|---|---|
| GET | `/workflow/process-definitions` | 查询流程定义列表 |
| GET | `/workflow/process-definitions/{id}` | 查询流程定义详情 |
| POST | `/workflow/process-definitions/{id}/suspend` | 挂起流程定义 |
| POST | `/workflow/process-definitions/{id}/activate` | 激活流程定义 |

---

### 阶段四：审批回调机制（P1）

#### 4.1 定义审批回调接口

**操作**：
- 创建`ApprovalCallback`接口，定义审批回调方法
- 业务模块（OA）实现此接口处理审批结果

**文件**：
- `spectra-modules/spectra-workflow/src/main/java/com/devops00/spectra/workflow/service/ApprovalCallback.java` — 新建接口

**接口定义**：
```java
public interface ApprovalCallback {
    // 审批通过回调
    void onApproved(String businessKey, Map<String, Object> variables);
    
    // 审批驳回回调
    void onRejected(String businessKey, String reason);
    
    // 流程终止回调
    void onTerminated(String businessKey, String reason);
}
```

#### 4.2 实现回调注册机制

**操作**：
- 在`WorkflowServiceImpl`中维护回调注册表
- 业务模块启动流程时注册回调
- 审批完成时自动调用回调

**文件**：
- `spectra-modules/spectra-workflow/src/main/java/com/devops00/spectra/workflow/service/impl/WorkflowServiceImpl.java` — 实现回调注册

#### 4.3 OA模块实现回调

**操作**：
- 创建`OaApprovalCallback`实现`ApprovalCallback`
- 实现Meeting审批回调（更新会议状态）
- 实现Attendance审批回调（更新考勤状态）

**文件**：
- `spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/workflow/OaApprovalCallback.java` — 新建
- `spectra-modules/spectra-oa/src/main/java/com/devops00/spectra/oa/meeting/service/impl/MeetingServiceImpl.java` — 注册回调

---

### 阶段五：流程图状态查询（P1）

#### 5.1 实现流程图生成

**操作**：
- 使用Flowable API生成流程图
- 高亮显示当前节点
- 返回流程图图片

**文件**：
- `spectra-modules/spectra-workflow/src/main/java/com/devops00/spectra/workflow/service/impl/ProcessInstanceServiceImpl.java` — 添加流程图生成方法

#### 5.2 实现流程图API

**操作**：
- 添加查询流程图API
- 返回流程图图片（PNG格式）

**文件**：
- `spectra-modules/spectra-workflow/src/main/java/com/devops00/spectra/workflow/controller/ProcessInstanceController.java` — 添加流程图API

**API端点**：
| 方法 | 端点 | 说明 |
|---|---|---|
| GET | `/workflow/process-instances/{id}/diagram` | 获取流程图 |

---

## 验证方案

### 阶段一验证

- [x] 能通过API查询当前用户的待办任务
- [x] 能通过API查询当前用户的已办任务
- [x] 能通过API完成任务（审批通过）
- [x] 能通过API驳回任务
- [x] 能通过API转办任务给其他人
- [x] 能通过API委派任务给其他人

### 阶段二验证

- [x] 启动流程时能传递流程变量（申请人、审批人等）
- [x] 能查询流程实例的当前状态
- [x] 能获取流程实例的所有变量
- [x] 能终止流程实例

### 阶段三验证

- [x] 系统启动时自动部署OA审批流程定义
- [x] 能查询所有流程定义列表
- [x] 能查询单个流程定义详情
- [x] 能挂起/激活流程定义

### 阶段四验证

- [x] 审批通过后自动调用业务模块回调
- [x] 审批驳回后自动调用业务模块回调
- [x] 流程终止后自动调用业务模块回调

### 阶段五验证

- [x] 能获取流程图图片
- [x] 流程图高亮显示当前节点（流程实例图）

---

## 影响范围

| 模块 | 影响 |
|---|---|
| `spectra-workflow` | 全模块改造，新增大量业务逻辑 |
| `spectra-oa` | Meeting模块接入审批回调 |
| 数据库 | Flowable自动管理，无需手动建表 |

---

## 相关

- [[60-工作流]] — Flowable工作流模块文档
- [[40-OA模块]] — OA模块文档
- [[90-API总览]] — API端点速查
- [[98-计划/spectra-admin/P-工作流模块完整实现计划]] — 工作流模块完整实现计划（总控计划，本计划将被整合）
