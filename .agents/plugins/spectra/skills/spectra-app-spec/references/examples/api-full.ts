/** 移动端 API 示例：只组合项目 request 封装，不直接拼接 token 或 BASE_URL。 */

import { get, getPage, post, upload } from "@/services/request";
import type { PageRequest, PageResponse, UserInfo } from "@/types";

export type UserQuery = PageRequest & {
    username?: string;
    status?: "ACTIVE" | "LOCKED" | "DISABLED";
};

export function getUserPage(params: UserQuery): Promise<PageResponse<UserInfo>> {
    return getPage<UserInfo>("/api/user/page", params);
}

export function getUser(id: string): Promise<UserInfo> {
    return get<UserInfo>(`/api/user/${id}`);
}

export function createUser(data: Record<string, unknown>): Promise<UserInfo> {
    return post<UserInfo>("/api/user/onboarding", data);
}

export function uploadUserAvatar(filePath: string, onProgress?: (progress: number) => void): Promise<string> {
    return upload<string>({
        url: "/api/user/avatar",
        filePath,
        name: "file",
        onProgress
    });
}
