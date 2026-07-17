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

package com.devops00.spectra.example.javabean.query;

import lombok.Data;

/// 查询参数对象完整示例
///
/// 注意：
/// 1. Query 用于复杂查询参数
/// 2. 统一后缀 Query
/// 3. 使用 @Data 注解
/// 4. 包路径：javabean/query/
/// 5. 使用 @Data 注解
///
/// @author yangxj96
/// @version 1.0
/// @since 2026/7/18
@Data
public class ExampleFullQuery {

    /// 示例名称（模糊查询）
    private String name;

    /// 是否激活
    private Boolean active;

    /// 开始时间
    private String startTime;

    /// 结束时间
    private String endTime;
}
