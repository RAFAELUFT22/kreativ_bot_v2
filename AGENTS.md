# AGENTS.md — Guia para Agentes de IA Continuarem o Desenvolvimento

> Este arquivo serve para que novos agentes entendam o estado atual e o roadmap.
> **Última atualização**: 21/02/2026 — Claude (Session End)

---

## 1. Status da Entrega (Resumo Executivo)

- **Redis Security**: ✅ Corrigido NOAUTH. Evolution API e Chatwoot agora usam a credencial unívoca `kreativ_redis` com senha definida no `.env`.
- **Schema Sync**: ✅ Aplicada migração `course_int_id` (INTEGER) como chave de join canônica. Seeds populados para cursos 4, 5 e 19.
- **AI Router V3**: ✅ Funcional com RAG Dual-Mode (Ementa + Chunks). Histórico Redis via TCP RESP (net.Socket) estabilizado.
- **Handoff Resilience**: ✅ Fluxo de transbordo humano com idempotência via `handoff_control` para evitar loops de estado.
- **Analytics**: ✅ 12 queries KPI prontas em `scripts/04-analytics-kpis.sql` para Metabase.
- **RAG Ingestion**: ✅ Pipeline de ingestão (`22-rag-ingestion.json`) ativo e salvando chunks no Postgres.

---

## 2. Arquitetura Atual

```
WhatsApp ─► Evolution API (TYPEBOT_ENABLED=true)
                    │
                    ▼
              Typebot v6 (bot visual)
                    │  blocos "Webhook" (capital W) = server-side HTTP
                    ▼
           N8N: kreativ-unified-api
           POST /webhook/kreativ-unified-api
                    │
         ┌──────────┼──────────┐
         ▼          ▼          ▼
    PostgreSQL    Redis    DeepSeek API
    (kreativ_edu)         (avaliação IA)
         │
         ▼
   Portal LMS (Next.js) + Chatwoot (suporte humano)
```

> ATENÇÃO: BuilderBot está presente no docker-compose mas NÃO está no fluxo ativo.
> A Evolution API roteia DIRETAMENTE para o Typebot (não passa mais pelo N8N Router).

### Serviços Ativos

| Serviço | Host Docker | Status |
|---|---|---|
| PostgreSQL | `kreativ_postgres` | Ativo (Porta 5432) — SEMPRE usar este hostname |
| Redis | `kreativ_redis` | Ativo |
| Evolution API | `kreativ_evolution` | Ativo (Porta 8081) — roteia para Typebot |
| Typebot Builder | `kreativ_typebot_builder` | Ativo — editor visual |
| Typebot Viewer | `kreativ_typebot_viewer` | Ativo — runtime do bot |
| N8N | `kreativ_n8n` | Ativo (Porta 5678) — endpoint unificado |
| Chatwoot | `kreativ_chatwoot` | Ativo — suporte humano |

---

## 3. Banco de Dados — Decisões Críticas

### Tabela `modules`
- **Sempre use `course_int_id`** para joins com `students` ou `document_chunks`.
- O campo `course_id` (VARCHAR) é legado e deve ser evitado em novas queries.

### Tabela `document_chunks`
- Usada para RAG real.
- Chunks são filtrados por `metadata->>'course_int_id'` e `metadata->>'module_number'`.

---

## 4. Estratégia RAG (40% Concluída)

- **Infra**: `pgvector` ativo e tabela criada.
- **Ingestão**: Workflow `22-rag-ingestion.json` processa textos e salva chunks.
- **Recuperação**: AI Router V3 injeta chunks no prompt automaticamente quando disponíveis (`rag_available: true`).
- **Pendente**: Ativar nó de Embeddings (OpenAI/DeepSeek) para busca semântica (atualmente usa busca por metadados exatos).

---

## 5. Gargalos Remanescentes (Ações para o Próximo Agente)

1.  **Popular Conteúdo**: Cursos 1, 15 e 17 têm muitos inscritos mas estão sem módulos.
2.  **ToolJet GUI**: Criar visualmente os 4 CRUDs no painel Admin (Módulos, Cursos, Alunos e Seções de Conteúdo).
3.  **Embeddings Reais**: Ativar a geração de vetores no workflow de ingestão.
4.  **Metabase**: Configurar os dashboards usando os scripts SQL fornecidos em `scripts/04-analytics-kpis.sql`.

---

## 6. Comandos Úteis

### Reset de Cache de Estado (Redis)
```bash
docker exec kreativ_redis redis-cli -a "$REDIS_PASSWORD" DEL "session:TELEFONE:status"
```

### Logs de Erro IA
```bash
# Ver as 50 últimas execuções via API
curl -H "X-N8N-API-KEY: $N8N_API_KEY" "https://n8n.extensionista.site/api/v1/executions?limit=50"
```
