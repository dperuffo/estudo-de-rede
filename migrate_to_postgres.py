#!/usr/bin/env python3
"""
═══════════════════════════════════════════════════════════════
  MIGRAÇÃO  SQLite → PostgreSQL
  Gestão de Abastecimentos de Frota
═══════════════════════════════════════════════════════════════
  Uso:
    python3 migrate_to_postgres.py [caminho_sqlite.db]

  Se o caminho não for informado, procura automaticamente por
  'gestao_frota.db' na mesma pasta deste script.

  Variáveis de ambiente (opcionais, usam defaults abaixo):
    PG_HOST      = localhost
    PG_PORT      = 5432
    PG_DBNAME    = gestao_frota
    PG_USER      = gestao_frota
    PG_PASSWORD  = gestao_frota
═══════════════════════════════════════════════════════════════
"""
import sqlite3
import psycopg2
import psycopg2.extras
import sys
import os

# ──────────────────────────────────────────────────────────────
#  Configuração PostgreSQL
# ──────────────────────────────────────────────────────────────
PG_HOST = os.environ.get('PG_HOST',     'localhost')
PG_PORT = int(os.environ.get('PG_PORT', '5432'))
PG_NAME = os.environ.get('PG_DBNAME',  'gestao_frota')
PG_USER = os.environ.get('PG_USER',    'gestao_frota')
PG_PASS = os.environ.get('PG_PASSWORD','gestao_frota')

