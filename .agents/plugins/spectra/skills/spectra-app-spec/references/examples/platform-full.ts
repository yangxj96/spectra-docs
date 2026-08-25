/**
 * 平台抽象入口示例。
 * 实际项目按 platform-abstraction.md 拆分为 types.ts、index.ts 和平台实现文件。
 */

import type { PermissionApi } from "./types";

let api: PermissionApi;

// #ifdef APP-ANDROID || APP-HARMONY
import { permissionApi as androidApi } from "./android";
api = androidApi;
// #endif

// #ifdef WEB
import { permissionApi as webApi } from "./web";
api = webApi;
// #endif

/** 业务代码只依赖这个统一能力，不直接接触 plus 或条件编译。 */
export const permission = api;
