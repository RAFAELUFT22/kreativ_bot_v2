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

> **TODOS os serviços ativos** e operacionais.

---

## 3. Fluxo de Mensagem Detalhado

```
1. Aluno manda msg no WhatsApp
2. Evolution API recebe (instância: europs)
3. Evolution API dispara webhook → N8N Router (http://n8n:5678/webhook/whatsapp)
4. N8N Router:
   a. Consulta students.attendance_status e current_module no PostgreSQL
   b. Se attendance_status='human' → ignora (Chatwoot cuida)
   c. Se keyword em BUILDERBOT_KEYWORDS ou current_module>0 → BuilderBot
   d. Caso contrário → DeepSeek (resposta IA livre)
5. BuilderBot recebe em POST /webhook
6. BuilderBot processa flow, chama N8N webhooks para dados (get-student-module, etc.)
```

### Atenção: URLs Internas (DNS do Docker)
- **Evolution -> Chatwoot**: `http://chatwoot-app:3000`
- **Evolution -> N8N**: `http://n8n:5678`
- **N8N -> Chatwoot**: `http://chatwoot-app:3000`
- **N8N -> BuilderBot**: `http://kreativ_builderbot:3008`
- **NENHUM IP FIXO (10.0.x.x) deve ser usado**, pois mudam no restart.

---

## 4. Variáveis de Ambiente Críticas

Arquivo: `/root/ideias_app/.env` (não commitado)

```
# PostgreSQL hostname: kreativ_postgres
# Evolution: EVOLUTION_INSTANCE=europs
# DeepSeek: DEEPSEEK_API_KEY=sk-... (Model: deepseek-chat)
# Chatwoot: CHATWOOT_URL=http://chatwoot-app:3000 (interno para API)
# N8N: N8N_API_KEY=...
```

---

## 5. Workflows N8N Ativos

| ID | Nome | Webhook Path | Função |
|---|---|---|---|
| `oeM02qpKdIGFbGQX` | WhatsApp Router | `/webhook/whatsapp` | Roteador principal (DeepSeek/BuilderBot) |
| `oDg2TF7C0ne12fFg` | get-student-module | `/webhook/get-student-module` | Busca conteúdo e quiz |
| `sKXwOHDHjEadXQD0` | submit-quiz-answer | `/webhook/submit-quiz-answer` | Valida quiz e chama lead-scoring |
| `04ZmheF5PCJr52aI` | request-human-support | `/webhook/request-human-support` | Cria conversa no Chatwoot |
| `9SQfSnUNWOc3SKFT` | Atualizar Label Chatwoot | `/webhook/update-chatwoot-label` | Sync etiquetas (ex: em-andamento-m2) |
| `zOSTJqpGI87IKmkm` | Chatwoot -> Retomar Bot | `/webhook/chatwoot-events` | Quando tutor resolve, volta para bot |
| `cj1N7ZPVoDxlI7Sk` | Lead Scoring | `/webhook/module-completed` | Calcula score e envia parabéns |
| `yKcjMnH87VsO5n9V` | Emitir Certificado | `/webhook/emit-certificate` | Gera HTML e link (sem Puppeteer) |

---

## 6. Banco de Dados

**Conectar**: `docker exec -it kreativ_postgres psql -U kreativ_user -d kreativ_edu`

**Reset de aluno para teste**:
```sql
UPDATE students SET
  current_module = 1,
  completed_modules = '{}',
  scores = '{}',
  lead_score = 0,
  attendance_status = 'bot',
  updated_at = NOW()
WHERE phone = 'PHONE';
```

---

## 7. Status das Fases (Roadmap)

- [x] **Fase 1-3**: Infra base, BuilderBot, Fluxos iniciais
- [x] **Fase 7**: ToolJet (Admin) - Online
- [x] **Fase 8**: Chatwoot (Suporte) - Online e Integrado
- [x] **Fase 9**: Lead Scoring - Online
- [x] **Fase 10**: Certificados (HTML Template) - Online
- [x] **Fase 11**: Metabase (Dashboards) - Online
- [x] **Fase 12**: Portal do Aluno (Next.js) - Online em `portal.extensionista.site`

**Próximos Passos (Futuro)**:
- [ ] RAGFlow (Material Didático com IA) - Requer setup específico
- [ ] Conteúdo real dos módulos (popular DB)
- [ ] Personalização fina dos dashboards Metabase

---

## 8. Como Fazer Deploy

**GitHub Push**:
```bash
git add .
git commit -m "feat: ..."
git push origin main
```
(Token já configurado no sistema)

**N8N Workflows**:
- Use script `push_workflows.js` no container se editar JSONs locais.
- `docker exec ... node /home/node/push_workflows.js`

**BuilderBot / Portal**:
- `docker compose build nome_servico`
- `docker compose up -d nome_servico`
