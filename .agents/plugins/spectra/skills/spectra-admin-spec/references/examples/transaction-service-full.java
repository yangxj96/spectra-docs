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

package com.devops00.spectra.example.service;

import com.devops00.spectra.example.javabean.from.ExampleFullFrom;

import java.util.UUID;

/**
 * 需要同库原子提交的组合应用用例示例。
 *
 * <p>本接口配合 transaction-full.java 说明组合事务，不扩展通用 CRUD。
 * 实际契约仍需明确两项输入校验、授权、读取版本和失败结果。</p>
 *
 * @author yangxj96
 * @version 1.0
 * @since 2026/10/03
 */
public interface ExampleFullTransactionService {

    /**
     * 将创建及编辑作为同一原子单元提交。
     *
     * @param id      编辑目标
     * @param created 创建字段
     * @param updated 完整编辑字段与读取版本
     */
    void createdAndModify(UUID id, ExampleFullFrom created, ExampleFullFrom updated);
}
