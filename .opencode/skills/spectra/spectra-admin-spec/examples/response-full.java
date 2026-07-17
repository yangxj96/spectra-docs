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

package com.devops00.spectra.example.javabean.vo;

import lombok.Data;

import java.time.LocalDateTime;

/// 详情视图对象完整示例
///
/// 注意：
/// 1. VO 用于响应数据封装
/// 2. 统一后缀 VO
/// 3. 使用 @Data 注解
/// 4. 包路径：javabean/vo/
/// 5. 与 Entity 分开定义，职责单一
///
/// @author yangxj96
/// @version 1.0
/// @since 2026/7/18
@Data
public class ExampleFullDetailVO {

    /// 示例ID
    private String id;

    /// 示例名称
    private String name;

    /// 示例编码
    private String code;

    /// 描述
    private String description;

    /// 是否激活
    private Boolean active;

    /// 创建时间
    private LocalDateTime createdAt;

    /// 更新时间
    private LocalDateTime updatedAt;
}