# ──────────────────────────────────────────────────────────────
#  Tabelas e respectivas colunas  (ordem importa para INSERT)
#  Tabelas com SERIAL têm sequência resetada ao final.
#  seguranca_regras usa TEXT PK — sem SERIAL.
# ──────────────────────────────────────────────────────────────
TABLES = [
    {
        'name': 'abastecimentos',
        'serial': True,
        'columns': [
            'id','data','hora','placa','motorista','cpf_motorista','hodometro',
            'posto','cnpj_posto','cidade_posto','uf_posto','combustivel','volume',
            'preco_unitario','valor_total','arla32_volume','arla32_preco',
            'arla32_total','servicos_abast','created_at',
        ],
    },
    {
        'name': 'postos',
        'serial': True,
        'columns': [
            'id','cnpj','razao','bandeira','cep','logradouro','numero','complemento',
            'bairro','cidade','uf','lat','lon','gestor','telefone','email_resp',
            'email_nf','banco','agencia','conta','servicos','combustiveis','fotos',
            'perfil_venda','status_posto','situacao','rede','tipo_bandeira',
            'grupo_economico','taxa_admin','possui_internet','data_habilitacao',
            'created_at',
        ],
    },
    {
        'name': 'motoristas',
        'serial': True,
        'columns': [
            'id','cpf','nome','status','classificacao','apelido','matricula',
            'celular','email','num_cnh','vencimento_cnh','created_at',
        ],
    },
    {
        'name': 'veiculos',
        'serial': True,
        'columns': [
            'id','placa','chassi','status','classificacao','tipo','subtipo',
            'num_eixos','marca','modelo','motor','ano_fabricacao','ano_modelo',
            'capacidade_tanque','hodometro','renavam','combustivel_especificado',
            'created_at',
        ],
    },
    {
        'name': 'vinculos',
        'serial': True,
        'columns': [
            'id','placa','motorista_nome','motorista_cpf','data_inicio','data_fim',
            'status','observacao','created_at',
        ],
    },
    {
        'name': 'intervalos_abastecimento',
        'serial': True,
        'columns': [
            'id','tipo','referencia','intervalo_minimo','unidade','status',
            'observacao','created_at',
        ],
    },
    {
        'name': 'valor_diario_motorista',
        'serial': True,
        'columns': ['id','motorista','valor_max','status','observacao','created_at'],
    },
    {
        'name': 'volume_diario_veiculo',
        'serial': True,
        'columns': ['id','placa','volume_max','status','observacao','created_at'],
    },
    {
        # TEXT primary key — sem SERIAL, sem reset de sequência
        'name': 'seguranca_regras',
        'serial': False,
        'columns': ['tipo','ativo','valor_int','valor_text','updated_at'],
    },
    {
        'name': 'precos_anp',
        'serial': True,
        'columns': [
            'id','mes','produto','preco_medio_revenda','preco_medio_distrib',
            'num_postos','updated_at',
        ],
    },
    {
        'name': 'anp_sync_log',
        'serial': True,
        'columns': ['id','status','message','started_at','ended_at'],
    },
    {
        'name': 'produto_abastecido_regras',
        'serial': True,
        'columns': ['id','placas','combustiveis','status','observacao','created_at'],
    },
    {
        'name': 'rotogramas',
        'serial': True,
        'columns': [
            'id','nome','origem','destino','distancia_km','rodovias','estados',
            'descricao','status','versao','ultima_revisao','observacao_seguranca',
            'created_at',
        ],
    },
    {
        'name': 'rotograma_trechos',
        'serial': True,
        'columns': [
            'id','rotograma_id','ordem','descricao','rodovia','km_inicial',
            'km_final','velocidade_max','tem_cerca','observacao','created_at',
        ],
    },
    {
        'name': 'rotograma_pontos_criticos',
        'serial': True,
        'columns': [
            'id','rotograma_id','tipo','descricao','km_referencia','nivel_risco',
            'observacao','created_at',
        ],
    },
    {
        'name': 'rotograma_pontos_apoio',
        'serial': True,
        'columns': [
            'id','rotograma_id','tipo','nome','km_referencia','endereco',
            'telefone','observacao','created_at',
        ],
    },
    {
        'name': 'rotograma_execucoes',
        'serial': True,
        'columns': [
            'id','rotograma_id','placa','motorista','data','status_exec',
            'observacao','created_at',
        ],
    },
    {
        'name': 'planos_viagem',
        'serial': True,
        'columns': [
            'id','nome','placa','motorista','rotograma_id','data_saida',
            'data_retorno_prevista','km_estimado','status','consumo_km_l',
            'preco_combustivel','custo_combustivel','custo_pedagio','num_diarias',
            'valor_refeicao','valor_pernoite','valor_banho','valor_lavagem',
            'custo_diarias','custo_manutencao_km','custo_manutencao',
            'custo_total_estimado','custo_total_real','observacoes','created_at',
        ],
    },
    {
        'name': 'planos_viagem_pedagios',
        'serial': True,
        'columns': [
            'id','plano_id','nome_praca','km_referencia','valor','sentido',
            'created_at',
        ],
    },
    {
        'name': 'hodo_variacao',
        'serial': True,
        'columns': [
            'id','tipo_veiculo','placa','variacao_max_km','status','observacao',
            'created_at',
        ],
    },
    {
        'name': 'negociacoes',
        'serial': True,
        'columns': [
            'id','posto_id','posto_nome','posto_cnpj','posto_cidade','posto_uf',
            'combustivel','preco_base','tipo_acordo','valor_acordo','preco_negociado',
            'volume_estimado','custo_estimado','data_inicio','data_fim','status',
            'justificativa','observacoes','created_at','updated_at',
        ],
    },
    {
        'name': 'roteirizador_rotas',
        'serial': True,
        'columns': [
            'id','nome','tipo_rota','origem','origem_lat','origem_lon','destino',
            'destino_lat','destino_lon','paradas','postos_rota','distancia_km',
            'duracao_min','combustivel','placa','litros_tanque','capacidade_tanque',
            'media_consumo','custo_estimado','filtros','geometria','status',
            'observacao','created_at',
        ],
    },
]


# ──────────────────────────────────────────────────────────────
#  Helpers
# ──────────────────────────────────────────────────────────────
RESET  = '\033[0m'
GREEN  = '\033[32m'
YELLOW = '\033[33m'
RED    = '\033[31m'
CYAN   = '\033[36m'
BOLD   = '\033[1m'

def ok(msg):    print(f"  {GREEN}✔{RESET}  {msg}")
def warn(msg):  print(f"  {YELLOW}⚠{RESET}  {msg}")
def err(msg):   print(f"  {RED}✘{RESET}  {msg}")
def info(msg):  print(f"  {CYAN}→{RESET}  {msg}")
def header(msg):print(f"\n{BOLD}{msg}{RESET}")


