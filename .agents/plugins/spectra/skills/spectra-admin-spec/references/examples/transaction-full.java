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

import com.devops00.spectra.example.javabean.from.ExampleFullFrom;
import com.devops00.spectra.example.service.ExampleFullService;
import com.devops00.spectra.example.service.ExampleFullTransactionService;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

/**
 * 同库组合用例的事务结构示例。
 *
 * <p>示范应用接口 + Impl 和语义 Service 组合，不为编排继承实体 CRUD。
 * 两项写入属于同一原子单元，第二项失败时第一项一起回滚；外部操作不自动获得该保证。
 * 实际入口必须执行两组输入约束，并在 Service 落实身份、授权与数据范围。</p>
 *
 * @author yangxj96
 * @version 1.0
 * @since 2026/7/18
 */
@Service
@RequiredArgsConstructor
public class ExampleFullTransactionServiceImpl implements ExampleFullTransactionService {

    private final ExampleFullService exampleService;

    @Override
    @Transactional
    public void createdAndModify(UUID id, ExampleFullFrom created, ExampleFullFrom updated) {
        exampleService.created(created);
        exampleService.modify(id, updated);
    }
}
