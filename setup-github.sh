#!/bin/bash
# =============================================================================
# SCRIPT DE CONFIGURAÇÃO DO GITHUB
# Execute após criar o repositório no GitHub
#
# COMO USAR:
# 1. Acesse https://github.com/new e crie um repositório (ex: kreativ-educacao)
# 2. Gere um Personal Access Token em https://github.com/settings/tokens
#    → Permissões necessárias: repo (full control)
# 3. Execute:
#    GITHUB_USER="seu-usuario" GITHUB_TOKEN="ghp_xxx..." REPO_NAME="kreativ-educacao" bash setup-github.sh
# =============================================================================

set -e

GITHUB_USER="${GITHUB_USER:-}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
REPO_NAME="${REPO_NAME:-kreativ-educacao}"

if [ -z "$GITHUB_USER" ] || [ -z "$GITHUB_TOKEN" ]; then
  echo "Erro: defina as variáveis GITHUB_USER e GITHUB_TOKEN"
  echo "Exemplo:"
  echo "  GITHUB_USER=\"rafaelluciano\" GITHUB_TOKEN=\"ghp_xxx\" REPO_NAME=\"kreativ-educacao\" bash setup-github.sh"
  exit 1
fi

REPO_URL="https://${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${REPO_NAME}.git"

echo "Configurando remote..."
git remote remove origin 2>/dev/null || true
git remote add origin "$REPO_URL"

echo "Criando branch main e fazendo push..."
git branch -M main
git push -u origin main

echo ""
echo "✅ Push realizado com sucesso!"
echo "Repositório: https://github.com/${GITHUB_USER}/${REPO_NAME}"
