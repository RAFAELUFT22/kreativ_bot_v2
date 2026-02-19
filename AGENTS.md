# AGENTS.md — Guia para Agentes de IA Continuarem o Desenvolvimento

> Este arquivo existe para que um novo agente (Claude Code, Antigravity, Cursor, etc.)
> entenda o estado atual do sistema e saiba exatamente como continuar o desenvolvimento.

---

## 1. O Que É Este Projeto

**Kreativ Educação** — sistema de educação conversacional via WhatsApp.

Alunos recebem módulos de conteúdo e quizzes diretamente no WhatsApp.
Um bot (BuilderBot) conduz a trilha de aprendizagem. Quando o aluno pede ajuda,
é transferido para um tutor humano (Chatwoot). Tudo orquestrado via N8N.

**VPS**: Hostinger, IP `187.77.46.37`, 7.8GB RAM, 1 vCPU (upgrade realizado)
**Domínio principal**: `extensionista.site`
**Painel de deploy**: Coolify em `http://187.77.46.37:8000`

---

## 2. Arquitetura Atual (Estado em 19/02/2026)

```
WhatsApp ─► Evolution API ─► N8N Router ─► BuilderBot ─► responde aluno
                                  │
                                  ├─► DeepSeek (mensagens livres/fallback)
                                  └─► Chatwoot (quando attendance_status='human')
```

### Serviços em produção (Docker Compose)

| Serviço | Container | Porta interna | URL externa |
|---|---|---|---|
| PostgreSQL + pgvector | `kreativ_postgres` | 5432 | interno |
| Redis | `kreativ_redis` | 6379 | interno |
| Evolution API v2 | `kreativ_evolution` | 8080 | https://evolution.extensionista.site |
| N8N | `kreativ_n8n` | 5678 | https://n8n.extensionista.site |
| BuilderBot | `kreativ_builderbot` | 3008 | interno (chamado pelo N8N) |
| MinIO | `kreativ_minio` | 9000/9001 | https://files.extensionista.site |
| Chatwoot | `kreativ_chatwoot_app` | 3000 | https://suporte.extensionista.site |
| ToolJet EE | `kreativ_tooljet` | 3000 | https://admin.extensionista.site |
| Metabase | `kreativ_metabase` | 3000 | https://dash.extensionista.site |
| Portal do Aluno (Next.js) | `kreativ_portal` | 3001 | https://portal.extensionista.site |

> **TODOS os serviços ativos** — VPS tem 7.8GB RAM após upgrade

---

## 3. Fluxo de Mensagem Detalhado

```
1. Aluno manda msg no WhatsApp
2. Evolution API recebe (instância: europs)
3. Evolution API dispara webhook → N8N Router (workflow ID: oeM02qpKdIGFbGQX)
4. N8N Router:
   a. Consulta students.attendance_status e current_module no PostgreSQL
   b. Se attendance_status='human' → ignora (Chatwoot cuida)
   c. Se keyword em BUILDERBOT_KEYWORDS ou current_module>0 → BuilderBot
   d. Caso contrário → DeepSeek (resposta IA livre)
5. BuilderBot recebe em POST /webhook (NÃO em POST /)
6. BuilderBot processa flow, chama N8N webhooks para dados:
   - POST /webhook/get-student-module → busca módulo atual + conteúdo + quiz
   - POST /webhook/submit-quiz-answer → valida resposta e atualiza progresso
   - POST /webhook/request-human-support → aciona tutor
```

### ATENÇÃO — Armadilhas conhecidas

1. **Telefone**: Evolution API envia 12 dígitos BR (ex: `556399374165`).
   O DB pode ter 13 dígitos (`5563999374165` — "extra 9" antigo).
   SQL no N8N Router lida com os dois formatos (ver workflow).

2. **BuilderBot endpoint**: O bot tem DOIS POST handlers:
   - `POST /` → `indexHome` → retorna "ok", NÃO processa mensagem
   - `POST /webhook` → `incomingMsg` → processa de verdade
   N8N DEVE enviar para `/webhook`.

