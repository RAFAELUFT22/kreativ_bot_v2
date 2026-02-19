# ROADMAP — Kreativ Educação: Próximos Passos de Implementação

> Baseado em: `arquitetura_builderbot_definitiva.docx`
> Atualizado em: 19/02/2026 (Pós-Implantação v2.0)

---

## Fases Concluídas ✅

### Fase 1 — Infra Base ✅
- Coolify configurado na VPS Hostinger (7.8GB RAM, 2 vCPU)
- Subdomínios com SSL via Traefik + Let's Encrypt
- Containers: PostgreSQL + pgvector, Redis, MinIO, Evolution API

### Fase 2 — BuilderBot + Evolution ✅
- BuilderBot rodando com `@builderbot/provider-evolution-api`
- Recebe e responde mensagens WhatsApp
- Flows: welcome, module, quiz, human-support, ai-tutor

### Fase 3 — Primeiro Flow de Boas-Vindas ✅
- Onboarding: menu principal
- Opções: 1=iniciar trilha, 2=continuar, 3=tutor, 4=certificado
- AI fallback via DeepSeek para mensagens livres

### Módulos e Quiz (parte da Fase 5) ✅
- Conteúdo dos módulos sendo entregue via WhatsApp
- Quiz com questões reais do banco de dados
- Score calculado e progresso salvo no PostgreSQL

### FASE 7 — ToolJet (Painel Administrativo) ✅
- **URL**: `https://admin.extensionista.site`
- **Status**: Online. DB `tooljet_db` criado.
- **Função**: Gestão de módulos e alunos (low-code).

### FASE 8 — Chatwoot (Tutores) ✅
- **URL**: `https://suporte.extensionista.site`
- **Status**: Online e Integrado.
- **Fluxo**:
  1. Aluno pede TUTOR -> N8N seta `attendance_status='human'`
  2. N8N cria conversa no Chatwoot via API
  3. Tutor responde -> Evolution API envia
  4. Tutor resolve ticket -> Webhook Chatwoot chama N8N -> Retoma Bot

### FASE 9 — Scoring + Qualificação de Leads ✅
- **Status**: Workflows N8N ativos.
- **Lógica**:
  - Módulo completo -> Calcula Score -> Atualiza Label Chatwoot
  - Envia msg parabéns se score > 70%

### FASE 10 — Certificados Automáticos ✅
- **Status**: Implementado (versão HTML).
- **Fluxo**:
  - Conclusão do curso -> N8N gera HTML
  - Salva no MinIO (bucket: certificados)
  - Envia link via WhatsApp e Portal do Aluno

### FASE 11 — Metabase (Analytics) ✅
- **URL**: `https://dash.extensionista.site`
- **Status**: Online. Conectado ao `kreativ_edu`.

### FASE 12 — Portal Next.js (Conteúdo Rico) ✅
- **URL**: `https://portal.extensionista.site`
- **Stack**: Next.js 14, TailwindCSS.
- **Funcionalidades**:
  - Lista de Módulos (integrada ao DB)
  - Visualização de Certificados

---

## Fases Pendentes (Futuro)

---

### FASE 4 — RAGFlow + Material Didático
**O que faz**: Indexa PDFs e slides do material didático para que o bot possa
responder perguntas específicas com base no conteúdo real do curso.

**Prioridade**: ALTA — sem isso, o AI Tutor responde com conhecimento genérico.

**Passos**:
1. Adicionar RAGFlow ao `docker-compose.yml` (Já temos RAM suficiente agora).
2. Configurar DNS: `rag.extensionista.site`.
3. Integrar `ai-tutor.flow.ts` para chamar a API de busca semântica.

---

### FASE 5 — Flows Completos de Módulos com IA (Conteúdo)
**O que faz**: Criar conteúdo específico para cada módulo.
Atualmente temos a estrutura, falta popular o banco de dados com o conteúdo real do curso.

**Passos**:
1. Popular tabela `modules` no PostgreSQL com conteúdo real.
2. Criar flows específicos se necessário (atualmente usamos flow genérico dinâmico).

---

### FASE 6 — Wellms ou LMS Customizado (Opcional)
**Status**: Baixa prioridade. O sistema atual (N8N + SQL) está atendendo bem.

---

## Resumo de Prioridades

| Prioridade | Fase | Status |
|---|---|---|
| 🟢 CONCLUÍDO | 1, 2, 3, 7, 8, 9, 10, 11, 12 | ✅ Deploy realizado |
| 🟠 ALTA | 4 (RAGFlow) | Pendente |
| 🟡 MÉDIA | 5 (Conteúdo) | Pendente |
