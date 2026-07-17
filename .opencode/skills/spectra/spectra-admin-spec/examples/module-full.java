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

package com.devops00.spectra.example;

import org.mybatis.spring.annotation.MapperScan;
import org.springframework.context.annotation.ComponentScan;

/// 模块入口类完整示例
///
/// 注意：
/// 1. 每个业务模块必须有一个 Module 入口类
/// 2. @ComponentScan 扫描当前模块包路径
/// 3. @MapperScan 扫描当前模块 Mapper 包路径
/// 4. 使用 @ComponentScan 和 @MapperScan 注解
///
/// @author yangxj96
/// @version 1.0
/// @since 2026/7/18
@ComponentScan("com.devops00.spectra.example")
@MapperScan("com.devops00.spectra.example.**.mapper")
public class ExampleFullModule {
}
