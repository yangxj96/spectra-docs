/**
 * 类型定义示例
 *
 * 规范说明：
 * 1. 类型文件放入 src/types/
 * 2. 使用 import type 导入类型
 * 3. 统一通过 src/types/index.ts 导出
 * 4. 文件命名：kebab-case
 * 5. 类型定义与后端 Entity/VO 对应
 */

// ==================== 请求/响应类型 ====================

/**
 * 通用 API 响应
 */
export interface ApiResponse<T = unknown> {
    /** 业务状态码 */
    code: number;
    /** 响应消息 */
    message: string;
    /** 响应数据 */
    data: T;
}

/**
 * 分页结果
 */
export interface PageResult<T> {
    /** 数据列表 */
    list: T[];
    /** 总记录数 */
    total: number;
    /** 当前页码 */
    page: number;
    /** 每页大小 */
    pageSize: number;
}

/**
 * 分页查询参数
 */
export interface PageParams {
    /** 页码（从 1 开始） */
    page?: number;
    /** 每页大小 */
    pageSize?: number;
}

/**
 * HTTP 请求配置
 */
export interface RequestOptions {
    /** 请求地址（相对路径） */
    url: string;
    /** 请求方法 */
    method?: "GET" | "POST" | "PUT" | "DELETE";
    /** 请求数据 */
    data?: Record<string, unknown>;
    /** 请求头 */
    header?: Record<string, string>;
    /** 超时时间（毫秒） */
    timeout?: number;
    /** 是否显示 loading */
    showLoading?: boolean;
    /** loading 提示文本 */
    loadingText?: string;
    /** 跳过 token 注入 */
    skipAuth?: boolean;
    /** 无响应体模式 */
    noBody?: boolean;
}

/**
 * API 错误
 */
export class ApiError extends Error {
    constructor(
        public code: number,
        message: string
    ) {
        super(message);
        this.name = "ApiError";
    }
}

// ==================== 用户相关类型 ====================

/**
 * 用户信息
 */
export interface UserInfo {
    /** 用户 ID */
    id: string;
    /** 用户名 */
    username: string;
    /** 昵称 */
    nickname: string;
    /** 头像 URL */
    avatar?: string;
    /** 邮箱 */
    email?: string;
    /** 手机号 */
    phone?: string;
    /** 性别：0-未知 1-男 2-女 */
    gender?: 0 | 1 | 2;
    /** 部门 ID */
    departmentId?: string;
    /** 部门名称 */
    departmentName?: string;
    /** 角色列表 */
    roles?: RoleInfo[];
    /** 状态：0-禁用 1-启用 */
    status: 0 | 1;
    /** 创建时间 */
    createdAt?: string;
    /** 更新时间 */
    updatedAt?: string;
}

/**
 * 角色信息
 */
export interface RoleInfo {
    /** 角色 ID */
    id: string;
    /** 角色名称 */
    name: string;
    /** 角色标识 */
    code: string;
}

/**
 * 登录参数
 */
export interface LoginParams {
    /** 用户名 */
    username: string;
    /** 密码 */
    password: string;
}

/**
 * 登录结果
 */
export interface LoginResult {
    /** 访问令牌 */
    accessToken: string;
    /** 刷新令牌 */
    refreshToken: string;
    /** 过期时间（秒） */
    expiresIn: number;
    /** 用户信息 */
    userInfo: UserInfo;
}

// ==================== 通用业务类型 ====================

/**
 * 字典项
 */
export interface DictItem {
    /** 字典值 */
    value: string | number;
    /** 字典标签 */
    label: string;
    /** 排序号 */
    sort?: number;
    /** 备注 */
    remark?: string;
}

/**
 * 树形节点
 */
export interface TreeNode {
    /** 节点 ID */
    id: string;
    /** 父节点 ID */
    parentId?: string;
    /** 节点名称 */
    name: string;
    /** 子节点 */
    children?: TreeNode[];
    /** 是否叶子节点 */
    isLeaf?: boolean;
}

// ==================== 表单验证类型 ====================

/**
 * 表单验证规则
 */
export interface FormRule {
    /** 是否必填 */
    required?: boolean;
    /** 最小长度 */
    min?: number;
    /** 最大长度 */
    max?: number;
    /** 正则表达式 */
    pattern?: RegExp;
    /** 自定义验证函数 */
    validator?: (value: unknown) => boolean | string;
    /** 错误提示 */
    message?: string;
}

/**
 * 表单状态
 */
export type FormStatus = "idle" | "loading" | "success" | "error";

// ==================== 平台相关类型 ====================

/**
 * 设备信息
 */
export interface DeviceInfo {
    /** 设备品牌 */
    brand: string;
    /** 设备型号 */
    model: string;
    /** 设备系统 */
    system: string;
    /** 系统版本 */
    version: string;
    /** 平台类型 */
    platform: "android" | "ios" | "web" | "mp-weixin";
    /** 屏幕宽度 */
    screenWidth: number;
    /** 屏幕高度 */
    screenHeight: number;
    /** 状态栏高度 */
    statusBarHeight?: number;
}

/**
 * 推送消息
 */
export interface PushMessage {
    /** 消息 ID */
    id: string;
    /** 消息标题 */
    title: string;
    /** 消息内容 */
    content: string;
    /** 消息类型 */
    type: "text" | "image" | "link" | "notification";
    /** 跳转链接 */
    url?: string;
    /** 发送时间 */
    timestamp: number;
    /** 是否已读 */
    read?: boolean;
}
