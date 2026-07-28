---
tags:
  - plan
  - architecture
  - backend
  - frontend
---

# P-全栈架构修复计划

## 状态

**已完成**

> 状态变更时间：2026-07-25

## 问题背景

对后端（spectra-admin）和前端（spectra-ui / spectra-app）进行架构审查，发现以下问题：

| 严重度 | 问题 | 所属项目 |
|---|---|---|
| 🔴 严重 | `crypto-api.ts` 状态访问器导致基础设施层→API 层循环依赖 | spectra-ui |
| 🟡 中等 | `NotificationApi` 返回类型声明错误（`IResult<T>` 应为 `T`） | spectra-ui |
| 🟡 中等 | `spectra-common` 依赖过重（kaptcha/tika/redis 不应在公共层） | spectra-admin |
| 🟡 中等 | 存储 key 三处重复定义，`STORAGE_KEYS` 为死代码 | spectra-app |
| 🟡 中等 | 分页类型定义跨项目不一致 | 跨项目 |
| 🟢 低 | `sass` 放在 dependencies 而非 devDependencies | spectra-ui |
| 🟢 低 | 组件命名规范局部不一致（Profile/Monitor） | spectra-ui |
| 🟢 低 | `FileUpload` 全局组件与页面局部组件同名 | spectra-ui |
| 🟢 低 | 缓存无 TTL/淘汰机制 | spectra-ui |
| 🟢 低 | 路由守卫取消所有请求（含后台任务） | spectra-ui |
| 🟢 低 | `package.json` name 仍为模板默认值 | spectra-app |
| 🟢 低 | `lint-staged` 配置错误（eslint 全项目执行） | spectra-app |
| 🟢 低 | 文件名拼写错误 `shime-uni.d.ts` | spectra-app |
| 🟢 低 | `platform/crypto/index.ts` 含死代码 | spectra-app |
| 🟢 低 | `form-api.ts` 内联重复定义 `IPage<T>` | spectra-ui |
| ℹ️ 信息 | 加密工具代码跨项目重复（暂不抽取，标记待办） | 跨项目 |
| ℹ️ 信息 | spectra-app 依赖版本由 uni-app 官方锁定，不可升级 | spectra-app |

## 修复目标

1. 消除 spectra-ui 中基础设施层对 API 层的循环依赖
2. 修正所有错误的 TypeScript 类型声明
3. 减轻后端 `spectra-common` 的依赖负担
4. 消除死代码和重复定义
5. 统一组件命名规范
6. 修复前端工具链配置错误

---

## 详细实现步骤

### 阶段一：前端快速修复（低风险杂项）

> 修复工具链配置、死代码、拼写错误等不影响业务的问题。

#### 1.1 spectra-app：修复 `package.json` name

**操作**：
- 将 `"name": "uni-preset-vue"` 改为 `"name": "spectra-app"`

**文件**：
- `spectra-app/package.json` — 第 2 行

**验证**：
```bash
cd spectra-app && pnpm install --frozen-lockfile
```

#### 1.2 spectra-app：修复 `lint-staged` 配置

**操作**：
- 将 `"eslint . --fix"` 改为 `"eslint --fix"`（去掉 `.`，仅 lint 暂存文件）

**文件**：
- `spectra-app/package.json` — 第 57 行

**验证**：
```bash
cd spectra-app
# 修改任意 .ts 文件并 git add，然后：
npx lint-staged --dry-run
# 确认输出中 eslint 命令不带 "." 参数
```

#### 1.3 spectra-app：修复文件名拼写错误

**操作**：
- 将 `src/shime-uni.d.ts` 重命名为 `src/shim-uni.d.ts`
- 检查 `tsconfig.json` 中是否引用了该文件名，如有则同步更新

**文件**：
- `spectra-app/src/shime-uni.d.ts` → `spectra-app/src/shim-uni.d.ts`
- `spectra-app/tsconfig.json` — 检查 include 配置

**验证**：
```bash
cd spectra-app && pnpm run type-check
```

#### 1.4 spectra-app：移除 `platform/crypto/index.ts` 死代码

**操作**：
- 删除 `createCryptoPlatform()` 函数（第 10-18 行），该函数从未被调用

