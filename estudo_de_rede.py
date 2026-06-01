# ═══════════════════════════════════════════════════════════════════
#  Estudo de Rede – Gestão de Frotas
#  Versão 5.1  |  Plotly WebGL map + NumPy vetorizado + cache 24h
# ═══════════════════════════════════════════════════════════════════

import base64
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
import hashlib
import io
import json as _json_mod
import math
import os
import re
import time
import unicodedata
import requests
import numpy as np
import pandas as pd
import plotly.graph_objects as go
import streamlit as st
import folium
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.lines import Line2D

# Diretório onde este script está — usado para localizar arquivos do repo
_DIR = os.path.dirname(os.path.abspath(__file__))

# Helper de fuso horário Brasil (UTC-3) — usado em todo o app
import datetime as _datetime_mod
_TZ_BRASILIA = _datetime_mod.timezone(_datetime_mod.timedelta(hours=-3))

def _now_br():
    """datetime.now() no fuso de Brasília (UTC-3)."""
    return _datetime_mod.datetime.now(tz=_TZ_BRASILIA)

def _today_br():
    """date.today() no fuso de Brasília (UTC-3)."""
    return _datetime_mod.datetime.now(tz=_TZ_BRASILIA).date()



# ── Compatibilidade @st.fragment (Streamlit >= 1.37) ──────────────────────
def _fragment(func=None, *, run_every=None):
    """Decorator que usa st.fragment se disponível, senão é no-op."""
    def _decorator(f):
        try:
            import streamlit as _st
            if hasattr(_st, "fragment"):
                kwargs = {"run_every": run_every} if run_every else {}
                return _st.fragment(f, **kwargs)
        except Exception:
            pass
        return f
    return _decorator(func) if func is not None else _decorator

# ═══════════════════════════════════════════════════════════════════
#  AUTO-SYNC ProFrotas — Sincronização automática de hora em hora
#  Roda em background threads (daemon) — uma thread por cliente.
#  Persiste entre reruns do Streamlit enquanto o servidor estiver ativo.
# ═══════════════════════════════════════════════════════════════════
import threading as _threading

_AUTO_SYNC_INTERVAL = 3600  # segundos entre cada ciclo (1 hora)

# @st.cache_resource garante que os dicts sobrevivem a reruns do Streamlit.
# Sem isso, _AUTO_SYNC_THREADS = {} no módulo é re-executado a cada rerun,
# destruindo referências de threads ativas.
@st.cache_resource
def _get_auto_sync_state():
    """Retorna dicts de estado do auto-sync — criados UMA vez por processo."""
    return {
        "threads":     {},        # cnpj_frota → threading.Thread
        "status":      {},        # cnpj_frota → dict de status
        "lock":        _threading.Lock(),
        "initialized": False,
    }

_AUTO_SYNC_STATE       = _get_auto_sync_state()
_AUTO_SYNC_THREADS     = _AUTO_SYNC_STATE["threads"]
_AUTO_SYNC_STATUS      = _AUTO_SYNC_STATE["status"]
_AUTO_SYNC_LOCK        = _AUTO_SYNC_STATE["lock"]
_AUTO_SYNC_INITIALIZED = False   # flag local; _STATE persiste


def _auto_sync_create_db():
    """Cria cliente Supabase sem st.session_state (thread-safe)."""
    try:
        from supabase import create_client as _cc
        # 1) Variáveis de ambiente
        _url = os.environ.get("SUPABASE_URL", "")
        _key = os.environ.get("SUPABASE_KEY", "")
        # 2) Arquivo secrets.toml do Streamlit (local)
        if not (_url and _key):
            for _sp in [
                os.path.join(_DIR, ".streamlit", "secrets.toml"),
                os.path.expanduser("~/.streamlit/secrets.toml"),
            ]:
                if os.path.exists(_sp):
                    try:
                        import tomllib as _tl
                    except ImportError:
                        try:
                            import tomli as _tl
                        except ImportError:
                            _tl = None
                    if _tl:
                        with open(_sp, "rb") as _f:
                            _sec = _tl.load(_f)
                        _url = _sec.get("supabase", {}).get("url", "")
                        _key = _sec.get("supabase", {}).get("key", "")
                        if _url and _key:
                            break
        if _url and _key:
            return _cc(_url, _key)
    except Exception:
        pass
    return None


def _auto_sync_worker(cnpj_frota: str, token_inicial: str):
    """
    Worker de sincronização automática.
    Executa a cada _AUTO_SYNC_INTERVAL segundos em background.
    Busca registros das últimas 3 horas (+ 1h de overlap para segurança).
    """
    import datetime as _dt
    import time as _tm
    import re as _re_th

    while True:
        try:
            _db_th = _auto_sync_create_db()
            if not _db_th:
                _AUTO_SYNC_STATUS[cnpj_frota] = {
                    "status": "erro",
                    "msg": "Supabase indisponível — verifique secrets/env vars.",
                    "last_attempt": _dt.datetime.now(tz=_dt.timezone(_dt.timedelta(hours=-3))).isoformat(),
                }
                _tm.sleep(300)   # retry em 5 min se sem DB
                continue

            # ── Descobre o token mais recente e último sync ───────────
            _cur_token = token_inicial
            try:
                _r = (_db_th.table("profrotas_api_keys")
                      .select("token,ultimo_sync")
                      .eq("cnpj_frota", cnpj_frota)
                      .execute())
                _row = (_r.data or [{}])[0] if _r.data else {}
                _cur_token = _row.get("token") or token_inicial
                _last_sync = _row.get("ultimo_sync")
            except Exception:
                _last_sync = None

            # ── Calcula data_inicio: re-busca overlap de 2h ───────────
            if _last_sync:
                try:
                    _ts = _dt.datetime.fromisoformat(_last_sync.replace("Z", "+00:00"))
                    _ts_naive = _ts.replace(tzinfo=None)
                    _data_inicio = (
                        _ts_naive - _dt.timedelta(hours=2)
                    ).strftime("%Y-%m-%dT%H:%M:%SZ")
                except Exception:
                    _data_inicio = (
                        _dt.datetime.utcnow() - _dt.timedelta(hours=3)
                    ).strftime("%Y-%m-%dT%H:%M:%SZ")
            else:
                # Primeiro sync automático: pega as últimas 4 horas
                _data_inicio = (
                    _dt.datetime.utcnow() - _dt.timedelta(hours=3)
                ).strftime("%Y-%m-%dT%H:%M:%SZ")

            _inicio_ts = _dt.datetime.utcnow()
            _AUTO_SYNC_STATUS[cnpj_frota] = {
                "status":  "syncing",
                "started": _inicio_ts.isoformat(),
                "msg":     "Sincronizando...",
            }

            # ── Executa sync (usa _db_override para evitar session_state) ──
            _pags, _salvos, _novo_tok, _erro, _total = _profrotas_sync(
                cnpj_frota, _cur_token, _data_inicio,
                _db_override=_db_th,
            )

            # Atualiza token se renovado
            if _novo_tok:
                token_inicial = _novo_tok

            _fim_ts = _dt.datetime.utcnow()
            _duracao = int((_fim_ts - _inicio_ts).total_seconds())
            _next_ts = _fim_ts + _dt.timedelta(seconds=_AUTO_SYNC_INTERVAL)

            _AUTO_SYNC_STATUS[cnpj_frota] = {
                "status":       "ok" if not _erro else "erro_parcial",
                "last_sync":    _fim_ts.isoformat(),
                "next_sync":    _next_ts.isoformat(),
                "records_last": _salvos,
                "total_api":    _total,
                "paginas":      _pags,
                "erro":         _erro or "",
                "duracao_s":    _duracao,
            }

        except Exception as _ex:
            _AUTO_SYNC_STATUS[cnpj_frota] = {
                "status":       "erro",
                "msg":          str(_ex)[:300],
                "last_attempt": _dt.datetime.now(tz=_dt.timezone(_dt.timedelta(hours=-3))).isoformat(),
            }

        _tm.sleep(_AUTO_SYNC_INTERVAL)


def _auto_sync_ensure_running(cnpj_frota: str, token: str) -> bool:
    """Inicia ou verifica thread de sync automático para um cliente.
    Retorna True se a thread foi iniciada agora, False se já estava rodando."""
    with _AUTO_SYNC_LOCK:
        _t = _AUTO_SYNC_THREADS.get(cnpj_frota)
        if _t and _t.is_alive():
            return False
        _t = _threading.Thread(
            target=_auto_sync_worker,
            args=(cnpj_frota, token),
            daemon=True,
            name=f"auto_sync_{cnpj_frota}",
        )
        _AUTO_SYNC_THREADS[cnpj_frota] = _t
        _t.start()
        _AUTO_SYNC_STATUS[cnpj_frota] = {
            "status":    "iniciado",
            "msg":       "Thread iniciada — primeiro sync em andamento.",
            "started":   __import__("datetime").datetime.utcnow().isoformat(),
            "next_sync": (
                __import__("datetime").datetime.utcnow() +
                __import__("datetime").timedelta(seconds=_AUTO_SYNC_INTERVAL)
            ).isoformat(),
        }
        return True


def _auto_sync_ensure_all():
    """
    Chamada a cada nova sessão.
    Inicia ou re-verifica threads para todas as chaves ProFrotas ativas.
    _auto_sync_ensure_running() é idempotente — não recria threads vivas.
    """
    try:
        _chaves = _profrotas_listar_chaves()
        for _c in _chaves:
            if _c.get("ativo") and _c.get("token") and _c.get("cnpj_frota"):
                _auto_sync_ensure_running(_c["cnpj_frota"], _c["token"])
    except Exception as _e_as:
        _AUTO_SYNC_STATUS["_startup_error"] = {
            "status": "erro", "msg": str(_e_as)[:200],
        }


# ═══════════════════════════════════════════════════════════════════
#  FORMATAÇÃO NUMÉRICA — Padrão Brasileiro (pt-BR)
#  Separador decimal: vírgula  |  Separador de milhar: ponto
#  Exemplos:  1234.56 → "1.234,56"  |  1234 → "1.234"
# ═══════════════════════════════════════════════════════════════════

def _br_num(v, d: int = 2) -> str:
    """Número decimal no padrão BR: 1.234,56 (sem prefixo de moeda)."""
    try:
        return f"{float(v):,.{d}f}".replace(",", "X").replace(".", ",").replace("X", ".")
    except (TypeError, ValueError):
        return "—"


def _br_moeda(v, d: int = 2) -> str:
    """Valor monetário no padrão BR: R$ 1.234,56."""
    try:
        return "R$ " + f"{float(v):,.{d}f}".replace(",", "X").replace(".", ",").replace("X", ".")
    except (TypeError, ValueError):
        return "R$ —"


def _br_int(v) -> str:
    """Inteiro com separador de milhar BR: 1.234."""
    try:
        return f"{int(round(float(v))):,}".replace(",", ".")
    except (TypeError, ValueError):
        return "—"

# ═══════════════════════════════════════════════════════════════════
#  SUPABASE — Banco de Dados para Persistência
# ═══════════════════════════════════════════════════════════════════

def _db_client():
    """Retorna o cliente Supabase. Cria uma vez por sessão via session_state."""
    if "_supabase_client" not in st.session_state:
        try:
            from supabase import create_client
            _url = st.secrets.get("supabase", {}).get("url") or os.environ.get("SUPABASE_URL", "")
            _key = st.secrets.get("supabase", {}).get("key") or os.environ.get("SUPABASE_KEY", "")
            if _url and _key:
                st.session_state["_supabase_client"] = create_client(_url, _key)
            else:
                st.session_state["_supabase_client"] = None
        except Exception:
            st.session_state["_supabase_client"] = None
    return st.session_state["_supabase_client"]


