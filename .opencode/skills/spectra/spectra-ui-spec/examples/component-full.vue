<script setup lang="ts">
import { ref } from "vue";

defineOptions({
    name: "MyComponent"
});

interface Props {
    /** 标题（必填） */
    title: string;
    /** 计数器（可选，默认值 0） */
    count?: number;
    /** 数据列表（可选，默认值空数组） */
    items?: string[];
    /** 状态（可选，默认值 'idle'） */
    status?: "idle" | "loading" | "success" | "error";
}

const props = withDefaults(defineProps<Props>(), {
    count: 0,
    items: () => [],
    status: "idle"
});

const emit = defineEmits<{
    /** 值变化时触发 */
    change: [value: string];
    /** 更新 v-model 时触发 */
    "update:modelValue": [value: string];
}>();

const model = defineModel<string>({ required: true });
const internalState = ref<string>("");
</script>

<template>
    <div class="my-component">
        <h3>{{ title }}</h3>
        <p>Count: {{ count }}</p>
        <p>Status: {{ status }}</p>
        <ul>
            <li v-for="(item, index) in items" :key="index">{{ item }}</li>
        </ul>
        <input v-model="model" />
        <button @click="emit('change', internalState)">触发</button>
    </div>
</template>

<style scoped>
.my-component {
    padding: 16px;
}
</style>
