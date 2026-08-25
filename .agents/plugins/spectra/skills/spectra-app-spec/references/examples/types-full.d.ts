/** 移动端类型示例：与 src/types/index.ts 的导出模型保持一致。 */

export interface ApiResponse<T = unknown> {
    code: number;
    data: T;
    msg: string;
}

export type PageRequest = {
    page: number;
    pageSize: number;
};

export type PageResponse<T = unknown> = {
    records: T[];
    total: number;
    size: number;
    current: number;
    pages: number;
};

export type RequestOptions = {
    url: string;
    method?: "GET" | "POST" | "PUT" | "DELETE";
    data?: Record<string, unknown>;
    header?: Record<string, string>;
    timeout?: number;
    skipAuth?: boolean;
    noBody?: boolean;
};

export interface UserInfo {
    id: string;
    username: string;
    avatar?: string;
    phone?: string;
    email?: string;
}

export type LoginRequest =
    | { type: "PASSWORD"; username: string; password: string; captcha: string; captchaKey?: string }
    | { type: "SMS"; username: string; sms_code: string }
    | { type: "EMAIL"; username: string; email_code: string };

export type LoginResult =
    | {
          id: string;
          username: string;
          access_token: string;
          refresh_token: string;
          permissions: string[];
          mfa_required?: false;
          mfa_enrollment_required?: false;
      }
    | {
          id: string;
          username: string;
          mfa_required: true;
          mfa_enrollment_required: boolean;
          mfa_challenge_id: string;
          mfa_challenge_expires_at: number;
          access_token?: never;
          refresh_token?: never;
          permissions?: never;
      };
