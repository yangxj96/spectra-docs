/**
 * 应用全局 Store
 *
 * 规范说明：
 * 1. 使用 Options API 风格（state + getters + actions）
 * 2. 与 uni.getStorageSync 双写模式（store 管运行时，storage 管持久化）
 * 3. 文件命名：app.ts（简洁）
 * 4. 导出命名：useAppStore
 */

import { defineStore } from "pinia";
import type { UserInfo } from "@/types";

// ==================== 类型定义 ====================

interface AppState {
    /** 应用是否就绪 */
    ready: boolean;
    /** 访问令牌 */
    token: string;
    /** 刷新令牌 */
    refreshToken: string;
    /** 用户信息 */
    userInfo: UserInfo | null;
    /** 是否首次启动 */
    isFirstLaunch: boolean;
    /** 推送设备 ID */
    pushId: string;
    /** 当前语言 */
    language: string;
    /** 主题模式 */
    theme: "light" | "dark" | "system";
}

// ==================== Store 定义 ====================

const useAppStore = defineStore("app", {
    // 状态
    state: (): AppState => ({
        ready: false,
        token: uni.getStorageSync("token") || "",
        refreshToken: uni.getStorageSync("refresh_token") || "",
        userInfo: null,
        isFirstLaunch: uni.getStorageSync("is_first_launch") !== false,
        pushId: uni.getStorageSync("push_id") || "",
        language: uni.getStorageSync("language") || "zh-CN",
        theme: (uni.getStorageSync("theme") as AppState["theme"]) || "system"
    }),

    // 计算属性
    getters: {
        /** 是否已登录 */
        isLoggedIn: (state) => !!state.token,

        /** 用户显示名称 */
        displayName: (state) => state.userInfo?.nickname || "未登录",

        /** 用户头像 */
        userAvatar: (state) => state.userInfo?.avatar || "/static/default/avatar.png"
    },

    // 方法
    actions: {
        /**
         * 设置访问令牌
         * @param token 令牌
         * @param refreshToken 刷新令牌
         */
        setToken(token: string, refreshToken?: string) {
            this.token = token;
            uni.setStorageSync("token", token);

            if (refreshToken) {
                this.refreshToken = refreshToken;
                uni.setStorageSync("refresh_token", refreshToken);
            }
        },

        /**
         * 设置用户信息
         * @param user 用户信息
         */
        setUser(user: UserInfo) {
            this.userInfo = user;
        },

        /**
         * 设置应用就绪状态
         * @param ready 是否就绪
         */
        setReady(ready: boolean) {
            this.ready = ready;
        },

        /**
         * 设置推送设备 ID
         * @param pushId 推送 ID
         */
        setPushId(pushId: string) {
            this.pushId = pushId;
            uni.setStorageSync("push_id", pushId);
        },

        /**
         * 设置语言
         * @param language 语言代码
         */
        setLanguage(language: string) {
            this.language = language;
            uni.setStorageSync("language", language);
        },

        /**
         * 设置主题
         * @param theme 主题模式
         */
        setTheme(theme: AppState["theme"]) {
            this.theme = theme;
            uni.setStorageSync("theme", theme);
        },

        /**
         * 标记非首次启动
         */
        markNotFirstLaunch() {
            this.isFirstLaunch = false;
            uni.setStorageSync("is_first_launch", false);
        },

        /**
         * 清除认证信息
         */
        clearAuth() {
            this.token = "";
            this.refreshToken = "";
            this.userInfo = null;

            uni.removeStorageSync("token");
            uni.removeStorageSync("refresh_token");
        },

        /**
         * 重置所有状态
         */
        resetAll() {
            this.clearAuth();
            this.ready = false;
            this.pushId = "";
            this.language = "zh-CN";
            this.theme = "system";

            uni.removeStorageSync("push_id");
            uni.removeStorageSync("language");
            uni.removeStorageSync("theme");
        }
    }
});

export default useAppStore;
