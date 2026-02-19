-- Migration: Pivot to Generative Evaluation
-- Removes numeric quiz questions and adds textual rubrics for AI evaluation.

-- 1. Add the column
ALTER TABLE modules ADD COLUMN IF NOT EXISTS evaluation_rubric TEXT;

-- 2. Update existing modules with sample rubrics
UPDATE modules SET evaluation_rubric = 'O aluno deve demonstrar que entendeu que o empreendedorismo digital utiliza a internet para escalar negócios e citar pelo menos um dos pilares (Produto, Audiência ou Canal).' WHERE module_number = 1;
UPDATE modules SET evaluation_rubric = 'O aluno deve explicar que Persona é uma representação baseada em dados reais do cliente ideal e por que ela é importante para as decisões de marketing.' WHERE module_number = 2;
UPDATE modules SET evaluation_rubric = 'O aluno deve citar pelo menos dois tipos de produtos digitais (ex: e-book, curso, mentoria) e explicar o critério de escolha baseado na preferência do público.' WHERE module_number = 3;
UPDATE modules SET evaluation_rubric = 'O aluno deve dar um exemplo de como a IA pode ser usada para aumentar a produtividade no trabalho ou na vida pessoal conforme discutido no módulo.' WHERE module_number = 4;
UPDATE modules SET evaluation_rubric = 'O aluno deve resumir o que aprendeu ao longo do curso e demonstrar prontidão para aplicar os conceitos em um projeto real.' WHERE module_number = 5;

-- 3. (Optional/Destructive) Remove quiz_questions column
-- ALTER TABLE modules DROP COLUMN quiz_questions;
