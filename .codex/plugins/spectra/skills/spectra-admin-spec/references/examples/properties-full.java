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

package com.devops00.spectra.example.properties;

import lombok.Data;
import org.springframework.boot.context.properties.ConfigurationProperties;

/// 模块配置属性完整示例
///
/// 注意：
/// 1. 配置属性类放在 properties/ 包下
/// 2. 使用 @ConfigurationProperties 注解
/// 3. 使用 @Data 注解
/// 4. 提供默认值
/// 5. 使用 @ConfigurationProperties 注解
///
/// @author yangxj96
/// @version 1.0
/// @since 2026/7/18
@Data
@ConfigurationProperties(prefix = "spectra.example.full")
public class ExampleFullProperties {

    /// 是否启用
    private Boolean enabled = true;

    /// 最大连接数
    private Integer maxConnections = 100;

    /// 超时时间（秒）
    private Integer timeout = 30;
}
