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

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.baomidou.mybatisplus.core.metadata.IPage;
import com.baomidou.mybatisplus.extension.plugins.pagination.Page;
import com.devops00.spectra.common.base.BaseServiceImpl;
import com.devops00.spectra.common.base.javabean.from.PageFrom;
import com.devops00.spectra.common.exception.DataNotExistException;
import com.devops00.spectra.common.exception.DataSaveException;
import com.devops00.spectra.example.javabean.converter.ExampleConverter;
import com.devops00.spectra.example.javabean.entity.Example;
import com.devops00.spectra.example.javabean.from.ExampleSaveFrom;
import com.devops00.spectra.example.javabean.from.ExamplePageFrom;
import com.devops00.spectra.example.javabean.vo.ExampleVO;
import com.devops00.spectra.example.mapper.ExampleMapper;
import com.devops00.spectra.example.service.ExampleServiceInterface;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.util.UUID;

/// Service实现完整示例
///
/// 注意：
/// 1. 继承 BaseServiceImpl<Mapper, Entity>，实现对应接口
/// 2. 必须加 @Slf4j、@Service
/// 3. 写操作必须加 @Transactional
/// 4. 异常消息统一中文
/// 5. 使用 Converter 进行对象转换
/// 6. 关键业务节点用 log.info()，异常用 log.error()
///
/// @author yangxj96
/// @version 1.0
/// @since 2026/7/18
@Slf4j
@Service
@RequiredArgsConstructor
public class ExampleServiceFullImpl extends BaseServiceImpl<ExampleMapper, Example>
        implements ExampleServiceInterface {

    private final ExampleConverter exampleConverter;

    @Override
    public IPage<ExampleVO> page(PageFrom page, ExamplePageFrom params) {
        var wrapper = new LambdaQueryWrapper<Example>();
        if (StringUtils.hasText(params.getName())) {
            wrapper.like(Example::getName, params.getName());
        }
        if (params.getActive() != null) {
            wrapper.eq(Example::getActive, params.getActive());
        }
        wrapper.orderByDesc(Example::getCreatedAt);
        var result = this.page(page.toPage(), wrapper);
        var voPage = new Page<ExampleVO>(result.getCurrent(), result.getSize(), result.getTotal());
        voPage.setRecords(result.getRecords().stream().map(exampleConverter::toVO).toList());
        return voPage;
    }

    @Override
    public ExampleVO getDetail(UUID id) {
        var entity = this.getById(id);
        if (entity == null) {
            throw new DataNotExistException("示例不存在");
        }
        return exampleConverter.toVO(entity);
    }

    @Override
    @Transactional
    public void created(ExampleSaveFrom from) {
        var entity = exampleConverter.toEntity(from);
        if (!this.save(entity)) {
            throw new DataSaveException("创建示例失败");
        }
        log.info("创建示例成功: id={}, name={}", entity.getId(), entity.getName());
    }

    @Override
    @Transactional
    public void modify(UUID id, ExampleSaveFrom from) {
        var entity = this.getById(id);
        if (entity == null) {
            throw new DataNotExistException("示例不存在");
        }
        exampleConverter.updateEntity(from, entity);
        if (!this.updateById(entity)) {
            throw new DataSaveException("更新示例失败");
        }
        log.info("更新示例成功: id={}", id);
    }

    @Override
    @Transactional
    public void deleteById(UUID id) {
        var entity = this.getById(id);
        if (entity == null) {
            throw new DataNotExistException("示例不存在");
        }
        if (!this.removeById(id)) {
            throw new DataSaveException("删除示例失败");
        }
        log.info("删除示例成功: id={}", id);
    }
}
