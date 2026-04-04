#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════
#  setup_postgres.sh  –  Configura PostgreSQL para Gestão de Frotas
# ═══════════════════════════════════════════════════════════════
#
#  O que este script faz:
#    1. Cria o usuário 'gestao_frota' no PostgreSQL
#    2. Cria o banco de dados 'gestao_frota'
#    3. Concede os privilégios necessários
#    4. Executa server.py uma vez para criar todas as tabelas (init_db)
#
#  Pré-requisitos:
#    • PostgreSQL instalado e rodando
#    • Acesso como superusuário do Postgres (via sudo -u postgres psql)
#    • Python 3 e psycopg2 instalados  (pip install psycopg2-binary)
#
#  Uso:
#    chmod +x setup_postgres.sh
#    ./setup_postgres.sh
#
#  Variáveis de ambiente (opcionais):
#    PG_HOST      (padrão: localhost)
#    PG_PORT      (padrão: 5432)
#    PG_DBNAME    (padrão: gestao_frota)
#    PG_USER      (padrão: gestao_frota)
#    PG_PASSWORD  (padrão: gestao_frota)
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

# ── Parâmetros (sobrepõe com variáveis de ambiente) ────────────
DB_HOST="${PG_HOST:-localhost}"
DB_PORT="${PG_PORT:-5432}"
DB_NAME="${PG_DBNAME:-gestao_frota}"
DB_USER="${PG_USER:-gestao_frota}"
DB_PASS="${PG_PASSWORD:-gestao_frota}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Cores ──────────────────────────────────────────────────────
RED='\033[31m'; GREEN='\033[32m'; YELLOW='\033[33m'
CYAN='\033[36m'; BOLD='\033[1m'; RESET='\033[0m'
ok()   { echo -e "  ${GREEN}✔${RESET}  $*"; }
warn() { echo -e "  ${YELLOW}⚠${RESET}  $*"; }
err()  { echo -e "  ${RED}✘${RESET}  $*"; }
info() { echo -e "  ${CYAN}→${RESET}  $*"; }

echo ""
echo -e "${BOLD}══════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}  Setup PostgreSQL — Gestão de Abastecimentos de Frota${RESET}"
echo -e "${BOLD}══════════════════════════════════════════════════════${RESET}"
echo ""
info "Host    : ${DB_HOST}:${DB_PORT}"
info "Banco   : ${DB_NAME}"
info "Usuário : ${DB_USER}"
echo ""

# ── 1. Verifica se o PostgreSQL está acessível ─────────────────
info "Verificando PostgreSQL…"
if ! command -v psql &>/dev/null; then
    err "psql não encontrado. Instale o PostgreSQL antes de continuar."
    exit 1
fi

# Testa a conexão como superusuário
if sudo -u postgres psql -c '\q' &>/dev/null 2>&1; then
    PSQL_CMD="sudo -u postgres psql"
elif psql -U postgres -c '\q' &>/dev/null 2>&1; then
    PSQL_CMD="psql -U postgres"
else
    err "Não foi possível conectar ao PostgreSQL como superusuário."
    err "Certifique-se de que o PostgreSQL está rodando e que você tem permissão de sudo."
    exit 1
fi
ok "PostgreSQL acessível"

# ── 2. Cria o usuário ──────────────────────────────────────────
info "Criando usuário '${DB_USER}'…"
$PSQL_CMD <<-EOSQL
DO \$\$
BEGIN
    IF NOT EXISTS (
        SELECT FROM pg_catalog.pg_roles WHERE rolname = '${DB_USER}'
    ) THEN
        CREATE USER "${DB_USER}" WITH PASSWORD '${DB_PASS}';
        RAISE NOTICE 'Usuário "${DB_USER}" criado.';
    ELSE
        ALTER USER "${DB_USER}" WITH PASSWORD '${DB_PASS}';
        RAISE NOTICE 'Usuário "${DB_USER}" já existe — senha atualizada.';
    END IF;
END
\$\$;
EOSQL
ok "Usuário '${DB_USER}' configurado"

# ── 3. Cria o banco de dados ───────────────────────────────────
info "Criando banco de dados '${DB_NAME}'…"
DB_EXISTS=$($PSQL_CMD -tAc "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'")
if [ "$DB_EXISTS" = "1" ]; then
    warn "Banco '${DB_NAME}' já existe — mantendo dados existentes"
