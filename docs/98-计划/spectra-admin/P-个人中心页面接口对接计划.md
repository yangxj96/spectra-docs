---
tags:
  - plan
  - backend
  - frontend
  - user
  - profile
---

# P-个人中心页面接口对接计划

## 状态

**已完成**

> 状态变更时间：2026-07-19

## 问题背景

个人中心页面（左侧面板和基本资料）当前使用硬编码数据，需要对接后端 API 实现：
- 左侧面板：显示当前用户的真实姓名、部门名称、角色列表、用户名、邮箱、手机号
- 基本资料：编辑并保存用户信息

## 修复目标

1. 实现获取当前用户详情接口（包含部门名称、角色列表）
2. 实现更新当前用户信息接口
3. 前端对接后端 API

## 详细实现步骤

### 阶段一：后端 VO/From 对象

#### 1.1 创建 UserProfileVO

**操作**：创建当前用户详情响应 VO

**文件**：
- 创建：`spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/javabean/vo/UserProfileVO.java`

**代码**：
```java
package com.devops00.spectra.core.user.javabean.vo;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.io.Serial;
import java.io.Serializable;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

/// 当前用户详情响应VO
///
/// @author yangxj96
/// @version 1.0
/// @since 2026/7/19
@Data
@AllArgsConstructor
@NoArgsConstructor
public class UserProfileVO implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    /// 用户ID
    private UUID id;

    /// 用户名
    private String username;

    /// 真实姓名
    private String realName;

    /// 头像
    private String avatar;

    /// 状态
    private Short status;

    /// 性别
    private Short gender;

    /// 生日
    private LocalDate birthday;

    /// 手机号
    private String phone;

    /// 邮箱
    private String email;

    /// 国家
    private String country;

    /// 城市
    private String city;

    /// 语言
    private String language;

    /// 时区
    private String timezone;

    /// 部门ID
    private UUID departmentId;

    /// 部门名称
    private String departmentName;

    /// 角色列表
    private List<RoleVO> roles;
}
```

#### 1.2 创建 UserProfileFrom

**操作**：创建更新当前用户信息入参

**文件**：
- 创建：`spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/javabean/from/UserProfileFrom.java`

**代码**：
```java
package com.devops00.spectra.core.user.javabean.from;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.time.LocalDate;

/// 更新当前用户信息入参
///
/// @author yangxj96
/// @version 1.0
/// @since 2026/7/19
@Data
@AllArgsConstructor
@NoArgsConstructor
public class UserProfileFrom {

    /// 真实姓名
    private String realName;

    /// 性别
    private Short gender;

    /// 生日
    private LocalDate birthday;

    /// 手机号
    private String phone;

    /// 邮箱
    private String email;

    /// 国家
    private String country;

    /// 城市
    private String city;

    /// 语言
    private String language;

    /// 时区
    private String timezone;
}
```

### 阶段二：后端 Service 层

#### 2.1 修改 UserService 接口

**操作**：在 UserService 接口中添加新方法定义

**文件**：
- 修改：`spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/service/UserService.java`

**添加内容**：
```java
/// 获取当前用户详情
///
/// @param userId 用户ID
/// @return 用户详情
UserProfileVO getProfile(UUID userId);

/// 更新当前用户信息
///
/// @param userId 用户ID
/// @param params 更新参数
void updateProfile(UUID userId, UserProfileFrom params);
```

**添加 import**：
```java
import com.devops00.spectra.core.user.javabean.from.UserProfileFrom;
import com.devops00.spectra.core.user.javabean.vo.UserProfileVO;
```

#### 2.2 修改 UserServiceImpl

**操作**：在 UserServiceImpl 中实现新方法

**文件**：
- 修改：`spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/service/impl/UserServiceImpl.java`

**添加内容**：
```java
@Override
public UserProfileVO getProfile(UUID userId) {
    var user = this.getById(userId);
    if (user == null) {
        throw new DataNotExistException("用户不存在");
    }
    var vo = userConverter.toProfileVO(user);
    // 填充部门名称
    if (user.getDepartmentId() != null) {
        var dept = departmentService.getById(user.getDepartmentId());
        if (dept != null) {
            vo.setDepartmentName(dept.getName());
        }
    }
    // 填充角色列表
    var roles = relUserRoleService.getRoles(userId);
    if (roles != null && !roles.isEmpty()) {
        vo.setRoles(roles.stream().map(roleConverter::toVO).toList());
    }
    return vo;
}

@Override
@Transactional
public void updateProfile(UUID userId, UserProfileFrom params) {
    var user = this.getById(userId);
    if (user == null) {
        throw new DataNotExistException("用户不存在");
    }
    userConverter.updateProfile(params, user);
    if (this.baseMapper.updateById(user) == 0) {
        throw new EntityUpdateException("更新用户信息失败");
    }
}
```

