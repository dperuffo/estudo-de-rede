from __future__ import annotations
import os
import json
import streamlit as st
from datetime import datetime, timezone

def _db():
    try:
        from supabase import create_client
        url = os.environ.get("SUPABASE_URL", "")
        key = os.environ.get("SUPABASE_KEY", "")
        if url and key:
            return create_client(url, key)
    except Exception:
        pass
    return None

def _empresa_id() -> str | None:
    try:
        return (st.session_state.get("_empresa_ativa") or {}).get("id")
    except Exception:
        return None

def _email() -> str:
    try:
        return (st.session_state.get("_auth_user") or {}).get("email", "")
    except Exception:
        return ""

def exportar_dados_empresa() -> dict | None:
    db = _db()
    eid = _empresa_id()
    if not db or not eid:
        return None
    dados = {"empresa_id": eid, "exportado_em": datetime.now(tz=timezone.utc).isoformat(), "tabelas": {}}
    tabelas = [
        "empresas", "usuarios_empresas", "frota_abastecimentos",
        "frota_veiculos_fipe", "postos_gf", "acordos_precos",
        "lgpd_consents", "invoices"
    ]
    for tabela in tabelas:
        try:
            res = db.table(tabela).select("*").eq("empresa_id", eid).execute()
            dados["tabelas"][tabela] = res.data or []
        except Exception:
            dados["tabelas"][tabela] = []
    return dados

def solicitar_exclusao() -> bool:
    db = _db()
    eid = _empresa_id()
    email = _email()
    if not db or not eid:
        return False
    try:
        # Verificar se já existe solicitação pendente
        res = db.table("lgpd_exclusoes").select("id").eq("empresa_id", eid).eq("status", "pendente").execute()
        if res.data:
            return True  # já solicitado
        db.table("lgpd_exclusoes").insert({
            "empresa_id": eid,
            "email": email,
            "status": "pendente",
        }).execute()
        # Suspender empresa imediatamente
        db.table("empresas").update({"status": "cancelado"}).eq("id", eid).execute()
        # Notificar admin
        try:
            from emails import _enviar, _base
            _enviar(
                "contato@fxgestaodefrotasonline.com",
                f"[LGPD] Solicitacao de exclusao — {email}",
                _base(f"<p>Empresa ID: {eid}<br>Email: {email}<br>Data: {datetime.now().strftime('%d/%m/%Y %H:%M')}</p>", "LGPD Exclusao")
            )
        except Exception:
            pass
        return True
    except Exception as e:
        st.error(f"Erro ao solicitar exclusão: {e}")
        return False

def mostrar_painel_lgpd():
    st.markdown("## 🔒 Privacidade e LGPD")
    st.caption("Gerencie seus dados pessoais conforme a Lei Geral de Proteção de Dados")

    # Exportação
    st.markdown("### 📥 Exportar meus dados")
    st.write("Baixe uma cópia completa de todos os seus dados armazenados na plataforma.")
    if st.button("📥 Exportar dados", use_container_width=True):
        with st.spinner("Preparando exportação..."):
            dados = exportar_dados_empresa()
        if dados:
            json_str = json.dumps(dados, ensure_ascii=False, indent=2, default=str)
            st.download_button(
                label="⬇️ Baixar arquivo JSON",
                data=json_str,
                file_name=f"meus_dados_fni_{datetime.now().strftime('%Y%m%d')}.json",
                mime="application/json",
                use_container_width=True
            )
        else:
            st.error("Não foi possível exportar os dados. Tente novamente.")

    st.markdown("---")

    # Exclusão
    st.markdown("### 🗑️ Solicitar exclusão de dados")
    st.warning(
        "⚠️ A exclusão é **irreversível**. Todos os dados da sua empresa serão "
        "removidos permanentemente em até **30 dias**. Sua conta será suspensa imediatamente.",
        icon="⚠️"
    )

    if "lgpd_confirmar_exclusao" not in st.session_state:
        st.session_state["lgpd_confirmar_exclusao"] = False

    if not st.session_state["lgpd_confirmar_exclusao"]:
        if st.button("🗑️ Solicitar exclusão de todos os meus dados", type="secondary", use_container_width=True):
            st.session_state["lgpd_confirmar_exclusao"] = True
            st.rerun()
    else:
        st.error("Tem certeza? Esta ação não pode ser desfeita!")
        col1, col2 = st.columns(2)
        with col1:
            if st.button("Cancelar", use_container_width=True):
                st.session_state["lgpd_confirmar_exclusao"] = False
                st.rerun()
        with col2:
            if st.button("Confirmar exclusão", type="primary", use_container_width=True):
                with st.spinner("Processando solicitação..."):
                    ok = solicitar_exclusao()
                if ok:
                    st.success("Solicitação registrada. Seus dados serão removidos em até 30 dias.")
                    st.session_state["lgpd_confirmar_exclusao"] = False
                else:
                    st.error("Erro ao processar solicitação. Contate contato@fxgestaodefrotasonline.com")

    st.markdown("---")
    st.caption("Para dúvidas sobre privacidade: contato@fxgestaodefrotasonline.com | Base legal: LGPD — Lei 13.709/2018")
