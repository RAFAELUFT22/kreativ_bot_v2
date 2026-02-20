-- =============================================================================
-- MIGRAÇÃO: Corrigir course_id em modules + Seed TDS (Programa TDS Tocantins)
-- =============================================================================
-- Problema: modules.course_id é VARCHAR(100) mas students.course_id é INTEGER.
-- O AI Router V3 consulta: WHERE m.course_id = '{{ student.course_id }}'
-- Quando aluno tem course_id=4 (Agronegócio), não encontra módulos 'curso_agro'.
--
-- Solução:
--   1. Adicionar course_int_id INTEGER FK para compatibilidade tipada
--   2. Backfill dados existentes
--   3. Re-seed TDS com IDs de courses corretos
--   4. Criar índice para performance
--
-- Aplicar: docker exec -i kreativ_postgres psql -U kreativ_user -d kreativ_edu < scripts/03-migration-tds-modules.sql
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- STEP 1: Adicionar coluna course_int_id
-- -----------------------------------------------------------------------------
ALTER TABLE modules ADD COLUMN IF NOT EXISTS course_int_id INTEGER REFERENCES courses(id);

-- -----------------------------------------------------------------------------
-- STEP 2: Backfill — mapear course_id (TEXT) para course_int_id (INTEGER)
-- Mapeamento:
--   '19'                       → 19 (Inteligência Artificial e Inclusão Digital)
--   'default'                  → 19 (fallback para curso IA)
--   'curso_agro'               → 4  (Agronegócio e Produção Rural)
--   'curso_empreendedor_urbano'→ 5  (Gestão Financeira para Empreendimentos)
-- -----------------------------------------------------------------------------
UPDATE modules SET course_int_id = 19   WHERE course_id IN ('19', 'default');
UPDATE modules SET course_int_id = 4    WHERE course_id = 'curso_agro';
UPDATE modules SET course_int_id = 5    WHERE course_id = 'curso_empreendedor_urbano';

-- -----------------------------------------------------------------------------
-- STEP 3: Criar índice para queries do AI Router
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_modules_course_int ON modules(course_int_id);
CREATE INDEX IF NOT EXISTS idx_modules_course_module ON modules(course_int_id, module_number);

-- -----------------------------------------------------------------------------
-- STEP 4: Adicionar colunas de suporte ao GUI Admin
-- -----------------------------------------------------------------------------
ALTER TABLE modules ADD COLUMN IF NOT EXISTS is_published BOOLEAN DEFAULT FALSE;
ALTER TABLE modules ADD COLUMN IF NOT EXISTS media_urls   TEXT[]  DEFAULT '{}';
ALTER TABLE modules ADD COLUMN IF NOT EXISTS updated_at   TIMESTAMP DEFAULT NOW();

-- -----------------------------------------------------------------------------
-- STEP 5: Re-seed módulos TDS com course_int_id correto
-- Trilha Agronegócio (course_int_id = 4)
-- -----------------------------------------------------------------------------
INSERT INTO modules (course_id, course_int_id, module_number, title, description, content_text, passing_score, is_published)
VALUES (
  '4', 4, 1,
  'Documentação e Formalização Rural',
  'Como tirar DAP e CAF sem dor de cabeça.',
  'Objetivo: Ensinar a importância e o passo a passo simplificado para emissão da DAP e do CAF. Tópicos: O que são esses documentos, quem tem direito (agricultor familiar, quilombola), quais documentos reunir e onde ir (Sindicatos, Emater). Dificuldade base: Muito simples e encorajador. Foque em desmistificar a burocracia.',
  70, TRUE
) ON CONFLICT (course_id, module_number) DO UPDATE
  SET course_int_id = EXCLUDED.course_int_id,
      content_text  = EXCLUDED.content_text,
      is_published  = EXCLUDED.is_published,
      updated_at    = NOW();

