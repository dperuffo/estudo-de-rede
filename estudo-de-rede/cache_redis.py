# ═══════════════════════════════════════════════════════════════════════════
#  FNI Gestão de Frotas — Cache Redis (Upstash)
#  Fase 5: cache de ANP, sessões, rate limiting e relatórios
# ═══════════════════════════════════════════════════════════════════════════

from __future__ import annotations
import os
import json
import hashlib
from typing import Any

REDIS_URL   = os.environ.get("UPSTASH_REDIS_REST_URL", "").strip()
REDIS_TOKEN = os.environ.get("UPSTASH_REDIS_REST_TOKEN", "").strip()

# TTLs em segundos
TTL_ANP        = 3600      # 1 hora  — preços ANP
TTL_SESSAO     = 28800     # 8 horas — sessões de usuário
TTL_RELATORIO  = 900       # 15 min  — relatórios pesados
TTL_RATE_LIMIT = 60        # 1 min   — rate limiting


def _client():
    """Retorna cliente Upstash Redis ou None se não configurado."""
    if not REDIS_URL or not REDIS_TOKEN:
        return None
    try:
        from upstash_redis import Redis
        return Redis(url=REDIS_URL, token=REDIS_TOKEN)
    except Exception:
        return None


def _chave(prefixo: str, *partes) -> str:
    """Gera chave Redis padronizada."""
    sufixo = ":".join(str(p) for p in partes if p)
    return f"fni:{prefixo}:{sufixo}" if sufixo else f"fni:{prefixo}"


def _hash(dados: Any) -> str:
    """Hash MD5 de dados para usar como chave de cache."""
    return hashlib.md5(json.dumps(dados, sort_keys=True, default=str).encode()).hexdigest()[:12]


# ─────────────────────────────────────────────────────────────────────────────
# OPERAÇÕES BASE
# ─────────────────────────────────────────────────────────────────────────────

def get(chave: str) -> Any | None:
    """Busca valor no cache. Retorna None se não existir ou erro."""
    r = _client()
    if not r:
        return None
    try:
        val = r.get(chave)
        if val is None:
            return None
        return json.loads(val) if isinstance(val, str) else val
    except Exception:
        return None


def set(chave: str, valor: Any, ttl: int = TTL_ANP) -> bool:
    """Salva valor no cache com TTL em segundos."""
    r = _client()
    if not r:
        return False
    try:
        r.setex(chave, ttl, json.dumps(valor, default=str))
        return True
    except Exception:
        return False


def delete(chave: str) -> bool:
    """Remove chave do cache."""
    r = _client()
    if not r:
        return False
    try:
        r.delete(chave)
        return True
    except Exception:
        return False


def flush_prefixo(prefixo: str) -> int:
    """Remove todas as chaves com determinado prefixo."""
    r = _client()
    if not r:
        return 0
    try:
        chaves = r.keys(f"fni:{prefixo}:*")
        if chaves:
            r.delete(*chaves)
        return len(chaves or [])
    except Exception:
        return 0


# ─────────────────────────────────────────────────────────────────────────────
# CACHE ANP
# ─────────────────────────────────────────────────────────────────────────────

def cache_anp_get(uf: str | None = None) -> dict | None:
    """Busca preços ANP do cache."""
    chave = _chave("anp", uf or "brasil")
    return get(chave)


def cache_anp_set(dados: dict, uf: str | None = None) -> bool:
    """Salva preços ANP no cache por 1 hora."""
    chave = _chave("anp", uf or "brasil")
    return set(chave, dados, TTL_ANP)


def cache_anp_invalida() -> int:
    """Invalida todo o cache ANP."""
    return flush_prefixo("anp")


# ─────────────────────────────────────────────────────────────────────────────
# CACHE DE SESSÃO
# ─────────────────────────────────────────────────────────────────────────────

def cache_sessao_get(email: str) -> dict | None:
    """Busca dados de sessão do usuário."""
    return get(_chave("sessao", email))


def cache_sessao_set(email: str, dados: dict) -> bool:
    """Salva sessão por 8 horas."""
    return set(_chave("sessao", email), dados, TTL_SESSAO)


def cache_sessao_invalida(email: str) -> bool:
    """Invalida sessão do usuário (logout)."""
    return delete(_chave("sessao", email))


# ─────────────────────────────────────────────────────────────────────────────
# CACHE DE RELATÓRIOS
# ─────────────────────────────────────────────────────────────────────────────

def cache_relatorio_get(empresa_id: str, tipo: str, params: dict = {}) -> Any | None:
    """Busca resultado de relatório cacheado."""
    h = _hash(params)
    return get(_chave("rel", empresa_id, tipo, h))


def cache_relatorio_set(empresa_id: str, tipo: str, dados: Any, params: dict = {}) -> bool:
    """Salva resultado de relatório por 15 minutos."""
    h = _hash(params)
    return set(_chave("rel", empresa_id, tipo, h), dados, TTL_RELATORIO)


def cache_relatorio_invalida(empresa_id: str) -> int:
    """Invalida todos os relatórios de uma empresa."""
    return flush_prefixo(f"rel:{empresa_id}")


# ─────────────────────────────────────────────────────────────────────────────
# RATE LIMITING
# ─────────────────────────────────────────────────────────────────────────────

def rate_limit_check(identificador: str, limite: int = 60, janela: int = 60) -> tuple[bool, int]:
    """
    Verifica rate limit por identificador (IP ou email).
    Retorna (permitido, requisicoes_restantes).
    """
    r = _client()
    if not r:
        return True, limite  # sem Redis = sem rate limit
    chave = _chave("rl", identificador)
    try:
        atual = r.incr(chave)
        if atual == 1:
            r.expire(chave, janela)
        restantes = max(0, limite - atual)
        return atual <= limite, restantes
    except Exception:
        return True, limite


# ─────────────────────────────────────────────────────────────────────────────
# DIAGNÓSTICO
# ─────────────────────────────────────────────────────────────────────────────

def ping() -> bool:
    """Testa conexão com Redis."""
    r = _client()
    if not r:
        return False
    try:
        return r.ping()
    except Exception:
        return False


def info_cache() -> dict:
    """Retorna informações sobre o cache."""
    r = _client()
    if not r:
        return {"status": "desconectado", "configurado": bool(REDIS_URL)}
    try:
        ok = r.ping()
        chaves = r.dbsize()
        return {
            "status":      "conectado" if ok else "erro",
            "configurado": True,
            "total_chaves": chaves,
            "url":         REDIS_URL[:40] + "..." if REDIS_URL else "",
        }
    except Exception as e:
        return {"status": "erro", "erro": str(e)}
