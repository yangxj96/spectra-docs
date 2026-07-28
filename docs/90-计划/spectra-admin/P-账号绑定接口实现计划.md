---
tags:
  - plan
  - backend
  - frontend
  - auth
---

# P-账号绑定接口实现计划

## 状态

**已完成**

> 状态变更时间：2026-07-19

## 问题背景

当前前端个人中心页面（ProfileBinding.vue）使用 mock 数据展示账号绑定列表，需要对接后端 API 实现真正的绑定/解绑功能。用户希望能够：
- 查看已绑定的登录方式列表
- 绑定新的手机号（通过验证码）
- 绑定新的邮箱（通过验证码）
- 解绑非密码登录的账号

## 修复目标

1. 实现获取用户绑定列表接口
2. 实现绑定手机号功能（含验证码验证）
3. 实现绑定邮箱功能（含验证码验证）
4. 实现解绑账号功能（密码登录不可解绑）
5. 前端对接后端 API，替换 mock 数据

## 详细实现步骤

### 阶段一：后端 From 对象

#### 1.1 创建 BindPhoneFrom

**操作**：创建绑定手机入参对象

**文件**：
- 创建：`spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/auth/javabean/from/BindPhoneFrom.java`

**代码**：
```java
package com.devops00.spectra.core.auth.javabean.from;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/// 绑定手机入参
///
/// @author yangxj96
/// @version 1.0
/// @since 2026/7/19
@Data
@AllArgsConstructor
@NoArgsConstructor
public class BindPhoneFrom {

    /// 手机号
    @NotBlank(message = "手机号不能为空")
    @Pattern(regexp = "^1[3-9]\\d{9}$", message = "手机号格式不正确")
    private String phone;

    /// 验证码
    @NotBlank(message = "验证码不能为空")
    private String code;
}
```

#### 1.2 创建 BindEmailFrom

**操作**：创建绑定邮箱入参对象

**文件**：
- 创建：`spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/auth/javabean/from/BindEmailFrom.java`

**代码**：
```java
package com.devops00.spectra.core.auth.javabean.from;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

/// 绑定邮箱入参
///
/// @author yangxj96
/// @version 1.0
/// @since 2026/7/19
@Data
@AllArgsConstructor
@NoArgsConstructor
public class BindEmailFrom {

    /// 邮箱
    @NotBlank(message = "邮箱不能为空")
    @Email(message = "邮箱格式不正确")
    private String email;

    /// 验证码
    @NotBlank(message = "验证码不能为空")
    private String code;
}
```

### 阶段二：后端 VO 对象

#### 2.1 创建 AccountVO

**操作**：创建账号绑定响应 VO 对象

**文件**：
- 创建：`spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/auth/javabean/vo/AccountVO.java`

**代码**：
```java
package com.devops00.spectra.core.auth.javabean.vo;

import com.devops00.spectra.security.base.constant.LoginType;
import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.io.Serial;
import java.io.Serializable;
import java.util.UUID;

/// 账号绑定响应VO
///
/// @author yangxj96
/// @version 1.0
/// @since 2026/7/19
@Data
@AllArgsConstructor
@NoArgsConstructor
public class AccountVO implements Serializable {

    @Serial
    private static final long serialVersionUID = 1L;

    /// 账号ID
    private UUID id;

    /// 登录类型
    private LoginType type;

    /// 登录名称（用户名/手机号/邮箱）
    private String loginName;

    /// 状态（1:正常 2:禁用 3:未验证）
    private Short status;

    /// 是否已验证（0:未验证 1:已验证）
    private Short verified;

    /// 是否为当前登录方式
    private Boolean current;
}
```

### 阶段三：Service 层

#### 3.1 扩展 AccountService 接口

**操作**：在 AccountService 接口中添加新方法定义

**文件**：
- 修改：`spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/auth/service/AccountService.java`

