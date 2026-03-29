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
import sqlite3, json, os, re, sys
from urllib.parse import urlparse

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
        created_at      TEXT    DEFAULT (datetime('now','localtime'))
    )''')
    conn.execute('''CREATE TABLE IF NOT EXISTS postos (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        cnpj        TEXT    NOT NULL,
        razao       TEXT    NOT NULL,
        bandeira    TEXT    NOT NULL,
        cep         TEXT    DEFAULT '',
        logradouro  TEXT    DEFAULT '',
        numero      TEXT    DEFAULT '',
        complemento TEXT    DEFAULT '',
        bairro      TEXT    DEFAULT '',
        cidade      TEXT    DEFAULT '',
        uf          TEXT    DEFAULT '',
        lat         TEXT    DEFAULT '',
        lon         TEXT    DEFAULT '',
        gestor      TEXT    DEFAULT '',
        telefone    TEXT    DEFAULT '',
        email_resp  TEXT    DEFAULT '',
        email_nf    TEXT    DEFAULT '',
        banco       TEXT    DEFAULT '',
        agencia     TEXT    DEFAULT '',
        conta       TEXT    DEFAULT '',
        servicos    TEXT    DEFAULT '[]',
        combustiveis TEXT   DEFAULT '{}',
        fotos       TEXT    DEFAULT '[]',
        created_at  TEXT    DEFAULT (datetime('now','localtime'))
    )''')
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
        created_at          TEXT    DEFAULT (datetime('now','localtime'))
    )''')
    conn.commit()
    conn.close()

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
        elif path == '/api/abastecimentos':
            conn = get_db()
            rows = conn.execute(
                'SELECT * FROM abastecimentos ORDER BY data DESC, hora DESC'
            ).fetchall()
            conn.close()
            self.send_json([dict(r) for r in rows])
        elif path == '/api/postos':
            conn = get_db()
            rows = conn.execute('SELECT * FROM postos ORDER BY razao').fetchall()
            conn.close()
            result = []
            for r in rows:
                d = dict(r)
                d['servicos']     = json.loads(d.get('servicos')     or '[]')
                d['combustiveis'] = json.loads(d.get('combustiveis') or '{}')
                d['fotos']        = json.loads(d.get('fotos')        or '[]')
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
                 combustivel,volume,preco_unitario,valor_total)
                VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)''', [
                d.get('data'),   d.get('hora'),   d.get('placa'),
                d.get('motorista'), d.get('cpfMotorista',''),
                d.get('hodometro',0), d.get('posto'),
                d.get('cnpjPosto',''), d.get('cidadePosto',''), d.get('ufPosto',''),
                d.get('combustivel'), d.get('volume',0),
                d.get('precoUnitario',0), d.get('valorTotal',0)
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
                     combustivel,volume,preco_unitario,valor_total)
                    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)''', [
                    item.get('data'),    item.get('hora'),    item.get('placa'),
                    item.get('motorista'), item.get('cpfMotorista',''),
                    item.get('hodometro',0), item.get('posto'),
                    item.get('cnpjPosto',''), item.get('cidadePosto',''), item.get('ufPosto',''),
                    item.get('combustivel'), item.get('volume',0),
                    item.get('precoUnitario',0), item.get('valorTotal',0)
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
                 servicos,combustiveis,fotos)
                VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)''', [
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
                json.dumps(d.get('fotos',[]),         ensure_ascii=False)
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
                         servicos,combustiveis,fotos)
                        VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)''', [
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
                     capacidade_tanque,hodometro,renavam)
                    VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)''', [
                    d.get('placa','').upper(), d.get('chassi',''),
                    d.get('status','Ativo'), d.get('classificacao','Próprio'),
                    d.get('tipo','Leve'), d.get('subtipo','Passeio'),
                    d.get('numEixos',2),
                    d.get('marca',''), d.get('modelo',''), d.get('motor',''),
                    d.get('anoFabricacao') or None, d.get('anoModelo') or None,
                    d.get('capacidadeTanque',0), d.get('hodometro',0),
                    d.get('renavam','')
                ])
                conn.commit()
                new_id = cur.lastrowid
                conn.close()
                self.send_json({'id': new_id}, 201)
            except Exception as e:
                conn.close()
                self.send_json({'error': str(e)}, 409)

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
                combustivel=?,volume=?,preco_unitario=?,valor_total=?
                WHERE id=?''', [
                d.get('data'),   d.get('hora'),   d.get('placa'),
                d.get('motorista'), d.get('cpfMotorista',''),
                d.get('hodometro',0), d.get('posto'),
                d.get('cnpjPosto',''), d.get('cidadePosto',''), d.get('ufPosto',''),
                d.get('combustivel'), d.get('volume',0),
                d.get('precoUnitario',0), d.get('valorTotal',0), id_
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
                servicos=?,combustiveis=?,fotos=? WHERE id=?''', [
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
                capacidade_tanque=?,hodometro=?,renavam=?
                WHERE id=?''', [
                d.get('placa','').upper(), d.get('chassi',''),
                d.get('status','Ativo'), d.get('classificacao','Próprio'),
                d.get('tipo','Leve'), d.get('subtipo','Passeio'),
                d.get('numEixos',2),
                d.get('marca',''), d.get('modelo',''), d.get('motor',''),
                d.get('anoFabricacao') or None, d.get('anoModelo') or None,
                d.get('capacidadeTanque',0), d.get('hodometro',0),
                d.get('renavam',''), id_
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
