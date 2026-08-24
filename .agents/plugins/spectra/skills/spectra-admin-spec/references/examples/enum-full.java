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

package com.devops00.spectra.example.enums;

import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 枚举完整示例
 *
 * 注意：
 * <ol>
 * <li>枚举使用 @Getter 注解</li>
 * <li>使用 @AllArgsConstructor 注解</li>
 * <li>常量使用大写下划线命名</li>
 * <li>命名优先使用明确的领域名；仅在语义需要时使用 XxxEnum 后缀</li>
 * <li>使用 @Getter 和 @AllArgsConstructor 注解</li>
 * <li>本系统控制的封闭状态、类型、渠道和动作不得使用魔法字符串</li>
 * </ol>
 *
 * @author yangxj96
 * @version 1.0
 * @since 2026/7/18
 */
@Getter
@AllArgsConstructor
public enum ExampleFullEnum {

    ACTIVE(1, "激活"),
    INACTIVE(0, "未激活");

    private final Integer code;
    private final String description;
}
