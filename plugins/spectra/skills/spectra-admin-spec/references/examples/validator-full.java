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

/// 校验注解完整示例
///
/// 注意：
/// 1. 必填字段必须加 @NotBlank/@NotNull 等校验注解
/// 2. 提供清晰的中文 message 参数
/// 3. 可选字段不加校验注解
/// 4. 使用 @Data 注解
///
/// @author yangxj96
/// @version 1.0
/// @since 2026/7/18
@Data
public class ValidatorFullExample {

    /// 必填字段 - 使用 @NotBlank
    @NotBlank(message = "用户名不能为空")
    private String username;

    /// 必填字段 - 使用 @NotNull
    @NotNull(message = "年龄不能为空")
    private Integer age;

    /// 必填字段 - 带长度限制
    @NotBlank(message = "密码不能为空")
    @Size(min = 6, max = 20, message = "密码长度必须在6-20之间")
    private String password;

    /// 必填字段 - 邮箱格式
    @NotBlank(message = "邮箱不能为空")
    @Email(message = "邮箱格式不正确")
    private String email;

    /// 可选字段 - 不加校验注解
    private String description;

    /// 可选字段 - 不加校验注解
    private Boolean active;
}
