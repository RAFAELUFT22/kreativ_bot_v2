# Roadmap: Gestão Pedagógica (Cursos, Módulos e Tutores)

Este roadmap define as etapas para estruturar a relação entre Cursos, Módulos e Tutores, preenchendo as atuais lacunas de roteamento e gestão de conteúdo.

## Fase 1: Estruturação do Banco de Dados (PostgreSQL)

**Objetivo:** Criar as entidades necessárias para representar Tutores e conectá-las aos Cursos e Módulos.

1.  **Criar Tabela `tutors`:**
    *   `id` (UUID)
    *   `name` (VARCHAR)
    *   `email` (VARCHAR, UNIQUE)
    *   `whatsapp_number` (VARCHAR) - Para notificações de fallback (opcional mas recomendado).
    *   `chatwoot_agent_id` (INTEGER) - ID real do agente/usuário lá no Chatwoot.
    *   `chatwoot_inbox_id` (INTEGER) - Caixa de entrada específica (se aplicável) no Chatwoot.
    *   `is_active` (BOOLEAN)
2.  **Referenciar Tutores nos Cursos (`courses`):**
    *   Adicionar coluna `coordinator_id` ou `tutor_id` (UUID, FOREIGN KEY referência `tutors(id)`) à tabela `courses`. Isso define o tutor primário responsável.
3.  **Aprimorar a Tabela `modules`:**
    *   Assegurar que os campos `content_text` (conteúdo pedagógico) e `evaluation_rubric` (critério de correção) estejam completos. (Já existem, mas precisam ser ativamente usados/validados).
4.  **Aprimorar `module_content_sections`:**
    *   Garantir a segmentação do conteúdo (`intro`, `concept`, `activity`, etc.) para facilitar a ingestão e edição via frontend.

## Fase 2: Roteamento Inteligente no n8n

**Objetivo:** Substituir o roteamento cego (hardcoded) por decisões dinâmicas baseadas no Tutor responsável pelo aluno/curso.

1.  **Modificar Webhook `14-tool-request-tutor`:**
    *   **Atual:** Notifica sempre o mesmo grupo de WhatsApp (`120363198506827018@g.us`) e roteia para a mesma `inbox_id` (2).
    *   **Novo Workflow:**
        *   Consultar a tabela `courses` usando o `course_id` do aluno.
        *   Obter o `tutor_id` vinculado a este curso.
        *   Consultar a tabela `tutors` para obter o `chatwoot_agent_id`, `chatwoot_inbox_id` e `whatsapp_number`.
        *   Criar a conversa no Chatwoot direcionando para a `inbox_id` correta e (se a API permitir) atribuindo ao `chatwoot_agent_id` correto.
        *   A notificação (via Evolution API) deve ir para o número de WhatsApp individual do Tutor, e não para o grupo geral (ou então para o grupo, mas marcando o Tutor).
2.  **Modificar Webhook `04-request-human-support`:**
    *   Atualizar a lógica de forma similar ao passo anterior.
    *   O Roteamento de transbordo (`inbox_id: 1`) deve ser inteligente.

## Fase 3: Operacionalização (Interface Admin ToolJet)

**Objetivo:** Prover uma interface amigável para que a equipe pedagógica insira os dados sem tocar em SQL.

1.  **App ToolJet "Gestão de Tutores":**
    *   **Tela 1:** Cadastro, Edição e Remoção de Tutores (CRUD na tabela `tutors`).
    *   **Importante:** Incluir o mapeamento de qual ID esse tutor usa no Chatwoot.
2.  **App ToolJet "Cursos e Módulos" (Aprimoramentos):**
    *   **Associação Tutor -> Curso:** Na tela de edição de um Curso, adicionar um *Dropdown* (Select) listando os tutores ativos, para vincular um Curso a um Tutor.
    *   **Gestão de Conteúdo Base (`module_content_sections`):** Formulários ricos para inserir textos e subir PDFs. Este conteúdo é a *fonte da verdade* do curso.
    *   **Gestão de Rubricas (`modules.evaluation_rubric`):** Campo textual obrigatório para a área pedagógica definir *como* a IA deve avaliar os quizzes ou atividades discursivas.

## Fase 4: Sincronização e Ingestão no RAG (Documentos e Vetores)

**Objetivo:** Alimentar o AI Tutor com o conteúdo real que os Coordenadores/Tutores inseriram via ToolJet.

1.  **Workflow n8n de Ingestão (`22-rag-ingestion.json`):**
    *   Criar ou ajustar o fluxo que é disparado quando um Coordenador salva um material novo (ou atualiza) no ToolJet.
    *   O fluxo consome os PDFs ou o campo `content_text`, *chunkifica* o texto.
    *   Gera os vetores (`embeddings`) via API (OpenAI/DeepSeek).
    *   Salva os vetores no PostgreSQL (pgvector) na tabela `document_chunks`.
2.  **AI Tutor (DeepSeek) com Contexto Certo:**
    *   Quando o Aluno faz uma pergunta, o n8n primeiro busca no `document_chunks` os pedaços de texto relativos ao `course_id` e `module_number` atuais.
    *   Alimenta o prompt do DeepSeek: "Você é o tutor da disciplina [X]... Baseado neste texto [Y], responda a dúvida: [Z]".
