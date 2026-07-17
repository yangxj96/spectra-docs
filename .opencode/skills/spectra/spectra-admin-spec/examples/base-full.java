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

package com.devops00.spectra.common.base;

import com.baomidou.mybatisplus.annotation.*;
import lombok.Data;

import java.time.Instant;
import java.util.UUID;

/// 实体基类完整示例
///
/// 注意：
/// 1. 所有实体必须继承 BaseEntity
/// 2. BaseEntity 包含以下字段：
///    - id：UUID v7 主键
///    - createdBy：创建人
///    - createdAt：创建时间
///    - updatedBy：更新人
///    - updatedAt：更新时间
///    - deleted：软删除标记（null = 未删除）
///    - version：乐观锁版本号
/// 3. 使用 @Data 注解
///
/// @author yangxj96
/// @version 1.0
/// @since 2026/7/18
@Data
public class BaseEntityFullExample {

    /// UUID 主键
    @TableId(type = IdType.INPUT)
    private UUID id;

    /// 创建人
    @TableField(fill = FieldFill.INSERT)
    private String createdBy;

    /// 创建时间
    @TableField(fill = FieldFill.INSERT)
    private Instant createdAt;

    /// 更新人
    @TableField(fill = FieldFill.INSERT_UPDATE)
    private String updatedBy;

    /// 更新时间
    @TableField(fill = FieldFill.INSERT_UPDATE)
    private Instant updatedAt;

    /// 软删除标记（null = 未删除）
    @TableLogic
    private Instant deleted;

    /// 乐观锁版本号
    @Version
    private Long version;
}