**添加内容**：
```java
/// 获取用户的所有绑定账号
///
/// @param userId 用户ID
/// @return 账号列表
List<Account> listByUserId(UUID userId);

/// 绑定手机号
///
/// @param userId 用户ID
/// @param phone 手机号
/// @param code 验证码
void bindPhone(UUID userId, String phone, String code);

/// 绑定邮箱
///
/// @param userId 用户ID
/// @param email 邮箱
/// @param code 验证码
void bindEmail(UUID userId, String email, String code);

/// 解绑账号
///
/// @param userId 用户ID
/// @param accountId 账号ID
void unbind(UUID userId, UUID accountId);
```

**添加 import**：
```java
import java.util.List;
```

#### 3.2 实现 AccountService 方法

**操作**：在 AccountServiceImpl 中实现新方法

**文件**：
- 修改：`spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/auth/service/impl/AccountServiceImpl.java`

**添加内容**：
```java
@Override
public List<Account> listByUserId(UUID userId) {
    var wrapper = new LambdaQueryWrapper<Account>()
            .eq(Account::getUserId, userId)
            .orderByAsc(Account::getType);
    return this.list(wrapper);
}

@Override
@Transactional
public void bindPhone(UUID userId, String phone, String code) {
    // 1. 验证手机号是否已被其他用户绑定
    var existingAccount = this.getByPhone(phone);
    if (existingAccount != null && !existingAccount.getUserId().equals(userId)) {
        throw new SpectraException("该手机号已被其他账号绑定");
    }

    // 2. 如果当前用户已绑定该手机号，直接返回
    if (existingAccount != null && existingAccount.getUserId().equals(userId)) {
        return;
    }

    // 3. 创建新的 Account 记录
    var account = new Account();
    account.setUserId(userId);
    account.setType(LoginType.SMS);
    account.setPhone(phone);
    account.setProvider("DEFAULT");
    account.setStatus((short) 1);
    account.setVerified((short) 1);
    if (!this.save(account)) {
        throw new DataSaveException("绑定手机号失败");
    }
    log.info("用户 {} 绑定手机号 {} 成功", userId, phone);
}

@Override
@Transactional
public void bindEmail(UUID userId, String email, String code) {
    // 1. 验证邮箱是否已被其他用户绑定
    var existingAccount = this.getByEmail(email);
    if (existingAccount != null && !existingAccount.getUserId().equals(userId)) {
        throw new SpectraException("该邮箱已被其他账号绑定");
    }

    // 2. 如果当前用户已绑定该邮箱，直接返回
    if (existingAccount != null && existingAccount.getUserId().equals(userId)) {
        return;
    }

    // 3. 创建新的 Account 记录
    var account = new Account();
    account.setUserId(userId);
    account.setType(LoginType.EMAIL);
    account.setEmail(email);
    account.setProvider("DEFAULT");
    account.setStatus((short) 1);
    account.setVerified((short) 1);
    if (!this.save(account)) {
        throw new DataSaveException("绑定邮箱失败");
    }
    log.info("用户 {} 绑定邮箱 {} 成功", userId, email);
}

@Override
@Transactional
public void unbind(UUID userId, UUID accountId) {
    // 1. 查询账号是否存在
    var account = this.getById(accountId);
    if (account == null) {
        throw new DataNotExistException("账号不存在");
    }

    // 2. 校验是否是当前用户的账号
    if (!account.getUserId().equals(userId)) {
        throw new SpectraException("无权操作此账号");
    }

    // 3. 校验是否是密码登录方式（不允许解绑密码登录）
    if (account.getType() == LoginType.PASSWORD) {
        throw new SpectraException("密码登录方式不允许解绑");
    }

    // 4. 校验是否至少保留一个登录方式
    var userAccounts = this.listByUserId(userId);
    if (userAccounts.size() <= 1) {
        throw new SpectraException("至少需要保留一个登录方式");
    }

    // 5. 执行删除
    if (!this.removeById(accountId)) {
        throw new EntityUpdateException("解绑账号失败");
    }
    log.info("用户 {} 解绑账号 {} 成功", userId, accountId);
}
```

