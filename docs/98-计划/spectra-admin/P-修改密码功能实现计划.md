---
tags:
  - plan
  - backend
  - frontend
  - password
---

# P-修改密码功能实现计划

## 状态

**已完成**

> 状态变更时间：2026-07-19

## 问题背景

个人中心页面的修改密码功能当前使用 mock 数据，需要对接后端 API 实现真正的密码修改功能。

## 修复目标

1. 实现修改密码接口
2. 密码强度要求：包含大小写字母、数字、特殊字符
3. 修改成功后自动退出登录
4. 旧密码错误时显示具体错误信息

## 详细实现步骤

### 阶段一：后端 From 对象

#### 1.1 创建 ChangePasswordFrom

**文件**：
- 创建：`spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/javabean/from/ChangePasswordFrom.java`

**代码**：
```java
package com.devops00.spectra.core.user.javabean.from;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/// 修改密码入参
///
/// @author yangxj96
/// @version 1.0
/// @since 2026/7/19
@Data
@AllArgsConstructor
@NoArgsConstructor
public class ChangePasswordFrom {

    /// 旧密码
    @NotBlank(message = "旧密码不能为空")
    private String old_password;

    /// 新密码
    @NotBlank(message = "新密码不能为空")
    @Size(min = 6, max = 20, message = "密码长度必须在6-20位之间")
    @Pattern(
        regexp = "^(?=.*[a-z])(?=.*[A-Z])(?=.*\\d)(?=.*[@$!%*?&])[A-Za-z\\d@$!%*?&]{6,20}$",
        message = "密码必须包含大小写字母、数字和特殊字符（@$!%*?&）"
    )
    private String new_password;

    /// 确认密码
    @NotBlank(message = "确认密码不能为空")
    private String verify_password;
}
```

### 阶段二：后端 Service 层

#### 2.1 修改 UserService 接口

**文件**：
- 修改：`spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/service/UserService.java`

**添加内容**：
```java
/// 修改当前用户密码
///
/// @param userId 用户ID
/// @param params 修改密码参数
void changePassword(UUID userId, ChangePasswordFrom params);
```

#### 2.2 修改 UserServiceImpl

**文件**：
- 修改：`spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/service/impl/UserServiceImpl.java`

**添加内容**：
```java
@Override
@Transactional
public void changePassword(UUID userId, ChangePasswordFrom params) {
    // 1. 获取用户
    var user = this.getById(userId);
    if (user == null) {
        throw new DataNotExistException("用户不存在");
    }

    // 2. 获取用户的默认账号
    var account = accountService.getDefaultByUserId(userId);
    if (account == null) {
        throw new DataNotExistException("账号不存在");
    }

    // 3. 验证旧密码
    if (!passwordEncoder.matches(params.getOld_password(), account.getPassword())) {
        throw new SpectraException("旧密码错误");
    }

    // 4. 验证新密码和确认密码是否一致
    if (!params.getNew_password().equals(params.getVerify_password())) {
        throw new SpectraException("两次输入的新密码不一致");
    }

    // 5. 验证新密码不能与旧密码相同
    if (passwordEncoder.matches(params.getNew_password(), account.getPassword())) {
        throw new SpectraException("新密码不能与旧密码相同");
    }

    // 6. 加密新密码并更新
    account.setPassword(passwordEncoder.encode(params.getNew_password()));
    if (!accountService.updateById(account)) {
        throw new EntityUpdateException("修改密码失败");
    }
    log.info("用户 {} 修改密码成功", userId);
}
```

### 阶段三：后端 Controller

#### 3.1 修改 UserController

**文件**：
- 修改：`spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/controller/UserController.java`

**添加内容**：
```java
@ULog("'修改密码'")
@PutMapping(value = "/password", version = "1.0.0+")
@PreAuthorize("isAuthenticated()")
public void changePassword(@Validated @RequestBody ChangePasswordFrom params) {
    UUID userId = SecUtil.getCurrentUserId();
    bindService.changePassword(userId, params);
}
```

### 阶段四：前端 API

#### 4.1 修改 user-api.ts

**文件**：
- 修改：`spectra-ui/src/api/user/user-api.ts`

**添加内容**：
```typescript
/**
 * 修改密码
 * @param params 修改密码参数
 */
async changePassword(params: ChangePasswordFrom): Promise<void> {
    return put<void>("/api/user/password", params);
}

/** 修改密码入参 */
export interface ChangePasswordFrom {
    /** 旧密码 */
    old_password: string;
    /** 新密码 */
    new_password: string;
    /** 确认密码 */
    verify_password: string;
}
```

