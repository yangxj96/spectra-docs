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

package com.devops00.spectra.common.base.javabean.from;

import lombok.Data;

import java.util.List;

/// 分页请求参数完整示例
///
/// 注意：
/// 1. 分页参数使用 PageFrom
/// 2. 包路径：common.base.javabean.from
/// 3. 使用 @Data 注解
/// 4. 统一分页参数
/// 5. 使用 @Data 注解
///
/// @author yangxj96
/// @version 1.0
/// @since 2026/7/18
@Data
public class PageFromFullExample {

    /// 页码
    private Integer pageNum = 1;

    /// 每页大小
    private Integer pageSize = 10;

    /// 排序字段
    private List<String> orders;
}