3. **N8N dual-table**: N8N v2.8.3 usa `workflow_history.nodes` para execução
   (não `workflow_entity.nodes`). Para editar via API: PUT para o workflow
   e depois reativar (deactivate → PUT → activate).

4. **Traefik no Coolify**: entrypoints são `http` e `https` (NÃO `web`/`websecure`).
   Certresolver: `letsencrypt`. Rede: `coolify` (external).

---

## 4. Como Autenticar no GitHub (Token)

```bash
# 1. Exporte seu Personal Access Token
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"

# 2. Configure remote com token
git remote add origin https://${GITHUB_TOKEN}@github.com/SEU_USER/SEU_REPO.git
# OU se já existe:
git remote set-url origin https://${GITHUB_TOKEN}@github.com/SEU_USER/SEU_REPO.git

# 3. Push
git push -u origin master
```

Para configurar autenticação permanente na sessão:
```bash
git config credential.helper store
echo "https://${GITHUB_TOKEN}:x-oauth-basic@github.com" > ~/.git-credentials
```

---

## 5. Variáveis de Ambiente Críticas

Arquivo: `/root/ideias_app/.env` (não commitado — ver `.gitignore`)

```
# PostgreSQL
POSTGRES_PASSWORD=...
POSTGRES_USER=kreativ_user
POSTGRES_DB=kreativ_edu

# Evolution API
EVOLUTION_API_KEY=...
EVOLUTION_INSTANCE=europs

# N8N
N8N_ENCRYPTION_KEY=...
N8N_USER_MANAGEMENT_JWT_SECRET=...

# DeepSeek
DEEPSEEK_API_KEY=...
DEEPSEEK_BASE_URL=https://api.deepseek.com

# Chatwoot
CHATWOOT_URL=https://suporte.extensionista.site
CHATWOOT_ACCOUNT_ID=2
CHATWOOT_API_KEY=hh5bHLwTRyKoqZzAvaPUUm5v
CHATWOOT_INBOX_ID=1

# N8N API (para scripts de automação)
N8N_API_KEY=...  # obter em: https://n8n.extensionista.site/settings/api
```

---

## 6. Arquivos de Código Importantes

```
/root/ideias_app/
├── docker-compose.yml          # Stack completa (Fase 2 comentada)
├── .env                        # Variáveis de ambiente (não no git)
├── init-scripts/
│   ├── 01-init-dbs.sql         # Schema completo (students, modules, etc.)
│   └── 02-migration-courses.sql # Tabelas de cursos e módulos padrão
├── apps/
│   └── builderbot/
│       └── src/
│           ├── app.ts          # Entry point: configura provider, flows, endpoints
│           └── flows/
│               ├── welcome.flow.ts       # Boas-vindas e menu principal
│               ├── module.flow.ts        # Conteúdo do módulo + quiz
│               ├── human-support.flow.ts # Transferência para tutor
│               └── ai-tutor.flow.ts      # Fallback com DeepSeek
├── fluxos_n8n/                 # JSONs exportados dos workflows N8N
│   └── *.json
├── ROADMAP.md                  # Próximos passos de implementação
└── GUIA_META_WEBHOOK.md        # Setup Meta WhatsApp Cloud API
```

---

## 7. Workflows N8N Ativos

Acesse: `https://n8n.extensionista.site` (credenciais no `.env`)

