---
tags:
  - plan
  - backend
  - ai
---

# P-AI 对话历史持久化计划

## 状态

**已完成**

> 状态变更时间：2026-07-26

## 问题背景

当前 AI 模块（spectra-ai）集成 LangChain4j 1.16.3，存在以下问题：

1. **记忆纯内存**：`AiConfiguration` 中 `MessageWindowChatMemory` 未配置 `chatMemoryStore`，应用重启后所有对话上下文丢失
2. **MemoryId 绑定 token**：`DeepSeekAssistant` 使用 `@MemoryId String token`（JWT），用户重新登录后 token 变化，旧对话记忆无法续接
3. **无会话管理**：没有多会话概念，无法创建/列表/删除/查看历史对话
4. **ai_session 表未接入**：表已建但从未被使用，结构与 LangChain4j `ChatMemoryStore` 接口不匹配
5. **工具依赖 token**：`@ToolMemoryId String token` 传给 `ToolExecutor.executeWithSecurity(token, ...)`，用于设置 SecurityContext——改 MemoryId 时必须保证工具仍能获取 token

## 修复目标

1. 实现 `ChatMemoryStore` 接口，将对话消息持久化到 PostgreSQL
2. 引入 `AiMemoryId` 复合对象（conversationId + token），解耦记忆标识与认证凭据
3. 支持多会话：用户可创建多个独立对话，每个对话有独立上下文窗口
4. 提供会话管理 REST API（创建/列表/重命名/删除/查看历史）
5. 重新登录后通过 conversationId 无缝续接历史对话

## 详细实现步骤

### 阶段一：数据库 Schema

#### 1.1 创建 ai_conversation 表

**操作**：新建会话元数据表

**SQL**：
```sql
CREATE TABLE spectra_ai.ai_conversation (
    id          UUID PRIMARY KEY,
    user_id     UUID NOT NULL,
    title       VARCHAR(200) NOT NULL DEFAULT '新对话',
    status      VARCHAR(20)  NOT NULL DEFAULT 'active',
    created_by  UUID,
    created_at  TIMESTAMPTZ NOT NULL,
    updated_by  UUID,
    updated_at  TIMESTAMPTZ NOT NULL,
    deleted     TIMESTAMPTZ,
    version     BIGINT DEFAULT 0
);

COMMENT ON TABLE spectra_ai.ai_conversation IS 'AI 会话元数据';
COMMENT ON COLUMN spectra_ai.ai_conversation.user_id IS '所属用户 ID';
COMMENT ON COLUMN spectra_ai.ai_conversation.title IS '会话标题（取首条消息前 30 字）';
COMMENT ON COLUMN spectra_ai.ai_conversation.status IS '状态：active / archived';

CREATE INDEX idx_ai_conversation_user ON spectra_ai.ai_conversation(user_id) WHERE deleted IS NULL;
```

#### 1.2 创建 ai_chat_memory 表

**操作**：新建消息持久化表（每个会话一行，全量 JSON）

**SQL**：
```sql
CREATE TABLE spectra_ai.ai_chat_memory (
    memory_id   VARCHAR(64) PRIMARY KEY,
    messages    TEXT NOT NULL DEFAULT '[]',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE spectra_ai.ai_chat_memory IS 'AI 对话消息持久化存储';
COMMENT ON COLUMN spectra_ai.ai_chat_memory.memory_id IS '会话 ID（= ai_conversation.id::text）';
COMMENT ON COLUMN spectra_ai.ai_chat_memory.messages IS 'ChatMessageSerializer.messagesToJson() 序列化的 JSON';
```

#### 1.3 删除废弃的 ai_session 表

**操作**：确认无数据后 DROP

**SQL**：
```sql
DROP TABLE IF EXISTS spectra_ai.ai_session;
```

---

### 阶段二：AiMemoryId 复合标识

#### 2.1 创建 AiMemoryId record

