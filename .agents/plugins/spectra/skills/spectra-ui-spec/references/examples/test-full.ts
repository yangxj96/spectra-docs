import { createTestingPinia } from "@pinia/testing";
import { mount } from "@vue/test-utils";
import { ElOption, ElSelect } from "element-plus";
import { beforeEach, describe, expect, it, vi } from "vitest";

import DictSelect from "../src/components/DictSelect/index.vue";
import { useDictStore } from "../src/plugin/store/modules/use-dict-store";

const dictItems = [
    { id: "1", gid: "state", label: "正常", value: "0", sort: 1, state: 0, default_flag: true },
    { id: "2", gid: "state", label: "冻结", value: "1", sort: 2, state: 0, default_flag: false },
    { id: "3", gid: "state", label: "封禁", value: "2", sort: 3, state: 0, default_flag: false }
];

function mountDictSelect(modelValue: string | undefined = "0") {
    const pinia = createTestingPinia({ stubActions: true });
    const store = useDictStore(pinia);
    vi.mocked(store.getDictData).mockResolvedValue(dictItems);
    return mount(DictSelect, {
        props: { modelValue, dict_code: "sys_common_state" },
        global: { plugins: [pinia], components: { ElSelect, ElOption } }
    });
}

beforeEach(() => vi.clearAllMocks());

describe("DictSelect 组件", () => {
    it("应该正确接收并传递dict_code和model值", async () => {
        const wrapper = mountDictSelect();

        // 检查props是否正确接收
        expect(wrapper.props("modelValue")).toBe("0");
        expect(wrapper.props("dict_code")).toBe("sys_common_state");
    });

    it("应该正确渲染选项", async () => {
        const wrapper = mountDictSelect();

        await wrapper.vm.$nextTick();

        // 检查选项是否渲染
        const options = wrapper.findAll(".el-select-dropdown__item");
        expect(options.length).toBe(3);
    });

    it("应该触发 update:modelValue 事件", async () => {
        const wrapper = mountDictSelect();

        // 模拟选择新值
        await wrapper.find(".el-select").trigger("click");
        await wrapper.findAll(".el-select-dropdown__item")[1].trigger("click");

        // 检查事件是否触发
        expect(wrapper.emitted("update:modelValue")).toBeTruthy();
    });

    it("应该处理空字典数据", async () => {
        const pinia = createTestingPinia({ stubActions: true });
        const store = useDictStore(pinia);
        vi.mocked(store.getDictData).mockResolvedValue([]);
        const wrapper = mount(DictSelect, {
            props: { modelValue: undefined, dict_code: "empty_dict" },
            global: { plugins: [pinia], components: { ElSelect, ElOption } }
        });

        await wrapper.vm.$nextTick();

        // 检查选项是否为空
        const options = wrapper.findAll(".el-select-dropdown__item");
        expect(options.length).toBe(0);
    });
});
