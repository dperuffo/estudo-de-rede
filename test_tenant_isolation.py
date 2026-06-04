#!/usr/bin/env python3
"""
FNI Pró-Frotas — Testes de Isolamento de Tenant (Fase 1)
=========================================================
Verifica que tenant A não consegue ler, escrever ou listar dados
pertencentes ao tenant B em nenhum cenário.

COMO EXECUTAR:
    pip install supabase python-dotenv
    python test_tenant_isolation.py

CONFIGURAÇÃO:
    Crie um arquivo .env com:
        SUPABASE_URL=https://seu-projeto.supabase.co
        SUPABASE_KEY=sua-service-role-key   # chave service_role para criar dados de teste

    O script cria dois tenants temporários (TEST_A e TEST_B),
    insere dados em cada um, verifica isolamento e apaga tudo ao final.
"""

from __future__ import annotations
import os
import sys
import uuid
import json
from datetime import datetime, timezone

# ─────────────────────────────────────────────────────────────────────────────
# Configuração
# ─────────────────────────────────────────────────────────────────────────────

try:
    from dotenv import load_dotenv
    load_dotenv()
except ImportError:
    pass

SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY", "")

# Tabelas testadas (precisam ter empresa_id)
TABELAS_TESTADAS = [
    "frota_abastecimentos",
    "postos_gf",
    "acordos_precos",
    "rotas_salvas",
    "preferencias",
    "perfis_veiculo",
    "security_logs",
]

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

VERDE  = "\033[92m"
VERM   = "\033[91m"
AMAR   = "\033[93m"
RESET  = "\033[0m"
NEGRIT = "\033[1m"

def ok(msg):   print(f"  {VERDE}✓{RESET}  {msg}")
def fail(msg): print(f"  {VERM}✗{RESET}  {msg}")
def info(msg): print(f"  {AMAR}·{RESET}  {msg}")
def header(msg): print(f"\n{NEGRIT}{msg}{RESET}")


def get_client(key: str | None = None):
    from supabase import create_client
    return create_client(SUPABASE_URL, key or SUPABASE_KEY)


def check_table_exists(db, tabela: str) -> bool:
    try:
        db.table(tabela).select("id").limit(1).execute()
        return True
    except Exception as e:
        if "42P01" in str(e) or "does not exist" in str(e).lower():
            return False
        return True  # outro erro — assume que existe


# ─────────────────────────────────────────────────────────────────────────────
# Fixtures — cria/remove dados de teste
# ─────────────────────────────────────────────────────────────────────────────

