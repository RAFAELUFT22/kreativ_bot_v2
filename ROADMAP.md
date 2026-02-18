# ROADMAP — Kreativ Educação: Próximos Passos de Implementação

> Baseado em: `arquitetura_builderbot_definitiva.docx`
> Estado em: 18/02/2026
> Referência para agentes de IA continuarem o desenvolvimento

---

## Fases Concluídas ✅

### Fase 1 — Infra Base ✅
- Coolify configurado na VPS Hostinger (3.8GB RAM, 1 vCPU)
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
- Avanço de módulo ao atingir nota mínima (70%)

---

## Fases Pendentes

---

### FASE 4 — RAGFlow + Material Didático
**O que faz**: Indexa PDFs e slides do material didático para que o bot possa
responder perguntas específicas com base no conteúdo real do curso.

**Prioridade**: ALTA — sem isso, o AI Tutor responde com conhecimento genérico

**Pré-requisito de hardware**: O RAGFlow requer ≥8GB RAM. VPS atual tem 3.8GB.
**→ Upgrade da VPS para 8GB RAM antes de iniciar esta fase.**

**Passos**:
1. Upgrade VPS para ≥8GB RAM (Hostinger painel)
2. Adicionar RAGFlow ao `docker-compose.yml`:
   ```yaml
   ragflow:
     image: infiniflow/ragflow:latest
     container_name: kreativ_ragflow
     ports: ["9380:9380"]
     volumes:
       - ragflow_data:/ragflow/data
     environment:
       - MYSQL_PASSWORD=${RAGFLOW_DB_PASSWORD}
     networks:
       - kreativ_network
       - coolify
     labels:
       - "traefik.http.routers.ragflow.rule=Host(`rag.extensionista.site`)"
   ```
3. Configurar DNS: `rag.extensionista.site` → `187.77.46.37`
4. Upload dos PDFs do material didático via UI do RAGFlow
5. Criar knowledge base no RAGFlow
6. Integrar `ai-tutor.flow.ts` para chamar a API de busca semântica do RAGFlow:
   ```typescript
   // Em ai-tutor.flow.ts
   const ragResponse = await fetch('http://ragflow:9380/api/v1/retrieval', {
     method: 'POST',
     body: JSON.stringify({ query: userQuestion, kb_id: 'KREATIV_KB_ID' })
   })
   ```

**Arquivos a modificar**:
- `docker-compose.yml` — adicionar serviço ragflow
- `apps/builderbot/src/flows/ai-tutor.flow.ts` — integrar busca semântica
- `.env` — adicionar `RAGFLOW_API_KEY`, `RAGFLOW_KB_ID`

---

### FASE 5 — Flows Completos de Módulos com IA
**O que faz**: AI gera flows BuilderBot completos para cada módulo do curso
(conteúdo + quiz + scoring). Atualmente temos flows genéricos — cada módulo
deveria ter seu próprio flow especializado.

**Passos**:
1. Para cada módulo do curso:
   - Dar o conteúdo ao agente de IA
   - IA gera arquivo TypeScript: `apps/builderbot/src/flows/module-N.flow.ts`
   - Dev revisa e faz commit
2. Registrar os novos flows em `app.ts`:
   ```typescript
   import { module1Flow } from './flows/module-1.flow'
   import { module2Flow } from './flows/module-2.flow'
   // ...
   const adapterFlow = createFlow([welcomeFlow, module1Flow, module2Flow, ...])
   ```
3. Popular tabela `modules` no PostgreSQL com conteúdo real
4. Testar via WhatsApp com aluno de teste

**Arquivos a criar**:
- `apps/builderbot/src/flows/module-1.flow.ts`
- `apps/builderbot/src/flows/module-2.flow.ts`
- etc.

---

### FASE 6 — Wellms ou LMS Customizado
**O que faz**: API headless para cursos, módulos, progresso, notas, certificados.
BuilderBot e N8N consomem via REST em vez de queries SQL diretas.

**Opções**:
- **Wellms** (MIT): LMS headless completo, Docker-ready
- **Custom REST API** (mais simples): FastAPI ou Express sobre o PostgreSQL atual

**Recomendação**: Para a escala atual, manter as queries SQL diretas via N8N
e criar apenas uma API REST simples se necessário.

