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

package com.devops00.spectra.example.utils;

/// 工具类完整示例
///
/// 注意：
/// 1. 工具类使用 final 修饰
/// 2. 私有构造函数
/// 3. 方法使用 static 修饰
/// 4. 命名：XxxUtils
/// 5. 使用 final 修饰类
///
/// @author yangxj96
/// @version 1.0
/// @since 2026/7/18
public final class ExampleFullUtils {

    private ExampleFullUtils() {
        // 私有构造函数
    }

    /// 示例方法
    public static String formatName(String name) {
        if (name == null || name.isBlank()) {
            return "未命名";
        }
        return name.trim();
    }
}
