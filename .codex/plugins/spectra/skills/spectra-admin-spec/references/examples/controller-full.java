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

import com.devops00.spectra.common.base.Verify;
import com.devops00.spectra.common.base.javabean.from.PageFrom;
import com.devops00.spectra.log.base.annotation.ULog;
import com.devops00.spectra.example.javabean.from.ExampleSaveFrom;
import com.devops00.spectra.example.javabean.from.ExamplePageFrom;
import com.devops00.spectra.example.javabean.vo.ExampleVO;
import com.devops00.spectra.example.service.ExampleServiceInterface;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.*;

import java.util.UUID;

/// Controller完整示例
///
/// 注意：
/// 1. 瘦 Controller：只做请求转发，不包含任何业务逻辑
/// 2. 统一 @RequiredArgsConstructor + private final 构造器注入
/// 3. 禁止返回 Object，必须返回具体类型
/// 4. 统一方法命名：created/modify/deleteById/page
/// 5. 所有接口必须加 @ULog、@PreAuthorize
/// 6. 写操作必须加 @Validated
/// 7. Mapping 注解中统一 version = "1.0.0+"
///
/// @author yangxj96
/// @version 1.0
/// @since 2026/7/18
@Slf4j
@RestController
@RequestMapping("/example")
@RequiredArgsConstructor
public class ExampleFullController {

    private final ExampleServiceInterface exampleService;

    /// 分页查询示例列表
    @ULog("'查询示例列表'")
    @GetMapping(value = "/page", version = "1.0.0+")
    @PreAuthorize("isAuthenticated()")
    public Object page(PageFrom page, ExamplePageFrom params) {
        return exampleService.page(page, params);
    }

    /// 查询示例详情
    @ULog("'查询示例详情'")
    @GetMapping(value = "/{id}", version = "1.0.0+")
    @PreAuthorize("isAuthenticated()")
    public ExampleVO getDetail(@PathVariable UUID id) {
        return exampleService.getDetail(id);
    }

    /// 创建示例
    @ULog("'创建示例'")
    @PostMapping(value = "", version = "1.0.0+")
    @PreAuthorize("hasPermission(null, 'EXAMPLE:INSERT')")
    public void created(@Validated(Verify.Insert.class) @RequestBody ExampleSaveFrom from) {
        exampleService.created(from);
    }

    /// 更新示例
    @ULog("'更新示例'")
    @PutMapping(value = "/{id}", version = "1.0.0+")
    @PreAuthorize("hasPermission(null, 'EXAMPLE:UPDATE')")
    public void modify(@PathVariable UUID id, @Validated(Verify.Update.class) @RequestBody ExampleSaveFrom from) {
        exampleService.modify(id, from);
    }

    /// 删除示例
    @ULog("'删除示例'")
    @DeleteMapping(value = "/{id}", version = "1.0.0+")
    @PreAuthorize("hasPermission(null, 'EXAMPLE:DELETE')")
    public void deleteById(@PathVariable UUID id) {
        exampleService.deleteById(id);
    }
}
