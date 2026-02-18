#!/bin/bash

# =============================================================================
# SCRIPT DE CRIAÇÃO - WHATSAPP CLOUD API (META)
# Evolution API v2 + WHATSAPP-BUSINESS integration
# =============================================================================

DOMAIN="http://localhost:8081"

# Carrega variáveis do .env
if [ -f .env ]; then
    set -a
    source .env
    set +a
fi

API_KEY="${EVOLUTION_API_KEY:-EXr5OuEE2sBMbRo94LtWQfofvEF1gHUM}"

# Nome da instância: usa EVOLUTION_INSTANCE do .env (padrão: europs)
INSTANCE="${EVOLUTION_INSTANCE:-europs}"

# Credenciais da Meta (lidas do .env)
TOKEN="${META_TOKEN:-${META_JWT_TOKEN:-}}"
NUMBER_ID="${META_NUMBER_ID:-}"
BUSINESS_ID="${META_BUSINESS_ID:-}"
WEBHOOK_TOKEN="${WA_BUSINESS_TOKEN_WEBHOOK:-evolution}"

# Verifica credenciais
if [ -z "$TOKEN" ] || [ -z "$NUMBER_ID" ]; then
    echo "ERRO: META_JWT_TOKEN e META_NUMBER_ID precisam estar no .env"
    exit 1
fi

echo "=============================================="
echo " Instância  : $INSTANCE"
echo " Number ID  : $NUMBER_ID"
echo " Business ID: $BUSINESS_ID"
echo "=============================================="

echo ""
echo "=== [1/3] REMOVENDO INSTÂNCIA EXISTENTE ($INSTANCE) ==="
RESP=$(curl -s -X DELETE "$DOMAIN/instance/delete/$INSTANCE" \
  -H "apikey: $API_KEY")
echo "$RESP"

sleep 2

echo ""
echo "=== [2/3] CRIANDO INSTÂNCIA WHATSAPP-BUSINESS ==="
# IMPORTANTE: campo correto é "number" (Phone Number ID), não "numberId"
curl -s -X POST "$DOMAIN/instance/create" \
  -H "apikey: $API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"instanceName\": \"$INSTANCE\",
    \"integration\": \"WHATSAPP-BUSINESS\",
    \"token\": \"$TOKEN\",
    \"number\": \"$NUMBER_ID\",
    \"businessId\": \"$BUSINESS_ID\",
    \"qrcode\": false
  }" | python3 -m json.tool 2>/dev/null || echo "(resposta acima)"

echo ""
echo "=== [3/3] STATUS FINAL ==="
curl -s "$DOMAIN/instance/fetchInstances" \
  -H "apikey: $API_KEY" | python3 -c "
import json, sys
instances = json.load(sys.stdin)
for i in instances:
    if i['name'] == '${INSTANCE}':
        print('Nome        :', i['name'])
        print('Status      :', i['connectionStatus'])
        print('Integração  :', i['integration'])
        print('Número      :', i['number'])
        print('Business ID :', i['businessId'])
" 2>/dev/null

echo ""
echo "=============================================="
echo " PROXIMOS PASSOS — CONFIGURE O WEBHOOK NA META"
echo "=============================================="
echo ""
echo "1. Acesse: developers.facebook.com → Seu App → WhatsApp → Configuração"
echo "2. Em 'Webhook', clique em 'Editar' (ou 'Adicionar URL de callback')"
echo "3. Preencha:"
echo ""
echo "   URL de callback : https://evolution.extensionista.site/webhook/meta"
echo "   Token de verificação: $WEBHOOK_TOKEN"
echo ""
echo "4. Clique em 'Verificar e salvar'"
echo "   (A Evolution API responde o desafio AUTOMATICAMENTE)"
echo ""
echo "5. Assine os campos:"
echo "   [x] messages"
echo "   [x] message_status"
echo "   [x] message_template_status_update"
echo ""
echo "6. Reinicie o BuilderBot para reconectar à nova instância:"
echo "   docker restart kreativ_builderbot"
echo "=============================================="
