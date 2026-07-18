<script setup lang="ts">
import { onLoad, onShow } from "@dcloudio/uni-app";
import { ref, computed } from "vue";
import { useI18n } from "vue-i18n";
import useAppStore from "@/stores/app";

defineOptions({
    name: "UserProfile"
});

const { t } = useI18n();
const appStore = useAppStore();

// 响应式状态
const loading = ref(false);
const userId = ref("");
const userInfo = ref<UserInfo | null>(null);

// 计算属性
const isLoggedIn = computed(() => appStore.isLoggedIn);
const displayName = computed(() => userInfo.value?.nickname || t("user.anonymous"));

// 页面生命周期
onLoad((options) => {
    if (options?.id) {
        userId.value = options.id;
        loadUserInfo(options.id);
    }
});

onShow(() => {
    // 页面显示时刷新数据
    if (userId.value) {
        loadUserInfo(userId.value);
    }
});

// 业务方法
async function loadUserInfo(id: string) {
    loading.value = true;
    try {
        // 使用 uni.request 封装的 API
        const { get } = await import("@/services/request");
        userInfo.value = await get<UserInfo>(`/api/users/${id}`);
    } catch (error) {
        console.error("加载用户信息失败:", error);
        uni.showToast({
            title: t("error.loadFailed"),
            icon: "none"
        });
    } finally {
        loading.value = false;
    }
}

function handleLogout() {
    uni.showModal({
        title: t("confirm.logout"),
        content: t("confirm.logoutContent"),
        success: (res) => {
            if (res.confirm) {
                appStore.clearAuth();
                uni.reLaunch({ url: "/pages/login/index" });
            }
        }
    });
}
</script>

<template>
    <view class="user-profile">
        <!-- 自定义导航栏 -->
        <uni-nav-bar status-bar fixed :title="t('profile.title')" />

        <!-- 加载状态 -->
        <view v-if="loading" class="user-profile__loading">
            <uni-load-more status="loading" />
        </view>

        <!-- 用户信息卡片 -->
        <view v-else class="user-profile__card">
            <view class="user-profile__avatar">
                <image
                    class="user-profile__avatar-img"
                    :src="userInfo?.avatar || '/static/default/avatar.png'"
                    mode="aspectFill"
                />
            </view>
            <view class="user-profile__info">
                <text class="user-profile__name">{{ displayName }}</text>
                <text class="user-profile__email">{{ userInfo?.email || "" }}</text>
            </view>
        </view>

        <!-- 功能列表 -->
        <view class="user-profile__menu">
            <view class="user-profile__menu-item" @tap="handleLogout">
                <text class="user-profile__menu-text">{{ t("profile.logout") }}</text>
                <text class="user-profile__menu-arrow">›</text>
            </view>
        </view>
    </view>
</template>

<style lang="scss" scoped>
.user-profile {
    min-height: 100vh;
    background-color: #f5f5f5;

    &__loading {
        display: flex;
        justify-content: center;
        align-items: center;
        height: 400rpx;
    }

    &__card {
        background-color: #fff;
        padding: 40rpx;
        margin: 20rpx;
        border-radius: 16rpx;
    }

    &__avatar {
        display: flex;
        justify-content: center;
        margin-bottom: 20rpx;

        &-img {
            width: 160rpx;
            height: 160rpx;
            border-radius: 50%;
        }
    }

    &__info {
        text-align: center;
    }

    &__name {
        font-size: 36rpx;
        font-weight: bold;
        color: #333;
    }

    &__email {
        font-size: 28rpx;
        color: #666;
        margin-top: 8rpx;
    }

    &__menu {
        background-color: #fff;
        margin: 20rpx;
        border-radius: 16rpx;
        overflow: hidden;

        &-item {
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding: 30rpx 40rpx;
            border-bottom: 1rpx solid #eee;

            &:last-child {
                border-bottom: none;
            }
        }

        &-text {
            font-size: 32rpx;
            color: #333;
        }

        &-arrow {
            font-size: 36rpx;
            color: #999;
        }
    }
}
</style>
