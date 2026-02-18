#!/bin/bash

# Configurações do seu ambiente
DOMAIN="https://evolution.extensionista.site"
API_KEY="EXr5OuEE2sBMbRo94LtWQfofvEF1gHUM"
INSTANCE="kreativ-bot"

echo "=== CRIANDO INSTÂNCIA: $INSTANCE ==="
curl -X POST "$DOMAIN/instance/create" \
-H "apikey: $API_KEY" \
-H "Content-Type: application/json" \
-d "{
  \"instanceName\": \"$INSTANCE\",
  \"token\": \"EXr5OuEE2sBMbRo94LtWQfofvEF1gHUM\",
  \"qrcode\": true,
  \"integration\": \"WHATSAPP-BAILEYS\"
}"

echo -e "\n\n=== VERIFICANDO CONEXÃO / PEGANDO QR CODE ==="
echo "Acesse este link no navegador para ver o QR Code se o terminal não exibir:"
echo "$DOMAIN/instance/connect/$INSTANCE"

curl -X GET "$DOMAIN/instance/connect/$INSTANCE" \
-H "apikey: $API_KEY"
echo -e "\n"
