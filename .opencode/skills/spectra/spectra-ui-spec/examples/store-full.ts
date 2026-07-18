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
        /**
         * 获取权限列表
         */
        getAuthorities(): string[] {
            return this.token.authorities || [];
        },
        /**
         * 获取角色列表
         */
        getRoles(): string[] {
            return this.token.roles.map(item => item.code) || [];
        },
        /**
         * 统一权限检查方法
         * 支持格式：
         * - 'USER:INSERT'
         * - 'ROLE:ADMIN'
         * - 'DICT:*'
         * - '*'
         */
        hasPermission(): (perm: string) => boolean {
            return (perm: string): boolean => {
                const { getAuthorities, getRoles } = this;
                const allPerms: string[] = [
                    ...getAuthorities,
                    ...getRoles.map(role => `ROLE:${role}`)
                ];
                if (allPerms.includes("*")) return true;
                if (perm === "*") return true;
                return allPerms.some(userPerm => {
                    if (userPerm === perm) return true;
                    if (userPerm.endsWith(":*")) {
                        const module = userPerm.slice(0, -2);
                        return perm.startsWith(`${module}:`);
                    }
                    return false;
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
        /**
         * 登录
         * @param credentials 登录凭证
         */
        async login(credentials: LoginCredentials): Promise<void> {
            // 登录逻辑
        },
        /**
         * 登出
         */
        async logout(): Promise<void> {
            this.token = {} as Token;
            this.isLoggedIn = false;
        }
    },
    persist: true
});
