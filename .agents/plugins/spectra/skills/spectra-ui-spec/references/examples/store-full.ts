import { defineStore } from "pinia";
import type {} from "pinia-plugin-persistedstate";

interface StoreUser {
    token: Token | undefined;
}

/** 会话共享状态示例；显式加载项目已有的持久化类型扩展，临时表单留在所属页面。 */
export const useExampleUserStore = defineStore("example-user", {
    state: (): StoreUser => ({
        token: undefined
    }),
    getters: {
        isLoggedIn(): boolean {
            return this.token !== undefined;
        },
        getPermissions(): string[] {
            return this.token?.permissions ?? [];
        },
        /** 仅控制界面可见性，Service 仍负责最终授权。 */
        hasPermission(): (permission: string) => boolean {
            return (permission: string): boolean => {
                if (!permission) return false;
                const required = permission.split(":");
                return this.getPermissions.some(granted => {
                    if (granted === "*") return true;
                    const parts = granted.split(":");
                    return (
                        parts.length === required.length &&
                        parts.every((part, index) => part === "*" || part === required[index])
                    );
                });
            };
        },
        hasAllPermissions(): (permissions: string[]) => boolean {
            return (permissions: string[]): boolean => permissions.every(permission => this.hasPermission(permission));
        }
    },
    actions: {
        setAuth(token: Token): void {
            this.token = { ...token, permissions: [...token.permissions] };
        },
        /** 退出或切换身份时先清理会话状态；其他共享缓存也须按所属生命周期失效。 */
        clearAuth(): void {
            this.token = undefined;
        }
    },
    // Access Token 仅在内存；Refresh Token 由 HttpOnly Cookie 管理。
    persist: false
});
