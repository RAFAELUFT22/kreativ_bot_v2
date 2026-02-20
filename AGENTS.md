# AGENTS.md — Guia para Agentes de IA Continuarem o Desenvolvimento

> Este arquivo existe para que um novo agente (Claude Code, Antigravity, Cursor, etc.)
> entenda o estado atual do sistema e saiba exatamente como continuar o desenvolvimento.
> **Última atualização**: 20/02/2026 — Claude Sonnet 4.6

---

## 1. O Que É Este Projeto

**Kreativ Educação** — sistema de educação conversacional via WhatsApp.

Alunos recebem módulos de conteúdo e avaliações generativas diretamente no WhatsApp.
Um bot (BuilderBot) e orquestradores IA (N8N + DeepSeek) conduzem a trilha. Quando o aluno pede ajuda,
é transferido para um tutor humano (Chatwoot).

**VPS**: Hostinger, IP `187.77.46.37`, 7.8GB RAM, 2 vCPU
**Domínio principal**: `extensionista.site`
**Painel de deploy**: Coolify em `http://187.77.46.37:8000`

---

## 2. Arquitetura Atual (Estado em 20/02/2026)

```
WhatsApp ─► Evolution API ─► N8N Router (Redis Cache/Rate Limit)
                                    │
                    ┌───────────────┴────────────────┐
                    ▼                                ▼
              BuilderBot                       AI Router V3
              (relay FSM)               (Redis Sliding Window)
                    │                        │    │    │
                    │                  Redis PG  RAG  Few-shot
                    └───────────────────────►│
                                             │
                                      DeepSeek API
                                             │
                                      Evolution API
                                      (resposta WA)
```

### FSM de Estado (Máquina de Estados Finita)

```
Estado:  bot ──(TUTOR/HUMANO)──► human ──(resolved)──► bot
                                    │
                             Chatwoot ticket
                             handoff_control (semáforo)
```

### Serviços em produção (Docker Compose — 14 containers)

| Serviço | Container | Porta | Papel |
|---|---|---|---|
| PostgreSQL | `kreativ_postgres` | 5432 | Fonte da Verdade (Long-Term Memory) |
| Redis | `kreativ_redis` | 6379 | Sessão, Cache de Estado e Rate Limit |
| Evolution API | `kreativ_evolution` | 8080 | Gateway WhatsApp (Meta Cloud API) |
| N8N | `kreativ_n8n` | 5678 | Orquestrador de Agentes e Webhooks |
| BuilderBot | `kreativ_builderbot` | 3008 | Relay de Mensagens e entry.flow |
| MinIO | `kreativ_minio` | 9000/9001 | Storage S3 (certificados) |
| ToolJet | `kreativ_tooljet` | 3000 | Painel Admin (CRUD cursos/módulos) |
| Metabase | `kreativ_metabase` | 3000 | Analytics e KPIs |
| Chatwoot | `kreativ_chatwoot_app` | 3000 | Atendimento Humano |
| Portal | `kreativ_portal` | 3000 | Portal do Aluno (Next.js) |
| Web | `kreativ_web` | 80 | Landing Page |
| Postfix | `kreativ_postfix` | 25 | SMTP |

---

## 3. Banco de Dados — Schema Atual (20/02/2026)

### Tabelas Core

| Tabela | Descrição |
|---|---|
| `courses` | 21 cursos (IDs 1-21 fixos) |
| `students` | Alunos ativos — `course_id INTEGER FK → courses.id` |
| `modules` | Módulos dos cursos — ver detalhe abaixo |
| `pre_inscriptions` | 508 pré-inscritos importados |
| `training_memory` | Pares Q&A dos atendimentos humanos (few-shot) |
| `handoff_control` | Semáforo de estado bot/human — PK: phone |
| `document_chunks` | Vetores pgvector (1536-dim) para RAG — VAZIO |
| `module_content_sections` | Seções granulares de conteúdo (para GUI) — NOVA |
| `support_sessions` | Histórico de atendimentos humanos |
| `certificates` | Certificados emitidos |
| `events_log` | Log de todos os eventos do sistema |

### Tabela `modules` — campos importantes

