# 工作流 Picker 选择弹框 实现计划

## 状态

**待启动**

> 执行时按 `spectra-ui/AGENTS.md` 和 Spectra Web skill 实施，并使用复选框跟踪进度；不依赖仓库未提供的外部 Agent 技能。

**目标：** 为流程设计器的 5 种 picker 类型（form/user/group/javaClass/process）实现对应的选择弹框，点击属性面板「选择」按钮后弹出对应弹框，选中后回填到 BPMN 属性。

**架构：** 在 `views/System/Workflow/components/pickers/` 下创建 5 个独立弹框组件，统一接口（`v-model:visible` + `multiple` + `modelValue` + `@confirm`）。WorkflowDesigner 监听 `property:picker` 事件，按 `pickerType` 分发到对应弹框，弹框确认后调用 `payload.resolve(value)` 回填。

**技术栈：** Vue 3 `<script setup>` + TypeScript + Element Plus（ElDialog/ElTable/ElTree/ElPagination）+ 现有 API 模块

---

## 文件结构

| 文件 | 职责 |
|---|---|
| 创建：`spectra-ui/src/views/System/Workflow/components/pickers/FormPickerDialog.vue` | 表单选择弹框（单选，返回 `code`） |
| 创建：`spectra-ui/src/views/System/Workflow/components/pickers/UserPickerDialog.vue` | 用户选择弹框（单/多选，返回 `username`） |
| 创建：`spectra-ui/src/views/System/Workflow/components/pickers/GroupPickerDialog.vue` | 部门选择弹框（单/多选，返回 `id`） |
| 创建：`spectra-ui/src/views/System/Workflow/components/pickers/JavaClassPickerDialog.vue` | Java 类选择弹框（壳子，暂无后端接口） |
| 创建：`spectra-ui/src/views/System/Workflow/components/pickers/ProcessPickerDialog.vue` | 流程定义选择弹框（单选，返回 `key`） |
| 修改：`spectra-ui/src/views/System/Workflow/components/WorkflowDesigner/index.vue` | 集成 picker 分发逻辑 + 弹框挂载 |

## 统一组件接口约定

所有 picker 弹框遵循相同接口：

```typescript
// 显隐（v-model）
const visible = defineModel<boolean>("visible", { required: true });

// props
defineProps<{
    /** 是否多选 */
    multiple?: boolean;
    /** 当前值（用于回显已选中项） */
    modelValue?: string;
}>();

// emits
const emit = defineEmits<{
    /** 确认选择，value 为逗号拼接的字符串（多选时） */
    confirm: [value: string];
}>();
```

## 返回值约定

| pickerType | 返回值字段 | 多选格式 |
|---|---|---|
| form | `FormDefinitionVO.code` | 不适用（单选） |
| user | `UserPageVO.username` | `user1,user2` |
| group | `DepartmentTreeVO.id` | `uuid1,uuid2` |
| javaClass | 类全限定名（手动） | 不适用 |
| process | `ProcessDefinitionVO.key` | 不适用（单选） |

---

### 任务 1：FormPickerDialog

**文件：**
- 创建：`spectra-ui/src/views/System/Workflow/components/pickers/FormPickerDialog.vue`

**数据源：** `FormApi.page({ name })` → `Page<FormDefinitionVO>`（records 字段）

- [ ] **步骤 1：创建组件**