INSERT INTO modules (course_id, course_int_id, module_number, title, description, content_text, passing_score, is_published)
VALUES (
  '4', 4, 2,
  'Vendendo para o Governo (PAA e PNAE)',
  'Como garantir a venda da sua safra para escolas e prefeituras.',
  'Objetivo: Explicar como acessar o PAA (Programa de Aquisição de Alimentos) e o PNAE (Programa Nacional de Alimentação Escolar). Tópicos: Diferença entre vender na feira e vender para a escola, a importância de estar em associações/cooperativas, como funciona o pagamento e as chamadas públicas. Dificuldade base: Prático e motivacional.',
  70, TRUE
) ON CONFLICT (course_id, module_number) DO UPDATE
  SET course_int_id = EXCLUDED.course_int_id,
      content_text  = EXCLUDED.content_text,
      is_published  = EXCLUDED.is_published,
      updated_at    = NOW();

INSERT INTO modules (course_id, course_int_id, module_number, title, description, content_text, passing_score, is_published)
VALUES (
  '4', 4, 3,
  'Crédito Rural e Pronaf B',
  'Como conseguir crédito para insumos e equipamentos.',
  'Objetivo: Orientar sobre acesso a crédito produtivo. Tópicos: O que é o Pronaf B (Microcrédito Rural), como solicitar, cuidados para não se endividar, usando o crédito para compra de insumos e equipamentos. Dificuldade base: Alerta sobre planejamento financeiro familiar versus dinheiro do negócio.',
  70, TRUE
) ON CONFLICT (course_id, module_number) DO UPDATE
  SET course_int_id = EXCLUDED.course_int_id,
      content_text  = EXCLUDED.content_text,
      is_published  = EXCLUDED.is_published,
      updated_at    = NOW();

-- -----------------------------------------------------------------------------
-- STEP 6: Re-seed módulos TDS com course_int_id correto
-- Trilha Gestão Financeira para Empreendimentos (course_int_id = 5)
-- -----------------------------------------------------------------------------
INSERT INTO modules (course_id, course_int_id, module_number, title, description, content_text, passing_score, is_published)
VALUES (
  '5', 5, 1,
  'O Valor do seu Trabalho (Precificação)',
  'Como calcular o preço do seu artesanato ou serviço.',
  'Objetivo: Ensinar cálculo básico de custos e precificação. Tópicos: Como somar o custo dos insumos (que estão caros), calcular o valor da própria hora de trabalho, e definir um preço de venda justo para o mercado local e feiras. Dificuldade base: Usar exemplos do dia a dia (ex: custo do barbante para tapete ou gasolina para transporte).',
  70, TRUE
) ON CONFLICT (course_id, module_number) DO UPDATE
  SET course_int_id = EXCLUDED.course_int_id,
      content_text  = EXCLUDED.content_text,
      is_published  = EXCLUDED.is_published,
      updated_at    = NOW();

INSERT INTO modules (course_id, course_int_id, module_number, title, description, content_text, passing_score, is_published)
VALUES (
  '5', 5, 2,
  'Saindo da Informalidade (MEI)',
  'Vantagens e direitos de abrir um CNPJ MEI.',
  'Objetivo: Mostrar os benefícios da formalização. Tópicos: Diferença entre trabalho eventual/bico e MEI. Benefícios previdenciários (auxílio-doença, aposentadoria), como emitir nota fiscal para vender mais, e o custo mensal (DAS). Dificuldade base: Focar na segurança que a formalização traz para a família.',
  70, TRUE
) ON CONFLICT (course_id, module_number) DO UPDATE
  SET course_int_id = EXCLUDED.course_int_id,
      content_text  = EXCLUDED.content_text,
      is_published  = EXCLUDED.is_published,
      updated_at    = NOW();

INSERT INTO modules (course_id, course_int_id, module_number, title, description, content_text, passing_score, is_published)
VALUES (
  '5', 5, 3,
  'Microcrédito e Capital de Giro',
  'Como usar crédito para crescer sem se enforcar.',
  'Objetivo: Educação financeira para microempreendedores. Tópicos: O que é capital de giro, como separar o dinheiro de casa do dinheiro do negócio, e como solicitar microcrédito de forma consciente para comprar mercadoria (comércio) ou ferramentas (serviços). Dificuldade base: Preventivo, foco em não misturar as contas.',
  70, TRUE
) ON CONFLICT (course_id, module_number) DO UPDATE
  SET course_int_id = EXCLUDED.course_int_id,
      content_text  = EXCLUDED.content_text,
      is_published  = EXCLUDED.is_published,
      updated_at    = NOW();

