/*
 *  Copyright 2018-2026 yangxj96
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 */

package com.devops00.spectra.example.controller;

import com.devops00.spectra.log.base.annotation.ULog;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/// 权限控制完整示例
///
/// 注意：
/// 1. 所有接口必须加 @PreAuthorize
/// 2. 公开接口用 @PreAuthorize("permitAll()") 显式标注
/// 3. 权限控制用 @PreAuthorize("hasPermission(null, 'MODULE:ACTION')")
/// 4. 角色控制用 @PreAuthorize("hasRole('ROLE_xxx')")
/// 5. 使用 @Slf4j 注解
///
/// @author yangxj96
/// @version 1.0
/// @since 2026/7/18
@Slf4j
@RestController
@RequestMapping("/security-full-example")
public class SecurityFullExampleController {

    /// 公开接口示例
    @ULog("'获取公开数据'")
    @GetMapping(value = "/public", version = "1.0.0+")
    @PreAuthorize("permitAll()")
    public String publicEndpoint() {
        return "公开数据";
    }

    /// 已认证用户接口示例
    @ULog("'获取用户数据'")
    @GetMapping(value = "/authenticated", version = "1.0.0+")
    @PreAuthorize("isAuthenticated()")
    public String authenticatedEndpoint() {
        return "用户数据";
    }

    /// 权限控制接口示例
    @ULog("'获取管理数据'")
    @GetMapping(value = "/admin", version = "1.0.0+")
    @PreAuthorize("hasPermission(null, 'SYSTEM:ADMIN')")
    public String adminEndpoint() {
        return "管理数据";
    }

    /// 角色控制接口示例
    @ULog("'获取开发数据'")
    @GetMapping(value = "/dev", version = "1.0.0+")
    @PreAuthorize("hasRole('ROLE_DEV_OPS')")
    public String devEndpoint() {
        return "开发数据";
    }
}
