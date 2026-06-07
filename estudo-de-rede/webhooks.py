# ═══════════════════════════════════════════════════════════════════════════
#  FNI Gestão de Frotas — Webhooks para Clientes
#  Fase 7: delivery com retry, logs e dashboard
# ═══════════════════════════════════════════════════════════════════════════

from __future__ import annotations
import os
import json
import time
import hashlib
import hmac
import threading
import requests
import streamlit as st
from datetime import datetime, timezone

EVENTOS_DISPONIVEIS = {
    "abastecimento.criado":    "Novo abastecimento registrado",
    "alerta.consumo_anomalo":  "Consumo anormal detectado",
    "relatorio.gerado":        "Relatório gerado",
    "veiculo.cadastrado":      "Novo veículo cadastrado",
    "trial.expirando":         "Trial expirando em 2 dias",
    "pagamento.confirmado":    "Pagamento confirmado",
    "pagamento.falhou":        "Falha no pagamento",
}

MAX_TENTATIVAS   = 3
BACKOFF_SEGUNDOS = [10, 30, 60]  # espera entre tentativas

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

def _gerar_secret() -> str:
    """Gera secret para assinatura HMAC dos webhooks."""
    import secrets
    return f"whsec_{secrets.token_urlsafe(32)}"

def _assinar_payload(payload: dict, secret: str) -> str:
    """Assina o payload com HMAC-SHA256."""
    body = json.dumps(payload, sort_keys=True, default=str).encode()
    return hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()

def _registrar_webhook(url: str, eventos: list, descricao: str = "") -> dict | None:
    """Registra novo webhook endpoint."""
    db = _db()
    eid = _empresa_id()
    if not db or not eid:
        return None
    try:
        secret = _gerar_secret()
        res = db.table("webhook_registrations").insert({
            "empresa_id":  eid,
            "url":         url.strip(),
            "eventos":     eventos,
            "descricao":   descricao.strip(),
            "usuario":     _email(),
            "secret":      secret,
            "ativo":       True,
            "criado_em":   datetime.now(tz=timezone.utc).isoformat(),
        }).execute()
        return res.data[0] if res.data else None
    except Exception as e:
        st.error(f"Erro ao registrar webhook: {e}")
        return None

def _listar_webhooks() -> list:
    """Lista webhooks da empresa."""
    db = _db()
    eid = _empresa_id()
    if not db or not eid:
        return []
    try:
        res = db.table("webhook_registrations")\
            .select("*")\
            .eq("empresa_id", eid)\
            .order("criado_em", desc=True)\
            .execute()
        return res.data or []
    except Exception:
        return []

def _listar_logs(webhook_id: str = None, limit: int = 50) -> list:
    """Lista logs de delivery de webhooks."""
    db = _db()
    eid = _empresa_id()
    if not db or not eid:
        return []
    try:
        q = db.table("webhook_logs")\
            .select("*")\
            .eq("empresa_id", eid)\
            .order("criado_em", desc=True)\
            .limit(limit)
        if webhook_id:
            q = q.eq("webhook_id", webhook_id)
        return q.execute().data or []
    except Exception:
        return []

def _deletar_webhook(webhook_id: str) -> bool:
    db = _db()
    if not db:
        return False
    try:
        db.table("webhook_registrations").update({"ativo": False}).eq("id", webhook_id).execute()
        return True
    except Exception:
        return False

def _salvar_log(webhook_id: str, empresa_id: str, evento: str,
                status: str, http_status: int, resposta: str,
                tentativa: int, payload: dict) -> None:
    """Salva log de tentativa de delivery."""
    db = _db()
    if not db:
        return
    try:
        db.table("webhook_logs").insert({
            "webhook_id":  webhook_id,
            "empresa_id":  empresa_id,
            "evento":      evento,
            "status":      status,
            "http_status": http_status,
            "resposta":    resposta[:500] if resposta else "",
            "tentativa":   tentativa,
            "payload":     json.dumps(payload, default=str)[:2000],
            "criado_em":   datetime.now(tz=timezone.utc).isoformat(),
        }).execute()
    except Exception:
        pass

