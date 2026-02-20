-- =============================================================================
-- Migration 07: Criar tabela training_memory
-- Referenciada em 10-chatwoot-events.json para capturar pares Q&A de tutores
-- Aplicar: docker exec kreativ_postgres psql -U kreativ_user -d kreativ_edu -f /path/07-migration-training-memory.sql
-- =============================================================================

CREATE TABLE IF NOT EXISTS training_memory (
    id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    question    TEXT NOT NULL,
    answer      TEXT NOT NULL,
    student_phone TEXT,
    course_id   INTEGER REFERENCES courses(id) ON DELETE SET NULL,
    module_number INTEGER,
    conv_id     INTEGER,
    created_at  TIMESTAMP DEFAULT NOW()
);

-- Índice para busca rápida por telefone e curso (usado no RAG / few-shot)
CREATE INDEX IF NOT EXISTS idx_training_memory_phone ON training_memory (student_phone);
CREATE INDEX IF NOT EXISTS idx_training_memory_course ON training_memory (course_id);

-- Constraint para evitar duplicatas da mesma conversa
CREATE UNIQUE INDEX IF NOT EXISTS idx_training_memory_conv
    ON training_memory (conv_id) WHERE conv_id IS NOT NULL;

COMMENT ON TABLE training_memory IS
    'Pares Q&A capturados de atendimentos de tutores humanos no Chatwoot. '
    'Usados como few-shot examples no AI Router (ai-router-v3).';
