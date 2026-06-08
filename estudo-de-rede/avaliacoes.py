from __future__ import annotations
import os
import streamlit as st
from datetime import datetime, timezone

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

def _email():
    try:
        return (st.session_state.get("_auth_user") or {}).get("email","")
    except Exception:
        return ""

def _ja_avaliou_hoje(email: str) -> bool:
    db = _db()
    if not db:
        return False
    try:
        hoje = datetime.now(tz=timezone.utc).date().isoformat()
        res = db.table("avaliacoes").select("id")\
            .eq("user_email", email)\
            .gte("criado_em", f"{hoje}T00:00:00Z")\
            .limit(1).execute()
        return len(res.data or []) > 0
    except Exception:
        return False

def _salvar_avaliacao(estrelas: int, comentario: str) -> bool:
    db = _db()
    if not db:
        return False
    try:
        db.table("avaliacoes").insert({
            "empresa_id": _empresa_id(),
            "user_email": _email(),
            "estrelas":   estrelas,
            "comentario": comentario.strip() if comentario else None,
        }).execute()
        return True
    except Exception as e:
        st.error(f"Erro ao salvar avaliação: {e}")
        return False

def _media_avaliacoes() -> tuple[float, int]:
    db = _db()
    if not db:
        return 0.0, 0
    try:
        res = db.table("avaliacoes").select("estrelas").execute()
        dados = res.data or []
        if not dados:
            return 0.0, 0
        media = sum(d["estrelas"] for d in dados) / len(dados)
        return round(media, 1), len(dados)
    except Exception:
        return 0.0, 0

def mostrar_avaliacao():
    """Widget de avaliação com estrelas — exibido na sidebar ou em tela cheia."""
    email = _email()

    st.markdown("## ⭐ Avalie o FNI Gestão de Frotas")
    st.caption("Sua opinião nos ajuda a melhorar a plataforma")

    # Média geral
    media, total = _media_avaliacoes()
    if total > 0:
        estrelas_media = "⭐" * round(media)
        st.info(f"{estrelas_media} **{media}/5** — baseado em {total} avaliação(ões)")

    st.markdown("---")

    if _ja_avaliou_hoje(email):
        st.success("✅ Você já avaliou hoje. Obrigado pelo feedback!")
        if st.button("← Voltar", key="btn_voltar_aval_done"):
            st.session_state.pop("_mostrar_avaliacao", None)
            st.rerun()
        return

    # Seleção de estrelas
    st.markdown("**Como você avalia a plataforma?**")
    estrelas = st.feedback("stars", key="feedback_estrelas")

    comentario = st.text_area(
        "Comentário (opcional)",
        placeholder="Conte o que você achou, o que pode melhorar...",
        max_chars=500,
        height=120,
    )

    col1, col2 = st.columns(2)
    with col1:
        if st.button("← Voltar", key="btn_voltar_aval", use_container_width=True):
            st.session_state.pop("_mostrar_avaliacao", None)
            st.rerun()
    with col2:
        if st.button("📨 Enviar avaliação", type="primary", use_container_width=True, key="btn_enviar_aval"):
            if estrelas is None:
                st.error("Selecione uma nota de 1 a 5 estrelas.")
            else:
                # st.feedback retorna 0-4, converter para 1-5
                nota = estrelas + 1
                if _salvar_avaliacao(nota, comentario):
                    st.balloons()
                    st.success(f"{'⭐' * nota} Obrigado pela avaliação!")
                    # Notificar admin
                    try:
                        from emails import _enviar, _base
                        _enviar(
                            "contato@fxgestaodefrotasonline.com",
                            f"⭐ Nova avaliação: {nota}/5 — {email}",
                            _base(f"""
                            <h3>Nova avaliação recebida</h3>
                            <p><b>Usuário:</b> {email}</p>
                            <p><b>Nota:</b> {"⭐" * nota} ({nota}/5)</p>
                            <p><b>Comentário:</b> {comentario or "Sem comentário"}</p>
                            """, "Nova avaliação")
                        )
                    except Exception:
                        pass
                    st.session_state["_avaliou"] = True
                    st.rerun()

def mostrar_painel_admin_avaliacoes():
    """Painel admin para ver todas as avaliações."""
    st.markdown("## ⭐ Avaliações dos Usuários")

    db = _db()
    if not db:
        st.error("Banco não disponível.")
        return

    try:
        res = db.table("avaliacoes").select("*").order("criado_em", desc=True).execute()
        dados = res.data or []
    except Exception:
        dados = []

    if not dados:
        st.info("Nenhuma avaliação registrada ainda.")
        return

    # Métricas
    media = sum(d["estrelas"] for d in dados) / len(dados)
    col1, col2, col3 = st.columns(3)
    with col1:
        st.metric("Média geral", f"{round(media,1)}/5 ⭐")
    with col2:
        st.metric("Total de avaliações", len(dados))
    with col3:
        cinco = sum(1 for d in dados if d["estrelas"] == 5)
        st.metric("Avaliações 5 estrelas", f"{cinco} ({round(cinco/len(dados)*100)}%)")

    # Distribuição
    st.markdown("### Distribuição")
    for n in range(5, 0, -1):
        count = sum(1 for d in dados if d["estrelas"] == n)
        pct = count / len(dados) if dados else 0
        st.markdown(f"{'⭐'*n} **{count}** ({round(pct*100)}%)")

    st.markdown("### Histórico")
    for d in dados:
        estrelas_str = "⭐" * d["estrelas"]
        data = d["criado_em"][:10] if d.get("criado_em") else ""
        with st.expander(f"{estrelas_str} {d['user_email']} · {data}"):
            st.caption(f"Empresa ID: {d.get('empresa_id','—')}")
            if d.get("comentario"):
                st.write(d["comentario"])
            else:
                st.caption("Sem comentário")