def _db_email() -> str:
    """E-mail do usuário logado, usado como identificador no banco."""
    return (st.session_state.get("_auth_user") or {}).get("email", "anonimo")


# ═══════════════════════════════════════════════════════════════════
#  SEGURANÇA — OWASP Top 10 Controls
#  A01 Broken Access Control  → _auth_tem_permissao() + _auth_filtrar_df()
#  A03 Injection              → _sec_sanitizar() + Supabase SDK (parameterizado)
#  A04 Insecure Design        → _sec_rate_limit() + session timeout
#  A07 Auth Failures          → rate limit MFA/login + lockout temporal
#  A09 Security Logging       → _sec_log_evento() → Supabase security_logs
# ═══════════════════════════════════════════════════════════════════

import html as _html_mod

# ── A07 / Rate Limiting ──────────────────────────────────────────
_SEC_RATE_LIMITS: dict[str, dict] = {
    "mfa_verify":    {"max": 5,  "window": 300},   # 5 tentativas / 5 min
    "mfa_setup":     {"max": 10, "window": 300},   # 10 tentativas / 5 min
    "login_attempt": {"max": 10, "window": 600},   # 10 tentativas / 10 min
    "admin_action":  {"max": 50, "window": 60},    # 50 ações admin / min
    "export":        {"max": 20, "window": 60},    # 20 exports / min
}

def _sec_rate_limit(chave: str, operacao: str = "default") -> tuple[bool, int]:
    """
    Verifica rate limit para uma operação.
    Retorna (permitido: bool, segundos_bloqueado: int).
    Armazena contadores em session_state com TTL automático.
    """
    _cfg    = _SEC_RATE_LIMITS.get(operacao, {"max": 20, "window": 60})
    _max    = _cfg["max"]
    _window = _cfg["window"]
    _key    = f"_sec_rl_{operacao}_{chave}"
    _now    = time.time()

    _entry = st.session_state.get(_key, {"count": 0, "window_start": _now, "blocked_until": 0})

    # Verifica bloqueio ativo
    if _entry["blocked_until"] > _now:
        return False, int(_entry["blocked_until"] - _now)

    # Reinicia janela se expirou
    if _now - _entry["window_start"] > _window:
        _entry = {"count": 0, "window_start": _now, "blocked_until": 0}

    _entry["count"] += 1
    if _entry["count"] > _max:
        _entry["blocked_until"] = _now + _window
        st.session_state[_key] = _entry
        _sec_log_evento("RATE_LIMIT", f"Operação '{operacao}' bloqueada para '{chave}'", "WARN")
        return False, _window

    st.session_state[_key] = _entry
    return True, 0

def _sec_reset_rate_limit(chave: str, operacao: str = "default"):
    """Reseta contador de rate limit após sucesso (ex: login bem-sucedido)."""
    st.session_state.pop(f"_sec_rl_{operacao}_{chave}", None)

# ── A03 / Input Validation & Sanitization ───────────────────────
def _sec_sanitizar(texto: str, max_len: int = 500, permitir_html: bool = False) -> str:
    """
    Sanitiza entrada de texto:
    - Remove/escapa HTML para prevenir XSS
    - Limita comprimento
    - Remove caracteres de controle
    """
    if not isinstance(texto, str):
        texto = str(texto) if texto is not None else ""
    # Remove caracteres de controle (exceto tab e newline)
    texto = re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]", "", texto)
    # Limita comprimento
    texto = texto[:max_len]
    # Escapa HTML se não permitido
    if not permitir_html:
        texto = _html_mod.escape(texto)
    return texto.strip()

def _sec_validar_email(email: str) -> tuple[bool, str]:
    """Valida formato de e-mail. Retorna (válido, mensagem)."""
    email = email.strip().lower() if email else ""
    if not email:
        return False, "E-mail obrigatório."
    if len(email) > 254:
        return False, "E-mail muito longo (máx 254 caracteres)."
    _pat = r"^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$"
    if not re.match(_pat, email):
        return False, "Formato de e-mail inválido."
    # Bloqueia domínios temporários conhecidos (lista mínima)
    _blocked = {"mailinator.com", "tempmail.com", "guerrillamail.com", "10minutemail.com"}
    _domain = email.split("@")[-1]
    if _domain in _blocked:
        return False, "Domínio de e-mail temporário não permitido."
    return True, ""

def _sec_validar_cnpj(cnpj: str) -> tuple[bool, str]:
    """Valida CNPJ com dígitos verificadores. Retorna (válido, mensagem)."""
    if not cnpj:
        return False, "CNPJ obrigatório."
    _d = re.sub(r"\D", "", str(cnpj))
    if len(_d) != 14:
        return False, "CNPJ deve ter 14 dígitos."
    if len(set(_d)) == 1:
        return False, "CNPJ inválido (dígitos repetidos)."
    # Cálculo dos dígitos verificadores
    def _calc(digits, weights):
        s = sum(int(d) * w for d, w in zip(digits, weights))
        r = s % 11
        return 0 if r < 2 else 11 - r
    _w1 = [5,4,3,2,9,8,7,6,5,4,3,2]
    _w2 = [6,5,4,3,2,9,8,7,6,5,4,3,2]
    if _calc(_d[:12], _w1) != int(_d[12]):
        return False, "CNPJ inválido (dígito verificador)."
    if _calc(_d[:13], _w2) != int(_d[13]):
        return False, "CNPJ inválido (dígito verificador)."
    return True, ""

def _sec_validar_upload(nome_arquivo: str, tamanho_bytes: int,
                        tipos_permitidos: list[str] | None = None,
                        tamanho_max_mb: float = 50.0) -> tuple[bool, str]:
    """
    Valida arquivo de upload:
    - Extensão permitida
    - Tamanho máximo
    - Nome sem path traversal
    """
    if not nome_arquivo:
        return False, "Nome de arquivo inválido."
    # Previne path traversal
    _nome = os.path.basename(nome_arquivo).strip()
    if ".." in _nome or "/" in _nome or "\\" in _nome:
        return False, "Nome de arquivo inválido."
    # Verifica extensão
    _ext = _nome.rsplit(".", 1)[-1].lower() if "." in _nome else ""
    _tipos = tipos_permitidos or ["xlsx", "xls", "csv", "pdf", "png", "jpg", "jpeg"]
    if _ext not in _tipos:
        return False, f"Tipo de arquivo não permitido. Permitidos: {', '.join(_tipos)}"
    # Verifica tamanho
    _max_bytes = tamanho_max_mb * 1024 * 1024
    if tamanho_bytes > _max_bytes:
        return False, f"Arquivo muito grande (máx {tamanho_max_mb:.0f} MB)."
    return True, ""

# ── A04 / Session Timeout ────────────────────────────────────────
_SEC_SESSION_TIMEOUT_H = 8   # horas de inatividade → logout automático

def _sec_verificar_timeout_sessao() -> bool:
    """
    Verifica timeout de inatividade da sessão.
    Retorna True se sessão ainda válida, False se expirada (e faz logout).
    """
    if not st.session_state.get("_auth_perfil"):
        return True  # não autenticado — sem timeout a aplicar
    _ts = st.session_state.get("_last_activity_ts")
    _now = time.time()
    if _ts and (_now - _ts) > (_SEC_SESSION_TIMEOUT_H * 3600):
        _sec_log_evento("SESSION_TIMEOUT",
                        f"Sessão expirada por inatividade ({_SEC_SESSION_TIMEOUT_H}h)",
                        "INFO")
        for _k in [k for k in st.session_state
                   if k.startswith(("_auth", "_acesso", "_empresa", "_todas_emp",
                                    "_admin_empresa", "_github_sync", "_mfa"))]:
            del st.session_state[_k]
        st.session_state.pop("_last_activity_ts", None)
        return False
    # Atualiza timestamp a cada interação
    st.session_state["_last_activity_ts"] = _now
    return True

# ── A09 / Security Audit Log ─────────────────────────────────────
def _sec_log_evento(tipo: str, descricao: str, nivel: str = "INFO"):
    """
    Registra evento de segurança no Supabase (tabela security_logs).
    Silencioso em caso de falha — nunca bloqueia o fluxo principal.
    tipos: LOGIN_OK | LOGIN_FAIL | MFA_OK | MFA_FAIL | RATE_LIMIT |
           PERM_DENIED | SESSION_TIMEOUT | ADMIN_ACTION | DATA_EXPORT
    níveis: INFO | WARN | ERROR
    """
    try:
        _db = _db_client()
        if _db is None:
            return
        _email = ""
        try:
            _email = (st.session_state.get("_auth_user") or {}).get("email", "") or                      st.session_state.get("_auth_usuario_db", {}).get("email", "")
        except Exception:
            pass
        _db.table("security_logs").insert({
            "tipo":      tipo[:50],
            "nivel":     nivel[:10],
            "email":     _email[:254],
            "descricao": str(descricao)[:500],
            "ip_hint":   "",   # Streamlit Cloud não expõe IP diretamente
            "ts":        _now_br().isoformat(),
        }).execute()
    except Exception:
        pass  # Log nunca deve travar o app

# ═══════════════════════════════════════════════════════════════════
#  AUTENTICAÇÃO — Google SSO via Supabase Auth
# ═══════════════════════════════════════════════════════════════════

# ── Matriz de permissões por perfil ───────────────────────────────
#   Chave: slug da aba/funcionalidade.  Valor: set de perfis autorizados.
_PERFIS_TODOS = {"admin", "analista", "gestor_frota", "posto"}

_PERMISSOES: dict[str, set] = {
    # ── Abas do menu ──────────────────────────────────────────────
    "aba_dashboard":        {"admin", "analista", "gestor_frota"},
    "aba_roteirizacao":     {"admin", "analista", "gestor_frota", "posto"},
    "aba_analise_cliente":  {"admin", "analista", "posto"},
    "aba_inteligencia":     {"admin", "analista"},
    "aba_variacao_precos":  {"admin", "analista"},
    "aba_recomendador":     {"admin", "analista", "gestor_frota"},
    "aba_frotas":           {"admin", "analista", "gestor_frota"},
    "aba_telemetria":       {"admin", "analista", "gestor_frota"},
    "aba_relatorios":       {"admin", "analista", "gestor_frota", "posto"},
    "aba_api_integracoes":  {"admin", "analista"},
    "aba_admin":            {"admin"},
    "aba_configuracoes":    {"admin", "analista"},
    "aba_documentacao":     _PERFIS_TODOS,
    # ── Funcionalidades dentro das abas ───────────────────────────
    "func_exportar":        {"admin", "analista", "gestor_frota", "posto"},
    "func_editar_acordos":  {"admin", "analista"},
    "func_upload_planilha": {"admin", "analista"},
    "func_ver_todos_cnpj":  {"admin", "analista"},          # ver dados de outros CNPJs
    "func_gerenciar_users": {"admin"},
    "func_ver_telem_todos": {"admin", "analista"},          # telemetria de todos os clientes
}


