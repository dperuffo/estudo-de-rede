#!/usr/bin/env python3
"""
═══════════════════════════════════════════════════════════════
  BACKEND – Gestão de Abastecimentos de Frota
  Banco de dados: PostgreSQL  |  Servidor: HTTP stdlib Python
═══════════════════════════════════════════════════════════════
  Configuração (variáveis de ambiente ou defaults):
    PG_HOST      = localhost
    PG_PORT      = 5432
    PG_DBNAME    = gestao_frota
    PG_USER      = gestao_frota
    PG_PASSWORD  = gestao_frota

  Como usar:
    1. python3 server.py
    2. Abra http://localhost:8080 no navegador
    3. Pressione Ctrl+C para parar o servidor
═══════════════════════════════════════════════════════════════
"""
from http.server import HTTPServer, BaseHTTPRequestHandler
import psycopg2
import psycopg2.extras
import json, os, re, sys, threading, hashlib, secrets, smtplib
from datetime import date as _date, datetime, timedelta
from urllib.parse import urlparse, parse_qs
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

BASE_DIR  = os.path.dirname(os.path.abspath(__file__))
HTML_FILE = os.path.join(BASE_DIR, 'gestao-abastecimentos.html')
# PORT: Railway define dinamicamente via env var PORT
PORT      = int(os.environ.get('PORT', '8080'))

# ═══════════════════════════════════════════════════════════════
#  CONFIGURAÇÃO DO BANCO PostgreSQL
#  Suporta DATABASE_URL (Railway/Heroku) ou variáveis individuais
# ═══════════════════════════════════════════════════════════════
_DATABASE_URL = os.environ.get('DATABASE_URL', '')

if _DATABASE_URL:
    # Railway / Render / Heroku fornecem DATABASE_URL no formato:
    # postgresql://user:pass@host:port/dbname
    _u = urlparse(_DATABASE_URL)
    DB_HOST  = _u.hostname
    DB_PORT  = _u.port or 5432
    DB_NAME  = _u.path.lstrip('/')
    DB_USER  = _u.username
    DB_PASS  = _u.password
    DB_SSL   = {'sslmode': 'require'}   # Railway exige SSL
else:
    DB_HOST  = os.environ.get('PG_HOST',    'localhost')
    DB_PORT  = int(os.environ.get('PG_PORT','5432'))
    DB_NAME  = os.environ.get('PG_DBNAME', 'gestao_frota')
    DB_USER  = os.environ.get('PG_USER',   'gestao_frota')
    DB_PASS  = os.environ.get('PG_PASSWORD','gestao_frota')
    DB_SSL   = {}

# ── Configuração SMTP (e-mail) ────────────────────────────────
SMTP_HOST   = os.environ.get('SMTP_HOST',  '')
SMTP_PORT   = int(os.environ.get('SMTP_PORT','587'))
SMTP_USER   = os.environ.get('SMTP_USER',  '')
SMTP_PASS   = os.environ.get('SMTP_PASS',  '')
SMTP_FROM   = os.environ.get('SMTP_FROM',  'noreply@gestaofrota.com')
APP_URL     = os.environ.get('APP_URL',    'http://localhost:8080')

def get_db():
    conn = psycopg2.connect(
        host=DB_HOST, port=DB_PORT,
        dbname=DB_NAME, user=DB_USER, password=DB_PASS,
        **DB_SSL
    )
    return conn

def _cur(conn):
    """Retorna cursor que retorna linhas como dicionários."""
    return conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

def _exec(conn, sql, params=None):
    cur = _cur(conn)
    cur.execute(sql, params or [])
    return cur

def _fetchall(conn, sql, params=None):
    cur = _exec(conn, sql, params)
    return [dict(r) for r in cur.fetchall()]

def _fetchone(conn, sql, params=None):
    cur = _exec(conn, sql, params)
    row = cur.fetchone()
    return dict(row) if row else None

def _hoje():
    return _date.today().isoformat()

# ═══════════════════════════════════════════════════════════════
#  AUTENTICAÇÃO
# ═══════════════════════════════════════════════════════════════
_SALT = os.environ.get('AUTH_SALT') or 'gestao_frota_salt_2024'

def _hash_senha(senha: str) -> str:
    dk = hashlib.pbkdf2_hmac('sha256', senha.encode(), _SALT.encode(), 200_000)
    return dk.hex()

def _gen_token() -> str:
    return secrets.token_urlsafe(48)

def _auth_get_user(conn, token: str):
    """Valida token de sessão e retorna usuário + permissões, ou None."""
    if not token:
        return None
    sess = _fetchone(conn,
        "SELECT * FROM sessoes WHERE token=%s AND expiry > NOW()", [token])
    if not sess:
        return None
    usr = _fetchone(conn,
        "SELECT u.*, pa.nome AS perfil_nome FROM usuarios u "
        "LEFT JOIN perfis_acesso pa ON pa.id = u.perfil_id "
        "WHERE u.id=%s AND u.status='Ativo'", [sess['usuario_id']])
    if not usr:
        return None
    perms = _fetchall(conn,
        "SELECT * FROM permissoes_perfil WHERE perfil_id=%s", [usr.get('perfil_id')])
    usr['permissoes'] = perms
    return usr

def _token_from_request(handler) -> str:
    auth = handler.headers.get('Authorization', '')
    if auth.startswith('Bearer '):
        return auth[7:].strip()
    return ''

def _send_email(to: str, subject: str, html_body: str):
    """Envia e-mail via SMTP. Se não configurado, imprime no console."""
    if not SMTP_HOST or not SMTP_USER:
        print(f'\n[EMAIL → {to}]\nAssunto: {subject}\n{html_body}\n')
        return
    try:
        msg = MIMEMultipart('alternative')
        msg['Subject'] = subject
        msg['From']    = SMTP_FROM
        msg['To']      = to
        msg.attach(MIMEText(html_body, 'html', 'utf-8'))
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as s:
            s.starttls()
            s.login(SMTP_USER, SMTP_PASS)
            s.sendmail(SMTP_FROM, [to], msg.as_string())
    except Exception as e:
        print(f'[EMAIL ERROR] {e}')

def _sync_abast_lancamentos(conn, abast_id, placa, data, posto,
                             combustivel, volume, preco_unitario,
                             arla32_total, servicos_abast, cliente_id):
    """Cria/atualiza lançamentos em lancamentos_cc para um abastecimento,
    usando o centro_custo_id do veículo (se configurado).
    O valor do combustível é calculado como volume × preco_unitario,
    separando-o do Arla 32 e dos serviços avulsos."""
    veiculo = _fetchone(conn,
        'SELECT centro_custo_id FROM veiculos WHERE placa=%s', [placa])
    cc_id = veiculo.get('centro_custo_id') if veiculo else None
    if not cc_id:
        return  # veículo sem centro de custo → não gera lançamento

    # Remove lançamentos anteriores deste abastecimento
    _exec(conn,
        "DELETE FROM lancamentos_cc WHERE referencia_tipo='Abastecimento' AND referencia_id=%s",
        [abast_id])

    data_lanc  = (data or _hoje())[:10]
    desc_base  = f"Abast. {combustivel or ''} — {placa} em {posto or ''}"
    # Valor apenas do combustível (sem Arla 32 e sem serviços)
    comb_valor = round(float(volume or 0) * float(preco_unitario or 0), 2)

    # Combustível principal
    if comb_valor > 0:
        _exec(conn, '''INSERT INTO lancamentos_cc
            (centro_custo_id,data,categoria,descricao,valor,tipo,
             referencia_tipo,referencia_id,cliente_id)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)''', [
            cc_id, data_lanc, 'Combustível', desc_base,
            comb_valor, 'Despesa', 'Abastecimento', abast_id,
            cliente_id or None,
        ])

    # Arla 32
    if arla32_total and float(arla32_total) > 0:
        _exec(conn, '''INSERT INTO lancamentos_cc
            (centro_custo_id,data,categoria,descricao,valor,tipo,
             referencia_tipo,referencia_id,cliente_id)
            VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)''', [
            cc_id, data_lanc, 'Combustível',
            f"Arla 32 — {placa} em {posto or ''}",
            float(arla32_total), 'Despesa', 'Abastecimento', abast_id,
            cliente_id or None,
        ])

    # Serviços avulsos
    if isinstance(servicos_abast, str):
        try:    servicos_abast = json.loads(servicos_abast)
        except: servicos_abast = []
    for svc in (servicos_abast or []):
        v = float(svc.get('valor', 0) or 0)
        if v > 0:
            _exec(conn, '''INSERT INTO lancamentos_cc
                (centro_custo_id,data,categoria,descricao,valor,tipo,
                 referencia_tipo,referencia_id,cliente_id)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)''', [
                cc_id, data_lanc, 'Manutenção',
                f"{svc.get('nome','Serviço')} — {placa}",
                v, 'Despesa', 'Abastecimento', abast_id,
                cliente_id or None,
            ])

