/**
 * 网络状态监听 Hook
 *
 * 规范说明：
 * 1. 文件命名：use-{功能名}.ts
 * 2. 导出命名：use{功能名}
 * 3. 使用 uni-app 生命周期钩子（onLoad、onShow 等）
 * 4. 全局共享状态使用模块级 ref
 * 5. setup*() 函数用于全局初始化（在 App.vue onLaunch 中调用）
 */

import { ref, onUnmounted } from "vue";
import { onShow } from "@dcloudio/uni-app";

// ==================== 类型定义 ====================

/** 网络类型 */
type NetworkType = "wifi" | "2g" | "3g" | "4g" | "5g" | "unknown" | "none";

/** 网络状态 */
interface NetworkState {
    /** 是否在线 */
    isOnline: boolean;
    /** 网络类型 */
    networkType: NetworkType;
}

// ==================== 模块级共享状态 ====================

/** 全局网络状态（单例模式） */
const isOnline = ref(true);
const networkType = ref<NetworkType>("unknown");

/** 监听器是否已设置 */
let listenerSetup = false;

// ==================== 全局初始化函数 ====================

/**
 * 设置网络监听器（在 App.vue onLaunch 中调用）
 *
 * @example
 * // App.vue
 * import { setupNetworkListener } from "@/hooks/useNetwork";
 * onLaunch(() => { setupNetworkListener(); });
 */
export function setupNetworkListener() {
    if (listenerSetup) return;

    // 获取初始网络状态
    uni.getNetworkType({
        success: (res) => {
            networkType.value = res.networkType as NetworkType;
            isOnline.value = res.networkType !== "none";
        }
    });

    // 监听网络变化
    uni.onNetworkStatusChange((res) => {
        isOnline.value = res.isConnected;
        networkType.value = res.networkType as NetworkType;

        // 网络恢复时可触发刷新
        if (res.isConnected) {
            console.log("[Network] 网络已恢复:", res.networkType);
        } else {
            console.log("[Network] 网络已断开");
        }
    });

    listenerSetup = true;
}

// ==================== Composable 函数 ====================

/**
 * 网络状态 Hook
 *
 * @returns 网络状态和方法
 *
 * @example
 * <script setup>
 * import { useNetwork } from "@/hooks/useNetwork";
 * const { isOnline, networkType, refreshNetwork } = useNetwork();
 * </script>
 *
 * <template>
 *   <view v-if="!isOnline" class="network-error">
 *     网络已断开，请检查网络连接
 *   </view>
 * </template>
 */
export function useNetwork(): NetworkState & {
    /** 刷新网络状态 */
    refreshNetwork: () => void;
} {
    // 页面显示时刷新网络状态
    onShow(() => {
        refreshNetwork();
    });

    // 组件卸载时清理（可选）
    onUnmounted(() => {
        // 不移除全局监听器，因为是单例模式
    });

    /**
     * 刷新网络状态
     */
    function refreshNetwork() {
        uni.getNetworkType({
            success: (res) => {
                networkType.value = res.networkType as NetworkType;
                isOnline.value = res.networkType !== "none";
            }
        });
    }

    return {
        isOnline,
        networkType,
        refreshNetwork
    };
}

// ==================== 类型导出 ====================

export type { NetworkType, NetworkState };