def _auth_tem_permissao(funcionalidade: str, _log_deny: bool = False) -> bool:
    """Retorna True se o usuário logado tem permissão para a funcionalidade."""
    _perfil = st.session_state.get("_auth_perfil", "")
    _ok = _perfil in _PERMISSOES.get(funcionalidade, set())
    if not _ok and _log_deny and _perfil:
        _sec_log_evento("PERM_DENIED",
                        f"Acesso negado: perfil='{_perfil}' func='{funcionalidade}'",
                        "WARN")
    return _ok


def _auth_perfil() -> str:
    """Retorna o perfil do usuário logado ('admin','analista','gestor_frota','posto','')."""
    return st.session_state.get("_auth_perfil", "")


def _auth_cnpj_vinculado() -> str | None:
    """CNPJ vinculado ao usuário (posto ou empresa de frota). None para admin/analista."""
    return st.session_state.get("_auth_cnpj_vinculado")


def _auth_filtrar_df(df: "pd.DataFrame", col_cnpj: str = "cnpj") -> "pd.DataFrame":
    """
    Filtra um DataFrame pelo CNPJ vinculado ao usuário logado.
    - admin / analista: retorna df completo (sem filtro).
    - gestor_frota / posto: retorna apenas linhas cujo col_cnpj normalizado
      bate com o CNPJ do usuário.
    Usa normalização (só dígitos) para tolerar formatos diferentes.
    """
    _perfil = _auth_perfil()
    if _perfil in ("admin", "analista", ""):
        return df
    _cnpj = _auth_cnpj_vinculado()
    if not _cnpj or col_cnpj not in df.columns:
        return df
    _cnpj_norm = "".join(c for c in str(_cnpj) if c.isdigit())
    return df[
        df[col_cnpj].fillna("").astype(str)
            .str.replace(r"\D", "", regex=True)
            .eq(_cnpj_norm)
    ]


def _auth_usuario() -> dict:
    """Retorna dict completo do usuário logado."""
    return st.session_state.get("_auth_usuario_db", {})


def _auth_logado() -> bool:
    """True se há usuário autenticado na sessão."""
    return bool(st.session_state.get("_auth_perfil"))


def _auth_carregar_usuario_db(email: str) -> dict | None:
    """
    Busca o perfil do usuário na tabela usuarios_app pelo e-mail.
    Retorna dict com {perfil, cnpj_vinculado, empresa_nome, ativo} ou None.
    Silencioso se a tabela ainda não foi criada no Supabase.
    """
    _db = _db_client()
    if _db is None:
        return None
    try:
        _res = (_db.table("usuarios_app")
                   .select("perfil,cnpj_vinculado,empresa_nome,ativo,nome,mfa_habilitado,mfa_secret")
                   .eq("email", email)
                   .eq("ativo", True)
                   .limit(1)
                   .execute())
        return _res.data[0] if _res.data else None
    except Exception as _e:
        # Tabela ainda não criada (42P01) ou outro erro de banco — ignora silenciosamente
        _err_str = str(_e)
        if "42P01" not in _err_str and "PGRST205" not in _err_str:
            pass  # outros erros também ignorados para não travar o login
        return None


def _auth_logado() -> bool:
    """True se há usuário autenticado na sessão (compatível com sistema streamlit_oauth)."""
    return bool(st.session_state.get("_auth_user"))


# ═══════════════════════════════════════════════════════════════════
#  MFA / 2FA — Autenticação de Dois Fatores (TOTP)
# ═══════════════════════════════════════════════════════════════════

_MFA_ISSUER = "FNI Pró-Frotas"   # nome exibido no app authenticator

def _mfa_gerar_segredo() -> str:
    """Gera um novo segredo TOTP aleatório (base32, 32 chars)."""
    try:
        import pyotp as _pyotp
        return _pyotp.random_base32()
    except ImportError:
        import base64, os
        return base64.b32encode(os.urandom(20)).decode().rstrip("=")

def _mfa_uri(email: str, segredo: str) -> str:
    """Retorna a URI otpauth:// para gerar o QR code."""
    try:
        import pyotp as _pyotp
        return _pyotp.totp.TOTP(segredo).provisioning_uri(
            name=email,
            issuer_name=_MFA_ISSUER,
        )
    except ImportError:
        import urllib.parse
        return (f"otpauth://totp/{urllib.parse.quote(_MFA_ISSUER)}:{urllib.parse.quote(email)}"
                f"?secret={segredo}&issuer={urllib.parse.quote(_MFA_ISSUER)}")

def _mfa_verificar_codigo(segredo: str, codigo: str) -> bool:
    """
    Verifica código TOTP (RFC 6238) — implementação pura Python, sem pyotp.
    Aceita janela de ±2 intervalos de 30s (tolerância de 60s de drift de relógio).
    """
    import hmac as _hmac, hashlib as _hl, struct as _st, time as _time, base64 as _b32
    try:
        _code = str(codigo).strip().zfill(6)
        # Decodifica segredo base32 (padding automático)
        _pad = segredo.upper() + "=" * (-len(segredo) % 8)
        _key = _b32.b32decode(_pad)
        _now = int(_time.time()) // 30
        for _offset in range(-2, 3):   # janela ±2 × 30s = ±60s
            _msg = _st.pack(">Q", _now + _offset)
            _h   = _hmac.new(_key, _msg, _hl.sha1).digest()
            _o   = _h[-1] & 0x0F
            _val = _st.unpack(">I", _h[_o:_o + 4])[0] & 0x7FFFFFFF
            if f"{_val % 1_000_000:06d}" == _code:
                return True
        # Fallback: tenta pyotp se disponível
        try:
            import pyotp as _pyotp
            return _pyotp.TOTP(segredo).verify(_code, valid_window=2)
        except Exception:
            pass
        return False
    except Exception:
        return False

def _mfa_gerar_qr_bytes(uri: str) -> bytes | None:
    """Retorna PNG do QR code como bytes (tenta lib local, senão API pública)."""
    # 1. Tenta biblioteca local (qrcode[pil])
    try:
        import qrcode as _qr
        import io as _io
        img = _qr.make(uri)
        buf = _io.BytesIO()
        img.save(buf, format="PNG")
        return buf.getvalue()
    except Exception:
        pass
    # 2. Fallback: API pública qrserver.com
    try:
        import urllib.request as _ur
        import urllib.parse as _up
        _api = "https://api.qrserver.com/v1/create-qr-code/"
        _params = _up.urlencode({"size": "220x220", "data": uri, "ecc": "M"})
        with _ur.urlopen(f"{_api}?{_params}", timeout=5) as _r:
            return _r.read()
    except Exception:
        return None

def _mfa_qr_url(uri: str) -> str:
    """Retorna URL de QR code via API pública (para uso direto em <img>)."""
    import urllib.parse as _up
    _params = _up.urlencode({"size": "220x220", "data": uri, "ecc": "M"})
    return f"https://api.qrserver.com/v1/create-qr-code/?{_params}"

def _mfa_salvar_no_db(email: str, segredo: str, habilitado: bool = True) -> bool:
    """
    Persiste mfa_secret e mfa_habilitado na tabela usuarios_app.
    Usa upsert para garantir que o registro exista (cria se necessário).
    Armazena também em session_state como cache de sessão.
    """
    # Cache na sessão para uso imediato (independente do banco)
    _udb = st.session_state.get("_auth_usuario_db", {})
    _udb["mfa_secret"]    = segredo
    _udb["mfa_habilitado"] = habilitado
    st.session_state["_auth_usuario_db"] = _udb

    _db = _db_client()
    if _db is None:
        return False
    try:
        # Upsert: cria o registro se não existir, atualiza se existir
        (_db.table("usuarios_app")
            .upsert({
                "email":          email,
                "mfa_secret":     segredo if segredo else None,
                "mfa_habilitado": habilitado,
                "perfil":         st.session_state.get("_auth_perfil", "admin"),
                "ativo":          True,
            }, on_conflict="email")
            .execute())
        return True
    except Exception:
        return False

def _mfa_obrigatorio(perfil: str) -> bool:
    """Retorna True se o perfil exige 2FA em todo login."""
    return perfil in ("admin", "analista", "gestor_frota", "posto")

def _mfa_render_tela_verificacao(email: str, segredo: str) -> bool:
    """
    Exibe tela de verificação MFA.
    Retorna True se o código foi validado com sucesso nesta chamada.
    """
    st.markdown(
        "<div style='max-width:420px;margin:60px auto 0;padding:32px 28px;"
        "background:#fff;border:1px solid #e0e0e0;border-radius:14px;"
        "box-shadow:0 4px 20px rgba(0,0,0,.08)'>"
        "<div style='text-align:center;margin-bottom:24px'>"
        "<div style='font-size:2.2rem'>🔐</div>"
        "<h2 style='margin:8px 0 4px;font-size:1.3rem;color:#1B2B5E'>Verificação em duas etapas</h2>"
        "<p style='color:#666;font-size:13px;margin:0'>"
        f"Conta: <strong>{email}</strong></p>"
        "</div>",
        unsafe_allow_html=True,
    )
    st.markdown(
        "<p style='color:#555;font-size:13px;text-align:center;margin-bottom:8px'>"
        "Abra o <strong>Google Authenticator</strong> ou <strong>Authy</strong> "
        "e insira o código de 6 dígitos:</p>",
        unsafe_allow_html=True,
    )
    _codigo = st.text_input(
        "Código 2FA",
        max_chars=6,
        placeholder="000000",
        key="_mfa_codigo_input",
        label_visibility="collapsed",
    )
    _col_ok, _col_sair = st.columns([3, 1])
    with _col_ok:
        _btn_ok = st.button("✅ Verificar", type="primary", use_container_width=True,
                            key="_mfa_btn_verificar")
    with _col_sair:
        if st.button("↩ Sair", use_container_width=True, key="_mfa_btn_sair"):
            for _k in list(st.session_state.keys()):
                if _k.startswith(("_auth", "_acesso", "_empresa", "_todas_emp",
                                   "_admin_empresa", "_github_sync", "_mfa")):
                    del st.session_state[_k]
            st.rerun()

    if _btn_ok:
        if not _codigo or len(_codigo.strip()) != 6:
            st.error("Digite os 6 dígitos do código.")
        else:
            # A07: Rate limiting nas tentativas de verificação MFA
            _rl_ok, _rl_wait = _sec_rate_limit(segredo[:8], "mfa_verify")
            if not _rl_ok:
                st.error(f"🚫 Muitas tentativas incorretas. Aguarde {_rl_wait}s antes de tentar novamente.")
                _sec_log_evento("MFA_FAIL", "Rate limit MFA atingido", "WARN")
            elif _mfa_verificar_codigo(segredo, _codigo):
                _sec_reset_rate_limit(segredo[:8], "mfa_verify")
                _sec_log_evento("MFA_OK", "Verificação MFA bem-sucedida", "INFO")
                st.session_state["_auth_mfa_verificado"] = True
                st.rerun()
                return True
            else:
                _sec_log_evento("MFA_FAIL", "Código TOTP inválido", "WARN")
                st.error("❌ Código inválido ou expirado. Tente novamente.")
    st.markdown("</div>", unsafe_allow_html=True)
    return False