# ═══════════════════════════════════════════════════════════════
#  SCHEMA – CREATE TABLES
# ═══════════════════════════════════════════════════════════════
def init_db():
    conn = get_db()
    cur  = _cur(conn)

    cur.execute('''CREATE TABLE IF NOT EXISTS abastecimentos (
        id              SERIAL PRIMARY KEY,
        data            TEXT    NOT NULL,
        hora            TEXT    NOT NULL,
        placa           TEXT    NOT NULL,
        motorista       TEXT    NOT NULL,
        cpf_motorista   TEXT    DEFAULT '',
        hodometro       REAL    DEFAULT 0,
        posto           TEXT    NOT NULL,
        cnpj_posto      TEXT    DEFAULT '',
        cidade_posto    TEXT    DEFAULT '',
        uf_posto        TEXT    DEFAULT '',
        combustivel     TEXT    NOT NULL,
        volume          REAL    DEFAULT 0,
        preco_unitario  REAL    DEFAULT 0,
        valor_total     REAL    DEFAULT 0,
        arla32_volume   REAL    DEFAULT 0,
        arla32_preco    REAL    DEFAULT 0,
        arla32_total    REAL    DEFAULT 0,
        servicos_abast  TEXT    DEFAULT '[]',
        created_at      TEXT    DEFAULT TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS')
    )''')

    cur.execute('''CREATE TABLE IF NOT EXISTS postos (
        id               SERIAL PRIMARY KEY,
        cnpj             TEXT    NOT NULL,
        razao            TEXT    NOT NULL,
        bandeira         TEXT    NOT NULL,
        cep              TEXT    DEFAULT '',
        logradouro       TEXT    DEFAULT '',
        numero           TEXT    DEFAULT '',
        complemento      TEXT    DEFAULT '',
        bairro           TEXT    DEFAULT '',
        cidade           TEXT    DEFAULT '',
        uf               TEXT    DEFAULT '',
        lat              TEXT    DEFAULT '',
        lon              TEXT    DEFAULT '',
        gestor           TEXT    DEFAULT '',
        telefone         TEXT    DEFAULT '',
        email_resp       TEXT    DEFAULT '',
        email_nf         TEXT    DEFAULT '',
        banco            TEXT    DEFAULT '',
        agencia          TEXT    DEFAULT '',
        conta            TEXT    DEFAULT '',
        servicos         TEXT    DEFAULT '[]',
        combustiveis     TEXT    DEFAULT '{}',
        fotos            TEXT    DEFAULT '[]',
        perfil_venda     TEXT    DEFAULT '',
        status_posto     TEXT    DEFAULT 'Ativo',
        situacao         TEXT    DEFAULT 'Habilitado',
        rede             TEXT    DEFAULT '',
        tipo_bandeira    TEXT    DEFAULT '',
        grupo_economico  TEXT    DEFAULT '',
        taxa_admin       REAL    DEFAULT 0,
        possui_internet  TEXT    DEFAULT '',
        data_habilitacao TEXT    DEFAULT '',
        created_at       TEXT    DEFAULT TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS')
    )''')

    cur.execute('''CREATE TABLE IF NOT EXISTS motoristas (
        id              SERIAL PRIMARY KEY,
        cpf             TEXT    NOT NULL UNIQUE,
        nome            TEXT    NOT NULL,
        status          TEXT    DEFAULT 'Ativo',
        classificacao   TEXT    DEFAULT 'Próprio',
        apelido         TEXT    DEFAULT '',
        matricula       TEXT    DEFAULT '',
        celular         TEXT    DEFAULT '',
        email           TEXT    DEFAULT '',
        num_cnh         TEXT    DEFAULT '',
        vencimento_cnh  TEXT    DEFAULT '',
        created_at      TEXT    DEFAULT TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS')
    )''')

    cur.execute('''CREATE TABLE IF NOT EXISTS veiculos (
        id                       SERIAL PRIMARY KEY,
        placa                    TEXT    NOT NULL UNIQUE,
        chassi                   TEXT    DEFAULT '',
        status                   TEXT    DEFAULT 'Ativo',
        classificacao            TEXT    DEFAULT 'Próprio',
        tipo                     TEXT    DEFAULT 'Leve',
        subtipo                  TEXT    DEFAULT 'Passeio',
        num_eixos                INTEGER DEFAULT 2,
        marca                    TEXT    DEFAULT '',
        modelo                   TEXT    DEFAULT '',
        motor                    TEXT    DEFAULT '',
        ano_fabricacao           INTEGER DEFAULT NULL,
        ano_modelo               INTEGER DEFAULT NULL,
        capacidade_tanque        REAL    DEFAULT 0,
        hodometro                REAL    DEFAULT 0,
        renavam                  TEXT    DEFAULT '',
        combustivel_especificado TEXT    DEFAULT '',
        created_at               TEXT    DEFAULT TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS')
    )''')

    cur.execute('''CREATE TABLE IF NOT EXISTS vinculos (
        id              SERIAL PRIMARY KEY,
        placa           TEXT    NOT NULL,
        motorista_nome  TEXT    NOT NULL,
        motorista_cpf   TEXT    DEFAULT '',
        data_inicio     TEXT    NOT NULL,
        data_fim        TEXT    DEFAULT '',
        status          TEXT    DEFAULT 'Ativo',
        observacao      TEXT    DEFAULT '',
        created_at      TEXT    DEFAULT TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS')
    )''')

    cur.execute('''CREATE TABLE IF NOT EXISTS intervalos_abastecimento (
        id                  SERIAL PRIMARY KEY,
        tipo                TEXT    NOT NULL,
        referencia          TEXT    DEFAULT 'Todos',
        intervalo_minimo    REAL    NOT NULL,
        unidade             TEXT    DEFAULT 'Horas',
        status              TEXT    DEFAULT 'Ativo',
        observacao          TEXT    DEFAULT '',
        created_at          TEXT    DEFAULT TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS')
    )''')

    cur.execute('''CREATE TABLE IF NOT EXISTS valor_diario_motorista (
        id          SERIAL PRIMARY KEY,
        motorista   TEXT    DEFAULT 'Todos',
        valor_max   REAL    NOT NULL,
        status      TEXT    DEFAULT 'Ativo',
        observacao  TEXT    DEFAULT '',
        created_at  TEXT    DEFAULT TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS')
    )''')

    cur.execute('''CREATE TABLE IF NOT EXISTS volume_diario_veiculo (
        id          SERIAL PRIMARY KEY,
        placa       TEXT    DEFAULT 'Todos',
        volume_max  REAL    NOT NULL,
        status      TEXT    DEFAULT 'Ativo',
        observacao  TEXT    DEFAULT '',
        created_at  TEXT    DEFAULT TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS')
    )''')

    cur.execute('''CREATE TABLE IF NOT EXISTS seguranca_regras (
        tipo        TEXT    PRIMARY KEY,
        ativo       INTEGER DEFAULT 0,
        valor_int   INTEGER DEFAULT 0,
        valor_text  TEXT    DEFAULT '',
        updated_at  TEXT    DEFAULT TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS')
    )''')

    cur.execute('''CREATE TABLE IF NOT EXISTS precos_anp (
        id                   SERIAL PRIMARY KEY,
        mes                  TEXT    NOT NULL,
        produto              TEXT    NOT NULL,
        preco_medio_revenda  REAL    DEFAULT 0,
        preco_medio_distrib  REAL    DEFAULT 0,
        num_postos           INTEGER DEFAULT 0,
        updated_at           TEXT    DEFAULT TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS'),
        UNIQUE (mes, produto)
    )''')

    cur.execute('''CREATE TABLE IF NOT EXISTS anp_sync_log (
        id         SERIAL PRIMARY KEY,
        status     TEXT DEFAULT 'idle',
        message    TEXT DEFAULT '',
        started_at TEXT DEFAULT TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS'),
        ended_at   TEXT DEFAULT ''
    )''')

    cur.execute('''CREATE TABLE IF NOT EXISTS produto_abastecido_regras (
        id          SERIAL PRIMARY KEY,
        placas      TEXT    DEFAULT '["Todos"]',
        combustiveis TEXT   DEFAULT '[]',
        status      TEXT    DEFAULT 'Ativo',
        observacao  TEXT    DEFAULT '',
        created_at  TEXT    DEFAULT TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS')
    )''')

    cur.execute('''CREATE TABLE IF NOT EXISTS rotogramas (
        id                      SERIAL PRIMARY KEY,
        nome                    TEXT    NOT NULL,
        origem                  TEXT    NOT NULL,
        destino                 TEXT    NOT NULL,
        distancia_km            REAL    DEFAULT 0,
        rodovias                TEXT    DEFAULT '',
        estados                 TEXT    DEFAULT '',
        descricao               TEXT    DEFAULT '',
        status                  TEXT    DEFAULT 'Ativo',
        versao                  TEXT    DEFAULT '1.0',
        ultima_revisao          TEXT    DEFAULT '',
        observacao_seguranca    TEXT    DEFAULT '',
        created_at              TEXT    DEFAULT TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS')
    )''')

    cur.execute('''CREATE TABLE IF NOT EXISTS rotograma_trechos (
        id              SERIAL PRIMARY KEY,
        rotograma_id    INTEGER NOT NULL,
        ordem           INTEGER DEFAULT 0,
        descricao       TEXT    NOT NULL,
        rodovia         TEXT    DEFAULT '',
        km_inicial      REAL    DEFAULT 0,
        km_final        REAL    DEFAULT 0,
        velocidade_max  INTEGER DEFAULT 0,
        tem_cerca       INTEGER DEFAULT 0,
        observacao      TEXT    DEFAULT '',
        created_at      TEXT    DEFAULT TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS')
    )''')

    cur.execute('''CREATE TABLE IF NOT EXISTS rotograma_pontos_criticos (
        id              SERIAL PRIMARY KEY,
        rotograma_id    INTEGER NOT NULL,
        tipo            TEXT    NOT NULL,
        descricao       TEXT    NOT NULL,
        km_referencia   TEXT    DEFAULT '',
        nivel_risco     TEXT    DEFAULT 'Médio',
        observacao      TEXT    DEFAULT '',
        created_at      TEXT    DEFAULT TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS')
    )''')

    cur.execute('''CREATE TABLE IF NOT EXISTS rotograma_pontos_apoio (
        id              SERIAL PRIMARY KEY,
        rotograma_id    INTEGER NOT NULL,
        tipo            TEXT    NOT NULL,
        nome            TEXT    NOT NULL,
        km_referencia   TEXT    DEFAULT '',
        endereco        TEXT    DEFAULT '',
        telefone        TEXT    DEFAULT '',
        observacao      TEXT    DEFAULT '',
        created_at      TEXT    DEFAULT TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS')
    )''')

    cur.execute('''CREATE TABLE IF NOT EXISTS rotograma_execucoes (
        id              SERIAL PRIMARY KEY,
        rotograma_id    INTEGER NOT NULL,
        placa           TEXT    DEFAULT '',
        motorista       TEXT    DEFAULT '',
        data            TEXT    NOT NULL,
        status_exec     TEXT    DEFAULT 'Concluída',
        observacao      TEXT    DEFAULT '',
        created_at      TEXT    DEFAULT TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS')
    )''')

    cur.execute('''CREATE TABLE IF NOT EXISTS planos_viagem (
        id                      SERIAL PRIMARY KEY,
        nome                    TEXT    NOT NULL,
        placa                   TEXT    DEFAULT '',
        motorista               TEXT    DEFAULT '',
        rotograma_id            INTEGER DEFAULT NULL,
        data_saida              TEXT    DEFAULT '',
        data_retorno_prevista   TEXT    DEFAULT '',
        km_estimado             REAL    DEFAULT 0,
        status                  TEXT    DEFAULT 'Rascunho',
        consumo_km_l            REAL    DEFAULT 0,
        preco_combustivel       REAL    DEFAULT 0,
        custo_combustivel       REAL    DEFAULT 0,
        custo_pedagio           REAL    DEFAULT 0,
        num_diarias             INTEGER DEFAULT 0,
        valor_refeicao          REAL    DEFAULT 0,
        valor_pernoite          REAL    DEFAULT 0,
        valor_banho             REAL    DEFAULT 0,
        valor_lavagem           REAL    DEFAULT 0,
        custo_diarias           REAL    DEFAULT 0,
        custo_manutencao_km     REAL    DEFAULT 0,
        custo_manutencao        REAL    DEFAULT 0,
        custo_total_estimado    REAL    DEFAULT 0,
        custo_total_real        REAL    DEFAULT 0,
        observacoes             TEXT    DEFAULT '',
        created_at              TEXT    DEFAULT TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS')
    )''')

    cur.execute('''CREATE TABLE IF NOT EXISTS planos_viagem_pedagios (
        id              SERIAL PRIMARY KEY,
        plano_id        INTEGER NOT NULL,
        nome_praca      TEXT    DEFAULT '',
        km_referencia   TEXT    DEFAULT '',
        valor           REAL    DEFAULT 0,
        sentido         TEXT    DEFAULT 'Ambos',
        created_at      TEXT    DEFAULT TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS')
    )''')

    cur.execute('''CREATE TABLE IF NOT EXISTS hodo_variacao (
        id              SERIAL PRIMARY KEY,
        tipo_veiculo    TEXT    NOT NULL,
        placa           TEXT    DEFAULT 'Todos',
        variacao_max_km INTEGER DEFAULT 0,
        status          TEXT    DEFAULT 'Ativo',
        observacao      TEXT    DEFAULT '',
        created_at      TEXT    DEFAULT TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS')
    )''')

    cur.execute('''CREATE TABLE IF NOT EXISTS negociacoes (
        id               SERIAL PRIMARY KEY,
        posto_id         INTEGER DEFAULT 0,
        posto_nome       TEXT    DEFAULT '',
        posto_cnpj       TEXT    DEFAULT '',
        posto_cidade     TEXT    DEFAULT '',
        posto_uf         TEXT    DEFAULT '',
        combustivel      TEXT    DEFAULT '',
        preco_base       REAL    DEFAULT 0,
        tipo_acordo      TEXT    DEFAULT 'desconto_pct',
        valor_acordo     REAL    DEFAULT 0,
        preco_negociado  REAL    DEFAULT 0,
        volume_estimado  REAL    DEFAULT 0,
        custo_estimado   REAL    DEFAULT 0,
        data_inicio      TEXT    DEFAULT '',
        data_fim         TEXT    DEFAULT '',
        status           TEXT    DEFAULT 'pendente',
        justificativa    TEXT    DEFAULT '',
        observacoes      TEXT    DEFAULT '',
        created_at       TEXT    DEFAULT TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS'),
        updated_at       TEXT    DEFAULT TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS')
    )''')

    cur.execute('''CREATE TABLE IF NOT EXISTS roteirizador_rotas (
        id                SERIAL PRIMARY KEY,
        nome              TEXT    DEFAULT '',
        tipo_rota         TEXT    DEFAULT 'Personalizada',
        origem            TEXT    DEFAULT '',
        origem_lat        REAL    DEFAULT 0,
        origem_lon        REAL    DEFAULT 0,
        destino           TEXT    DEFAULT '',
        destino_lat       REAL    DEFAULT 0,
        destino_lon       REAL    DEFAULT 0,
        paradas           TEXT    DEFAULT '[]',
        postos_rota       TEXT    DEFAULT '[]',
        distancia_km      REAL    DEFAULT 0,
        duracao_min       INTEGER DEFAULT 0,
        combustivel       TEXT    DEFAULT '',
        placa             TEXT    DEFAULT '',
        litros_tanque     REAL    DEFAULT 0,
        capacidade_tanque REAL    DEFAULT 0,
        media_consumo     REAL    DEFAULT 0,
        custo_estimado    REAL    DEFAULT 0,
        filtros           TEXT    DEFAULT '{}',
        geometria         TEXT    DEFAULT '',
        status            TEXT    DEFAULT 'Rascunho',
        observacao        TEXT    DEFAULT '',
        created_at        TEXT    DEFAULT TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS')
    )''')

    # ── Tabela de Clientes ────────────────────────────────────
    cur.execute('''CREATE TABLE IF NOT EXISTS clientes (
        id                    SERIAL PRIMARY KEY,
        cnpj                  TEXT    DEFAULT '',
        razao_social          TEXT    NOT NULL,
        contato               TEXT    DEFAULT '',
        telefone              TEXT    DEFAULT '',
        email                 TEXT    DEFAULT '',
        status                TEXT    DEFAULT 'Ativo',
        grupo_economico       TEXT    DEFAULT '',
        porte_empresa         TEXT    DEFAULT 'Médio',
        qtd_veiculos_pesados  INTEGER DEFAULT 0,
        qtd_veiculos_leves    INTEGER DEFAULT 0,
        segmento_atuacao      TEXT    DEFAULT '',
        volume_diesel         REAL    DEFAULT 0,
        volume_gasolina_alcool REAL   DEFAULT 0,
        pagamento             TEXT    DEFAULT 'Pós-Pago',
        observacoes           TEXT    DEFAULT '',
        created_at            TEXT    DEFAULT TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS'),
        updated_at            TEXT    DEFAULT TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS')
    )''')

    # ── Usuários do sistema ──────────────────────────────────────
    cur.execute('''CREATE TABLE IF NOT EXISTS usuarios (
        id          SERIAL PRIMARY KEY,
        nome        TEXT    NOT NULL,
        cpf         TEXT    NOT NULL DEFAULT '',
        telefone    TEXT    DEFAULT '',
        email       TEXT    DEFAULT '',
        perfil      TEXT    DEFAULT 'Operador',
        status      TEXT    DEFAULT 'Ativo',
        cliente_id  INTEGER DEFAULT NULL,
        observacoes TEXT    DEFAULT '',
        created_at  TEXT    DEFAULT TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS'),
        senha_hash  TEXT    DEFAULT '',
        token_reset TEXT    DEFAULT NULL,
        token_expiry TEXT   DEFAULT NULL,
        perfil_id   INTEGER DEFAULT NULL,
        tipo_acesso TEXT    DEFAULT 'Entrante'
    )''')
    cur.execute("ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS cliente_id INTEGER DEFAULT NULL")
    cur.execute("ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS senha_hash TEXT DEFAULT ''")
    cur.execute("ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS token_reset TEXT DEFAULT NULL")
    cur.execute("ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS token_expiry TEXT DEFAULT NULL")
    cur.execute("ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS perfil_id INTEGER DEFAULT NULL")
    cur.execute("ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS tipo_acesso TEXT DEFAULT 'Entrante'")
    cur.execute("ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS segmento TEXT DEFAULT NULL")
    cur.execute("ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS is_admin BOOLEAN DEFAULT FALSE")
    # Garante que o super-admin sempre tenha is_admin=TRUE
    cur.execute("""
        UPDATE usuarios SET is_admin = TRUE
        WHERE LOWER(email) = 'd.peruffo@yahoo.com'
    """)
    # Remove constraint legada de CPF único (permite usuários sem CPF via login)
    cur.execute("""
        DO $$ BEGIN
            IF EXISTS (
                SELECT 1 FROM pg_constraint
                WHERE conname = 'usuarios_cpf_key'
            ) THEN
                ALTER TABLE usuarios DROP CONSTRAINT usuarios_cpf_key;
            END IF;
        END $$
    """)
    # Índice parcial único de CPF (só para CPFs não-vazios)
    cur.execute("""
        DO $$ BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_indexes
                WHERE indexname = 'usuarios_cpf_unique_partial'
            ) THEN
                CREATE UNIQUE INDEX usuarios_cpf_unique_partial
                ON usuarios (cpf)
                WHERE cpf IS NOT NULL AND cpf <> '';
            END IF;
        END $$
    """)
    # Índice parcial único de email (só para e-mails não-vazios)
    cur.execute("""
        DO $$ BEGIN
            IF NOT EXISTS (
                SELECT 1 FROM pg_indexes
                WHERE indexname = 'usuarios_email_unique_partial'
            ) THEN
                CREATE UNIQUE INDEX usuarios_email_unique_partial
                ON usuarios (LOWER(email))
                WHERE email IS NOT NULL AND email <> '';
            END IF;
        END $$
    """)

    # ── Sessões de autenticação ────────────────────────────────
    cur.execute('''CREATE TABLE IF NOT EXISTS sessoes (
        id          SERIAL PRIMARY KEY,
        usuario_id  INTEGER NOT NULL,
        token       TEXT    NOT NULL UNIQUE,
        expiry      TIMESTAMP NOT NULL,
        created_at  TEXT    DEFAULT TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS')
    )''')

    # ── Perfis de Acesso ─────────────────────────────────────────
    cur.execute('''CREATE TABLE IF NOT EXISTS perfis_acesso (
        id          SERIAL PRIMARY KEY,
        nome        TEXT NOT NULL UNIQUE,
        descricao   TEXT DEFAULT '',
        created_at  TEXT DEFAULT TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS')
    )''')
    cur.execute('''CREATE TABLE IF NOT EXISTS permissoes_perfil (
        id          SERIAL PRIMARY KEY,
        perfil_id   INTEGER NOT NULL,
        modulo      TEXT NOT NULL,
        inclusao    BOOLEAN DEFAULT FALSE,
        consulta    BOOLEAN DEFAULT FALSE,
        edicao      BOOLEAN DEFAULT FALSE,
        exclusao    BOOLEAN DEFAULT FALSE,
        UNIQUE(perfil_id, modulo)
    )''')
    # Seed: perfis de acesso (níveis de permissão — independentes do segmento)
    cur.execute("""
        INSERT INTO perfis_acesso (nome, descricao) VALUES
          ('Gestor',           'Acesso total ao sistema'),
          ('Administrativo',   'Acesso operacional com restrições'),
          ('Operador',         'Somente consulta e inclusão básica'),
          ('Usuário Entrante', 'Acesso somente leitura para novos usuários auto-cadastrados')
        ON CONFLICT (nome) DO NOTHING
    """)
    # Remove perfis "Frota" e "Revenda" que foram criados erroneamente como perfis
    # (são segmentos de negócio, não níveis de acesso)
    cur.execute("""
        DELETE FROM permissoes_perfil WHERE perfil_id IN (
            SELECT id FROM perfis_acesso WHERE nome IN ('Frota','Revenda')
        )
    """)
    cur.execute("DELETE FROM perfis_acesso WHERE nome IN ('Frota','Revenda')")
    # Migração: adiciona coluna segmento em usuarios (Frota / Revenda / Entrante)
    cur.execute("ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS segmento TEXT DEFAULT 'Frota'")
    # Popula segmento a partir de tipo_acesso para registros existentes
    cur.execute("""
        UPDATE usuarios SET segmento = tipo_acesso
        WHERE segmento IS NULL OR segmento = ''
    """)
    # ── Permissões padrão por perfil (IDs alinhados com frontend _PF_MODULOS) ───
    # Formato por módulo: (inclusao, consulta, edicao, exclusao)
    T, F = True, False
    MODULOS_FRONTEND = [
        'indicadores','clientes','veiculos','motoristas','usuarios','perfil-usuario',
        'abastecimentos','postos','negociacoes','parametros','seguranca',
        'roteirizador','rotograma','plano-viagem','custos',
        'precos','varprecos','mapabandeira','volprojetado',
    ]
    # Gestor: acesso total
    PERMS_GESTOR = {m: (T,T,T,T) for m in MODULOS_FRONTEND}
    # Administrativo: CRUD na maioria, sem gestão de usuários/perfis/segurança
    PERMS_ADMIN = {
        'indicadores':    (F,T,F,F),
        'clientes':       (T,T,T,T),
        'veiculos':       (T,T,T,T),
        'motoristas':     (T,T,T,T),
        'usuarios':       (F,T,F,F),
        'perfil-usuario': (F,F,F,F),
        'abastecimentos': (T,T,T,F),
        'postos':         (T,T,T,F),
        'negociacoes':    (F,T,F,F),
        'parametros':     (T,T,T,F),
        'seguranca':      (F,T,F,F),
        'roteirizador':   (F,T,F,F),
        'rotograma':      (F,T,F,F),
        'plano-viagem':   (T,T,T,F),
        'custos':         (T,T,T,F),
        'precos':         (F,T,F,F),
        'varprecos':      (F,T,F,F),
        'mapabandeira':   (F,T,F,F),
        'volprojetado':   (F,T,F,F),
    }
    # Operador: inclusão em abastecimentos, consulta nos demais, sem acesso a admin
    PERMS_OPERADOR = {
        'indicadores':    (F,T,F,F),
        'clientes':       (F,T,F,F),
        'veiculos':       (F,T,F,F),
        'motoristas':     (F,T,F,F),
        'usuarios':       (F,F,F,F),
        'perfil-usuario': (F,F,F,F),
        'abastecimentos': (T,T,F,F),
        'postos':         (F,T,F,F),
        'negociacoes':    (F,F,F,F),
        'parametros':     (F,T,F,F),
        'seguranca':      (F,F,F,F),
        'roteirizador':   (F,T,F,F),
        'rotograma':      (F,T,F,F),
        'plano-viagem':   (F,T,F,F),
        'custos':         (F,T,F,F),
        'precos':         (F,T,F,F),
        'varprecos':      (F,T,F,F),
        'mapabandeira':   (F,T,F,F),
        'volprojetado':   (F,T,F,F),
    }
    # Usuário Entrante: consulta limitada, sem gestão
    PERMS_ENTRANTE = {
        'indicadores':    (F,T,F,F),
        'clientes':       (F,F,F,F),
        'veiculos':       (F,T,F,F),
        'motoristas':     (F,T,F,F),
        'usuarios':       (F,F,F,F),
        'perfil-usuario': (F,F,F,F),
        'abastecimentos': (F,T,F,F),
        'postos':         (F,T,F,F),
        'negociacoes':    (F,F,F,F),
        'parametros':     (F,F,F,F),
        'seguranca':      (F,F,F,F),
        'roteirizador':   (F,T,F,F),
        'rotograma':      (F,T,F,F),
        'plano-viagem':   (F,F,F,F),
        'custos':         (F,F,F,F),
        'precos':         (F,T,F,F),
        'varprecos':      (F,T,F,F),
        'mapabandeira':   (F,T,F,F),
        'volprojetado':   (F,T,F,F),
    }
    PERFIL_SEED_MAP = [
        ('Gestor',           PERMS_GESTOR,   True),   # True = UPSERT (sempre sobrescreve)
        ('Administrativo',   PERMS_ADMIN,    False),  # False = INSERT ONLY (respeita personalizações)
        ('Operador',         PERMS_OPERADOR, False),
        ('Usuário Entrante', PERMS_ENTRANTE, False),
    ]
    pid_gestor = None
    for perfil_nome, perms_map, force_update in PERFIL_SEED_MAP:
        cur.execute("SELECT id FROM perfis_acesso WHERE nome=%s", [perfil_nome])
        row_p = cur.fetchone()
        if not row_p:
            continue
        pid = row_p['id']
        if perfil_nome == 'Gestor':
            pid_gestor = pid
        for mod, (inc, con, edi, exc) in perms_map.items():
            if force_update:
                cur.execute("""
                    INSERT INTO permissoes_perfil
                        (perfil_id, modulo, inclusao, consulta, edicao, exclusao)
                    VALUES (%s,%s,%s,%s,%s,%s)
                    ON CONFLICT (perfil_id, modulo) DO UPDATE SET
                        inclusao=%s, consulta=%s, edicao=%s, exclusao=%s
                """, [pid, mod, inc, con, edi, exc, inc, con, edi, exc])
            else:
                cur.execute("""
                    INSERT INTO permissoes_perfil
                        (perfil_id, modulo, inclusao, consulta, edicao, exclusao)
                    VALUES (%s,%s,%s,%s,%s,%s)
                    ON CONFLICT (perfil_id, modulo) DO NOTHING
                """, [pid, mod, inc, con, edi, exc])
    if pid_gestor is None:
        cur.execute("SELECT id FROM perfis_acesso WHERE nome='Gestor'")
        row_g = cur.fetchone()
        if row_g: pid_gestor = row_g['id']

        # Seed: usuário administrador (senha: Prototipo@2026)
        # Hash = pbkdf2_hmac('sha256', senha, 'gestao_frota_salt_2024', 200000)
        _ADMIN_EMAIL = 'd.peruffo@yahoo.com'
        _ADMIN_HASH  = '44062eeb20fd85b2d10d3a40a750bdd2fe7b8d14fe096e7c333d09951ae23eaa'
        cur.execute("SELECT id FROM usuarios WHERE LOWER(email)=%s",
                    [_ADMIN_EMAIL.lower()])
        admin_row = cur.fetchone()
        if admin_row:
            cur.execute("""
                UPDATE usuarios SET
                    nome='Daniel Peruffo', senha_hash=%s,
                    perfil='Gestor', segmento='Frota', tipo_acesso='Frota', perfil_id=%s,
                    status='Ativo', token_reset=NULL, token_expiry=NULL
                WHERE id=%s
            """, [_ADMIN_HASH, pid_gestor, admin_row['id']])
        else:
            cur.execute("""
                INSERT INTO usuarios
                    (nome, email, cpf, perfil, segmento, tipo_acesso, perfil_id, status, senha_hash)
                VALUES ('Daniel Peruffo',%s,'','Gestor','Frota','Frota',%s,'Ativo',%s)
            """, [_ADMIN_EMAIL, pid_gestor, _ADMIN_HASH])

    # ── Controle de Custos ───────────────────────────────────────
    cur.execute('''CREATE TABLE IF NOT EXISTS centros_custo (
        id            SERIAL PRIMARY KEY,
        codigo        TEXT    DEFAULT '',
        nome          TEXT    NOT NULL,
        descricao     TEXT    DEFAULT '',
        responsavel   TEXT    DEFAULT '',
        cliente_id    INTEGER DEFAULT NULL,
        status        TEXT    DEFAULT 'Ativo',
        criado_em     TEXT    DEFAULT TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS')
    )''')

    cur.execute('''CREATE TABLE IF NOT EXISTS orcamentos_cc (
        id                SERIAL PRIMARY KEY,
        centro_custo_id   INTEGER NOT NULL,
        ano               INTEGER NOT NULL,
        mes               INTEGER NOT NULL,
        categoria         TEXT    NOT NULL,
        valor_orcado      REAL    DEFAULT 0,
        observacoes       TEXT    DEFAULT '',
        cliente_id        INTEGER DEFAULT NULL
    )''')
    cur.execute("ALTER TABLE orcamentos_cc ADD COLUMN IF NOT EXISTS cliente_id INTEGER DEFAULT NULL")

    cur.execute('''CREATE TABLE IF NOT EXISTS lancamentos_cc (
        id                SERIAL PRIMARY KEY,
        centro_custo_id   INTEGER NOT NULL,
        data              TEXT    NOT NULL,
        categoria         TEXT    NOT NULL,
        descricao         TEXT    DEFAULT '',
        valor             REAL    NOT NULL DEFAULT 0,
        tipo              TEXT    DEFAULT 'Despesa',
        referencia_tipo   TEXT    DEFAULT 'Manual',
        referencia_id     INTEGER DEFAULT NULL,
        cliente_id        INTEGER DEFAULT NULL,
        criado_em         TEXT    DEFAULT TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS')
    )''')

    # ── Adiciona cliente_id nas tabelas existentes (idempotente) ──
    _TABLES_WITH_CLIENT = [
        'abastecimentos', 'motoristas', 'veiculos', 'vinculos',
        'intervalos_abastecimento', 'valor_diario_motorista',
        'volume_diario_veiculo', 'produto_abastecido_regras',
        'rotogramas', 'rotograma_execucoes',
        'planos_viagem', 'hodo_variacao',
        'negociacoes', 'roteirizador_rotas',
    ]
    for tbl in _TABLES_WITH_CLIENT:
        cur.execute(f'''
            ALTER TABLE "{tbl}"
            ADD COLUMN IF NOT EXISTS cliente_id INTEGER DEFAULT NULL
        ''')

    # seguranca_regras: chave primária precisa ser (tipo, cliente_id)
    cur.execute('''ALTER TABLE seguranca_regras
        ADD COLUMN IF NOT EXISTS cliente_id INTEGER DEFAULT NULL''')
    # Recria constraint única composta caso ainda não exista
    cur.execute('''
        DO $$ BEGIN
          IF NOT EXISTS (
            SELECT 1 FROM pg_constraint
            WHERE conname = 'seguranca_regras_tipo_cliente_key'
          ) THEN
            BEGIN
              ALTER TABLE seguranca_regras
                DROP CONSTRAINT IF EXISTS seguranca_regras_pkey;
            EXCEPTION WHEN OTHERS THEN NULL;
            END;
            ALTER TABLE seguranca_regras
              ADD CONSTRAINT seguranca_regras_tipo_cliente_key
              UNIQUE (tipo, cliente_id);
          END IF;
        END $$
    ''')

    # centro_custo_id in veiculos, motoristas and planos_viagem
    cur.execute('''ALTER TABLE veiculos
        ADD COLUMN IF NOT EXISTS centro_custo_id INTEGER DEFAULT NULL''')
    cur.execute('''ALTER TABLE motoristas
        ADD COLUMN IF NOT EXISTS centro_custo_id INTEGER DEFAULT NULL''')
    cur.execute('''ALTER TABLE planos_viagem
        ADD COLUMN IF NOT EXISTS centro_custo_id INTEGER DEFAULT NULL''')

    # ── Migração: corrige lançamentos de combustível que usavam valor_total
    #    (combustível + Arla 32 + serviços) em vez de volume × preco_unitario ──
    cur.execute('''
        UPDATE lancamentos_cc lc
        SET valor = ROUND((a.volume * a.preco_unitario)::numeric, 2)
        FROM abastecimentos a
        WHERE lc.referencia_tipo = 'Abastecimento'
          AND lc.referencia_id  = a.id
          AND lc.categoria      = 'Combustível'
          AND lc.descricao      NOT LIKE 'Arla 32%'
    ''')

    conn.commit()
    conn.close()

