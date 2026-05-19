#!/bin/bash
# ══════════════════════════════════════════════════════════════════
#  deploy.sh — GitHub + fly.io em um único comando
#  Estudo de Rede – Pró-Frotas
#
#  Como usar:
#    1. Abra o Terminal na pasta do projeto (estudo-de-rede)
#    2. chmod +x deploy.sh
#    3. ./deploy.sh
# ══════════════════════════════════════════════════════════════════

set -e

VERDE='\033[0;32m'
AZUL='\033[0;34m'
AMARELO='\033[1;33m'
RESET='\033[0m'

echo ""
echo -e "${AZUL}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${AZUL}║   ⛽  Estudo de Rede – Pró-Frotas  |  Deploy        ║${RESET}"
echo -e "${AZUL}╚══════════════════════════════════════════════════════╝${RESET}"
echo ""

# ─── 1. Git: commit e push ────────────────────────────────────────
echo -e "${AMARELO}📦 Passo 1/3 — Atualizando repositório GitHub...${RESET}"

if ! command -v git &>/dev/null; then
    echo "❌ Git não encontrado. Instale em: https://git-scm.com"
    exit 1
fi

git add -A
git status --short

# Mensagem de commit com data/hora
MENSAGEM="deploy: atualização $(date '+%d/%m/%Y %H:%M')"
git commit -m "$MENSAGEM" 2>/dev/null || echo "  ℹ️  Nada novo para commitar."

# Verifica se há remote configurado
if git remote get-url origin &>/dev/null; then
    git push origin main 2>/dev/null || git push origin master 2>/dev/null || {
        echo -e "${AMARELO}  ⚠️  Push falhou. Verifique suas credenciais do GitHub.${RESET}"
    }
    echo -e "${VERDE}  ✅ Código enviado para o GitHub${RESET}"
else
    echo -e "${AMARELO}  ⚠️  Nenhum repositório remoto configurado. Pulando push.${RESET}"
    echo "     Configure com: git remote add origin https://github.com/SEU_USUARIO/estudo-de-rede.git"
fi

echo ""

# ─── 2. fly.io: verificação ───────────────────────────────────────
echo -e "${AMARELO}🚀 Passo 2/3 — Verificando fly.io CLI...${RESET}"

if ! command -v flyctl &>/dev/null && ! command -v fly &>/dev/null; then
    echo ""
    echo "  ❌ flyctl não encontrado. Instale com:"
    echo ""
    echo "     curl -L https://fly.io/install.sh | sh"
    echo ""
    echo "  Depois execute este script novamente."
    exit 1
fi

FLY_CMD=$(command -v flyctl 2>/dev/null || command -v fly)
echo -e "${VERDE}  ✅ flyctl encontrado: $($FLY_CMD version | head -1)${RESET}"

echo ""
echo "  Verificando autenticação..."
if ! $FLY_CMD auth whoami &>/dev/null; then
    echo "  🔐 Você precisa fazer login no fly.io:"
    $FLY_CMD auth login
fi
echo -e "${VERDE}  ✅ Autenticado: $($FLY_CMD auth whoami)${RESET}"

echo ""

# ─── 3. fly.io: deploy ────────────────────────────────────────────
echo -e "${AMARELO}🌐 Passo 3/3 — Fazendo deploy no fly.io...${RESET}"
echo ""

APP_NAME=$(grep '^app' fly.toml | sed 's/app *= *"\(.*\)"/\1/')

# Verifica se o app já existe
if $FLY_CMD apps list 2>/dev/null | grep -q "$APP_NAME"; then
    echo "  📡 App '$APP_NAME' já existe — atualizando..."
    $FLY_CMD deploy --ha=false
else
    echo "  🆕 Criando novo app '$APP_NAME'..."
    $FLY_CMD launch --name "$APP_NAME" --region gru --no-deploy --copy-config
    $FLY_CMD deploy --ha=false
fi

echo ""
echo -e "${VERDE}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${VERDE}║   ✅  Deploy concluído com sucesso!                  ║${RESET}"
echo -e "${VERDE}╚══════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "  🌐 Acesse em: ${AZUL}https://${APP_NAME}.fly.dev${RESET}"
echo ""
