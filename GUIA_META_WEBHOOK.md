# Guia: WhatsApp Cloud API — Conexão + Webhook
**Kreativ Educação | Evolution API v2.2.3 + Meta Cloud API**

---

## Estado Atual (diagnosticado em 18/02/2026)

| Item | Estado |
|------|--------|
| Evolution API | ✅ Rodando (`evolution.extensionista.site`) |
| Instância `europs` | ❌ Tipo errado (`WHATSAPP-BAILEYS`, desconectada) |
| BuilderBot | ⚠️ Iniciado mas com erro de auth (causa: instância errada) |
| Endpoint `/webhook/meta` | ✅ Funcional (responde challenge automaticamente) |
| Meta webhook configurado | ❌ Pendente |

---

## Por Que a Evolution API Não Precisa de Fluxo N8N para o Challenge

Quando você configura o webhook no painel da Meta, ela faz uma requisição GET:
```
GET https://evolution.extensionista.site/webhook/meta
  ?hub.mode=subscribe
  &hub.verify_token=SEU_TOKEN
  &hub.challenge=NUMERO_ALEATORIO
```

A Evolution API v2 já tem o handler desse endpoint embutido. Ela:
1. Valida que `hub.verify_token` bate com o `WA_BUSINESS_TOKEN_WEBHOOK` configurado
2. Responde com o valor de `hub.challenge` (isso é exigido pela Meta)

**Testado e funcionando:**
```bash
curl "http://localhost:8081/webhook/meta?hub.mode=subscribe&hub.verify_token=evolution&hub.challenge=HELLO"
# Resposta: HELLO ← Meta aceita isso como confirmação
```

> O vídeo que você viu provavelmente mostrava uma arquitetura diferente onde o N8N recebia o webhook DIRETAMENTE da Meta, sem Evolution API no meio. No nosso caso, a Evolution é o intermediário e já cuida do challenge.

---

## Sequência de Setup — Passo a Passo

### PASSO 1 — Recriar a Instância (você executa na VPS)

```bash
cd /root/ideias_app
bash create_instance_meta.sh
```

**O que o script faz:**
1. Remove a instância `europs` atual (está errada — é Baileys)
2. Recria como `WHATSAPP-BUSINESS` com seu `META_JWT_TOKEN` + `META_NUMBER_ID`
3. Mostra o status final

**Resultado esperado:**
```json
{
  "instanceName": "europs",
  "integration": "WHATSAPP-BUSINESS",
  "connectionStatus": "open"   ← cloud API não precisa de QR
}
```

Se `connectionStatus` ficar como `close` ou der erro 401/403, o `META_JWT_TOKEN` provavelmente **expirou**. Veja a seção "Token Expirado" abaixo.

---

### PASSO 2 — Configurar Webhook no Meta Developer (manual, exige browser)

1. Acesse: **developers.facebook.com** → Faça login com a conta do Business Manager

2. Selecione o app do projeto (ou crie se necessário)

3. No menu lateral: **WhatsApp → Configuração** (ou "Configuration")

4. Seção **Webhook** → clique **Editar** (ou "Configure Webhooks")

5. Preencha EXATAMENTE:

   | Campo | Valor |
   |-------|-------|
   | URL de callback | `https://evolution.extensionista.site/webhook/meta` |
   | Token de verificação | `evolution` |

6. Clique **Verificar e salvar** (Verify and save)
   - Meta fará uma chamada GET para validar
   - Evolution API vai responder o challenge automaticamente em < 1 segundo
   - Se der erro de verificação: veja "Problemas Comuns" abaixo

7. Após verificar, **assine os campos** (webhook fields):
   - [x] `messages`
   - [x] `message_status`
   - [x] `message_template_status_update`

8. Clique **Salvar**

---

### PASSO 3 — Reiniciar o BuilderBot (você executa na VPS)

```bash
docker restart kreativ_builderbot

# Aguardar ~10s e verificar os logs
docker logs kreativ_builderbot --tail 20
```

**Log de sucesso esperado:**
```
[BuilderBot] Iniciado na porta 3008
[BuilderBot] Evolution API: http://evolution-api:8080
[BuilderBot] Instância: europs
HTTP Server ON
```
Sem erros de AUTH significa que o BuilderBot se conectou à instância.

---

### PASSO 4 — Teste de Ponta a Ponta

