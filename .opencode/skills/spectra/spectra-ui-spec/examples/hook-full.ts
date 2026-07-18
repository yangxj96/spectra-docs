import { onMounted, ref } from "vue";

/**
 * 表格分页 Hook
 *
 * @template T - 数据类型
 * @param request - 分页查询函数
 * @param parameters - 分页参数
 * @returns 表格相关状态和方法
 */
export function useTable<T>(
    request: (params?: BasePageParams) => Promise<Page<T>>,
    parameters: BasePageParams
) {
    // 分页实体
    const pagination = ref<Pagination>({
        size: 10,
        page: 1,
        page_sizes: [10, 15, 50, 100, 150, 300],
        default_page_size: 10,
        total: 0
    });

    // 表数据
    const table_data = ref<T[]>([]);

    // 加载状态
    const loading = ref<boolean>(false);

    onMounted(() => {
        pagination.value.page = parameters.page_num;
        pagination.value.size = parameters.page_size;
        handleCurrentChange(pagination.value.page);
    });

    /**
     * 处理页码改变
     * @param value 页码
     */
    async function handleCurrentChange(value: number) {
        parameters.page_num = value;
        parameters.page_size = pagination.value.size;
        await fetchData();
    }

    /**
     * 处理每页数量改变
     * @param value 每页数量
     */
    async function handleSizeChange(value: number) {
        parameters.page_num = pagination.value.page;
        parameters.page_size = value;
        await fetchData();
    }

    /**
     * 进行一次条件查询（重置到第一页）
     */
    async function handlerConditionQuery() {
        parameters.page_num = 1;
        pagination.value.page = 1;
        await fetchData();
    }

    /**
     * 获取数据
     */
    async function fetchData() {
        loading.value = true;
        try {
            const result = await request(parameters);
            table_data.value = result.records ?? [];
            pagination.value.total = result.total ?? 0;
        } finally {
            loading.value = false;
        }
    }

    return {
        table_data,
        pagination,
        loading,
        handleCurrentChange,
        handleSizeChange,
        handlerConditionQuery
    };
}

export default useTable;
