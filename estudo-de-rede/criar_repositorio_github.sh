#!/bin/bash
# ══════════════════════════════════════════════════════════
#  Script: criar_repositorio_github.sh
#  Cria o repositório "estudo-de-rede" no GitHub e faz push
#
#  Como usar:
#    1. Abra o Terminal
#    2. cd CAMINHO/DESTA/PASTA
#    3. chmod +x criar_repositorio_github.sh
#    4. ./criar_repositorio_github.sh
# ══════════════════════════════════════════════════════════

set -e

REPO_NAME="estudo-de-rede"
DESCRICAO="Mapa interativo de postos de combustiveis do Brasil - Dados ANP"

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║   ⛽  Estudo de Rede – Criar Repositório GitHub  ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# ── Verifica se o Git está instalado ──
if ! command -v git &>/dev/null; then
    echo "❌ Git não encontrado. Instale em: https://git-scm.com"
    exit 1
fi
echo "✅ Git encontrado: $(git --version)"

# ── Verifica se já há um repositório local ──
if [ ! -d ".git" ]; then
    echo "⚠️  Nenhum repositório git encontrado nesta pasta."
    echo "   Execute este script na pasta onde estão os arquivos .py"
    exit 1
fi
echo "✅ Repositório local encontrado"

# ── Verifica se o GitHub CLI (gh) está instalado ──
if command -v gh &>/dev/null; then
    echo "✅ GitHub CLI (gh) encontrado: $(gh --version | head -1)"
    echo ""
    echo "📡 Verificando autenticação no GitHub..."

    if ! gh auth status &>/dev/null; then
        echo ""
        echo "🔐 Você precisa fazer login no GitHub CLI."
        echo "   Executando: gh auth login"
        gh auth login
    fi

    echo ""
    echo "🚀 Criando repositório '$REPO_NAME' no GitHub..."

    # Cria o repositório público
    gh repo create "$REPO_NAME" \
        --public \
        --description "$DESCRICAO" \
        --source=. \
        --remote=origin \
        --push

    echo ""
    echo "✅ Repositório criado e código enviado com sucesso!"
    echo ""
    echo "🔗 Acesse em: https://github.com/$(gh api user --jq .login)/$REPO_NAME"

else
    # ── Sem GitHub CLI: usa HTTPS manual ──
    echo ""
    echo "⚠️  GitHub CLI (gh) não encontrado."
    echo "   Vamos configurar manualmente."
    echo ""
    echo "══════════════════════════════════════════════════"
    echo "  PASSO 1: Crie o repositório no GitHub"
    echo "══════════════════════════════════════════════════"
    echo "  1. Abra: https://github.com/new"
    echo "  2. Nome do repositório: $REPO_NAME"
    echo "  3. Descrição: $DESCRICAO"
    echo "  4. Visibilidade: Public (ou Private)"
    echo "  5. NÃO marque 'Initialize this repository'"
    echo "  6. Clique em 'Create repository'"
    echo ""
    read -p "Pressione ENTER após criar o repositório no GitHub..."
    echo ""

    echo "══════════════════════════════════════════════════"
    echo "  PASSO 2: Informe seu usuário do GitHub"
    echo "══════════════════════════════════════════════════"
    read -p "Seu usuário do GitHub: " GITHUB_USER
    echo ""

    REMOTE_URL="https://github.com/$GITHUB_USER/$REPO_NAME.git"

    echo "📡 Conectando ao repositório remoto..."
    git remote add origin "$REMOTE_URL" 2>/dev/null || \
        git remote set-url origin "$REMOTE_URL"

    echo "🚀 Enviando código para o GitHub..."
    echo "   (será pedido seu usuário e senha/token do GitHub)"
    echo ""
    echo "   ⚠️  Dica: Se pedir senha, use um Personal Access Token."
    echo "   Crie em: https://github.com/settings/tokens"
    echo ""
    git push -u origin main

    echo ""
    echo "✅ Repositório publicado com sucesso!"
    echo "🔗 Acesse em: https://github.com/$GITHUB_USER/$REPO_NAME"
fi

echo ""
echo "══════════════════════════════════════════════════"
echo "  ✅  Concluído!"
echo "══════════════════════════════════════════════════"
echo ""