**操作**：新建复合 MemoryId，同时携带 conversationId 和 token

**文件**：
- 创建：`spectra-admin/spectra-modules/spectra-ai/src/main/java/com/devops00/spectra/ai/javabean/AiMemoryId.java`

**代码**：
```java
package com.devops00.spectra.ai.javabean;

/**
 * AI 对话复合记忆标识
 *
 * conversationId 用于 ChatMemory 缓存 key 和数据库存储 key；
 * token 用于工具执行时设置 SecurityContext。
 * equals/hashCode 仅比较 conversationId，确保同一会话在 token 变化后仍复用同一 Memory 实例。
 *
 * @author yangxj96
 * @version 1.0
 * @since 2026/7/26
 */
public record AiMemoryId(String conversationId, String token) {

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof AiMemoryId that)) return false;
        return conversationId.equals(that.conversationId);
    }

    @Override
    public int hashCode() {
        return conversationId.hashCode();
    }

    @Override
    public String toString() {
        return conversationId;
    }
}
```

---

### 阶段三：实体与 Mapper

#### 3.1 创建 AiConversation 实体

**文件**：
- 创建：`spectra-admin/spectra-modules/spectra-ai/src/main/java/com/devops00/spectra/ai/javabean/entity/AiConversation.java`

**代码**：
```java
package com.devops00.spectra.ai.javabean.entity;

import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableName;
import com.devops00.spectra.common.base.BaseEntity;
import lombok.Getter;
import lombok.Setter;
import lombok.ToString;

import java.util.UUID;

/**
 * AI 会话元数据
 *
 * @author yangxj96
 * @version 1.0
 * @since 2026/7/26
 */
@Getter
@Setter
@ToString
@TableName(value = "ai_conversation", schema = "spectra_ai")
public class AiConversation extends BaseEntity {

    /**
     * 所属用户 ID
     */
    @TableField("user_id")
    private UUID userId;

    /**
     * 会话标题
     */
    @TableField("title")
    private String title;

    /**
     * 状态：active / archived
     */
    @TableField("status")
    private String status;
}
```

#### 3.2 创建 AiChatMemory 实体

**文件**：
- 创建：`spectra-admin/spectra-modules/spectra-ai/src/main/java/com/devops00/spectra/ai/javabean/entity/AiChatMemory.java`

**代码**：
```java
package com.devops00.spectra.ai.javabean.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import lombok.Getter;
import lombok.Setter;
import lombok.ToString;

import java.time.Instant;

/**
 * AI 对话消息持久化记录
 *
 * @author yangxj96
 * @version 1.0
 * @since 2026/7/26
 */
@Getter
@Setter
@ToString
@TableName(value = "ai_chat_memory", schema = "spectra_ai")
public class AiChatMemory {

    /**
     * 会话 ID（= ai_conversation.id::text）
     */
    @TableId(value = "memory_id", type = IdType.INPUT)
    private String memoryId;

    /**
     * 序列化的消息 JSON
     */
    @TableField("messages")
    private String messages;

    /**
     * 创建时间
     */
    @TableField("created_at")
    private Instant createdAt;

    /**
     * 更新时间
     */
    @TableField("updated_at")
    private Instant updatedAt;
}
```

#### 3.3 创建 AiConversationMapper

**文件**：
- 创建：`spectra-admin/spectra-modules/spectra-ai/src/main/java/com/devops00/spectra/ai/mapper/AiConversationMapper.java`

**代码**：
```java
package com.devops00.spectra.ai.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.devops00.spectra.ai.javabean.entity.AiConversation;

/**
 * AI 会话 Mapper
 *
 * @author yangxj96
 * @version 1.0
 * @since 2026/7/26
 */
public interface AiConversationMapper extends BaseMapper<AiConversation> {
}
```

#### 3.4 创建 AiChatMemoryMapper（含 upsert）