def disparar_webhook(empresa_id: str, evento: str, payload: dict) -> None:
    """
    Dispara webhooks registrados para um evento.
    Roda em thread separada para não bloquear o app.
    """
    def _enviar():
        db = _db()
        if not db:
            return
        try:
            res = db.table("webhook_registrations")\
                .select("*")\
                .eq("empresa_id", empresa_id)\
                .eq("ativo", True)\
                .execute()
            webhooks = res.data or []
        except Exception:
            return

        for wh in webhooks:
            eventos_wh = wh.get("eventos") or []
            if evento not in eventos_wh and "*" not in eventos_wh:
                continue

            full_payload = {
                "evento":     evento,
                "empresa_id": empresa_id,
                "timestamp":  datetime.now(tz=timezone.utc).isoformat(),
                "dados":      payload,
            }
            secret = wh.get("secret","")
            assinatura = _assinar_payload(full_payload, secret) if secret else ""
            headers = {
                "Content-Type":        "application/json",
                "X-FNI-Event":         evento,
                "X-FNI-Signature":     f"sha256={assinatura}",
                "X-FNI-Delivery":      datetime.now(tz=timezone.utc).isoformat(),
            }

            sucesso = False
            for tentativa in range(1, MAX_TENTATIVAS + 1):
                try:
                    resp = requests.post(
                        wh["url"],
                        json=full_payload,
                        headers=headers,
                        timeout=10
                    )
                    status = "sucesso" if resp.ok else "erro_http"
                    _salvar_log(
                        wh["id"], empresa_id, evento,
                        status, resp.status_code,
                        resp.text[:500], tentativa, full_payload
                    )
                    if resp.ok:
                        sucesso = True
                        break
                except Exception as ex:
                    _salvar_log(
                        wh["id"], empresa_id, evento,
                        "erro_conexao", 0,
                        str(ex)[:500], tentativa, full_payload
                    )

                if not sucesso and tentativa < MAX_TENTATIVAS:
                    time.sleep(BACKOFF_SEGUNDOS[tentativa - 1])

    threading.Thread(target=_enviar, daemon=True).start()

def _testar_webhook(webhook_id: str, url: str, secret: str) -> tuple[bool, str]:
    """Envia payload de teste para o endpoint."""
    payload = {
        "evento":    "webhook.teste",
        "empresa_id": _empresa_id(),
        "timestamp": datetime.now(tz=timezone.utc).isoformat(),
        "dados":     {"mensagem": "Teste de webhook FNI Gestão de Frotas"},
    }
    assinatura = _assinar_payload(payload, secret) if secret else ""
    try:
        resp = requests.post(url, json=payload, headers={
            "Content-Type":    "application/json",
            "X-FNI-Event":     "webhook.teste",
            "X-FNI-Signature": f"sha256={assinatura}",
        }, timeout=10)
        return resp.ok, f"HTTP {resp.status_code}: {resp.text[:200]}"
    except Exception as e:
        return False, str(e)