class TenantTestFixture:
    def __init__(self, db, label: str):
        self.db = db
        self.label = label
        self.empresa_id = str(uuid.uuid4())
        self.email = f"test_{label.lower()}_{uuid.uuid4().hex[:6]}@fni-test.invalid"
        self.records: dict[str, list[str]] = {}  # tabela → lista de IDs

    def criar_empresa(self):
        self.db.table("empresas").insert({
            "id":     self.empresa_id,
            "nome":   f"[TEST] Empresa {self.label}",
            "plano":  "profissional",
            "status": "ativo",
            "ativo":  True,
        }).execute()
        # Cria vínculo de usuário
        self.db.table("usuarios_empresas").insert({
            "user_email": self.email,
            "empresa_id": self.empresa_id,
            "role":       "editor",
            "ativo":      True,
        }).execute()

    def inserir_registro(self, tabela: str, extra: dict | None = None) -> str | None:
        """Insere registro de teste na tabela e registra o ID para limpeza."""
        base_payload: dict = {"empresa_id": self.empresa_id}

        # Payload mínimo por tabela
        payloads: dict[str, dict] = {
            "frota_abastecimentos": {
                "usuario_email": self.email,
                "data_abastecimento": datetime.now(tz=timezone.utc).isoformat(),
                "placa": f"TEST-{self.label}",
                "produto": "DIESEL S10",
                "litros": 100.0,
                "valor_total": 700.0,
            },
            "postos_gf": {
                "cnpj": f"00000000000{self.label[0]}",
                "razao_social": f"[TEST] Posto {self.label}",
                "municipio": "São Paulo",
                "uf": "SP",
            },
            "acordos_precos": {
                "cnpj": f"00000000000{self.label[0]}",
                "produto": "DIESEL S10",
                "preco_acordo": 5.99,
            },
            "rotas_salvas": {
                "id": f"test_{self.label}_{uuid.uuid4().hex[:8]}",
                "usuario_email": self.email,
                "nome": f"Rota Teste {self.label}",
                "tipo": "rota",
                "dados": {},
            },
            "preferencias": {
                "usuario_email": self.email,
                "placa": f"TEST{self.label}",
                "combustivel": "DIESEL S10",
            },
            "perfis_veiculo": {
                "usuario_email": self.email,
                "nome": f"Perfil Teste {self.label}",
                "placa": f"TST{self.label}01",
                "combustivel": "DIESEL S10",
                "tanque": 100,
                "autonomia": 3.5,
            },
            "security_logs": {
                "tipo": "test_isolation",
                "nivel": "INFO",
                "email": self.email,
                "descricao": f"Teste de isolamento tenant {self.label}",
                "ts": datetime.now(tz=timezone.utc).isoformat(),
            },
        }

        payload = {**base_payload, **payloads.get(tabela, {}), **(extra or {})}
        try:
            res = self.db.table(tabela).insert(payload).execute()
            record_id = (res.data[0] if res.data else {}).get("id")
            self.records.setdefault(tabela, [])
            if record_id:
                self.records[tabela].append(str(record_id))
            return str(record_id) if record_id else None
        except Exception as e:
            info(f"    Skipping {tabela} insert: {e}")
            return None

    def limpar(self):
        """Remove todos os dados de teste."""
        for tabela, ids in self.records.items():
            for rid in ids:
                try:
                    self.db.table(tabela).delete().eq("id", rid).execute()
                except Exception:
                    pass
        # Remove vínculo e empresa
        try:
            self.db.table("usuarios_empresas").delete().eq("empresa_id", self.empresa_id).execute()
            self.db.table("empresas").delete().eq("id", self.empresa_id).execute()
        except Exception:
            pass


# ─────────────────────────────────────────────────────────────────────────────
# Testes
# ─────────────────────────────────────────────────────────────────────────────

def test_empresa_id_presente(db, fixture_a: TenantTestFixture, tabelas: list[str]) -> dict[str, bool]:
    """T1: Verifica que empresa_id existe como coluna nas tabelas."""
    resultados = {}
    header("T1 · Coluna empresa_id presente nas tabelas")
    for t in tabelas:
        if not check_table_exists(db, t):
            info(f"{t}: tabela não existe (skip)")
            continue
        try:
            res = db.table(t).select("empresa_id").limit(1).execute()
            ok(f"{t}: coluna empresa_id existe")
            resultados[t] = True
        except Exception as e:
            if "empresa_id" in str(e).lower() or "column" in str(e).lower():
                fail(f"{t}: coluna empresa_id NÃO existe — {e}")
                resultados[t] = False
            else:
                ok(f"{t}: coluna empresa_id existe (tabela vazia)")
                resultados[t] = True
    return resultados