```vue
<script setup lang="ts">
import { ref, watch } from "vue";
import { FormApi } from "@/api/workflow/form-api.ts";

const visible = defineModel<boolean>("visible", { required: true });

const props = defineProps<{
    multiple?: boolean;
    modelValue?: string;
}>();

const emit = defineEmits<{
    confirm: [value: string];
}>();

const loading = ref(false);
const tableData = ref<FormDefinitionVO[]>([]);
const keyword = ref("");
const selected = ref<FormDefinitionVO | null>(null);

const loadData = async () => {
    loading.value = true;
    try {
        const params: Record<string, unknown> = {};
        if (keyword.value) params.name = keyword.value;
        const result = await FormApi.page(params);
        tableData.value = result?.records || [];
    } finally {
        loading.value = false;
    }
};

watch(visible, v => {
    if (v) {
        keyword.value = "";
        selected.value = null;
        loadData();
    }
});

const handleRowClick = (row: FormDefinitionVO) => {
    selected.value = row;
};

const handleConfirm = () => {
    if (!selected.value) return;
    emit("confirm", selected.value.code);
    visible.value = false;
};
</script>

<template>
    <el-dialog v-model="visible" title="选择表单" width="600px" destroy-on-close :close-on-click-modal="false">
        <div style="margin-bottom: 12px">
            <el-input v-model="keyword" placeholder="搜索表单名称" clearable style="width: 240px" @keyup.enter="loadData" />
            <el-button type="primary" style="margin-left: 8px" @click="loadData">查询</el-button>
        </div>
        <el-table
            v-loading="loading"
            :data="tableData"
            highlight-current-row
            height="360"
            @row-click="handleRowClick"
            @current-change="handleRowClick"
        >
            <el-table-column label="表单名称" prop="name" />
            <el-table-column label="编码" prop="code" width="160" />
            <el-table-column label="版本" prop="current_version" width="70" align="center" />
            <el-table-column label="状态" width="80" align="center">
                <template #default="{ row }">
                    <el-tag :type="row.active ? 'success' : 'info'" size="small">{{ row.active ? "启用" : "禁用" }}</el-tag>
                </template>
            </el-table-column>
        </el-table>
        <template #footer>
            <el-button @click="visible = false">取消</el-button>
            <el-button type="primary" :disabled="!selected" @click="handleConfirm">确定</el-button>
        </template>
    </el-dialog>
</template>
```

- [ ] **步骤 2：验证编译**

运行：`cd spectra-ui && pnpm run type-check`
预期：PASS

---

### 任务 2：UserPickerDialog

**文件：**
- 创建：`spectra-ui/src/views/System/Workflow/components/pickers/UserPickerDialog.vue`

**数据源：** `UserApi.page({ username, page_num, page_size })` → `Page<UserPageVO>`

- [ ] **步骤 1：创建组件**

```vue
<script setup lang="ts">
import { ref, watch } from "vue";
import { UserApi } from "@/api/user/user-api.ts";

const visible = defineModel<boolean>("visible", { required: true });

const props = defineProps<{
    multiple?: boolean;
    modelValue?: string;
}>();

const emit = defineEmits<{
    confirm: [value: string];
}>();

const loading = ref(false);
const tableData = ref<UserPageVO[]>([]);
const total = ref(0);
const keyword = ref("");
const pageNum = ref(1);
const pageSize = ref(10);
const selectedRows = ref<UserPageVO[]>([]);
const currentRow = ref<UserPageVO | null>(null);

const loadData = async () => {
    loading.value = true;
    try {
        const params: UserPageParams = {
            page_num: pageNum.value,
            page_size: pageSize.value
        };
        if (keyword.value) params.username = keyword.value;
        const result = await UserApi.page(params);
        tableData.value = result?.records || [];
        total.value = result?.total || 0;
    } finally {
        loading.value = false;
    }
};

watch(visible, v => {
    if (v) {
        keyword.value = "";
        pageNum.value = 1;
        selectedRows.value = [];
        currentRow.value = null;
        loadData();
    }
});

const handleSelectionChange = (rows: UserPageVO[]) => {
    selectedRows.value = rows;
};

const handleRowClick = (row: UserPageVO) => {
    currentRow.value = row;
};

const handleConfirm = () => {
    if (props.multiple) {
        if (selectedRows.value.length === 0) return;
        emit("confirm", selectedRows.value.map(r => r.username).join(","));
    } else {
        if (!currentRow.value) return;
        emit("confirm", currentRow.value.username);
    }
    visible.value = false;
};

const hasSelection = () => (props.multiple ? selectedRows.value.length > 0 : !!currentRow.value);
</script>

<template>
    <el-dialog v-model="visible" title="选择用户" width="680px" destroy-on-close :close-on-click-modal="false">
        <div style="margin-bottom: 12px">
            <el-input v-model="keyword" placeholder="搜索用户名" clearable style="width: 240px" @keyup.enter="loadData" />
            <el-button type="primary" style="margin-left: 8px" @click="loadData">查询</el-button>
        </div>
        <el-table
            v-loading="loading"
            :data="tableData"
            :highlight-current-row="!multiple"
            height="360"
            @selection-change="handleSelectionChange"
            @row-click="handleRowClick"
        >
            <el-table-column v-if="multiple" type="selection" width="50" />
            <el-table-column label="用户名" prop="username" width="140" />
            <el-table-column label="姓名" prop="real_name" width="120" />
            <el-table-column label="部门" prop="department_name" />
            <el-table-column label="手机号" prop="phone" width="140" />
        </el-table>
        <div style="margin-top: 12px; display: flex; justify-content: flex-end">
            <el-pagination
                v-model:current-page="pageNum"
                v-model:page-size="pageSize"
                :total="total"
                :page-sizes="[10, 20, 50]"
                layout="total, sizes, prev, pager, next"
                @size-change="loadData"
                @current-change="loadData"
            />
        </div>
        <template #footer>
            <el-button @click="visible = false">取消</el-button>
            <el-button type="primary" :disabled="!hasSelection()" @click="handleConfirm">确定</el-button>
        </template>
    </el-dialog>
</template>
```

