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
import com.devops00.spectra.framework.serialization.mapper.GlobalMapperConfig;
import com.devops00.spectra.framework.serialization.mapper.TimeMapper;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;
import org.mapstruct.MappingTarget;
import org.mapstruct.NullValuePropertyMappingStrategy;

/**
 * MapStruct转换器完整示例
 *
 * 注意：
 * <ol>
 * <li>复用结构映射；确需手写组装有明确职责，业务校验与数据库访问另行处理</li>
 * <li>统一放在 javabean/converter/</li>
 * <li>引用 GlobalMapperConfig.class 和 TimeMapper.class</li>
 * <li>使用 @Mapper 注解</li>
 * <li>提供 toVO、toEntity、updateEntity 方法</li>
 * </ol>
 *
 * @author yangxj96
 * @version 1.0
 * @since 2026/7/18
 */
@Mapper(uses = TimeMapper.class, config = GlobalMapperConfig.class)
public interface ExampleFullConverter {

    /**
     * 实体转 VO
     */
    ExampleFullVO toVO(ExampleFullEntity source);

    /**
     * From 转实体
     */
    @Mapping(target = "id", ignore = true)
    @Mapping(target = "createdBy", ignore = true)
    @Mapping(target = "createdAt", ignore = true)
    @Mapping(target = "updatedBy", ignore = true)
    @Mapping(target = "updatedAt", ignore = true)
    @Mapping(target = "deleted", ignore = true)
    @Mapping(target = "version", ignore = true)
    ExampleFullEntity toEntity(ExampleFullFrom source);

    /**
     * 更新已有实体
     */
    @Mapping(target = "id", ignore = true)
    @Mapping(target = "createdBy", ignore = true)
    @Mapping(target = "createdAt", ignore = true)
    @Mapping(target = "updatedBy", ignore = true)
    @Mapping(target = "updatedAt", ignore = true)
    @Mapping(target = "deleted", ignore = true)
    @Mapping(target = "version", source = "version")
    @Mapping(target = "code", nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.SET_TO_NULL)
    @Mapping(target = "description", nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.SET_TO_NULL)
    void updateEntity(ExampleFullFrom source, @MappingTarget ExampleFullEntity target);
}
