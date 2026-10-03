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

package com.devops00.spectra.example.controller;

import com.baomidou.mybatisplus.core.metadata.IPage;
import com.devops00.spectra.common.base.Verify;
import com.devops00.spectra.framework.persistence.pagination.PageFrom;
import com.devops00.spectra.common.audit.Audit;
import com.devops00.spectra.example.javabean.from.ExampleFullFrom;
import com.devops00.spectra.example.javabean.query.ExampleFullQuery;
import com.devops00.spectra.example.javabean.vo.ExampleFullVO;
import com.devops00.spectra.example.service.ExampleFullService;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

/**
 * Controller完整示例
 *
 * 注意：
 * <ol>
 * <li>Controller 做绑定、入口校验和接口级授权，用例及记录范围由 Service 保障</li>
 * <li>统一 @RequiredArgsConstructor + private final 构造器注入</li>
 * <li>禁止返回 Object，必须返回具体类型</li>
 * <li>统一方法命名：created/modify/deleteById/page</li>
 * <li>需要审计的入口使用 @Audit，接口显式 @PreAuthorize；审计避免敏感快照</li>
 * <li>写操作必须加 @Validated</li>
 * <li>Mapping 注解中统一 version = "1.0.0"</li>
 * </ol>
 *
 * @author yangxj96
 * @version 1.0
 * @since 2026/7/18
 */
@Slf4j
@RestController
@RequestMapping("/example")
@RequiredArgsConstructor
public class ExampleFullController {

    private final ExampleFullService exampleService;

    /**
     * 分页查询示例列表
     */
    @Audit("'查询示例列表'")
    @GetMapping(value = "/page", version = "1.0.0")
    @PreAuthorize("isAuthenticated()")
    public IPage<ExampleFullVO> page(PageFrom page, ExampleFullQuery params) {
        return exampleService.page(page, params);
    }

    /**
     * 查询示例详情
     */
    @Audit("'查询示例详情'")
    @GetMapping(value = "/{id}", version = "1.0.0")
    @PreAuthorize("isAuthenticated()")
    public ExampleFullVO getDetail(@PathVariable UUID id) {
        return exampleService.getDetail(id);
    }

    /**
     * 创建示例
     */
    @Audit("'创建示例'")
    @PostMapping(value = "", version = "1.0.0")
    @PreAuthorize("hasPermission(null, 'EXAMPLE:INSERT')")
    public void created(@Validated(Verify.Insert.class) @RequestBody ExampleFullFrom from) {
        exampleService.created(from);
    }

    /**
     * 更新示例
     */
    @Audit("'更新示例'")
    @PutMapping(value = "/{id}", version = "1.0.0")
    @PreAuthorize("hasPermission(null, 'EXAMPLE:UPDATE')")
    public void modify(@PathVariable UUID id, @Validated(Verify.Update.class) @RequestBody ExampleFullFrom from) {
        exampleService.modify(id, from);
    }

    /**
     * 删除示例
     */
    @Audit("'删除示例'")
    @DeleteMapping(value = "/{id}", version = "1.0.0")
    @PreAuthorize("hasPermission(null, 'EXAMPLE:DELETE')")
    public void deleteById(@PathVariable UUID id) {
        exampleService.deleteById(id);
    }
}
