-- =============================================================================
-- KREATIV EDUCAÇÃO — Módulos iniciais do curso padrão
-- Executado automaticamente na primeira inicialização OU manualmente
-- =============================================================================

-- Módulo 1: Introdução ao Empreendedorismo Digital
INSERT INTO modules (course_id, module_number, title, description, content_text, quiz_questions, passing_score)
VALUES (
  'default', 1,
  'Introdução ao Empreendedorismo Digital',
  'Fundamentos para começar no mundo digital',
  E'Módulo 1: Introdução ao Empreendedorismo Digital\n\nBem-vindo à sua jornada de aprendizado! Neste módulo você vai entender os fundamentos do empreendedorismo no mundo digital.\n\nO que é empreendedorismo digital?\nÉ a criação e gestão de negócios usando tecnologia e internet como base. Diferente do empreendedorismo tradicional, permite escalar com menos custo e atingir clientes no mundo todo.\n\n3 Pilares do negócio digital:\n- Produto/Serviço: O que você oferece de valor\n- Audiência: Para quem você oferece\n- Canal: Como você chega até seu cliente\n\nExemplo prático:\nUm professor que cria cursos online está empreendendo digitalmente. Seu produto é o conhecimento, sua audiência são os alunos, e seu canal pode ser WhatsApp, Instagram ou uma plataforma.\n\nLeia com atenção e quando estiver pronto, responda QUIZ para testar o que aprendeu.',
  '[{"id":1,"question":"Qual é um dos 3 pilares do negócio digital?","options":{"A":"Produto/Serviço","B":"Escritório físico","C":"Funcionários"},"answer":"A","feedbackCorrect":"Correto! Produto/Serviço é um dos pilares junto com Audiência e Canal.","feedbackWrong":"A resposta correta é A) Produto/Serviço — os 3 pilares são: Produto, Audiência e Canal."}]',
  70
)
ON CONFLICT (course_id, module_number) DO NOTHING;

-- Módulo 2: Público-Alvo
INSERT INTO modules (course_id, module_number, title, description, content_text, quiz_questions, passing_score)
VALUES (
  'default', 2,
  'Identificando seu Público-Alvo',
  'Como descobrir e entender quem é seu cliente ideal',
  E'Módulo 2: Identificando seu Público-Alvo\n\nConhecer seu cliente ideal é a base de qualquer negócio de sucesso. Sem isso, você estará atirando no escuro.\n\nO que é persona?\nPersona é a representação fictícia do seu cliente ideal, baseada em dados reais. Ela tem nome, idade, profissão, dores e sonhos.\n\nComo criar sua persona:\n1. Dados demográficos: Idade, localização, profissão, renda\n2. Comportamento: O que faz no dia a dia, quais redes usa\n3. Dores: Quais problemas enfrenta que você pode resolver\n4. Objetivos: O que ela quer alcançar\n\nExemplo de persona:\nCarla, 35 anos, professora de escola pública, quer complementar sua renda mas não tem tempo para um segundo emprego. Busca formas de ensinar online nas horas vagas.\n\nQuando terminar, responda QUIZ para avançar.',
  '[{"id":1,"question":"O que é uma persona no marketing digital?","options":{"A":"Um anúncio pago","B":"Representação fictícia do cliente ideal baseada em dados reais","C":"Um perfil nas redes sociais"},"answer":"B","feedbackCorrect":"Perfeito! A persona é a representação do cliente ideal que guia suas decisões de marketing.","feedbackWrong":"A resposta correta é B. Persona é a representação fictícia do cliente ideal, baseada em dados reais."}]',
  70
)
ON CONFLICT (course_id, module_number) DO NOTHING;

-- Módulo 3: Produto Digital
INSERT INTO modules (course_id, module_number, title, description, content_text, quiz_questions, passing_score)
VALUES (
  'default', 3,
  'Criando seu Produto Digital',
  'Tipos de produtos digitais e como criar o seu',
  E'Módulo 3: Criando seu Produto Digital\n\nAgora que você conhece seu público, vamos criar um produto que resolva os problemas dele.\n\nTipos de produtos digitais:\n- E-books: Guias em PDF sobre um tema específico\n- Cursos online: Aulas gravadas ou ao vivo\n- Templates: Modelos prontos para usar\n- Mentorias: Acompanhamento personalizado\n- Comunidades: Grupos pagos com conteúdo exclusivo\n\nComo escolher o melhor formato:\nPense no que seu público-alvo prefere consumir. Pessoas que leram bastante → e-book. Pessoas visuais → curso em vídeo. Pessoas que precisam de atenção → mentoria.\n\nPrimeiro produto: Comece simples. Um e-book de 20 páginas respondendo uma dúvida comum do seu público já é um produto digital válido.\n\nQuando terminar, responda QUIZ para avançar.',
  '[{"id":1,"question":"Qual é o tipo de produto digital mais indicado para quem quer começar com baixo investimento?","options":{"A":"Aplicativo mobile","B":"E-book","C":"Software SaaS"},"answer":"B","feedbackCorrect":"Exato! O e-book é o ponto de entrada ideal: baixo custo de produção e entrega instantânea.","feedbackWrong":"A resposta correta é B) E-book — é o produto digital com menor barreira de entrada para começar."}]',
  70
)
ON CONFLICT (course_id, module_number) DO NOTHING;
