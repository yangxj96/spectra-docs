export {};

declare global {
    /**
     * 用户实体
     */
    type User = BaseEntity & {
        /** 用户名 */
        username: string;
        /** 邮箱 */
        email: string;
        /** 手机号 */
        phone?: string;
        /** 头像 */
        avatar?: string;
        /** 状态（0正常 1冻结 2封禁） */
        status: number;
        /** 部门ID */
        department_id?: string;
        /** 角色列表 */
        roles: Role[];
        /** 权限列表 */
        authorities: string[];
    };

    /**
     * 用户VO（响应对象）
     */
    type UserVO = User & {
        /** 部门名称 */
        department_name?: string;
        /** 创建时间 */
        created_at?: string;
    };

    /**
     * 用户保存表单
     */
    type UserSaveFrom = {
        /** 用户ID（编辑时必填） */
        id?: string;
        /** 用户名（必填） */
        username: string;
        /** 邮箱（必填） */
        email: string;
        /** 手机号 */
        phone?: string;
        /** 密码（创建时必填） */
        password?: string;
        /** 部门ID */
        department_id?: string;
        /** 角色ID列表 */
        role_ids?: string[];
    };

    /**
     * 用户分页请求参数
     */
    type UserPageParams = BasePageParams & {
        /** 用户名 */
        username?: string;
        /** 邮箱 */
        email?: string;
        /** 状态 */
        status?: boolean;
        /** 部门ID */
        department_id?: string;
    };

    /**
     * 登录凭证
     */
    type LoginCredentials = {
        /** 用户名 */
        username: string;
        /** 密码 */
        password: string;
    };

    /**
     * Token
     */
    type Token = {
        /** 访问令牌 */
        access_token: string;
        /** 刷新令牌 */
        refresh_token: string;
        /** 过期时间 */
        expires_in: number;
        /** 权限列表 */
        authorities: string[];
        /** 角色列表 */
        roles: Role[];
    };

    /**
     * 角色
     */
    type Role = {
        /** 角色ID */
        id: string;
        /** 角色编码 */
        code: string;
        /** 角色名称 */
        name: string;
    };

    /**
     * 字典项
     */
    type DictItem = {
        /** 主键ID */
        id: string;
        /** 字典组ID */
        gid: string;
        /** 标签 */
        label: string;
        /** 值 */
        value: string;
        /** 排序 */
        sort: number;
        /** 状态（0正常 1禁用） */
        state: number;
        /** 是否默认 */
        default_flag: boolean;
        /** 备注 */
        remark?: string;
    };

    /**
     * 字典组
     */
    type DictGroup = {
        /** 主键ID */
        id: string;
        /** 父级ID */
        pid?: string;
        /** 名称 */
        name: string;
        /** 编码 */
        code: string;
        /** 状态（0正常 1禁用） */
        state: number;
        /** 备注 */
        remark?: string;
        /** 子节点 */
        children?: DictGroup[];
    };
}