**添加 import**：
```java
import com.devops00.spectra.common.exception.DataNotExistException;
import com.devops00.spectra.common.exception.DataSaveException;
import com.devops00.spectra.common.exception.EntityUpdateException;
import com.devops00.spectra.common.exception.SpectraException;
import com.devops00.spectra.security.base.constant.LoginType;
import java.util.List;
```

### 阶段四：Controller 层

#### 4.1 创建 AccountController

**操作**：创建账号绑定控制器

**文件**：
- 创建：`spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/auth/controller/AccountController.java`

**代码**：
```java
package com.devops00.spectra.core.auth.controller;

import com.devops00.spectra.core.auth.javabean.from.BindEmailFrom;
import com.devops00.spectra.core.auth.javabean.from.BindPhoneFrom;
import com.devops00.spectra.core.auth.javabean.vo.AccountVO;
import com.devops00.spectra.core.auth.service.AccountService;
import com.devops00.spectra.log.base.annotation.ULog;
import com.devops00.spectra.security.base.holder.SecUtil;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.UUID;

/// 账号绑定控制器
///
/// @author yangxj96
/// @version 1.0
/// @since 2026/7/19
@Slf4j
@RestController
@RequestMapping("/account")
@RequiredArgsConstructor
public class AccountController {

    private final AccountService accountService;

    /// 获取当前用户绑定的账号列表
    @ULog("'获取账号绑定列表'")
    @GetMapping(value = "/list", version = "1.0.0+")
    @PreAuthorize("isAuthenticated()")
    public List<AccountVO> list() {
        UUID userId = SecUtil.getCurrentUserId();
        var accounts = accountService.listByUserId(userId);
        UUID currentAccountId = SecUtil.getCurrentAccountId();

        return accounts.stream().map(account -> {
            var vo = new AccountVO();
            vo.setId(account.getId());
            vo.setType(account.getType());
            vo.setLoginName(getLoginName(account));
            vo.setStatus(account.getStatus());
            vo.setVerified(account.getVerified());
            vo.setCurrent(account.getId().equals(currentAccountId));
            return vo;
        }).toList();
    }

    /// 绑定手机号
    @ULog("'绑定手机号'")
    @PostMapping(value = "/bindPhone", version = "1.0.0+")
    @PreAuthorize("isAuthenticated()")
    public void bindPhone(@Validated @RequestBody BindPhoneFrom params) {
        UUID userId = SecUtil.getCurrentUserId();
        accountService.bindPhone(userId, params.getPhone(), params.getCode());
    }

    /// 绑定邮箱
    @ULog("'绑定邮箱'")
    @PostMapping(value = "/bindEmail", version = "1.0.0+")
    @PreAuthorize("isAuthenticated()")
    public void bindEmail(@Validated @RequestBody BindEmailFrom params) {
        UUID userId = SecUtil.getCurrentUserId();
        accountService.bindEmail(userId, params.getEmail(), params.getCode());
    }

    /// 解绑账号
    @ULog("'解绑账号'")
    @DeleteMapping(value = "/unbind/{accountId}", version = "1.0.0+")
    @PreAuthorize("isAuthenticated()")
    public void unbind(@PathVariable UUID accountId) {
        UUID userId = SecUtil.getCurrentUserId();
        accountService.unbind(userId, accountId);
    }

    /// 根据账号类型获取显示名称
    private String getLoginName(com.devops00.spectra.core.auth.javabean.entity.Account account) {
        return switch (account.getType()) {
            case PASSWORD -> account.getLoginName();
            case SMS -> account.getPhone();
            case EMAIL -> account.getEmail();
            default -> "";
        };
    }
}
```

### 阶段五：前端 API 模块

#### 5.1 创建 AccountApi

**操作**：创建账号绑定相关 API

**文件**：
- 创建：`spectra-ui/src/api/account/account-api.ts`