**Passos para Custom API**:
1. Criar `apps/lms-api/` com Express.js ou FastAPI
2. Endpoints:
   - `GET /students/:phone` — estado do aluno
   - `POST /students/:phone/progress` — atualizar progresso
   - `GET /modules/:id` — conteúdo do módulo
   - `POST /certificates` — emitir certificado
3. N8N chama esta API em vez de queries SQL diretas

---

### FASE 7 — ToolJet (Painel Administrativo)
**O que faz**: Interface para gestores e tutores sem conhecimento técnico:
- Editar textos de boas-vindas
- Configurar nota mínima por módulo
- Ver lista de alunos e progresso
- Painel de tutores

**Pré-requisito**: ≥8GB RAM

**Passos**:
1. Descomentar ToolJet no `docker-compose.yml`
2. Configurar DNS: `admin.extensionista.site` → `187.77.46.37`
3. Criar tabelas de configuração no PostgreSQL:
   ```sql
   CREATE TABLE course_config (
     key VARCHAR(100) PRIMARY KEY,
     value JSONB,
     updated_at TIMESTAMP DEFAULT NOW()
   );
   ```
4. Criar apps no ToolJet:
   - App: "Gerenciar Módulos" — CRUD na tabela modules
   - App: "Painel de Alunos" — visualização de students + progresso
   - App: "Configurações do Curso" — min_score, welcome_text, etc.
5. Importar JSON das apps (a ser gerado pelo agente de IA)

---

### FASE 8 — Chatwoot (Tutores) ⚠️ URGENTE
**O que faz**: Inbox multi-agente para tutores responderem alunos que
solicitaram atendimento humano. Bot é pausado enquanto tutor atende.

**Status atual**: Chatwoot está comentado no docker-compose.yml
(sem RAM suficiente). Integração com Evolution API está configurada
(`accountId: 2`, token: `hh5bHLwTRyKoqZzAvaPUUm5v`).

**Problema identificado**: Quando aluno digita TUTOR:
1. BuilderBot chama `POST /webhook/request-human-support` no N8N ✅
2. N8N seta `attendance_status='human'` no DB ✅
3. **MAS**: nenhuma conversa aparece no Chatwoot para tutores responderem ❌

**Causa provável**: Chatwoot não está rodando (container comentado).
Mesmo que estivesse, o fluxo N8N `request-human-support` precisa
notificar o Chatwoot via API para criar a conversa.

**Passos para ativar**:
1. Upgrade VPS para ≥8GB RAM
2. Descomentar Chatwoot no `docker-compose.yml`
3. Configurar DNS: `suporte.extensionista.site` → `187.77.46.37`
4. Criar workflow N8N `request-human-support`:
   ```
   Webhook /request-human-support
   → Atualizar students SET attendance_status='human' (PostgreSQL)
   → Criar conversa no Chatwoot via API:
     POST https://suporte.extensionista.site/api/v1/accounts/2/conversations
     Header: api_access_token: hh5bHLwTRyKoqZzAvaPUUm5v
     Body: { inbox_id: 1, contact_phone: "+55...", ... }
   → Responder BuilderBot: { success: true, tutorName: "...", estimatedWait: "5 min" }
   ```
5. Configurar webhook Chatwoot → N8N quando tutor encerra atendimento:
   - Evento `conversation_status_changed` → chamar `POST /webhook/resume-bot`
   - N8N: seta `attendance_status='bot'`, chama `POST /api/resume` no BuilderBot

**Solução alternativa sem Chatwoot** (funciona com RAM atual):
- Usar Evolution API para criar grupo WhatsApp de tutores
- N8N envia mensagem no grupo alertando novo pedido de suporte
- Tutor responde diretamente pelo próprio WhatsApp Business

---

### FASE 9 — Scoring + Qualificação de Leads
**O que faz**: Lógica de pontuação de leads no N8N: tags, score,
relatório para vendas.

**Passos**:
1. Criar workflow N8N "Lead Scoring":
   - Trigger: módulo completado ou quiz respondido
   - Calcular score baseado em: módulos concluídos, notas, tempo de resposta
   - Atualizar `students.lead_score` e `students.lead_tags`
2. Criar workflow N8N "Relatório Semanal":
   - Trigger: toda segunda-feira 8h
   - Query SQL: top leads, progresso geral, alunos inativos
   - Enviar relatório via WhatsApp para gestores
