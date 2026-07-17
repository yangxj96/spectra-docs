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

package com.devops00.spectra.example.runner;

import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

/// 模块启动执行器完整示例
///
/// 注意：
/// 1. 使用 @Component 注解
/// 2. 实现 ApplicationRunner 接口
/// 3. 在应用启动后执行
/// 4. 使用 @Slf4j 注解
///
/// @author yangxj96
/// @version 1.0
/// @since 2026/7/18
@Slf4j
@Component
public class ExampleFullRunner implements ApplicationRunner {

    @Override
    public void run(ApplicationArguments args) {
        log.info("示例模块启动完成");
    }
}