**代码**：
```typescript
import { del, get, post } from "@/plugin/request/api.ts";

/**
 * 账号绑定相关接口
 *
 * @author yangxj96
 * @version 1.0
 * @since 2026-07-19
 */
export const AccountApi = {
    /**
     * 获取当前用户绑定的账号列表
     */
    async list(): Promise<AccountVO[]> {
        return get<AccountVO[]>("/api/account/list");
    },

    /**
     * 绑定手机号
     * @param params 手机号和验证码
     */
    async bindPhone(params: { phone: string; code: string }): Promise<void> {
        return post<void>("/api/account/bindPhone", params);
    },

    /**
     * 绑定邮箱
     * @param params 邮箱和验证码
     */
    async bindEmail(params: { email: string; code: string }): Promise<void> {
        return post<void>("/api/account/bindEmail", params);
    },

    /**
     * 解绑账号
     * @param accountId 账号ID
     */
    async unbind(accountId: string): Promise<void> {
        return del<void>(`/api/account/unbind/${accountId}`);
    }
};

/** 账号绑定信息 */
export interface AccountVO {
    /** 账号ID */
    id: string;
    /** 登录类型：PASSWORD/SMS/EMAIL/OTP */
    type: "PASSWORD" | "SMS" | "EMAIL" | "OTP";
    /** 登录名称 */
    loginName: string;
    /** 状态：1-正常 2-禁用 3-未验证 */
    status: number;
    /** 是否已验证：0-未验证 1-已验证 */
    verified: number;
    /** 是否为当前登录方式 */
    current: boolean;
}
```

### 阶段六：前端页面更新

#### 6.1 更新 ProfileBinding.vue

**操作**：将 ProfileBinding.vue 中的 mock 数据替换为真实 API 调用

**文件**：
- 修改：`spectra-ui/src/views/Profile/components/ProfileBinding.vue`

**关键修改**：

1. **导入 API 和类型**：
```typescript
import { AccountApi, type AccountVO } from "@/api/account/account-api";
```

2. **替换 mock 数据**：
```typescript
// 已绑定账号列表
const accountBindings = ref<AccountVO[]>([]);

// 当前登录方式
const currentLoginType = ref("PASSWORD");
const currentLoginName = ref("admin@devops00.com");
```

3. **添加加载函数**：
```typescript
async function loadBindings() {
    try {
        const list = await AccountApi.list();
        accountBindings.value = list;

        // 找到当前登录方式
        const current = list.find(item => item.current);
        if (current) {
            currentLoginType.value = current.type;
            currentLoginName.value = current.loginName;
        }
    } catch (error) {
        console.error("加载绑定列表失败:", error);
    }
}
```

4. **添加绑定手机弹窗逻辑**：
```typescript
const phoneDialogVisible = ref(false);
const phoneForm = ref({ phone: "", code: "" });
const phoneLoading = ref(false);
const phoneCountdown = ref(0);

async function handleSendPhoneCode() {
    // 发送验证码逻辑
}

async function handleBindPhone() {
    // 绑定手机逻辑
    await AccountApi.bindPhone({
        phone: phoneForm.value.phone,
        code: phoneForm.value.code
    });
    loadBindings();
}
```

5. **添加绑定邮箱弹窗逻辑**：
```typescript
const emailDialogVisible = ref(false);
const emailForm = ref({ email: "", code: "" });
const emailLoading = ref(false);
const emailCountdown = ref(0);

async function handleSendEmailCode() {
    // 发送验证码逻辑
}

async function handleBindEmail() {
    // 绑定邮箱逻辑
    await AccountApi.bindEmail({
        email: emailForm.value.email,
        code: emailForm.value.code
    });
    loadBindings();
}
```

6. **添加解绑逻辑**：
```typescript
async function handleUnbind(accountId: string) {
    await ElMessageBox.confirm("确定要解绑该账号吗？", "提示", {
        type: "warning"
    });
    await AccountApi.unbind(accountId);
    loadBindings();
}
```