3. Criar views no PostgreSQL para Metabase (Fase 11)

---

### FASE 10 — Certificados Automáticos
**O que faz**: Quando aluno conclui todos os módulos com aprovação,
N8N gera PDF via Puppeteer e envia link por WhatsApp.

**Pré-requisito**: Instalar community node no N8N:
```bash
docker exec -it kreativ_n8n sh -c "cd /home/node && npm install n8n-nodes-puppeteer"
# Reiniciar N8N após instalar
```

**Passos**:
1. Criar template HTML/CSS do certificado em `apps/certificate-template/`
2. Subir template no MinIO como arquivo estático
3. Criar workflow N8N "Emitir Certificado":
   - Trigger: `students.current_module > total_modules`
   - Puppeteer: gera PDF a partir do template HTML
   - MinIO: salva PDF como `certificates/{phone}-{date}.pdf`
   - Atualizar `students.certificate_id`
   - BuilderBot: enviar link do PDF via WhatsApp

---

### FASE 11 — Metabase (Analytics)
**O que faz**: Dashboard SQL para gestores visualizarem KPIs.

**Pré-requisito**: ≥8GB RAM

**Passos**:
1. Descomentar Metabase no `docker-compose.yml`
2. Configurar DNS: `dash.extensionista.site` → `187.77.46.37`
3. Conectar ao PostgreSQL `kreativ_edu`
4. Criar dashboards:
   - Alunos por módulo (bar chart)
   - Taxa de conclusão por módulo
   - Leads qualificados (lead_score > 70)
   - Tempo médio de resposta
   - Tutores mais ativos

---

### FASE 12 — Portal Next.js (Conteúdo Rico)
**O que faz**: Portal web com vídeos, slides e material complementar.
Bot envia link via WhatsApp quando aluno pede mais detalhes.

**Passos**:
1. Criar `apps/portal/` com Next.js 14
2. Páginas:
   - `/modulo/[id]` — conteúdo do módulo com vídeo + texto
   - `/certificado/[id]` — visualizar certificado
3. Deploy via Coolify (porta 3000, domínio `portal.extensionista.site`)
4. BuilderBot envia link quando aluno pede "ver mais":
   ```typescript
   await flowDynamic([{
     body: `📱 Veja o material completo aqui:\nhttps://portal.extensionista.site/modulo/${moduleNumber}`
   }])
   ```

---

## Resumo de Prioridades

| Prioridade | Fase | Bloqueio |
|---|---|---|
| 🔴 URGENTE | 8 (Chatwoot tutores) | Upgrade RAM ou solução alternativa |
| 🟠 ALTA | 4 (RAGFlow) | Upgrade RAM |
| 🟡 MÉDIA | 5 (Flows completos por módulo) | Conteúdo dos módulos |
| 🟡 MÉDIA | 9 (Lead scoring) | Nenhum |
| 🟡 MÉDIA | 10 (Certificados) | Instalar community node N8N |
| 🟢 BAIXA | 6 (LMS API) | Opcional se SQL direto funcionar |
| 🟢 BAIXA | 7 (ToolJet admin) | Upgrade RAM |
| 🟢 BAIXA | 11 (Metabase) | Upgrade RAM |
| 🟢 BAIXA | 12 (Portal Next.js) | Conteúdo disponível |

---

## Solução Imediata para Alerta de Tutores (sem upgrade de RAM)

Enquanto Chatwoot não é ativado, use este workflow N8N temporário:

**Criar workflow N8N `request-human-support`**:
```
POST /webhook/request-human-support
→ PostgreSQL: UPDATE students SET attendance_status='human' WHERE phone=...
→ Evolution API: enviar mensagem no grupo de tutores:
  POST http://kreativ_evolution_api:8080/message/sendText/europs
  Body: { number: "GRUPO_TUTORES_ID@g.us", text: "🚨 Aluno {phone} solicitou atendimento!\nMotivo: {reason}" }
→ Responder: { success: true, tutorName: "Equipe Kreativ", estimatedWait: "15 min" }
```

**Grupo de tutores**: Criar grupo WhatsApp com todos os tutores.
O N8N envia alerta lá quando aluno solicita suporte.
Tutor responde diretamente e ao final chama `POST /webhook/resume-bot`
(ou usa endpoint direto: `POST http://builderbot:3008/api/resume`).
