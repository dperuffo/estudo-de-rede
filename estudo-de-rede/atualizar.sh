#!/bin/bash
# ══════════════════════════════════════════════════════════════════
#  atualizar.sh — Copia o arquivo do Claude e faz deploy no GitHub
#
#  Como usar (apenas uma vez para configurar):
#    chmod +x atualizar.sh
#
#  Como usar toda vez que o Claude atualizar o código:
#    ./atualizar.sh
# ══════════════════════════════════════════════════════════════════

PROJETO="/Users/daniel/Documents/Claude/Projects/How to use Claude/estudo-de-rede"
CLAUDE_DIR="/Users/daniel/Library/Application Support/Claude/local-agent-mode-sessions/6122515e-4e8b-4fd4-b31b-1b7bd663374a/5f8b2163-a385-4f30-afaa-02d3f7b6f211/local_fa146e09-6ce8-4581-a069-1569f83a41fd/outputs"

VERDE='\033[0;32m'
AZUL='\033[0;34m'
RESET='\033[0m'

echo ""
echo -e "${AZUL}⛽  Estudo de Rede – Atualização rápida${RESET}"
echo ""

# Copia o arquivo principal
echo "📋 Copiando estudo_de_rede.py..."
cp "${CLAUDE_DIR}/estudo_de_rede.py" "${PROJETO}/estudo_de_rede.py"

# Verifica e inclui o logo (deve estar na pasta do projeto)
if [ -f "${PROJETO}/logo_profrotas.png" ]; then
    echo "🖼️  Logo encontrado — será incluído no deploy."
else
    echo "⚠️  logo_profrotas.png não encontrado em:"
    echo "    ${PROJETO}"
    echo "    Salve o arquivo lá para o logo aparecer no app."
fi

# Entra na pasta do projeto
cd "${PROJETO}"

# Sincroniza com o remoto ANTES de commitar (evita rejeição no push)
echo "🔄 Sincronizando com repositório remoto..."
git pull origin master --rebase 2>/dev/null || git pull origin master --no-rebase 2>/dev/null

# Commit e push
MENSAGEM="deploy: atualização $(date '+%d/%m/%Y %H:%M')"
git add estudo_de_rede.py
[ -f logo_profrotas.png ] && git add logo_profrotas.png
for LOGO_FILE in Logo_profrotas.jpg logo_profrotas.jpg Logo_profrotas.png logo_profrotas.png; do
    [ -f "$LOGO_FILE" ] && git add "$LOGO_FILE" && echo "🖼️  Logo incluído: $LOGO_FILE"
done
git commit -m "$MENSAGEM" 2>/dev/null || echo "  ℹ️  Nenhuma mudança nova."
git push origin master

echo ""
echo -e "${VERDE}✅ Pronto! Streamlit Cloud vai atualizar em ~1 minuto.${RESET}"
echo -e "   Acesse: ${AZUL}https://dperuffo-estudo-de-rede.streamlit.app${RESET}"
echo ""