| ID | Nome | Webhook Path | Função |
|---|---|---|---|
| `oeM02qpKdIGFbGQX` | WhatsApp Router | — (Evolution webhook) | Roteador principal: BuilderBot vs DeepSeek vs pausado |
| `oDg2TF7C0ne12fFg` | get-student-module | `/webhook/get-student-module` | Busca módulo atual, conteúdo e quizQuestions |
| `sKXwOHDHjEadXQD0` | submit-quiz-answer | `/webhook/submit-quiz-answer` | Valida quiz, dispara lead-scoring e certificado |
| `04ZmheF5PCJr52aI` | request-human-support | `/webhook/request-human-support` | Aciona tutor humano via Chatwoot |
| `9SQfSnUNWOc3SKFT` | Atualizar Label Chatwoot | `/webhook/update-chatwoot-label` | Atualiza label do contato no Chatwoot |
| `krpsi0uW7fMhxj5T` | Cadastrar Aluno | `/webhook/enroll-student` | Cadastra aluno (aceita array para bulk) |
| `QVrgXdevaAwnykPn` | Dashboard Monitoramento | `GET /webhook/dashboard` | Dashboard HTML com auto-refresh 60s |
| `FDkc4gh7kp6hKZ3E` | Lembrete Inatividade | cron 10h diário | Envia lembrete para alunos inativos |
| `HCnfOkbtviheBGBk` | Relatório Semanal | cron 17h sexta | Relatório semanal por email/WhatsApp |
| `zOSTJqpGI87IKmkm` | Chatwoot → Retomar Bot | `/webhook/chatwoot-events` | Retoma bot quando tutor fecha conversa |
| `cj1N7ZPVoDxlI7Sk` | Lead Scoring | `/webhook/module-completed` | Atualiza score e label Chatwoot |
| `yKcjMnH87VsO5n9V` | Emitir Certificado | `/webhook/emit-certificate` | Gera HTML, salva MinIO, envia link WhatsApp |

**Fluxo certificado**: `submit-quiz-answer` → `module-completed` (lead scoring) → `emit-certificate` → URL: `https://portal.extensionista.site/certificado/{certId}?name=...`

> **Arquivos exportados**: `n8n-workflows/01-*.json` até `12-*.json` (12 workflows)

Para editar workflows via API N8N:
```bash
N8N_BASE="https://n8n.extensionista.site/api/v1"
N8N_KEY="$(grep N8N_API_KEY /root/ideias_app/.env | cut -d= -f2)"

# Listar workflows
curl -s -H "X-N8N-API-KEY: $N8N_KEY" "$N8N_BASE/workflows" | jq '.data[] | {id, name, active}'

# Desativar → editar → reativar
curl -s -X POST -H "X-N8N-API-KEY: $N8N_KEY" "$N8N_BASE/workflows/ID/deactivate"
curl -s -X PUT -H "X-N8N-API-KEY: $N8N_KEY" -H "Content-Type: application/json" \
  -d '{"name":"...","nodes":[...],"connections":{...},"settings":{...}}' \
  "$N8N_BASE/workflows/ID"
curl -s -X POST -H "X-N8N-API-KEY: $N8N_KEY" "$N8N_BASE/workflows/ID/activate"
```

---

## 8. Banco de Dados

**Conectar ao PostgreSQL**:
```bash
docker exec -it kreativ_postgres psql -U kreativ_user -d kreativ_edu
```

**Tabelas principais**:
- `students` — alunos, progresso, attendance_status
- `modules` — conteúdo dos módulos (title, content_text, quiz_questions JSONB)
- `courses` — cursos disponíveis
- `pre_inscriptions` — leads pré-inscritos

**Reset de aluno para teste**:
```sql
DELETE FROM history WHERE phone = 'PHONE';
DELETE FROM contact WHERE phone = 'PHONE';
UPDATE students SET
  current_module = 1,
  completed_modules = '{}',
  scores = '{}',
  attendance_status = 'bot',
  updated_at = NOW()
WHERE phone = 'PHONE';
```

---

## 9. ToolJet e Metabase (Painel Admin / Dashboards)

### ToolJet — https://admin.extensionista.site
- Painel de administração low-code
- Login: configurar na primeira vez em https://admin.extensionista.site
- **Variáveis críticas** (docker-compose.yml):
  - `PG_HOST: kreativ_postgres` (NÃO `postgres` — IPv6 issue!)
  - `PG_PASS: ${POSTGRES_PASSWORD}` (script usa PG_PASS não PG_PASSWORD)
  - `LOCKBOX_MASTER_KEY: ${LOCKBOX_KEY}` (encryption key para migrações)
  - `TOOLJET_DB: tooljet_internal_db` (deve ser DIFERENTE de PG_DB!)