**添加 import**：
```java
import com.devops00.spectra.common.exception.DataNotExistException;
import com.devops00.spectra.common.exception.EntityUpdateException;
import com.devops00.spectra.core.user.javabean.from.UserProfileFrom;
import com.devops00.spectra.core.user.javabean.vo.UserProfileVO;
import org.springframework.transaction.annotation.Transactional;
```

### 阶段三：后端 Controller

#### 3.1 修改 UserController

**操作**：在 UserController 中添加新接口

**文件**：
- 修改：`spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/controller/UserController.java`

**添加内容**：
```java
@ULog("'获取当前用户详情'")
@GetMapping(value = "/profile", version = "1.0.0+")
@PreAuthorize("isAuthenticated()")
public UserProfileVO getProfile() {
    UUID userId = SecUtil.getCurrentUserId();
    return bindService.getProfile(userId);
}

@ULog("'更新当前用户信息'")
@PutMapping(value = "/profile", version = "1.0.0+")
@PreAuthorize("isAuthenticated()")
public void updateProfile(@Validated @RequestBody UserProfileFrom params) {
    UUID userId = SecUtil.getCurrentUserId();
    bindService.updateProfile(userId, params);
}
```

**添加 import**：
```java
import com.devops00.spectra.core.user.javabean.from.UserProfileFrom;
import com.devops00.spectra.core.user.javabean.vo.UserProfileVO;
import com.devops00.spectra.security.base.holder.SecUtil;
import java.util.UUID;
```

### 阶段四：前端 API

#### 4.1 修改 user-api.ts

**操作**：在 user-api.ts 中添加新方法和类型

**文件**：
- 修改：`spectra-ui/src/api/user/user-api.ts`

**添加类型**：
```typescript
/** 当前用户详情 */
export interface UserProfileVO {
    /** 用户ID */
    id: string;
    /** 用户名 */
    username: string;
    /** 真实姓名 */
    realName: string;
    /** 头像 */
    avatar: string;
    /** 状态 */
    status: number;
    /** 性别 */
    gender: number;
    /** 生日 */
    birthday: string;
    /** 手机号 */
    phone: string;
    /** 邮箱 */
    email: string;
    /** 国家 */
    country: string;
    /** 城市 */
    city: string;
    /** 语言 */
    language: string;
    /** 时区 */
    timezone: string;
    /** 部门ID */
    departmentId: string;
    /** 部门名称 */
    departmentName: string;
    /** 角色列表 */
    roles: RoleInfo[];
}

/** 角色信息 */
export interface RoleInfo {
    /** 角色ID */
    id: string;
    /** 角色名称 */
    name: string;
    /** 角色编码 */
    code: string;
}

/** 更新用户信息入参 */
export interface UserProfileFrom {
    /** 真实姓名 */
    realName: string;
    /** 性别 */
    gender: number;
    /** 生日 */
    birthday: string;
    /** 手机号 */
    phone: string;
    /** 邮箱 */
    email: string;
    /** 国家 */
    country: string;
    /** 城市 */
    city: string;
    /** 语言 */
    language: string;
    /** 时区 */
    timezone: string;
}
```

**添加方法**：
```typescript
/**
 * 获取当前用户详情
 */
async getProfile(): Promise<UserProfileVO> {
    return get<UserProfileVO>("/api/user/profile");
},

/**
 * 更新当前用户信息
 * @param params 用户信息
 */
async updateProfile(params: UserProfileFrom): Promise<void> {
    return put<void>("/api/user/profile", params);
}
```

### 阶段五：前端页面

#### 5.1 修改 Profile/index.vue

**操作**：调用 getProfile 加载用户信息

**文件**：
- 修改：`spectra-ui/src/views/Profile/index.vue`

