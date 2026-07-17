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

package com.devops00.spectra.example.constant;

/// 常量类完整示例
///
/// 注意：
/// 1. 常量类使用 final 修饰
/// 2. 私有构造函数
/// 3. 常量使用 static final 修饰
/// 4. 命名：XxxConstants
/// 5. 使用 final 修饰类
///
/// @author yangxj96
/// @version 1.0
/// @since 2026/7/18
public final class ExampleFullConstants {

    private ExampleFullConstants() {
        // 私有构造函数
    }

    /// 默认最大连接数
    public static final int DEFAULT_MAX_CONNECTIONS = 100;

    /// 默认超时时间（秒）
    public static final int DEFAULT_TIMEOUT = 30;
}