**文件**：
- `spectra-app/src/platform/crypto/index.ts` — 删除第 10-18 行

**验证**：
```bash
cd spectra-app && pnpm run type-check && pnpm run lint
```

#### 1.5 spectra-app：整合存储 key 定义

**操作**：
- 删除 `src/utils/storage.ts` 中的 `STORAGE_KEYS` 常量（第 9-15 行，死代码）
- 将 `src/stores/app.ts` 中 `clearAuth()` 的硬编码字符串 `"token"` / `"refresh_token"` 替换为 `config/env.ts` 中的 `STORAGE_KEY_TOKEN` / `STORAGE_KEY_REFRESH_TOKEN`

**文件**：
- `spectra-app/src/utils/storage.ts` — 删除 `STORAGE_KEYS` 常量
- `spectra-app/src/stores/app.ts` — 第 43-44 行，导入并使用 `STORAGE_KEY_TOKEN`、`STORAGE_KEY_REFRESH_TOKEN`

**验证**：
```bash
cd spectra-app && pnpm run type-check && pnpm run lint
# 全局搜索确认无遗漏：
rg '"token"' spectra-app/src/ --include="*.ts" --include="*.vue"
rg '"refresh_token"' spectra-app/src/ --include="*.ts" --include="*.vue"
```

#### 1.6 spectra-ui：将 `sass` 移至 devDependencies

**操作**：
- 将 `"sass": "1.97.3"` 从 `dependencies` 移至 `devDependencies`

**文件**：
- `spectra-ui/package.json` — 第 77 行移至 devDependencies

**验证**：
```bash
cd spectra-ui && pnpm install && pnpm run build
# 构建成功即说明 sass 作为 devDependency 可正常工作
```

#### 1.7 spectra-app：升级 vue-tsc 修复 Node 24 兼容性

**操作**：
- 将 `"vue-tsc": "~2.0.0"` 升级为 `"vue-tsc": "2.2.12"`（vue-tsc 不受 uni-app 约束）
- 修复升级后暴露的 3 个类型错误：
  - `buildUrl` 和 `RequestOptions.data` 参数拓宽为 `Record<string, unknown>`
  - `PageRequest`、`PasswordLoginRequest`、`SmsLoginRequest`、`EmailLoginRequest` 从 `interface` 改为 `type`（type alias 有隐式索引签名）
  - `onLoad` 回调参数改为可选

**文件**：
- `spectra-app/package.json` — vue-tsc 版本
- `spectra-app/src/services/http.ts` — `buildUrl` 参数类型
- `spectra-app/src/types/request.ts` — `RequestOptions.data` 和 `PageRequest` 类型
- `spectra-app/src/types/user.ts` — 登录请求类型改为 type alias
- `spectra-app/src/services/request.ts` — helper 函数参数类型
- `spectra-app/src/services/api/auth.ts` — 移除多余断言
- `spectra-app/src/pages/login/index.vue` — `onLoad` 参数可选

**验证**：
```bash
cd spectra-app && pnpm run type-check && pnpm run lint
```

---

### 阶段二：spectra-ui 分层修复（crypto-api 循环依赖）

> 消除 `plugin/request/http.ts`（基础设施层）对 `api/system/crypto-api.ts`（API 层）的依赖。

#### 2.1 将状态访问器移入 `use-crypto-store.ts`

**操作**：
- 在 `use-crypto-store.ts` 中新增三个 getter 函数导出：
  ```typescript
  export function isCryptoEnabled(): boolean {
      return useCryptoStore().enabled;
  }
  export function getServerPublicKey(): string | null {
      return useCryptoStore().server_public_key;
  }
  export function getClientPrivateKey(): string | null {
      return useCryptoStore().client_private_key;
  }
  ```

**文件**：
- `spectra-ui/src/plugin/store/modules/use-crypto-store.ts` — 末尾追加三个导出函数

**验证**：
```bash
cd spectra-ui && pnpm run type-check
```

#### 2.2 更新 `http.ts` 的 import 来源

**操作**：
- 将第 3 行：
  ```typescript
  import { isCryptoEnabled, getServerPublicKey, getClientPrivateKey } from "@/api/system/crypto-api";
  ```
  改为：
  ```typescript
  import { isCryptoEnabled, getServerPublicKey, getClientPrivateKey } from "@/plugin/store/modules/use-crypto-store";
  ```