**修改 script 部分**：
```typescript
<script setup lang="ts">
import { onMounted, ref } from "vue";
import { UserApi, type UserProfileVO } from "@/api/user/user-api";

import avatar from "@/assets/images/avatar.png";

import ProfileBinding from "./components/ProfileBinding.vue";
import ProfileInfo from "./components/ProfileInfo.vue";
import ProfilePassword from "./components/ProfilePassword.vue";
import ProfileSettings from "./components/ProfileSettings.vue";

defineOptions({
    name: "Profile"
});

const activeTab = ref("info");

const userInfo = ref<UserProfileVO>({
    id: "",
    username: "",
    realName: "",
    avatar: "",
    status: 1,
    gender: 0,
    birthday: "",
    phone: "",
    email: "",
    country: "",
    city: "",
    language: "",
    timezone: "",
    departmentId: "",
    departmentName: "",
    roles: []
});

async function loadUserProfile() {
    try {
        const profile = await UserApi.getProfile();
        userInfo.value = profile;
    } catch (error) {
        console.error("加载用户信息失败:", error);
    }
}

onMounted(() => {
    loadUserProfile();
});
</script>
```

**修改 template 部分**：
```vue
<el-avatar :src="userInfo.avatar || avatar" :size="100" class="avatar-image" />
<h3 class="username">{{ userInfo.realName || userInfo.username }}</h3>
<p class="department">{{ userInfo.departmentName }}</p>
<div class="role-tags">
    <el-tag v-for="role in userInfo.roles" :key="role.id" size="small" type="info">
        {{ role.name }}
    </el-tag>
</div>
<el-divider />
<div class="info-list">
    <div class="info-item">
        <span class="info-label">用户名</span>
        <span class="info-value">{{ userInfo.username }}</span>
    </div>
    <div class="info-item">
        <span class="info-label">邮箱</span>
        <span class="info-value">{{ userInfo.email }}</span>
    </div>
    <div class="info-item">
        <span class="info-label">手机</span>
        <span class="info-value">{{ userInfo.phone }}</span>
    </div>
</div>
```

#### 5.2 修改 ProfileInfo.vue

**操作**：调用 updateProfile 保存用户信息

**文件**：
- 修改：`spectra-ui/src/views/Profile/components/ProfileInfo.vue`

**修改 script 部分**：
```typescript
<script setup lang="ts">
import { Check } from "@element-plus/icons-vue";
import { ref } from "vue";
import { ElMessage } from "element-plus";

import DictSelect from "@/components/DictSelect/index.vue";
import { UserApi, type UserProfileFrom } from "@/api/user/user-api";

defineOptions({
    name: "ProfileInfo"
});

const userInfo = defineModel<ProfileUserInfo>("userInfo", { required: true });
const loading = ref(false);

async function handleSaveInfo() {
    loading.value = true;
    try {
        const params: UserProfileFrom = {
            realName: userInfo.value.real_name,
            gender: userInfo.value.gender,
            birthday: userInfo.value.birthday,
            phone: userInfo.value.phone,
            email: userInfo.value.email,
            country: userInfo.value.country,
            city: userInfo.value.city,
            language: userInfo.value.language,
            timezone: userInfo.value.timezone
        };
        await UserApi.updateProfile(params);
        ElMessage.success("保存成功");
    } catch (error: unknown) {
        const message = error instanceof Error ? error.message : "保存失败";
        ElMessage.error(message);
    } finally {
        loading.value = false;
    }
}
</script>
```

**修改 template 中的按钮**：
```vue
<el-form-item>
    <el-button type="primary" :loading="loading" @click="handleSaveInfo">
        <el-icon><Check /></el-icon>
        保存
    </el-button>
</el-form-item>
```

## 验证方案

1. **启动后端服务**：
   ```bash
   cd spectra-admin
   ./mvnw spring-boot:run -pl spectra-launch
   ```

2. **启动前端服务**：
   ```bash
   cd spectra-ui
   pnpm start
   ```

3. **测试步骤**：
   - 登录系统
   - 进入个人中心
   - 验证左侧面板显示正确的用户信息
   - 修改基本资料表单
   - 点击保存
   - 刷新页面验证数据已保存

## 影响范围

### 后端
- `spectra-core/user/javabean/vo/UserProfileVO.java` (新建)
- `spectra-core/user/javabean/from/UserProfileFrom.java` (新建)
- `spectra-core/user/service/UserService.java` (修改)
- `spectra-core/user/service/impl/UserServiceImpl.java` (修改)
- `spectra-core/user/controller/UserController.java` (修改)

### 前端
- `spectra-ui/src/api/user/user-api.ts` (修改)
- `spectra-ui/src/views/Profile/index.vue` (修改)
- `spectra-ui/src/views/Profile/components/ProfileInfo.vue` (修改)

## 相关

- [[20-用户与权限]] — 用户权限域详解
- [[10-ER图]] — 实体关系图
