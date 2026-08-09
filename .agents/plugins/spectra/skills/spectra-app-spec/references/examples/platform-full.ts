/**
 * 平台抽象层示例 - 指纹认证
 *
 * 规范说明：
 * 1. 平台差异代码放入 src/platform/
 * 2. 业务代码从 @/platform/{feature} 导入
 * 3. 不要在业务代码中直接写 #ifdef 调用原生 API
 * 4. 目录结构：
 *    platform/
 *      {feature}/
 *        types.ts      # 类型定义（统一接口）
 *        index.ts      # 条件编译入口（#ifdef 导出对应平台实现）
 *        web.ts        # Web/H5 实现
 *        android.ts    # Android 原生实现
 *        ios.ts        # iOS 原生实现（可选）
 *        mp-weixin.ts  # 微信小程序实现（可选）
 */

// ==================== types.ts - 类型定义 ====================

/**
 * 指纹认证能力接口
 *
 * 所有平台必须实现此接口
 */
export interface BiometricAuth {
    /**
     * 检查设备是否支持生物认证
     * @returns 是否支持
     */
    isAvailable(): Promise<boolean>;

    /**
     * 执行生物认证
     * @param prompt 认证提示语
     * @returns 认证结果
     */
    authenticate(prompt?: string): Promise<BiometricResult>;

    /**
     * 取消认证（如果正在进行）
     */
    cancel(): void;
}

/**
 * 认证结果
 */
export interface BiometricResult {
    /** 是否成功 */
    success: boolean;
    /** 错误码（失败时） */
    errorCode?: string;
    /** 错误信息（失败时） */
    errorMessage?: string;
}

/**
 * 生物认证类型
 */
export type BiometricType = "fingerprint" | "face" | "iris";

// ==================== web.ts - H5 实现 ====================

/**
 * H5 平台生物认证
 *
 * 注意：H5 平台生物认证能力有限，使用 Web Authentication API（如果可用）
 */
class WebBiometricAuth implements BiometricAuth {
    async isAvailable(): Promise<boolean> {
        // 检查 Web Authentication API 是否可用
        if (!window.PublicKeyCredential) {
            return false;
        }

        try {
            const available = await PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable();
            return available;
        } catch {
            return false;
        }
    }

    async authenticate(prompt?: string): Promise<BiometricResult> {
        try {
            // 简化的 WebAuthn 实现
            // 实际项目中需要与后端配合生成 challenge
            console.log("[WebAuth] 认证提示:", prompt);

            // WebAuthn 需要 HTTPS 环境
            if (location.protocol !== "https:" && location.hostname !== "localhost") {
                return {
                    success: false,
                    errorCode: "HTTPS_REQUIRED",
                    errorMessage: "WebAuthn 需要 HTTPS 环境"
                };
            }

            // 实际实现需要调用 navigator.credentials.create/get
            // 这里仅作为示例
            return {
                success: false,
                errorCode: "NOT_IMPLEMENTED",
                errorMessage: "H5 平台生物认证需要完整实现"
            };
        } catch (error) {
            return {
                success: false,
                errorCode: "AUTH_FAILED",
                errorMessage: String(error)
            };
        }
    }

    cancel(): void {
        // H5 平台无需实现
    }
}

// ==================== android.ts - Android 实现 ====================

/**
 * Android 平台生物认证
 *
 * 使用 plus.biometric API（uni-app 原生能力）
 */
class AndroidBiometricAuth implements BiometricAuth {
    async isAvailable(): Promise<boolean> {
        // #ifdef APP-ANDROID
        try {
            const result = await new Promise<boolean>((resolve) => {
                plus.biometric.checkIsSupport(
                    {
                        type: "FINGERPRINT"
                    },
                    (e) => {
                        resolve(e.isSupport === 1);
                    },
                    () => {
                        resolve(false);
                    }
                );
            });
            return result;
        } catch {
            return false;
        }
        // #endif

        // 非 Android 平台返回 false
        return false;
    }

    async authenticate(prompt?: string): Promise<BiometricResult> {
        // #ifdef APP-ANDROID
        try {
            const result = await new Promise<BiometricResult>((resolve) => {
                plus.biometric.verify(
                    {
                        type: "FINGERPRINT",
                        prompt: prompt || "请验证指纹"
                    },
                    (e) => {
                        resolve({
                            success: e.result === 1,
                            errorCode: e.result !== 1 ? String(e.code) : undefined,
                            errorMessage: e.result !== 1 ? e.message : undefined
                        });
                    },
                    (e) => {
                        resolve({
                            success: false,
                            errorCode: String(e.code),
                            errorMessage: e.message
                        });
                    }
                );
            });
            return result;
        } catch (error) {
            return {
                success: false,
                errorCode: "UNKNOWN_ERROR",
                errorMessage: String(error)
            };
        }
        // #endif

        return {
            success: false,
            errorCode: "PLATFORM_NOT_SUPPORTED",
            errorMessage: "当前平台不支持生物认证"
        };
    }

    cancel(): void {
        // #ifdef APP-ANDROID
        plus.biometric.cancel();
        // #endif
    }
}

// ==================== mp-weixin.ts - 微信小程序实现 ====================

/**
 * 微信小程序平台生物认证
 *
 * 使用 wx.startSoterAuthentication API
 */
class MpWeixinBiometricAuth implements BiometricAuth {
    async isAvailable(): Promise<boolean> {
        // #ifdef MP-WEIXIN
        try {
            const res = await new Promise<UniApp.GetSupportResult>((resolve, reject) => {
                uni.getSupport({
                    order: ["fingerPrint", "facial"],
                    success: resolve,
                    fail: reject
                });
            });
            return res.isSupport.length > 0;
        } catch {
            return false;
        }
        // #endif

        return false;
    }

    async authenticate(prompt?: string): Promise<BiometricResult> {
        // #ifdef MP-WEIXIN
        try {
            // 1. 先获取 challenge
            // 实际项目中应从后端获取
            const challenge = "mock_challenge_from_server";

            // 2. 调用 SOTER 认证
            const res = await new Promise<UniApp.StartSoterAuthenticationSuccess>((resolve, reject) => {
                uni.startSoterAuthentication({
                    requestAuthModes: ["fingerPrint", "facial"],
                    challenge,
                    authContent: prompt || "请验证指纹",
                    success: resolve,
                    fail: reject
                });
            });

            return {
                success: res.errCode === 0,
                errorCode: res.errCode !== 0 ? String(res.errCode) : undefined,
                errorMessage: res.errMsg
            };
        } catch (error) {
            return {
                success: false,
                errorCode: "AUTH_FAILED",
                errorMessage: String(error)
            };
        }
        // #endif

        return {
            success: false,
            errorCode: "PLATFORM_NOT_SUPPORTED",
            errorMessage: "当前平台不支持生物认证"
        };
    }

    cancel(): void {
        // 微信小程序无需实现
    }
}

// ==================== index.ts - 条件编译入口 ====================

/**
 * 创建平台对应的生物认证实例
 *
 * 使用条件编译导出对应平台的实现
 */
function createBiometricAuth(): BiometricAuth {
    // #ifdef H5
    return new WebBiometricAuth();
    // #endif

    // #ifdef APP-ANDROID
    return new AndroidBiometricAuth();
    // #endif

    // #ifdef MP-WEIXIN
    return new MpWeixinBiometricAuth();
    // #endif

    // 默认返回 H5 实现
    return new WebBiometricAuth();
}

/**
 * 生物认证单例
 */
export const biometric = createBiometricAuth();

// 导出类型
export type { BiometricAuth, BiometricResult, BiometricType };