```sql
id               UUID PK
course_id        VARCHAR(100)  -- LEGADO: não usar para join
course_int_id    INTEGER FK → courses.id  -- USAR ESTE para joins
module_number    INTEGER
title            VARCHAR(255)
content_text     TEXT          -- ementa/diretriz para IA
evaluation_rubric TEXT         -- rubrica para avaliação generativa
is_published     BOOLEAN       -- visível para alunos
quiz_questions   JSONB         -- legado, não usado
syllabus_json    JSONB         -- estrutura rica opcional
```

> ⚠️ **CRÍTICO**: Sempre use `course_int_id` para joins. `course_id` é VARCHAR legado.
> O AI Router V3 já usa `course_int_id` após a migration de 20/02/2026.

### Cursos TDS populados (Programa TDS Tocantins)

| course_int_id | Nome | Módulos |
|---|---|---|
| 4 | Agronegócio e Produção Rural | 3 (DAP/CAF, PAA/PNAE, Pronaf B) |
| 5 | Gestão Financeira para Empreendimentos | 3 (Precificação, MEI, Microcrédito) |
| 19 | Inteligência Artificial e Inclusão Digital | 5 (completo) |

---

## 4. Workflows N8N Ativos (Principais)

| ID N8N | Nome | Webhook Path | Função |
|---|---|---|---|
| `WbDAVxu7OwCTttRF` | WhatsApp Router | `/webhook/whatsapp` | Roteador com Redis (Cache + Limit) |
| `5caL67H387euTxan` | AI Router V3 | `/webhook/ai-tutor-v3` | Tutor + RAG + Sliding Window Redis |
| `oDg2TF7C0ne12fFg` | get-student-module | `/webhook/get-student-module` | Retorna conteúdo + rubrica |
| `tULwBOlfOnCuk586` | Save Progress | `/webhook/save-progress` | Salva nota e libera próximo módulo |
| `y92mEtPP4nK1p037` | Chatwoot Events | `/webhook/chatwoot-events` | Sync bot/human com idempotência |
| `cj1N7ZPVoDxlI7Sk` | Lead Scoring | `/webhook/lead-scoring` | Pontuação de engajamento |

### AI Router V3 — Fluxo de Dados (20/02/2026)

```
Webhook → Transformer → Redis: GetHistory
                                  │
                                  ▼
                          Get Student Info (PG)
                                  │
                          Get Student Fallback
                         /        │         \
                        ▼         ▼          ▼
               Get Module      Few-shot    RAG: Buscar
               Info (PG)       (PG)        Chunks (PG)
               course_int_id ← ← ← ← ← ←  document_chunks
                        \         │          /
                         └────────▼─────────┘
                          Agregador de Contexto
                                  │
                           DeepSeek AI
                                  │
                          Check AI Response
                         /                  \
                Redis: Push User    Redis: Push AI
                                            │
                                    Redis: Trim (20 msgs)
                                            │
                                    Send WhatsApp
```

### Chatwoot Events — Fluxo com Idempotência (20/02/2026)

```
Webhook → Extrair Evento → Switch Tipo
              │
              ├─► [resolved] → Verificar Estado Atual (PG)
              │                       │
              │              Idempotência: Já é Bot?
              │                       │ (se já 'bot' → PARA)
              │                       ▼
              │              Retomar Bot no DB (atomic BEGIN/COMMIT)
              │                       │
              │              Redis: Set Bot (com current_module real)
              │
              ├─► [open] → Handoff no DB + Redis: Set Human
              │
              └─► [message_created/outgoing] → Buscar Histórico
                                                       │
                                              Extrair Par Q&A
                                                       │
                                              Salvar training_memory
```

---

## 5. Redis — Chaves em Uso

| Chave | Tipo | Conteúdo | TTL |
|---|---|---|---|
| `session:{phone}:status` | STRING | `{"attendance_status":"bot","current_module":N}` | 24h |
| `chat_history:{phone}` | LIST | JSON msgs `{role,content}` (máx 20) | sem TTL |
| `rate_limit:{phone}` | STRING | contador INT | 3s |

> ⚠️ Redis usa senha — sempre via `redis://:${REDIS_PASSWORD}@kreativ_redis:6379/{db}`
> Usar `kreativ_redis` (container_name), NUNCA `redis` (ambíguo na rede coolify).

