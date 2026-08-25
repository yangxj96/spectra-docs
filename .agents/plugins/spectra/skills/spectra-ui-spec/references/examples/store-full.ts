import { defineStore } from "pinia";

interface StoreUser {
    token: Token;
    isLoggedIn: boolean;
}

export const useUserStore = defineStore("user", {
    state: (): StoreUser => ({
        token: {} as Token,
        isLoggedIn: false
    }),
    getters: {
        /** 获取 Permission Catalog 权限编码 */
        getPermissions(): string[] {
            return this.token.permissions || [];
        },
        /**
         * 统一权限检查方法
         * 支持精确编码、同级通配符和全局通配符。
         */
        hasPermission(): (perm: string) => boolean {
            return (perm: string): boolean => {
                if (!perm) return false;
                const required = perm.split(":");
                return this.getPermissions.some(granted => {
                    if (granted === "*") return true;
                    const parts = granted.split(":");
                    return parts.length === required.length && parts.every((part, index) => part === "*" || part === required[index]);
                });
            };
        },
        /**
         * 批量检查权限（用于 v-permission="[...]"）
         */
        hasAllPermissions(): (perms: string[]) => boolean {
            return (perms: string[]): boolean => {
                return perms.every(perm => this.hasPermission(perm));
            };
        }
    },
    actions: {
        /** 清除当前内存中的认证状态；Refresh Token 由 HttpOnly Cookie 管理。 */
        clearAuth(): void {
            this.token = {} as Token;
            this.isLoggedIn = false;
        }
    },
    persist: false
});
