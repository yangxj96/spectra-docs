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

package com.devops00.spectra.example.javabean.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.devops00.spectra.common.base.BaseEntity;
import lombok.Getter;
import lombok.Setter;
import lombok.ToString;

/// 实体完整示例
///
/// 注意：
/// 1. 继承 BaseEntity（包含 id、createdBy、createdAt、updatedBy、updatedAt、deleted、version）
/// 2. UUID 主键：@TableId(type = IdType.INPUT)
/// 3. 表名注解：@TableName("xxx")
/// 4. 字段注解：@TableField("xxx")
/// 5. 使用 @Getter、@Setter、@ToString 注解
///
/// @author yangxj96
/// @version 1.0
/// @since 2026/7/18
@Getter
@Setter
@ToString
@TableName("example_full")
public class ExampleFullEntity extends BaseEntity {

    @TableField("name")
    private String name;

    @TableField("code")
    private String code;

    @TableField("description")
    private String description;

    @TableField("active")
    private Boolean active;
}
