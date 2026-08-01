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

package com.devops00.spectra.example.javabean.converter;

import com.devops00.spectra.example.javabean.entity.ExampleFullEntity;
import com.devops00.spectra.example.javabean.from.ExampleFullFrom;
import com.devops00.spectra.example.javabean.vo.ExampleFullVO;
import com.devops00.spectra.framework.configure.mapstruct.GlobalMapperConfig;
import com.devops00.spectra.framework.configure.mapstruct.TimeMapper;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.MappingTarget;

/// MapStruct转换器完整示例
///
/// 注意：
/// 1. 所有模块必须使用 MapStruct Converter 进行对象转换，禁止手动 setter
/// 2. 统一放在 javabean/converter/
/// 3. 引用 GlobalMapperConfig.class 和 TimeMapper.class
/// 4. 使用 @Mapper 注解
/// 5. 提供 toVO、toEntity、updateEntity 方法
///
/// @author yangxj96
/// @version 1.0
/// @since 2026/7/18
@Mapper(uses = TimeMapper.class, config = GlobalMapperConfig.class)
public interface ExampleFullConverter {

    /// 实体转 VO
    ExampleFullVO toVO(ExampleFullEntity source);

    /// From 转实体
    ExampleFullEntity toEntity(ExampleFullFrom source);

    /// 更新已有实体
    void updateEntity(ExampleFullFrom source, @MappingTarget ExampleFullEntity target);
}
