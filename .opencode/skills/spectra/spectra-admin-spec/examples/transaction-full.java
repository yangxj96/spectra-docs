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

package com.devops00.spectra.example.service.impl;

import com.devops00.spectra.common.base.BaseServiceImpl;
import com.devops00.spectra.common.exception.DataNotExistException;
import com.devops00.spectra.common.exception.DataSaveException;
import com.devops00.spectra.example.javabean.entity.ExampleFullEntity;
import com.devops00.spectra.example.javabean.from.ExampleFullFrom;
import com.devops00.spectra.example.mapper.ExampleFullMapper;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

/// 事务处理完整示例
///
/// 注意：
/// 1. 写操作必须加 @Transactional
/// 2. 异常消息统一中文
/// 3. 使用自定义异常，禁止裸 RuntimeException
/// 4. 使用 @Slf4j 注解
/// 5. 使用 @Service 注解
///
/// @author yangxj96
/// @version 1.0
/// @since 2026/7/18
@Slf4j
@Service
public class TransactionFullExample extends BaseServiceImpl<ExampleFullMapper, ExampleFullEntity> {

    /// 事务处理示例
    @Transactional
    public void transactionExample(UUID id, ExampleFullFrom from) {
        // 1. 查询实体
        var entity = this.getById(id);
        if (entity == null) {
            throw new DataNotExistException("示例不存在");
        }

        // 2. 更新实体
        entity.setName(from.getName());
        if (!this.updateById(entity)) {
            throw new DataSaveException("更新示例失败");
        }

        // 3. 记录日志
        log.info("更新示例成功: id={}", id);
    }

    /// 事务传播示例
    @Transactional
    public void propagationExample() {
        // 事务传播：内部方法会加入外部事务
        this.innerMethod();
    }

    @Transactional
    public void innerMethod() {
        // 内部方法
    }
}