def _mfa_render_setup_inicial(email: str, segredo: str):
    """
    Tela de configuração inicial do MFA.
    Exibe QR code via <img> apontando para API pública — sem dependência de lib.
    """
    import urllib.parse as _up
    _uri    = _mfa_uri(email, segredo)
    _params = _up.urlencode({"size": "220x220", "data": _uri, "ecc": "M"})
    _qr_url = f"https://api.qrserver.com/v1/create-qr-code/?{_params}"

    _sc1, _sc2, _sc3 = st.columns([1, 2, 1])
    with _sc2:
        st.markdown(
            "<div style='text-align:center;padding:28px 20px 20px;"
            "background:#fff;border:1px solid #dde3f0;border-radius:14px;"
            "box-shadow:0 4px 18px rgba(27,43,94,.10);margin-bottom:16px'>"
            "<div style='font-size:2.4rem;margin-bottom:8px'>🔐</div>"
            "<h2 style='margin:0 0 4px;font-size:1.2rem;color:#1B2B5E'>"
            "Configure a autenticação em 2 etapas</h2>"
            f"<p style='color:#888;font-size:12px;margin:0 0 20px'>{email}</p>"
            f"<img src='{_qr_url}' width='200' height='200' "
            "style='border:6px solid #f5f5f5;border-radius:8px;"
            "box-shadow:0 2px 8px rgba(0,0,0,.12);display:block;margin:0 auto 16px' "
            "alt='QR Code 2FA'/>"
            "</div>",
            unsafe_allow_html=True,
        )

        st.markdown(
            "**Como configurar (uma única vez):**\n\n"
            "1. Instale o **Google Authenticator** ou **Authy** no celular\n"
            "2. Toque em **+** > **Ler QR code**\n"
            "3. Aponte a camera para o QR acima\n"
            "4. Digite abaixo o codigo de 6 digitos que aparecer no app"
        )

        with st.expander("🔑 Não consegue escanear? Use a chave manual"):
            st.code(segredo, language=None)
            st.caption(
                "No Authenticator: toque em **+** → **Inserir chave de configuração** "
                "→ cole a chave acima → Tipo: **Baseado em tempo**"
            )

        _codigo_setup = st.text_input(
            "Código de 6 dígitos gerado pelo app",
            max_chars=6,
            placeholder="000000",
            key="_mfa_setup_codigo",
        )
        _c1s, _c2s = st.columns([3, 1])
        with _c1s:
            _btn_confirmar = st.button(
                "✅ Confirmar e acessar", type="primary",
                use_container_width=True, key="_mfa_setup_confirmar"
            )
        with _c2s:
            if st.button("↩ Sair", use_container_width=True, key="_mfa_setup_sair"):
                for _k in list(st.session_state.keys()):
                    if _k.startswith(("_auth", "_acesso", "_empresa", "_todas_emp",
                                       "_admin_empresa", "_github_sync", "_mfa")):
                        del st.session_state[_k]
                st.rerun()

        if _btn_confirmar:
            if not _codigo_setup or len(_codigo_setup.strip()) != 6:
                st.error("Digite os 6 dígitos exibidos no app.")
            elif _mfa_verificar_codigo(segredo, _codigo_setup):
                # Setup OK: marca como verificado e limpa tmp para não regenerar
                st.session_state["_auth_mfa_verificado"]  = True
                st.session_state.pop("_mfa_setup_secret_tmp", None)
                st.session_state["_mfa_tentativas"]       = 0
                st.rerun()
            else:
                st.error("❌ Código inválido. Aguarde o próximo código (30s) e tente novamente.")



# ═══════════════════════════════════════════════════════════════════
#  ADMIN — Gestão de Usuários
# ═══════════════════════════════════════════════════════════════════

def _admin_listar_usuarios() -> list[dict]:
    """Retorna lista de todos os usuários cadastrados."""
    _db = _db_client()
    if _db is None:
        return []
    try:
        _r = (_db.table("usuarios_app")
                  .select("id,email,nome,perfil,cnpj_vinculado,empresa_nome,ativo,mfa_habilitado,created_at")
                  .order("created_at", desc=True)
                  .execute())
        return _r.data or []
    except Exception as _e:
        _err = str(_e)
        if "42P01" in _err or "PGRST205" in _err or "usuarios_app" in _err:
            st.warning(
                "⚠️ A tabela **usuarios_app** ainda não foi criada no Supabase. "
                "Execute o arquivo **`setup_completo.sql`** no SQL Editor do Supabase Dashboard "
                "para ativar o sistema de usuários.",
                icon="🗄️",
            )
        return []


def _admin_salvar_usuario(email: str, nome: str, perfil: str,
                          cnpj: str, empresa: str, ativo: bool) -> tuple[bool, str]:
    """Cria ou atualiza um usuário. Retorna (sucesso, mensagem)."""
    _db = _db_client()
    if _db is None:
        return False, "Banco não disponível"
    try:
        _dados = {
            "email":          email.strip().lower(),
            "nome":           nome.strip(),
            "perfil":         perfil,
            "cnpj_vinculado": cnpj.strip() or None,
            "empresa_nome":   empresa.strip() or None,
            "ativo":          ativo,
        }
        (_db.table("usuarios_app")
            .upsert(_dados, on_conflict="email")
            .execute())
        return True, f"Usuário {email} salvo com sucesso."
    except Exception as _e:
        _emsg = str(_e)
        if "42P01" in _emsg or "PGRST205" in _emsg:
            return False, "Tabela usuarios_app não encontrada. Execute setup_completo.sql no Supabase."
        return False, _emsg


def _admin_excluir_usuario(email: str) -> tuple[bool, str]:
    """Desativa (soft-delete) um usuário."""
    _db = _db_client()
    if _db is None:
        return False, "Banco não disponível"
    try:
        (_db.table("usuarios_app")
            .update({"ativo": False})
            .eq("email", email)
            .execute())
        return True, f"Usuário {email} desativado."
    except Exception as _e:
        return False, str(_e)


@_fragment
def _render_admin_usuarios():
    """Renderiza o painel de gerenciamento de usuários (apenas para admin)."""
    if not _auth_tem_permissao("func_gerenciar_users"):
        st.warning("⛔ Acesso restrito a administradores.")
        return

    st.markdown("### 👥 Gerenciamento de Usuários")

    _usuarios = _admin_listar_usuarios()

    # ── Tabela de usuários ────────────────────────────────────────
    if _usuarios:
        _df_u = pd.DataFrame(_usuarios)
        _badge = {
            "admin":        "🔴 Admin",
            "analista":     "🟠 Analista",
            "gestor_frota": "🟢 Gestor de Frota",
            "posto":        "🔵 Posto / Rede",
        }
        _df_u["Perfil"]  = _df_u["perfil"].map(_badge).fillna(_df_u["perfil"])
        _df_u["Status"]  = _df_u["ativo"].map({True: "✅ Ativo", False: "❌ Inativo"})
        _df_u["Criado"]  = pd.to_datetime(_df_u["created_at"]).dt.strftime("%d/%m/%Y")
        _df_u["2FA"]     = _df_u.get("mfa_habilitado", pd.Series([False]*len(_df_u))).map(
                               {True: "🔐 Ativo", False: "⬜ Inativo"})
        _df_show = _df_u[["email","nome","Perfil","cnpj_vinculado","empresa_nome","Status","2FA","Criado"]]
        _df_show.columns = ["E-mail","Nome","Perfil","CNPJ Vinculado","Empresa","Status","2FA","Criado"]
        st.dataframe(_df_show, use_container_width=True, hide_index=True)
    else:
        st.info("Nenhum usuário cadastrado ainda.")

    st.divider()

    # ── Seção MFA ─────────────────────────────────────────────────
    st.markdown("#### 🔐 Gerenciar 2FA dos Usuários")
    st.caption(
        "Gere o QR code de configuração do Google Authenticator para cada usuário. "
        "Envie o QR (screenshot) para o usuário escanear no app Authenticator."
    )

    if _usuarios:
        _emails_mfa = [u["email"] for u in _usuarios if u.get("ativo", True)]
        _sel_email_mfa = st.selectbox(
            "Selecione o usuário", _emails_mfa, key="admin_mfa_email_sel"
        )
        _usuario_sel = next((u for u in _usuarios if u["email"] == _sel_email_mfa), {})
        _mfa_ja_ativo = _usuario_sel.get("mfa_habilitado", False)
        _mfa_tem_seg  = bool(_usuario_sel.get("mfa_secret"))

        _mc1, _mc2 = st.columns(2)
        with _mc1:
            if st.button(
                "🔐 Gerar novo QR code para este usuário",
                key="btn_admin_gerar_mfa",
                use_container_width=True,
                type="primary",
            ):
                _novo_seg_admin = _mfa_gerar_segredo()
                if _mfa_salvar_no_db(_sel_email_mfa, _novo_seg_admin, True):
                    st.session_state["_admin_mfa_preview_email"]  = _sel_email_mfa
                    st.session_state["_admin_mfa_preview_secret"] = _novo_seg_admin
                    st.success(f"✅ Segredo 2FA gerado para {_sel_email_mfa}. Mostre o QR abaixo ao usuário.")
                    st.rerun()
                else:
                    st.error("Erro ao salvar segredo no banco.")
        with _mc2:
            if _mfa_ja_ativo and st.button(
                "🚫 Desativar 2FA deste usuário",
                key="btn_admin_desativar_mfa",
                use_container_width=True,
            ):
                _mfa_salvar_no_db(_sel_email_mfa, "", False)
                st.warning(f"2FA desativado para {_sel_email_mfa}.")
                st.rerun()

        # Exibe QR se acabou de ser gerado
        _prev_email  = st.session_state.get("_admin_mfa_preview_email", "")
        _prev_secret = st.session_state.get("_admin_mfa_preview_secret", "")
        if _prev_email == _sel_email_mfa and _prev_secret:
            import urllib.parse as _up_adm
            _uri_adm    = _mfa_uri(_prev_email, _prev_secret)
            _params_adm = _up_adm.urlencode({"size": "220x220", "data": _uri_adm, "ecc": "M"})
            _qr_url_adm = f"https://api.qrserver.com/v1/create-qr-code/?{_params_adm}"
            st.markdown(f"**QR code para** `{_prev_email}`:")
            _qa1, _qa2, _qa3 = st.columns([1, 2, 1])
            with _qa2:
                st.markdown(
                    f"<img src='{_qr_url_adm}' width='200' height='200' "
                    "style='border:6px solid #f5f5f5;border-radius:8px;"
                    "box-shadow:0 2px 8px rgba(0,0,0,.12);display:block;margin:0 auto' "
                    "alt='QR Code 2FA'/>",
                    unsafe_allow_html=True,
                )
            st.info("📌 Instrua o usuário a escanear este QR antes do próximo login. "
                    "O código expira a cada 30 segundos.")
            with st.expander("🔑 Chave manual (se não conseguir escanear)"):
                st.code(_prev_secret, language=None)

        # Status atual
        if _mfa_ja_ativo and _mfa_tem_seg:
            st.success(f"🔐 2FA **ativo** para {_sel_email_mfa}")
        elif _mfa_ja_ativo and not _mfa_tem_seg:
            st.warning(f"⚠️ 2FA marcado como ativo mas sem segredo. Gere um novo QR.")
        else:
            st.info(f"⬜ 2FA **inativo** para {_sel_email_mfa}. Clique em 'Gerar novo QR code' para ativar.")

    st.divider()

    # ── Formulário: Adicionar / Editar ────────────────────────────
    st.markdown("#### ➕ Adicionar / Editar Usuário")

    # Seletor de perfil FORA do form para controlar campos dinamicamente
    _u_perfil = st.selectbox("Perfil *", [
        "posto", "gestor_frota", "analista", "admin"
    ], format_func=lambda x: {
        "admin":        "🔴 Admin (acesso total — sem CNPJ necessário)",
        "analista":     "🟠 Analista Interno — sem CNPJ necessário",
        "gestor_frota": "🟢 Gestor de Frota",
        "posto":        "🔵 Posto / Rede",
    }.get(x, x), key="form_perfil_sel")

    _precisa_cnpj = _u_perfil in ("posto", "gestor_frota")

    with st.form("form_add_usuario", clear_on_submit=True):
        _c1, _c2 = st.columns(2)
        with _c1:
            _u_email   = st.text_input("E-mail Google *", placeholder="usuario@empresa.com")
            _u_nome    = st.text_input("Nome", placeholder="João Silva")
            st.markdown(
                f"**Perfil selecionado:** { {'admin':'🔴 Admin','analista':'🟠 Analista','gestor_frota':'🟢 Gestor de Frota','posto':'🔵 Posto / Rede'}.get(_u_perfil,_u_perfil) }"
            )
        with _c2:
            if _precisa_cnpj:
                _u_cnpj    = st.text_input("CNPJ Vinculado *",
                                           placeholder="CNPJ do posto ou empresa de frota",
                                           help="Somente dígitos ou formatado (XX.XXX.XXX/XXXX-XX)")
                _u_empresa = st.text_input("Nome da Empresa / Posto *",
                                           placeholder="Ex: Posto Central Ltda")
            else:
                _u_cnpj    = ""
                _u_empresa = ""
                st.info(
                    "🔓 Perfil **Admin** e **Analista** têm visão total da aplicação "
                    "— CNPJ e empresa não são necessários.",
                    icon="ℹ️",
                )
            _u_ativo = st.checkbox("Usuário ativo", value=True)
        _sub = st.form_submit_button("💾 Salvar Usuário", type="primary",
                                     use_container_width=True)
        if _sub:
            _email_ok, _email_err = _sec_validar_email(_u_email)
            _cnpj_ok  = True
            _cnpj_err = ""
            if _precisa_cnpj:
                _cnpj_ok, _cnpj_err = _sec_validar_cnpj(_u_cnpj)
            if not _email_ok:
                st.error(f"E-mail inválido: {_email_err}")
            elif _precisa_cnpj and not _cnpj_ok:
                st.error(f"CNPJ inválido: {_cnpj_err}")
            else:
                _ok, _msg = _admin_salvar_usuario(
                    _u_email, _u_nome, _u_perfil, _u_cnpj, _u_empresa, _u_ativo
                )
                if _ok:
                    _sec_log_evento("ADMIN_ACTION",
                                    f"Usuário salvo: {_sec_sanitizar(_u_email)} perfil={_u_perfil}",
                                    "INFO")
                    st.success(_msg)
                    st.rerun()
                else:
                    st.error(f"Erro: {_msg}")