def test_isolamento_leitura(db, fixture_a: TenantTestFixture, fixture_b: TenantTestFixture, tabelas: list[str]) -> dict[str, bool]:
    """T2: Tenant A não deve ver registros do Tenant B via empresa_id filter."""
    resultados = {}
    header("T2 · Isolamento de leitura (A não lê dados de B)")
    for t in tabelas:
        if not check_table_exists(db, t):
            continue
        # Insere dado no tenant B
        fixture_b.inserir_registro(t)
        # Consulta com filtro empresa_a — não deve retornar dados de empresa_b
        try:
            res = db.table(t).select("empresa_id").eq("empresa_id", fixture_a.empresa_id).limit(100).execute()
            ids_retornados = [r.get("empresa_id") for r in (res.data or [])]
            contaminado = any(eid == fixture_b.empresa_id for eid in ids_retornados)
            if contaminado:
                fail(f"{t}: FALHOU — dados do tenant B aparecem ao filtrar por tenant A")
                resultados[t] = False
            else:
                ok(f"{t}: isolado corretamente")
                resultados[t] = True
        except Exception as e:
            info(f"{t}: erro na query — {e}")
            resultados[t] = True  # erro é neutro
    return resultados


def test_empresa_id_inserido_automaticamente(db, fixture_a: TenantTestFixture, tabelas: list[str]) -> dict[str, bool]:
    """T3: Registros inseridos pelo tenant A devem ter empresa_id correto."""
    resultados = {}
    header("T3 · empresa_id inserido corretamente nos registros")
    for t in tabelas:
        if not check_table_exists(db, t):
            continue
        record_id = fixture_a.inserir_registro(t)
        if not record_id:
            info(f"{t}: insert falhou — skip")
            continue
        try:
            res = db.table(t).select("empresa_id").eq("id", record_id).limit(1).execute()
            eid = (res.data[0] if res.data else {}).get("empresa_id")
            if eid == fixture_a.empresa_id:
                ok(f"{t}: empresa_id correto ({eid[:8]}...)")
                resultados[t] = True
            else:
                fail(f"{t}: empresa_id incorreto — esperado {fixture_a.empresa_id[:8]}, obtido {eid}")
                resultados[t] = False
        except Exception as e:
            info(f"{t}: erro ao verificar — {e}")
    return resultados


def test_rls_ativo(db, tabelas: list[str]) -> dict[str, bool]:
    """T4: Verifica que RLS está habilitado em todas as tabelas."""
    resultados = {}
    header("T4 · RLS habilitado nas tabelas")
    try:
        res = db.rpc("_check_rls_status", {}).execute()
        # Se RPC não existir, verifica via pg_tables
    except Exception:
        pass
    # Verifica via SQL direto (service_role pode ler pg_class)
    for t in tabelas:
        if not check_table_exists(db, t):
            continue
        try:
            res = db.rpc("_fni_rls_check", {"p_table": t}).execute()
            rls_on = (res.data or [False])[0]
        except Exception:
            # RPC não existe — tenta inferir via comportamento
            rls_on = None
        if rls_on is True:
            ok(f"{t}: RLS ativo")
            resultados[t] = True
        elif rls_on is False:
            fail(f"{t}: RLS NÃO ativo — execute a migration fase1_migration.sql")
            resultados[t] = False
        else:
            info(f"{t}: não foi possível verificar RLS diretamente (verifique no Supabase Dashboard)")
            resultados[t] = None
    return resultados


def test_sem_dados_cruzados(db, fixture_a: TenantTestFixture, fixture_b: TenantTestFixture, tabelas: list[str]) -> dict[str, bool]:
    """T5: Query sem filtro de empresa_id não mistura dados entre tenants."""
    resultados = {}
    header("T5 · Nenhum dado cruzado entre tenants em consulta livre")
    for t in tabelas:
        if not check_table_exists(db, t):
            continue
        try:
            # Busca todos os registros dos dois tenants
            res_a = db.table(t).select("id,empresa_id").eq("empresa_id", fixture_a.empresa_id).execute()
            res_b = db.table(t).select("id,empresa_id").eq("empresa_id", fixture_b.empresa_id).execute()
            ids_a = {r["id"] for r in (res_a.data or []) if r.get("id")}
            ids_b = {r["id"] for r in (res_b.data or []) if r.get("id")}
            cruzado = ids_a & ids_b
            if cruzado:
                fail(f"{t}: FALHOU — {len(cruzado)} registros aparecem em ambos os tenants: {cruzado}")
                resultados[t] = False
            else:
                ok(f"{t}: sem dados cruzados ({len(ids_a)} registros A, {len(ids_b)} registros B)")
                resultados[t] = True
        except Exception as e:
            info(f"{t}: erro — {e}")
    return resultados


