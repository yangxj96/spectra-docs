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

/// 版本控制完整示例
///
/// 注意：
/// 1. Mapping 注解中统一 version = "1.0.0+"
/// 2. 版本号格式：主版本.次版本.修订号
/// 3. "+" 表示兼容该版本及更高版本
/// 4. 使用 @Slf4j 注解
///
/// @author yangxj96
/// @version 1.0
/// @since 2026/7/18
@Slf4j
@RestController
@RequestMapping("/version-full-example")
public class VersionFullExampleController {

    /// 版本控制接口示例
    @ULog("'获取版本数据'")
    @GetMapping(value = "/data", version = "1.0.0+")
    @PreAuthorize("isAuthenticated()")
    public String versionedEndpoint() {
        return "版本数据";
    }

    /// 不同版本的接口示例
    @ULog("'获取V1版本数据'")
    @GetMapping(value = "/data", version = "1.0.0")
    @PreAuthorize("isAuthenticated()")
    public String v1Endpoint() {
        return "V1版本数据";
    }

    @ULog("'获取V2版本数据'")
    @GetMapping(value = "/data", version = "2.0.0")
    @PreAuthorize("isAuthenticated()")
    public String v2Endpoint() {
        return "V2版本数据";
    }
}
