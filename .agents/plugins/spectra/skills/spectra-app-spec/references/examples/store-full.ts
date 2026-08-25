import { defineStore } from "pinia";

import { STORAGE_KEY_REFRESH_TOKEN, STORAGE_KEY_TOKEN } from "@/config/env";
import type { UserInfo } from "@/types";

// ==================== 类型定义 ====================

const useAppStore = defineStore("app", {
    state: () => ({
        ready: false,
        token: "",
        userInfo: null as UserInfo | null,
        permissions: [] as string[],
        isFirstLaunch: true,
        push_id: ""
    }),

    getters: {
        isLoggedIn: state => Boolean(state.token)
    },

    actions: {
        setReady(value: boolean) {
            this.ready = value;
        },
        setToken(token: string) {
            this.token = token;
        },
        setUser(user: UserInfo | null) {
            this.userInfo = user;
        },
        setPermissions(permissions: string[]) {
            this.permissions = [...permissions];
        },
        setFirstLaunch(value: boolean) {
            this.isFirstLaunch = value;
        },
        setPushId(id: string) {
            this.push_id = id;
        },
        clearAuth() {
            this.token = "";
            this.userInfo = null;
            this.permissions = [];
            uni.removeStorageSync(STORAGE_KEY_TOKEN);
            uni.removeStorageSync(STORAGE_KEY_REFRESH_TOKEN);
        }
    }
});

export default useAppStore;