### Metabase — https://dash.extensionista.site
- Dashboards analíticos
- `MB_DB_HOST: kreativ_postgres` (NÃO `postgres` — IPv6 issue!)
- Setup inicial: acessar URL e configurar admin + conectar ao kreativ_edu

### ATENÇÃO: hostname `postgres` → IPv6
O Docker resolve `postgres` para IPv6 (`fd9e:4404:9d55::2`), mas pg_hba.conf
só aceita md5 para conexões externas. Use SEMPRE `kreativ_postgres` como hostname.

---

## 10. Como Fazer Deploy de Mudanças

### BuilderBot (código TypeScript)
```bash
# Editar arquivos em apps/builderbot/src/
# Reconstruir container
docker compose build builderbot
docker compose up -d builderbot

# Verificar logs
docker logs kreativ_builderbot -f --tail 50
```

### N8N Workflows
Editar diretamente na UI: `https://n8n.extensionista.site`
Ou via API (ver seção 7).

### Schema SQL
Editar `/root/ideias_app/init-scripts/01-init-dbs.sql`
Para aplicar sem recriar o container:
```bash
docker exec -i kreativ_postgres psql -U kreativ_user -d kreativ_edu < /root/ideias_app/init-scripts/01-init-dbs.sql
```

---

## 10. Diagnóstico Rápido

```bash
# Ver todos os containers
docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# Testar BuilderBot diretamente
curl -s -X POST http://localhost:3008/webhook \
  -H "Content-Type: application/json" \
  -d '{"entry":[{"changes":[{"value":{"messages":[{"from":"556399999999","type":"text","text":{"body":"MODULO"}}]}}]}]}'

# Testar N8N webhook
curl -s -X POST http://localhost:5678/webhook/get-student-module \
  -H "Content-Type: application/json" \
  -d '{"phone":"556399374165"}'

# Verificar roteamento N8N
# Acesse https://n8n.extensionista.site → workflow "N8N Router" → execuções recentes

# Logs em tempo real
docker logs kreativ_n8n -f --tail 30
docker logs kreativ_builderbot -f --tail 30
docker logs kreativ_evolution_api -f --tail 30
```

---

## 11. O Que Está Funcionando (18/02/2026)

- [x] Stack Docker completa rodando (PostgreSQL, Redis, Evolution API, N8N, BuilderBot, MinIO)
- [x] WhatsApp conectado via Evolution API (instância `europs`)
- [x] N8N Router roteando mensagens corretamente para BuilderBot
- [x] BuilderBot processando mensagens de alunos
- [x] Módulos sendo entregues via WhatsApp (conteúdo do DB)
- [x] Quiz com questões reais do banco de dados
- [x] Progresso salvo no PostgreSQL
- [x] Avanço de módulo ao atingir 70%
- [x] Fluxo de atendimento humano iniciado (TUTOR → attendance_status='human')
- [x] Telefones BR 12 e 13 dígitos tratados no roteamento

---

## 12. O Que Está Pendente (ver ROADMAP.md)

- [ ] Chatwoot acessível (suporte.extensionista.site — container comentado no compose)
- [ ] Alerta para tutores quando aluno solicita atendimento humano
- [ ] RAGFlow para indexação de PDFs do material didático
- [ ] ToolJet para painel administrativo
- [ ] Certificados automáticos (N8N + Puppeteer)
- [ ] Metabase para analytics
- [ ] Portal Next.js para conteúdo rico

---

## 13. Contato e Contexto do Projeto

- **Proprietário**: Rafael da Silva — `rafael.luciano@mail.uft.edu.br`
- **N8N login**: `rafael.luciano@mail.uft.edu.br`
- **Coolify**: `http://187.77.46.37:8000`
- **WhatsApp instância**: `europs` (configurada no Evolution API)
- **Curso padrão**: `course_id='default'` ou `id=1`