# ── Rotas ──────────────────────────────────────────────────────────

@st.cache_data(show_spinner=False, ttl=600)  # 10 min
def _db_carregar_rotas() -> list:
    """Carrega rotas do Supabase. Fallback para JSON local."""
    db = _db_client()
    if db:
        try:
            res = db.table("rotas_salvas") \
                    .select("*") \
                    .eq("usuario_email", _db_email()) \
                    .order("criado_em", desc=True) \
                    .execute()
            return [{"id": r["id"], "nome": r["nome"], "tipo": r["tipo"],
                     "criado_em": r["criado_em"], **r.get("dados", {})}
                    for r in (res.data or [])]
        except Exception:
            pass
    return _carregar_rotas_salvas_local()


def _db_salvar_rota(nome: str, tipo: str, dados: dict) -> bool:
    """Salva rota no Supabase. Fallback para JSON local."""
    db = _db_client()
    _id = f"{int(time.time())}_{nome[:8]}"
    # Garante que dados é JSON puro (converte numpy, datetime, etc.)
    try:
        _dados_json = _json_mod.loads(_json_mod.dumps(dados, default=str))
    except Exception:
        _dados_json = {}
    if db:
        try:
            db.table("rotas_salvas").insert({
                "id":            _id,
                "usuario_email": _db_email(),
                "nome":          nome.strip() or "Rota",
                "tipo":          tipo,
                "criado_em":     _agora(),
                "dados":         _dados_json,
            }).execute()
            return True
        except Exception as _e:
            st.warning(f"⚠️ Banco indisponível ({_e}), salvando localmente.", icon="💾")
    return _salvar_rota_nova_local(nome, tipo, dados)


def _db_deletar_rota(rota_id: str) -> bool:
    """Remove rota do Supabase. Fallback para JSON local."""
    db = _db_client()
    if db:
        try:
            db.table("rotas_salvas") \
              .delete() \
              .eq("id", rota_id) \
              .eq("usuario_email", _db_email()) \
              .execute()
            return True
        except Exception:
            pass
    return _deletar_rota_local(rota_id)


# ── Preferências ───────────────────────────────────────────────────

def _db_salvar_preferencias(placa: str = "", combustivel: str = "",
                             autonomia: float = 0.0, capacidade: float = 0.0,
                             extras: dict = None) -> bool:
    """Grava preferências do usuário no Supabase."""
    db = _db_client()
    if not db:
        return False
    try:
        db.table("preferencias").upsert({
            "usuario_email": _db_email(),
            "placa":         placa,
            "combustivel":   combustivel,
            "autonomia":     autonomia,
            "capacidade":    capacidade,
            "extras":        extras or {},
            "atualizado_em": _now_bsb().isoformat(),
        }).execute()
        return True
    except Exception:
        return False


def _db_carregar_preferencias() -> dict:
    """Carrega preferências do usuário do Supabase."""
    db = _db_client()
    if not db:
        return {}
    try:
        res = db.table("preferencias") \
                .select("*") \
                .eq("usuario_email", _db_email()) \
                .limit(1) \
                .execute()
        if res.data:
            return res.data[0]
    except Exception:
        pass
    return {}


# ── Frota: Abastecimentos ─────────────────────────────────────────

def _db_salvar_abastecimentos(df_rows: list, nome_arquivo: str) -> tuple[int, str]:
    """
    Salva lista de dicts de abastecimentos no Supabase.
    Faz upsert usando (usuario_email, id_transacao) como chave única.
    Retorna (n_salvos, mensagem_erro_ou_vazio).
    """
    db = _db_client()
    if not db:
        return 0, "Supabase não configurado"
    email = _db_email()
    if not email:
        return 0, "Usuário não autenticado"
    _eid = _db_empresa_id()
    try:
        for row in df_rows:
            row["usuario_email"] = email
            if _eid:
                row["empresa_id"] = _eid
        res = db.table("frota_abastecimentos").upsert(
            df_rows,
            on_conflict="usuario_email,id_transacao",
            ignore_duplicates=True,
        ).execute()
        n = len(res.data) if res.data else 0
        # Registra upload
        if df_rows:
            datas = [r.get("data_abastecimento") for r in df_rows if r.get("data_abastecimento")]
            db.table("frota_uploads").insert({
                "usuario_email": email,
                "nome_arquivo":  nome_arquivo,
                "n_registros":   len(df_rows),
                "n_veiculos":    len({r.get("placa") for r in df_rows if r.get("placa")}),
                "periodo_ini":   min(datas) if datas else None,
                "periodo_fim":   max(datas) if datas else None,
            }).execute()
        return n, ""
    except Exception as _e:
        return 0, str(_e)


@st.cache_data(show_spinner=False, ttl=300)  # 5 min — invalidar após sync
def _db_carregar_abastecimentos() -> list:
    """
    Carrega abastecimentos do Supabase com paginação automática.
    Usa _db_paginar() para contornar o limite de 1000 linhas do PostgREST.
    Estratégia em camadas para cobrir registros legados sem empresa_id.
    """
    db = _db_client()
    if not db:
        return []

    try:
        _eid   = _db_empresa_id()
        _email = _db_email()

        # 1. Filtra por empresa_id — paginação completa
        if _eid:
            _rows = _db_paginar(
                "frota_abastecimentos", "*",
                filters=[("empresa_id", _eid)],
                order_by="data_abastecimento", order_desc=True,
            )
            if _rows:
                return _rows

        # 2. Filtra por e-mail do usuário
        if _email:
            _rows = _db_paginar(
                "frota_abastecimentos", "*",
                filters=[("usuario_email", _email)],
                order_by="data_abastecimento", order_desc=True,
            )
            if _rows:
                return _rows

        # 3. Sem filtros — retorna tudo (admin / dados legados sem vínculo)
        return _db_paginar(
            "frota_abastecimentos", "*",
            order_by="data_abastecimento", order_desc=True,
        )

    except Exception:
        try:
            return _db_paginar("frota_abastecimentos", "*",
                               order_by="data_abastecimento", order_desc=True)
        except Exception:
            return []


@st.cache_data(show_spinner=False, ttl=300)  # 5 min
def _carregar_abastecimentos_unificados(dias: int = 730) -> pd.DataFrame:
    """
    Carrega abastecimentos de TODAS as fontes disponíveis e retorna um
    DataFrame unificado com colunas no formato padrão (sem prefixo _):
      data_abastecimento, placa, motorista, produto, litros, preco_litro,
      valor_total, cnpj_posto, nome_posto, cidade_posto, uf_posto,
      lat_posto, lon_posto, cnpj_frota, fonte.

    Fontes combinadas:
      1. frota_abastecimentos  — uploads manuais via Análise de Cliente
      2. profrotas_abastecimentos — API GestãoFrotas sincronizada
    """
    dfs = []

    # ── Fonte 1: uploads manuais ───────────────────────────────────
    try:
        _rows = _db_carregar_abastecimentos()
        if _rows:
            _df1 = pd.DataFrame(_rows)
            # Garante colunas normalizadas sem prefixo
            _df1["fonte"] = _df1.get("nome_arquivo", pd.Series(["upload"] * len(_df1)))
            dfs.append(_df1)
    except Exception:
        pass

    # ── Fonte 2: API ProFrotas ─────────────────────────────────────
    try:
        _df_pf = _profrotas_para_df_analise(None, dias)
        if _df_pf is not None and not _df_pf.empty:
            # _profrotas_para_df_analise retorna colunas com prefixo _.
            # Remapeia para o formato padrão sem prefixo.
            _map = {
                "_data":          "data_abastecimento",
                "_placa":         "placa",
                "_motorista":     "motorista",
                "_produto":       "produto",
                "_litros":        "litros",
                "_preco_litro":   "preco_litro",
                "_valor_total":   "valor_total",
                "_cnpj_posto":    "cnpj_posto",
                "_nome_posto":    "nome_posto",
                "_cidade_posto":  "cidade_posto",
                "_uf_posto":      "uf_posto",
                "_lat_posto":     "lat_posto",
                "_lon_posto":     "lon_posto",
                "_cnpj_frota":    "cnpj_frota",
                "_razao_frota":   "razao_frota",
                "_hod_atual":     "hodometro",
                "_fonte":         "fonte",
            }
            _df2 = _df_pf.rename(columns=_map)
            dfs.append(_df2)
    except Exception:
        pass

    if not dfs:
        return pd.DataFrame()

    _unified = pd.concat(dfs, ignore_index=True)

    # Normaliza tipos
    for _c in ["litros", "preco_litro", "valor_total", "lat_posto", "lon_posto"]:
        if _c in _unified.columns:
            _unified[_c] = pd.to_numeric(_unified[_c], errors="coerce")

    if "data_abastecimento" in _unified.columns:
        _unified["data_abastecimento"] = pd.to_datetime(
            _unified["data_abastecimento"], errors="coerce"
        )
        # Aplica corte por data_abastecimento em TODAS as fontes de forma uniforme.
        # Este é o filtro primário: dados fora do período simplesmente não são retornados.
        _cutoff_dt = pd.Timestamp.now(tz=None) - pd.Timedelta(days=dias)
        _unified = _unified[
            _unified["data_abastecimento"].dt.tz_localize(None).fillna(
                pd.Timestamp("2000-01-01")) >= _cutoff_dt
        ].copy()

    return _unified


