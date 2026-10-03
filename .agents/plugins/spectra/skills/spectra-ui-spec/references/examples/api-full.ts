import { get, post, put } from "@/plugin/request/api";

/**
 * 薄 API 示例：绑定当前真实 User 类型和端点，不复制另一份协议。
 * OpenAPI 生成链路完成后改用生成的类型；当前不存在该导入入口。
 * loading 是传输选项，局部状态和反馈由调用页面负责。
 */
export const ExampleUserApi = {
    page(
        params: UserPageParams,
        options?: Pick<RequestOptions<"/api/user/page">, "loading">
    ): Promise<Page<UserPageVO>> {
        return get<Page<UserPageVO>>("/api/user/page", params, { loading: false, ...options });
    },

    detail(id: string): Promise<UserPageVO> {
        return get<UserPageVO, "/api/user/{id}">("/api/user/{id}", undefined, {
            pathParams: { id },
            loading: false
        });
    },

    submitCreate(params: UserOnboardingDTO): Promise<UserOnboardingVO> {
        return post<UserOnboardingVO>("/api/user/onboarding", params, { loading: false, retry: 0 });
    },

    submitUpdate(params: UserOnboardingDTO): Promise<UserOnboardingVO> {
        // 可编辑集合、清空、版本及冲突按后端实际契约迁移，不伪造已经落地的版本字段。
        return put<UserOnboardingVO>("/api/user/onboarding", params, { loading: false, retry: 0 });
    },

    resetPassword(id: string): Promise<void> {
        return put<void, "/api/user/password/reset/{id}">("/api/user/password/reset/{id}", undefined, {
            pathParams: { id },
            noBody: true,
            loading: false,
            retry: 0
        });
    }
};