else
    $PSQL_CMD -c "CREATE DATABASE \"${DB_NAME}\" OWNER \"${DB_USER}\" ENCODING 'UTF8' LC_COLLATE 'pt_BR.UTF-8' LC_CTYPE 'pt_BR.UTF-8' TEMPLATE template0;" 2>/dev/null \
    || $PSQL_CMD -c "CREATE DATABASE \"${DB_NAME}\" OWNER \"${DB_USER}\" ENCODING 'UTF8';"
    ok "Banco '${DB_NAME}' criado"
fi

# ── 4. Concede privilégios ─────────────────────────────────────
info "Concedendo privilégios…"
$PSQL_CMD -d "${DB_NAME}" <<-EOSQL
GRANT ALL PRIVILEGES ON DATABASE "${DB_NAME}" TO "${DB_USER}";
GRANT ALL PRIVILEGES ON SCHEMA public TO "${DB_USER}";
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL ON TABLES    TO "${DB_USER}";
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT ALL ON SEQUENCES TO "${DB_USER}";
EOSQL
ok "Privilégios concedidos"

# ── 5. Verifica se psycopg2 está instalado ─────────────────────
info "Verificando psycopg2…"
if ! python3 -c "import psycopg2" &>/dev/null; then
    warn "psycopg2 não instalado. Tentando instalar…"
    if pip3 install psycopg2-binary --break-system-packages &>/dev/null \
       || pip3 install psycopg2-binary &>/dev/null; then
        ok "psycopg2 instalado"
    else
        err "Não foi possível instalar psycopg2."
        err "Instale manualmente: pip3 install psycopg2-binary"
        exit 1
    fi
else
    ok "psycopg2 disponível"
fi

# ── 6. Executa init_db via server.py ──────────────────────────
info "Criando tabelas (init_db)…"
SERVER_PY="${SCRIPT_DIR}/server.py"
if [ ! -f "$SERVER_PY" ]; then
    err "server.py não encontrado em: ${SCRIPT_DIR}"
    exit 1
fi

export PG_HOST="$DB_HOST"
export PG_PORT="$DB_PORT"
export PG_DBNAME="$DB_NAME"
export PG_USER="$DB_USER"
export PG_PASSWORD="$DB_PASS"

python3 - <<'PYEOF'
import os, sys
sys.path.insert(0, os.environ.get('SCRIPT_DIR', '.'))

# Importa e executa init_db diretamente
import importlib.util, pathlib

script_dir = os.environ.get('SCRIPT_DIR', '.')
spec = importlib.util.spec_from_file_location(
    "server",
    pathlib.Path(script_dir) / "server.py"
)
server = importlib.util.module_from_spec(spec)
spec.loader.exec_module(server)
server.init_db()
print("  \033[32m✔\033[0m  Tabelas criadas/verificadas com sucesso")
PYEOF

# ── 7. Testa a conexão como usuário da aplicação ──────────────
info "Testando conexão com o usuário '${DB_USER}'…"
PGPASSWORD="${DB_PASS}" psql \
    -h "${DB_HOST}" -p "${DB_PORT}" \
    -U "${DB_USER}" -d "${DB_NAME}" \
    -c "SELECT COUNT(*) AS tabelas FROM information_schema.tables WHERE table_schema='public';" \
    2>/dev/null | grep -E '^\s+[0-9]' | xargs -I{} echo "  $(printf '\033[32m✔\033[0m')  {} tabelas no schema public"

echo ""
echo -e "${BOLD}══════════════════════════════════════════════════════${RESET}"
echo -e "  ${GREEN}${BOLD}✔  Setup concluído!${RESET}"
echo ""
echo "  Próximos passos:"
echo "    1. (Opcional) Migrar dados do SQLite:"
echo "       python3 migrate_to_postgres.py gestao_frota.db"
echo ""
echo "    2. Iniciar o servidor:"
echo "       python3 server.py"
echo ""
echo "    3. Abrir no navegador:"
echo "       http://localhost:8080"
echo -e "${BOLD}══════════════════════════════════════════════════════${RESET}"
echo ""