# ── Rede GF — postos_gf ───────────────────────────────────────────

def _normalizar_cnpj14(v) -> str:
    """Normaliza qualquer valor para string de exatamente 14 dígitos com zero-padding."""
    _s = str(v or "")
    # Se for float com .0, converte para int primeiro para evitar "22912349000132.0"
    if "." in _s:
        try:
            _s = str(int(float(_s)))
        except Exception:
            pass
    return re.sub(r"\D", "", _s).zfill(14)


def _db_paginar(table_name: str, select_cols: str,
                filters: "list[tuple] | None" = None,
                page_size: int = 1000,
                order_by: "str | None" = None,
                order_desc: bool = False) -> list:
    """
    Busca TODOS os registros de uma tabela Supabase usando paginação automática.
    Contorna o limite padrão de 1000 linhas por resposta do PostgREST.

    Parâmetros:
      filters  : lista de (campo, valor) aplicados como .eq()
      order_by : coluna para ordenação (ex: "data_abastecimento")
      order_desc: True para ORDER BY DESC
    """
    _db = _db_client()
    if _db is None:
        return []
    todos: list = []
    offset = 0
    while True:
        try:
            _q = _db.table(table_name).select(select_cols)
            if filters:
                for _campo, _valor in filters:
                    _q = _q.eq(_campo, _valor)
            if order_by:
                _q = _q.order(order_by, desc=order_desc)
            _q = _q.range(offset, offset + page_size - 1)
            res = _q.execute()
            pagina = res.data or []
            todos.extend(pagina)
            if len(pagina) < page_size:
                break  # última página — sem mais dados
            offset += page_size
        except Exception:
            break
    return todos


def _db_carregar_cnpjs_postos_gf() -> set:
    """
    Retorna set de CNPJs (14 dígitos, zero-padded) da rede GF
    lidos da tabela postos_gf no Supabase (com paginação completa).
    """
    _eid = _db_empresa_id()
    _filters = [("empresa_id", _eid)] if _eid else None
    rows = _db_paginar("postos_gf", "cnpj", _filters)
    if rows:
        return {
            _normalizar_cnpj14(r.get("cnpj", ""))
            for r in rows
            if r.get("cnpj")
        }
    # fallback: session_state
    _pf = st.session_state.get("pf_coords_df")
    if _pf is not None and not _pf.empty and "cnpj_norm" in _pf.columns:
        return {_normalizar_cnpj14(c) for c in _pf["cnpj_norm"].dropna()}
    return set()


@st.cache_data(show_spinner=False, ttl=600)  # 10 min — dados de rede mudam menos
def _db_carregar_postos_gf_df() -> "pd.DataFrame":
    """
    Retorna DataFrame completo da rede GF (cnpj, razao_social,
    municipio, uf, lat, lon, perfil_venda) com paginação completa.
    """
    _eid = _db_empresa_id()
    _filters = [("empresa_id", _eid)] if _eid else None
    rows = _db_paginar(
        "postos_gf",
        "cnpj,razao_social,distribuidora,municipio,uf,lat,lon,perfil_venda",
        _filters,
    )
    if rows:
        _df_gf = pd.DataFrame(rows)
        _df_gf["cnpj_norm"] = _df_gf["cnpj"].apply(
            lambda v: re.sub(r"\D", "", str(v or ""))
        )
        return _df_gf
    return pd.DataFrame()


# ── Acordos de Preço (Posto × Frota × Combustível) ────────────────

# Mapeamento: nome do combustível na planilha de acordos → pk usado no sistema
_ACORDOS_PARA_PK = {
    "diesel s-10 comum":     "DIESEL S-10 COMUM",
    "diesel s-10 aditivado": "DIESEL S-10 ADITIVADO",
    "diesel s-500 comum":    "DIESEL S-500 COMUM",
    "diesel s-500 aditivado":"DIESEL S-500 ADITIVADO",
    "gasolina comum":        "GASOLINA COMUM",
    "gasolina aditivada":    "GASOLINA ADITIVADA",
    "gasolina alta octanagem":"GASOLINA PREMIUM",
    "etanol comum":          "ETANOL HIDRATADO",
    "etanol aditivado":      "ETANOL HIDRATADO ADITIVADO",
    "gnv":                   "GNV",
}

_REPO_SUBPASTA = "estudo-de-rede"
_REPO_BASE_URL = (
    "https://raw.githubusercontent.com/dperuffo/estudo-de-rede"
    f"/master/{_REPO_SUBPASTA}"
)
_ACORDOS_GITHUB_URL = f"{_REPO_BASE_URL}/Acordos.xlsx"


def _normalizar_cnpj_str(v) -> str:
    """Normaliza qualquer valor para string de 14 dígitos (CNPJ)."""
    return re.sub(r"\D", "", str(int(v)) if isinstance(v, float) else str(v or "")).zfill(14)


@st.cache_data(show_spinner=False, ttl=300)  # 5 min
def _db_carregar_acordos() -> "pd.DataFrame":
    """
    Carrega acordos de preço do Supabase com paginação automática.
    Estratégia em camadas para cobrir registros legados sem empresa_id:
      1. Filtra por empresa_id  → se vazio, tenta próxima camada
      2. Filtra por usuario_email → se vazio, tenta próxima camada
      3. Sem filtro (retorna tudo — admin / dados legados)
    """
    _COLS = ("cnpj_posto,nome_posto,cnpj_frota,razao_social_frota,"
             "combustivel,preco_negociado,va_desconto,dt_vigencia")

    def _to_df(rows):
        if not rows:
            return None
        _df = pd.DataFrame(rows)
        _df["dt_vigencia"] = pd.to_datetime(_df["dt_vigencia"], errors="coerce")
        # Normaliza preco_negociado: valores > 50 estão em centésimos de centavo (×10000)
        if "preco_negociado" in _df.columns:
            _df["preco_negociado"] = pd.to_numeric(_df["preco_negociado"], errors="coerce")
            _pn_med = _df["preco_negociado"].dropna()
            if not _pn_med.empty and _pn_med.median() > 50:
                _df["preco_negociado"] = (_df["preco_negociado"] / 10_000).round(4)
        return _df

    try:
        _eid   = _db_empresa_id()
        _email = _db_email()

        # 1. Filtra por empresa_id
        if _eid:
            _df = _to_df(_db_paginar("acordos_precos", _COLS, filters=[("empresa_id", _eid)]))
            if _df is not None:
                return _df

        # 2. Filtra por e-mail do usuário
        if _email:
            _df = _to_df(_db_paginar("acordos_precos", _COLS, filters=[("usuario_email", _email)]))
            if _df is not None:
                return _df

        # 3. Sem filtro — retorna tudo (admin / dados legados)
        _df = _to_df(_db_paginar("acordos_precos", _COLS))
        if _df is not None:
            return _df
    except Exception:
        pass
    return pd.DataFrame()


# ── Postos GF — salvar / restaurar ───────────────────────────────────────────

def _db_salvar_postos_gf(df_coords: "pd.DataFrame",
                          cnpjs_set: set,
                          perfil_map: dict,
                          nome_arquivo: str = "") -> tuple:
    """
    Substitui TODOS os registros de postos_gf do usuário (DELETE filtrado por
    empresa_id/email → INSERT todos os CNPJs da nova planilha).
    Garante que o banco reflita exatamente o conteúdo do upload mais recente.
    Retorna (n_salvos, erro_str).  n_salvos == -1 em caso de falha total.
    """
    _db = _db_client()
    if _db is None:
        return -1, "Sem conexão com o banco de dados."
    if not cnpjs_set:
        return -1, "Conjunto de CNPJs está vazio."

    try:
        _eid   = _db_empresa_id()
        _email = _db_email()

        # ── Índice cnpj → row de df_coords (para enriquecer com dados da planilha) ──
        # Aceita "cnpj_norm" (padrão Supabase) ou "cnpj" (retorno direto de _processar_bytes_pro_frotas)
        _coords_idx: dict = {}
        if df_coords is not None and not df_coords.empty:
            _cnpj_col_gf = "cnpj_norm" if "cnpj_norm" in df_coords.columns else (
                           "cnpj"      if "cnpj"      in df_coords.columns else None)
            if _cnpj_col_gf:
                # Vetorizado: sem iterrows()
                _coords_idx = {
                    str(k).strip(): df_coords.loc[i]
                    for i, k in df_coords[_cnpj_col_gf].items()
                    if str(k).strip()
                }

        # ── Monta registros para TODOS os CNPJs do conjunto ───────
        registros = []
        for _cnpj in cnpjs_set:
            _cnpj = str(_cnpj).strip()
            if not _cnpj:
                continue
            row = _coords_idx.get(_cnpj, {})
            _lat = row.get("_lat") if hasattr(row, "get") else None
            _lon = row.get("_lon") if hasattr(row, "get") else None
            _rec = {
                "cnpj":           _cnpj,
                "razao_social":   str(row.get("razaoSocial", "") or "").strip() or None
                                  if hasattr(row, "get") else None,
                "distribuidora":  str(row.get("distribuidora", "") or "").strip() or None
                                  if hasattr(row, "get") else None,
                "municipio":      str(row.get("municipio", "") or "").strip() or None
                                  if hasattr(row, "get") else None,
                "uf":             str(row.get("uf", "") or "").strip() or None
                                  if hasattr(row, "get") else None,
                "lat":            float(_lat) if _lat and str(_lat) not in ("", "nan") else None,
                "lon":            float(_lon) if _lon and str(_lon) not in ("", "nan") else None,
                "perfil_venda":   perfil_map.get(_cnpj) if perfil_map else None,
                "horario":        str(row.get("horario", "") or "").strip() or None
                                  if hasattr(row, "get") else None,
                "funciona_24h":   bool(row.get("funciona_24h", False))
                                  if hasattr(row, "get") else False,
                "pista_caminhao": bool(row.get("pista_caminhao", False))
                                  if hasattr(row, "get") else False,
                "arla":           bool(row.get("arla", False))
                                  if hasattr(row, "get") else False,
                "conveniencia":   bool(row.get("conveniencia", False))
                                  if hasattr(row, "get") else False,
            }
            if _eid:
                _rec["empresa_id"] = _eid
            if _email:
                _rec["usuario_email"] = _email
            registros.append(_rec)

        # ── DELETE registros existentes deste usuário/empresa ─────
        _del_q = _db.table("postos_gf").delete()
        if _eid:
            _del_q = _del_q.eq("empresa_id", _eid)
        elif _email:
            _del_q = _del_q.eq("usuario_email", _email)
        else:
            _del_q = _del_q.neq("cnpj", "__NONE__")  # delete all if no filter
        _del_q.execute()

        # ── INSERT todos em lotes de 500 ──────────────────────────
        _salvos = 0
        for i in range(0, len(registros), 500):
            _lote = registros[i:i+500]
            _resp = _db.table("postos_gf").insert(_lote).execute()
            _salvos += len(_resp.data or [])

        # ── Versão ────────────────────────────────────────────────
        _n_coords = sum(1 for r in registros if r.get("lat") is not None)
        _db.table("postos_gf_versoes").insert({
            "usuario_email": _email or "",
            "nome_arquivo":  nome_arquivo or "upload_manual",
            "n_cnpjs":       _salvos,
            "n_coords":      _n_coords,
        }).execute()

        return _salvos, ""
    except Exception as _e:
        return -1, str(_e)


