#!/usr/bin/env python3
"""
worker_sync.py — ProFrotas Auto-Sync Worker
============================================
Roda em background, independente do Streamlit e de sessões de usuário.
Verifica a cada CHECK_INTERVAL segundos se algum cliente precisa de sync
(último sync > SYNC_INTERVAL segundos atrás) e executa automaticamente.

Lê credenciais do Supabase via:
  1. Variáveis de ambiente: SUPABASE_URL, SUPABASE_KEY
  2. Arquivo .streamlit/secrets.toml
"""

import os
import re
import time
import math
import hashlib
import logging
import datetime

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [WORKER] %(levelname)s %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
log = logging.getLogger("worker_sync")

SYNC_INTERVAL  = 3600   # sincroniza se último sync > 1 hora atrás
CHECK_INTERVAL = 300    # verifica clientes a cada 5 minutos
BATCH_SIZE     = 25     # registros por upsert
PAGE_SIZE      = 100    # registros por página da API
API_URL        = "https://api-portal.profrotas.com.br/api/frotista/abastecimento/pesquisa"


# ── Supabase ──────────────────────────────────────────────────────

def get_db():
    """Cria cliente Supabase sem depender de st.session_state."""
    try:
        from supabase import create_client
        url = os.environ.get("SUPABASE_URL", "")
        key = os.environ.get("SUPABASE_KEY", "")
        if not (url and key):
            _dir = os.path.dirname(os.path.abspath(__file__))
            for sp in [
                os.path.join(_dir, ".streamlit", "secrets.toml"),
                os.path.expanduser("~/.streamlit/secrets.toml"),
            ]:
                if os.path.exists(sp):
                    try:
                        import tomllib as tl
                    except ImportError:
                        try:
                            import tomli as tl
                        except ImportError:
                            tl = None
                    if tl:
                        with open(sp, "rb") as f:
                            sec = tl.load(f)
                        url = sec.get("supabase", {}).get("url", "")
                        key = sec.get("supabase", {}).get("key", "")
                        if url and key:
                            break
        if url and key:
            return create_client(url, key)
    except Exception as e:
        log.error(f"Erro ao criar cliente Supabase: {e}")
    return None


def get_active_keys(db) -> list:
    """Retorna todas as chaves ProFrotas ativas."""
    try:
        r = (db.table("profrotas_api_keys")
               .select("cnpj_frota,token,ultimo_sync,ativo")
               .eq("ativo", True)
               .execute())
        return r.data or []
    except Exception as e:
        log.error(f"Erro ao listar chaves: {e}")
        return []


def needs_sync(ultimo_sync: str | None) -> bool:
    """True se o último sync foi há mais de SYNC_INTERVAL segundos."""
    if not ultimo_sync:
        return True
    try:
        ts = datetime.datetime.fromisoformat(ultimo_sync.replace("Z", "+00:00"))
        elapsed = (datetime.datetime.utcnow() - ts.replace(tzinfo=None)).total_seconds()
        return elapsed >= SYNC_INTERVAL
    except Exception:
        return True


# ── Sync de um cliente ────────────────────────────────────────────

def make_sync_key(cnpj: str, ident, item: str) -> str:
    raw = f"{cnpj}|{ident or 'sem_id'}|{item or ''}"
    return hashlib.md5(raw.encode()).hexdigest()


def safe_num(val):
    try:
        return float(val) if val is not None else None
    except (TypeError, ValueError):
        return None


def safe_ts(val):
    if not val:
        return None
    try:
        return str(val).replace("Z", "+00:00")
    except Exception:
        return None