def sqlite_table_exists(sq_cur, table):
    sq_cur.execute(
        "SELECT count(*) FROM sqlite_master WHERE type='table' AND name=?", (table,)
    )
    return sq_cur.fetchone()[0] > 0


def sqlite_columns(sq_cur, table):
    """Retorna a lista de nomes de colunas da tabela SQLite."""
    sq_cur.execute(f'PRAGMA table_info("{table}")')
    return [row[1] for row in sq_cur.fetchall()]


def migrate_table(sq_conn, pg_conn, tbl):
    table   = tbl['name']
    columns = tbl['columns']
    serial  = tbl['serial']

    sq_cur = sq_conn.cursor()

    # ── Verifica se a tabela existe no SQLite ──────────────────
    if not sqlite_table_exists(sq_cur, table):
        warn(f"[{table}] não existe no SQLite — pulando")
        return 0

    # ── Colunas presentes no SQLite ────────────────────────────
    sq_cols = sqlite_columns(sq_cur, table)

    # Filtra apenas as colunas que existem em AMBOS os lados
    cols_to_migrate = [c for c in columns if c in sq_cols]
    missing = [c for c in columns if c not in sq_cols]
    if missing:
        warn(f"[{table}] colunas ausentes no SQLite (serão ignoradas): {missing}")

    # ── Lê todos os dados do SQLite ────────────────────────────
    col_list = ', '.join(f'"{c}"' for c in cols_to_migrate)
    sq_cur.execute(f'SELECT {col_list} FROM "{table}"')
    rows = sq_cur.fetchall()

    if not rows:
        ok(f"[{table}] vazia — nenhum dado para migrar")
        return 0

    # ── Prepara INSERT PostgreSQL ──────────────────────────────
    pg_cur = pg_conn.cursor()

    # Limpa a tabela no destino antes de inserir
    pg_cur.execute(f'DELETE FROM "{table}"')

    ph      = ', '.join(['%s'] * len(cols_to_migrate))
    col_sql = ', '.join(f'"{c}"' for c in cols_to_migrate)

    if serial and 'id' in cols_to_migrate:
        # OVERRIDING SYSTEM VALUE preserva os IDs originais do SQLite
        insert_sql = (
            f'INSERT INTO "{table}" ({col_sql}) '
            f'OVERRIDING SYSTEM VALUE VALUES ({ph})'
        )
    else:
        insert_sql = f'INSERT INTO "{table}" ({col_sql}) VALUES ({ph})'

    # ── Insere linha a linha (compatível com qualquer versão) ──
    inserted = 0
    errors   = 0
    for row in rows:
        try:
            pg_cur.execute(insert_sql, list(row))
            inserted += 1
        except Exception as e:
            errors += 1
            if errors <= 3:
                warn(f"[{table}] erro na linha id={row[0] if row else '?'}: {e}")
            pg_conn.rollback()
            # Reabre cursor após rollback
            pg_cur = pg_conn.cursor()
            continue

    pg_conn.commit()

    if errors:
        warn(f"[{table}] {inserted} migradas, {errors} com erro")
    else:
        ok(f"[{table}] {inserted} registros migrados")

    return inserted


def reset_sequences(pg_conn):
    """Reseta as sequences de todas as tabelas com SERIAL."""
    header("Resetando sequences PostgreSQL…")
    pg_cur = pg_conn.cursor()

    for tbl in TABLES:
        if not tbl['serial']:
            continue
        table = tbl['name']
        seq   = f"{table}_id_seq"
        try:
            pg_cur.execute(f'SELECT MAX(id) FROM "{table}"')
            row = pg_cur.fetchone()
            max_id = row[0] if row and row[0] is not None else 0
            next_val = max_id + 1
            pg_cur.execute(f"SELECT SETVAL('{seq}', %s, false)", (next_val,))
            ok(f"[{seq}] → {next_val}")
        except Exception as e:
            warn(f"[{seq}] não resetada: {e}")
            pg_conn.rollback()

    pg_conn.commit()