Envie uma mensagem de WhatsApp para o número conectado.
Verifique os logs:

```bash
# Ver mensagens chegando na Evolution API
docker logs kreativ_evolution --tail 50 -f

# Ver o BuilderBot processando
docker logs kreativ_builderbot --tail 50 -f
```

---

## Problemas Comuns

### "Token Expirado" — META_JWT_TOKEN inválido

O token `EAAHN1QCX...` no `.env` é um **User Access Token** que expira em ~60 dias.

**Sintoma:** Instance creation retorna erro 401 ou `connectionStatus: close`

**Solução — Gerar token permanente (System User Token):**

1. Acesse **business.facebook.com** → Configurações → Usuários → Usuários do Sistema
2. Crie um "Usuário do sistema" (System User) se não existir
3. Clique em **Gerar novo token**
4. Selecione o app e conceda as permissões:
   - `whatsapp_business_messaging`
   - `whatsapp_business_management`
5. Copie o token gerado (começa com `EAA...` mas não expira)
6. Atualize no `.env`:
   ```
   META_JWT_TOKEN=EAAnovotoken...
   ```
7. Execute o `create_instance_meta.sh` novamente

### "Erro de verificação do webhook" na Meta

**Causas possíveis:**
1. O DNS do `evolution.extensionista.site` não está propagado ainda
2. O SSL/TLS não está válido (Traefik/Let's Encrypt ainda não gerou o certificado)
3. A URL ou token estão com espaço/caractere errado

**Teste antes de configurar na Meta:**
```bash
# Teste do seu computador (fora da VPS)
curl "https://evolution.extensionista.site/webhook/meta?hub.mode=subscribe&hub.verify_token=evolution&hub.challenge=TESTE123"
# Deve retornar: TESTE123
```

Se retornar erro 502/504: problema de rede/DNS/SSL → resolva isso primeiro.

### BuilderBot continua com "ERROR AUTH" após PASSO 3

Verifique se a instância foi criada corretamente:
```bash
curl -s http://localhost:8081/instance/fetchInstances \
  -H "apikey: EXr5OuEE2sBMbRo94LtWQfofvEF1gHUM" | python3 -c "
import json, sys
for i in json.load(sys.stdin):
    if i['name'] == 'europs':
        print(i)
"
```

---

## Alterar o Verify Token (opcional — mais seguro)

O token padrão da Evolution API é `evolution`. Para usar um token personalizado:

**1. Adicione no `.env`:**
```bash
WA_BUSINESS_TOKEN_WEBHOOK=kreativ_meta_wh_2026
```

**2. Adicione no `docker-compose.yml`** na seção `environment` da `evolution-api`:
```yaml
WA_BUSINESS_TOKEN_WEBHOOK: ${WA_BUSINESS_TOKEN_WEBHOOK:-evolution}
```

**3. Recrie o container:**
```bash
docker compose up -d evolution-api
```

**4. No painel da Meta:** use o novo token `kreativ_meta_wh_2026` como "Token de verificação"

---

## O Que o Claude Code Pode Automatizar vs. O Que É Manual

### Automatizado (Claude Code faz via scripts/API)
- Criar/recriar instâncias na Evolution API
- Configurar webhooks da Evolution API para BuilderBot/N8N
- Verificar status de containers e conexões
- Atualizar `.env` e `docker-compose.yml`
- Reiniciar serviços

### Manual Obrigatório (requer browser/acesso externo)
| Ação | Onde | Por quê |
|------|------|---------|
| Configurar webhook URL na Meta | developers.facebook.com | Exige login na conta Facebook |
| Criar/renovar tokens de acesso | business.facebook.com | Exige autenticação 2FA |
| Submeter e aprovar templates | developers.facebook.com | Revisão humana da Meta (1-3 dias) |
| Verificar Business Manager | business.facebook.com | Upload de documentos CNPJ/empresa |

---

## Próximos Passos Após Webhook Funcionando

1. **Templates de mensagem** — criar e submeter para aprovação (necessário para iniciar conversas)
2. **Flows do BuilderBot** — adaptar `welcome.flow.ts` para usar templates aprovados
3. **N8N workflows** — criar fluxo de qualificação de leads + certificados
4. **Chatwoot/atendimento humano** — Fase 2 (após upgrade VPS para 8GB)

---

*Gerado pelo Claude Code — Kreativ Educação — Fevereiro 2026*