def sync_client(db, cnpj_frota: str, token: str) -> tuple[int, str]:
    """
    Sincroniza abastecimentos de um cliente via API ProFrotas.
    Salva em profrotas_abastecimentos (upsert por sync_key).
    Retorna (total_salvos, mensagem_erro).
    """
    import requests

    # Calcula data_inicio com overlap de 2h
    try:
        r = (db.table("profrotas_api_keys")
               .select("ultimo_sync")
               .eq("cnpj_frota", cnpj_frota)
               .execute())
        ultimo = (r.data or [{}])[0].get("ultimo_sync")
    except Exception:
        ultimo = None

    if ultimo:
        try:
            ts = datetime.datetime.fromisoformat(ultimo.replace("Z", "+00:00"))
            data_inicio = (ts.replace(tzinfo=None) - datetime.timedelta(hours=2)
                           ).strftime("%Y-%m-%dT%H:%M:%SZ")
        except Exception:
            data_inicio = (datetime.datetime.utcnow() - datetime.timedelta(hours=4)
                           ).strftime("%Y-%m-%dT%H:%M:%SZ")
    else:
        data_inicio = (datetime.datetime.utcnow() - datetime.timedelta(hours=4)
                       ).strftime("%Y-%m-%dT%H:%M:%SZ")

    hoje          = datetime.datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
    total_salvos  = 0
    pagina        = 1
    total_items   = None

    while True:
        try:
            resp = requests.post(
                API_URL,
                json={"pagina": pagina, "dataInicial": data_inicio, "dataFinal": hoje},
                headers={
                    "Authorization": f"Bearer {token}",
                    "Content-Type": "application/json",
                },
                timeout=30,
            )
            if resp.status_code == 401:
                return total_salvos, "Token expirado ou inválido (401)"
            resp.raise_for_status()
            data = resp.json()
        except Exception as e:
            return total_salvos, f"Erro API pág {pagina}: {str(e)[:150]}"

        registros = (data.get("registros") or data.get("items") or
                     data.get("data") or data.get("content") or [])

        if total_items is None:
            total_items = int(
                data.get("totalItems") or data.get("total") or
                data.get("totalRegistros") or 0
            )
        tam_pag = int(data.get("tamanhoPagina", PAGE_SIZE)) or PAGE_SIZE

        # Monta rows
        rows = []
        for reg in registros:
            _id  = str(reg.get("identificador") or "")
            _mot = reg.get("motorista") or {}
            _vei = reg.get("veiculo") or {}
            _pv  = reg.get("pontoVenda") or {}
            _end = _pv.get("endereco") or {}
            _frt = reg.get("frota") or {}

            _base = {
                "cnpj_frota":         cnpj_frota,
                "identificador":      _id or None,
                "data_abastecimento": safe_ts(reg.get("data") or reg.get("dataTransacao")),
                "data_atualizacao":   safe_ts(reg.get("dataAtualizacao")),
                "status_autorizacao": reg.get("statusAutorizacao"),
                "hodometro":          safe_num(reg.get("hodometro")),
                "horimetro":          safe_num(reg.get("horimetro")),
                "frota_cnpj":         re.sub(r"\D", "", str(_frt.get("cnpj") or "")).zfill(14),
                "frota_razao_social": _frt.get("razaoSocial"),
                "motorista_nome":     _mot.get("nome"),
                "motorista_id":       str(_mot.get("identificador") or "") or None,
                "veiculo_placa":      str(_vei.get("placa") or "").upper().strip() or None,
                "veiculo_id":         str(_vei.get("identificador") or "") or None,
                "pv_cnpj":            re.sub(r"\D", "", str(_pv.get("cnpj") or "")).zfill(14),
                "pv_razao_social":    _pv.get("razaoSocial"),
                "pv_municipio":       _end.get("municipio"),
                "pv_uf":              _end.get("uf"),
                "pv_latitude":        safe_num(_end.get("latitude")),
                "pv_longitude":       safe_num(_end.get("longitude")),
                "abastecimento_estornado": int(bool(reg.get("abastecimentoEstornado"))),
            }

            itens = reg.get("items") or []
            if itens:
                for item in itens:
                    iid  = str(item.get("identificador") or "")
                    row  = dict(_base)
                    row["item_id"]             = iid
                    row["item_nome"]           = item.get("nome")
                    row["item_quantidade"]     = safe_num(item.get("quantidade"))
                    row["item_valor_unitario"] = safe_num(item.get("valorUnitario"))
                    row["item_valor_total"]    = safe_num(item.get("valorTotal"))
                    row["sync_key"]            = make_sync_key(cnpj_frota, _id, iid)
                    rows.append(row)
            else:
                _base["item_id"]  = ""
                _base["sync_key"] = make_sync_key(cnpj_frota, _id, "")
                rows.append(_base)

        # Upsert em lotes
        for i in range(0, len(rows), BATCH_SIZE):
            lote = rows[i: i + BATCH_SIZE]
            try:
                db.table("profrotas_abastecimentos").upsert(
                    lote, on_conflict="sync_key"
                ).execute()
                total_salvos += len(lote)
            except Exception as e:
                # Fallback: insert individual
                for row in lote:
                    try:
                        db.table("profrotas_abastecimentos").insert(
                            row, returning="minimal"
                        ).execute()
                        total_salvos += 1
                    except Exception as e2:
                        err = str(e2).lower()
                        if "duplicate" in err or "unique" in err or "23505" in err:
                            total_salvos += 1  # já existe = ok

        # Condição de parada
        total_pg = math.ceil(total_items / tam_pag) if total_items and tam_pag else None
        if not registros:
            break
        if total_pg and pagina >= total_pg:
            break
        if total_items and total_salvos >= total_items:
            break
        if not total_items and len(registros) < tam_pag:
            break

        pagina += 1
        time.sleep(0.3)

    # Atualiza metadados
    try:
        db.table("profrotas_api_keys").update({
            "ultimo_sync":    datetime.datetime.utcnow().isoformat(),
            "registros_sync": total_salvos,
        }).eq("cnpj_frota", cnpj_frota).execute()
    except Exception as e:
        log.warning(f"Falha ao atualizar ultimo_sync: {e}")

    return total_salvos, ""


# ── Loop principal ────────────────────────────────────────────────

def main():
    log.info("=" * 50)
    log.info("ProFrotas Sync Worker iniciado")
    log.info(f"Intervalo de sync:   {SYNC_INTERVAL // 60} minutos")
    log.info(f"Intervalo de check:  {CHECK_INTERVAL // 60} minutos")
    log.info("=" * 50)

    consecutive_db_errors = 0

    while True:
        try:
            db = get_db()
            if not db:
                consecutive_db_errors += 1
                wait = min(300, 60 * consecutive_db_errors)
                log.error(f"Supabase indisponível. Retry em {wait}s.")
                time.sleep(wait)
                continue

            consecutive_db_errors = 0
            chaves = get_active_keys(db)

            if not chaves:
                log.info("Nenhuma chave ProFrotas ativa encontrada.")
            else:
                for c in chaves:
                    cnpj  = c.get("cnpj_frota", "")
                    token = c.get("token", "")
                    if not cnpj or not token:
                        continue

                    if needs_sync(c.get("ultimo_sync")):
                        log.info(f"Sincronizando cliente {cnpj}...")
                        salvos, erro = sync_client(db, cnpj, token)
                        if erro:
                            log.warning(f"  {cnpj}: ERRO — {erro} ({salvos} salvos)")
                        else:
                            log.info(f"  {cnpj}: {salvos} registros sincronizados.")
                    else:
                        log.debug(f"  {cnpj}: sync recente, pulando.")

        except Exception as e:
            log.error(f"Erro inesperado no loop principal: {e}", exc_info=True)

        log.debug(f"Próxima verificação em {CHECK_INTERVAL // 60} minutos.")
        time.sleep(CHECK_INTERVAL)


if __name__ == "__main__":
    main()
