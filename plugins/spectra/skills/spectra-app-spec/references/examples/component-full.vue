<script setup lang="ts">
import { ref, computed } from "vue";

defineOptions({
    name: "UserInfoCard"
});

interface Props {
    /** 用户头像 */
    avatar?: string;
    /** 用户昵称 */
    nickname: string;
    /** 用户描述 */
    description?: string;
    /** 是否显示操作按钮 */
    showActions?: boolean;
    /** 尺寸模式 */
    size?: "small" | "medium" | "large";
}

const props = withDefaults(defineProps<Props>(), {
    avatar: "",
    description: "",
    showActions: false,
    size: "medium"
});

const emit = defineEmits<{
    /** 点击卡片时触发 */
    tap: [userInfo: { nickname: string; avatar: string }];
    /** 点击操作按钮时触发 */
    action: [action: "follow" | "message" | "more"];
}>();

// 计算属性
const defaultAvatar = computed(() => "/static/default/avatar.png");
const avatarSrc = computed(() => props.avatar || defaultAvatar.value);

// 方法
function handleTap() {
    emit("tap", {
        nickname: props.nickname,
        avatar: avatarSrc.value
    });
}

function handleAction(action: "follow" | "message" | "more") {
    emit("action", action);
}
</script>

<template>
    <view class="user-info-card" :class="`user-info-card--${size}`" @tap="handleTap">
        <view class="user-info-card__avatar">
            <image class="user-info-card__avatar-img" :src="avatarSrc" mode="aspectFill" />
        </view>
        <view class="user-info-card__content">
            <text class="user-info-card__nickname">{{ nickname }}</text>
            <text v-if="description" class="user-info-card__desc">{{ description }}</text>
        </view>
        <view v-if="showActions" class="user-info-card__actions" @tap.stop>
            <view class="user-info-card__action-btn" @tap="handleAction('follow')">
                <text class="user-info-card__action-text">关注</text>
            </view>
            <view class="user-info-card__action-btn" @tap="handleAction('message')">
                <text class="user-info-card__action-text">私信</text>
            </view>
        </view>
    </view>
</template>

<style lang="scss" scoped>
.user-info-card {
    display: flex;
    align-items: center;
    padding: 20rpx;
    background-color: #fff;

    // 尺寸变体
    &--small {
        .user-info-card__avatar-img {
            width: 80rpx;
            height: 80rpx;
        }
        .user-info-card__nickname {
            font-size: 28rpx;
        }
    }

    &--medium {
        .user-info-card__avatar-img {
            width: 120rpx;
            height: 120rpx;
        }
        .user-info-card__nickname {
            font-size: 32rpx;
        }
    }

    &--large {
        .user-info-card__avatar-img {
            width: 160rpx;
            height: 160rpx;
        }
        .user-info-card__nickname {
            font-size: 36rpx;
        }
    }

    &__avatar {
        margin-right: 20rpx;

        &-img {
            border-radius: 50%;
        }
    }

    &__content {
        flex: 1;
        overflow: hidden;
    }

    &__nickname {
        font-weight: bold;
        color: #333;
        display: block;
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
    }

    &__desc {
        font-size: 24rpx;
        color: #666;
        margin-top: 8rpx;
        display: block;
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
    }

    &__actions {
        display: flex;
        gap: 16rpx;
    }

    &__action-btn {
        padding: 12rpx 24rpx;
        background-color: #007aff;
        border-radius: 8rpx;

        &:active {
            opacity: 0.8;
        }
    }

    &__action-text {
        font-size: 24rpx;
        color: #fff;
    }
}
</style>
