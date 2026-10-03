import { onScopeDispose, ref, shallowRef, watch, type Ref } from "vue";

import { isRequestCancelled } from "@/plugin/request/error";

/**
 * 有独立查询生命周期的分页 Hook 示例；简单页面不必机械提取。
 * scopeKey 由调用方提供身份/会话范围标识，初次加载由调用方在合适生命周期触发。
 * error 供页面内联反馈或单一提示责任方消费，不在 Hook 重复弹消息。
 */
export function useTable<T, P extends BasePageParams>(
    request: (params: P) => Promise<Page<T>>,
    parameters: P,
    scopeKey: Readonly<Ref<string>>
) {
    const pagination = ref({
        page: parameters.page_num,
        size: parameters.page_size,
        total: 0
    });
    // 这是页面初始状态，不改写服务端空值或字段省略协议。
    const tableData = shallowRef<T[]>([]);
    const loading = ref(false);
    const error = shallowRef<unknown>();
    let requestVersion = 0;
    let disposed = false;

    function invalidate() {
        requestVersion += 1;
        loading.value = false;
        error.value = undefined;
        tableData.value = [];
        pagination.value.total = 0;
    }

    watch(scopeKey, invalidate, { flush: "sync" });
    onScopeDispose(() => {
        disposed = true;
        invalidate();
    });

    async function fetchData() {
        if (disposed) return;
        const version = ++requestVersion;
        loading.value = true;
        error.value = undefined;
        try {
            // 调用参数约定为不可变过滤值；复杂嵌套过滤由所属用例提供稳定快照。
            const result = await request({ ...parameters });
            if (disposed || version !== requestVersion) return;
            tableData.value = result.records;
            pagination.value.total = result.total;
        } catch (failure: unknown) {
            if (disposed || version !== requestVersion) return;
            if (!isRequestCancelled(failure)) error.value = failure;
        } finally {
            if (!disposed && version === requestVersion) loading.value = false;
        }
    }

    async function handleCurrentChange(page: number) {
        pagination.value.page = page;
        parameters.page_num = page;
        await fetchData();
    }

    async function handleSizeChange(size: number) {
        pagination.value.size = size;
        parameters.page_size = size;
        pagination.value.page = 1;
        parameters.page_num = 1;
        await fetchData();
    }

    async function queryFirstPage() {
        pagination.value.page = 1;
        parameters.page_num = 1;
        await fetchData();
    }

    return {
        tableData,
        pagination,
        loading,
        error,
        fetchData,
        handleCurrentChange,
        handleSizeChange,
        queryFirstPage
    };
}

export default useTable;