- [ ] **步骤 2：验证编译**

运行：`cd spectra-ui && pnpm run type-check`
预期：PASS

---

### 任务 3：GroupPickerDialog

**文件：**
- 创建：`spectra-ui/src/views/System/Workflow/components/pickers/GroupPickerDialog.vue`

**数据源：** `DepartmentApi.tree()` → `DepartmentTreeVO[]`（树形）

- [ ] **步骤 1：创建组件**

```vue
<script setup lang="ts">
import { ref, watch } from "vue";
import { DepartmentApi } from "@/api/user/department-api.ts";
import type { ElTree } from "element-plus";

const visible = defineModel<boolean>("visible", { required: true });

const props = defineProps<{
    multiple?: boolean;
    modelValue?: string;
}>();

const emit = defineEmits<{
    confirm: [value: string];
}>();

const loading = ref(false);
const treeData = ref<DepartmentTreeVO[]>([]);
const treeRef = ref<InstanceType<typeof ElTree>>();
const currentNode = ref<DepartmentTreeVO | null>(null);

const loadData = async () => {
    loading.value = true;
    try {
        treeData.value = await DepartmentApi.tree();
    } finally {
        loading.value = false;
    }
};

watch(visible, v => {
    if (v) {
        currentNode.value = null;
        loadData();
    }
});

const handleNodeClick = (data: DepartmentTreeVO) => {
    if (!props.multiple) {
        currentNode.value = data;
    }
};

const handleConfirm = () => {
    if (props.multiple) {
        const checked = treeRef.value?.getCheckedNodes(false, false) as DepartmentTreeVO[];
        if (!checked || checked.length === 0) return;
        emit("confirm", checked.map(n => n.id).join(","));
    } else {
        if (!currentNode.value) return;
        emit("confirm", currentNode.value.id);
    }
    visible.value = false;
};

const hasSelection = () => {
    if (props.multiple) {
        const checked = treeRef.value?.getCheckedNodes(false, false);
        return !!checked && checked.length > 0;
    }
    return !!currentNode.value;
};
</script>

<template>
    <el-dialog v-model="visible" title="选择部门" width="480px" destroy-on-close :close-on-click-modal="false">
        <div v-loading="loading" style="height: 380px; overflow-y: auto">
            <el-tree
                ref="treeRef"
                :data="treeData"
                :props="{ label: 'name', children: 'children' }"
                node-key="id"
                :highlight-current="!multiple"
                :show-checkbox="multiple"
                default-expand-all
                @node-click="handleNodeClick"
            />
        </div>
        <template #footer>
            <el-button @click="visible = false">取消</el-button>
            <el-button type="primary" :disabled="!hasSelection()" @click="handleConfirm">确定</el-button>
        </template>
    </el-dialog>
</template>
```

- [ ] **步骤 2：验证编译**

运行：`cd spectra-ui && pnpm run type-check`
预期：PASS

---

### 任务 4：JavaClassPickerDialog（壳子）

