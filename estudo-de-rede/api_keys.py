# ═══════════════════════════════════════════════════════════════════════════
#  FNI Gestão de Frotas — API Keys por Tenant
#  Fase 7: autenticação via API Keys rotacionáveis com escopos
# ═══════════════════════════════════════════════════════════════════════════

from __future__ import annotations
import os
import secrets
import hashlib
import streamlit as st
from datetime import datetime, timezone

ESCOPOS_DISPONIVEIS = {
    "veiculos:read":       "Listar e consultar veículos",
    "veiculos:write":      "Cadastrar e atualizar veículos",
    "abastecimentos:read": "Consultar abastecimentos",
    "abastecimentos:write":"Registrar abastecimentos",
    "anp:read":            "Consultar preços ANP",
    "relatorios:read":     "Gerar e baixar relatórios",
    "webhooks:manage":     "Gerenciar webhooks",
}

LIMITE_KEYS = {
    "gratuito":      0,
    "basico":        0,
    "profissional":  3,
    "enterprise":    999,
}

def _db():
    try:
        from supabase import create_client
        url = os.environ.get("SUPABASE_URL","")
        key = os.environ.get("SUPABASE_KEY","")
        if url and key:
            return create_client(url, key)
    except Exception:
        pass
    return None

def _empresa_id():
    try:
        return (st.session_state.get("_empresa_ativa") or {}).get("id")
    except Exception:
        return None

def _plano_atual():
    try:
        return (st.session_state.get("_empresa_ativa") or {}).get("plano","gratuito")
    except Exception:
        return "gratuito"

def _gerar_api_key() -> tuple[str, str]:
    """Gera API key e retorna (chave_publica, hash_para_banco)."""
    chave = f"fni_{secrets.token_urlsafe(32)}"
    hash_chave = hashlib.sha256(chave.encode()).hexdigest()
    return chave, hash_chave

def _criar_key(nome: str, escopos: list[str]) -> str | None:
    """Cria nova API key. Retorna a chave em texto puro (mostrar UMA VEZ)."""
    db = _db()
    eid = _empresa_id()
    if not db or not eid:
        return None
    try:
        chave, hash_chave = _gerar_api_key()
        db.table("api_keys").insert({
            "empresa_id": eid,
            "nome":       nome.strip(),
            "hash_chave": hash_chave,
            "escopos":    escopos,
            "ativa":      True,
            "criada_em":  datetime.now(tz=timezone.utc).isoformat(),
        }).execute()
        return chave
    except Exception as e:
        st.error(f"Erro ao criar API key: {e}")
        return None

def _listar_keys() -> list:
    """Lista API keys da empresa (sem o hash)."""
    db = _db()
    eid = _empresa_id()
    if not db or not eid:
        return []
    try:
        res = db.table("api_keys")\
            .select("id,nome,escopos,ativa,criada_em,ultimo_uso")\
            .eq("empresa_id", eid)\
            .order("criada_em", desc=True)\
            .execute()
        return res.data or []
    except Exception:
        return []

def _revogar_key(key_id: str) -> bool:
    """Revoga uma API key."""
    db = _db()
    if not db:
        return False
    try:
        db.table("api_keys").update({
            "ativa": False,
            "revogada_em": datetime.now(tz=timezone.utc).isoformat()
        }).eq("id", key_id).execute()
        return True
    except Exception:
        return False

def _rotacionar_key(key_id: str) -> str | None:
    """Rotaciona uma API key — gera nova e invalida a anterior."""
    db = _db()
    if not db:
        return None
    try:
        # Buscar dados da key atual
        res = db.table("api_keys").select("*").eq("id", key_id).single().execute()
        key_atual = res.data
        if not key_atual:
            return None
        # Revogar antiga
        _revogar_key(key_id)
        # Criar nova com mesmo nome e escopos
        nova_chave, hash_chave = _gerar_api_key()
        db.table("api_keys").insert({
            "empresa_id": key_atual["empresa_id"],
            "nome":       key_atual["nome"] + " (rotacionada)",
            "hash_chave": hash_chave,
            "escopos":    key_atual["escopos"],
            "ativa":      True,
            "criada_em":  datetime.now(tz=timezone.utc).isoformat(),
        }).execute()
        return nova_chave
    except Exception as e:
        st.error(f"Erro ao rotacionar: {e}")
        return None

