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

package com.devops00.spectra.common.exception;

/// 自定义异常完整示例
///
/// 注意：
/// 1. 统一使用项目自定义异常，禁止裸 RuntimeException
/// 2. 异常消息统一中文（用户友好）
/// 3. 继承 DataException
/// 4. 提供无参和有参构造函数
///
/// 可用异常类型：
/// - DataNotExistException：数据不存在
/// - DataSaveException：数据保存失败
/// - EntityUpdateException：实体更新失败
/// - BuiltinDataException：内置数据不可操作
/// - DefaultDataException：默认数据不可操作
///
/// @author yangxj96
/// @version 1.0
/// @since 2026/7/18
public class ExampleFullException extends DataException {

    public ExampleFullException() {
        super("示例异常");
    }

    public ExampleFullException(String message) {
        super(message);
    }
}
