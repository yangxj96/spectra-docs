/**
 * 用户相关 API 模块
 *
 * 规范说明：
 * 1. 所有 API 函数返回 Promise
 * 2. 使用 services/request.ts 中的便捷方法（get/post/put/del）
 * 3. 类型定义从 @/types 导入
 * 4. 文件命名：kebab-case（user-api.ts 或 user.ts）
 */

import { get, post, put, del } from "@/services/request";
import type { UserInfo, PageResult, PageParams } from "@/types";

// ==================== 类型定义 ====================

/** 用户查询参数 */
export interface UserQueryParams extends PageParams {
    /** 关键词搜索 */
    keyword?: string;
    /** 部门 ID */
    departmentId?: string;
    /** 状态：0-禁用 1-启用 */
    status?: 0 | 1;
}

/** 用户创建参数 */
export interface UserCreateParams {
    username: string;
    nickname: string;
    email?: string;
    phone?: string;
    departmentId?: string;
    roleIds?: string[];
}

/** 用户更新参数 */
export interface UserUpdateParams extends Partial<UserCreateParams> {
    id: string;
}

// ==================== API 函数 ====================

/**
 * 获取用户分页列表
 * @param params 查询参数
 * @returns 分页结果
 */
export function getUserPage(params: UserQueryParams): Promise<PageResult<UserInfo>> {
    return get<PageResult<UserInfo>>("/api/users/page", params);
}

/**
 * 获取用户详情
 * @param id 用户 ID
 * @returns 用户信息
 */
export function getUserDetail(id: string): Promise<UserInfo> {
    return get<UserInfo>(`/api/users/${id}`);
}

/**
 * 获取当前登录用户信息
 * @returns 用户信息
 */
export function getCurrentUser(): Promise<UserInfo> {
    return get<UserInfo>("/api/users/current");
}

/**
 * 创建用户
 * @param params 创建参数
 * @returns 创建的用户 ID
 */
export function createUser(params: UserCreateParams): Promise<string> {
    return post<string>("/api/users", params);
}

/**
 * 更新用户
 * @param params 更新参数
 * @returns void
 */
export function updateUser(params: UserUpdateParams): Promise<void> {
    return put<void>("/api/users", params);
}

/**
 * 删除用户
 * @param id 用户 ID
 * @returns void
 */
export function deleteUser(id: string): Promise<void> {
    return del<void>(`/api/users/${id}`);
}

/**
 * 批量删除用户
 * @param ids 用户 ID 列表
 * @returns void
 */
export function batchDeleteUsers(ids: string[]): Promise<void> {
    return post<void>("/api/users/batch-delete", { ids });
}

/**
 * 修改用户状态
 * @param id 用户 ID
 * @param status 状态：0-禁用 1-启用
 * @returns void
 */
export function updateUserStatus(id: string, status: 0 | 1): Promise<void> {
    return put<void>("/api/users/status", { id, status });
}

/**
 * 重置用户密码
 * @param id 用户 ID
 * @returns 新密码
 */
export function resetUserPassword(id: string): Promise<string> {
    return post<string>(`/api/users/${id}/reset-password`);
}

/**
 * 上传用户头像
 * @param filePath 本地文件路径
 * @param onProgress 进度回调
 * @returns 头像 URL
 */
export function uploadUserAvatar(
    filePath: string,
    onProgress?: (progress: number) => void
): Promise<string> {
    return new Promise((resolve, reject) => {
        const uploadTask = uni.uploadFile({
            url: `${getBaseUrl()}/api/users/avatar`,
            filePath,
            name: "file",
            header: {
                Authorization: `Bearer ${uni.getStorageSync("token")}`
            },
            success: (res) => {
                if (res.statusCode === 200) {
                    const data = JSON.parse(res.data);
                    resolve(data.data);
                } else {
                    reject(new Error("上传失败"));
                }
            },
            fail: (err) => {
                reject(err);
            }
        });

        // 监听上传进度
        if (onProgress) {
            uploadTask.onProgressUpdate((res) => {
                onProgress(res.progress);
            });
        }
    });
}

// ==================== 辅助函数 ====================

/**
 * 获取 API 基础 URL
 * @returns 基础 URL
 */
function getBaseUrl(): string {
    return import.meta.env.VITE_API_BASE_URL || "";
}