def mostrar_painel_webhooks():
    """Painel de gerenciamento de webhooks."""
    st.markdown("### 🔌 Webhooks")
    st.caption("Receba notificações em tempo real quando eventos ocorrerem na plataforma")

    aba1, aba2 = st.tabs(["📋 Meus Webhooks", "📊 Logs de Delivery"])

    with aba1:
        # Registrar novo webhook
        with st.expander("➕ Registrar novo webhook", expanded=True):
            with st.form("form_webhook"):
                url_wh = st.text_input(
                    "URL do endpoint *",
                    placeholder="https://meu-erp.empresa.com/webhooks/fni",
                    help="Endpoint que receberá os eventos via POST"
                )
                eventos_sel = st.multiselect(
                    "Eventos para assinar *",
                    options=list(EVENTOS_DISPONIVEIS.keys()),
                    format_func=lambda x: f"{x} — {EVENTOS_DISPONIVEIS[x]}",
                    default=["abastecimento.criado"]
                )
                descricao_wh = st.text_input(
                    "Descrição",
                    placeholder="Ex: Integração ERP TOTVS Protheus"
                )
                registrar = st.form_submit_button("🔌 Registrar webhook", type="primary", use_container_width=True)

            if registrar:
                if not url_wh.strip():
                    st.error("Informe a URL do endpoint.")
                elif not url_wh.startswith("https://"):
                    st.error("A URL deve usar HTTPS.")
                elif not eventos_sel:
                    st.error("Selecione pelo menos um evento.")
                else:
                    with st.spinner("Registrando..."):
                        wh = _registrar_webhook(url_wh, eventos_sel, descricao_wh)
                    if wh:
                        st.success("✅ Webhook registrado!")
                        st.info(f"🔐 **Secret para validação HMAC:**")
                        st.code(wh.get("secret",""), language=None)
                        st.warning("⚠️ Guarde o secret — não será exibido novamente!")
                        st.rerun()

        # Listar webhooks
        webhooks = _listar_webhooks()
        if not webhooks:
            st.info("Nenhum webhook registrado ainda.")
        else:
            st.markdown(f"**{len(webhooks)} webhook(s) registrado(s)**")
            for wh in webhooks:
                status = "🟢 Ativo" if wh.get("ativo") else "🔴 Inativo"
                with st.expander(f"**{wh.get('descricao') or wh['url'][:50]}** — {status}"):
                    st.caption(f"URL: `{wh['url']}`")
                    st.caption(f"ID: `{wh['id'][:8]}...`")
                    eventos = wh.get("eventos") or []
                    st.markdown("**Eventos:**")
                    for ev in eventos:
                        st.caption(f"• {ev} — {EVENTOS_DISPONIVEIS.get(ev,'')}")

                    col1, col2, col3 = st.columns(3)
                    with col1:
                        if st.button("🧪 Testar", key=f"test_{wh['id']}", use_container_width=True):
                            ok, msg = _testar_webhook(wh["id"], wh["url"], wh.get("secret",""))
                            if ok:
                                st.success(f"✅ {msg}")
                            else:
                                st.error(f"❌ {msg}")
                    with col2:
                        st.caption(f"Criado: {wh['criado_em'][:10] if wh.get('criado_em') else '—'}")
                    with col3:
                        if wh.get("ativo"):
                            if st.button("🗑️ Remover", key=f"del_{wh['id']}", use_container_width=True):
                                if _deletar_webhook(wh["id"]):
                                    st.success("Webhook removido.")
                                    st.rerun()

    with aba2:
        st.markdown("### 📊 Logs de Delivery")
        webhooks = _listar_webhooks()
        opcoes = {"Todos": None}
        for wh in webhooks:
            opcoes[wh.get("descricao") or wh["url"][:40]] = wh["id"]

        col1, col2 = st.columns(2)
        with col1:
            filtro_wh = st.selectbox("Webhook", list(opcoes.keys()), key="sel_wh_log")
        with col2:
            limite = st.selectbox("Últimos", [20, 50, 100], key="sel_limit_log")

        logs = _listar_logs(opcoes[filtro_wh], limite)

        if not logs:
            st.info("Nenhum log de delivery encontrado.")
        else:
            # Métricas
            total = len(logs)
            sucesso = sum(1 for l in logs if l.get("status") == "sucesso")
            col1, col2, col3 = st.columns(3)
            col1.metric("Total", total)
            col2.metric("Sucesso", sucesso)
            col3.metric("Taxa", f"{round(sucesso/total*100)}%" if total else "0%")

            st.markdown("---")
            for log in logs:
                status_icon = "✅" if log.get("status") == "sucesso" else "❌"
                data = log["criado_em"][:16] if log.get("criado_em") else ""
                with st.expander(f"{status_icon} {log.get('evento','—')} · {data} · Tentativa {log.get('tentativa',1)}"):
                    col1, col2 = st.columns(2)
                    with col1:
                        st.caption(f"Status: **{log.get('status','—')}**")
                        st.caption(f"HTTP: **{log.get('http_status',0)}**")
                    with col2:
                        st.caption(f"Tentativa: {log.get('tentativa',1)}/{MAX_TENTATIVAS}")
                    if log.get("resposta"):
                        st.markdown("**Resposta do endpoint:**")
                        st.code(log["resposta"], language=None)