**文件**：
- `spectra-ui/src/plugin/request/http.ts` — 第 3 行

**验证**：
```bash
cd spectra-ui && pnpm run type-check
```

#### 2.3 更新 `router/index.ts` 的 import 来源

**操作**：
- 将第 3 行：
  ```typescript
  import { fetchClientPrivateKey, getClientPrivateKey, isCryptoEnabled } from "@/api/system/crypto-api.ts";
  ```
  拆分为两个 import：
  ```typescript
  import { fetchClientPrivateKey } from "@/api/system/crypto-api.ts";
  import { getClientPrivateKey, isCryptoEnabled } from "@/plugin/store/modules/use-crypto-store.ts";
  ```

**文件**：
- `spectra-ui/src/plugin/router/index.ts` — 第 3 行

**验证**：
```bash
cd spectra-ui && pnpm run type-check
```

#### 2.4 清理 `crypto-api.ts` 中的状态访问器

**操作**：
- 删除 `crypto-api.ts` 中的 `isCryptoEnabled()`、`getServerPublicKey()`、`getClientPrivateKey()` 三个函数（第 9-19 行）
- 删除不再需要的 `useCryptoStore` import（如果 `initCrypto` 和 `fetchClientPrivateKey` 仍需要则保留）
- 全局搜索确认无其他文件从 `crypto-api.ts` 导入这三个函数

**文件**：
- `spectra-ui/src/api/system/crypto-api.ts` — 删除第 5-19 行（注释 + 三个函数）

**验证**：
```bash
cd spectra-ui
rg "from.*crypto-api" src/ --include="*.ts" --include="*.vue"
# 确认无文件再从 crypto-api 导入 isCryptoEnabled/getServerPublicKey/getClientPrivateKey
pnpm run type-check && pnpm run lint
```

#### 2.5 端到端验证

**验证**：
```bash
cd spectra-ui && pnpm run type-check && pnpm run lint && pnpm run test
# 启动开发服务器，手动验证：
# 1. 登录流程正常（token 获取）
# 2. 加解密功能正常（如果已启用）
# 3. 页面切换正常
```

---

### 阶段三：spectra-ui 类型修复

> 修正错误的 TypeScript 类型声明。

#### 3.1 修复 `NotificationApi` 返回类型

**操作**：
- `request()` 函数内部已解包 `IResult`，直接返回 `data` 字段
- 将所有方法的返回类型从 `Promise<IResult<T>>` 改为 `Promise<T>`：
  - `list()`: `Promise<IResult<Page<Notification>>>` → `Promise<Page<Notification>>`
  - `unreadCount()`: `Promise<IResult<number>>` → `Promise<number>`
  - `markAsRead()`: `Promise<IResult<void>>` → `Promise<void>`
  - `markAllAsRead()`: `Promise<IResult<void>>` → `Promise<void>`
  - `delete()`: `Promise<IResult<void>>` → `Promise<void>`
  - `batchDelete()`: `Promise<IResult<void>>` → `Promise<void>`
- 同步修改泛型参数：`get<IResult<Page<Notification>>>` → `get<Page<Notification>>` 等

**文件**：
- `spectra-ui/src/api/notification/notification-api.ts` — 全部 6 个方法

**验证**：
```bash
cd spectra-ui && pnpm run type-check
# 检查 use-notification-store.ts 中的调用是否类型匹配：
rg "NotificationApi" src/ --include="*.ts" --include="*.vue"
```

#### 3.2 修复 `form-api.ts` 内联重复类型

**操作**：
- 删除 `form-api.ts` 中内联定义的 `IPage<T>` 接口
- 将使用 `IPage<T>` 的地方替换为全局 `Page<T>` 类型（来自 `types/paging.d.ts`）
- 检查字段映射是否一致（`IPage` 的字段名应与 `Page` 一致：records/total/size/current）

**文件**：
- `spectra-ui/src/api/workflow/form-api.ts` — 删除 `IPage<T>` 定义，替换引用为 `Page<T>`

**验证**：
```bash
cd spectra-ui && pnpm run type-check && pnpm run lint
```