def verify_counts(sq_conn, pg_conn):
    """Compara contagens SQLite × PostgreSQL."""
    header("Verificação de contagens…")
    sq_cur = sq_conn.cursor()
    pg_cur = pg_conn.cursor()

    all_ok  = True
    for tbl in TABLES:
        table = tbl['name']
        sq_cur.execute(f'SELECT COUNT(*) FROM "{table}"')
        sq_n = sq_cur.fetchone()[0]

        try:
            pg_cur.execute(f'SELECT COUNT(*) FROM "{table}"')
            pg_n = pg_cur.fetchone()[0]
        except Exception:
            pg_n = -1

        if sq_n == pg_n:
            ok(f"[{table}]  SQLite={sq_n}  PG={pg_n}")
        else:
            err(f"[{table}]  SQLite={sq_n}  PG={pg_n}  ← DIVERGÊNCIA")
            all_ok = False

    return all_ok


# ──────────────────────────────────────────────────────────────
#  Main
# ──────────────────────────────────────────────────────────────
def main():
    # ── Localiza o arquivo SQLite ──────────────────────────────
    if len(sys.argv) > 1:
        sqlite_path = sys.argv[1]
    else:
        sqlite_path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                   'gestao_frota.db')

    if not os.path.exists(sqlite_path):
        err(f"Arquivo SQLite não encontrado: {sqlite_path}")
        err("Informe o caminho como argumento: python3 migrate_to_postgres.py /path/to/gestao_frota.db")
        sys.exit(1)

    print(f"\n{'='*60}")
    print(f"  MIGRAÇÃO  SQLite → PostgreSQL")
    print(f"  Origem : {sqlite_path}")
    print(f"  Destino: {PG_USER}@{PG_HOST}:{PG_PORT}/{PG_NAME}")
    print(f"{'='*60}")

    # ── Conecta SQLite ─────────────────────────────────────────
    info("Conectando ao SQLite…")
    try:
        sq_conn = sqlite3.connect(sqlite_path)
        sq_conn.row_factory = sqlite3.Row
        ok("SQLite conectado")
    except Exception as e:
        err(f"Falha ao abrir SQLite: {e}")
        sys.exit(1)

    # ── Conecta PostgreSQL ─────────────────────────────────────
    info("Conectando ao PostgreSQL…")
    try:
        pg_conn = psycopg2.connect(
            host=PG_HOST, port=PG_PORT,
            dbname=PG_NAME, user=PG_USER, password=PG_PASS
        )
        pg_conn.autocommit = False
        ok("PostgreSQL conectado")
    except Exception as e:
        err(f"Falha ao conectar PostgreSQL: {e}")
        err("Verifique se o banco de dados está rodando e as credenciais estão corretas.")
        err("Use as variáveis de ambiente PG_HOST, PG_PORT, PG_DBNAME, PG_USER, PG_PASSWORD.")
        sq_conn.close()
        sys.exit(1)

    # ── Migra cada tabela ──────────────────────────────────────
    header("Migrando tabelas…")
    total = 0
    for tbl in TABLES:
        total += migrate_table(sq_conn, pg_conn, tbl)

    # ── Reseta sequences ───────────────────────────────────────
    reset_sequences(pg_conn)

    # ── Verificação final ──────────────────────────────────────
    all_ok = verify_counts(sq_conn, pg_conn)

    # ── Fecha conexões ─────────────────────────────────────────
    sq_conn.close()
    pg_conn.close()

    print(f"\n{'='*60}")
    if all_ok:
        print(f"  {GREEN}{BOLD}✔  Migração concluída com sucesso!{RESET}")
        print(f"     {total} registros migrados no total.")
    else:
        print(f"  {YELLOW}{BOLD}⚠  Migração concluída com divergências.{RESET}")
        print(f"     Verifique os itens marcados com ← DIVERGÊNCIA acima.")
    print(f"{'='*60}\n")

    sys.exit(0 if all_ok else 2)


if __name__ == '__main__':
    main()
