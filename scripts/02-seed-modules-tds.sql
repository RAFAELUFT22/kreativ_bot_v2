-- =============================================================================
-- KREATIV EDUCAÇÃO — Ementas Adaptativas para o Programa TDS
-- O campo 'content_text' agora guarda a DIRETRIZ para a IA, e não o texto final.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- TRILHA 1: AGRICULTURA FAMILIAR E AGROPECUÁRIA ('curso_agro')
-- Foco: Superar falta de documentação e acessar mercados institucionais.
-- -----------------------------------------------------------------------------

INSERT INTO modules (course_id, module_number, title, description, content_text, quiz_questions, passing_score)
VALUES (
  'curso_agro', 1,
  'Documentação e Formalização Rural',
  'Como tirar DAP e CAF sem dor de cabeça.',
  'Objetivo: Ensinar a importância e o passo a passo simplificado para emissão da DAP e do CAF. Tópicos: O que são esses documentos, quem tem direito (agricultor familiar, quilombola), quais documentos reunir e onde ir (Sindicatos, Emater). Dificuldade base: Muito simples e encorajador. Foque em desmistificar a burocracia.',
  '[]', 70
) ON CONFLICT (course_id, module_number) DO UPDATE SET content_text = EXCLUDED.content_text, title = EXCLUDED.title;

INSERT INTO modules (course_id, module_number, title, description, content_text, quiz_questions, passing_score)
VALUES (
  'curso_agro', 2,
  'Vendendo para o Governo (PAA e PNAE)',
  'Como garantir a venda da sua safra para escolas e prefeituras.',
  'Objetivo: Explicar como acessar o PAA (Programa de Aquisição de Alimentos) e o PNAE (Programa Nacional de Alimentação Escolar). Tópicos: Diferença entre vender na feira e vender para a escola, a importância de estar em associações/cooperativas, como funciona o pagamento e as chamadas públicas. Dificuldade base: Prático e motivacional.',
  '[]', 70
) ON CONFLICT (course_id, module_number) DO UPDATE SET content_text = EXCLUDED.content_text, title = EXCLUDED.title;

INSERT INTO modules (course_id, module_number, title, description, content_text, quiz_questions, passing_score)
VALUES (
  'curso_agro', 3,
  'Crédito Rural e Pronaf B',
  'Como conseguir crédito para insumos e equipamentos.',
  'Objetivo: Orientar sobre acesso a crédito produtivo. Tópicos: O que é o Pronaf B (Microcrédito Rural), como solicitar, cuidados para não se endividar, usando o crédito para compra de insumos e equipamentos. Dificuldade base: Alerta sobre planejamento financeiro familiar versus dinheiro do negócio.',
  '[]', 70
) ON CONFLICT (course_id, module_number) DO UPDATE SET content_text = EXCLUDED.content_text, title = EXCLUDED.title;


-- -----------------------------------------------------------------------------
-- TRILHA 2: ARTESANATO, COMÉRCIO E SERVIÇOS ('curso_empreendedor_urbano')
-- Foco: Precificação, MEI e acesso a microcrédito.
-- -----------------------------------------------------------------------------

INSERT INTO modules (course_id, module_number, title, description, content_text, quiz_questions, passing_score)
VALUES (
  'curso_empreendedor_urbano', 1,
  'O Valor do seu Trabalho (Precificação)',
  'Como calcular o preço do seu artesanato ou serviço.',
  'Objetivo: Ensinar cálculo básico de custos e precificação. Tópicos: Como somar o custo dos insumos (que estão caros), calcular o valor da própria hora de trabalho, e definir um preço de venda justo para o mercado local e feiras. Dificuldade base: Usar exemplos do dia a dia (ex: custo do barbante para tapete ou gasolina para transporte).',
  '[]', 70
) ON CONFLICT (course_id, module_number) DO UPDATE SET content_text = EXCLUDED.content_text, title = EXCLUDED.title;

INSERT INTO modules (course_id, module_number, title, description, content_text, quiz_questions, passing_score)
VALUES (
  'curso_empreendedor_urbano', 2,
  'Saindo da Informalidade (MEI)',
  'Vantagens e direitos de abrir um CNPJ MEI.',
  'Objetivo: Mostrar os benefícios da formalização. Tópicos: Diferença entre trabalho eventual/bico e MEI. Benefícios previdenciários (auxílio-doença, aposentadoria), como emitir nota fiscal para vender mais, e o custo mensal (DAS). Dificuldade base: Focar na segurança que a formalização traz para a família.',
  '[]', 70
) ON CONFLICT (course_id, module_number) DO UPDATE SET content_text = EXCLUDED.content_text, title = EXCLUDED.title;

INSERT INTO modules (course_id, module_number, title, description, content_text, quiz_questions, passing_score)
VALUES (
  'curso_empreendedor_urbano', 3,
  'Microcrédito e Capital de Giro',
  'Como usar crédito para crescer sem se enforcar.',
  'Objetivo: Educação financeira para microempreendedores. Tópicos: O que é capital de giro, como separar o dinheiro de casa do dinheiro do negócio, e como solicitar microcrédito de forma consciente para comprar mercadoria (comércio) ou ferramentas (serviços). Dificuldade base: Preventivo, foco em não misturar as contas.',
  '[]', 70
) ON CONFLICT (course_id, module_number) DO UPDATE SET content_text = EXCLUDED.content_text, title = EXCLUDED.title;
