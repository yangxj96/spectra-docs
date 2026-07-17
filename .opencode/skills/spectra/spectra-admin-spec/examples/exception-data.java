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

/// 自定义异常类型示例
///
/// 注意：
/// 1. 统一使用项目自定义异常，禁止裸 RuntimeException
/// 2. 异常消息统一中文（用户友好）
/// 3. 继承 DataException
///
/// @author yangxj96
/// @version 1.0
/// @since 2026/7/18
public class ExceptionExamples {

    /// 数据不存在异常
    /// 使用场景：查询/更新/删除时实体不存在
    /// 示例：throw new DataNotExistException("表单定义不存在");
    public void dataNotExistExample() {
        throw new DataNotExistException("表单定义不存在");
    }

    /// 数据保存失败异常
    /// 使用场景：insert/update 操作失败
    /// 示例：throw new DataSaveException("创建表单定义失败");
    public void dataSaveExample() {
        throw new DataSaveException("创建表单定义失败");
    }

    /// 实体更新失败异常
    /// 使用场景：updateById 返回 false
    /// 示例：throw new EntityUpdateException("实体更新异常");
    public void entityUpdateExample() {
        throw new EntityUpdateException("实体更新异常");
    }

    /// 内置数据不可操作异常
    /// 使用场景：删除/修改系统内置数据
    /// 示例：throw new BuiltinDataException("内置角色,不可删除");
    public void builtinDataExample() {
        throw new BuiltinDataException("内置角色,不可删除");
    }

    /// 默认数据不可操作异常
    /// 使用场景：删除默认角色/用户等
    /// 示例：throw new DefaultDataException("默认用户,不可删除");
    public void defaultDataExample() {
        throw new DefaultDataException("默认用户,不可删除");
    }
}
