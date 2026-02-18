-- =============================================================================
-- KREATIV EDUCAÇÃO — Script de inicialização do PostgreSQL
-- Executado automaticamente na primeira inicialização do container.
-- =============================================================================

-- Habilitar extensão pgvector no banco principal (kreativ_edu)
CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Criar banco para Evolution API
CREATE DATABASE evolution_db;

-- Criar banco para Chatwoot
CREATE DATABASE chatwoot_db;

-- =============================================================================
-- TABELAS PRINCIPAIS (banco kreativ_edu)
-- =============================================================================

-- Cursos oferecidos pela instituição
CREATE TABLE IF NOT EXISTS courses (
    id              INTEGER PRIMARY KEY,
    name            VARCHAR(255) NOT NULL,
    slug            VARCHAR(100) UNIQUE,
    description     TEXT,
    area            VARCHAR(100),       -- área temática: "financeiro", "agro", etc.
    carga_horaria   INTEGER DEFAULT 40, -- horas
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);

-- Pré-inscrições (dados brutos importados)
CREATE TABLE IF NOT EXISTS pre_inscriptions (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    person_id               VARCHAR(64) UNIQUE NOT NULL,  -- hash do sistema de origem
    email                   VARCHAR(255),
    nome_completo           VARCHAR(255),
    cpf                     VARCHAR(20),
    cpf_formatado           VARCHAR(20),
    cpf_valido              BOOLEAN DEFAULT FALSE,
    data_nascimento         VARCHAR(20),
    idade_calculada         INTEGER,
    genero                  VARCHAR(20),
    -- contato
    telefone_whatsapp       VARCHAR(25),   -- formato +55XXXXXXXXXXX
    telefone_original       VARCHAR(50),
    telefone_valido         BOOLEAN DEFAULT FALSE,
    -- endereço
    cep                     VARCHAR(15),
    endereco                TEXT,
    cidade                  VARCHAR(100),
    estado                  VARCHAR(5),
    -- disponibilidade
    disponibilidade         VARCHAR(100),
    -- datas
    data_primeira_inscricao TIMESTAMP,
    data_ultima_interacao   TIMESTAMP,
    -- controle de importação / conversão
    student_id              UUID REFERENCES students(id) ON DELETE SET NULL,
    importado_em            TIMESTAMP DEFAULT NOW(),
    convertido              BOOLEAN DEFAULT FALSE,  -- se virou student ativo
    review_required         BOOLEAN DEFAULT FALSE,
    obs                     TEXT
);

-- Relação pré-inscrição ↔ cursos (many-to-many)
CREATE TABLE IF NOT EXISTS pre_inscription_courses (
    pre_inscription_id  UUID REFERENCES pre_inscriptions(id) ON DELETE CASCADE,
    course_id           INTEGER REFERENCES courses(id),
    PRIMARY KEY (pre_inscription_id, course_id)
);

-- Estudantes e estado da trilha
CREATE TABLE IF NOT EXISTS students (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    phone           VARCHAR(20) UNIQUE NOT NULL,   -- número WhatsApp (ex: 5511999999999)
    name            VARCHAR(255),
    email           VARCHAR(255),
    course_id       INTEGER REFERENCES courses(id),
    current_module  INTEGER DEFAULT 0,
    completed_modules INTEGER[] DEFAULT '{}',
    scores          JSONB DEFAULT '{}',            -- {"module_1": 85, "module_2": 92}
    lead_score      INTEGER DEFAULT 0,
    lead_tags       TEXT[] DEFAULT '{}',           -- ["interesse_credito", "renda_alta"]
    lead_profile    VARCHAR(50),                   -- "hot", "warm", "cold"
    tutor_id        UUID,
    attendance_status VARCHAR(20) DEFAULT 'bot',   -- "bot" | "human" | "pending"
    certificate_id  UUID,
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);

-- Módulos do curso
CREATE TABLE IF NOT EXISTS modules (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    course_id       INTEGER REFERENCES courses(id),
    module_number   INTEGER NOT NULL,
    title           VARCHAR(255) NOT NULL,
    description     TEXT,
    content_text    TEXT,                          -- conteúdo processado da apostila
    quiz_questions  JSONB DEFAULT '[]',            -- array de questões
    passing_score   INTEGER DEFAULT 70,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMP DEFAULT NOW(),
    UNIQUE(course_id, module_number)
);

-- Embeddings vetoriais do material didático (pgvector)
CREATE TABLE IF NOT EXISTS document_chunks (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    module_id       UUID REFERENCES modules(id),
    source_file     VARCHAR(500),                  -- nome do arquivo original
    chunk_index     INTEGER,
    content         TEXT NOT NULL,
    embedding       vector(1536),                  -- dimensão compatível com OpenAI/DeepSeek
    metadata        JSONB DEFAULT '{}',
    created_at      TIMESTAMP DEFAULT NOW()
);