def mostrar_painel_api_keys():
    """Painel de gerenciamento de API Keys."""
    st.markdown("### 🔑 API Keys")
    st.caption("Chaves de acesso para integrar sistemas externos com a plataforma")

    plano = _plano_atual()
    limite = LIMITE_KEYS.get(plano, 0)

    if limite == 0:
        st.warning(
            "🔒 API Keys disponíveis apenas nos planos **Profissional** e **Enterprise**.\n\n"
            "Faça upgrade para integrar com ERPs, telemetria e outros sistemas."
        )
        if st.button("🚀 Ver planos", key="btn_upgrade_apikeys"):
            st.session_state["_mostrar_planos"] = True
            st.rerun()
        return

    keys = _listar_keys()
    keys_ativas = [k for k in keys if k.get("ativa")]

    # Métricas
    col1, col2, col3 = st.columns(3)
    with col1:
        st.metric("Keys ativas", f"{len(keys_ativas)}/{limite}")
    with col2:
        st.metric("Plano", plano.capitalize())
    with col3:
        st.metric("Total criadas", len(keys))

    st.markdown("---")

    # Criar nova key
    if len(keys_ativas) < limite:
        with st.expander("➕ Criar nova API Key", expanded=len(keys_ativas) == 0):
            with st.form("form_nova_key"):
                nome_key = st.text_input(
                    "Nome da integração *",
                    placeholder="Ex: ERP TOTVS, Power BI, App Mobile",
                    max_chars=60
                )
                escopos_sel = st.multiselect(
                    "Escopos de permissão *",
                    options=list(ESCOPOS_DISPONIVEIS.keys()),
                    format_func=lambda x: f"{x} — {ESCOPOS_DISPONIVEIS[x]}",
                    default=["veiculos:read","abastecimentos:read","anp:read"]
                )
                criar = st.form_submit_button("🔑 Gerar API Key", type="primary", use_container_width=True)

            if criar:
                if not nome_key.strip():
                    st.error("Informe um nome para a integração.")
                elif not escopos_sel:
                    st.error("Selecione pelo menos um escopo.")
                else:
                    with st.spinner("Gerando API Key..."):
                        nova_key = _criar_key(nome_key, escopos_sel)
                    if nova_key:
                        st.success("✅ API Key criada com sucesso!")
                        st.warning("⚠️ **Copie agora!** Esta chave não será exibida novamente.")
                        st.code(nova_key, language=None)
                        st.info(
                            "Use no header das requisições:\n"
                            f"`Authorization: Bearer {nova_key[:20]}...`"
                        )
                        st.rerun()
    else:
        st.info(f"Limite de {limite} keys ativas atingido. Revogue uma key para criar outra.")

    # Listar keys existentes
    if keys:
        st.markdown("### Keys existentes")
        for k in keys:
            status = "🟢 Ativa" if k.get("ativa") else "🔴 Revogada"
            data = k["criada_em"][:10] if k.get("criada_em") else ""
            with st.expander(f"**{k['nome']}** — {status} · {data}"):
                st.caption(f"ID: `{k['id']}`")
                escopos = k.get("escopos") or []
                if escopos:
                    st.markdown("**Escopos:**")
                    for e in escopos:
                        st.caption(f"✓ {e} — {ESCOPOS_DISPONIVEIS.get(e,'')}")
                if k.get("ultimo_uso"):
                    st.caption(f"Último uso: {k['ultimo_uso'][:16]}")

                if k.get("ativa"):
                    col1, col2 = st.columns(2)
                    with col1:
                        if st.button("🔄 Rotacionar", key=f"rot_{k['id']}", use_container_width=True):
                            nova = _rotacionar_key(k["id"])
                            if nova:
                                st.success("✅ Key rotacionada!")
                                st.warning("⚠️ Copie a nova key agora:")
                                st.code(nova, language=None)
                    with col2:
                        if st.button("🗑️ Revogar", key=f"rev_{k['id']}", use_container_width=True, type="secondary"):
                            if _revogar_key(k["id"]):
                                st.success("Key revogada.")
                                st.rerun()
