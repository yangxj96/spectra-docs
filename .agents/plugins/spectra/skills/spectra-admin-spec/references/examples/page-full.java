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

package com.devops00.spectra.example.javabean.from;

import com.devops00.spectra.framework.persistence.pagination.PageFrom;
import lombok.Data;
import lombok.EqualsAndHashCode;

/**
 * 复用真实分页参数的业务查询示例。
 *
 * <p>分页基础契约以 Framework PageFrom 为准，不复制一份不同的 orders 模型。
 * 用例必须校验分页预算、排序白名单并在分页/统计前落实数据范围。</p>
 *
 * @author yangxj96
 * @version 1.0
 * @since 2026/7/18
 */
@Data
@EqualsAndHashCode(callSuper = true)
public class PageFromFullExample extends PageFrom {

    /**
     * 可选名称筛选。
     */
    private String name;
}