-- Índice para busca vetorial por similaridade
CREATE INDEX IF NOT EXISTS idx_chunks_embedding
    ON document_chunks USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100);

-- Certificados emitidos
CREATE TABLE IF NOT EXISTS certificates (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id      UUID REFERENCES students(id),
    course_id       INTEGER REFERENCES courses(id),
    issued_at       TIMESTAMP DEFAULT NOW(),
    score_final     INTEGER,
    pdf_path        VARCHAR(500),                  -- caminho no MinIO
    pdf_url         VARCHAR(1000),                 -- URL assinada para download
    verification_code VARCHAR(50) UNIQUE           -- QR Code / link de verificação
);

-- Sessões de atendimento humano (tutor / Chatwoot)
CREATE TABLE IF NOT EXISTS support_sessions (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id      UUID REFERENCES students(id),
    tutor_id        UUID,
    chatwoot_conversation_id INTEGER,              -- ID da conversa no Chatwoot
    reason          TEXT,                          -- por que precisou de humano
    started_at      TIMESTAMP DEFAULT NOW(),
    ended_at        TIMESTAMP,
    resolution      TEXT,
    bot_resumed     BOOLEAN DEFAULT FALSE
);

-- Log de eventos para N8N e métricas
CREATE TABLE IF NOT EXISTS events_log (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    student_id      UUID,
    event_type      VARCHAR(100) NOT NULL,         -- "module_completed", "quiz_passed", "lead_qualified"
    payload         JSONB DEFAULT '{}',
    created_at      TIMESTAMP DEFAULT NOW()
);

-- =============================================================================
-- SEED: CURSOS (IDs fixos mapeados dos dados de pré-inscrição)
-- =============================================================================
INSERT INTO courses (id, name, slug, area, is_active) VALUES
    (1,  'Administração e Gestão',                                        'admin-gestao',           'gestao',      true),
    (2,  'Saúde e Bem-estar',                                             'saude-bem-estar',        'saude',       true),
    (3,  'Turismo e Hospitalidade',                                       'turismo',                'servicos',    true),
    (4,  'Agronegócio e Produção Rural',                                  'agronegocio',            'agro',        true),
    (5,  'Gestão Financeira para Empreendimentos',                        'gestao-financeira',      'financeiro',  true),
    (6,  'Elaboração de Projetos para Captação de Recursos',              'captacao-recursos',      'gestao',      true),
    (7,  'Organização da Produção para o Mercado',                        'producao-mercado',       'agro',        true),
    (8,  'Logística Eficiente para Pequenos Empreendimentos',             'logistica',              'gestao',      true),
    (9,  'Mercados Institucionais',                                       'mercados-inst',          'gestao',      true),
    (10, 'Agroindústria e Acesso ao Mercado',                             'agroindustria',          'agro',        true),
    (11, 'Boas Práticas na Produção e Manipulação de Alimentos',          'boas-praticas-alimentos','alimentacao', true),
    (12, 'Restauração Florestal e Serviços Ambientais',                   'restauracao-florestal',  'ambiental',   true),
    (13, 'Desenvolvimento de Quintais Produtivos',                        'quintais-produtivos',    'agro',        true),
    (14, 'Práticas Extrativistas Sustentáveis e Valorização da Biodiversidade', 'extrativismo',    'ambiental',   true),
    (15, 'Crédito e Cooperativismo',                                      'credito-cooperativismo', 'financeiro',  true),
    (16, 'Produção Audiovisual',                                          'audiovisual',            'cultura',     true),
    (17, 'Educação Financeira',                                           'educacao-financeira',    'financeiro',  true),
    (18, 'Planejamento Produtivo',                                        'planejamento-produtivo', 'gestao',      true),
    (19, 'Inteligência Artificial e Inclusão Digital',                    'ia-inclusao-digital',    'tecnologia',  true),
    (20, 'Educação Financeira para Idosos',                               'educacao-financeira-idosos', 'financeiro', true),
    (21, 'Culinária Saudável',                                            'culinaria-saudavel',     'alimentacao', true)
ON CONFLICT (id) DO NOTHING;

-- =============================================================================
-- ÍNDICES DE PERFORMANCE
-- =============================================================================
CREATE INDEX IF NOT EXISTS idx_students_phone ON students(phone);
CREATE INDEX IF NOT EXISTS idx_students_course ON students(course_id);
CREATE INDEX IF NOT EXISTS idx_events_student ON events_log(student_id);
CREATE INDEX IF NOT EXISTS idx_events_type ON events_log(event_type);
CREATE INDEX IF NOT EXISTS idx_events_created ON events_log(created_at);
CREATE INDEX IF NOT EXISTS idx_preinscriptions_phone ON pre_inscriptions(telefone_whatsapp);
CREATE INDEX IF NOT EXISTS idx_preinscriptions_cpf ON pre_inscriptions(cpf);
CREATE INDEX IF NOT EXISTS idx_preinscriptions_convertido ON pre_inscriptions(convertido);
