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
import com.devops00.spectra.framework.persistence.base.BaseServiceImpl;
import com.devops00.spectra.framework.persistence.pagination.PageFrom;
import com.devops00.spectra.common.exception.DataNotExistException;
import com.devops00.spectra.common.exception.DataSaveException;
import com.devops00.spectra.common.exception.EntityUpdateException;
import com.devops00.spectra.example.javabean.converter.ExampleFullConverter;
import com.devops00.spectra.example.javabean.entity.ExampleFullEntity;
import com.devops00.spectra.example.javabean.from.ExampleFullFrom;
import com.devops00.spectra.example.javabean.query.ExampleFullQuery;
import com.devops00.spectra.example.javabean.vo.ExampleFullVO;
import com.devops00.spectra.example.mapper.ExampleFullMapper;
import com.devops00.spectra.example.service.ExampleFullService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

import java.time.Clock;
import java.time.Instant;
import java.util.UUID;

/**
 * 实体 CRUD 持久化结构示例
 *
 * <p>采用时必须落实 Service 操作/数据范围授权、有效 Clock 配置、版本冲突错误映射和实际协议验证。
 * 本片段不代表这些治理能力已实现；审计按入口与用例责任明确，不重复记录同一动作。</p>
 *
 * 注意：
 * <ol>
 * <li>实体 CRUD 示例继承 BaseServiceImpl 并实现接口；编排服务采用组合</li>
 * <li>必须加 @Slf4j、@Service</li>
 * <li>用例需要同库原子提交时使用 @Transactional，外部副作用按独立契约处理</li>
 * <li>异常消息统一中文</li>
 * <li>使用 Converter 进行对象转换</li>
 * <li>记录安全的操作结果；授权/数据范围必须在访问前落实，避免重复错误日志</li>
 * </ol>
 *
 * @author yangxj96
 * @version 1.0
 * @since 2026/7/18
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class ExampleFullServiceImpl extends BaseServiceImpl<ExampleFullMapper, ExampleFullEntity>
        implements ExampleFullService {

    private final ExampleFullConverter exampleConverter;
    private final Clock clock;

    @Override
    public IPage<ExampleFullVO> page(PageFrom page, ExampleFullQuery params) {
        // 实际用例先落实授权范围、分页预算和排序白名单。
        var wrapper = new LambdaQueryWrapper<ExampleFullEntity>();
        wrapper.isNull(ExampleFullEntity::getDeleted);
        if (StringUtils.hasText(params.getName())) {
            wrapper.like(ExampleFullEntity::getName, params.getName());
        }
        if (params.getActive() != null) {
            wrapper.eq(ExampleFullEntity::getActive, params.getActive());
        }
        wrapper.orderByDesc(ExampleFullEntity::getCreatedAt);
        var result = this.page(page.toPage(), wrapper);
        var voPage = new Page<ExampleFullVO>(result.getCurrent(), result.getSize(), result.getTotal());
        voPage.setRecords(result.getRecords().stream().map(exampleConverter::toVO).toList());
        return voPage;
    }

    @Override
    public ExampleFullVO getDetail(UUID id) {
        var entity = this.getById(id);
        if (entity == null || entity.getDeleted() != null) {
            throw new DataNotExistException("示例不存在");
        }
        return exampleConverter.toVO(entity);
    }

    @Override
    @Transactional
    public void created(ExampleFullFrom from) {
        var entity = exampleConverter.toEntity(from);
        if (!this.save(entity)) {
            throw new DataSaveException("创建示例失败");
        }
        log.info("创建示例成功: id={}", entity.getId());
    }

    @Override
    @Transactional
    public void modify(UUID id, ExampleFullFrom from) {
        var entity = this.getById(id);
        if (entity == null || entity.getDeleted() != null) {
            throw new DataNotExistException("示例不存在");
        }
        // 必需输入校验在入口执行；这里保留客户端读取版本，不使用数据库新版本。
        exampleConverter.updateEntity(from, entity);
        entity.setVersion(from.getVersion());
        if (!this.updateById(entity)) {
            // 目标统一异常映射必须区分版本冲突为 HTTP 409 / 稳定 error_code。
            throw new EntityUpdateException("记录已变化，请刷新后重试");
        }
        log.info("更新示例成功: id={}", id);
    }

    @Override
    @Transactional
    public void deleteById(UUID id) {
        var entity = this.getById(id);
        if (entity == null || entity.getDeleted() != null) {
            throw new DataNotExistException("示例不存在");
        }
        entity.setDeleted(Instant.now(clock));
        if (!this.updateById(entity)) {
            throw new EntityUpdateException("记录已变化，请刷新后重试");
        }
        log.info("删除示例成功: id={}", id);
    }
}
