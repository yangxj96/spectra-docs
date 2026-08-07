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

package com.devops00.spectra.example.service.impl;

import lombok.extern.slf4j.Slf4j;

/// 日志使用完整示例
///
/// 注意：
/// 1. Controller 层：使用 log.debug() 记录请求入参
/// 2. Service 层：关键业务节点用 log.info()，异常用 log.error()
/// 3. 日志消息使用中文
/// 4. 关键节点必须记录实体 ID
/// 5. 使用 @Slf4j 注解
///
/// @author yangxj96
/// @version 1.0
/// @since 2026/7/18
@Slf4j
public class LogFullExample {

    /// Controller 层日志示例
    public void controllerLogExample() {
        // 使用较低级别 log.debug() 记录请求入参
        log.debug("查询示例列表: name={}, page={}", "test", 1);
    }

    /// Service 层日志示例
    public void serviceLogExample() {
        // 关键业务节点用 log.info()
        log.info("创建示例成功: id={}, name={}", "123", "test");

        // 业务校验失败用 log.warn()
        log.warn("业务校验失败: 原因={}", "名称已存在");

        // 异常用 log.error()
        try {
            // 业务逻辑
        } catch (Exception e) {
            log.error("创建示例失败: 原因={}", e.getMessage(), e);
        }
    }
}