def _db_restaurar_postos_gf() -> None:
    """
    Carrega CNPJs, perfil_map e pf_coords_df da tabela postos_gf do Supabase.
    Chamada uma vez por sessão; usa setdefault para não sobrescrever dados mais recentes.
    """
    if st.session_state.get("_pf_restaurado_supabase"):
        return
    st.session_state["_pf_restaurado_supabase"] = True
    try:
        _df_gf = _db_carregar_postos_gf_df()
        if _df_gf.empty:
            return
        _cnpjs = {str(r) for r in _df_gf["cnpj_norm"].dropna() if r}
        if not _cnpjs:
            return
        st.session_state.setdefault("cnpjs_pro_frotas", _cnpjs)
        st.session_state.setdefault("_pf_fonte",        "supabase")
        st.session_state.setdefault("_pf_carregado_em", "banco de dados")
        # perfil_venda_map
        if "perfil_venda" in _df_gf.columns:
            # Vetorizado: sem iterrows()
            _mask_pv = _df_gf["perfil_venda"].notna() & (_df_gf["perfil_venda"].astype(str).str.strip() != "")
            _pm = dict(zip(
                _df_gf.loc[_mask_pv, "cnpj_norm"].astype(str),
                _df_gf.loc[_mask_pv, "perfil_venda"].astype(str),
            ))
            if _pm:
                st.session_state.setdefault("perfil_venda_map", _pm)
                st.session_state.setdefault("perfis_pf_lista", sorted(set(_pm.values())))
        # pf_coords_df — normaliza nomes de colunas para o formato esperado pelo app
        _coords_cols = {
            "cnpj_norm": "cnpj_norm",
            "lat": "_lat", "lon": "_lon",
            "razao_social": "razaoSocial",
            "distribuidora": "distribuidora",
            "municipio": "municipio",
            "uf": "uf",
        }
        _available = {c: _coords_cols[c] for c in _coords_cols if c in _df_gf.columns}
        if len(_available) >= 3:
            _coords_df = _df_gf[list(_available.keys())].rename(columns=_available).copy()
            if not _coords_df.empty:
                # Garante coluna "cnpj" (alias de cnpj_norm) para compatibilidade downstream
                if "cnpj_norm" in _coords_df.columns and "cnpj" not in _coords_df.columns:
                    _coords_df["cnpj"] = _coords_df["cnpj_norm"]
                # Garante que todas as colunas esperadas existem (dados antigos podem não ter todas)
                _coords_defaults = {
                    "uf": "", "municipio": "", "distribuidora": "",
                    "razaoSocial": "", "_lat": None, "_lon": None,
                }
                for _cd_col, _cd_val in _coords_defaults.items():
                    if _cd_col not in _coords_df.columns:
                        _coords_df[_cd_col] = _cd_val
                st.session_state.setdefault("pf_coords_df", _coords_df)
                if not st.session_state.get("_servicos_pf_labels"):
                    _atualizar_servicos_pf(_coords_df)
    except Exception:
        pass


# ── Postos Cercados — salvar / restaurar ─────────────────────────────────────

def _db_salvar_postos_cercados(cnpjs_set: set, nome_arquivo: str = "") -> tuple:
    """
    Substitui TODOS os registros de postos_cercados_db pela nova carga
    (DELETE all → INSERT all) para garantir sincronismo total com a planilha.
    Retorna (n_salvos, erro_str).  n_salvos == -1 em caso de falha total.
    """
    _db = _db_client()
    if _db is None:
        return -1, "Sem conexão com o banco de dados."
    if not cnpjs_set:
        return -1, "Conjunto de CNPJs está vazio."

    # Filtra CNPJs inválidos antes de enviar
    _cnpjs_validos = {c for c in cnpjs_set if c and len(str(c).strip()) > 0}
    if not _cnpjs_validos:
        return -1, "Nenhum CNPJ válido para salvar."

    try:
        _email = _db_email()

        # ── 1. Remove todos os registros existentes ────────────────
        # (DELETE sem filtro — tabela não tem isolamento por empresa)
        _db.table("postos_cercados_db").delete().neq("cnpj", "__NONE__").execute()

        # ── 2. Insere os novos registros em lotes de 500 ──────────
        registros = [{"cnpj": str(c).strip()} for c in _cnpjs_validos]
        _salvos = 0
        for i in range(0, len(registros), 500):
            _lote = registros[i:i+500]
            _resp = _db.table("postos_cercados_db").insert(_lote).execute()
            _salvos += len(_resp.data or [])

        # ── 3. Versão ──────────────────────────────────────────────
        _db.table("postos_cercados_versoes").insert({
            "usuario_email": _email or "",
            "nome_arquivo":  nome_arquivo or "upload_manual",
            "n_cnpjs":       _salvos,
        }).execute()

        return _salvos, ""
    except Exception as _e:
        return -1, str(_e)


def _db_restaurar_postos_cercados() -> None:
    """
    Carrega CNPJs de postos cercados da tabela postos_cercados_db do Supabase.
    Chamada uma vez por sessão; usa setdefault para não sobrescrever dados mais recentes.
    """
    if st.session_state.get("_cer_restaurado_supabase"):
        return
    st.session_state["_cer_restaurado_supabase"] = True
    rows = _db_paginar("postos_cercados_db", "cnpj")
    if rows:
        _cnpjs = {str(r["cnpj"]) for r in rows if r.get("cnpj")}
        if _cnpjs:
            st.session_state.setdefault("cnpjs_cercados",         _cnpjs)
            st.session_state.setdefault("_cercados_fonte",        "supabase")
            st.session_state.setdefault("_cercados_carregado_em", "banco de dados")


# ── Preços por Posto — salvar tabela precos_posto_db ────────────────────────

def _db_salvar_precos_posto(pp_df: "pd.DataFrame", nome_arquivo: str = "") -> tuple:
    """
    Substitui TODOS os registros de precos_posto_db pela nova carga
    (DELETE all → INSERT all) para garantir sincronismo total.
    Também insere em historico_precos (preserva histórico por data).
    Retorna (n_salvos, erro_str).  n_salvos == -1 em caso de falha total.
    """
    _db = _db_client()
    if _db is None:
        return -1, "Sem conexão com o banco de dados."
    if pp_df is None or pp_df.empty:
        return -1, "DataFrame de preços está vazio."
    try:
        from datetime import date as _date
        _hoje = _date.today().isoformat()
        _email = _db_email()

        # ── Monta registros válidos ────────────────────────────────
        registros = []
        for _, row in pp_df.iterrows():
            _cnpj = str(row.get("cnpj_norm", "") or "").strip()
            _comb = str(row.get("combustivel_pk", "") or "").strip()
            if not _cnpj or not _comb:
                continue
            _preco = row.get("preco")
            registros.append({
                "cnpj_norm":         _cnpj,
                "combustivel_pk":    _comb,
                "combustivel_label": str(row.get("combustivel_label", "") or "").strip() or None,
                "preco":             float(_preco) if _preco is not None else None,
                "data_atualizacao":  str(row.get("data_atualizacao", "") or _hoje).strip() or _hoje,
            })

        if not registros:
            return -1, "Nenhum registro válido (cnpj_norm + combustivel_pk) encontrado."

        # ── DELETE todos os registros existentes ──────────────────
        _db.table("precos_posto_db").delete().neq("cnpj_norm", "__NONE__").execute()

        # ── INSERT em lotes de 500 ────────────────────────────────
        _salvos = 0
        for i in range(0, len(registros), 500):
            _lote = registros[i:i+500]
            _resp = _db.table("precos_posto_db").insert(_lote).execute()
            _salvos += len(_resp.data or [])

        # ── Versão ────────────────────────────────────────────────
        _n_postos = pp_df["cnpj_norm"].nunique() if "cnpj_norm" in pp_df.columns else 0
        _db.table("precos_posto_versoes").insert({
            "usuario_email": _email or "",
            "nome_arquivo":  nome_arquivo or "upload_manual",
            "n_registros":   _salvos,
            "n_postos":      int(_n_postos),
        }).execute()

        # ── Popula historico_precos (INSERT OR IGNORE por data) ───
        # O historico preserva uma linha por (cnpj, combustivel, data_ref)
        # permitindo análise temporal. Não deletamos histórico antigo.
        _hist_rows = []
        for _, row in pp_df.iterrows():
            _cnpj = str(row.get("cnpj_norm", "") or "").strip()
            _comb = str(row.get("combustivel_pk", "") or "").strip()
            _preco = row.get("preco")
            if not _cnpj or not _comb or _preco is None:
                continue
            _hist_rows.append({
                "cnpj":        _cnpj,
                "combustivel": _comb,
                "preco":       float(_preco),
                "data_ref":    _hoje,
                "fonte":       "upload_manual",
            })
        if _hist_rows:
            for i in range(0, len(_hist_rows), 500):
                try:
                    _db.table("historico_precos").upsert(
                        _hist_rows[i:i+500],
                        on_conflict="cnpj,combustivel,data_ref",
                    ).execute()
                except Exception:
                    pass

        return _salvos, ""
    except Exception as _e:
        return -1, str(_e)


