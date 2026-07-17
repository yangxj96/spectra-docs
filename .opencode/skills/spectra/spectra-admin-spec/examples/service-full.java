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

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.devops00.spectra.common.base.BaseService;
import com.devops00.spectra.common.base.javabean.from.PageFrom;
import com.devops00.spectra.example.javabean.entity.ExampleFullEntity;
import com.devops00.spectra.example.javabean.from.ExampleFullFrom;
import com.devops00.spectra.example.javabean.from.ExamplePageFrom;
import com.devops00.spectra.example.javabean.vo.ExampleFullVO;

import java.util.UUID;

/// Service接口完整示例
///
/// 注意：
/// 1. 继承 BaseService<Entity>
/// 2. 禁止直接继承 MyBatis-Plus 的 IService
/// 3. 方法命名规范：created/modify/deleteById/page
/// 4. 返回类型使用具体 VO 类型
/// 5. 使用 @Service 注解
///
/// @author yangxj96
/// @version 1.0
/// @since 2026/7/18
public interface ExampleFullServiceInterface extends BaseService<ExampleFullEntity> {

    /// 分页查询示例列表
    IPage<ExampleFullVO> page(PageFrom page, ExamplePageFrom params);

    /// 查询示例详情
    ExampleFullVO getDetail(UUID id);

    /// 创建示例
    void created(ExampleFullFrom from);

    /// 更新示例
    void modify(UUID id, ExampleFullFrom from);

    /// 删除示例
    void deleteById(UUID id);
}