**文件：**
- 创建：`spectra-ui/src/views/System/Workflow/components/pickers/JavaClassPickerDialog.vue`

**数据源：** 暂无后端接口，展示空状态 + 手动输入兜底

- [ ] **步骤 1：创建组件**

```vue
<script setup lang="ts">
import { ref, watch } from "vue";

const visible = defineModel<boolean>("visible", { required: true });

const props = defineProps<{
    multiple?: boolean;
    modelValue?: string;
}>();

const emit = defineEmits<{
    confirm: [value: string];
}>();

const inputValue = ref("");

watch(visible, v => {
    if (v) {
        inputValue.value = props.modelValue || "";
    }
});

const handleConfirm = () => {
    if (!inputValue.value.trim()) return;
    emit("confirm", inputValue.value.trim());
    visible.value = false;
};
</script>

<template>
    <el-dialog v-model="visible" title="选择实现类" width="520px" destroy-on-close :close-on-click-modal="false">
        <el-empty description="类列表接口开发中，请手动输入全限定类名" :image-size="80" />
        <el-input v-model="inputValue" placeholder="如：com.devops00.spectra.workflow.delegate.MyDelegate" clearable style="margin-top: 12px" />
        <template #footer>
            <el-button @click="visible = false">取消</el-button>
            <el-button type="primary" :disabled="!inputValue.trim()" @click="handleConfirm">确定</el-button>
        </template>
    </el-dialog>
</template>
```

- [ ] **步骤 2：验证编译**

运行：`cd spectra-ui && pnpm run type-check`
预期：PASS

---

### 任务 5：ProcessPickerDialog

**文件：**
- 创建：`spectra-ui/src/views/System/Workflow/components/pickers/ProcessPickerDialog.vue`

**数据源：** `WorkflowApi.getProcessDefinitions()` → `ProcessDefinitionVO[]`

- [ ] **步骤 1：创建组件**

```vue
<script setup lang="ts">
import { ref, watch } from "vue";
import { WorkflowApi } from "@/api/workflow/workflow-api.ts";

const visible = defineModel<boolean>("visible", { required: true });

const props = defineProps<{
    multiple?: boolean;
    modelValue?: string;
}>();

const emit = defineEmits<{
    confirm: [value: string];
}>();

const loading = ref(false);
const tableData = ref<ProcessDefinitionVO[]>([]);
const selected = ref<ProcessDefinitionVO | null>(null);

const loadData = async () => {
    loading.value = true;
    try {
        tableData.value = await WorkflowApi.getProcessDefinitions();
    } finally {
        loading.value = false;
    }
};

watch(visible, v => {
    if (v) {
        selected.value = null;
        loadData();
    }
});

const handleRowClick = (row: ProcessDefinitionVO) => {
    selected.value = row;
};

const handleConfirm = () => {
    if (!selected.value) return;
    emit("confirm", selected.value.key);
    visible.value = false;
};
</script>

<template>
    <el-dialog v-model="visible" title="选择流程定义" width="620px" destroy-on-close :close-on-click-modal="false">
        <el-table v-loading="loading" :data="tableData" highlight-current-row height="360" @row-click="handleRowClick" @current-change="handleRowClick">
            <el-table-column label="流程名称" prop="name" />
            <el-table-column label="Key" prop="key" width="180" />
            <el-table-column label="版本" prop="version" width="70" align="center" />
            <el-table-column label="状态" width="80" align="center">
                <template #default="{ row }">
                    <el-tag :type="row.suspended ? 'danger' : 'success'" size="small">{{ row.suspended ? "挂起" : "激活" }}</el-tag>
                </template>
            </el-table-column>
        </el-table>
        <template #footer>
            <el-button @click="visible = false">取消</el-button>
            <el-button type="primary" :disabled="!selected" @click="handleConfirm">确定</el-button>
        </template>
    </el-dialog>
</template>
```

- [ ] **步骤 2：验证编译**

运行：`cd spectra-ui && pnpm run type-check`
预期：PASS

---

### 任务 6：WorkflowDesigner 集成

**文件：**
- 修改：`spectra-ui/src/views/System/Workflow/components/WorkflowDesigner/index.vue`

- [ ] **步骤 1：添加 import 和 picker 状态**