#### 3.3 检查其他 API 文件是否有同类问题

**操作**：
- 全局搜索 `Promise<IResult<` 确认无其他 API 文件存在相同的返回类型错误

**验证**：
```bash
cd spectra-ui
rg "Promise<IResult<" src/api/ --include="*.ts"
# 应返回 0 结果
```

---

### 阶段四：spectra-ui 组件规范修复

> 统一组件目录命名，消除同名冲突。

#### 4.1 修复 `Profile/components/` 扁平文件

**操作**：
- 将扁平 `.vue` 文件改为 `目录/index.vue` 结构：
  - `ProfileBinding.vue` → `ProfileBinding/index.vue`
  - `ProfileInfo.vue` → `ProfileInfo/index.vue`
  - `ProfilePassword.vue` → `ProfilePassword/index.vue`
  - `ProfileSettings.vue` → `ProfileSettings/index.vue`
- 更新 `Profile/index.vue` 中的 import 路径

**文件**：
- `spectra-ui/src/views/Profile/components/` — 4 个文件重组为 4 个目录
- `spectra-ui/src/views/Profile/index.vue` — 更新 import 路径

**验证**：
```bash
cd spectra-ui && pnpm run type-check && pnpm run lint
# 启动开发服务器，访问个人中心页面确认渲染正常
```

#### 4.2 修复 `Monitor/Task/components/Edit.vue` 命名

**操作**：
- 将 `Edit.vue` 改为 `TaskEdit/index.vue`（添加模块前缀 + 目录结构）
- 更新 `Monitor/Task/index.vue` 中的 import 路径

**文件**：
- `spectra-ui/src/views/Monitor/Task/components/Edit.vue` → `spectra-ui/src/views/Monitor/Task/components/TaskEdit/index.vue`
- `spectra-ui/src/views/Monitor/Task/index.vue` — 更新 import

**验证**：
```bash
cd spectra-ui && pnpm run type-check && pnpm run lint
```

#### 4.3 解决 `FileUpload` 同名冲突

**操作**：
- 将 `views/System/Storage/components/FileUpload/` 重命名为 `views/System/Storage/components/StorageUpload/`
- 更新 `Storage/index.vue` 中的 import 路径和组件注册名

**文件**：
- `spectra-ui/src/views/System/Storage/components/FileUpload/` → `StorageUpload/`
- `spectra-ui/src/views/System/Storage/index.vue` — 更新 import

**验证**：
```bash
cd spectra-ui && pnpm run type-check && pnpm run lint
# 启动开发服务器，访问存储管理页面确认上传组件正常
```

---

### 阶段五：spectra-ui 缓存与路由优化

> 改善请求缓存和路由切换时的请求管理。

#### 5.1 为缓存添加 TTL 机制

**操作**：
- 改造 `cache.ts`，为每个缓存条目添加过期时间：
  ```typescript
  interface CacheEntry {
      data: unknown;
      expiresAt: number;
  }
  const cache = new Map<string, CacheEntry>();
  const DEFAULT_TTL = 5 * 60 * 1000; // 默认 5 分钟

  export function getCache<T>(key: string): T | undefined {
      const entry = cache.get(key);
      if (!entry) return undefined;
      if (Date.now() > entry.expiresAt) {
          cache.delete(key);
          return undefined;
      }
      return entry.data as T;
  }

  export function setCache(key: string, value: unknown, ttl = DEFAULT_TTL) {
      cache.set(key, { data: value, expiresAt: Date.now() + ttl });
  }
  ```
- 保持 `clearCache()` 不变

**文件**：
- `spectra-ui/src/plugin/request/cache.ts` — 重写

**验证**：
```bash
cd spectra-ui && pnpm run type-check && pnpm run test
```

#### 5.2 路由守卫请求取消策略优化

**操作**：
- 在 `http.ts` 中为 `request()` 添加 `persistent?: boolean` 选项，标记为 persistent 的请求不会被 `cancelAllRequests()` 取消
- 修改 `cancelAllRequests()` 跳过 persistent 请求
- 在 `RequestOptions` 类型中添加 `persistent` 字段