# ═══════════════════════════════════════════════════════════════
#  SINCRONIZAÇÃO ANP (background thread)
# ═══════════════════════════════════════════════════════════════
_anp_sync_running = False

def _do_anp_sync():
    global _anp_sync_running
    import urllib.request, csv, io, json as _json

    conn = get_db()
    _exec(conn, "INSERT INTO anp_sync_log (status, message) VALUES ('running', 'Iniciando busca na ANP...')")
    conn.commit()
    cur = _cur(conn)
    cur.execute("SELECT MAX(id) FROM anp_sync_log")
    log_id = cur.fetchone()['max']

    def _log(msg, status='running'):
        _exec(conn, "UPDATE anp_sync_log SET message=%s, status=%s WHERE id=%s", [msg, status, log_id])
        conn.commit()

    try:
        ua = {'User-Agent': 'Mozilla/5.0 (compatible; GestaoFrotas/1.0)'}

        api_url = ('https://dados.gov.br/api/3/action/package_show'
                   '?id=serie-historica-de-precos-de-combustiveis-e-de-glp')
        _log('Consultando catálogo dados.gov.br...')
        req = urllib.request.Request(api_url, headers=ua)
        with urllib.request.urlopen(req, timeout=30) as resp:
            pkg = _json.loads(resp.read().decode('utf-8'))

        resources = pkg.get('result', {}).get('resources', [])
        csv_res = sorted(
            [r for r in resources if r.get('format', '').upper() == 'CSV'],
            key=lambda r: r.get('created', ''),
            reverse=True
        )[:6]

        if not csv_res:
            _log('Nenhum CSV encontrado no catálogo ANP.', 'error')
            return

        monthly = {}
        total_rows = 0

        for i, res in enumerate(csv_res):
            csv_url = res.get('url', '')
            if not csv_url:
                continue
            _log(f'Baixando arquivo {i+1}/{len(csv_res)}: {res.get("name","?")}...')
            try:
                req2 = urllib.request.Request(csv_url, headers=ua)
                with urllib.request.urlopen(req2, timeout=180) as resp2:
                    raw = resp2.read()
                for enc in ('utf-8-sig', 'latin-1', 'utf-8'):
                    try:
                        content = raw.decode(enc)
                        break
                    except Exception:
                        continue
            except Exception as e:
                _log(f'Aviso: erro no arquivo {i+1} ({e}), continuando...')
                continue

            try:
                reader = csv.DictReader(io.StringIO(content), delimiter=';')
                for row in reader:
                    try:
                        keys = {k.strip().lower(): v for k, v in row.items()}
                        data_str = (keys.get('data da coleta') or keys.get('data') or '').strip()
                        produto   = (keys.get('produto') or '').strip().upper()
                        p_rev_str = (keys.get('preço médio revenda')
                                     or keys.get('preco medio revenda')
                                     or keys.get('pre\u00e7o m\u00e9dio revenda')
                                     or '').strip().replace(',', '.')
                        p_dis_str = (keys.get('preço médio distribuição')
                                     or keys.get('preco medio distribuicao')
                                     or keys.get('pre\u00e7o m\u00e9dio distribui\u00e7\u00e3o')
                                     or '').strip().replace(',', '.')
                        if not data_str or not produto or not p_rev_str:
                            continue
                        parts = data_str.split('/')
                        if len(parts) != 3:
                            continue
                        mes = f'{parts[2].strip()}-{parts[1].strip()}'
                        if not any(p in produto for p in
                                   ['GASOLINA', 'ETANOL', 'DIESEL', 'GNV']):
                            continue
                        p_rev  = float(p_rev_str)
                        p_dist = float(p_dis_str) if p_dis_str else 0.0
                        key = (mes, produto)
                        if key not in monthly:
                            monthly[key] = {'soma_rev': 0.0, 'soma_dist': 0.0, 'n': 0}
                        monthly[key]['soma_rev']  += p_rev
                        monthly[key]['soma_dist'] += p_dist
                        monthly[key]['n']         += 1
                        total_rows += 1
                    except (ValueError, KeyError):
                        continue
            except Exception as e:
                _log(f'Aviso: erro ao parsear arquivo {i+1} ({e}), continuando...')
                continue

        if not monthly:
            _log('Nenhum dado processado. Verifique o formato dos arquivos ANP.', 'error')
            return

        _log(f'Gravando {len(monthly)} registros mensais no banco...')
        for (mes, produto), v in monthly.items():
            n = v['n'] or 1
            _exec(conn, '''
                INSERT INTO precos_anp (mes, produto, preco_medio_revenda, preco_medio_distrib, num_postos, updated_at)
                VALUES (%s, %s, %s, %s, %s, TO_CHAR(NOW(), 'YYYY-MM-DD HH24:MI:SS'))
                ON CONFLICT (mes, produto) DO UPDATE SET
                    preco_medio_revenda = EXCLUDED.preco_medio_revenda,
                    preco_medio_distrib = EXCLUDED.preco_medio_distrib,
                    num_postos          = EXCLUDED.num_postos,
                    updated_at          = EXCLUDED.updated_at
            ''', (mes, produto, round(v['soma_rev'] / n, 4), round(v['soma_dist'] / n, 4), n))
        conn.commit()

        _log(f'Concluído: {len(monthly)} meses/produtos atualizados '
             f'({total_rows:,} leituras processadas).', 'done')
    except Exception as e:
        _log(f'Erro inesperado: {e}', 'error')
    finally:
        _exec(conn, "UPDATE anp_sync_log SET ended_at=TO_CHAR(NOW(),'YYYY-MM-DD HH24:MI:SS') WHERE id=%s", [log_id])
        conn.commit()
        conn.close()
        _anp_sync_running = False

