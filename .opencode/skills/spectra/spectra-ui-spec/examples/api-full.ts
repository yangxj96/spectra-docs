import { del, get, post, put } from "@/plugin/request/api";

/**
 * 用户相关接口
 *
 * @author Jack Young
 * @version 1.0
 * @since 2025-11-11 15:00:00
 */
export const UserApi = {
    /**
     * 分页查询用户
     * @param params 分页参数
     */
    getPage(params: UserPageParams): Promise<Page<UserVO>> {
        return get<Page<UserVO>>("/api/user/page", params);
    },

    /**
     * 获取用户详情
     * @param id 用户ID
     */
    getById(id: string): Promise<UserVO> {
        return get<UserVO>(`/api/user/${id}`);
    },

    /**
     * 创建用户
     * @param params 用户信息
     */
    created(params: UserSaveFrom): Promise<void> {
        return post<void>("/api/user", params);
    },

    /**
     * 修改用户
     * @param params 用户信息
     */
    modify(params: UserSaveFrom): Promise<void> {
        return put<void>("/api/user", params);
    },

    /**
     * 删除用户
     * @param id 用户ID
     */
    deleteById(id: string): Promise<void> {
        return del<void>(`/api/user/${id}`);
    },

    /**
     * 重置密码
     * @param id 用户ID
     */
    resetPassword(id: string): Promise<void> {
        return post<void>(`/api/user/${id}/reset-password`);
    }
};