**文件**：
- `spectra-ui/src/plugin/request/http.ts` — 修改 `cancelAllRequests()` 和 `request()`
- `spectra-ui/types/http.d.ts` — `RequestOptions` 添加 `persistent?: boolean`

**验证**：
```bash
cd spectra-ui && pnpm run type-check && pnpm run test
# 手动测试：页面切换时，标记为 persistent 的请求不被取消
```

---

### 阶段六：后端 common 模块依赖瘦身

> 将不属于公共基础层的依赖上移至实际使用模块。

#### 6.1 将 `kaptcha` 从 common 移至 framework

**操作**：
- 从 `spectra-common/pom.xml` 删除 kaptcha 依赖（第 65-74 行）
- 在 `spectra-framework/pom.xml` 添加 kaptcha 依赖
- 确认 common 模块中无 Java 代码 import kaptcha 的类
- 确认 `KaptchaException` 等异常类不依赖 kaptcha 库（仅使用自定义消息）

**文件**：
- `spectra-admin/spectra-common/pom.xml` — 删除 kaptcha 依赖
- `spectra-admin/spectra-framework/pom.xml` — 添加 kaptcha 依赖

**验证**：
```bash
cd spectra-admin && ./mvnw clean compile -DskipTests
# 确认编译通过，无 ClassNotFoundException
```

#### 6.2 将 `tika-core` 从 common 移至 upload

**操作**：
- 从 `spectra-common/pom.xml` 删除 tika-core 依赖（第 61-63 行）
- 在 `spectra-modules/spectra-upload/pom.xml` 添加 tika-core 依赖
- 确认 common 模块中无 Java 代码 import tika 的类
- 确认仅 upload 模块的 `TikaValidationStrategy.java` 使用 tika

**文件**：
- `spectra-admin/spectra-common/pom.xml` — 删除 tika-core 依赖
- `spectra-admin/spectra-modules/spectra-upload/pom.xml` — 添加 tika-core 依赖

**验证**：
```bash
cd spectra-admin && ./mvnw clean compile -DskipTests
```

#### 6.3 评估 Redis 依赖位置

**操作**：
- 检查 common 模块中哪些类使用了 Redis（搜索 `import org.springframework.data.redis`）
- 如果仅 `RedisCacheKey` 常量类使用（不依赖 Redis API），则可将 `spring-boot-starter-data-redis` 移至 framework
- 如果 common 中有类直接使用 `RedisTemplate` 等 API，则保留不动

**文件**：
- `spectra-admin/spectra-common/pom.xml` — 可能删除 redis 依赖
- `spectra-admin/spectra-framework/pom.xml` — 可能添加 redis 依赖（已有，需确认）

**验证**：
```bash
cd spectra-admin
rg "import org.springframework.data.redis" spectra-common/src/ --include="*.java"
# 根据结果决定是否移动
./mvnw clean compile -DskipTests
```

#### 6.4 将 `bouncycastle` 从 common 移至 framework

**操作**：
- 检查 common 模块中哪些类使用了 bouncycastle
- 如果仅被 framework 层的加解密 Advice 使用，则移至 framework
- 如果 common 的 `AESUtils`/`RSAUtils` 使用，则保留

**文件**：
- `spectra-admin/spectra-common/pom.xml` — 可能删除 bcprov 依赖
- `spectra-admin/spectra-framework/pom.xml` — 可能添加 bcprov 依赖

**验证**：
```bash
cd spectra-admin
rg "import org.bouncycastle" spectra-common/src/ --include="*.java"
rg "import org.bouncycastle" spectra-framework/src/ --include="*.java"
./mvnw clean compile -DskipTests
```

#### 6.5 完整构建验证

**验证**：
```bash
cd spectra-admin && ./mvnw clean package -DskipTests
# 确认全部模块编译打包成功
./mvnw test
# 运行全部测试
```

---

### 阶段七：跨项目一致性整理

> 统一两个前端项目的类型定义和命名约定（不涉及依赖升级）。

#### 7.1 统一分页类型命名

**操作**：
- 检查 `spectra-app/src/types/request.ts` 中的 `PageResponse<T>` 定义
- 如果字段名与后端实际返回不一致（`list` vs `records`），修正为与后端一致
- 在 `spectra-app/src/types/request.ts` 中添加注释说明与 spectra-ui `Page<T>` 的对应关系