---

## 6. Estratégia RAG (Estado Atual e Próximos Passos)

### Estado Atual
- `document_chunks` tabela existe com índice `ivfflat (embedding vector_cosine_ops)`
- **0 chunks populados** — pipeline de embedding não implementado ainda
- AI Router V3 já tem nó `RAG: Buscar Chunks` preparado
- Quando chunks existirem, são injetados automaticamente no contexto da IA

### Para Popular RAG (Próximo Agente)
```sql
-- 1. Inserir chunks manualmente ou via script
INSERT INTO document_chunks (module_id, source_file, chunk_index, content, embedding)
VALUES ($module_uuid, 'apostila.pdf', 0, 'Conteúdo...', '[0.1, 0.2, ...]'::vector);

-- 2. Para gerar embeddings, usar DeepSeek Embeddings API ou OpenAI
-- POST https://api.deepseek.com/embeddings
-- { "input": "texto", "model": "text-embedding-3-small" }
```

### Opção RAGFlow (Fase 4 do ROADMAP)
- Adicionar `ragflow` ao docker-compose.yml
- Requer ~2GB RAM adicionais (VPS tem 7.8GB, factível)
- DNS: `rag.extensionista.site`
- Integrar via API HTTP no AI Router V3

---

## 7. GUI Admin — ToolJet Apps a Implementar

ToolJet está rodando em `https://admin.extensionista.site`.

### Apps a Criar no ToolJet (manual no UI)

#### App 1: Gestão de Módulos
- **Data Source**: PostgreSQL kreativ_edu
- **Query**: `SELECT m.*, c.name as course_name FROM modules m JOIN courses c ON c.id=m.course_int_id ORDER BY c.name, m.module_number`
- **Actions**: UPDATE modules SET title, content_text, evaluation_rubric, is_published
- **Componentes**: Table + Form + Text Editor para content_text

#### App 2: Cadastro de Cursos
- **Query**: `SELECT * FROM courses ORDER BY id`
- **Actions**: INSERT + UPDATE courses
- **Componentes**: Table + Form

#### App 3: Acompanhamento de Alunos
- **Query**:
```sql
SELECT s.phone, s.name, s.email, c.name as curso,
       s.current_module, s.lead_score, s.attendance_status,
       array_length(s.completed_modules,1) as mods_concluidos,
       s.updated_at
FROM students s LEFT JOIN courses c ON c.id=s.course_id
ORDER BY s.updated_at DESC
```
- **Actions**: Reset de módulo, mudar attendance_status
- **Filtros**: por curso, por status, por lead_score

#### App 4: Conteúdo por Seções (module_content_sections)
- CRUD granular para editar intro, concept, example, activity, summary de cada módulo

---

## 8. Analytics — Metabase Dashboards

Queries em `scripts/04-analytics-kpis.sql` (12 blocos):

1. **Funil de Conversão** — Pre-inscritos → Alunos → Certificados
2. **Taxa de Conclusão por Módulo** — por curso
3. **Lead Score** — Hot/Warm/Cold distribution
4. **Escalação de Suporte** — tempo médio, taxa de resolução
5. **Top Razões de Suporte** — para identificar lacunas de conteúdo
6. **DAU** — Daily Active Users (30 dias)
7. **Engajamento Geográfico** — por cidade/estado (Tocantins focus)
8. **Retenção Semanal** — cohort analysis
9. **Cursos Mais Populares** — por inscrições e certificados
10. **Saúde do Sistema** — KPIs técnicos em tempo real
11. **Progressão por Módulo** — heatmap
12. **Memória de Treinamento** — qualidade do few-shot

---

## 9. Decisões Arquiteturais (20/02/2026)

### Decisão 1: course_int_id como campo de join canônico
**Problema**: `modules.course_id` era VARCHAR, `students.course_id` era INTEGER.
**Solução**: Adicionado `course_int_id INTEGER FK → courses.id` em modules.
**Migration**: `scripts/03-migration-tds-modules.sql`
**Impacto**: AI Router V3 atualizado para usar `course_int_id`.