### 阶段五：前端页面

#### 5.1 修改 ProfilePassword.vue

**文件**：
- 修改：`spectra-ui/src/views/Profile/components/ProfilePassword.vue`

**代码**：
```vue
<script setup lang="ts">
import { Lock } from "@element-plus/icons-vue";
import { ElMessage } from "element-plus";
import type { FormInstance } from "element-plus";
import { ref } from "vue";

import { UserApi, type ChangePasswordFrom } from "@/api/user/user-api";

defineOptions({
    name: "ProfilePassword"
});

const formRef = ref<FormInstance>();
const loading = ref(false);

const passwordForm = ref<ChangePasswordFrom>({
    old_password: "",
    new_password: "",
    verify_password: ""
});

// 密码强度验证
const validatePassword = (_rule: unknown, value: string, callback: (error?: Error) => void) => {
    if (!value) {
        callback(new Error("请输入新密码"));
    } else if (value.length < 6 || value.length > 20) {
        callback(new Error("密码长度必须在6-20位之间"));
    } else if (!/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])/.test(value)) {
        callback(new Error("密码必须包含大小写字母、数字和特殊字符"));
    } else {
        callback();
    }
};

// 确认密码验证
const validateVerifyPassword = (_rule: unknown, value: string, callback: (error?: Error) => void) => {
    if (!value) {
        callback(new Error("请再次输入新密码"));
    } else if (value !== passwordForm.value.new_password) {
        callback(new Error("两次输入的密码不一致"));
    } else {
        callback();
    }
};

const rules = {
    old_password: [{ required: true, message: "请输入旧密码", trigger: "blur" }],
    new_password: [{ required: true, validator: validatePassword, trigger: "blur" }],
    verify_password: [{ required: true, validator: validateVerifyPassword, trigger: "blur" }]
};

async function handleChangePassword() {
    if (!formRef.value) return;
    await formRef.value.validate(async (valid) => {
        if (!valid) return;
        loading.value = true;
        try {
            await UserApi.changePassword(passwordForm.value);
            ElMessage.success("密码修改成功，请重新登录");
            setTimeout(() => {
                window.location.href = "/login";
            }, 1500);
        } catch (error: unknown) {
            const message = error instanceof Error ? error.message : "修改密码失败";
            ElMessage.error(message);
        } finally {
            loading.value = false;
        }
    });
}
</script>

<template>
    <el-form
        ref="formRef"
        :model="passwordForm"
        :rules="rules"
        label-width="100px"
        class="info-form">
        <el-form-item label="旧密码" prop="old_password">
            <el-input
                v-model="passwordForm.old_password"
                type="password"
                show-password
                placeholder="请输入旧密码" />
        </el-form-item>
        <el-form-item label="新密码" prop="new_password">
            <el-input
                v-model="passwordForm.new_password"
                type="password"
                show-password
                placeholder="请输入新密码（6-20位，包含大小写字母、数字、特殊字符）" />
        </el-form-item>
        <el-form-item label="确认密码" prop="verify_password">
            <el-input
                v-model="passwordForm.verify_password"
                type="password"
                show-password
                placeholder="请再次输入新密码" />
        </el-form-item>
        <el-form-item>
            <el-button type="primary" :loading="loading" @click="handleChangePassword">
                <el-icon><Lock /></el-icon>
                修改密码
            </el-button>
        </el-form-item>
    </el-form>
</template>

<style scoped lang="scss">
.info-form {
    max-width: 480px;
    padding: 8px 0;
}
</style>
```

## 验证方案

1. **启动后端服务**
2. **启动前端服务**
3. **测试步骤**：
   - 登录系统
   - 进入个人中心 -> 修改密码
   - 输入旧密码
   - 输入不符合强度要求的新密码，验证前端校验
   - 输入符合条件的新密码，验证修改成功
   - 确认自动退出登录
   - 使用旧密码登录，验证已修改

## 影响范围

### 后端
- `spectra-core/user/javabean/from/ChangePasswordFrom.java` (新建)
- `spectra-core/user/service/UserService.java` (修改)
- `spectra-core/user/service/impl/UserServiceImpl.java` (修改)
- `spectra-core/user/controller/UserController.java` (修改)

### 前端
- `spectra-ui/src/api/user/user-api.ts` (修改)
- `spectra-ui/src/views/Profile/components/ProfilePassword.vue` (修改)

## 相关

- [[20-用户与权限]] — 用户权限域详解