**文件**：
- 创建：`spectra-admin/spectra-modules/spectra-ai/src/main/java/com/devops00/spectra/ai/mapper/AiChatMemoryMapper.java`

**代码**：
```java
package com.devops00.spectra.ai.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.devops00.spectra.ai.javabean.entity.AiChatMemory;
import org.apache.ibatis.annotations.Param;

/**
 * AI 对话消息存储 Mapper
 *
 * @author yangxj96
 * @version 1.0
 * @since 2026/7/26
 */
public interface AiChatMemoryMapper extends BaseMapper<AiChatMemory> {

    /**
     * 插入或更新消息（PostgreSQL ON CONFLICT）
     */
    void upsert(@Param("memoryId") String memoryId, @Param("messages") String messages);
}
```

#### 3.5 创建 AiChatMemoryMapper.xml

**文件**：
- 创建：`spectra-admin/spectra-modules/spectra-ai/src/main/resources/mapper/AiChatMemoryMapper.xml`

**代码**：
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE mapper PUBLIC "-//mybatis.org//DTD Mapper 3.0//EN" "http://mybatis.org/dtd/mybatis-3-mapper.dtd">
<mapper namespace="com.devops00.spectra.ai.mapper.AiChatMemoryMapper">

    <insert id="upsert">
        INSERT INTO spectra_ai.ai_chat_memory (memory_id, messages, created_at, updated_at)
        VALUES (#{memoryId}, #{messages}, now(), now())
        ON CONFLICT (memory_id)
        DO UPDATE SET messages = EXCLUDED.messages, updated_at = now()
    </insert>

</mapper>
```

#### 3.6 创建 AiConversationMapper.xml

**文件**：
- 创建：`spectra-admin/spectra-modules/spectra-ai/src/main/resources/mapper/AiConversationMapper.xml`

**代码**：
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE mapper PUBLIC "-//mybatis.org//DTD Mapper 3.0//EN" "http://mybatis.org/dtd/mybatis-3-mapper.dtd">
<mapper namespace="com.devops00.spectra.ai.mapper.AiConversationMapper">

    <resultMap id="BaseResultMap"
               extends="com.devops00.spectra.common.base.BaseMapper.BaseAuditMap"
               type="com.devops00.spectra.ai.javabean.entity.AiConversation">
        <result column="user_id" property="userId"/>
        <result column="title"   property="title"/>
        <result column="status"  property="status"/>
    </resultMap>

    <sql id="Base_Column_List">
        user_id, title, status,
        <include refid="com.devops00.spectra.common.base.BaseMapper.BaseAuditColumns"/>
    </sql>

</mapper>
```

---

### 阶段四：ChatMemoryStore 实现

#### 4.1 创建 PostgresChatMemoryStore

**操作**：实现 LangChain4j `ChatMemoryStore` 接口，将消息持久化到 `ai_chat_memory` 表

**文件**：
- 创建：`spectra-admin/spectra-modules/spectra-ai/src/main/java/com/devops00/spectra/ai/store/PostgresChatMemoryStore.java`

**代码**：
```java
package com.devops00.spectra.ai.store;

import com.devops00.spectra.ai.javabean.AiMemoryId;
import com.devops00.spectra.ai.javabean.entity.AiChatMemory;
import com.devops00.spectra.ai.mapper.AiChatMemoryMapper;
import dev.langchain4j.data.message.ChatMessage;
import dev.langchain4j.data.message.ChatMessageDeserializer;
import dev.langchain4j.data.message.ChatMessageSerializer;
import dev.langchain4j.store.memory.chat.ChatMemoryStore;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

import java.util.List;

/**
 * 基于 PostgreSQL 的 ChatMemoryStore 实现
 *
 * @author yangxj96
 * @version 1.0
 * @since 2026/7/26
 */
@Component
@RequiredArgsConstructor
public class PostgresChatMemoryStore implements ChatMemoryStore {

    private final AiChatMemoryMapper mapper;

    @Override
    public List<ChatMessage> getMessages(Object memoryId) {
        String key = extractKey(memoryId);
        AiChatMemory row = mapper.selectById(key);
        if (row == null || row.getMessages() == null || row.getMessages().isBlank()) {
            return List.of();
        }
        return ChatMessageDeserializer.messagesFromJson(row.getMessages());
    }

    @Override
    public void updateMessages(Object memoryId, List<ChatMessage> messages) {
        String key = extractKey(memoryId);
        String json = ChatMessageSerializer.messagesToJson(messages);
        mapper.upsert(key, json);
    }

    @Override
    public void deleteMessages(Object memoryId) {
        String key = extractKey(memoryId);
        mapper.deleteById(key);
    }

    private String extractKey(Object memoryId) {
        if (memoryId instanceof AiMemoryId ami) {
            return ami.conversationId();
        }
        return memoryId.toString();
    }
}
```

---

### 阶段五：Service 层

#### 5.1 创建 AiConversationService 接口

**文件**：
- 创建：`spectra-admin/spectra-modules/spectra-ai/src/main/java/com/devops00/spectra/ai/service/AiConversationService.java`

**代码**：
```java
package com.devops00.spectra.ai.service;

import com.devops00.spectra.ai.javabean.entity.AiConversation;
import com.devops00.spectra.common.base.BaseService;

import java.util.List;
import java.util.UUID;

/**
 * AI 会话管理 Service
 *
 * @author yangxj96
 * @version 1.0
 * @since 2026/7/26
 */
public interface AiConversationService extends BaseService<AiConversation> {

    /**
     * 创建新会话
     */
    UUID create(UUID userId, String firstMessage);

    /**
     * 获取当前用户的会话列表
     */
    List<AiConversation> listByUser(UUID userId);

    /**
     * 重命名会话
     */
    void rename(UUID conversationId, UUID userId, String title);

    /**
     * 删除会话（同时清理消息存储）
     */
    void delete(UUID conversationId, UUID userId);
}
```

#### 5.2 创建 AiConversationServiceImpl

**文件**：
- 创建：`spectra-admin/spectra-modules/spectra-ai/src/main/java/com/devops00/spectra/ai/service/impl/AiConversationServiceImpl.java`

**代码**：
```java
package com.devops00.spectra.ai.service.impl;

import com.baomidou.mybatisplus.core.conditions.query.LambdaQueryWrapper;
import com.devops00.spectra.ai.javabean.entity.AiConversation;
import com.devops00.spectra.ai.mapper.AiChatMemoryMapper;
import com.devops00.spectra.ai.mapper.AiConversationMapper;
import com.devops00.spectra.ai.service.AiConversationService;
import com.devops00.spectra.common.base.BaseServiceImpl;
import com.devops00.spectra.common.exception.SpectraException;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

/**
 * AI 会话管理 Service 实现
 *
 * @author yangxj96
 * @version 1.0
 * @since 2026/7/26
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AiConversationServiceImpl
        extends BaseServiceImpl<AiConversationMapper, AiConversation>
        implements AiConversationService {

    private final AiChatMemoryMapper chatMemoryMapper;

    @Override
    public UUID create(UUID userId, String firstMessage) {
        AiConversation conversation = new AiConversation();
        conversation.setId(UUID.randomUUID());
        conversation.setUserId(userId);
        conversation.setTitle(generateTitle(firstMessage));
        conversation.setStatus("active");
        baseMapper.insert(conversation);
        return conversation.getId();
    }

    @Override
    public List<AiConversation> listByUser(UUID userId) {
        return baseMapper.selectList(
                new LambdaQueryWrapper<AiConversation>()
                        .eq(AiConversation::getUserId, userId)
                        .isNull(AiConversation::getDeleted)
                        .orderByDesc(AiConversation::getUpdatedAt)
        );
    }

    @Override
    public void rename(UUID conversationId, UUID userId, String title) {
        AiConversation conversation = getOwnedConversation(conversationId, userId);
        conversation.setTitle(title);
        baseMapper.updateById(conversation);
    }

    @Override
    @Transactional
    public void delete(UUID conversationId, UUID userId) {
        getOwnedConversation(conversationId, userId);
        baseMapper.deleteById(conversationId);
        chatMemoryMapper.deleteById(conversationId.toString());
    }

    private AiConversation getOwnedConversation(UUID conversationId, UUID userId) {
        AiConversation conversation = baseMapper.selectById(conversationId);
        if (conversation == null || !conversation.getUserId().equals(userId)) {
            throw new SpectraException("会话不存在");
        }
        return conversation;
    }

    private String generateTitle(String message) {
        if (message == null || message.isBlank()) {
            return "新对话";
        }
        String trimmed = message.strip();
        return trimmed.length() <= 30 ? trimmed : trimmed.substring(0, 30) + "...";
    }
}
```

---

### 阶段六：修改 AiConfiguration

#### 6.1 注入 PostgresChatMemoryStore 并挂载到 ChatMemoryProvider

**文件**：
- 修改：`spectra-admin/spectra-modules/spectra-ai/src/main/java/com/devops00/spectra/ai/configuration/AiConfiguration.java`

**变更**：
```java
// 新增注入
private final PostgresChatMemoryStore chatMemoryStore;

// 修改 chatMemoryProvider 构建
ChatMemoryProvider chatMemoryProvider = memoryId -> MessageWindowChatMemory.builder()
        .id(memoryId)
        .maxMessages(20)
        .chatMemoryStore(chatMemoryStore)  // ← 新增：持久化
        .build();
```

---

### 阶段七：修改 DeepSeekAssistant

#### 7.1 @MemoryId 类型改为 AiMemoryId

**文件**：
- 修改：`spectra-admin/spectra-modules/spectra-ai/src/main/java/com/devops00/spectra/ai/configuration/DeepSeekAssistant.java`

**变更**：
```java
import com.devops00.spectra.ai.javabean.AiMemoryId;

// 改前
String chat(@MemoryId String token, @UserMessage String message);
TokenStream stream(@MemoryId String token, @UserMessage String message);

// 改后
String chat(@MemoryId AiMemoryId memoryId, @UserMessage String message);
TokenStream stream(@MemoryId AiMemoryId memoryId, @UserMessage String message);
```

---

### 阶段八：修改 AiAskFrom 和 AiAskController

#### 8.1 AiAskFrom 增加 conversationId 字段

**文件**：
- 修改：`spectra-admin/spectra-modules/spectra-ai/src/main/java/com/devops00/spectra/ai/javabean/from/AiAskFrom.java`

**变更**：
```java
import java.util.UUID;

@Data
public class AiAskFrom {

    /**
     * 会话 ID（为空时自动创建新会话）
     */
    private UUID conversationId;

    /**
     * 问题消息
     */
    @NotBlank(message = "消息内容不能为空")
    private String message;
}
```

#### 8.2 修改 AiAskController.stream()

**文件**：
- 修改：`spectra-admin/spectra-modules/spectra-ai/src/main/java/com/devops00/spectra/ai/controller/AiAskController.java`

**变更**：
```java
// 新增注入
private final AiConversationService conversationService;

@PostMapping(value = "/stream", produces = MediaType.TEXT_EVENT_STREAM_VALUE, version = "1.0.0+")
@PreAuthorize("isAuthenticated()")
public Flux<String> stream(@Validated @RequestBody AiAskFrom from) {
    // 确定 conversationId
    UUID conversationId = from.getConversationId();
    if (conversationId == null) {
        conversationId = conversationService.create(SecUtil.getCurrentUserId(), from.getMessage());
    }

    // 构建复合 MemoryId
    AiMemoryId memoryId = new AiMemoryId(conversationId.toString(), SecUtil.getCurrentToken());

    String streamId = "chatcmpl-" + UUID.randomUUID().toString().replace("-", "");
    return Flux.create(sink -> {
        assistant.stream(memoryId, from.getMessage())
                .onPartialResponse(token -> { /* 不变 */ })
                .onCompleteResponse(chatResponse -> { /* 不变 */ })
                .onError(sink::error)
                .start();
    });
}
```

**注意**：响应中需要返回 conversationId 给前端（可通过 SSE 首包或响应头传递）。建议在第一个 chunk 中附加 `conversation_id` 字段，或在 `OpenAIStreamVO` 中增加该字段。

---

### 阶段九：修改 Tools（@ToolMemoryId 类型变更）

#### 9.1 修改 TimeTools

**文件**：
- 修改：`spectra-admin/spectra-modules/spectra-ai/src/main/java/com/devops00/spectra/ai/configuration/tool/TimeTools.java`

**变更**：
```java
import com.devops00.spectra.ai.javabean.AiMemoryId;

// 改前
public String getCurrentDateTimeISO(@ToolMemoryId String token) {
    return ToolExecutor.execute(token, _ -> { ... });
}

// 改后
public String getCurrentDateTimeISO(@ToolMemoryId AiMemoryId memoryId) {
    return ToolExecutor.execute(memoryId.token(), _ -> { ... });
}
```

#### 9.2 修改 AiDeptTool

**文件**：
- 修改：`spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/system/ai/tools/AiDeptTool.java`

**变更**：
```java
import com.devops00.spectra.ai.javabean.AiMemoryId;

// 改前
public String getAllDepartments(@ToolMemoryId String token) {
    return ToolExecutor.execute(token, _ -> { ... });
}

// 改后
public String getAllDepartments(@ToolMemoryId AiMemoryId memoryId) {
    return ToolExecutor.execute(memoryId.token(), _ -> { ... });
}
```

#### 9.3 修改 AiUserTool

**文件**：
- 修改：`spectra-admin/spectra-modules/spectra-core/src/main/java/com/devops00/spectra/core/user/ai/tools/AiUserTool.java`

**变更**：
```java
import com.devops00.spectra.ai.javabean.AiMemoryId;

// 改前
public String getAllUsers(@ToolMemoryId String token) {
    return ToolExecutor.execute(token, _ -> { ... });
}

// 改后
public String getAllUsers(@ToolMemoryId AiMemoryId memoryId) {
    return ToolExecutor.execute(memoryId.token(), _ -> { ... });
}
```

---

### 阶段十：会话管理 Controller

#### 10.1 创建 AiConversationController

**文件**：
- 创建：`spectra-admin/spectra-modules/spectra-ai/src/main/java/com/devops00/spectra/ai/controller/AiConversationController.java`

**API 设计**：

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/ai/conversation/list` | 当前用户的会话列表 |
| PUT | `/ai/conversation/{id}/title` | 重命名会话 |
| DELETE | `/ai/conversation/{id}` | 删除会话（含消息清理） |
| GET | `/ai/conversation/{id}/messages` | 获取对话历史（反序列化 JSON 返回） |

**代码**：
```java
package com.devops00.spectra.ai.controller;

// ... imports

@Slf4j
@RestController
@RequiredArgsConstructor
@RequestMapping("/ai/conversation")
public class AiConversationController {

    private final AiConversationService conversationService;
    private final AiChatMemoryMapper chatMemoryMapper;

    @GetMapping("/list")
    @PreAuthorize("isAuthenticated()")
    public IResult<List<AiConversation>> list() {
        return IResult.ok(conversationService.listByUser(SecUtil.getCurrentUserId()));
    }

    @PutMapping("/{id}/title")
    @PreAuthorize("isAuthenticated()")
    public IResult<Void> rename(@PathVariable UUID id, @RequestParam String title) {
        conversationService.rename(id, SecUtil.getCurrentUserId(), title);
        return IResult.ok();
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("isAuthenticated()")
    public IResult<Void> delete(@PathVariable UUID id) {
        conversationService.delete(id, SecUtil.getCurrentUserId());
        return IResult.ok();
    }

    @GetMapping("/{id}/messages")
    @PreAuthorize("isAuthenticated()")
    public IResult<List<ChatMessageVO>> messages(@PathVariable UUID id) {
        // 校验归属 → 从 ai_chat_memory 读取 → 反序列化 → 转 VO 返回
    }
}
```

#### 10.2 创建 ChatMessageVO

**文件**：
- 创建：`spectra-admin/spectra-modules/spectra-ai/src/main/java/com/devops00/spectra/ai/javabean/vo/ChatMessageVO.java`

**代码**：
```java
package com.devops00.spectra.ai.javabean.vo;

import lombok.Data;

/**
 * 对话消息 VO（前端展示用）
 *
 * @author yangxj96
 * @version 1.0
 * @since 2026/7/26
 */
@Data
public class ChatMessageVO {

    /**
     * 角色：user / assistant / system
     */
    private String role;

    /**
     * 消息内容
     */
    private String content;
}
```

---

### 阶段十一：清理废弃代码

#### 11.1 删除 AiSession 相关文件

**操作**：删除以下文件

- `spectra-admin/spectra-modules/spectra-ai/src/main/java/com/devops00/spectra/ai/javabean/entity/AiSession.java`
- `spectra-admin/spectra-modules/spectra-ai/src/main/java/com/devops00/spectra/ai/mapper/AiSessionMapper.java`
- `spectra-admin/spectra-modules/spectra-ai/src/main/java/com/devops00/spectra/ai/service/AiSessionService.java`
- `spectra-admin/spectra-modules/spectra-ai/src/main/java/com/devops00/spectra/ai/service/impl/AiSessionServiceImpl.java`
- `spectra-admin/spectra-modules/spectra-ai/src/main/resources/mapper/AiSessionMapper.xml`

---

### 阶段十二：OpenAIStreamVO 增加 conversationId

#### 12.1 在流式响应首包中返回 conversationId

**文件**：
- 修改：`spectra-admin/spectra-modules/spectra-ai/src/main/java/com/devops00/spectra/ai/javabean/vo/OpenAIStreamVO.java`

**变更**：增加 `conversationId` 字段，仅在第一个 chunk 中赋值，前端据此保存当前会话 ID。

---

## 验证方案

1. **编译验证**：`./mvnw clean compile -pl spectra-modules/spectra-ai,spectra-modules/spectra-core -am`
2. **启动验证**：`./mvnw spring-boot:run -pl spectra-launch`，确认无 Bean 创建异常
3. **功能验证**：
   - POST `/ai/ask/stream`（不带 conversationId）→ 返回中包含新 conversationId
   - 再次 POST（带同一 conversationId）→ AI 能记住上文
   - GET `/ai/conversation/list` → 返回会话列表
   - GET `/ai/conversation/{id}/messages` → 返回历史消息
   - DELETE `/ai/conversation/{id}` → 会话和消息均被删除
4. **重启验证**：重启后端，用同一 conversationId 继续对话 → 历史上下文正常加载
5. **工具验证**：触发 TimeTools/AiDeptTool → SecurityContext 正常设置，返回正确数据

## 影响范围

| 模块 | 影响 |
|---|---|
| spectra-ai | 核心变更：实体/Mapper/Service/Controller/Configuration/Store |
| spectra-core | AiDeptTool、AiUserTool 的 @ToolMemoryId 参数类型变更 |
| spectra-ai-base | 无变更（ToolExecutor 接口不变） |
| 数据库 | spectra_ai schema：新增 2 表，删除 1 表 |
| 前端 | AiAskFrom 增加 conversationId 字段，SSE 响应增加 conversationId |

## 相关

- [[70-AI模块]]
- [[10-架构分层]]
- [[80-基础设施]]