def _processar_acordos_df(df_raw: "pd.DataFrame") -> "pd.DataFrame":
    """
    Normaliza o DataFrame bruto da planilha de acordos para o formato interno.
    Tolerante a variações nos nomes das colunas.
    """
    # ── Mapeamento de colunas com aliases alternativos ────────────────
    _col_map = {
        # cd_frota_ptov_preco
        "cd_frota_ptov_preco":   "cd_frota_ptov_preco",
        "CD_FROTA_PTOV_PRECO":   "cd_frota_ptov_preco",
        # combustivel
        "ds_tipo_combustivel":   "combustivel",
        "DS_TIPO_COMBUSTIVEL":   "combustivel",
        "Combustivel":           "combustivel",
        "combustivel":           "combustivel",
        "COMBUSTIVEL":           "combustivel",
        "Tipo Combustivel":      "combustivel",
        # preco negociado
        "Preco Negociado":       "preco_negociado",
        "preco_negociado":       "preco_negociado",
        "PRECO_NEGOCIADO":       "preco_negociado",
        "Preço Negociado":       "preco_negociado",
        "preco negociado":       "preco_negociado",
        # desconto
        "va_desconto_vigente":   "va_desconto",
        "VA_DESCONTO_VIGENTE":   "va_desconto",
        "va_desconto":           "va_desconto",
        # CNPJ posto
        "CNPJ do Posto":         "cnpj_posto_raw",
        "cnpj_posto":            "cnpj_posto_raw",
        "CNPJ_POSTO":            "cnpj_posto_raw",
        "CNPJ Posto":            "cnpj_posto_raw",
        "cnpj do posto":         "cnpj_posto_raw",
        # Nome posto
        "Nome do Posto":         "nome_posto",
        "nome_posto":            "nome_posto",
        "NOME_POSTO":            "nome_posto",
        "Nome Posto":            "nome_posto",
        # CNPJ frota
        "CNPJ da Frota":         "cnpj_frota_raw",
        "cnpj_frota":            "cnpj_frota_raw",
        "CNPJ_FROTA":            "cnpj_frota_raw",
        "CNPJ Frota":            "cnpj_frota_raw",
        "cnpj da frota":         "cnpj_frota_raw",
        # Razão social frota
        "nm_razao_social":       "razao_social_frota",
        "NM_RAZAO_SOCIAL":       "razao_social_frota",
        "razao_social_frota":    "razao_social_frota",
        "Razao Social":          "razao_social_frota",
        # dt_vigencia
        "dt_vigencia":           "dt_vigencia",
        "DT_VIGENCIA":           "dt_vigencia",
        "Data Vigencia":         "dt_vigencia",
        "Data Vigência":         "dt_vigencia",
        "Vigencia":              "dt_vigencia",
    }
    df = df_raw.rename(columns={k: v for k, v in _col_map.items() if k in df_raw.columns}).copy()

    # ── Fallback por substring se colunas obrigatórias ainda faltam ──
    def _find_col(df, keywords):
        """Retorna o primeiro nome de coluna que contenha qualquer keyword (case-insensitive)."""
        for _kw in keywords:
            for _c in df.columns:
                if _kw.lower() in str(_c).lower():
                    return _c
        return None

    if "cnpj_posto_raw" not in df.columns:
        _fc = _find_col(df, ["cnpj_posto", "cnpj posto", "cnpjposto"])
        if _fc:
            df.rename(columns={_fc: "cnpj_posto_raw"}, inplace=True)
    if "cnpj_frota_raw" not in df.columns:
        _fc = _find_col(df, ["cnpj_frota", "cnpj frota", "cnpjfrota"])
        if _fc:
            df.rename(columns={_fc: "cnpj_frota_raw"}, inplace=True)
    if "combustivel" not in df.columns:
        _fc = _find_col(df, ["combustivel", "combustível", "tipo_comb"])
        if _fc:
            df.rename(columns={_fc: "combustivel"}, inplace=True)
    if "preco_negociado" not in df.columns:
        _fc = _find_col(df, ["preco_negociado", "preco negociado", "preço negociado", "preco"])
        if _fc:
            df.rename(columns={_fc: "preco_negociado"}, inplace=True)
    if "dt_vigencia" not in df.columns:
        _fc = _find_col(df, ["dt_vigencia", "vigencia", "vigência", "data_vigencia"])
        if _fc:
            df.rename(columns={_fc: "dt_vigencia"}, inplace=True)

    # ── Normaliza CNPJs ───────────────────────────────────────────────
    df["cnpj_posto"] = (
        df["cnpj_posto_raw"].apply(_normalizar_cnpj_str)
        if "cnpj_posto_raw" in df.columns
        else pd.Series([""] * len(df))
    )
    df["cnpj_frota"] = (
        df["cnpj_frota_raw"].apply(_normalizar_cnpj_str)
        if "cnpj_frota_raw" in df.columns
        else pd.Series([""] * len(df))
    )

    # ── Demais colunas ────────────────────────────────────────────────
    if "combustivel" in df.columns:
        df["combustivel_pk"] = df["combustivel"].str.lower().map(_ACORDOS_PARA_PK).fillna(
            df["combustivel"].str.upper()
        )
    else:
        df["combustivel"] = ""
        df["combustivel_pk"] = ""

    df["dt_vigencia"] = pd.to_datetime(
        df["dt_vigencia"] if "dt_vigencia" in df.columns else pd.Series(dtype="object"),
        errors="coerce",
    )
    df["preco_negociado"] = pd.to_numeric(
        df["preco_negociado"] if "preco_negociado" in df.columns else pd.Series(dtype=float),
        errors="coerce",
    )
    # ── Normalização automática de unidade ─────────────────────────────────
    # Planilhas legadas podem trazer o preço em centésimos de centavo (×10000):
    #   38400 → 3.84 R$/L   |   66300 → 6.63 R$/L
    # Detecta: se mediana dos preços válidos > 50, divide tudo por 10.000.
    if "preco_negociado" in df.columns:
        _pn_validos = df["preco_negociado"].dropna()
        if not _pn_validos.empty and _pn_validos.median() > 50:
            df["preco_negociado"] = (df["preco_negociado"] / 10_000).round(4)
    df["va_desconto"] = pd.to_numeric(
        df["va_desconto"] if "va_desconto" in df.columns else pd.Series(dtype=float),
        errors="coerce",
    )
    return df


def _acordos_vigentes(df_acordos: "pd.DataFrame") -> "pd.DataFrame":
    """
    Retorna apenas o acordo mais recente por (cnpj_posto, cnpj_frota, combustivel).
    Usado para comparações de preço atual.
    """
    if df_acordos.empty:
        return df_acordos
    return (
        df_acordos.sort_values("dt_vigencia", ascending=False)
        .drop_duplicates(subset=["cnpj_posto", "cnpj_frota", "combustivel"])
        .reset_index(drop=True)
    )


def _db_salvar_acordos(df_raw: "pd.DataFrame", email: str, nome_arquivo: str) -> dict:
    """
    Salva acordos no Supabase com versionamento.
    Retorna {'ok': True/False, 'n_inseridos': int, 'n_duplicados': int}.
    """
    db = _db_client()
    if not db:
        return {"ok": False, "n_inseridos": 0, "n_duplicados": 0}
    try:
        df = _processar_acordos_df(df_raw)
        # Cria versão
        v_res = db.table("acordos_versoes").insert({
            "usuario_email": email,
            "nome_arquivo":  nome_arquivo,
            "n_registros":   len(df),
            "n_postos":      df["cnpj_posto"].nunique(),
            "n_frotas":      df["cnpj_frota"].nunique(),
        }).execute()
        versao_id = v_res.data[0]["id"] if v_res.data else None

        _eid_ac = _db_empresa_id()
        _rows = []
        for _, r in df.iterrows():
            if pd.isna(r.get("dt_vigencia")):
                continue
            _row_ac = {
                "cd_frota_ptov_preco": int(r["cd_frota_ptov_preco"]) if pd.notna(r.get("cd_frota_ptov_preco")) else None,
                "cnpj_posto":          r["cnpj_posto"],
                "nome_posto":          str(r.get("nome_posto", "") or ""),
                "cnpj_frota":          r["cnpj_frota"],
                "razao_social_frota":  str(r.get("razao_social_frota", "") or ""),
                "combustivel":         str(r.get("combustivel", "") or ""),
                "preco_negociado":     float(r["preco_negociado"]) if pd.notna(r.get("preco_negociado")) else None,
                "va_desconto":         float(r["va_desconto"]) if pd.notna(r.get("va_desconto")) else None,
                "dt_vigencia":         r["dt_vigencia"].isoformat(),
                "versao_id":           versao_id,
            }
            if _eid_ac:
                _row_ac["empresa_id"] = _eid_ac
            _rows.append(_row_ac)

        _n_ok = _n_dup = 0
        _BATCH = 500
        for _i in range(0, len(_rows), _BATCH):
            _chunk = _rows[_i:_i + _BATCH]
            try:
                db.table("acordos_precos").upsert(
                    _chunk,
                    on_conflict="cnpj_posto,cnpj_frota,combustivel,dt_vigencia"
                ).execute()
                _n_ok += len(_chunk)
            except Exception as _e:
                if "duplicate" in str(_e).lower() or "23505" in str(_e):
                    _n_dup += len(_chunk)
                else:
                    raise
        return {"ok": True, "n_inseridos": _n_ok, "n_duplicados": _n_dup}
    except Exception as _exc:
        return {"ok": False, "erro": str(_exc), "n_inseridos": 0, "n_duplicados": 0}


# ── Postos Favoritos ───────────────────────────────────────────────

def _db_favoritos() -> list:
    """Lista postos favoritos do usuário."""
    db = _db_client()
    if not db:
        return []
    try:
        res = db.table("postos_favoritos") \
                .select("*") \
                .eq("usuario_email", _db_email()) \
                .execute()
        return res.data or []
    except Exception:
        return []


def _db_add_favorito(cnpj: str, razao_social: str, municipio: str,
                     uf: str, lat: float = None, lon: float = None) -> bool:
    """Adiciona posto aos favoritos."""
    db = _db_client()
    if not db:
        return False
    try:
        db.table("postos_favoritos").upsert({
            "usuario_email": _db_email(),
            "cnpj":          cnpj,
            "razao_social":  razao_social,
            "municipio":     municipio,
            "uf":            uf,
            "lat":           lat,
            "lon":           lon,
        }).execute()
        return True
    except Exception:
        return False


def _db_remove_favorito(cnpj: str) -> bool:
    """Remove posto dos favoritos."""
    db = _db_client()
    if not db:
        return False
    try:
        db.table("postos_favoritos") \
          .delete() \
          .eq("usuario_email", _db_email()) \
          .eq("cnpj", cnpj) \
          .execute()
        return True
    except Exception:
        return False


# ── Perfis de Veículo (Roteirização) ──────────────────────────────

def _db_perfis_veiculo() -> list:
    """Lista perfis de veículo salvos pelo usuário."""
    db = _db_client()
    if not db:
        return []
    try:
        res = db.table("perfis_veiculo") \
                .select("*") \
                .eq("usuario_email", _db_email()) \
                .order("criado_em", desc=False) \
                .execute()
        return res.data or []
    except Exception:
        return []


def _db_salvar_perfil_veiculo(nome: str, placa: str, combustivel: str,
                               tanque: float, autonomia: float) -> bool:
    """Salva um novo perfil de veículo."""
    db = _db_client()
    if not db:
        return False
    try:
        db.table("perfis_veiculo").insert({
            "usuario_email": _db_email(),
            "nome":          nome.strip() or placa or "Veículo",
            "placa":         placa.strip().upper(),
            "combustivel":   combustivel,
            "tanque":        tanque,
            "autonomia":     autonomia,
            "criado_em":     _now_bsb().isoformat(),
        }).execute()
        return True
    except Exception:
        return False


def _db_deletar_perfil_veiculo(perfil_id) -> bool:
    """Remove um perfil de veículo."""
    db = _db_client()
    if not db:
        return False
    try:
        db.table("perfis_veiculo") \
          .delete() \
          .eq("id", perfil_id) \
          .eq("usuario_email", _db_email()) \
          .execute()
        return True
    except Exception:
        return False


# ── Histórico de Preços ────────────────────────────────────────────

def _db_gravar_preco(cnpj: str, razao_social: str, municipio: str, uf: str,
                     combustivel: str, preco: float, fonte: str = "PP",
                     lat: float = None, lon: float = None,
                     data_ref: str = None) -> bool:
    """Grava snapshot de preço no histórico. Ignora duplicatas (cnpj + combustivel + data_ref)."""
    db = _db_client()
    if not db or not cnpj or not preco:
        return False
    try:
        _payload = {
            "cnpj":         cnpj,
            "razao_social": razao_social or "",
            "municipio":    municipio or "",
            "uf":           uf or "",
            "combustivel":  combustivel,
            "preco":        round(float(preco), 3),
            "fonte":        fonte,
            "data_ref":     data_ref or _now_bsb().strftime("%Y-%m-%d"),
            "lat":          lat,
            "lon":          lon,
        }
        _eid = _db_empresa_id()
        if _eid:
            _payload["empresa_id"] = _eid
        db.table("historico_precos").upsert(
            _payloa