#!/usr/bin/env python3
"""
Script de criação do usuário administrador.
Execute UMA VEZ na mesma máquina onde o servidor roda:
    python3 create_admin.py
"""
import hashlib, os, sys
from urllib.parse import urlparse
import psycopg2, psycopg2.extras

_DATABASE_URL = os.environ.get('DATABASE_URL', '')
if _DATABASE_URL:
    _u = urlparse(_DATABASE_URL)
    DB_HOST = _u.hostname
    DB_PORT = _u.port or 5432
    DB_NAME = _u.path.lstrip('/')
    DB_USER = _u.username
    DB_PASS = _u.password
    DB_SSL  = {'sslmode': 'require'}
else:
    DB_HOST = os.environ.get('PG_HOST',    'localhost')
    DB_PORT = int(os.environ.get('PG_PORT','5432'))
    DB_NAME = os.environ.get('PG_DBNAME', 'gestao_frota')
    DB_USER = os.environ.get('PG_USER',   'gestao_frota')
    DB_PASS = os.environ.get('PG_PASSWORD','gestao_frota')
    DB_SSL  = {}
SALT    = os.environ.get('AUTH_SALT') or 'gestao_frota_salt_2024'

ADMIN_EMAIL = 'd.peruffo@yahoo.com'
ADMIN_SENHA = 'Prototipo@2026'
ADMIN_NOME  = 'Daniel Peruffo'

MODULOS = [
    'Clientes','Postos','Veículos','Motoristas','Negociações',
    'Inventário','Volumes','Hodômetro','Segurança','Roteirizador',
    'Planos de Viagem','Abastecimentos','Centros de Custo',
    'Orçamento CC','Lançamentos CC','Dashboard CC',
    'Usuários','Perfis de Acesso','Configurações',
]

def hash_senha(s):
    dk = hashlib.pbkdf2_hmac('sha256', s.encode(), SALT.encode(), 200_000)
    return dk.hex()

def main():
    conn = psycopg2.connect(host=DB_HOST, port=DB_PORT,
                             dbname=DB_NAME, user=DB_USER, password=DB_PASS, **DB_SSL)
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    # 1. Garante que o perfil "Gestor" existe e tem permissões totais
    cur.execute("INSERT INTO perfis_acesso (nome, descricao) VALUES ('Gestor','Acesso total ao sistema') ON CONFLICT (nome) DO NOTHING")
    cur.execute("SELECT id FROM perfis_acesso WHERE nome='Gestor'")
    perfil_id = cur.fetchone()['id']
    print(f'Perfil Gestor: id={perfil_id}')

    for mod in MODULOS:
        cur.execute("""
            INSERT INTO permissoes_perfil (perfil_id, modulo, inclusao, consulta, edicao, exclusao)
            VALUES (%s,%s,TRUE,TRUE,TRUE,TRUE)
            ON CONFLICT (perfil_id, modulo) DO UPDATE
              SET inclusao=TRUE, consulta=TRUE, edicao=TRUE, exclusao=TRUE
        """, [perfil_id, mod])
    print(f'Permissões totais configuradas em {len(MODULOS)} módulos.')

    # 2. Cria ou atualiza o usuário administrador
    cur.execute("SELECT id FROM usuarios WHERE LOWER(email)=%s", [ADMIN_EMAIL.lower()])
    row = cur.fetchone()
    h = hash_senha(ADMIN_SENHA)

    if row:
        cur.execute("""
            UPDATE usuarios SET
                nome=%s, senha_hash=%s, perfil='Gestor',
                tipo_acesso='Frota', perfil_id=%s,
                status='Ativo', token_reset=NULL, token_expiry=NULL
            WHERE id=%s
        """, [ADMIN_NOME, h, perfil_id, row['id']])
        print(f'Usuário atualizado: id={row["id"]}')
    else:
        cur.execute("""
            INSERT INTO usuarios (nome, email, cpf, perfil, tipo_acesso, perfil_id, status, senha_hash)
            VALUES (%s,%s,'','Gestor','Frota',%s,'Ativo',%s) RETURNING id
        """, [ADMIN_NOME, ADMIN_EMAIL, perfil_id, h])
        new_id = cur.fetchone()['id']
        print(f'Usuário criado: id={new_id}')

    conn.commit()
    conn.close()
    print('\n✅ Pronto! Faça login com:')
    print(f'   E-mail: {ADMIN_EMAIL}')
    print(f'   Senha:  {ADMIN_SENHA}')

if __name__ == '__main__':
    main()