7. **添加弹窗模板**：
```vue
<!-- 绑定手机弹窗 -->
<el-dialog v-model="phoneDialogVisible" title="绑定手机号" width="400px">
    <el-form :model="phoneForm" label-width="80px">
        <el-form-item label="手机号">
            <el-input v-model="phoneForm.phone" placeholder="请输入手机号" />
        </el-form-item>
        <el-form-item label="验证码">
            <div class="code-input">
                <el-input v-model="phoneForm.code" placeholder="请输入验证码" />
                <el-button :disabled="phoneCountdown > 0" @click="handleSendPhoneCode">
                    {{ phoneCountdown > 0 ? `${phoneCountdown}s` : "获取验证码" }}
                </el-button>
            </div>
        </el-form-item>
    </el-form>
    <template #footer>
        <el-button @click="phoneDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="phoneLoading" @click="handleBindPhone">
            确定
        </el-button>
    </template>
</el-dialog>

<!-- 绑定邮箱弹窗 -->
<el-dialog v-model="emailDialogVisible" title="绑定邮箱" width="400px">
    <el-form :model="emailForm" label-width="80px">
        <el-form-item label="邮箱">
            <el-input v-model="emailForm.email" placeholder="请输入邮箱" />
        </el-form-item>
        <el-form-item label="验证码">
            <div class="code-input">
                <el-input v-model="emailForm.code" placeholder="请输入验证码" />
                <el-button :disabled="emailCountdown > 0" @click="handleSendEmailCode">
                    {{ emailCountdown > 0 ? `${emailCountdown}s` : "获取验证码" }}
                </el-button>
            </div>
        </el-form-item>
    </el-form>
    <template #footer>
        <el-button @click="emailDialogVisible = false">取消</el-button>
        <el-button type="primary" :loading="emailLoading" @click="handleBindEmail">
            确定
        </el-button>
    </template>
</el-dialog>
```

8. **在 onMounted 中加载数据**：
```typescript
onMounted(() => {
    loadBindings();
});
```

9. **添加样式**：
```scss
.code-input {
    display: flex;
    gap: 8px;
    width: 100%;

    .el-input {
        flex: 1;
    }
}
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
   - 进入个人中心 -> 账号绑定
   - 验证已绑定账号列表正确显示
   - 测试绑定手机号功能（输入手机号和验证码）
   - 测试绑定邮箱功能（输入邮箱和验证码）
   - 测试解绑功能（点击解绑按钮，确认后解绑）

4. **测试用例**：
   - 正常绑定手机号
   - 重复绑定手机号（应提示已绑定）
   - 绑定邮箱
   - 重复绑定邮箱（应提示已绑定）
   - 解绑非密码登录账号（应成功）
   - 尝试解绑密码登录（应提示不允许）
   - 尝试解绑最后一个登录方式（应提示至少保留一个）

## 影响范围

### 后端
- `spectra-core/auth/controller/AccountController.java` (新建)
- `spectra-core/auth/service/AccountService.java` (修改)
- `spectra-core/auth/service/impl/AccountServiceImpl.java` (修改)
- `spectra-core/auth/javabean/from/BindPhoneFrom.java` (新建)
- `spectra-core/auth/javabean/from/BindEmailFrom.java` (新建)
- `spectra-core/auth/javabean/vo/AccountVO.java` (新建)

### 前端
- `spectra-ui/src/api/account/account-api.ts` (新建)
- `spectra-ui/src/views/Profile/components/ProfileBinding.vue` (修改)

## 相关

- [[20-用户与权限]] — 用户权限域详解
- [[10-ER图]] — 实体关系图
- [[20-实体清单]] — 实体字段详情

## 注意事项

1. **验证码发送**：当前使用模拟方式，后续需要对接实际的短信/邮件发送服务
2. **SecUtil 方法**：需要确认 SecUtil 是否有 `getCurrentUserId` 和 `getCurrentAccountId` 方法，如没有需要补充
3. **验证码验证**：绑定接口中的验证码验证逻辑需要根据项目现有的 Redis 验证码服务实现
4. **权限控制**：所有接口都需要登录才能访问