-- -----------------------------------------------------------------------------
-- STEP 7: Marcar módulos course_id='19' como publicados (já têm conteúdo)
-- -----------------------------------------------------------------------------
UPDATE modules SET is_published = TRUE, course_int_id = 19
WHERE course_id = '19' AND is_published = FALSE;

-- -----------------------------------------------------------------------------
-- STEP 8: Adicionar rubricas de avaliação generativa para os cursos TDS
-- -----------------------------------------------------------------------------
UPDATE modules SET evaluation_rubric =
  'O aluno deve demonstrar que entendeu o que é a DAP/CAF, para quem serve (agricultores familiares, quilombolas) e quais são os documentos necessários para emiti-la. Aceitar qualquer resposta que mencione: documentação, Emater, sindicato rural, ou agricultura familiar.'
WHERE course_int_id = 4 AND module_number = 1;

UPDATE modules SET evaluation_rubric =
  'O aluno deve explicar ao menos um dos programas (PAA ou PNAE) e conectá-lo à sua realidade como produtor. Aceitar resposta que mencione: escola, prefeitura, chamada pública, preço mínimo garantido, ou cooperativa.'
WHERE course_int_id = 4 AND module_number = 2;

UPDATE modules SET evaluation_rubric =
  'O aluno deve demonstrar que entendeu o que é o Pronaf B e citar pelo menos um cuidado ao contrair crédito rural. Aceitar resposta que mencione: planejamento, custo do crédito, separar dinheiro pessoal do negócio, ou finalidade produtiva.'
WHERE course_int_id = 4 AND module_number = 3;

UPDATE modules SET evaluation_rubric =
  'O aluno deve demonstrar que entende como calcular o preço do seu produto/serviço, incluindo insumos e hora de trabalho. Aceitar resposta que mencione: custo, margem, hora de trabalho, ou preço de venda.'
WHERE course_int_id = 5 AND module_number = 1;

UPDATE modules SET evaluation_rubric =
  'O aluno deve explicar pelo menos uma vantagem do MEI para seu trabalho. Aceitar resposta que mencione: nota fiscal, aposentadoria, auxílio-doença, crédito mais fácil, ou formalização.'
WHERE course_int_id = 5 AND module_number = 2;

UPDATE modules SET evaluation_rubric =
  'O aluno deve demonstrar que entendeu a diferença entre capital pessoal e capital de giro do negócio. Aceitar resposta que mencione: separar contas, fluxo de caixa, reinvestimento, ou comprar mercadoria.'
WHERE course_int_id = 5 AND module_number = 3;

-- -----------------------------------------------------------------------------
-- STEP 9: Tabela de conteúdo estruturado para GUI Admin
-- Permite que o ToolJet edite seções de conteúdo de forma granular
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS module_content_sections (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    module_id    UUID NOT NULL REFERENCES modules(id) ON DELETE CASCADE,
    section_type VARCHAR(50) NOT NULL, -- 'intro', 'concept', 'example', 'activity', 'summary'
    sort_order   INTEGER DEFAULT 0,
    title        VARCHAR(255),
    body         TEXT NOT NULL,
    media_url    VARCHAR(1000),
    created_at   TIMESTAMP DEFAULT NOW(),
    updated_at   TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_mcs_module ON module_content_sections(module_id, sort_order);

-- -----------------------------------------------------------------------------
-- STEP 10: Remover entradas com course_id legado (string slug)
-- agora que os dados foram migrados para course_id numérico
-- -----------------------------------------------------------------------------
DELETE FROM modules WHERE course_id IN ('curso_agro', 'curso_empreendedor_urbano', 'default')
  AND course_int_id IS NOT NULL; -- só remove se backfill foi feito

COMMIT;

-- =============================================================================
-- VERIFICAÇÃO PÓS-MIGRAÇÃO
-- =============================================================================
SELECT
    c.id as course_id,
    c.name as course_name,
    count(m.id) as total_modules,
    count(m.evaluation_rubric) as modules_with_rubric,
    count(m.is_published) filter (where m.is_published = true) as published
FROM courses c
LEFT JOIN modules m ON m.course_int_id = c.id
WHERE c.id IN (4, 5, 19)
GROUP BY c.id, c.name
ORDER BY c.id;