### Decisão 2: Idempotência via handoff_control
**Problema**: Chatwoot pode disparar eventos `conversation_status_changed` duplicados.
**Solução**: Antes de atualizar estado para 'bot', verificar `handoff_control.status`.
Se já é 'bot', o nó Code Node retorna `[]` encerrando a execução sem efeitos colaterais.
**Workflow**: `10-chatwoot-events.json` — nó "Idempotência: Já é Bot?"

### Decisão 3: RAG em dois modos
**Modo atual** (content_text): AI Router injeta ementa textual no prompt.
**Modo futuro** (pgvector): Quando document_chunks populados, busca por similaridade.
O nó `RAG: Buscar Chunks` já existe — quando chunks > 0, `rag_available=true` e
o contexto usa MATERIAL DO MÓDULO em vez de EMENTA.

### Decisão 4: Redis hostname canônico
**Regra**: Sempre `kreativ_redis` (container_name), NUNCA `redis` (service name).
**Motivo**: Evolution API está em `kreativ_net` E `coolify`. O hostname `redis` pode
resolver para `coolify-redis` (container sem senha). `kreativ_redis` é unívoco.

---

## 10. Guia de Manutenção (Para o Próximo Agente)

### Deploy de Workflows N8N
```bash
# 1. Editar JSON local
# 2. Importar via N8N UI: Settings → Import Workflow
# 3. Ou via API:
N8N_URL=https://n8n.extensionista.site
curl -X POST $N8N_URL/api/v1/workflows/import \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  -H "Content-Type: application/json" \
  -d @n8n-workflows/20-ai-router-v3.json
```

### Aplicar Migrations SQL
```bash
docker exec -i kreativ_postgres psql -U kreativ_user -d kreativ_edu \
  < scripts/03-migration-tds-modules.sql
```

### Reset de Aluno (debug)
```sql
UPDATE students SET current_module=1, completed_modules='{}', lead_score=0, attendance_status='bot'
WHERE phone='NUMERO';
DELETE FROM handoff_control WHERE phone='NUMERO';
-- Redis:
docker exec kreativ_redis redis-cli -a "$REDIS_PASSWORD" DEL "session:NUMERO:status" "chat_history:NUMERO"
```

### Logs
```bash
docker logs kreativ_n8n --tail 50 -f
docker logs kreativ_builderbot --tail 50 -f
docker logs kreativ_evolution --tail 50 -f
```

### Adicionar Conteúdo ao Módulo (via SQL)
```sql
UPDATE modules
SET content_text = 'Ementa detalhada aqui...',
    evaluation_rubric = 'Critério de avaliação aqui...',
    is_published = TRUE
WHERE course_int_id = 4 AND module_number = 1;
```

---

## 11. Status do Roadmap (20/02/2026)

| Fase | Status | Notas |
|---|---|---|
| 1 — Infra Base | ✅ | Evolution, N8N, PostgreSQL, Redis, MinIO |
| 2 — BuilderBot | ✅ | Phase 19: entry.flow + N8N delegation |
| 3 — Flows de Boas-Vindas | ✅ | Onboarding completo |
| 4 — RAGFlow | 🟠 ALTA | pgvector instalado, document_chunks vazio |
| 5 — Conteúdo TDS | 🟡 MÉDIA | Ementas seeds prontas (cursos 4, 5, 19) |
| 7 — ToolJet Admin | ✅ | Online — Apps CRUD a criar no UI |
| 8 — Chatwoot | ✅ | Integrado com idempotência (20/02) |
| 9 — Lead Scoring | ✅ | Workflows ativos |
| 10 — Certificados | ✅ | HTML + MinIO |
| 11 — Metabase | ✅ | Online — 12 KPIs em scripts/04-analytics-kpis.sql |
| 12 — Portal Next.js | ✅ | portal.extensionista.site |

### Próximos Passos (prioridade)
1. **Importar workflows N8N** atualizados (20-ai-router-v3.json, 10-chatwoot-events.json)
2. **Popular document_chunks** com embeddings para ativar RAG real
3. **Criar Apps ToolJet** (CRUD Módulos, Cursos, Alunos) — ver Seção 7
4. **Adicionar mais conteúdo TDS** — cursos 1, 17, 19 (mais alunos)
5. **Configurar Metabase dashboards** usando scripts/04-analytics-kpis.sql
