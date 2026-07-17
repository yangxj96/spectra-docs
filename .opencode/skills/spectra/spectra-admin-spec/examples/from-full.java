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

package com.devops00.spectra.example.javabean.from;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import lombok.Data;

/// From对象完整示例
///
/// 注意：
/// 1. 统一后缀 From（非 Form）
/// 2. 包路径：javabean/from/
/// 3. 必填字段必须加 @NotBlank/@NotNull 等校验注解
/// 4. 使用 @Data 注解
/// 5. 提供清晰的中文 message 参数
///
/// @author yangxj96
/// @version 1.0
/// @since 2026/7/18
@Data
public class ExampleFullFrom {

    /// 示例名称
    @NotBlank(message = "示例名称不能为空")
    private String name;

    /// 示例编码（可选，后端自动生成）
    private String code;

    /// 描述
    private String description;

    /// 是否激活
    @NotNull(message = "激活状态不能为空")
    private Boolean active;

    /// 邮箱
    @NotBlank(message = "邮箱不能为空")
    @Email(message = "邮箱格式不正确")
    private String email;

    /// 密码
    @NotBlank(message = "密码不能为空")
    @Size(min = 6, max = 20, message = "密码长度必须在6-20之间")
    private String password;
}