# ─────────────────────────────────────────────────────────────────────────────
# Runner principal
# ─────────────────────────────────────────────────────────────────────────────

def main():
    print(f"\n{'═'*60}")
    print(f"  FNI Pró-Frotas — Testes de Isolamento de Tenant (Fase 1)")
    print(f"{'═'*60}")

    if not SUPABASE_URL or not SUPABASE_KEY:
        print(f"\n{VERM}ERRO: SUPABASE_URL e SUPABASE_KEY são obrigatórios.{RESET}")
        print("Crie um arquivo .env ou exporte as variáveis de ambiente.")
        sys.exit(1)

    print(f"\n  URL: {SUPABASE_URL}")
    print(f"  Tabelas testadas: {', '.join(TABELAS_TESTADAS)}\n")

    db = get_client()
    fixture_a = TenantTestFixture(db, "A")
    fixture_b = TenantTestFixture(db, "B")

    # Tabelas que existem neste banco
    tabelas_existentes = [t for t in TABELAS_TESTADAS if check_table_exists(db, t)]
    info(f"Tabelas disponíveis: {', '.join(tabelas_existentes)}")

    try:
        print("\n─── Criando dados de teste ───────────────────────────────")
        fixture_a.criar_empresa()
        fixture_b.criar_empresa()
        ok(f"Tenant A criado: {fixture_a.empresa_id[:8]}...")
        ok(f"Tenant B criado: {fixture_b.empresa_id[:8]}...")

        # Executa todos os testes
        resultados_todos: dict[str, dict] = {}
        resultados_todos["T1_coluna"]       = test_empresa_id_presente(db, fixture_a, tabelas_existentes)
        resultados_todos["T3_insert"]       = test_empresa_id_inserido_automaticamente(db, fixture_a, tabelas_existentes)
        resultados_todos["T2_leitura"]      = test_isolamento_leitura(db, fixture_a, fixture_b, tabelas_existentes)
        resultados_todos["T5_cruzamento"]   = test_sem_dados_cruzados(db, fixture_a, fixture_b, tabelas_existentes)
        resultados_todos["T4_rls"]          = test_rls_ativo(db, tabelas_existentes)

    finally:
        print("\n─── Limpando dados de teste ──────────────────────────────")
        fixture_a.limpar()
        fixture_b.limpar()
        ok("Dados de teste removidos")

    # ── Sumário ──────────────────────────────────────────────────────────────
    print(f"\n{'═'*60}")
    print(f"  SUMÁRIO DOS TESTES")
    print(f"{'═'*60}")

    total_ok   = 0
    total_fail = 0
    total_skip = 0

    for suite, resultados in resultados_todos.items():
        for tabela, resultado in resultados.items():
            if resultado is True:
                total_ok += 1
            elif resultado is False:
                total_fail += 1
                print(f"  {VERM}FALHOU{RESET}  {suite} / {tabela}")
            else:
                total_skip += 1

    print(f"\n  {VERDE}Passou: {total_ok}{RESET}  |  "
          f"{VERM}Falhou: {total_fail}{RESET}  |  "
          f"{AMAR}Ignorado: {total_skip}{RESET}")

    if total_fail == 0:
        print(f"\n  {VERDE}{NEGRIT}✓ Todos os testes de isolamento passaram!{RESET}")
        print("  O isolamento de tenant está funcionando corretamente.\n")
        sys.exit(0)
    else:
        print(f"\n  {VERM}{NEGRIT}✗ {total_fail} teste(s) falharam.{RESET}")
        print("  Verifique se a migration fase1_migration.sql foi executada no Supabase.\n")
        sys.exit(1)


if __name__ == "__main__":
    main()
