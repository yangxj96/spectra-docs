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

package com.devops00.spectra.framework.persistence.base;

import com.baomidou.mybatisplus.annotation.FieldFill;
import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.Version;
import lombok.Data;

import java.time.Instant;
import java.util.UUID;

/**
 * 实体基类完整示例
 *
 * 注意：
 * <ol>
 * <li>可维护业务实体复用实际 BaseEntity；特殊生命周期按领域约定</li>
 * <li>BaseEntity 包含以下字段：</li>
 * </ol>
 * <ul>
 * <li>id：UUID v7 主键</li>
 * <li>createdBy：创建人</li>
 * <li>createdAt：创建时间</li>
 * <li>updatedBy：更新人</li>
 * <li>updatedAt：更新时间</li>
 * <li>deleted：删除时间（null = 未删除）；查询过滤需由实际用例落实</li>
 * <li>version：乐观锁版本号</li>
 * </ul>
 * <ol>
 * <li>使用 @Data 注解</li>
 * </ol>
 *
 * @author yangxj96
 * @version 1.0
 * @since 2026/7/18
 */
@Data
public class BaseEntityFullExample {

    /**
     * UUID 主键
     */
    @TableId(value = "id", type = IdType.INPUT)
    private UUID id;

    /**
     * 创建人
     */
    @TableField(value = "created_by", fill = FieldFill.INSERT)
    private UUID createdBy;

    /**
     * 创建时间
     */
    @TableField(fill = FieldFill.INSERT)
    private Instant createdAt;

    /**
     * 更新人
     */
    @TableField(value = "updated_by", fill = FieldFill.INSERT_UPDATE)
    private UUID updatedBy;

    /**
     * 更新时间
     */
    @TableField(fill = FieldFill.INSERT_UPDATE)
    private Instant updatedAt;

    /**
     * 软删除标记（null = 未删除）
     */
    @TableField(value = "deleted")
    private Instant deleted;

    /**
     * 乐观锁版本号
     */
    @Version
    @TableField(value = "version")
    private Long version;
}
