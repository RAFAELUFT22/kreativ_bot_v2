#!/bin/bash
# =============================================================================
# Importa/atualiza workflows do N8N via API
# Uso: bash import-workflows.sh
# =============================================================================

set -e

cd "$(dirname "$0")/.."

N8N_API_KEY=$(grep N8N_API_KEY .env | cut -d= -f2-)
N8N_URL="http://10.0.2.7:5678"
CRED_ID="FEBlfOrqsjez08pe"

if [ -z "$N8N_API_KEY" ]; then
  echo "ERROR: N8N_API_KEY not found in .env"
  exit 1
fi

echo "=== Kreativ N8N Workflow Importer ==="
echo "N8N URL: $N8N_URL"
echo "Postgres Credential ID: $CRED_ID"
echo ""

# Substitui o placeholder do credential ID nos arquivos JSON
for f in n8n-workflows/*.json; do
  sed -i "s/KREATIV_PG_CRED_ID/${CRED_ID}/g" "$f"
done

import_or_update() {
  local FILE="$1"
  local NAME=$(python3 -c "import json; d=json.load(open('$FILE')); print(d['name'])")

  echo "--- Processando: $NAME"

  # Verifica se já existe
  EXISTING_ID=$(curl -s "${N8N_URL}/api/v1/workflows" \
    -H "X-N8N-API-KEY: ${N8N_API_KEY}" | \
    python3 -c "
import json,sys
d=json.load(sys.stdin)
for w in d.get('data',[]):
    if w['name'] == '${NAME}':
        print(w['id'])
        break
" 2>/dev/null)

  if [ -n "$EXISTING_ID" ]; then
    echo "  Atualizando workflow existente (ID: $EXISTING_ID)..."
    # Desativa antes de atualizar
    curl -s -X PATCH "${N8N_URL}/api/v1/workflows/${EXISTING_ID}" \
      -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
      -H "Content-Type: application/json" \
      -d '{"active": false}' > /dev/null

    # Atualiza o workflow
    RESULT=$(curl -s -X PUT "${N8N_URL}/api/v1/workflows/${EXISTING_ID}" \
      -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
      -H "Content-Type: application/json" \
      -d @"${FILE}")

    NEW_ID=$(echo "$RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('id','ERROR'))" 2>/dev/null)
    echo "  Atualizado: $NEW_ID"
    echo "$EXISTING_ID"
  else
    echo "  Criando novo workflow..."
    RESULT=$(curl -s -X POST "${N8N_URL}/api/v1/workflows" \
      -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
      -H "Content-Type: application/json" \
      -d @"${FILE}")

    NEW_ID=$(echo "$RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('id','ERROR'))" 2>/dev/null)
    ERR=$(echo "$RESULT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('message','OK')[:100])" 2>/dev/null)
    echo "  Criado: $NEW_ID | $ERR"
    echo "$NEW_ID"
  fi
}

activate_workflow() {
  local ID="$1"
  local NAME="$2"
  if [ -n "$ID" ] && [ "$ID" != "ERROR" ]; then
    curl -s -X PATCH "${N8N_URL}/api/v1/workflows/${ID}" \
      -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
      -H "Content-Type: application/json" \
      -d '{"active": true}' > /dev/null
    echo "  Ativado: $NAME ($ID)"
  fi
}

echo "=== 1. WhatsApp Router (workflow principal) ==="
ROUTER_ID=$(import_or_update "n8n-workflows/01-whatsapp-router.json")
activate_workflow "$ROUTER_ID" "WhatsApp Router"

echo ""
echo "=== 2. get-student-module ==="
MODULE_ID=$(import_or_update "n8n-workflows/02-get-student-module.json")
activate_workflow "$MODULE_ID" "get-student-module"

echo ""
echo "=== 3. submit-quiz-answer ==="
QUIZ_ID=$(import_or_update "n8n-workflows/03-submit-quiz-answer.json")
activate_workflow "$QUIZ_ID" "submit-quiz-answer"

echo ""
echo "=== 4. request-human-support ==="
SUPPORT_ID=$(import_or_update "n8n-workflows/04-request-human-support.json")
activate_workflow "$SUPPORT_ID" "request-human-support"

echo ""
echo "=== Desativar workflow antigo (WhatsApp Bot - Kreativ Educação) ==="
OLD_ID=$(curl -s "${N8N_URL}/api/v1/workflows" \
  -H "X-N8N-API-KEY: ${N8N_API_KEY}" | \
  python3 -c "
import json,sys
d=json.load(sys.stdin)
for w in d.get('data',[]):
    if w['name'] == 'WhatsApp Bot - Kreativ Educação':
        print(w['id'])
        break
" 2>/dev/null)

if [ -n "$OLD_ID" ]; then
  curl -s -X PATCH "${N8N_URL}/api/v1/workflows/${OLD_ID}" \
    -H "X-N8N-API-KEY: ${N8N_API_KEY}" \
    -H "Content-Type: application/json" \
    -d '{"active": false}' > /dev/null
  echo "  Desativado: WhatsApp Bot - Kreativ Educação ($OLD_ID)"
fi

echo ""
echo "=== Workflows ativos ==="
curl -s "${N8N_URL}/api/v1/workflows" \
  -H "X-N8N-API-KEY: ${N8N_API_KEY}" | \
  python3 -c "
import json,sys
d=json.load(sys.stdin)
for w in d.get('data',[]):
    status = '✅ ativo  ' if w['active'] else '⏸  inativo'
    print(f'  {status} | {w[\"id\"]} | {w[\"name\"]}')
"
echo ""
echo "Pronto!"