# ═══════════════════════════════════════════════════════════════
#  SERVIDOR HTTP
# ═══════════════════════════════════════════════════════════════
class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print(f'  [{self.command}] {self.path}')

    def cors(self):
        self.send_header('Access-Control-Allow-Origin',  '*')
        self.send_header('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE,OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type,Authorization')

    def send_json(self, data, status=200):
        body = json.dumps(data, ensure_ascii=False, default=str).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', len(body))
        self.cors()
        self.end_headers()
        self.wfile.write(body)

    def send_html(self):
        try:
            with open(HTML_FILE, 'rb') as f:
                body = f.read()
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Content-Length', len(body))
            self.end_headers()
            self.wfile.write(body)
        except FileNotFoundError:
            self.send_json({'error': 'HTML file not found'}, 404)

    def read_body(self):
        length = int(self.headers.get('Content-Length', 0))
        return json.loads(self.rfile.read(length).decode('utf-8')) if length else {}

    def do_OPTIONS(self):
        self.send_response(200)
        self.cors()
        self.end_headers()

    # ──────────────────────────────────────────────────────────
    #  GET
    # ──────────────────────────────────────────────────────────
    def do_GET(self):
        path = urlparse(self.path).path

        # ── Auth: dados do usuário logado ──────────────────────
        # ── Ping / health check (sem autenticação) ────────────────
        if path == '/api/ping':
            self.send_json({'ok': True, 'server': 'gestao-frota'}); return

        if path == '/api/auth/me':
            conn = get_db()
            usr = _auth_get_user(conn, _token_from_request(self))
            conn.close()
            if not usr:
                self.send_json({'error': 'Não autenticado'}, 401); return
            self.send_json(usr); return

        if path in ('/', '/index.html'):
            self.send_html()

        elif path == '/postos-data.json':
            json_path = os.path.join(BASE_DIR, 'postos-data.json')
            try:
                with open(json_path, 'rb') as f:
                    data = f.read()
                self.send_response(200)
                self.send_header('Content-Type', 'application/json; charset=utf-8')
                self.send_header('Content-Length', str(len(data)))
                self.send_header('Access-Control-Allow-Origin', '*')
                self.end_headers()
                self.wfile.write(data)
            except FileNotFoundError:
                self.send_json({'error': 'postos-data.json not found'}, 404)

        elif path == '/api/clientes':
            qs  = parse_qs(urlparse(self.path).query)
            status_f  = qs.get('status',  [None])[0]
            busca_f   = qs.get('busca',   [None])[0]
            segmento_f= qs.get('segmento',[None])[0]
            porte_f   = qs.get('porte',   [None])[0]
            where, params = [], []
            if status_f:   where.append('status = %s');            params.append(status_f)
            if segmento_f: where.append('segmento_atuacao = %s'); params.append(segmento_f)
            if porte_f:    where.append('porte_empresa = %s');     params.append(porte_f)
            if busca_f:
                where.append("(razao_social ILIKE %s OR cnpj ILIKE %s OR contato ILIKE %s)")
                like = f'%{busca_f}%'
                params += [like, like, like]
            sql = 'SELECT * FROM clientes'
            if where: sql += ' WHERE ' + ' AND '.join(where)
            sql += ' ORDER BY razao_social'
            conn = get_db()
            rows = _fetchall(conn, sql, params)
            conn.close()
            self.send_json(rows)

        elif re.match(r'^/api/clientes/(\d+)$', path):
            cid  = int(re.match(r'^/api/clientes/(\d+)$', path).group(1))
            conn = get_db()
            row  = _fetchone(conn, 'SELECT * FROM clientes WHERE id=%s', [cid])
            conn.close()
            self.send_json(row if row else {})

        elif path == '/api/usuarios/stats':
            # Dashboard de segmentos × perfis com contagem de usuários
            conn = get_db()
            rows = _fetchall(conn, '''
                SELECT
                    COALESCE(segmento, tipo_acesso, 'Frota') AS segmento,
                    COALESCE(u.perfil, pa.nome, 'Operador')  AS perfil,
                    COUNT(*) AS total
                FROM usuarios u
                LEFT JOIN perfis_acesso pa ON pa.id = u.perfil_id
                WHERE u.status = 'Ativo'
                GROUP BY 1, 2
                ORDER BY 1, 2
            ''', [])
            # totais por segmento
            totais = _fetchall(conn, '''
                SELECT
                    COALESCE(segmento, tipo_acesso, 'Frota') AS segmento,
                    COUNT(*) AS total
                FROM usuarios
                WHERE status = 'Ativo'
                GROUP BY 1
            ''', [])
            total_geral = _fetchone(conn,
                "SELECT COUNT(*) AS total FROM usuarios WHERE status='Ativo'", [])
            conn.close()
            self.send_json({
                'breakdown': rows,
                'totais':    totais,
                'total':     total_geral['total'] if total_geral else 0,
            }); return

        elif path == '/api/usuarios':
            qs       = parse_qs(urlparse(self.path).query)
            status_f = qs.get('status', [None])[0]
            perfil_f = qs.get('perfil', [None])[0]
            busca_f  = qs.get('busca',  [None])[0]
            where, params = [], []
            if status_f: where.append('status=%s'); params.append(status_f)
            if perfil_f: where.append('perfil=%s'); params.append(perfil_f)
            if busca_f:
                where.append("(nome ILIKE %s OR cpf ILIKE %s OR email ILIKE %s)")
                like = f'%{busca_f}%'; params += [like, like, like]
            sql = 'SELECT * FROM usuarios'
            if where: sql += ' WHERE ' + ' AND '.join(where)
            sql += ' ORDER BY nome'
            conn = get_db()
            rows = _fetchall(conn, sql, params)
            conn.close()
            self.send_json(rows)

        elif path == '/api/perfis-acesso':
            conn = get_db()
            rows = _fetchall(conn, 'SELECT * FROM perfis_acesso ORDER BY nome', [])
            conn.close()
            self.send_json(rows)

        elif re.match(r'^/api/perfis-acesso/(\d+)/permissoes$', path):
            m = re.match(r'^/api/perfis-acesso/(\d+)/permissoes$', path)
            conn = get_db()
            rows = _fetchall(conn, 'SELECT * FROM permissoes_perfil WHERE perfil_id=%s', [int(m.group(1))])
            conn.close()
            self.send_json(rows)

        elif path == '/api/abastecimentos':
            qs  = parse_qs(urlparse(self.path).query)
            cid = qs.get('cliente_id', [None])[0]
            conn  = get_db()
            if cid:
                rows = _fetchall(conn, 'SELECT * FROM abastecimentos WHERE cliente_id=%s ORDER BY data DESC, hora DESC', [int(cid)])
            else:
                rows = _fetchall(conn, 'SELECT * FROM abastecimentos ORDER BY data DESC, hora DESC')
            conn.close()
            for d in rows:
                svcs = d.get('servicos_abast') or '[]'
                try:    d['servicos_abast'] = json.loads(svcs)
                except: d['servicos_abast'] = []
            self.send_json(rows)

        elif path == '/api/postos':
            conn = get_db()
            rows = _fetchall(conn, 'SELECT * FROM postos ORDER BY razao')
            conn.close()
            result = []
            for d in rows:
                d['servicos'] = json.loads(d.get('servicos') or '[]')
                d['fotos']    = json.loads(d.get('fotos')    or '[]')
                raw_combs = json.loads(d.get('combustiveis') or '{}')
                combs_norm = {}
                for k, v in raw_combs.items():
                    combs_norm[k] = v if isinstance(v, dict) else {'preco': v}
                d['combustiveis'] = combs_norm
                result.append(d)
            self.send_json(result)

        elif path == '/api/motoristas':
            qs  = parse_qs(urlparse(self.path).query)
            cid = qs.get('cliente_id', [None])[0]
            conn = get_db()
            if cid:
                rows = _fetchall(conn, 'SELECT * FROM motoristas WHERE cliente_id=%s ORDER BY nome', [int(cid)])
            else:
                rows = _fetchall(conn, 'SELECT * FROM motoristas ORDER BY nome')
            conn.close()
            self.send_json(rows)

        elif path == '/api/veiculos':
            qs  = parse_qs(urlparse(self.path).query)
            cid = qs.get('cliente_id', [None])[0]
            conn = get_db()
            if cid:
                rows = _fetchall(conn, 'SELECT * FROM veiculos WHERE cliente_id=%s ORDER BY placa', [int(cid)])
            else:
                rows = _fetchall(conn, 'SELECT * FROM veiculos ORDER BY placa')
            conn.close()
            self.send_json(rows)

        elif path == '/api/vinculos':
            qs  = parse_qs(urlparse(self.path).query)
            cid = qs.get('cliente_id', [None])[0]
            conn = get_db()
            if cid:
                rows = _fetchall(conn, 'SELECT * FROM vinculos WHERE cliente_id=%s ORDER BY data_inicio DESC', [int(cid)])
            else:
                rows = _fetchall(conn, 'SELECT * FROM vinculos ORDER BY data_inicio DESC')
            conn.close()
            self.send_json(rows)

        elif path == '/api/intervalos':
            qs  = parse_qs(urlparse(self.path).query)
            cid = qs.get('cliente_id', [None])[0]
            conn = get_db()
            if cid:
                rows = _fetchall(conn, 'SELECT * FROM intervalos_abastecimento WHERE cliente_id=%s ORDER BY tipo, referencia', [int(cid)])
            else:
                rows = _fetchall(conn, 'SELECT * FROM intervalos_abastecimento ORDER BY tipo, referencia')
            conn.close()
            self.send_json(rows)

        elif path == '/api/valor-diario':
            qs  = parse_qs(urlparse(self.path).query)
            cid = qs.get('cliente_id', [None])[0]
            conn = get_db()
            if cid:
                rows = _fetchall(conn, 'SELECT * FROM valor_diario_motorista WHERE cliente_id=%s ORDER BY motorista', [int(cid)])
            else:
                rows = _fetchall(conn, 'SELECT * FROM valor_diario_motorista ORDER BY motorista')
            conn.close()
            self.send_json(rows)

        elif path == '/api/volume-diario':
            qs  = parse_qs(urlparse(self.path).query)
            cid = qs.get('cliente_id', [None])[0]
            conn = get_db()
            if cid:
                rows = _fetchall(conn, 'SELECT * FROM volume_diario_veiculo WHERE cliente_id=%s ORDER BY placa', [int(cid)])
            else:
                rows = _fetchall(conn, 'SELECT * FROM volume_diario_veiculo ORDER BY placa')
            conn.close()
            self.send_json(rows)

        elif path == '/api/produto-abastecido':
            qs  = parse_qs(urlparse(self.path).query)
            cid = qs.get('cliente_id', [None])[0]
            conn = get_db()
            if cid:
                rows = _fetchall(conn, 'SELECT * FROM produto_abastecido_regras WHERE cliente_id=%s ORDER BY id', [int(cid)])
            else:
                rows = _fetchall(conn, 'SELECT * FROM produto_abastecido_regras ORDER BY id')
            conn.close()
            self.send_json(rows)

        elif path == '/api/seguranca-regras':
            qs   = parse_qs(urlparse(self.path).query)
            cid  = qs.get('cliente_id', [None])[0]
            todos = qs.get('todos', [None])[0]
            conn = get_db()
            if todos:
                rows = _fetchall(conn, 'SELECT * FROM seguranca_regras ORDER BY cliente_id NULLS FIRST, tipo')
            elif cid:
                rows = _fetchall(conn, 'SELECT * FROM seguranca_regras WHERE cliente_id=%s', [int(cid)])
            else:
                rows = _fetchall(conn, 'SELECT * FROM seguranca_regras WHERE cliente_id IS NULL')
            conn.close()
            self.send_json(rows)

        elif path == '/api/precos-anp':
            qs = parse_qs(urlparse(self.path).query)
            produto = qs.get('produto', [None])[0]
            start   = qs.get('start',   [None])[0]
            end     = qs.get('end',     [None])[0]
            where, params = [], []
            if produto:
                where.append('produto = %s'); params.append(produto.upper())
            if start:
                where.append('mes >= %s');    params.append(start[:7])
            if end:
                where.append('mes <= %s');    params.append(end[:7])
            sql = 'SELECT * FROM precos_anp'
            if where:
                sql += ' WHERE ' + ' AND '.join(where)
            sql += ' ORDER BY mes, produto'
            conn = get_db()
            rows = _fetchall(conn, sql, params)
            conn.close()
            self.send_json(rows)

        elif path == '/api/precos-anp/status':
            conn = get_db()
            row  = _fetchone(conn, 'SELECT * FROM anp_sync_log ORDER BY id DESC LIMIT 1')
            conn.close()
            self.send_json(row if row else {'status': 'idle', 'message': ''})

        elif path == '/api/rotogramas':
            qs  = parse_qs(urlparse(self.path).query)
            cid = qs.get('cliente_id', [None])[0]
            conn = get_db()
            if cid:
                rows = _fetchall(conn, 'SELECT * FROM rotogramas WHERE cliente_id=%s ORDER BY nome', [int(cid)])
            else:
                rows = _fetchall(conn, 'SELECT * FROM rotogramas ORDER BY nome')
            conn.close()
            self.send_json(rows)

        elif re.match(r'^/api/rotogramas/(\d+)$', path):
            rid  = int(re.match(r'^/api/rotogramas/(\d+)$', path).group(1))
            conn = get_db()
            row  = _fetchone(conn, 'SELECT * FROM rotogramas WHERE id=%s', [rid])
            conn.close()
            self.send_json(row if row else {})

        elif re.match(r'^/api/rotograma-trechos/(\d+)$', path):
            rid  = int(re.match(r'^/api/rotograma-trechos/(\d+)$', path).group(1))
            conn = get_db()
            rows = _fetchall(conn, 'SELECT * FROM rotograma_trechos WHERE rotograma_id=%s ORDER BY ordem, id', [rid])
            conn.close()
            self.send_json(rows)

        elif re.match(r'^/api/rotograma-pontos-criticos/(\d+)$', path):
            rid  = int(re.match(r'^/api/rotograma-pontos-criticos/(\d+)$', path).group(1))
            conn = get_db()
            rows = _fetchall(conn, 'SELECT * FROM rotograma_pontos_criticos WHERE rotograma_id=%s ORDER BY nivel_risco DESC, id', [rid])
            conn.close()
            self.send_json(rows)

        elif re.match(r'^/api/rotograma-pontos-apoio/(\d+)$', path):
            rid  = int(re.match(r'^/api/rotograma-pontos-apoio/(\d+)$', path).group(1))
            conn = get_db()
            rows = _fetchall(conn, 'SELECT * FROM rotograma_pontos_apoio WHERE rotograma_id=%s ORDER BY tipo, km_referencia', [rid])
            conn.close()
            self.send_json(rows)

        elif re.match(r'^/api/rotograma-execucoes/(\d+)$', path):
            rid  = int(re.match(r'^/api/rotograma-execucoes/(\d+)$', path).group(1))
            conn = get_db()
            rows = _fetchall(conn, 'SELECT * FROM rotograma_execucoes WHERE rotograma_id=%s ORDER BY data DESC, id DESC', [rid])
            conn.close()
            self.send_json(rows)

        elif path == '/api/planos-viagem':
            qs  = parse_qs(urlparse(self.path).query)
            cid = qs.get('cliente_id', [None])[0]
            conn = get_db()
            if cid:
                rows = _fetchall(conn, '''
                    SELECT p.*, r.nome AS rotograma_nome
                    FROM planos_viagem p
                    LEFT JOIN rotogramas r ON r.id = p.rotograma_id
                    WHERE p.cliente_id=%s
                    ORDER BY p.data_saida DESC, p.id DESC
                ''', [int(cid)])
            else:
                rows = _fetchall(conn, '''
                SELECT p.*, r.nome AS rotograma_nome
                FROM planos_viagem p
                LEFT JOIN rotogramas r ON r.id = p.rotograma_id
                ORDER BY p.data_saida DESC, p.id DESC
            ''')
            conn.close()
            self.send_json(rows)

        elif re.match(r'^/api/planos-viagem/(\d+)$', path):
            pid  = int(re.match(r'^/api/planos-viagem/(\d+)$', path).group(1))
            conn = get_db()
            row  = _fetchone(conn, '''
                SELECT p.*, r.nome AS rotograma_nome
                FROM planos_viagem p
                LEFT JOIN rotogramas r ON r.id = p.rotograma_id
                WHERE p.id=%s
            ''', [pid])
            conn.close()
            self.send_json(row if row else {})

        elif re.match(r'^/api/planos-viagem-pedagios/(\d+)$', path):
            pid  = int(re.match(r'^/api/planos-viagem-pedagios/(\d+)$', path).group(1))
            conn = get_db()
            rows = _fetchall(conn, 'SELECT * FROM planos_viagem_pedagios WHERE plano_id=%s ORDER BY id', [pid])
            conn.close()
            self.send_json(rows)

        elif path == '/api/hodo-variacao':
            qs   = parse_qs(urlparse(self.path).query)
            tipo = qs.get('tipo', [None])[0]
            cid  = qs.get('cliente_id', [None])[0]
            conn = get_db()
            where, params = [], []
            if tipo: where.append('tipo_veiculo=%s'); params.append(tipo)
            if cid:  where.append('cliente_id=%s');  params.append(int(cid))
            sql = 'SELECT * FROM hodo_variacao'
            if where: sql += ' WHERE ' + ' AND '.join(where)
            sql += ' ORDER BY tipo_veiculo, placa'
            rows = _fetchall(conn, sql, params)
            conn.close()
            self.send_json(rows)

        elif path == '/api/negociacoes':
            qs  = parse_qs(urlparse(self.path).query)
            cid = qs.get('cliente_id', [None])[0]
            conn = get_db()
            if cid:
                rows = _fetchall(conn, 'SELECT * FROM negociacoes WHERE cliente_id=%s ORDER BY created_at DESC', [int(cid)])
            else:
                rows = _fetchall(conn, 'SELECT * FROM negociacoes ORDER BY created_at DESC')
            conn.close()
            today = __import__('datetime').date.today().isoformat()
            result = []
            for d in rows:
                if d['status'] not in ('cancelada',) and d['data_fim'] and d['data_fim'] < today:
                    d['status'] = 'expirada'
                elif d['status'] not in ('cancelada', 'expirada') and d['data_inicio'] and d['data_inicio'] > today:
                    d['status'] = 'pendente'
                elif d['status'] not in ('cancelada', 'expirada', 'pendente'):
                    d['status'] = 'ativa'
                result.append(d)
            self.send_json(result)

        elif path == '/api/roteirizador-rotas':
            qs  = parse_qs(urlparse(self.path).query)
            cid = qs.get('cliente_id', [None])[0]
            conn = get_db()
            if cid:
                rows = _fetchall(conn, 'SELECT * FROM roteirizador_rotas WHERE cliente_id=%s ORDER BY created_at DESC', [int(cid)])
            else:
                rows = _fetchall(conn, 'SELECT * FROM roteirizador_rotas ORDER BY created_at DESC')
            conn.close()
            self.send_json(rows)

        elif path == '/api/planos-viagem-kpis':
            conn  = get_db()
            kpis  = {}
            kpis['total_planos']  = (_fetchone(conn, 'SELECT COUNT(*) AS c FROM planos_viagem') or {}).get('c', 0)
            kpis['total_budget']  = (_fetchone(conn, 'SELECT COALESCE(SUM(custo_total_estimado),0) AS s FROM planos_viagem') or {}).get('s', 0)
            kpis['media_custo_km']= (_fetchone(conn, "SELECT CASE WHEN SUM(km_estimado)>0 THEN SUM(custo_total_estimado)/SUM(km_estimado) ELSE 0 END AS v FROM planos_viagem WHERE km_estimado>0") or {}).get('v', 0)
            kpis['por_status']    = _fetchall(conn, "SELECT status, COUNT(*) AS qtd, COALESCE(SUM(custo_total_estimado),0) AS total FROM planos_viagem GROUP BY status")
            kpis['por_veiculo']   = _fetchall(conn, "SELECT placa, COUNT(*) AS qtd, COALESCE(SUM(custo_total_estimado),0) AS total, COALESCE(SUM(km_estimado),0) AS km FROM planos_viagem WHERE placa!='' GROUP BY placa ORDER BY total DESC LIMIT 10")
            kpis['por_categoria'] = _fetchall(conn, "SELECT COALESCE(SUM(custo_combustivel),0) AS combustivel, COALESCE(SUM(custo_pedagio),0) AS pedagio, COALESCE(SUM(custo_diarias),0) AS diarias, COALESCE(SUM(custo_manutencao),0) AS manutencao FROM planos_viagem")
            conn.close()
            self.send_json(kpis)

        elif path == '/api/centros-custo':
            qs  = parse_qs(urlparse(self.path).query)
            cid = qs.get('cliente_id', [None])[0]
            conn = get_db()
            if cid:
                rows = _fetchall(conn, 'SELECT * FROM centros_custo WHERE cliente_id=%s ORDER BY nome', [int(cid)])
            else:
                rows = _fetchall(conn, 'SELECT * FROM centros_custo ORDER BY nome')
            conn.close()
            self.send_json(rows)

        elif path == '/api/orcamentos-cc':
            qs  = parse_qs(urlparse(self.path).query)
            cc  = qs.get('centro_custo_id', [None])[0]
            ano = qs.get('ano', [None])[0]
            mes = qs.get('mes', [None])[0]
            where, params = [], []
            if cc:  where.append('centro_custo_id=%s'); params.append(int(cc))
            if ano: where.append('ano=%s');             params.append(int(ano))
            if mes: where.append('mes=%s');             params.append(int(mes))
            sql = 'SELECT * FROM orcamentos_cc'
            if where: sql += ' WHERE ' + ' AND '.join(where)
            sql += ' ORDER BY ano DESC, mes DESC, categoria'
            conn = get_db()
            rows = _fetchall(conn, sql, params)
            conn.close()
            self.send_json(rows)

        elif path == '/api/lancamentos-cc':
            qs    = parse_qs(urlparse(self.path).query)
            cc    = qs.get('centro_custo_id', [None])[0]
            ano   = qs.get('ano',   [None])[0]
            mes   = qs.get('mes',   [None])[0]
            categ = qs.get('categoria', [None])[0]
            tipo  = qs.get('tipo',  [None])[0]
            cid   = qs.get('cliente_id', [None])[0]
            where, params = [], []
            if cc:    where.append('centro_custo_id=%s'); params.append(int(cc))
            if cid:   where.append('cliente_id=%s');      params.append(int(cid))
            if ano:   where.append("EXTRACT(YEAR FROM data::date)=%s");  params.append(int(ano))
            if mes:   where.append("EXTRACT(MONTH FROM data::date)=%s"); params.append(int(mes))
            if categ: where.append('categoria=%s');       params.append(categ)
            if tipo:  where.append('tipo=%s');            params.append(tipo)
            sql = 'SELECT * FROM lancamentos_cc'
            if where: sql += ' WHERE ' + ' AND '.join(where)
            sql += ' ORDER BY data DESC, id DESC'
            conn = get_db()
            rows = _fetchall(conn, sql, params)
            conn.close()
            self.send_json(rows)

        elif path == '/api/status':
            self.send_json({'ok': True, 'db': f'postgresql://{DB_HOST}:{DB_PORT}/{DB_NAME}'})

        else:
            self.send_json({'error': 'Not found'}, 404)

    # ──────────────────────────────────────────────────────────
    #  POST
    # ──────────────────────────────────────────────────────────
    def do_POST(self):
        path = urlparse(self.path).path
        d    = self.read_body()

        # ══════════════════════════════════════════════════════
        #  AUTENTICAÇÃO
        # ══════════════════════════════════════════════════════

        # ── Login ─────────────────────────────────────────────
        if path == '/api/auth/login':
            email = (d.get('email') or '').strip().lower()
            senha = d.get('senha') or ''
            if not email or not senha:
                self.send_json({'error': 'E-mail e senha obrigatórios'}, 400); return
            conn = get_db()
            usr = _fetchone(conn,
                "SELECT * FROM usuarios WHERE LOWER(email)=%s AND status='Ativo'", [email])
            if not usr or usr.get('senha_hash','') != _hash_senha(senha):
                conn.close()
                self.send_json({'error': 'E-mail ou senha inválidos'}, 401); return
            # Cria sessão (24h)
            token  = _gen_token()
            expiry = datetime.utcnow() + timedelta(hours=24)
            _exec(conn, "INSERT INTO sessoes (usuario_id,token,expiry) VALUES (%s,%s,%s)",
                  [usr['id'], token, expiry])
            conn.commit()
            # Carrega permissões
            perms = _fetchall(conn, "SELECT * FROM permissoes_perfil WHERE perfil_id=%s",
                              [usr.get('perfil_id')]) if usr.get('perfil_id') else []
            perfil = _fetchone(conn, "SELECT nome FROM perfis_acesso WHERE id=%s",
                               [usr.get('perfil_id')]) if usr.get('perfil_id') else None
            conn.close()
            self.send_json({
                'token': token,
                'usuario': {
                    'id':          usr['id'],
                    'nome':        usr['nome'],
                    'email':       usr['email'],
                    'tipo_acesso': usr.get('tipo_acesso','Entrante'),
                    'segmento':    usr.get('segmento', usr.get('tipo_acesso','Frota')),
                    'perfil_id':   usr.get('perfil_id'),
                    'perfil_nome': perfil['nome'] if perfil else usr.get('perfil',''),
                    'cliente_id':  usr.get('cliente_id'),
                    'is_admin':    bool(usr.get('is_admin', False)),
                },
                'permissoes': perms,
            }); return

        # ── Logout ────────────────────────────────────────────
        if path == '/api/auth/logout':
            token = _token_from_request(self)
            if token:
                conn = get_db()
                _exec(conn, "DELETE FROM sessoes WHERE token=%s", [token])
                conn.commit()
                conn.close()
            self.send_json({'ok': True}); return

        # ── Cadastro (auto-registro) ───────────────────────────
        if path == '/api/auth/register':
            nome  = (d.get('nome')  or '').strip()
            email = (d.get('email') or '').strip().lower()
            if not nome or not email:
                self.send_json({'error': 'Nome e e-mail obrigatórios'}, 400); return
            conn = get_db()
            # Verifica se e-mail já existe
            existing = _fetchone(conn, "SELECT id FROM usuarios WHERE LOWER(email)=%s", [email])
            if existing:
                conn.close()
                self.send_json({'error': 'E-mail já cadastrado'}, 409); return
            # Busca perfil "Usuário Entrante"
            perfil_e = _fetchone(conn, "SELECT id FROM perfis_acesso WHERE nome='Usuário Entrante'")
            pid = perfil_e['id'] if perfil_e else None
            # Gera token de definição de senha (24h)
            tok  = _gen_token()
            exp  = (datetime.utcnow() + timedelta(hours=24)).strftime('%Y-%m-%d %H:%M:%S')
            cur = _exec(conn, """
                INSERT INTO usuarios (nome, email, cpf, perfil, segmento, tipo_acesso, perfil_id, status,
                                      token_reset, token_expiry)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) RETURNING id
            """, [nome, email, '', 'Usuário Entrante', 'Entrante', 'Entrante', pid, 'Ativo', tok, exp])
            conn.commit()
            new_id = cur.fetchone()['id']
            conn.close()
            link = f"{APP_URL}/?reset_token={tok}"
            _send_email(email, 'Bem-vindo! Defina sua senha de acesso',
                f"""<h2>Olá, {nome}!</h2>
                <p>Seu cadastro foi criado. Clique no link abaixo para definir sua senha:</p>
                <p><a href="{link}">{link}</a></p>
                <p>Este link expira em 24 horas.</p>""")
            self.send_json({'ok': True, 'id': new_id}); return

        # ── Definir / Redefinir senha (via token) ─────────────
        if path == '/api/auth/set-password':
            tok   = (d.get('token') or '').strip()
            senha = d.get('senha') or ''
            if not tok or len(senha) < 6:
                self.send_json({'error': 'Token inválido ou senha muito curta (mín. 6 chars)'}, 400); return
            conn = get_db()
            usr = _fetchone(conn,
                "SELECT * FROM usuarios WHERE token_reset=%s AND token_expiry > NOW()", [tok])
            if not usr:
                conn.close()
                self.send_json({'error': 'Token inválido ou expirado'}, 401); return
            _exec(conn, """
                UPDATE usuarios SET senha_hash=%s, token_reset=NULL, token_expiry=NULL
                WHERE id=%s
            """, [_hash_senha(senha), usr['id']])
            conn.commit()
            conn.close()
            self.send_json({'ok': True}); return

        # ── Reenviar link de definição de senha ───────────────
        if path == '/api/auth/resend-token':
            email = (d.get('email') or '').strip().lower()
            if not email:
                self.send_json({'error': 'E-mail obrigatório'}, 400); return
            conn = get_db()
            usr = _fetchone(conn, "SELECT * FROM usuarios WHERE LOWER(email)=%s AND status='Ativo'", [email])
            if not usr:
                conn.close()
                self.send_json({'ok': True}); return  # silencia: não revela existência
            tok = _gen_token()
            exp = (datetime.utcnow() + timedelta(hours=24)).strftime('%Y-%m-%d %H:%M:%S')
            _exec(conn, "UPDATE usuarios SET token_reset=%s, token_expiry=%s WHERE id=%s",
                  [tok, exp, usr['id']])
            conn.commit()
            conn.close()
            link = f"{APP_URL}/?reset_token={tok}"
            _send_email(email, 'Redefinição de senha – Gestão de Frota',
                f"""<h2>Olá, {usr['nome']}!</h2>
                <p>Solicitamos a redefinição da sua senha. Acesse o link:</p>
                <p><a href="{link}">{link}</a></p>
                <p>Este link expira em 24 horas. Se não foi você, ignore este e-mail.</p>""")
            self.send_json({'ok': True}); return

        # ══════════════════════════════════════════════════════

        if path == '/api/clientes':
            conn = get_db()
            cur  = _exec(conn, '''INSERT INTO clientes
                (cnpj,razao_social,contato,telefone,email,status,grupo_economico,
                 porte_empresa,qtd_veiculos_pesados,qtd_veiculos_leves,
                 segmento_atuacao,volume_diesel,volume_gasolina_alcool,pagamento,observacoes)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                RETURNING id''', [
                d.get('cnpj',''),           d.get('razaoSocial',''),
                d.get('contato',''),        d.get('telefone',''),
                d.get('email',''),          d.get('status','Ativo'),
                d.get('grupoEconomico',''), d.get('porteEmpresa','Médio'),
                d.get('qtdVeiculosPesados',0), d.get('qtdVeiculosLeves',0),
                d.get('segmentoAtuacao',''),d.get('volumeDiesel',0),
                d.get('volumeGasolinaAlcool',0), d.get('pagamento','Pós-Pago'),
                d.get('observacoes',''),
            ])
            conn.commit()
            new_id = cur.fetchone()['id']
            conn.close()
            self.send_json({'id': new_id}); return

        if path == '/api/usuarios':
            conn = get_db()
            try:
                cli_id    = d.get('cliente_id') or None
                if cli_id: cli_id = int(cli_id)
                perfil_id = d.get('perfil_id') or None
                if perfil_id: perfil_id = int(perfil_id)
                seg = d.get('segmento','Frota')
                cur = _exec(conn, '''INSERT INTO usuarios
                    (nome,cpf,telefone,email,perfil,segmento,tipo_acesso,perfil_id,status,cliente_id,observacoes)
                    VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) RETURNING id''', [
                    d.get('nome',''), d.get('cpf',''),
                    d.get('telefone',''), d.get('email',''),
                    d.get('perfil','Operador'),
                    seg, seg,          # segmento e tipo_acesso em sincronia
                    perfil_id,
                    d.get('status','Ativo'),
                    cli_id, d.get('observacoes',''),
                ])
                conn.commit()
                new_id = cur.fetchone()['id']
                conn.close()
                self.send_json({'id': new_id}, 201); return
            except Exception as e:
                conn.rollback(); conn.close()
                self.send_json({'error': str(e)}, 409); return

        if path == '/api/perfis-acesso':
            conn = get_db()
            try:
                cur = _exec(conn, '''INSERT INTO perfis_acesso (nome, descricao)
                    VALUES (%s,%s) RETURNING id''', [
                    d.get('nome',''), d.get('descricao','')
                ])
                conn.commit()
                new_id = cur.fetchone()['id']
                conn.close()
                self.send_json({'id': new_id}, 201); return
            except Exception as e:
                conn.rollback(); conn.close()
                self.send_json({'error': str(e)}, 409); return

        if path == '/api/permissoes-perfil':
            # Upsert em lote: body = {perfil_id, permissoes: [{modulo, inclusao, consulta, edicao, exclusao}]}
            conn = get_db()
            try:
                pid = int(d.get('perfil_id'))
                perms = d.get('permissoes', [])
                for p in perms:
                    _exec(conn, '''INSERT INTO permissoes_perfil
                        (perfil_id, modulo, inclusao, consulta, edicao, exclusao)
                        VALUES (%s,%s,%s,%s,%s,%s)
                        ON CONFLICT (perfil_id, modulo) DO UPDATE SET
                          inclusao=%s, consulta=%s, edicao=%s, exclusao=%s''', [
                        pid, p.get('modulo'),
                        bool(p.get('inclusao')), bool(p.get('consulta')),
                        bool(p.get('edicao')),   bool(p.get('exclusao')),
                        bool(p.get('inclusao')), bool(p.get('consulta')),
                        bool(p.get('edicao')),   bool(p.get('exclusao')),
                    ])
                conn.commit(); conn.close()
                self.send_json({'ok': True}); return
            except Exception as e:
                conn.rollback(); conn.close()
                self.send_json({'error': str(e)}, 500); return

        if path == '/api/abastecimentos':
            conn = get_db()
            cur  = _exec(conn, '''INSERT INTO abastecimentos
                (data,hora,placa,motorista,cpf_motorista,hodometro,
                 posto,cnpj_posto,cidade_posto,uf_posto,
                 combustivel,volume,preco_unitario,valor_total,
                 arla32_volume,arla32_preco,arla32_total,servicos_abast,cliente_id)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                RETURNING id''', [
                d.get('data'),   d.get('hora'),   d.get('placa'),
                d.get('motorista'), d.get('cpfMotorista',''),
                d.get('hodometro',0), d.get('posto'),
                d.get('cnpjPosto',''), d.get('cidadePosto',''), d.get('ufPosto',''),
                d.get('combustivel'), d.get('volume',0),
                d.get('precoUnitario',0), d.get('valorTotal',0),
                d.get('arla32Volume',0), d.get('arla32Preco',0), d.get('arla32Total',0),
                json.dumps(d.get('servicosAbast',[]), ensure_ascii=False),
                d.get('cliente_id') or None,
            ])
            conn.commit()
            new_id = cur.fetchone()['id']
            _sync_abast_lancamentos(
                conn,
                abast_id       = new_id,
                placa          = d.get('placa',''),
                data           = d.get('data',''),
                posto          = d.get('posto',''),
                combustivel    = d.get('combustivel',''),
                volume         = d.get('volume', 0),
                preco_unitario = d.get('precoUnitario', 0),
                arla32_total   = d.get('arla32Total', 0),
                servicos_abast = d.get('servicosAbast', []),
                cliente_id     = d.get('cliente_id') or None,
            )
            conn.commit()
            conn.close()
            self.send_json({'id': new_id}, 201)

        elif path == '/api/abastecimentos/bulk':
            items = d if isinstance(d, list) else []
            conn  = get_db()
            for item in items:
                _exec(conn, '''INSERT INTO abastecimentos
                    (data,hora,placa,motorista,cpf_motorista,hodometro,
                     posto,cnpj_posto,cidade_posto,uf_posto,
                     combustivel,volume,preco_unitario,valor_total,
                     arla32_volume,arla32_preco,arla32_total,servicos_abast)
                    VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)''', [
                    item.get('data'),    item.get('hora'),    item.get('placa'),
                    item.get('motorista'), item.get('cpfMotorista',''),
                    item.get('hodometro',0), item.get('posto'),
                    item.get('cnpjPosto',''), item.get('cidadePosto',''), item.get('ufPosto',''),
                    item.get('combustivel'), item.get('volume',0),
                    item.get('precoUnitario',0), item.get('valorTotal',0),
                    item.get('arla32Volume',0), item.get('arla32Preco',0), item.get('arla32Total',0),
                    json.dumps(item.get('servicosAbast',[]), ensure_ascii=False)
                ])
            conn.commit()
            conn.close()
            self.send_json({'ok': True, 'count': len(items)}, 201)

        elif path == '/api/postos':
            conn = get_db()
            cur  = _exec(conn, '''INSERT INTO postos
                (cnpj,razao,bandeira,cep,logradouro,numero,complemento,
                 bairro,cidade,uf,lat,lon,gestor,telefone,
                 email_resp,email_nf,banco,agencia,conta,
                 servicos,combustiveis,fotos,
                 perfil_venda,status_posto,situacao,rede,tipo_bandeira,
                 grupo_economico,taxa_admin,possui_internet,data_habilitacao)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                RETURNING id''', [
                d.get('cnpj'), d.get('razao'), d.get('bandeira'),
                d.get('cep',''), d.get('logradouro',''), d.get('numero',''),
                d.get('complemento',''), d.get('bairro',''),
                d.get('cidade',''), d.get('uf',''),
                d.get('lat',''), d.get('lon',''),
                d.get('gestor',''), d.get('telefone',''),
                d.get('emailResp',''), d.get('emailNf',''),
                d.get('banco',''), d.get('agencia',''), d.get('conta',''),
                json.dumps(d.get('servicos',[]),     ensure_ascii=False),
                json.dumps(d.get('combustiveis',{}), ensure_ascii=False),
                json.dumps(d.get('fotos',[]),         ensure_ascii=False),
                d.get('perfilVenda',''), d.get('statusPosto','Ativo'),
                d.get('situacao','Habilitado'), d.get('rede',''),
                d.get('tipoBandeira',''), d.get('grupoEconomico',''),
                d.get('taxaAdmin',0), d.get('possuiInternet',''),
                d.get('dataHabilitacao','')
            ])
            conn.commit()
            new_id = cur.fetchone()['id']
            conn.close()
            self.send_json({'id': new_id}, 201)

        elif path == '/api/postos/bulk':
            items = d if isinstance(d, list) else []
            conn  = get_db()
            inseridos = 0
            for item in items:
                try:
                    _exec(conn, '''INSERT INTO postos
                        (cnpj,razao,bandeira,cep,logradouro,numero,complemento,
                         bairro,cidade,uf,lat,lon,gestor,telefone,
                         email_resp,email_nf,banco,agencia,conta,
                         servicos,combustiveis,fotos,
                         perfil_venda,status_posto,situacao,rede,tipo_bandeira,
                         grupo_economico,taxa_admin,possui_internet,data_habilitacao)
                        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                        ON CONFLICT DO NOTHING''', [
                        item.get('cnpj',''), item.get('razao',''), item.get('bandeira',''),
                        item.get('cep',''), item.get('logradouro',''), item.get('numero',''),
                        item.get('complemento',''), item.get('bairro',''),
                        item.get('cidade',''), item.get('uf',''),
                        item.get('lat',''), item.get('lon',''),
                        item.get('gestor',''), item.get('telefone',''),
                        item.get('emailResp',''), item.get('emailNf',''),
                        item.get('banco',''), item.get('agencia',''), item.get('conta',''),
                        json.dumps(item.get('servicos',[]),      ensure_ascii=False),
                        json.dumps(item.get('combustiveis',{}),  ensure_ascii=False),
                        json.dumps(item.get('fotos',[]),          ensure_ascii=False),
                        item.get('perfilVenda',''), item.get('statusPosto','Ativo'),
                        item.get('situacao','Habilitado'), item.get('rede',''),
                        item.get('tipoBandeira',''), item.get('grupoEconomico',''),
                        item.get('taxaAdmin',0), item.get('possuiInternet',''),
                        item.get('dataHabilitacao',''),
                    ])
                    inseridos += 1
                except Exception:
                    conn.rollback()
            conn.commit()
            conn.close()
            self.send_json({'ok': True, 'count': inseridos}, 201)

        elif path == '/api/motoristas':
            conn = get_db()
            try:
                cur = _exec(conn, '''INSERT INTO motoristas
                    (cpf,nome,status,classificacao,apelido,matricula,celular,email,num_cnh,vencimento_cnh,cliente_id,centro_custo_id)
                    VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) RETURNING id''', [
                    d.get('cpf',''), d.get('nome',''),
                    d.get('status','Ativo'), d.get('classificacao','Próprio'),
                    d.get('apelido',''), d.get('matricula',''), d.get('celular',''),
                    d.get('email',''), d.get('numCnh',''), d.get('vencimentoCnh',''),
                    d.get('cliente_id') or None,
                    d.get('centro_custo_id') or None,
                ])
                conn.commit()
                new_id = cur.fetchone()['id']
                conn.close()
                self.send_json({'id': new_id}, 201)
            except Exception as e:
                conn.rollback()
                conn.close()
                self.send_json({'error': str(e)}, 409)

        elif path == '/api/veiculos':
            conn = get_db()
            try:
                cur = _exec(conn, '''INSERT INTO veiculos
                    (placa,chassi,status,classificacao,tipo,subtipo,num_eixos,
                     marca,modelo,motor,ano_fabricacao,ano_modelo,
                     capacidade_tanque,hodometro,renavam,combustivel_especificado,cliente_id,centro_custo_id)
                    VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) RETURNING id''', [
                    d.get('placa','').upper(), d.get('chassi',''),
                    d.get('status','Ativo'), d.get('classificacao','Próprio'),
                    d.get('tipo','Leve'), d.get('subtipo','Passeio'),
                    d.get('numEixos',2),
                    d.get('marca',''), d.get('modelo',''), d.get('motor',''),
                    d.get('anoFabricacao') or None, d.get('anoModelo') or None,
                    d.get('capacidadeTanque',0), d.get('hodometro',0),
                    d.get('renavam',''), d.get('combustivelEspecificado',''),
                    d.get('cliente_id') or None,
                    d.get('centro_custo_id') or None,
                ])
                conn.commit()
                new_id = cur.fetchone()['id']
                conn.close()
                self.send_json({'id': new_id}, 201)
            except Exception as e:
                conn.rollback()
                conn.close()
                self.send_json({'error': str(e)}, 409)

        elif path == '/api/vinculos':
            conn = get_db()
            cur  = _exec(conn, '''INSERT INTO vinculos
                (placa,motorista_nome,motorista_cpf,data_inicio,data_fim,status,observacao,cliente_id)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s) RETURNING id''', [
                d.get('placa','').upper(), d.get('motoristaNome',''),
                d.get('motoristaCpf',''), d.get('dataInicio',''),
                d.get('dataFim',''), d.get('status','Ativo'),
                d.get('observacao',''), d.get('cliente_id') or None,
            ])
            conn.commit()
            new_id = cur.fetchone()['id']
            conn.close()
            self.send_json({'id': new_id}, 201)

        elif path == '/api/intervalos':
            conn = get_db()
            cur  = _exec(conn, '''INSERT INTO intervalos_abastecimento
                (tipo,referencia,intervalo_minimo,unidade,status,observacao,cliente_id)
                VALUES (%s,%s,%s,%s,%s,%s,%s) RETURNING id''', [
                d.get('tipo',''), d.get('referencia','Todos'),
                d.get('intervaloMinimo', 0), d.get('unidade','Horas'),
                d.get('status','Ativo'), d.get('observacao',''),
                d.get('cliente_id') or None,
            ])
            conn.commit()
            new_id = cur.fetchone()['id']
            conn.close()
            self.send_json({'id': new_id}, 201)

        elif path == '/api/valor-diario':
            conn = get_db()
            cur  = _exec(conn, '''INSERT INTO valor_diario_motorista
                (motorista,valor_max,status,observacao,cliente_id) VALUES (%s,%s,%s,%s,%s) RETURNING id''', [
                d.get('motorista','Todos'), d.get('valorMax', 0),
                d.get('status','Ativo'),    d.get('observacao',''),
                d.get('cliente_id') or None,
            ])
            conn.commit()
            new_id = cur.fetchone()['id']
            conn.close()
            self.send_json({'id': new_id}, 201)

        elif path == '/api/volume-diario':
            conn = get_db()
            cur  = _exec(conn, '''INSERT INTO volume_diario_veiculo
                (placa,volume_max,status,observacao,cliente_id) VALUES (%s,%s,%s,%s,%s) RETURNING id''', [
                d.get('placa','Todos'), d.get('volumeMax', 0),
                d.get('status','Ativo'), d.get('observacao',''),
                d.get('cliente_id') or None,
            ])
            conn.commit()
            new_id = cur.fetchone()['id']
            conn.close()
            self.send_json({'id': new_id}, 201)

        elif path == '/api/produto-abastecido':
            conn = get_db()
            cur  = _exec(conn, '''INSERT INTO produto_abastecido_regras
                (placas,combustiveis,status,observacao,cliente_id) VALUES (%s,%s,%s,%s,%s) RETURNING id''', [
                json.dumps(d.get('placas', ['Todos'])),
                json.dumps(d.get('combustiveis', [])),
                d.get('status', 'Ativo'),
                d.get('observacao', ''),
                d.get('cliente_id') or None,
            ])
            conn.commit()
            new_id = cur.fetchone()['id']
            conn.close()
            self.send_json({'id': new_id}, 201)

        elif path == '/api/seguranca-regras':
            cid  = d.get('cliente_id') or None
            conn = get_db()
            _exec(conn, '''INSERT INTO seguranca_regras (tipo,ativo,valor_int,valor_text,cliente_id,updated_at)
                VALUES (%s,%s,%s,%s,%s,TO_CHAR(NOW(),'YYYY-MM-DD HH24:MI:SS'))
                ON CONFLICT (tipo, cliente_id) DO UPDATE SET
                    ativo       = EXCLUDED.ativo,
                    valor_int   = EXCLUDED.valor_int,
                    valor_text  = EXCLUDED.valor_text,
                    updated_at  = EXCLUDED.updated_at''', [
                d.get('tipo',''), int(d.get('ativo', 0)),
                int(d.get('valorInt', 0)), d.get('valorText',''), cid,
            ])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})

        elif path == '/api/rotogramas':
            conn = get_db()
            cur  = _exec(conn, '''INSERT INTO rotogramas
                (nome,origem,destino,distancia_km,rodovias,estados,descricao,status,versao,ultima_revisao,observacao_seguranca,cliente_id)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) RETURNING id''', [
                d.get('nome',''), d.get('origem',''), d.get('destino',''),
                d.get('distanciaKm', 0), d.get('rodovias',''), d.get('estados',''),
                d.get('descricao',''), d.get('status','Ativo'), d.get('versao','1.0'),
                d.get('ultimaRevisao',''), d.get('observacaoSeguranca',''),
                d.get('cliente_id') or None,
            ])
            conn.commit()
            new_id = cur.fetchone()['id']
            conn.close()
            self.send_json({'id': new_id}, 201)

        elif path == '/api/rotograma-trechos':
            conn = get_db()
            cur  = _exec(conn, '''INSERT INTO rotograma_trechos
                (rotograma_id,ordem,descricao,rodovia,km_inicial,km_final,velocidade_max,tem_cerca,observacao)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s) RETURNING id''', [
                d.get('rotogramaId'), d.get('ordem', 0), d.get('descricao',''),
                d.get('rodovia',''), d.get('kmInicial', 0), d.get('kmFinal', 0),
                d.get('velocidadeMax', 0), int(d.get('temCerca', 0)), d.get('observacao','')
            ])
            conn.commit()
            new_id = cur.fetchone()['id']
            conn.close()
            self.send_json({'id': new_id}, 201)

        elif path == '/api/rotograma-pontos-criticos':
            conn = get_db()
            cur  = _exec(conn, '''INSERT INTO rotograma_pontos_criticos
                (rotograma_id,tipo,descricao,km_referencia,nivel_risco,observacao)
                VALUES (%s,%s,%s,%s,%s,%s) RETURNING id''', [
                d.get('rotogramaId'), d.get('tipo',''), d.get('descricao',''),
                d.get('kmReferencia',''), d.get('nivelRisco','Médio'), d.get('observacao','')
            ])
            conn.commit()
            new_id = cur.fetchone()['id']
            conn.close()
            self.send_json({'id': new_id}, 201)

        elif path == '/api/rotograma-pontos-apoio':
            conn = get_db()
            cur  = _exec(conn, '''INSERT INTO rotograma_pontos_apoio
                (rotograma_id,tipo,nome,km_referencia,endereco,telefone,observacao)
                VALUES (%s,%s,%s,%s,%s,%s,%s) RETURNING id''', [
                d.get('rotogramaId'), d.get('tipo',''), d.get('nome',''),
                d.get('kmReferencia',''), d.get('endereco',''),
                d.get('telefone',''), d.get('observacao','')
            ])
            conn.commit()
            new_id = cur.fetchone()['id']
            conn.close()
            self.send_json({'id': new_id}, 201)

        elif path == '/api/rotograma-execucoes':
            conn = get_db()
            cur  = _exec(conn, '''INSERT INTO rotograma_execucoes
                (rotograma_id,placa,motorista,data,status_exec,observacao)
                VALUES (%s,%s,%s,%s,%s,%s) RETURNING id''', [
                d.get('rotogramaId'), d.get('placa',''), d.get('motorista',''),
                d.get('data',''), d.get('statusExec','Concluída'), d.get('observacao','')
            ])
            conn.commit()
            new_id = cur.fetchone()['id']
            conn.close()
            self.send_json({'id': new_id}, 201)

        elif path == '/api/hodo-variacao':
            conn = get_db()
            cur  = _exec(conn, '''INSERT INTO hodo_variacao
                (tipo_veiculo,placa,variacao_max_km,status,observacao)
                VALUES (%s,%s,%s,%s,%s) RETURNING id''', [
                d.get('tipoVeiculo',''), d.get('placa','Todos'),
                d.get('variacaoMaxKm',0), d.get('status','Ativo'),
                d.get('observacao','')
            ])
            conn.commit()
            new_id = cur.fetchone()['id']
            conn.close()
            self.send_json({'id': new_id}, 201)

        elif path == '/api/planos-viagem':
            conn = get_db()
            cc_id = d.get('centro_custo_id') or None
            cur  = _exec(conn, '''INSERT INTO planos_viagem
                (nome,placa,motorista,rotograma_id,data_saida,data_retorno_prevista,
                 km_estimado,status,consumo_km_l,preco_combustivel,custo_combustivel,
                 custo_pedagio,num_diarias,valor_refeicao,valor_pernoite,valor_banho,
                 valor_lavagem,custo_diarias,custo_manutencao_km,custo_manutencao,
                 custo_total_estimado,custo_total_real,observacoes,cliente_id,centro_custo_id)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                RETURNING id''', [
                d.get('nome',''), d.get('placa',''), d.get('motorista',''),
                d.get('rotogramaId') or None,
                d.get('dataSaida',''), d.get('dataRetornoPrevista',''),
                d.get('kmEstimado',0), d.get('status','Rascunho'),
                d.get('consumoKmL',0), d.get('precoCombustivel',0), d.get('custoCombustivel',0),
                d.get('custoPedagio',0),
                d.get('numDiarias',0), d.get('valorRefeicao',0), d.get('valorPernoite',0),
                d.get('valorBanho',0), d.get('valorLavagem',0), d.get('custoDiarias',0),
                d.get('custoManutencaoKm',0), d.get('custoManutencao',0),
                d.get('custoTotalEstimado',0), d.get('custoTotalReal',0),
                d.get('observacoes',''), d.get('cliente_id') or None, cc_id,
            ])
            conn.commit()
            new_id = cur.fetchone()['id']
            # Auto-create lancamento_cc if centro_custo_id set and cost > 0
            custo = d.get('custoTotalEstimado', 0) or 0
            if cc_id and custo > 0:
                _exec(conn, '''INSERT INTO lancamentos_cc
                    (centro_custo_id,data,categoria,descricao,valor,tipo,
                     referencia_tipo,referencia_id,cliente_id)
                    VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)''', [
                    cc_id,
                    d.get('dataSaida','')[:10] or _hoje(),
                    'Plano de Viagem',
                    f"Plano: {d.get('nome','')} | Placa: {d.get('placa','')}",
                    custo, 'Despesa', 'PlanoViagem', new_id,
                    d.get('cliente_id') or None,
                ])
                conn.commit()
            conn.close()
            self.send_json({'id': new_id}, 201)

        elif path == '/api/planos-viagem-pedagios':
            conn = get_db()
            cur  = _exec(conn, '''INSERT INTO planos_viagem_pedagios
                (plano_id,nome_praca,km_referencia,valor,sentido)
                VALUES (%s,%s,%s,%s,%s) RETURNING id''', [
                d.get('planoId'), d.get('nomePraca',''), d.get('kmReferencia',''),
                d.get('valor',0), d.get('sentido','Ambos')
            ])
            conn.commit()
            new_id = cur.fetchone()['id']
            conn.close()
            self.send_json({'id': new_id}, 201)

        elif path == '/api/negociacoes':
            conn = get_db()
            cur  = _exec(conn, '''INSERT INTO negociacoes
                (posto_id,posto_nome,posto_cnpj,posto_cidade,posto_uf,
                 combustivel,preco_base,tipo_acordo,valor_acordo,preco_negociado,
                 volume_estimado,custo_estimado,data_inicio,data_fim,
                 status,justificativa,observacoes,cliente_id)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s) RETURNING id''', [
                d.get('postoId',0), d.get('postoNome',''), d.get('postoCnpj',''),
                d.get('postoCidade',''), d.get('postoUf',''),
                d.get('combustivel',''), d.get('precoBase',0),
                d.get('tipoAcordo','desconto_pct'), d.get('valorAcordo',0),
                d.get('precoNegociado',0), d.get('volumeEstimado',0),
                d.get('custoEstimado',0), d.get('dataInicio',''), d.get('dataFim',''),
                d.get('status','pendente'), d.get('justificativa',''), d.get('observacoes',''),
                d.get('cliente_id') or None,
            ])
            conn.commit()
            new_id = cur.fetchone()['id']
            conn.close()
            self.send_json({'id': new_id}, 201)

        elif path == '/api/roteirizador-rotas':
            conn = get_db()
            cur  = _exec(conn, '''INSERT INTO roteirizador_rotas
                (nome,tipo_rota,origem,origem_lat,origem_lon,destino,destino_lat,destino_lon,
                 paradas,postos_rota,distancia_km,duracao_min,combustivel,placa,
                 litros_tanque,capacidade_tanque,media_consumo,custo_estimado,
                 filtros,geometria,status,observacao,cliente_id)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
                RETURNING id''', [
                d.get('nome',''), d.get('tipoRota','Personalizada'),
                d.get('origem',''), d.get('origemLat',0), d.get('origemLon',0),
                d.get('destino',''), d.get('destinoLat',0), d.get('destinoLon',0),
                json.dumps(d.get('paradas',[])), json.dumps(d.get('postosRota',[])),
                d.get('distanciaKm',0), d.get('duracaoMin',0),
                d.get('combustivel',''), d.get('placa',''),
                d.get('litrosTanque',0), d.get('capacidadeTanque',0),
                d.get('mediaConsumo',0), d.get('custoEstimado',0),
                json.dumps(d.get('filtros',{})), d.get('geometria',''),
                d.get('status','Rascunho'), d.get('observacao',''),
                d.get('cliente_id') or None,
            ])
            conn.commit()
            new_id = cur.fetchone()['id']
            conn.close()
            self.send_json({'id': new_id}, 201)

        elif path == '/api/motoristas/bulk-status':
            items = d if isinstance(d, list) else []
            conn  = get_db()
            for item in items:
                _exec(conn, 'UPDATE motoristas SET status=%s WHERE id=%s',
                      [item.get('status','Inativo'), item.get('id')])
            conn.commit()
            conn.close()
            self.send_json({'ok': True, 'count': len(items)})

        elif path == '/api/precos-anp/sync':
            global _anp_sync_running
            if _anp_sync_running:
                self.send_json({'ok': False, 'message': 'Sincronização já em andamento.'})
            else:
                _anp_sync_running = True
                t = threading.Thread(target=_do_anp_sync, daemon=True)
                t.start()
                self.send_json({'ok': True, 'message': 'Sincronização iniciada em segundo plano.'})

        elif path == '/api/centros-custo':
            conn = get_db()
            cur  = _exec(conn, '''INSERT INTO centros_custo
                (codigo,nome,descricao,responsavel,cliente_id,status)
                VALUES (%s,%s,%s,%s,%s,%s) RETURNING id''', [
                d.get('codigo',''), d.get('nome',''), d.get('descricao',''),
                d.get('responsavel',''),
                d.get('cliente_id') or d.get('clienteId') or None,
                d.get('status','Ativo')
            ])
            new_id = cur.fetchone()['id']
            conn.commit(); conn.close()
            self.send_json({'id': new_id})

        elif path == '/api/orcamentos-cc':
            conn = get_db()
            orc_cli = d.get('cliente_id') or None
            if orc_cli: orc_cli = int(orc_cli)
            cur  = _exec(conn, '''INSERT INTO orcamentos_cc
                (centro_custo_id,ano,mes,categoria,valor_orcado,observacoes,cliente_id)
                VALUES (%s,%s,%s,%s,%s,%s,%s) RETURNING id''', [
                d.get('centro_custo_id') or d.get('centroCustoId'),
                d.get('ano'), d.get('mes'),
                d.get('categoria',''),
                d.get('valor_orcado') or d.get('valorOrcado',0),
                d.get('observacoes',''), orc_cli
            ])
            new_id = cur.fetchone()['id']
            conn.commit(); conn.close()
            self.send_json({'id': new_id})

        elif path == '/api/lancamentos-cc':
            conn = get_db()
            cur  = _exec(conn, '''INSERT INTO lancamentos_cc
                (centro_custo_id,data,categoria,descricao,valor,tipo,referencia_tipo,referencia_id,cliente_id)
                VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s) RETURNING id''', [
                d.get('centro_custo_id') or d.get('centroCustoId'),
                d.get('data'), d.get('categoria',''),
                d.get('descricao',''), d.get('valor',0), d.get('tipo','Despesa'),
                d.get('referencia_tipo') or d.get('referenciaTipo','Manual'),
                d.get('referencia_id') or d.get('referenciaId') or None,
                d.get('cliente_id') or d.get('clienteId') or None
            ])
            new_id = cur.fetchone()['id']
            conn.commit(); conn.close()
            self.send_json({'id': new_id})

        else:
            self.send_json({'error': 'Not found'}, 404)

    # ──────────────────────────────────────────────────────────
    #  PUT
    # ──────────────────────────────────────────────────────────
    def do_PUT(self):
        path = urlparse(self.path).path
        d    = self.read_body()

        m = re.match(r'^/api/abastecimentos/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            _exec(conn, '''UPDATE abastecimentos SET
                data=%s,hora=%s,placa=%s,motorista=%s,cpf_motorista=%s,hodometro=%s,
                posto=%s,cnpj_posto=%s,cidade_posto=%s,uf_posto=%s,
                combustivel=%s,volume=%s,preco_unitario=%s,valor_total=%s,
                arla32_volume=%s,arla32_preco=%s,arla32_total=%s,servicos_abast=%s,
                cliente_id=%s
                WHERE id=%s''', [
                d.get('data'),   d.get('hora'),   d.get('placa'),
                d.get('motorista'), d.get('cpfMotorista',''),
                d.get('hodometro',0), d.get('posto'),
                d.get('cnpjPosto',''), d.get('cidadePosto',''), d.get('ufPosto',''),
                d.get('combustivel'), d.get('volume',0),
                d.get('precoUnitario',0), d.get('valorTotal',0),
                d.get('arla32Volume',0), d.get('arla32Preco',0), d.get('arla32Total',0),
                json.dumps(d.get('servicosAbast',[]), ensure_ascii=False),
                d.get('cliente_id') or None,
                id_
            ])
            conn.commit()
            _sync_abast_lancamentos(
                conn,
                abast_id       = id_,
                placa          = d.get('placa',''),
                data           = d.get('data',''),
                posto          = d.get('posto',''),
                combustivel    = d.get('combustivel',''),
                volume         = d.get('volume', 0),
                preco_unitario = d.get('precoUnitario', 0),
                arla32_total   = d.get('arla32Total', 0),
                servicos_abast = d.get('servicosAbast', []),
                cliente_id     = d.get('cliente_id') or None,
            )
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/postos/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            _exec(conn, '''UPDATE postos SET
                cnpj=%s,razao=%s,bandeira=%s,cep=%s,logradouro=%s,numero=%s,complemento=%s,
                bairro=%s,cidade=%s,uf=%s,lat=%s,lon=%s,gestor=%s,telefone=%s,
                email_resp=%s,email_nf=%s,banco=%s,agencia=%s,conta=%s,
                servicos=%s,combustiveis=%s,fotos=%s,
                perfil_venda=%s,status_posto=%s,situacao=%s,rede=%s,tipo_bandeira=%s,
                grupo_economico=%s,taxa_admin=%s,possui_internet=%s,data_habilitacao=%s
                WHERE id=%s''', [
                d.get('cnpj'), d.get('razao'), d.get('bandeira'),
                d.get('cep',''), d.get('logradouro',''), d.get('numero',''),
                d.get('complemento',''), d.get('bairro',''),
                d.get('cidade',''), d.get('uf',''),
                d.get('lat',''), d.get('lon',''),
                d.get('gestor',''), d.get('telefone',''),
                d.get('emailResp',''), d.get('emailNf',''),
                d.get('banco',''), d.get('agencia',''), d.get('conta',''),
                json.dumps(d.get('servicos',[]),     ensure_ascii=False),
                json.dumps(d.get('combustiveis',{}), ensure_ascii=False),
                json.dumps(d.get('fotos',[]),         ensure_ascii=False),
                d.get('perfilVenda',''), d.get('statusPosto','Ativo'),
                d.get('situacao','Habilitado'), d.get('rede',''),
                d.get('tipoBandeira',''), d.get('grupoEconomico',''),
                d.get('taxaAdmin',0), d.get('possuiInternet',''),
                d.get('dataHabilitacao',''),
                id_
            ])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/motoristas/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            _exec(conn, '''UPDATE motoristas SET
                cpf=%s,nome=%s,status=%s,classificacao=%s,apelido=%s,matricula=%s,celular=%s,
                email=%s,num_cnh=%s,vencimento_cnh=%s,cliente_id=%s,centro_custo_id=%s WHERE id=%s''', [
                d.get('cpf',''), d.get('nome',''),
                d.get('status','Ativo'), d.get('classificacao','Próprio'),
                d.get('apelido',''), d.get('matricula',''), d.get('celular',''),
                d.get('email',''), d.get('numCnh',''), d.get('vencimentoCnh',''),
                d.get('cliente_id') or None, d.get('centro_custo_id') or None, id_
            ])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/veiculos/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            _exec(conn, '''UPDATE veiculos SET
                placa=%s,chassi=%s,status=%s,classificacao=%s,tipo=%s,subtipo=%s,num_eixos=%s,
                marca=%s,modelo=%s,motor=%s,ano_fabricacao=%s,ano_modelo=%s,
                capacidade_tanque=%s,hodometro=%s,renavam=%s,combustivel_especificado=%s,
                cliente_id=%s,centro_custo_id=%s WHERE id=%s''', [
                d.get('placa','').upper(), d.get('chassi',''),
                d.get('status','Ativo'), d.get('classificacao','Próprio'),
                d.get('tipo','Leve'), d.get('subtipo','Passeio'),
                d.get('numEixos',2),
                d.get('marca',''), d.get('modelo',''), d.get('motor',''),
                d.get('anoFabricacao') or None, d.get('anoModelo') or None,
                d.get('capacidadeTanque',0), d.get('hodometro',0),
                d.get('renavam',''), d.get('combustivelEspecificado',''),
                d.get('cliente_id') or None, d.get('centro_custo_id') or None, id_
            ])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/vinculos/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            _exec(conn, '''UPDATE vinculos SET
                placa=%s,motorista_nome=%s,motorista_cpf=%s,
                data_inicio=%s,data_fim=%s,status=%s,observacao=%s WHERE id=%s''', [
                d.get('placa','').upper(), d.get('motoristaNome',''),
                d.get('motoristaCpf',''), d.get('dataInicio',''),
                d.get('dataFim',''), d.get('status','Ativo'),
                d.get('observacao',''), id_
            ])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/intervalos/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            _exec(conn, '''UPDATE intervalos_abastecimento SET
                tipo=%s,referencia=%s,intervalo_minimo=%s,unidade=%s,status=%s,observacao=%s,
                cliente_id=%s WHERE id=%s''', [
                d.get('tipo',''), d.get('referencia','Todos'),
                d.get('intervaloMinimo', 0), d.get('unidade','Horas'),
                d.get('status','Ativo'), d.get('observacao',''),
                d.get('cliente_id') or None, id_
            ])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/valor-diario/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            _exec(conn, '''UPDATE valor_diario_motorista SET
                motorista=%s,valor_max=%s,status=%s,observacao=%s,cliente_id=%s WHERE id=%s''', [
                d.get('motorista','Todos'), d.get('valorMax', 0),
                d.get('status','Ativo'), d.get('observacao',''),
                d.get('cliente_id') or None, id_
            ])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/volume-diario/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            _exec(conn, '''UPDATE volume_diario_veiculo SET
                placa=%s,volume_max=%s,status=%s,observacao=%s,cliente_id=%s WHERE id=%s''', [
                d.get('placa','Todos'), d.get('volumeMax', 0),
                d.get('status','Ativo'), d.get('observacao',''),
                d.get('cliente_id') or None, id_
            ])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/produto-abastecido/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            _exec(conn, '''UPDATE produto_abastecido_regras SET
                placas=%s,combustiveis=%s,status=%s,observacao=%s,cliente_id=%s WHERE id=%s''', [
                json.dumps(d.get('placas', ['Todos'])),
                json.dumps(d.get('combustiveis', [])),
                d.get('status', 'Ativo'),
                d.get('observacao', ''),
                d.get('cliente_id') or None, id_
            ])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/rotogramas/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            _exec(conn, '''UPDATE rotogramas SET
                nome=%s,origem=%s,destino=%s,distancia_km=%s,rodovias=%s,estados=%s,
                descricao=%s,status=%s,versao=%s,ultima_revisao=%s,observacao_seguranca=%s,
                cliente_id=%s WHERE id=%s''', [
                d.get('nome',''), d.get('origem',''), d.get('destino',''),
                d.get('distanciaKm', 0), d.get('rodovias',''), d.get('estados',''),
                d.get('descricao',''), d.get('status','Ativo'), d.get('versao','1.0'),
                d.get('ultimaRevisao',''), d.get('observacaoSeguranca',''),
                d.get('cliente_id') or None, id_
            ])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/rotograma-trechos/item/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            _exec(conn, '''UPDATE rotograma_trechos SET
                ordem=%s,descricao=%s,rodovia=%s,km_inicial=%s,km_final=%s,velocidade_max=%s,tem_cerca=%s,observacao=%s
                WHERE id=%s''', [
                d.get('ordem', 0), d.get('descricao',''), d.get('rodovia',''),
                d.get('kmInicial', 0), d.get('kmFinal', 0), d.get('velocidadeMax', 0),
                int(d.get('temCerca', 0)), d.get('observacao',''), id_
            ])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/rotograma-pontos-criticos/item/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            _exec(conn, '''UPDATE rotograma_pontos_criticos SET
                tipo=%s,descricao=%s,km_referencia=%s,nivel_risco=%s,observacao=%s WHERE id=%s''', [
                d.get('tipo',''), d.get('descricao',''), d.get('kmReferencia',''),
                d.get('nivelRisco','Médio'), d.get('observacao',''), id_
            ])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/rotograma-pontos-apoio/item/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            _exec(conn, '''UPDATE rotograma_pontos_apoio SET
                tipo=%s,nome=%s,km_referencia=%s,endereco=%s,telefone=%s,observacao=%s WHERE id=%s''', [
                d.get('tipo',''), d.get('nome',''), d.get('kmReferencia',''),
                d.get('endereco',''), d.get('telefone',''), d.get('observacao',''), id_
            ])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/hodo-variacao/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            _exec(conn, '''UPDATE hodo_variacao SET
                tipo_veiculo=%s,placa=%s,variacao_max_km=%s,status=%s,observacao=%s,
                cliente_id=%s WHERE id=%s''', [
                d.get('tipoVeiculo',''), d.get('placa','Todos'),
                d.get('variacaoMaxKm',0), d.get('status','Ativo'),
                d.get('observacao',''),
                d.get('cliente_id') or None, id_
            ])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/negociacoes/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            _exec(conn, '''UPDATE negociacoes SET
                posto_id=%s,posto_nome=%s,posto_cnpj=%s,posto_cidade=%s,posto_uf=%s,
                combustivel=%s,preco_base=%s,tipo_acordo=%s,valor_acordo=%s,preco_negociado=%s,
                volume_estimado=%s,custo_estimado=%s,data_inicio=%s,data_fim=%s,
                status=%s,justificativa=%s,observacoes=%s,cliente_id=%s,
                updated_at=TO_CHAR(NOW(),'YYYY-MM-DD HH24:MI:SS') WHERE id=%s''', [
                d.get('postoId',0), d.get('postoNome',''), d.get('postoCnpj',''),
                d.get('postoCidade',''), d.get('postoUf',''),
                d.get('combustivel',''), d.get('precoBase',0),
                d.get('tipoAcordo','desconto_pct'), d.get('valorAcordo',0),
                d.get('precoNegociado',0), d.get('volumeEstimado',0),
                d.get('custoEstimado',0), d.get('dataInicio',''), d.get('dataFim',''),
                d.get('status','pendente'), d.get('justificativa',''), d.get('observacoes',''),
                d.get('cliente_id') or None,
                id_
            ])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/roteirizador-rotas/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            _exec(conn, '''UPDATE roteirizador_rotas SET
                nome=%s,tipo_rota=%s,origem=%s,origem_lat=%s,origem_lon=%s,
                destino=%s,destino_lat=%s,destino_lon=%s,paradas=%s,postos_rota=%s,
                distancia_km=%s,duracao_min=%s,combustivel=%s,placa=%s,
                litros_tanque=%s,capacidade_tanque=%s,media_consumo=%s,custo_estimado=%s,
                filtros=%s,geometria=%s,status=%s,observacao=%s WHERE id=%s''', [
                d.get('nome',''), d.get('tipoRota','Personalizada'),
                d.get('origem',''), d.get('origemLat',0), d.get('origemLon',0),
                d.get('destino',''), d.get('destinoLat',0), d.get('destinoLon',0),
                json.dumps(d.get('paradas',[])), json.dumps(d.get('postosRota',[])),
                d.get('distanciaKm',0), d.get('duracaoMin',0),
                d.get('combustivel',''), d.get('placa',''),
                d.get('litrosTanque',0), d.get('capacidadeTanque',0),
                d.get('mediaConsumo',0), d.get('custoEstimado',0),
                json.dumps(d.get('filtros',{})), d.get('geometria',''),
                d.get('status','Rascunho'), d.get('observacao',''), id_
            ])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/rotograma-execucoes/item/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            _exec(conn, '''UPDATE rotograma_execucoes SET
                data=%s,placa=%s,motorista=%s,status_exec=%s,observacao=%s WHERE id=%s''', [
                d.get('data',''), d.get('placa',''), d.get('motorista',''),
                d.get('statusExec',''), d.get('observacao',''), id_
            ])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/planos-viagem/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            cc_id = d.get('centro_custo_id') or None
            conn = get_db()
            _exec(conn, '''UPDATE planos_viagem SET
                nome=%s,placa=%s,motorista=%s,rotograma_id=%s,data_saida=%s,data_retorno_prevista=%s,
                km_estimado=%s,status=%s,consumo_km_l=%s,preco_combustivel=%s,custo_combustivel=%s,
                custo_pedagio=%s,num_diarias=%s,valor_refeicao=%s,valor_pernoite=%s,valor_banho=%s,
                valor_lavagem=%s,custo_diarias=%s,custo_manutencao_km=%s,custo_manutencao=%s,
                custo_total_estimado=%s,custo_total_real=%s,observacoes=%s,
                cliente_id=%s,centro_custo_id=%s WHERE id=%s''', [
                d.get('nome',''), d.get('placa',''), d.get('motorista',''),
                d.get('rotogramaId') or None,
                d.get('dataSaida',''), d.get('dataRetornoPrevista',''),
                d.get('kmEstimado',0), d.get('status','Rascunho'),
                d.get('consumoKmL',0), d.get('precoCombustivel',0), d.get('custoCombustivel',0),
                d.get('custoPedagio',0),
                d.get('numDiarias',0), d.get('valorRefeicao',0), d.get('valorPernoite',0),
                d.get('valorBanho',0), d.get('valorLavagem',0), d.get('custoDiarias',0),
                d.get('custoManutencaoKm',0), d.get('custoManutencao',0),
                d.get('custoTotalEstimado',0), d.get('custoTotalReal',0),
                d.get('observacoes',''),
                d.get('cliente_id') or None, cc_id, id_
            ])
            # Sync lancamento_cc for this plano (upsert by referencia)
            if cc_id:
                custo = d.get('custoTotalEstimado', 0) or 0
                existing = _fetchone(conn,
                    "SELECT id FROM lancamentos_cc WHERE referencia_tipo='PlanoViagem' AND referencia_id=%s",
                    [id_])
                if existing:
                    _exec(conn, '''UPDATE lancamentos_cc SET
                        centro_custo_id=%s,data=%s,descricao=%s,valor=%s,cliente_id=%s WHERE id=%s''', [
                        cc_id,
                        d.get('dataSaida','')[:10] or _hoje(),
                        f"Plano: {d.get('nome','')} | Placa: {d.get('placa','')}",
                        custo, d.get('cliente_id') or None, existing['id']
                    ])
                else:
                    _exec(conn, '''INSERT INTO lancamentos_cc
                        (centro_custo_id,data,categoria,descricao,valor,tipo,
                         referencia_tipo,referencia_id,cliente_id)
                        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s)''', [
                        cc_id,
                        d.get('dataSaida','')[:10] or _hoje(),
                        'Plano de Viagem',
                        f"Plano: {d.get('nome','')} | Placa: {d.get('placa','')}",
                        custo, 'Despesa', 'PlanoViagem', id_,
                        d.get('cliente_id') or None,
                    ])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/planos-viagem-pedagios/item/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            _exec(conn, '''UPDATE planos_viagem_pedagios SET
                nome_praca=%s,km_referencia=%s,valor=%s,sentido=%s WHERE id=%s''', [
                d.get('nomePraca',''), d.get('kmReferencia',''),
                d.get('valor',0), d.get('sentido','Ambos'), id_
            ])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/clientes/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            _exec(conn, '''UPDATE clientes SET
                cnpj=%s,razao_social=%s,contato=%s,telefone=%s,email=%s,status=%s,
                grupo_economico=%s,porte_empresa=%s,qtd_veiculos_pesados=%s,
                qtd_veiculos_leves=%s,segmento_atuacao=%s,volume_diesel=%s,
                volume_gasolina_alcool=%s,pagamento=%s,observacoes=%s,
                updated_at=TO_CHAR(NOW(),'YYYY-MM-DD HH24:MI:SS')
                WHERE id=%s''', [
                d.get('cnpj',''),           d.get('razaoSocial',''),
                d.get('contato',''),        d.get('telefone',''),
                d.get('email',''),          d.get('status','Ativo'),
                d.get('grupoEconomico',''), d.get('porteEmpresa','Médio'),
                d.get('qtdVeiculosPesados',0), d.get('qtdVeiculosLeves',0),
                d.get('segmentoAtuacao',''),d.get('volumeDiesel',0),
                d.get('volumeGasolinaAlcool',0), d.get('pagamento','Pós-Pago'),
                d.get('observacoes',''),    id_
            ])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/usuarios/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            try:
                cli_id    = d.get('cliente_id') or None
                if cli_id: cli_id = int(cli_id)
                perfil_id = d.get('perfil_id') or None
                if perfil_id: perfil_id = int(perfil_id)
                seg = d.get('segmento','Frota')
                _exec(conn, '''UPDATE usuarios SET
                    nome=%s,cpf=%s,telefone=%s,email=%s,perfil=%s,segmento=%s,tipo_acesso=%s,
                    perfil_id=%s,status=%s,cliente_id=%s,observacoes=%s
                    WHERE id=%s''', [
                    d.get('nome',''), d.get('cpf',''),
                    d.get('telefone',''), d.get('email',''),
                    d.get('perfil','Operador'),
                    seg, seg,          # segmento e tipo_acesso em sincronia
                    perfil_id,
                    d.get('status','Ativo'),
                    cli_id, d.get('observacoes',''), id_
                ])
                conn.commit(); conn.close()
                self.send_json({'ok': True}); return
            except Exception as e:
                conn.rollback(); conn.close()
                self.send_json({'error': str(e)}, 409); return

        m = re.match(r'^/api/perfis-acesso/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            try:
                _exec(conn, 'UPDATE perfis_acesso SET nome=%s, descricao=%s WHERE id=%s',
                    [d.get('nome',''), d.get('descricao',''), id_])
                conn.commit(); conn.close()
                self.send_json({'ok': True}); return
            except Exception as e:
                conn.rollback(); conn.close()
                self.send_json({'error': str(e)}, 409); return

        m = re.match(r'^/api/centros-custo/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            _exec(conn, '''UPDATE centros_custo SET
                codigo=%s,nome=%s,descricao=%s,responsavel=%s,cliente_id=%s,status=%s
                WHERE id=%s''', [
                d.get('codigo',''), d.get('nome',''), d.get('descricao',''),
                d.get('responsavel',''),
                d.get('cliente_id') or d.get('clienteId') or None,
                d.get('status','Ativo'), id_
            ])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/orcamentos-cc/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            orc_cli = d.get('cliente_id') or None
            if orc_cli: orc_cli = int(orc_cli)
            _exec(conn, '''UPDATE orcamentos_cc SET
                centro_custo_id=%s,ano=%s,mes=%s,categoria=%s,valor_orcado=%s,observacoes=%s,cliente_id=%s
                WHERE id=%s''', [
                d.get('centro_custo_id') or d.get('centroCustoId'),
                d.get('ano'), d.get('mes'),
                d.get('categoria',''),
                d.get('valor_orcado') or d.get('valorOrcado',0),
                d.get('observacoes',''), orc_cli, id_
            ])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/lancamentos-cc/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            _exec(conn, '''UPDATE lancamentos_cc SET
                centro_custo_id=%s,data=%s,categoria=%s,descricao=%s,
                valor=%s,tipo=%s,referencia_tipo=%s,referencia_id=%s,cliente_id=%s
                WHERE id=%s''', [
                d.get('centro_custo_id') or d.get('centroCustoId'),
                d.get('data'), d.get('categoria',''),
                d.get('descricao',''), d.get('valor',0), d.get('tipo','Despesa'),
                d.get('referencia_tipo') or d.get('referenciaTipo','Manual'),
                d.get('referencia_id') or d.get('referenciaId') or None,
                d.get('cliente_id') or d.get('clienteId') or None, id_
            ])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        self.send_json({'error': 'Not found'}, 404)

    # ──────────────────────────────────────────────────────────
    #  DELETE
    # ──────────────────────────────────────────────────────────
    def do_DELETE(self):
        path = urlparse(self.path).path

        if path == '/api/abastecimentos':
            conn = get_db()
            cur  = _exec(conn, 'SELECT COUNT(*) AS n FROM abastecimentos')
            n    = cur.fetchone()['n']
            _exec(conn, "DELETE FROM lancamentos_cc WHERE referencia_tipo='Abastecimento'")
            _exec(conn, 'DELETE FROM abastecimentos')
            _exec(conn, "SELECT SETVAL('abastecimentos_id_seq', 1, false)")
            conn.commit(); conn.close()
            self.send_json({'ok': True, 'deleted': n}); return

        m = re.match(r'^/api/abastecimentos/(\d+)$', path)
        if m:
            aid = int(m.group(1))
            conn = get_db()
            _exec(conn, "DELETE FROM lancamentos_cc WHERE referencia_tipo='Abastecimento' AND referencia_id=%s", [aid])
            _exec(conn, 'DELETE FROM abastecimentos WHERE id=%s', [aid])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        if path == '/api/postos':
            conn = get_db()
            _exec(conn, 'DELETE FROM postos')
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/postos/(\d+)$', path)
        if m:
            conn = get_db()
            _exec(conn, 'DELETE FROM postos WHERE id=%s', [int(m.group(1))])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/motoristas/(\d+)$', path)
        if m:
            conn = get_db()
            _exec(conn, 'DELETE FROM motoristas WHERE id=%s', [int(m.group(1))])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/veiculos/(\d+)$', path)
        if m:
            conn = get_db()
            _exec(conn, 'DELETE FROM veiculos WHERE id=%s', [int(m.group(1))])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/vinculos/(\d+)$', path)
        if m:
            conn = get_db()
            _exec(conn, 'DELETE FROM vinculos WHERE id=%s', [int(m.group(1))])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/intervalos/(\d+)$', path)
        if m:
            conn = get_db()
            _exec(conn, 'DELETE FROM intervalos_abastecimento WHERE id=%s', [int(m.group(1))])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/valor-diario/(\d+)$', path)
        if m:
            conn = get_db()
            _exec(conn, 'DELETE FROM valor_diario_motorista WHERE id=%s', [int(m.group(1))])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/volume-diario/(\d+)$', path)
        if m:
            conn = get_db()
            _exec(conn, 'DELETE FROM volume_diario_veiculo WHERE id=%s', [int(m.group(1))])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/produto-abastecido/(\d+)$', path)
        if m:
            conn = get_db()
            _exec(conn, 'DELETE FROM produto_abastecido_regras WHERE id=%s', [int(m.group(1))])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/rotogramas/(\d+)$', path)
        if m:
            rid  = int(m.group(1))
            conn = get_db()
            for tbl in ('rotograma_trechos','rotograma_pontos_criticos',
                        'rotograma_pontos_apoio','rotograma_execucoes'):
                _exec(conn, f'DELETE FROM {tbl} WHERE rotograma_id=%s', [rid])
            _exec(conn, 'DELETE FROM rotogramas WHERE id=%s', [rid])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/rotograma-trechos/item/(\d+)$', path)
        if m:
            conn = get_db()
            _exec(conn, 'DELETE FROM rotograma_trechos WHERE id=%s', [int(m.group(1))])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/rotograma-pontos-criticos/item/(\d+)$', path)
        if m:
            conn = get_db()
            _exec(conn, 'DELETE FROM rotograma_pontos_criticos WHERE id=%s', [int(m.group(1))])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/rotograma-pontos-apoio/item/(\d+)$', path)
        if m:
            conn = get_db()
            _exec(conn, 'DELETE FROM rotograma_pontos_apoio WHERE id=%s', [int(m.group(1))])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/rotograma-execucoes/item/(\d+)$', path)
        if m:
            conn = get_db()
            _exec(conn, 'DELETE FROM rotograma_execucoes WHERE id=%s', [int(m.group(1))])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/hodo-variacao/(\d+)$', path)
        if m:
            conn = get_db()
            _exec(conn, 'DELETE FROM hodo_variacao WHERE id=%s', [int(m.group(1))])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/planos-viagem/(\d+)$', path)
        if m:
            pid  = int(m.group(1))
            conn = get_db()
            _exec(conn, 'DELETE FROM planos_viagem_pedagios WHERE plano_id=%s', [pid])
            _exec(conn, 'DELETE FROM planos_viagem WHERE id=%s', [pid])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/planos-viagem-pedagios/item/(\d+)$', path)
        if m:
            conn = get_db()
            _exec(conn, 'DELETE FROM planos_viagem_pedagios WHERE id=%s', [int(m.group(1))])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/roteirizador-rotas/(\d+)$', path)
        if m:
            conn = get_db()
            _exec(conn, 'DELETE FROM roteirizador_rotas WHERE id=%s', [int(m.group(1))])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/negociacoes/(\d+)$', path)
        if m:
            conn = get_db()
            _exec(conn, 'DELETE FROM negociacoes WHERE id=%s', [int(m.group(1))])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/clientes/(\d+)$', path)
        if m:
            conn = get_db()
            _exec(conn, 'DELETE FROM clientes WHERE id=%s', [int(m.group(1))])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/usuarios/(\d+)$', path)
        if m:
            conn = get_db()
            _exec(conn, 'DELETE FROM usuarios WHERE id=%s', [int(m.group(1))])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/perfis-acesso/(\d+)$', path)
        if m:
            conn = get_db()
            id_ = int(m.group(1))
            _exec(conn, 'DELETE FROM permissoes_perfil WHERE perfil_id=%s', [id_])
            _exec(conn, 'DELETE FROM perfis_acesso WHERE id=%s', [id_])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/centros-custo/(\d+)$', path)
        if m:
            conn = get_db()
            _exec(conn, 'DELETE FROM centros_custo WHERE id=%s', [int(m.group(1))])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/orcamentos-cc/(\d+)$', path)
        if m:
            conn = get_db()
            _exec(conn, 'DELETE FROM orcamentos_cc WHERE id=%s', [int(m.group(1))])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        m = re.match(r'^/api/lancamentos-cc/(\d+)$', path)
        if m:
            conn = get_db()
            _exec(conn, 'DELETE FROM lancamentos_cc WHERE id=%s', [int(m.group(1))])
            conn.commit(); conn.close()
            self.send_json({'ok': True}); return

        self.send_json({'error': 'Not found'}, 404)

# ═══════════════════════════════════════════════════════════════
#  MAIN
# ═══════════════════════════════════════════════════════════════
if __name__ == '__main__':
    init_db()
    print()
    print('  ╔══════════════════════════════════════════╗')
    print('  ║   Gestão de Abastecimentos – Servidor    ║')
    print('  ╠══════════════════════════════════════════╣')
    print(f'  ║  Banco:    PostgreSQL {DB_HOST}:{DB_PORT}/{DB_NAME}')
    print(f'  ║  URL:      http://localhost:{PORT}           ║')
    print(f'  ║  Parar:    Ctrl+C                        ║')
    print('  ╚══════════════════════════════════════════╝')
    print()
    server = HTTPServer(('0.0.0.0', PORT), Handler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('\n  Servidor parado.')
        sys.exit(0)