**文件**：
- `spectra-app/src/types/request.ts` — 修正 `PageResponse<T>` 字段名（如需要）

**验证**：
```bash
cd spectra-app && pnpm run type-check && pnpm run lint
```

#### 7.2 记录环境变量命名约定

**操作**：
- 在 `docs/20-前端/10-spectra-ui.md` 和 `docs/20-前端/20-spectra-app.md` 中补充说明：
  - spectra-ui 使用 `VITE_API_URL`（带尾部 `/`）
  - spectra-app 使用 `VITE_API_BASE_URL`（无尾部 `/`）
  - 这是两个项目的既定约定，不强制统一（uni-app 和 Vite SPA 的 base URL 处理逻辑不同）

**文件**：
- `docs/20-前端/10-spectra-ui.md` — 补充环境变量说明
- `docs/20-前端/20-spectra-app.md` — 补充环境变量说明

**验证**：
- 文档审查，确认描述准确

#### 7.3 标记加密代码重复为技术债务

**操作**：
- 在 `docs/20-前端/10-spectra-ui.md` 的加解密说明章节末尾添加技术债务备注：
  > ⚠️ 技术债务：`utils/crypto/` 下的 `aes-utils.ts`、`rsa-utils.ts`、`crypto-utils.ts` 与 spectra-app 中完全重复。未来应抽取为共享包 `@spectra/crypto`。

**文件**：
- `docs/20-前端/10-spectra-ui.md` — 添加技术债务备注
- `docs/20-前端/20-spectra-app.md` — 添加同样的备注

**验证**：
- 文档审查

---

## 验证方案

### 每阶段验证

每个阶段结束后执行对应的验证命令（见各步骤的"验证"部分）。

### 全量回归验证

所有阶段完成后，执行全量验证：

```bash
# 后端
cd spectra-admin && ./mvnw clean package -DskipTests && ./mvnw test

# spectra-ui
cd spectra-ui && pnpm run type-check && pnpm run lint && pnpm run test && pnpm run build

# spectra-app
cd spectra-app && pnpm run type-check && pnpm run lint
```

### 手动验证清单

- [ ] spectra-ui 登录流程正常
- [ ] spectra-ui 加解密功能正常（如已启用）
- [ ] spectra-ui 通知功能正常（列表/未读数/已读/删除）
- [ ] spectra-ui 个人中心页面渲染正常
- [ ] spectra-ui 存储管理页面上传组件正常
- [ ] spectra-ui 监控-定时任务页面编辑弹窗正常
- [ ] spectra-ui 页面切换时 Loading 正常显示/隐藏
- [ ] spectra-app 登录流程正常
- [ ] spectra-app 加解密功能正常（H5 平台）
- [ ] 后端全部 API 正常响应

## 影响范围

| 项目 | 变更文件数 | 主要变更 |
|---|---|---|
| spectra-ui | ~15 | 分层修复、类型修正、组件重组、缓存改造 |
| spectra-app | ~6 | 配置修复、死代码清理、存储 key 整合 |
| spectra-admin | ~4-6 | common 依赖瘦身（POM 调整） |
| docs | ~2 | 技术债务标记、环境变量约定 |

## 不纳入本次计划

| 问题 | 原因 |
|---|---|
| spectra-app 依赖版本升级 | uni-app 官方锁定依赖版本，升级会导致兼容性问题 |
| 加密工具抽取为共享包 | 用户决定暂不抽取，已标记为技术债务 |
| Example 视图删除 | 用户决定保留作为开发参考 |
| spectra-launch parent POM 调整 | 风险高收益低，当前设计可正常工作 |
| spectra-modules 父 POM 依赖细化 | 需要逐模块评估，工作量大，可后续单独处理 |

## 相关

- [[00-项目总览]] — 系统架构总览
- [[10-架构分层]] — 后端 Maven 多模块架构
- [[10-spectra-ui]] — Web 前端详情
- [[20-spectra-app]] — 移动端详情
- [[15-后端开发规范]] — 后端编码规范
- [[90-计划/spectra-ui/P-前端规范性修复计划]] — 前端规范修复（Props/Emits/目录命名）
