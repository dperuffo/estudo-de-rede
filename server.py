#!/usr/bin/env python3
"""
═══════════════════════════════════════════════════════════════
  BACKEND – Gestão de Abastecimentos de Frota
  Banco de dados: SQLite  |  Servidor: HTTP stdlib Python
═══════════════════════════════════════════════════════════════
  Como usar:
    1. python3 server.py
    2. Abra http://localhost:5000 no navegador
    3. Pressione Ctrl+C para parar o servidor
═══════════════════════════════════════════════════════════════
"""
from http.server import HTTPServer, BaseHTTPRequestHandler
import sqlite3, json, os, re, sys, threading
from urllib.parse import urlparse, parse_qs

BASE_DIR  = os.path.dirname(os.path.abspath(__file__))
DATABASE  = os.path.join(BASE_DIR, 'gestao_frota.db')
HTML_FILE = os.path.join(BASE_DIR, 'gestao-abastecimentos.html')
PORT      = 8080

# ═══════════════════════════════════════════════════════════════
#  BANCO DE DADOS
# ═══════════════════════════════════════════════════════════════
def get_db():
    conn = sqlite3.connect(DATABASE)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL")
    return conn

def init_db():
    conn = get_db()
    conn.execute('''CREATE TABLE IF NOT EXISTS abastecimentos (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
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
        created_at      TEXT    DEFAULT (datetime('now','localtime'))
    )''')
    # Migração: adiciona colunas de serviços/Arla 32 se não existirem
    for col_def in [
        ("arla32_volume",  "REAL DEFAULT 0"),
        ("arla32_preco",   "REAL DEFAULT 0"),
        ("arla32_total",   "REAL DEFAULT 0"),
        ("servicos_abast", "TEXT DEFAULT '[]'"),
    ]:
        try:
            conn.execute(f"ALTER TABLE abastecimentos ADD COLUMN {col_def[0]} {col_def[1]}")
            conn.commit()
        except Exception:
            pass  # coluna já existe
    conn.execute('''CREATE TABLE IF NOT EXISTS postos (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
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
        created_at       TEXT    DEFAULT (datetime('now','localtime'))
    )''')
    # Migração: adiciona novas colunas de postos se não existirem
    for col_def in [
        ("perfil_venda",    "TEXT DEFAULT ''"),
        ("status_posto",    "TEXT DEFAULT 'Ativo'"),
        ("situacao",        "TEXT DEFAULT 'Habilitado'"),
        ("rede",            "TEXT DEFAULT ''"),
        ("tipo_bandeira",   "TEXT DEFAULT ''"),
        ("grupo_economico", "TEXT DEFAULT ''"),
        ("taxa_admin",      "REAL DEFAULT 0"),
        ("possui_internet", "TEXT DEFAULT ''"),
        ("data_habilitacao","TEXT DEFAULT ''"),
    ]:
        try:
            conn.execute(f"ALTER TABLE postos ADD COLUMN {col_def[0]} {col_def[1]}")
            conn.commit()
        except Exception:
            pass  # coluna já existe
    conn.execute('''CREATE TABLE IF NOT EXISTS motoristas (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
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
        created_at      TEXT    DEFAULT (datetime('now','localtime'))
    )''')
    # Migração: adiciona coluna se não existir (banco já criado sem ela)
    try:
        conn.execute("ALTER TABLE motoristas ADD COLUMN classificacao TEXT DEFAULT 'Próprio'")
        conn.commit()
    except Exception:
        pass  # coluna já existe
    conn.execute('''CREATE TABLE IF NOT EXISTS veiculos (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        placa               TEXT    NOT NULL UNIQUE,
        chassi              TEXT    DEFAULT '',
        status              TEXT    DEFAULT 'Ativo',
        classificacao       TEXT    DEFAULT 'Próprio',
        tipo                TEXT    DEFAULT 'Leve',
        subtipo             TEXT    DEFAULT 'Passeio',
        num_eixos           INTEGER DEFAULT 2,
        marca               TEXT    DEFAULT '',
        modelo              TEXT    DEFAULT '',
        motor               TEXT    DEFAULT '',
        ano_fabricacao      INTEGER DEFAULT NULL,
        ano_modelo          INTEGER DEFAULT NULL,
        capacidade_tanque   REAL    DEFAULT 0,
        hodometro           REAL    DEFAULT 0,
        renavam             TEXT    DEFAULT '',
        combustivel_especificado TEXT DEFAULT '',
        created_at          TEXT    DEFAULT (datetime('now','localtime'))
    )''')
    try:
        conn.execute("ALTER TABLE veiculos ADD COLUMN combustivel_especificado TEXT DEFAULT ''")
        conn.commit()
    except Exception:
        pass  # coluna já existe
    conn.execute('''CREATE TABLE IF NOT EXISTS vinculos (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        placa           TEXT    NOT NULL,
        motorista_nome  TEXT    NOT NULL,
        motorista_cpf   TEXT    DEFAULT '',
        data_inicio     TEXT    NOT NULL,
        data_fim        TEXT    DEFAULT '',
        status          TEXT    DEFAULT 'Ativo',
        observacao      TEXT    DEFAULT '',
        created_at      TEXT    DEFAULT (datetime('now','localtime'))
    )''')
    conn.execute('''CREATE TABLE IF NOT EXISTS intervalos_abastecimento (
        id                  INTEGER PRIMARY KEY AUTOINCREMENT,
        tipo                TEXT    NOT NULL,
        referencia          TEXT    DEFAULT 'Todos',
        intervalo_minimo    REAL    NOT NULL,
        unidade             TEXT    DEFAULT 'Horas',
        status              TEXT    DEFAULT 'Ativo',
        observacao          TEXT    DEFAULT '',
        created_at          TEXT    DEFAULT (datetime('now','localtime'))
    )''')
    conn.execute('''CREATE TABLE IF NOT EXISTS valor_diario_motorista (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        motorista   TEXT    DEFAULT 'Todos',
        valor_max   REAL    NOT NULL,
        status      TEXT    DEFAULT 'Ativo',
        observacao  TEXT    DEFAULT '',
        created_at  TEXT    DEFAULT (datetime('now','localtime'))
    )''')
    conn.execute('''CREATE TABLE IF NOT EXISTS volume_diario_veiculo (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        placa       TEXT    DEFAULT 'Todos',
        volume_max  REAL    NOT NULL,
        status      TEXT    DEFAULT 'Ativo',
        observacao  TEXT    DEFAULT '',
        created_at  TEXT    DEFAULT (datetime('now','localtime'))
    )''')
    conn.execute('''CREATE TABLE IF NOT EXISTS seguranca_regras (
        tipo        TEXT    PRIMARY KEY,
        ativo       INTEGER DEFAULT 0,
        valor_int   INTEGER DEFAULT 0,
        valor_text  TEXT    DEFAULT '',
        updated_at  TEXT    DEFAULT (datetime('now','localtime'))
    )''')
    conn.execute('''CREATE TABLE IF NOT EXISTS precos_anp (
        id                   INTEGER PRIMARY KEY AUTOINCREMENT,
        mes                  TEXT    NOT NULL,
        produto              TEXT    NOT NULL,
        preco_medio_revenda  REAL    DEFAULT 0,
        preco_medio_distrib  REAL    DEFAULT 0,
        num_postos           INTEGER DEFAULT 0,
        updated_at           TEXT    DEFAULT (datetime('now','localtime')),
        UNIQUE(mes, produto)
    )''')
    conn.execute('''CREATE TABLE IF NOT EXISTS anp_sync_log (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        status     TEXT DEFAULT 'idle',
        message    TEXT DEFAULT '',
        started_at TEXT DEFAULT (datetime('now','localtime')),
        ended_at   TEXT DEFAULT ''
    )''')
    conn.execute('''CREATE TABLE IF NOT EXISTS produto_abastecido_regras (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        placas      TEXT    DEFAULT '["Todos"]',
        combustiveis TEXT   DEFAULT '[]',
        status      TEXT    DEFAULT 'Ativo',
        observacao  TEXT    DEFAULT '',
        created_at  TEXT    DEFAULT (datetime('now','localtime'))
    )''')
    conn.execute('''CREATE TABLE IF NOT EXISTS rotogramas (
        id                      INTEGER PRIMARY KEY AUTOINCREMENT,
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
        created_at              TEXT    DEFAULT (datetime('now','localtime'))
    )''')
    conn.execute('''CREATE TABLE IF NOT EXISTS rotograma_trechos (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        rotograma_id    INTEGER NOT NULL,
        ordem           INTEGER DEFAULT 0,
        descricao       TEXT    NOT NULL,
        rodovia         TEXT    DEFAULT '',
        km_inicial      REAL    DEFAULT 0,
        km_final        REAL    DEFAULT 0,
        velocidade_max  INTEGER DEFAULT 0,
        tem_cerca       INTEGER DEFAULT 0,
        observacao      TEXT    DEFAULT '',
        created_at      TEXT    DEFAULT (datetime('now','localtime'))
    )''')
    conn.execute('''CREATE TABLE IF NOT EXISTS rotograma_pontos_criticos (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        rotograma_id    INTEGER NOT NULL,
        tipo            TEXT    NOT NULL,
        descricao       TEXT    NOT NULL,
        km_referencia   TEXT    DEFAULT '',
        nivel_risco     TEXT    DEFAULT 'Médio',
        observacao      TEXT    DEFAULT '',
        created_at      TEXT    DEFAULT (datetime('now','localtime'))
    )''')
    conn.execute('''CREATE TABLE IF NOT EXISTS rotograma_pontos_apoio (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        rotograma_id    INTEGER NOT NULL,
        tipo            TEXT    NOT NULL,
        nome            TEXT    NOT NULL,
        km_referencia   TEXT    DEFAULT '',
        endereco        TEXT    DEFAULT '',
        telefone        TEXT    DEFAULT '',
        observacao      TEXT    DEFAULT '',
        created_at      TEXT    DEFAULT (datetime('now','localtime'))
    )''')
    conn.execute('''CREATE TABLE IF NOT EXISTS rotograma_execucoes (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        rotograma_id    INTEGER NOT NULL,
        placa           TEXT    DEFAULT '',
        motorista       TEXT    DEFAULT '',
        data            TEXT    NOT NULL,
        status_exec     TEXT    DEFAULT 'Concluída',
        observacao      TEXT    DEFAULT '',
        created_at      TEXT    DEFAULT (datetime('now','localtime'))
    )''')
    # ── Orçamento: Planos de Viagem ─────────────────────────────
    conn.execute('''CREATE TABLE IF NOT EXISTS planos_viagem (
        id                      INTEGER PRIMARY KEY AUTOINCREMENT,
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
        created_at              TEXT    DEFAULT (datetime('now','localtime'))
    )''')
    conn.execute('''CREATE TABLE IF NOT EXISTS planos_viagem_pedagios (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        plano_id        INTEGER NOT NULL,
        nome_praca      TEXT    DEFAULT '',
        km_referencia   TEXT    DEFAULT '',
        valor           REAL    DEFAULT 0,
        sentido         TEXT    DEFAULT 'Ambos',
        created_at      TEXT    DEFAULT (datetime('now','localtime'))
    )''')
    conn.execute('''CREATE TABLE IF NOT EXISTS hodo_variacao (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        tipo_veiculo    TEXT    NOT NULL,
        placa           TEXT    DEFAULT 'Todos',
        variacao_max_km INTEGER DEFAULT 0,
        status          TEXT    DEFAULT 'Ativo',
        observacao      TEXT    DEFAULT '',
        created_at      TEXT    DEFAULT (datetime('now','localtime'))
    )''')
    conn.execute('''CREATE TABLE IF NOT EXISTS negociacoes (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
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
        created_at       TEXT    DEFAULT (datetime('now','localtime')),
        updated_at       TEXT    DEFAULT (datetime('now','localtime'))
    )''')
    conn.execute('''CREATE TABLE IF NOT EXISTS roteirizador_rotas (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
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
        created_at        TEXT    DEFAULT (datetime('now','localtime'))
    )''')
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
    conn.execute("INSERT INTO anp_sync_log (status, message) VALUES ('running', 'Iniciando busca na ANP...')")
    conn.commit()
    log_id = conn.execute("SELECT MAX(id) FROM anp_sync_log").fetchone()[0]

    def _log(msg, status='running'):
        conn.execute("UPDATE anp_sync_log SET message=?, status=? WHERE id=?", [msg, status, log_id])
        conn.commit()

    try:
        ua = {'User-Agent': 'Mozilla/5.0 (compatible; GestaoFrotas/1.0; +https://github.com/gestaofrotas)'}

        # Descobre os recursos CSV no dados.gov.br (CKAN)
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
        )[:6]  # últimos 6 semestres ≈ 3 anos

        if not csv_res:
            _log('Nenhum CSV encontrado no catálogo ANP.', 'error')
            return

        monthly = {}  # {(mes, produto): {'soma_rev': x, 'soma_dist': x, 'n': n}}
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
                        # Suporte a nomes de colunas com variações de maiúsculas/acentos
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
                        # Filtra apenas combustíveis relevantes
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
            conn.execute('''INSERT OR REPLACE INTO precos_anp
                (mes, produto, preco_medio_revenda, preco_medio_distrib, num_postos, updated_at)
                VALUES (?, ?, ?, ?, ?, datetime('now','localtime'))
            ''', (mes, produto, round(v['soma_rev'] / n, 4), round(v['soma_dist'] / n, 4), n))
        conn.commit()

        _log(f'Concluído: {len(monthly)} meses/produtos atualizados '
             f'({total_rows:,} leituras processadas).', 'done')
    except Exception as e:
        _log(f'Erro inesperado: {e}', 'error')
    finally:
        conn.execute("UPDATE anp_sync_log SET ended_at=datetime('now','localtime') WHERE id=?", [log_id])
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
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')

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

    def do_GET(self):
        path = urlparse(self.path).path
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
        elif path == '/api/abastecimentos':
            conn = get_db()
            rows = conn.execute(
                'SELECT * FROM abastecimentos ORDER BY data DESC, hora DESC'
            ).fetchall()
            conn.close()
            result = []
            for r in rows:
                d = dict(r)
                svcs = d.get('servicos_abast') or '[]'
                try:
                    d['servicos_abast'] = json.loads(svcs)
                except Exception:
                    d['servicos_abast'] = []
                result.append(d)
            self.send_json(result)
        elif path == '/api/postos':
            conn = get_db()
            rows = conn.execute('SELECT * FROM postos ORDER BY razao').fetchall()
            conn.close()
            result = []
            for r in rows:
                d = dict(r)
                d['servicos'] = json.loads(d.get('servicos') or '[]')
                d['fotos']    = json.loads(d.get('fotos')    or '[]')
                # Normaliza combustiveis: aceita tanto {"Diesel": 6.29} quanto {"Diesel": {"preco": 6.29}}
                raw_combs = json.loads(d.get('combustiveis') or '{}')
                combs_norm = {}
                for k, v in raw_combs.items():
                    if isinstance(v, dict):
                        combs_norm[k] = v  # já no formato correto
                    elif isinstance(v, (int, float)):
                        combs_norm[k] = {'preco': v}  # migra formato legado
                d['combustiveis'] = combs_norm
                result.append(d)
            self.send_json(result)
        elif path == '/api/motoristas':
            conn = get_db()
            rows = conn.execute('SELECT * FROM motoristas ORDER BY nome').fetchall()
            conn.close()
            self.send_json([dict(r) for r in rows])
        elif path == '/api/veiculos':
            conn = get_db()
            rows = conn.execute('SELECT * FROM veiculos ORDER BY placa').fetchall()
            conn.close()
            self.send_json([dict(r) for r in rows])
        elif path == '/api/vinculos':
            conn = get_db()
            rows = conn.execute('SELECT * FROM vinculos ORDER BY data_inicio DESC').fetchall()
            conn.close()
            self.send_json([dict(r) for r in rows])
        elif path == '/api/intervalos':
            conn = get_db()
            rows = conn.execute('SELECT * FROM intervalos_abastecimento ORDER BY tipo, referencia').fetchall()
            conn.close()
            self.send_json([dict(r) for r in rows])
        elif path == '/api/valor-diario':
            conn = get_db()
            rows = conn.execute('SELECT * FROM valor_diario_motorista ORDER BY motorista').fetchall()
            conn.close()
            self.send_json([dict(r) for r in rows])
        elif path == '/api/volume-diario':
            conn = get_db()
            rows = conn.execute('SELECT * FROM volume_diario_veiculo ORDER BY placa').fetchall()
            conn.close()
            self.send_json([dict(r) for r in rows])
        elif path == '/api/produto-abastecido':
            conn = get_db()
            rows = conn.execute('SELECT * FROM produto_abastecido_regras ORDER BY id').fetchall()
            conn.close()
            self.send_json([dict(r) for r in rows])
        elif path == '/api/seguranca-regras':
            conn = get_db()
            rows = conn.execute('SELECT * FROM seguranca_regras').fetchall()
            conn.close()
            self.send_json([dict(r) for r in rows])
        elif path == '/api/precos-anp':
            qs = parse_qs(urlparse(self.path).query)
            produto = qs.get('produto', [None])[0]
            start   = qs.get('start',   [None])[0]
            end     = qs.get('end',     [None])[0]
            where, params = [], []
            if produto:
                where.append('produto = ?'); params.append(produto.upper())
            if start:
                where.append('mes >= ?');    params.append(start[:7])
            if end:
                where.append('mes <= ?');    params.append(end[:7])
            sql = 'SELECT * FROM precos_anp'
            if where:
                sql += ' WHERE ' + ' AND '.join(where)
            sql += ' ORDER BY mes, produto'
            conn = get_db()
            rows = conn.execute(sql, params).fetchall()
            conn.close()
            self.send_json([dict(r) for r in rows])
        elif path == '/api/precos-anp/status':
            conn = get_db()
            row = conn.execute(
                "SELECT * FROM anp_sync_log ORDER BY id DESC LIMIT 1"
            ).fetchone()
            conn.close()
            self.send_json(dict(row) if row else {'status': 'idle', 'message': ''})
        elif path == '/api/rotogramas':
            conn = get_db()
            rows = conn.execute('SELECT * FROM rotogramas ORDER BY nome').fetchall()
            conn.close()
            self.send_json([dict(r) for r in rows])
        elif re.match(r'^/api/rotogramas/(\d+)$', path):
            rid = int(re.match(r'^/api/rotogramas/(\d+)$', path).group(1))
            conn = get_db()
            row = conn.execute('SELECT * FROM rotogramas WHERE id=?', [rid]).fetchone()
            conn.close()
            self.send_json(dict(row) if row else {})
        elif re.match(r'^/api/rotograma-trechos/(\d+)$', path):
            rid = int(re.match(r'^/api/rotograma-trechos/(\d+)$', path).group(1))
            conn = get_db()
            rows = conn.execute('SELECT * FROM rotograma_trechos WHERE rotograma_id=? ORDER BY ordem, id', [rid]).fetchall()
            conn.close()
            self.send_json([dict(r) for r in rows])
        elif re.match(r'^/api/rotograma-pontos-criticos/(\d+)$', path):
            rid = int(re.match(r'^/api/rotograma-pontos-criticos/(\d+)$', path).group(1))
            conn = get_db()
            rows = conn.execute('SELECT * FROM rotograma_pontos_criticos WHERE rotograma_id=? ORDER BY nivel_risco DESC, id', [rid]).fetchall()
            conn.close()
            self.send_json([dict(r) for r in rows])
        elif re.match(r'^/api/rotograma-pontos-apoio/(\d+)$', path):
            rid = int(re.match(r'^/api/rotograma-pontos-apoio/(\d+)$', path).group(1))
            conn = get_db()
            rows = conn.execute('SELECT * FROM rotograma_pontos_apoio WHERE rotograma_id=? ORDER BY tipo, km_referencia', [rid]).fetchall()
            conn.close()
            self.send_json([dict(r) for r in rows])
        elif re.match(r'^/api/rotograma-execucoes/(\d+)$', path):
            rid = int(re.match(r'^/api/rotograma-execucoes/(\d+)$', path).group(1))
            conn = get_db()
            rows = conn.execute('SELECT * FROM rotograma_execucoes WHERE rotograma_id=? ORDER BY data DESC, id DESC', [rid]).fetchall()
            conn.close()
            self.send_json([dict(r) for r in rows])
        elif path == '/api/planos-viagem':
            conn = get_db()
            rows = conn.execute('''
                SELECT p.*, r.nome as rotograma_nome
                FROM planos_viagem p
                LEFT JOIN rotogramas r ON r.id = p.rotograma_id
                ORDER BY p.data_saida DESC, p.id DESC
            ''').fetchall()
            conn.close()
            self.send_json([dict(r) for r in rows])
        elif re.match(r'^/api/planos-viagem/(\d+)$', path):
            pid = int(re.match(r'^/api/planos-viagem/(\d+)$', path).group(1))
            conn = get_db()
            row = conn.execute('''
                SELECT p.*, r.nome as rotograma_nome
                FROM planos_viagem p
                LEFT JOIN rotogramas r ON r.id = p.rotograma_id
                WHERE p.id=?
            ''', [pid]).fetchone()
            conn.close()
            self.send_json(dict(row) if row else {})
        elif re.match(r'^/api/planos-viagem-pedagios/(\d+)$', path):
            pid = int(re.match(r'^/api/planos-viagem-pedagios/(\d+)$', path).group(1))
            conn = get_db()
            rows = conn.execute('SELECT * FROM planos_viagem_pedagios WHERE plano_id=? ORDER BY id', [pid]).fetchall()
            conn.close()
            self.send_json([dict(r) for r in rows])
        elif path == '/api/hodo-variacao':
            from urllib.parse import parse_qs, urlparse as _up
            qs   = parse_qs(_up(self.path).query)
            tipo = qs.get('tipo', [None])[0]
            conn = get_db()
            if tipo:
                rows = conn.execute('SELECT * FROM hodo_variacao WHERE tipo_veiculo=? ORDER BY placa', [tipo]).fetchall()
            else:
                rows = conn.execute('SELECT * FROM hodo_variacao ORDER BY tipo_veiculo, placa').fetchall()
            conn.close()
            self.send_json([dict(r) for r in rows])
        elif path == '/api/negociacoes':
            conn = get_db()
            rows = conn.execute('SELECT * FROM negociacoes ORDER BY created_at DESC').fetchall()
            conn.close()
            # Auto-update expired status
            today = __import__('datetime').date.today().isoformat()
            result = []
            for r in rows:
                d = dict(r)
                if d['status'] not in ('cancelada',) and d['data_fim'] and d['data_fim'] < today:
                    d['status'] = 'expirada'
                elif d['status'] not in ('cancelada', 'expirada') and d['data_inicio'] and d['data_inicio'] > today:
                    d['status'] = 'pendente'
                elif d['status'] not in ('cancelada', 'expirada', 'pendente'):
                    d['status'] = 'ativa'
                result.append(d)
            self.send_json(result)
        elif path == '/api/roteirizador-rotas':
            conn = get_db()
            rows = conn.execute('SELECT * FROM roteirizador_rotas ORDER BY created_at DESC').fetchall()
            conn.close()
            self.send_json([dict(r) for r in rows])
        elif path == '/api/planos-viagem-kpis':
            conn = get_db()
            kpis = {}
            kpis['total_planos']  = (conn.execute('SELECT COUNT(*) FROM planos_viagem').fetchone()[0] or 0)
            kpis['total_budget']  = (conn.execute('SELECT COALESCE(SUM(custo_total_estimado),0) FROM planos_viagem').fetchone()[0] or 0)
            kpis['media_custo_km']= (conn.execute("SELECT CASE WHEN SUM(km_estimado)>0 THEN SUM(custo_total_estimado)/SUM(km_estimado) ELSE 0 END FROM planos_viagem WHERE km_estimado>0").fetchone()[0] or 0)
            kpis['por_status']    = [dict(r) for r in conn.execute("SELECT status, COUNT(*) as qtd, COALESCE(SUM(custo_total_estimado),0) as total FROM planos_viagem GROUP BY status").fetchall()]
            kpis['por_veiculo']   = [dict(r) for r in conn.execute("SELECT placa, COUNT(*) as qtd, COALESCE(SUM(custo_total_estimado),0) as total, COALESCE(SUM(km_estimado),0) as km FROM planos_viagem WHERE placa!='' GROUP BY placa ORDER BY total DESC LIMIT 10").fetchall()]
            kpis['por_categoria'] = [dict(r) for r in conn.execute("SELECT COALESCE(SUM(custo_combustivel),0) as combustivel, COALESCE(SUM(custo_pedagio),0) as pedagio, COALESCE(SUM(custo_diarias),0) as diarias, COALESCE(SUM(custo_manutencao),0) as manutencao FROM planos_viagem").fetchall()]
            conn.close()
            self.send_json(kpis)
        elif path == '/api/status':
            self.send_json({'ok': True, 'db': DATABASE})
        else:
            self.send_json({'error': 'Not found'}, 404)

    def do_POST(self):
        path = urlparse(self.path).path
        d    = self.read_body()

        if path == '/api/abastecimentos':
            conn = get_db()
            cur  = conn.execute('''INSERT INTO abastecimentos
                (data,hora,placa,motorista,cpf_motorista,hodometro,
                 posto,cnpj_posto,cidade_posto,uf_posto,
                 combustivel,volume,preco_unitario,valor_total,
                 arla32_volume,arla32_preco,arla32_total,servicos_abast)
                VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)''', [
                d.get('data'),   d.get('hora'),   d.get('placa'),
                d.get('motorista'), d.get('cpfMotorista',''),
                d.get('hodometro',0), d.get('posto'),
                d.get('cnpjPosto',''), d.get('cidadePosto',''), d.get('ufPosto',''),
                d.get('combustivel'), d.get('volume',0),
                d.get('precoUnitario',0), d.get('valorTotal',0),
                d.get('arla32Volume',0), d.get('arla32Preco',0), d.get('arla32Total',0),
                json.dumps(d.get('servicosAbast',[]), ensure_ascii=False)
            ])
            conn.commit()
            new_id = cur.lastrowid
            conn.close()
            self.send_json({'id': new_id}, 201)

        elif path == '/api/abastecimentos/bulk':
            items = d if isinstance(d, list) else []
            conn  = get_db()
            for item in items:
                conn.execute('''INSERT INTO abastecimentos
                    (data,hora,placa,motorista,cpf_motorista,hodometro,
                     posto,cnpj_posto,cidade_posto,uf_posto,
                     combustivel,volume,preco_unitario,valor_total,
                     arla32_volume,arla32_preco,arla32_total,servicos_abast)
                    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)''', [
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
            cur  = conn.execute('''INSERT INTO postos
                (cnpj,razao,bandeira,cep,logradouro,numero,complemento,
                 bairro,cidade,uf,lat,lon,gestor,telefone,
                 email_resp,email_nf,banco,agencia,conta,
                 servicos,combustiveis,fotos,
                 perfil_venda,status_posto,situacao,rede,tipo_bandeira,
                 grupo_economico,taxa_admin,possui_internet,data_habilitacao)
                VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)''', [
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
            new_id = cur.lastrowid
            conn.close()
            self.send_json({'id': new_id}, 201)

        elif path == '/api/postos/bulk':
            items = d if isinstance(d, list) else []
            conn  = get_db()
            inseridos = 0
            for item in items:
                try:
                    conn.execute('''INSERT OR IGNORE INTO postos
                        (cnpj,razao,bandeira,cep,logradouro,numero,complemento,
                         bairro,cidade,uf,lat,lon,gestor,telefone,
                         email_resp,email_nf,banco,agencia,conta,
                         servicos,combustiveis,fotos,
                         perfil_venda,status_posto,situacao,rede,tipo_bandeira,
                         grupo_economico,taxa_admin,possui_internet,data_habilitacao)
                        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)''', [
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
                    pass
            conn.commit()
            conn.close()
            self.send_json({'ok': True, 'count': inseridos}, 201)

        elif path == '/api/motoristas':
            conn = get_db()
            try:
                cur = conn.execute('''INSERT INTO motoristas
                    (cpf,nome,status,classificacao,apelido,matricula,celular,email,num_cnh,vencimento_cnh)
                    VALUES (?,?,?,?,?,?,?,?,?,?)''', [
                    d.get('cpf',''), d.get('nome',''),
                    d.get('status','Ativo'), d.get('classificacao','Próprio'),
                    d.get('apelido',''), d.get('matricula',''), d.get('celular',''),
                    d.get('email',''), d.get('numCnh',''), d.get('vencimentoCnh','')
                ])
                conn.commit()
                new_id = cur.lastrowid
                conn.close()
                self.send_json({'id': new_id}, 201)
            except Exception as e:
                conn.close()
                self.send_json({'error': str(e)}, 409)

        elif path == '/api/veiculos':
            conn = get_db()
            try:
                cur = conn.execute('''INSERT INTO veiculos
                    (placa,chassi,status,classificacao,tipo,subtipo,num_eixos,
                     marca,modelo,motor,ano_fabricacao,ano_modelo,
                     capacidade_tanque,hodometro,renavam,combustivel_especificado)
                    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)''', [
                    d.get('placa','').upper(), d.get('chassi',''),
                    d.get('status','Ativo'), d.get('classificacao','Próprio'),
                    d.get('tipo','Leve'), d.get('subtipo','Passeio'),
                    d.get('numEixos',2),
                    d.get('marca',''), d.get('modelo',''), d.get('motor',''),
                    d.get('anoFabricacao') or None, d.get('anoModelo') or None,
                    d.get('capacidadeTanque',0), d.get('hodometro',0),
                    d.get('renavam',''), d.get('combustivelEspecificado','')
                ])
                conn.commit()
                new_id = cur.lastrowid
                conn.close()
                self.send_json({'id': new_id}, 201)
            except Exception as e:
                conn.close()
                self.send_json({'error': str(e)}, 409)

        elif path == '/api/vinculos':
            conn = get_db()
            cur  = conn.execute('''INSERT INTO vinculos
                (placa, motorista_nome, motorista_cpf, data_inicio, data_fim, status, observacao)
                VALUES (?,?,?,?,?,?,?)''', [
                d.get('placa','').upper(), d.get('motoristaNome',''),
                d.get('motoristaCpf',''), d.get('dataInicio',''),
                d.get('dataFim',''), d.get('status','Ativo'),
                d.get('observacao','')
            ])
            conn.commit()
            new_id = cur.lastrowid
            conn.close()
            self.send_json({'id': new_id}, 201)

        elif path == '/api/intervalos':
            conn = get_db()
            cur  = conn.execute('''INSERT INTO intervalos_abastecimento
                (tipo, referencia, intervalo_minimo, unidade, status, observacao)
                VALUES (?,?,?,?,?,?)''', [
                d.get('tipo',''), d.get('referencia','Todos'),
                d.get('intervaloMinimo', 0), d.get('unidade','Horas'),
                d.get('status','Ativo'), d.get('observacao','')
            ])
            conn.commit()
            new_id = cur.lastrowid
            conn.close()
            self.send_json({'id': new_id}, 201)

        elif path == '/api/valor-diario':
            conn = get_db()
            cur  = conn.execute('''INSERT INTO valor_diario_motorista
                (motorista, valor_max, status, observacao) VALUES (?,?,?,?)''', [
                d.get('motorista','Todos'), d.get('valorMax', 0),
                d.get('status','Ativo'),    d.get('observacao','')
            ])
            conn.commit()
            new_id = cur.lastrowid
            conn.close()
            self.send_json({'id': new_id}, 201)

        elif path == '/api/volume-diario':
            conn = get_db()
            cur  = conn.execute('''INSERT INTO volume_diario_veiculo
                (placa, volume_max, status, observacao) VALUES (?,?,?,?)''', [
                d.get('placa','Todos'), d.get('volumeMax', 0),
                d.get('status','Ativo'), d.get('observacao','')
            ])
            conn.commit()
            new_id = cur.lastrowid
            conn.close()
            self.send_json({'id': new_id}, 201)

        elif path == '/api/produto-abastecido':
            import json as _json
            conn = get_db()
            cur  = conn.execute('''INSERT INTO produto_abastecido_regras
                (placas, combustiveis, status, observacao) VALUES (?,?,?,?)''', [
                _json.dumps(d.get('placas', ['Todos'])),
                _json.dumps(d.get('combustiveis', [])),
                d.get('status', 'Ativo'),
                d.get('observacao', '')
            ])
            conn.commit()
            new_id = cur.lastrowid
            conn.close()
            self.send_json({'id': new_id}, 201)

        elif path == '/api/seguranca-regras':
            conn = get_db()
            conn.execute('''INSERT INTO seguranca_regras (tipo, ativo, valor_int, valor_text, updated_at)
                VALUES (?, ?, ?, ?, datetime('now','localtime'))
                ON CONFLICT(tipo) DO UPDATE SET
                    ativo=excluded.ativo,
                    valor_int=excluded.valor_int,
                    valor_text=excluded.valor_text,
                    updated_at=excluded.updated_at''', [
                d.get('tipo',''), int(d.get('ativo', 0)),
                int(d.get('valorInt', 0)), d.get('valorText','')
            ])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})

        elif path == '/api/rotogramas':
            conn = get_db()
            cur = conn.execute('''INSERT INTO rotogramas
                (nome,origem,destino,distancia_km,rodovias,estados,descricao,status,versao,ultima_revisao,observacao_seguranca)
                VALUES (?,?,?,?,?,?,?,?,?,?,?)''', [
                d.get('nome',''), d.get('origem',''), d.get('destino',''),
                d.get('distanciaKm', 0), d.get('rodovias',''), d.get('estados',''),
                d.get('descricao',''), d.get('status','Ativo'), d.get('versao','1.0'),
                d.get('ultimaRevisao',''), d.get('observacaoSeguranca','')
            ])
            conn.commit()
            new_id = cur.lastrowid
            conn.close()
            self.send_json({'id': new_id}, 201)

        elif path == '/api/rotograma-trechos':
            conn = get_db()
            cur = conn.execute('''INSERT INTO rotograma_trechos
                (rotograma_id,ordem,descricao,rodovia,km_inicial,km_final,velocidade_max,tem_cerca,observacao)
                VALUES (?,?,?,?,?,?,?,?,?)''', [
                d.get('rotogramaId'), d.get('ordem', 0), d.get('descricao',''),
                d.get('rodovia',''), d.get('kmInicial', 0), d.get('kmFinal', 0),
                d.get('velocidadeMax', 0), int(d.get('temCerca', 0)), d.get('observacao','')
            ])
            conn.commit()
            new_id = cur.lastrowid
            conn.close()
            self.send_json({'id': new_id}, 201)

        elif path == '/api/rotograma-pontos-criticos':
            conn = get_db()
            cur = conn.execute('''INSERT INTO rotograma_pontos_criticos
                (rotograma_id,tipo,descricao,km_referencia,nivel_risco,observacao)
                VALUES (?,?,?,?,?,?)''', [
                d.get('rotogramaId'), d.get('tipo',''), d.get('descricao',''),
                d.get('kmReferencia',''), d.get('nivelRisco','Médio'), d.get('observacao','')
            ])
            conn.commit()
            new_id = cur.lastrowid
            conn.close()
            self.send_json({'id': new_id}, 201)

        elif path == '/api/rotograma-pontos-apoio':
            conn = get_db()
            cur = conn.execute('''INSERT INTO rotograma_pontos_apoio
                (rotograma_id,tipo,nome,km_referencia,endereco,telefone,observacao)
                VALUES (?,?,?,?,?,?,?)''', [
                d.get('rotogramaId'), d.get('tipo',''), d.get('nome',''),
                d.get('kmReferencia',''), d.get('endereco',''),
                d.get('telefone',''), d.get('observacao','')
            ])
            conn.commit()
            new_id = cur.lastrowid
            conn.close()
            self.send_json({'id': new_id}, 201)

        elif path == '/api/rotograma-execucoes':
            conn = get_db()
            cur = conn.execute('''INSERT INTO rotograma_execucoes
                (rotograma_id,placa,motorista,data,status_exec,observacao)
                VALUES (?,?,?,?,?,?)''', [
                d.get('rotogramaId'), d.get('placa',''), d.get('motorista',''),
                d.get('data',''), d.get('statusExec','Concluída'), d.get('observacao','')
            ])
            conn.commit()
            new_id = cur.lastrowid
            conn.close()
            self.send_json({'id': new_id}, 201)

        elif path == '/api/hodo-variacao':
            conn = get_db()
            cur = conn.execute('''INSERT INTO hodo_variacao
                (tipo_veiculo,placa,variacao_max_km,status,observacao)
                VALUES (?,?,?,?,?)''', [
                d.get('tipoVeiculo',''), d.get('placa','Todos'),
                d.get('variacaoMaxKm',0), d.get('status','Ativo'),
                d.get('observacao','')
            ])
            conn.commit()
            new_id = cur.lastrowid
            conn.close()
            self.send_json({'id': new_id}, 201)

        elif path == '/api/planos-viagem':
            conn = get_db()
            cur = conn.execute('''INSERT INTO planos_viagem
                (nome,placa,motorista,rotograma_id,data_saida,data_retorno_prevista,
                 km_estimado,status,consumo_km_l,preco_combustivel,custo_combustivel,
                 custo_pedagio,num_diarias,valor_refeicao,valor_pernoite,valor_banho,
                 valor_lavagem,custo_diarias,custo_manutencao_km,custo_manutencao,
                 custo_total_estimado,custo_total_real,observacoes)
                VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)''', [
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
                d.get('observacoes','')
            ])
            conn.commit()
            new_id = cur.lastrowid
            conn.close()
            self.send_json({'id': new_id}, 201)

        elif path == '/api/planos-viagem-pedagios':
            conn = get_db()
            cur = conn.execute('''INSERT INTO planos_viagem_pedagios
                (plano_id,nome_praca,km_referencia,valor,sentido)
                VALUES (?,?,?,?,?)''', [
                d.get('planoId'), d.get('nomePraca',''), d.get('kmReferencia',''),
                d.get('valor',0), d.get('sentido','Ambos')
            ])
            conn.commit()
            new_id = cur.lastrowid
            conn.close()
            self.send_json({'id': new_id}, 201)

        elif path == '/api/negociacoes':
            conn = get_db()
            cur = conn.execute('''INSERT INTO negociacoes
                (posto_id,posto_nome,posto_cnpj,posto_cidade,posto_uf,
                 combustivel,preco_base,tipo_acordo,valor_acordo,preco_negociado,
                 volume_estimado,custo_estimado,data_inicio,data_fim,
                 status,justificativa,observacoes)
                VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)''', [
                d.get('postoId',0), d.get('postoNome',''), d.get('postoCnpj',''),
                d.get('postoCidade',''), d.get('postoUf',''),
                d.get('combustivel',''), d.get('precoBase',0),
                d.get('tipoAcordo','desconto_pct'), d.get('valorAcordo',0),
                d.get('precoNegociado',0), d.get('volumeEstimado',0),
                d.get('custoEstimado',0), d.get('dataInicio',''), d.get('dataFim',''),
                d.get('status','pendente'), d.get('justificativa',''), d.get('observacoes','')
            ])
            conn.commit()
            new_id = cur.lastrowid
            conn.close()
            self.send_json({'id': new_id}, 201)

        elif path == '/api/roteirizador-rotas':
            import json as _json
            conn = get_db()
            cur = conn.execute('''INSERT INTO roteirizador_rotas
                (nome,tipo_rota,origem,origem_lat,origem_lon,destino,destino_lat,destino_lon,
                 paradas,postos_rota,distancia_km,duracao_min,combustivel,placa,
                 litros_tanque,capacidade_tanque,media_consumo,custo_estimado,
                 filtros,geometria,status,observacao)
                VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)''', [
                d.get('nome',''), d.get('tipoRota','Personalizada'),
                d.get('origem',''), d.get('origemLat',0), d.get('origemLon',0),
                d.get('destino',''), d.get('destinoLat',0), d.get('destinoLon',0),
                _json.dumps(d.get('paradas',[])), _json.dumps(d.get('postosRota',[])),
                d.get('distanciaKm',0), d.get('duracaoMin',0),
                d.get('combustivel',''), d.get('placa',''),
                d.get('litrosTanque',0), d.get('capacidadeTanque',0),
                d.get('mediaConsumo',0), d.get('custoEstimado',0),
                _json.dumps(d.get('filtros',{})), d.get('geometria',''),
                d.get('status','Rascunho'), d.get('observacao','')
            ])
            conn.commit()
            new_id = cur.lastrowid
            conn.close()
            self.send_json({'id': new_id}, 201)

        elif path == '/api/motoristas/bulk-status':
            items = d if isinstance(d, list) else []
            conn = get_db()
            for item in items:
                conn.execute('UPDATE motoristas SET status=? WHERE id=?',
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

        else:
            self.send_json({'error': 'Not found'}, 404)

    def do_PUT(self):
        path = urlparse(self.path).path
        d    = self.read_body()

        m = re.match(r'^/api/abastecimentos/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            conn.execute('''UPDATE abastecimentos SET
                data=?,hora=?,placa=?,motorista=?,cpf_motorista=?,hodometro=?,
                posto=?,cnpj_posto=?,cidade_posto=?,uf_posto=?,
                combustivel=?,volume=?,preco_unitario=?,valor_total=?,
                arla32_volume=?,arla32_preco=?,arla32_total=?,servicos_abast=?
                WHERE id=?''', [
                d.get('data'),   d.get('hora'),   d.get('placa'),
                d.get('motorista'), d.get('cpfMotorista',''),
                d.get('hodometro',0), d.get('posto'),
                d.get('cnpjPosto',''), d.get('cidadePosto',''), d.get('ufPosto',''),
                d.get('combustivel'), d.get('volume',0),
                d.get('precoUnitario',0), d.get('valorTotal',0),
                d.get('arla32Volume',0), d.get('arla32Preco',0), d.get('arla32Total',0),
                json.dumps(d.get('servicosAbast',[]), ensure_ascii=False),
                id_
            ])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/postos/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            conn.execute('''UPDATE postos SET
                cnpj=?,razao=?,bandeira=?,cep=?,logradouro=?,numero=?,complemento=?,
                bairro=?,cidade=?,uf=?,lat=?,lon=?,gestor=?,telefone=?,
                email_resp=?,email_nf=?,banco=?,agencia=?,conta=?,
                servicos=?,combustiveis=?,fotos=?,
                perfil_venda=?,status_posto=?,situacao=?,rede=?,tipo_bandeira=?,
                grupo_economico=?,taxa_admin=?,possui_internet=?,data_habilitacao=?
                WHERE id=?''', [
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
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/motoristas/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            conn.execute('''UPDATE motoristas SET
                cpf=?,nome=?,status=?,classificacao=?,apelido=?,matricula=?,celular=?,
                email=?,num_cnh=?,vencimento_cnh=? WHERE id=?''', [
                d.get('cpf',''), d.get('nome',''),
                d.get('status','Ativo'), d.get('classificacao','Próprio'),
                d.get('apelido',''), d.get('matricula',''), d.get('celular',''),
                d.get('email',''), d.get('numCnh',''), d.get('vencimentoCnh',''), id_
            ])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/veiculos/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            conn.execute('''UPDATE veiculos SET
                placa=?,chassi=?,status=?,classificacao=?,tipo=?,subtipo=?,num_eixos=?,
                marca=?,modelo=?,motor=?,ano_fabricacao=?,ano_modelo=?,
                capacidade_tanque=?,hodometro=?,renavam=?,combustivel_especificado=?
                WHERE id=?''', [
                d.get('placa','').upper(), d.get('chassi',''),
                d.get('status','Ativo'), d.get('classificacao','Próprio'),
                d.get('tipo','Leve'), d.get('subtipo','Passeio'),
                d.get('numEixos',2),
                d.get('marca',''), d.get('modelo',''), d.get('motor',''),
                d.get('anoFabricacao') or None, d.get('anoModelo') or None,
                d.get('capacidadeTanque',0), d.get('hodometro',0),
                d.get('renavam',''), d.get('combustivelEspecificado',''), id_
            ])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/vinculos/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            conn.execute('''UPDATE vinculos SET
                placa=?, motorista_nome=?, motorista_cpf=?,
                data_inicio=?, data_fim=?, status=?, observacao=?
                WHERE id=?''', [
                d.get('placa','').upper(), d.get('motoristaNome',''),
                d.get('motoristaCpf',''), d.get('dataInicio',''),
                d.get('dataFim',''), d.get('status','Ativo'),
                d.get('observacao',''), id_
            ])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/intervalos/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            conn.execute('''UPDATE intervalos_abastecimento SET
                tipo=?, referencia=?, intervalo_minimo=?, unidade=?, status=?, observacao=?
                WHERE id=?''', [
                d.get('tipo',''), d.get('referencia','Todos'),
                d.get('intervaloMinimo', 0), d.get('unidade','Horas'),
                d.get('status','Ativo'), d.get('observacao',''), id_
            ])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/valor-diario/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            conn.execute('''UPDATE valor_diario_motorista SET
                motorista=?, valor_max=?, status=?, observacao=? WHERE id=?''', [
                d.get('motorista','Todos'), d.get('valorMax', 0),
                d.get('status','Ativo'), d.get('observacao',''), id_
            ])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/volume-diario/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            conn.execute('''UPDATE volume_diario_veiculo SET
                placa=?, volume_max=?, status=?, observacao=? WHERE id=?''', [
                d.get('placa','Todos'), d.get('volumeMax', 0),
                d.get('status','Ativo'), d.get('observacao',''), id_
            ])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/produto-abastecido/(\d+)$', path)
        if m:
            import json as _json
            id_ = int(m.group(1))
            conn = get_db()
            conn.execute('''UPDATE produto_abastecido_regras SET
                placas=?, combustiveis=?, status=?, observacao=? WHERE id=?''', [
                _json.dumps(d.get('placas', ['Todos'])),
                _json.dumps(d.get('combustiveis', [])),
                d.get('status', 'Ativo'),
                d.get('observacao', ''), id_
            ])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/rotogramas/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            conn.execute('''UPDATE rotogramas SET
                nome=?,origem=?,destino=?,distancia_km=?,rodovias=?,estados=?,
                descricao=?,status=?,versao=?,ultima_revisao=?,observacao_seguranca=?
                WHERE id=?''', [
                d.get('nome',''), d.get('origem',''), d.get('destino',''),
                d.get('distanciaKm', 0), d.get('rodovias',''), d.get('estados',''),
                d.get('descricao',''), d.get('status','Ativo'), d.get('versao','1.0'),
                d.get('ultimaRevisao',''), d.get('observacaoSeguranca',''), id_
            ])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/rotograma-trechos/item/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            conn.execute('''UPDATE rotograma_trechos SET
                ordem=?,descricao=?,rodovia=?,km_inicial=?,km_final=?,velocidade_max=?,tem_cerca=?,observacao=?
                WHERE id=?''', [
                d.get('ordem', 0), d.get('descricao',''), d.get('rodovia',''),
                d.get('kmInicial', 0), d.get('kmFinal', 0), d.get('velocidadeMax', 0),
                int(d.get('temCerca', 0)), d.get('observacao',''), id_
            ])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/rotograma-pontos-criticos/item/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            conn.execute('''UPDATE rotograma_pontos_criticos SET
                tipo=?,descricao=?,km_referencia=?,nivel_risco=?,observacao=? WHERE id=?''', [
                d.get('tipo',''), d.get('descricao',''), d.get('kmReferencia',''),
                d.get('nivelRisco','Médio'), d.get('observacao',''), id_
            ])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/rotograma-pontos-apoio/item/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            conn.execute('''UPDATE rotograma_pontos_apoio SET
                tipo=?,nome=?,km_referencia=?,endereco=?,telefone=?,observacao=? WHERE id=?''', [
                d.get('tipo',''), d.get('nome',''), d.get('kmReferencia',''),
                d.get('endereco',''), d.get('telefone',''), d.get('observacao',''), id_
            ])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/hodo-variacao/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            conn.execute('''UPDATE hodo_variacao SET
                tipo_veiculo=?,placa=?,variacao_max_km=?,status=?,observacao=? WHERE id=?''', [
                d.get('tipoVeiculo',''), d.get('placa','Todos'),
                d.get('variacaoMaxKm',0), d.get('status','Ativo'),
                d.get('observacao',''), id_
            ])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/negociacoes/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            conn.execute('''UPDATE negociacoes SET
                posto_id=?,posto_nome=?,posto_cnpj=?,posto_cidade=?,posto_uf=?,
                combustivel=?,preco_base=?,tipo_acordo=?,valor_acordo=?,preco_negociado=?,
                volume_estimado=?,custo_estimado=?,data_inicio=?,data_fim=?,
                status=?,justificativa=?,observacoes=?,
                updated_at=datetime('now','localtime') WHERE id=?''', [
                d.get('postoId',0), d.get('postoNome',''), d.get('postoCnpj',''),
                d.get('postoCidade',''), d.get('postoUf',''),
                d.get('combustivel',''), d.get('precoBase',0),
                d.get('tipoAcordo','desconto_pct'), d.get('valorAcordo',0),
                d.get('precoNegociado',0), d.get('volumeEstimado',0),
                d.get('custoEstimado',0), d.get('dataInicio',''), d.get('dataFim',''),
                d.get('status','pendente'), d.get('justificativa',''), d.get('observacoes',''),
                id_
            ])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/roteirizador-rotas/(\d+)$', path)
        if m:
            import json as _json
            id_ = int(m.group(1))
            conn = get_db()
            conn.execute('''UPDATE roteirizador_rotas SET
                nome=?,tipo_rota=?,origem=?,origem_lat=?,origem_lon=?,
                destino=?,destino_lat=?,destino_lon=?,paradas=?,postos_rota=?,
                distancia_km=?,duracao_min=?,combustivel=?,placa=?,
                litros_tanque=?,capacidade_tanque=?,media_consumo=?,custo_estimado=?,
                filtros=?,geometria=?,status=?,observacao=? WHERE id=?''', [
                d.get('nome',''), d.get('tipoRota','Personalizada'),
                d.get('origem',''), d.get('origemLat',0), d.get('origemLon',0),
                d.get('destino',''), d.get('destinoLat',0), d.get('destinoLon',0),
                _json.dumps(d.get('paradas',[])), _json.dumps(d.get('postosRota',[])),
                d.get('distanciaKm',0), d.get('duracaoMin',0),
                d.get('combustivel',''), d.get('placa',''),
                d.get('litrosTanque',0), d.get('capacidadeTanque',0),
                d.get('mediaConsumo',0), d.get('custoEstimado',0),
                _json.dumps(d.get('filtros',{})), d.get('geometria',''),
                d.get('status','Rascunho'), d.get('observacao',''), id_
            ])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/rotograma-execucoes/item/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            conn.execute('''UPDATE rotograma_execucoes SET
                data=?,placa=?,motorista=?,status_exec=?,observacao=? WHERE id=?''', [
                d.get('data',''), d.get('placa',''), d.get('motorista',''),
                d.get('statusExec',''), d.get('observacao',''), id_
            ])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/planos-viagem/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            conn.execute('''UPDATE planos_viagem SET
                nome=?,placa=?,motorista=?,rotograma_id=?,data_saida=?,data_retorno_prevista=?,
                km_estimado=?,status=?,consumo_km_l=?,preco_combustivel=?,custo_combustivel=?,
                custo_pedagio=?,num_diarias=?,valor_refeicao=?,valor_pernoite=?,valor_banho=?,
                valor_lavagem=?,custo_diarias=?,custo_manutencao_km=?,custo_manutencao=?,
                custo_total_estimado=?,custo_total_real=?,observacoes=? WHERE id=?''', [
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
                d.get('observacoes',''), id_
            ])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/planos-viagem-pedagios/item/(\d+)$', path)
        if m:
            id_ = int(m.group(1))
            conn = get_db()
            conn.execute('''UPDATE planos_viagem_pedagios SET
                nome_praca=?,km_referencia=?,valor=?,sentido=? WHERE id=?''', [
                d.get('nomePraca',''), d.get('kmReferencia',''),
                d.get('valor',0), d.get('sentido','Ambos'), id_
            ])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        self.send_json({'error': 'Not found'}, 404)

    def do_DELETE(self):
        path = urlparse(self.path).path

        if path == '/api/abastecimentos':
            conn = get_db()
            n = conn.execute('SELECT COUNT(*) FROM abastecimentos').fetchone()[0]
            conn.execute('DELETE FROM abastecimentos')
            conn.execute("DELETE FROM sqlite_sequence WHERE name='abastecimentos'")
            conn.commit()
            conn.close()
            self.send_json({'ok': True, 'deleted': n})
            return

        m = re.match(r'^/api/abastecimentos/(\d+)$', path)
        if m:
            conn = get_db()
            conn.execute('DELETE FROM abastecimentos WHERE id=?', [int(m.group(1))])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        if path == '/api/postos':
            conn = get_db()
            conn.execute('DELETE FROM postos')
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/postos/(\d+)$', path)
        if m:
            conn = get_db()
            conn.execute('DELETE FROM postos WHERE id=?', [int(m.group(1))])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/motoristas/(\d+)$', path)
        if m:
            conn = get_db()
            conn.execute('DELETE FROM motoristas WHERE id=?', [int(m.group(1))])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/veiculos/(\d+)$', path)
        if m:
            conn = get_db()
            conn.execute('DELETE FROM veiculos WHERE id=?', [int(m.group(1))])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/vinculos/(\d+)$', path)
        if m:
            conn = get_db()
            conn.execute('DELETE FROM vinculos WHERE id=?', [int(m.group(1))])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/intervalos/(\d+)$', path)
        if m:
            conn = get_db()
            conn.execute('DELETE FROM intervalos_abastecimento WHERE id=?', [int(m.group(1))])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/valor-diario/(\d+)$', path)
        if m:
            conn = get_db()
            conn.execute('DELETE FROM valor_diario_motorista WHERE id=?', [int(m.group(1))])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/volume-diario/(\d+)$', path)
        if m:
            conn = get_db()
            conn.execute('DELETE FROM volume_diario_veiculo WHERE id=?', [int(m.group(1))])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/produto-abastecido/(\d+)$', path)
        if m:
            conn = get_db()
            conn.execute('DELETE FROM produto_abastecido_regras WHERE id=?', [int(m.group(1))])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/rotogramas/(\d+)$', path)
        if m:
            rid = int(m.group(1))
            conn = get_db()
            conn.execute('DELETE FROM rotogramas WHERE id=?', [rid])
            conn.execute('DELETE FROM rotograma_trechos WHERE rotograma_id=?', [rid])
            conn.execute('DELETE FROM rotograma_pontos_criticos WHERE rotograma_id=?', [rid])
            conn.execute('DELETE FROM rotograma_pontos_apoio WHERE rotograma_id=?', [rid])
            conn.execute('DELETE FROM rotograma_execucoes WHERE rotograma_id=?', [rid])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/rotograma-trechos/item/(\d+)$', path)
        if m:
            conn = get_db()
            conn.execute('DELETE FROM rotograma_trechos WHERE id=?', [int(m.group(1))])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/rotograma-pontos-criticos/item/(\d+)$', path)
        if m:
            conn = get_db()
            conn.execute('DELETE FROM rotograma_pontos_criticos WHERE id=?', [int(m.group(1))])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/rotograma-pontos-apoio/item/(\d+)$', path)
        if m:
            conn = get_db()
            conn.execute('DELETE FROM rotograma_pontos_apoio WHERE id=?', [int(m.group(1))])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/rotograma-execucoes/item/(\d+)$', path)
        if m:
            conn = get_db()
            conn.execute('DELETE FROM rotograma_execucoes WHERE id=?', [int(m.group(1))])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/hodo-variacao/(\d+)$', path)
        if m:
            conn = get_db()
            conn.execute('DELETE FROM hodo_variacao WHERE id=?', [int(m.group(1))])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/planos-viagem/(\d+)$', path)
        if m:
            conn = get_db()
            pid = int(m.group(1))
            conn.execute('DELETE FROM planos_viagem_pedagios WHERE plano_id=?', [pid])
            conn.execute('DELETE FROM planos_viagem WHERE id=?', [pid])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/planos-viagem-pedagios/item/(\d+)$', path)
        if m:
            conn = get_db()
            conn.execute('DELETE FROM planos_viagem_pedagios WHERE id=?', [int(m.group(1))])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/roteirizador-rotas/(\d+)$', path)
        if m:
            conn = get_db()
            conn.execute('DELETE FROM roteirizador_rotas WHERE id=?', [int(m.group(1))])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

        m = re.match(r'^/api/negociacoes/(\d+)$', path)
        if m:
            conn = get_db()
            conn.execute('DELETE FROM negociacoes WHERE id=?', [int(m.group(1))])
            conn.commit()
            conn.close()
            self.send_json({'ok': True})
            return

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
    print(f'  ║  Banco:    gestao_frota.db               ║')
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
