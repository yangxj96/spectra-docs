-- ============================================
-- spectra_ai schema 建表语句
-- RAG 向量存储（需要 pgvector 扩展）
-- ============================================

CREATE SCHEMA IF NOT EXISTS spectra_ai;

-- 启用 pgvector 扩展
CREATE EXTENSION IF NOT EXISTS vector WITH SCHEMA spectra_ai;

-- RAG 知识分块表
CREATE TABLE spectra_ai.ai_knowledge_chunks (
    embedding_id  UUID PRIMARY KEY,
    embedding     spectra_ai.vector(1536),
    text          TEXT,
    metadata      JSONB
);
COMMENT ON TABLE spectra_ai.ai_knowledge_chunks IS 'RAG知识分块表';
COMMENT ON COLUMN spectra_ai.ai_knowledge_chunks.embedding_id IS '主键，向量ID';
COMMENT ON COLUMN spectra_ai.ai_knowledge_chunks.embedding IS '1536维向量（OpenAI text-embedding-3-small）';
COMMENT ON COLUMN spectra_ai.ai_knowledge_chunks.text IS '原始文本内容';
COMMENT ON COLUMN spectra_ai.ai_knowledge_chunks.metadata IS '元数据（来源、章节等）';

-- 向量索引（余弦相似度）
CREATE INDEX ai_knowledge_chunks_embedding_idx
    ON spectra_ai.ai_knowledge_chunks
    USING ivfflat (embedding spectra_ai.vector_cosine_ops)
    WITH (lists = '100');

-- 文本转向量函数
CREATE FUNCTION spectra_ai.cast_text_to_vector(text)
    RETURNS spectra_ai.vector
    LANGUAGE sql IMMUTABLE STRICT
    AS $$
        SELECT $1::spectra_ai.vector;
    $$;

-- AI 会话元数据
CREATE TABLE spectra_ai.ai_conversation (
    id          UUID PRIMARY KEY,
    user_id     UUID NOT NULL,
    title       VARCHAR(200) NOT NULL DEFAULT '新对话',
    status      VARCHAR(20) NOT NULL DEFAULT 'active',
    created_by  UUID,
    created_at  TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    updated_by  UUID,
    updated_at  TIMESTAMP(6) WITH TIME ZONE NOT NULL,
    deleted     TIMESTAMP(6) WITH TIME ZONE,
    version     BIGINT DEFAULT 0
);
CREATE INDEX idx_ai_conversation_user
    ON spectra_ai.ai_conversation (user_id)
    WHERE deleted IS NULL;
COMMENT ON TABLE spectra_ai.ai_conversation IS 'AI 会话元数据';
COMMENT ON COLUMN spectra_ai.ai_conversation.id IS '主键ID';
COMMENT ON COLUMN spectra_ai.ai_conversation.user_id IS '所属用户 ID';
COMMENT ON COLUMN spectra_ai.ai_conversation.title IS '会话标题（取首条消息前 30 字）';
COMMENT ON COLUMN spectra_ai.ai_conversation.status IS '状态：active / archived';
COMMENT ON COLUMN spectra_ai.ai_conversation.created_by IS '创建人';
COMMENT ON COLUMN spectra_ai.ai_conversation.created_at IS '创建时间';
COMMENT ON COLUMN spectra_ai.ai_conversation.updated_by IS '最后更新人';
COMMENT ON COLUMN spectra_ai.ai_conversation.updated_at IS '最后更新时间';
COMMENT ON COLUMN spectra_ai.ai_conversation.deleted IS '删除标识';
COMMENT ON COLUMN spectra_ai.ai_conversation.version IS '乐观锁';

-- AI 对话消息持久化存储
CREATE TABLE spectra_ai.ai_chat_memory (
    memory_id  VARCHAR(64) PRIMARY KEY,
    messages   TEXT NOT NULL DEFAULT '[]',
    created_at TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP(6) WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);
COMMENT ON TABLE spectra_ai.ai_chat_memory IS 'AI 对话消息持久化存储';
COMMENT ON COLUMN spectra_ai.ai_chat_memory.memory_id IS '会话 ID（= ai_conversation.id::text）';
COMMENT ON COLUMN spectra_ai.ai_chat_memory.messages IS 'ChatMessageSerializer.messagesToJson() 序列化的 JSON';
COMMENT ON COLUMN spectra_ai.ai_chat_memory.created_at IS '创建时间';
COMMENT ON COLUMN spectra_ai.ai_chat_memory.updated_at IS '更新时间';
