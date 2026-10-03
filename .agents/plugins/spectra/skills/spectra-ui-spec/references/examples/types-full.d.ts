export {};

declare global {
    /**
     * 手写页面模型示例。API 数据与端点类型由后端契约生成，
     * 生成链路落地前引用项目现有真实类型，不在此另建 User/Token 协议。
     */
    namespace UIExample {
        type LoadState<T> =
            | { status: "idle" }
            | { status: "loading" }
            | { status: "ready"; value: T }
            | { status: "failed"; error: unknown };

        type UserEditorState = {
            source: UserPageVO | undefined;
            draftName: string;
            saving: boolean;
            validationMessages: Record<string, string>;
        };

        type PaginationState = {
            page: number;
            size: number;
            total: number;
        };
    }
}
