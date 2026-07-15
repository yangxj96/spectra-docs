-- ============================================
-- spectra_rag schema 建表语句
-- RAG 向量存储（需要 pgvector 扩展）
-- ============================================

CREATE SCHEMA IF NOT EXISTS spectra_rag;

-- 启用 pgvector 扩展
CREATE EXTENSION IF NOT EXISTS vector;

-- RAG 知识分块表
CREATE TABLE spectra_rag.ai_knowledge_chunks (
    embedding_id  UUID PRIMARY KEY,
    embedding     spectra_rag.vector(1536),
    text          TEXT,
    metadata      JSONB
);
COMMENT ON TABLE spectra_rag.ai_knowledge_chunks IS 'RAG知识分块表';
COMMENT ON COLUMN spectra_rag.ai_knowledge_chunks.embedding_id IS '主键，向量ID';
COMMENT ON COLUMN spectra_rag.ai_knowledge_chunks.embedding IS '1536维向量（OpenAI text-embedding-3-small）';
COMMENT ON COLUMN spectra_rag.ai_knowledge_chunks.text IS '原始文本内容';
COMMENT ON COLUMN spectra_rag.ai_knowledge_chunks.metadata IS '元数据（来源、章节等）';

-- 向量索引（余弦相似度）
CREATE INDEX ai_knowledge_chunks_embedding_idx
    ON spectra_rag.ai_knowledge_chunks
    USING ivfflat (embedding spectra_rag.vector_cosine_ops)
    WITH (lists = '100');

-- 文本转向量函数
CREATE FUNCTION spectra_rag.cast_text_to_vector(text)
    RETURNS spectra_rag.vector
    LANGUAGE sql IMMUTABLE STRICT
    AS $$
        SELECT $1::spectra_rag.vector;
    $$;
