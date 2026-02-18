-- =============================================================================
-- MIGRAÇÃO: Adiciona courses, pre_inscriptions e ajusta students
-- Aplicar manualmente: docker exec -i kreativ_postgres psql -U kreativ_user -d kreativ_edu < 02-migration-courses.sql
-- =============================================================================

BEGIN;

-- 1. Tabela de cursos
CREATE TABLE IF NOT EXISTS courses (
    id              INTEGER PRIMARY KEY,
    name            VARCHAR(255) NOT NULL,
    slug            VARCHAR(100) UNIQUE,
    description     TEXT,
    area            VARCHAR(100),
    carga_horaria   INTEGER DEFAULT 40,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMP DEFAULT NOW(),
    updated_at      TIMESTAMP DEFAULT NOW()
);

-- 2. Seed dos cursos
INSERT INTO courses (id, name, slug, area, is_active) VALUES
    (1,  'Administração e Gestão',                                         'admin-gestao',                'gestao',      true),
    (2,  'Saúde e Bem-estar',                                              'saude-bem-estar',             'saude',       true),
    (3,  'Turismo e Hospitalidade',                                        'turismo',                     'servicos',    true),
    (4,  'Agronegócio e Produção Rural',                                   'agronegocio',                 'agro',        true),
    (5,  'Gestão Financeira para Empreendimentos',                         'gestao-financeira',           'financeiro',  true),
    (6,  'Elaboração de Projetos para Captação de Recursos',               'captacao-recursos',           'gestao',      true),
    (7,  'Organização da Produção para o Mercado',                         'producao-mercado',            'agro',        true),
    (8,  'Logística Eficiente para Pequenos Empreendimentos',              'logistica',                   'gestao',      true),
    (9,  'Mercados Institucionais',                                        'mercados-inst',               'gestao',      true),
    (10, 'Agroindústria e Acesso ao Mercado',                              'agroindustria',               'agro',        true),
    (11, 'Boas Práticas na Produção e Manipulação de Alimentos',           'boas-praticas-alimentos',     'alimentacao', true),
    (12, 'Restauração Florestal e Serviços Ambientais',                    'restauracao-florestal',       'ambiental',   true),
    (13, 'Desenvolvimento de Quintais Produtivos',                         'quintais-produtivos',         'agro',        true),
    (14, 'Práticas Extrativistas Sustentáveis e Valorização da Biodiversidade', 'extrativismo',          'ambiental',   true),
    (15, 'Crédito e Cooperativismo',                                       'credito-cooperativismo',      'financeiro',  true),
    (16, 'Produção Audiovisual',                                           'audiovisual',                 'cultura',     true),
    (17, 'Educação Financeira',                                            'educacao-financeira',         'financeiro',  true),
    (18, 'Planejamento Produtivo',                                         'planejamento-produtivo',      'gestao',      true),
    (19, 'Inteligência Artificial e Inclusão Digital',                     'ia-inclusao-digital',         'tecnologia',  true),
    (20, 'Educação Financeira para Idosos',                                'educacao-financeira-idosos',  'financeiro',  true),
    (21, 'Culinária Saudável',                                             'culinaria-saudavel',          'alimentacao', true)
ON CONFLICT (id) DO NOTHING;

-- 3. Converter students.course_id de VARCHAR para INTEGER
--    (seguro: apenas 2 registros de teste com course_id NULL)
DROP INDEX IF EXISTS idx_students_course;
ALTER TABLE students ALTER COLUMN course_id TYPE INTEGER USING NULL::INTEGER;
ALTER TABLE students ADD CONSTRAINT fk_students_course FOREIGN KEY (course_id) REFERENCES courses(id);
CREATE INDEX IF NOT EXISTS idx_students_course ON students(course_id);

-- 4. Tabela de pré-inscrições
CREATE TABLE IF NOT EXISTS pre_inscriptions (
    id                      UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    person_id               VARCHAR(64) UNIQUE NOT NULL,
    email                   VARCHAR(255),
    nome_completo           VARCHAR(255),
    cpf                     VARCHAR(20),
    cpf_formatado           VARCHAR(20),
    cpf_valido              BOOLEAN DEFAULT FALSE,
    data_nascimento         VARCHAR(20),
    idade_calculada         INTEGER,
    genero                  VARCHAR(20),
    telefone_whatsapp       VARCHAR(25),
    telefone_original       VARCHAR(50),
    telefone_valido         BOOLEAN DEFAULT FALSE,
    cep                     VARCHAR(15),
    endereco                TEXT,
    cidade                  VARCHAR(100),
    estado                  VARCHAR(5),
    disponibilidade         VARCHAR(100),
    data_primeira_inscricao TIMESTAMP,
    data_ultima_interacao   TIMESTAMP,
    student_id              UUID REFERENCES students(id) ON DELETE SET NULL,
    importado_em            TIMESTAMP DEFAULT NOW(),
    convertido              BOOLEAN DEFAULT FALSE,
    review_required         BOOLEAN DEFAULT FALSE,
    obs                     TEXT
);

-- 5. Relação pré-inscrição ↔ cursos
CREATE TABLE IF NOT EXISTS pre_inscription_courses (
    pre_inscription_id  UUID REFERENCES pre_inscriptions(id) ON DELETE CASCADE,
    course_id           INTEGER REFERENCES courses(id),
    PRIMARY KEY (pre_inscription_id, course_id)
);

-- 6. Adicionar campo Chatwoot em support_sessions
ALTER TABLE support_sessions
    ADD COLUMN IF NOT EXISTS chatwoot_conversation_id INTEGER;

-- 7. Índices para pré-inscrições
CREATE INDEX IF NOT EXISTS idx_preinscriptions_phone      ON pre_inscriptions(telefone_whatsapp);
CREATE INDEX IF NOT EXISTS idx_preinscriptions_cpf        ON pre_inscriptions(cpf);
CREATE INDEX IF NOT EXISTS idx_preinscriptions_convertido ON pre_inscriptions(convertido);

COMMIT;