在 `<script setup>` 中添加：

```typescript
import type { PickerRequestPayload, PickerType } from "@yangxj96/logicflow-plugin-flowable";
import FormPickerDialog from "./pickers/FormPickerDialog.vue";
import UserPickerDialog from "./pickers/UserPickerDialog.vue";
import GroupPickerDialog from "./pickers/GroupPickerDialog.vue";
import JavaClassPickerDialog from "./pickers/JavaClassPickerDialog.vue";
import ProcessPickerDialog from "./pickers/ProcessPickerDialog.vue";
import { reactive } from "vue";

const picker = reactive({
    visible: false,
    type: "" as PickerType | "",
    multiple: false,
    value: "",
    resolve: null as ((v: string) => void) | null
});

const handlePickerConfirm = (value: string) => {
    picker.resolve?.(value);
    picker.visible = false;
};
```

- [ ] **步骤 2：替换现有的 property:picker 监听**

将现有的 `window.prompt` 版本替换为：

```typescript
logicFlow.value.on("property:picker", (payload: PickerRequestPayload) => {
    console.log("[WorkflowDesigner] property:picker:", payload);
    picker.type = payload.pickerType;
    picker.multiple = payload.multiple;
    picker.value = payload.currentValue;
    picker.resolve = payload.resolve;
    picker.visible = true;
});
```

- [ ] **步骤 3：在 template 中添加弹框**

在 `</template>` 前（designer-body div 之后）添加：

```vue
<!-- Picker 弹框 -->
<FormPickerDialog
    v-if="picker.type === 'form'"
    v-model:visible="picker.visible"
    :multiple="picker.multiple"
    :model-value="picker.value"
    @confirm="handlePickerConfirm"
/>
<UserPickerDialog
    v-else-if="picker.type === 'user'"
    v-model:visible="picker.visible"
    :multiple="picker.multiple"
    :model-value="picker.value"
    @confirm="handlePickerConfirm"
/>
<GroupPickerDialog
    v-else-if="picker.type === 'group'"
    v-model:visible="picker.visible"
    :multiple="picker.multiple"
    :model-value="picker.value"
    @confirm="handlePickerConfirm"
/>
<JavaClassPickerDialog
    v-else-if="picker.type === 'javaClass'"
    v-model:visible="picker.visible"
    :model-value="picker.value"
    @confirm="handlePickerConfirm"
/>
<ProcessPickerDialog
    v-else-if="picker.type === 'process'"
    v-model:visible="picker.visible"
    :model-value="picker.value"
    @confirm="handlePickerConfirm"
/>
```

- [ ] **步骤 4：更新 pluginsOptions 中的 pickers 配置**

将 `pickers: ["form", "user"]` 改为全部启用：

```typescript
pickers: ["form", "user", "group", "javaClass", "process"]
```

- [ ] **步骤 5：验证**

运行：`cd spectra-ui && pnpm run format && pnpm run lint:fix && pnpm run type-check`
预期：全部 PASS

- [ ] **步骤 6：手动验证**

启动 `pnpm start`，在流程设计器中：
1. 拖入用户任务 → 点击 → 「表单Key」显示 readonly + 选择按钮 → 点击弹出表单列表 → 选中 → 回填
2. 「指定人」→ 弹出用户列表（单选）→ 选中 → 回填 username
3. 「候选人」→ 弹出用户列表（多选）→ 勾选多个 → 回填逗号拼接
4. 「候选组」→ 弹出部门树（多选）→ 勾选 → 回填 id 逗号拼接
5. 拖入服务任务 → 「实现类」→ 弹出手动输入框
6. 拖入调用活动 → 「调用元素」→ 弹出流程定义列表 → 选中 → 回填 key

---

## 自检

- **规格覆盖度：** 5 种 pickerType 全部有对应弹框 ✓，WorkflowDesigner 分发逻辑 ✓，配置全量启用 ✓
- **占位符扫描：** 无 TODO/待定 ✓（javaClass 的空状态是有意设计，非占位符）
- **类型一致性：** 所有弹框统一 `confirm: [value: string]`，WorkflowDesigner 统一 `handlePickerConfirm(value: string)` ✓
