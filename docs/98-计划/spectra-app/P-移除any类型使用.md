---
tags:
  - plan
  - spectra-app
  - typescript
  - in-progress
---

# P-移除any类型使用

## 状态

**已完成** - 2026-07-16 执行完毕

## 问题背景

spectra-app 项目中存在 **36 处** `any` 类型使用，分布在 **8 个文件**中。这些 `any` 使用降低了代码的类型安全性，违反了项目的 ESLint `no-any` 规则。

### 使用统计

| 分类 | 数量 | 占比 |
|---|---|---|
| 泛型默认值 `<T = any>` | 16 | 44.4% |
| 参数类型 `: any` | 11 | 30.6% |
| `Record<string, any>` | 6 | 16.7% |
| `Promise<any>` | 2 | 5.6% |
| `as any` | 1 | 2.8% |

## 修复目标

1. 消除所有 `any` 类型使用（`env.d.ts` 除外，行业惯例可接受）
2. 替换为具体类型或 `unknown` 类型
3. 通过 ESLint `no-any` 规则检查
4. 通过 TypeScript 类型检查

## 详细实现步骤

### 阶段一：新增类型定义

#### 1.1 创建推送消息类型

**操作**：
- 新建 `src/types/push.ts` 文件
- 定义 `PushMessagePayload` 和 `PushMessageResult` 接口

**文件**：
- `src/types/push.ts` — 新建

```typescript
export interface PushMessagePayload {
    type: string;
    data?: Record<string, unknown>;
    [key: string]: unknown;
}

export interface PushMessageResult {
    type: "click" | "receive";
    data: PushMessagePayload;
}
```

### 阶段二：高优先级修复

#### 2.1 修复 catch 块中的 `any`（3 处）

**操作**：
- 将 `catch (err: any)` 改为 `catch (err: unknown)`
- 添加类型守卫检查

**文件**：
- `src/pages/login/index.vue` — 第 129 行、第 198 行
- `src/services/http.ts` — 第 353 行

**修复方案**：
```typescript
// 修复前
catch (err: any) {
    uni.showToast({ title: err.msg || t("login.failed"), icon: "none" });
}

// 修复后
catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    uni.showToast({ title: msg || t("login.failed"), icon: "none" });
}
```

#### 2.2 修复 `as any` 强制转换（2 处）

**操作**：
- 将 `method as any` 改为类型安全的转换
- 重构 `(result as any).data` 赋值方式

**文件**：
- `src/services/http.ts` — 第 311 行、第 352 行

**修复方案**：
```typescript
// 修复前
method: method as any,

// 修复后
method: method as UniApp.RequestOption["method"],
```

```typescript
// 修复前
(result as any).data = await decryptResponse(encrypted);

// 修复后
const decrypted = await decryptResponse(encrypted);
Object.assign(result, { data: decrypted });
```

### 阶段三：中优先级修复

#### 3.1 修复 `Record<string, any>`（6 处）

**操作**：
- 替换为更精确的联合类型

**文件**：
- `src/services/http.ts` — 第 139 行
- `src/services/request.ts` — 第 9、13、17、21、25、172 行
- `src/types/request.ts` — 第 15 行

**修复方案**：
```typescript
// 修复前
data?: Record<string, any>;

// 修复后
data?: Record<string, string | number | boolean | null | undefined>;
```

#### 3.2 修复推送消息相关 `any`（5 处）

**操作**：
- 使用阶段一创建的 `PushMessagePayload` 类型

**文件**：
- `src/helper/push_message/index.ts` — 第 11、30、45、52、68 行

**修复方案**：
```typescript
// 修复前
interface MessageHandler {
    (data: any, type: string): void | Promise<void>;
}

// 修复后
interface MessageHandler {
    (data: PushMessagePayload, type: string): void | Promise<void>;
}
```

### 阶段四：低优先级修复

#### 4.1 修复 `<T = any>` 泛型默认值（16 处）

**操作**：
- 将所有 `<T = any>` 改为 `<T = unknown>`

**文件**：
- `src/services/http.ts` — 第 260、283、385 行
- `src/services/request.ts` — 第 9、13、17、21、47、167 行
- `src/types/request.ts` — 第 31、47 行
- `src/utils/storage.ts` — 第 20、34、67、81 行

#### 4.2 修复其他 `any`（2 处）

**操作**：
- 将 `detail?: any` 改为 `detail?: unknown`
- 将 `(err: any) => void` 改为 `(err: unknown) => void`

**文件**：
- `src/helper/error_handler.ts` — 第 45 行
- `src/services/http.ts` — 第 89、385 行

### 阶段五：跳过处理

#### 5.1 `env.d.ts` 中的 `any`

**操作**：
- 保持不变

**文件**：
- `src/env.d.ts` — 第 6 行

**原因**：这是 Vite/Vue 的标准 shim 文件，`DefineComponent<{}, {}, any>` 是行业惯例，可接受。

## 验证方案

1. **类型检查**：运行 `pnpm type-check` 确保无 TypeScript 错误
2. **代码检查**：运行 `pnpm lint` 确保 ESLint `no-any` 规则通过
3. **功能测试**：启动开发服务器 `pnpm start`，测试关键功能
   - 登录功能
   - 推送消息功能
   - API 请求功能
   - 本地存储功能

## 影响范围

| 文件路径 | 修改数量 | 优先级 |
|---|---|---|
| `src/services/http.ts` | 11 处 | 高 |
| `src/services/request.ts` | 8 处 | 中 |
| `src/pages/login/index.vue` | 3 处 | 高 |
| `src/types/request.ts` | 3 处 | 低 |
| `src/utils/storage.ts` | 4 处 | 低 |
| `src/helper/push_message/index.ts` | 5 处 | 中 |
| `src/helper/error_handler.ts` | 1 处 | 低 |
| `src/types/push.ts` | 新建 | 中 |
| `src/env.d.ts` | 0 处（忽略） | - |

## 相关

- [[20-spectra-app]] — 移动端项目文档