"""
stripe_billing.py — Módulo de Billing Stripe
=============================================
Integração completa Stripe Subscriptions para FX Gestão de Frotas.

Uso no estudo_de_rede.py:
    from stripe_billing import (
        criar_checkout_session,
        processar_webhook,
        requer_plano,
        get_plano_atual,
        portal_cliente
    )
"""

import os
import stripe
import streamlit as st
from supabase import create_client

# ─────────────────────────────────────────────
# Configuração
# ─────────────────────────────────────────────
stripe.api_key = os.environ.get("STRIPE_SECRET_KEY")

SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY")
supabase     = create_client(SUPABASE_URL, SUPABASE_KEY)

APP_URL = os.environ.get("APP_URL", "https://fxgestaodefrotasonline.com")

# Price IDs dos planos (Stripe)
PLANOS = {
    "gratuito":    {"price_id": None,                              "max_usuarios": 1,  "max_veiculos": 10},
    "basico":      {"price_id": "price_1Tf2ftRoRAomG8bP8hqJDGNC", "max_usuarios": 5,  "max_veiculos": 50},
    "profissional":{"price_id": "price_1Tf2gJRoRAomG8bPxUCKnKZy", "max_usuarios": 20, "max_veiculos": 200},
    "enterprise":  {"price_id": "price_1Tf2goRoRAomG8bPU40Yll9M", "max_usuarios": -1, "max_veiculos": -1},
}

# Mapeamento price_id → nome do plano
PRICE_ID_PARA_PLANO = {v["price_id"]: k for k, v in PLANOS.items() if v["price_id"]}

# Hierarquia dos planos (para comparação)
HIERARQUIA = {"gratuito": 0, "basico": 1, "profissional": 2, "enterprise": 3}


# ─────────────────────────────────────────────
# Checkout — redireciona para o Stripe
# ─────────────────────────────────────────────
def criar_checkout_session(plano: str, empresa_id: str, email: str) -> str:
    """
    Cria uma sessão de checkout no Stripe e retorna a URL.
    
    Uso:
        url = criar_checkout_session("basico", empresa_id, user_email)
        st.markdown(f'<meta http-equiv="refresh" content="0;url={url}">', unsafe_allow_html=True)
    """
    price_id = PLANOS[plano]["price_id"]
    if not price_id:
        raise ValueError(f"Plano '{plano}' não tem price_id configurado.")

    # Busca ou cria customer no Stripe
    empresa = supabase.table("empresas").select("stripe_customer_id").eq("id", empresa_id).single().execute()
    customer_id = empresa.data.get("stripe_customer_id")

    if not customer_id:
        customer = stripe.Customer.create(email=email, metadata={"empresa_id": empresa_id})
        customer_id = customer.id
        supabase.table("empresas").update({"stripe_customer_id": customer_id}).eq("id", empresa_id).execute()

    # Cria sessão de checkout
    session = stripe.checkout.Session.create(
        customer=customer_id,
        payment_method_types=["card"],
        line_items=[{"price": price_id, "quantity": 1}],
        mode="subscription",
        success_url=f"{APP_URL}?checkout=success&session_id={{CHECKOUT_SESSION_ID}}",
        cancel_url=f"{APP_URL}?checkout=cancelled",
        metadata={"empresa_id": empresa_id, "plano": plano},
        subscription_data={"metadata": {"empresa_id": empresa_id, "plano": plano}},
    )
    return session.url


# ─────────────────────────────────────────────
# Portal do Cliente — autoatendimento de billing
# ─────────────────────────────────────────────
def portal_cliente(empresa_id: str) -> str:
    """
    Retorna URL do portal Stripe onde o cliente pode:
    - Trocar cartão
    - Fazer upgrade/downgrade
    - Cancelar assinatura
    """
    empresa = supabase.table("empresas").select("stripe_customer_id").eq("id", empresa_id).single().execute()
    customer_id = empresa.data.get("stripe_customer_id")

    if not customer_id:
        raise ValueError("Empresa não tem customer_id no Stripe.")

    session = stripe.billing_portal.Session.create(
        customer=customer_id,
        return_url=APP_URL,
    )
    return session.url


# ─────────────────────────────────────────────
# Webhooks — processa eventos do Stripe
# ─────────────────────────────────────────────
def processar_webhook(payload: bytes, sig_header: str) -> dict:
    """
    Valida e processa um evento webhook do Stripe.
    Garante idempotência verificando stripe_events.
    
    Retorna: {"status": "ok"|"ignorado"|"erro", "mensagem": str}
    """
    webhook_secret = os.environ.get("STRIPE_WEBHOOK_SECRET")

    try:
        evento = stripe.Webhook.construct_event(payload, sig_header, webhook_secret)
    except stripe.error.SignatureVerificationError:
        return {"status": "erro", "mensagem": "Assinatura inválida"}

    event_id   = evento["id"]
    event_tipo = evento["type"]

    # ── Idempotência: ignora evento já processado ──
    existente = supabase.table("stripe_events").select("id").eq("stripe_event_id", event_id).execute()
    if existente.data:
        return {"status": "ignorado", "mensagem": f"Evento {event_id} já processado"}

    # ── Salva o evento ──
    supabase.table("stripe_events").insert({
        "stripe_event_id": event_id,
        "tipo": event_tipo,
        "payload": evento,
    }).execute()

    # ── Processa por tipo ──
    dados = evento["data"]["object"]

    if event_tipo == "checkout.session.completed":
        _handle_checkout_completed(dados)

    elif event_tipo == "invoice.payment_succeeded":
        _handle_payment_succeeded(dados)

    elif event_tipo == "invoice.payment_failed":
        _handle_payment_failed(dados)

    elif event_tipo == "customer.subscription.deleted":
        _handle_subscription_deleted(dados)

    elif event_tipo == "customer.subscription.updated":
        _handle_subscription_updated(dados)

    # ── Marca como processado ──
    supabase.table("stripe_events").update({"processado_em": "now()"}).eq("stripe_event_id", event_id).execute()

    return {"status": "ok", "mensagem": f"Evento {event_tipo} processado"}


def _handle_checkout_completed(session: dict):
    """Ativa tenant após checkout bem-sucedido."""
    empresa_id       = session.get("metadata", {}).get("empresa_id")
    plano            = session.get("metadata", {}).get("plano", "basico")
    subscription_id  = session.get("subscription")
    customer_id      = session.get("customer")

    if not empresa_id:
        return

    supabase.table("empresas").update({
        "status":                  "ativo",
        "plano":                   plano,
        "stripe_subscription_id":  subscription_id,
        "stripe_customer_id":      customer_id,
        "max_usuarios":            PLANOS[plano]["max_usuarios"],
        "max_veiculos":            PLANOS[plano]["max_veiculos"],
    }).eq("id", empresa_id).execute()


def _handle_payment_succeeded(invoice: dict):
    """Renova status ativo e registra fatura."""
    customer_id = invoice.get("customer")
    empresa     = supabase.table("empresas").select("id").eq("stripe_customer_id", customer_id).execute()
    if not empresa.data:
        return

    empresa_id = empresa.data[0]["id"]

    supabase.table("empresas").update({"status": "ativo"}).eq("id", empresa_id).execute()

    # Registra fatura
    supabase.table("invoices").insert({
        "empresa_id":       empresa_id,
        "stripe_invoice_id": invoice.get("id"),
        "valor_cents":      invoice.get("amount_paid", 0),
        "status":           "pago",
        "periodo_inicio":   _ts(invoice.get("period_start")),
        "periodo_fim":      _ts(invoice.get("period_end")),
    }).execute()


def _handle_payment_failed(invoice: dict):
    """Suspende tenant após falha de pagamento."""
    customer_id = invoice.get("customer")
    empresa     = supabase.table("empresas").select("id").eq("stripe_customer_id", customer_id).execute()
    if not empresa.data:
        return

    empresa_id = empresa.data[0]["id"]
    supabase.table("empresas").update({"status": "suspenso"}).eq("id", empresa_id).execute()

    supabase.table("invoices").insert({
        "empresa_id":        empresa_id,
        "stripe_invoice_id": invoice.get("id"),
        "valor_cents":       invoice.get("amount_due", 0),
        "status":            "falhou",
        "periodo_inicio":    _ts(invoice.get("period_start")),
        "periodo_fim":       _ts(invoice.get("period_end")),
    }).execute()


def _handle_subscription_deleted(subscription: dict):
    """Cancela tenant quando assinatura é deletada."""
    customer_id = subscription.get("customer")
    empresa     = supabase.table("empresas").select("id").eq("stripe_customer_id", customer_id).execute()
    if not empresa.data:
        return

    supabase.table("empresas").update({
        "status":       "cancelado",
        "cancelado_em": "now()",
        "plano":        "gratuito",
    }).eq("id", empresa.data[0]["id"]).execute()


def _handle_subscription_updated(subscription: dict):
    """Atualiza plano após upgrade/downgrade."""
    customer_id = subscription.get("customer")
    empresa     = supabase.table("empresas").select("id").eq("stripe_customer_id", customer_id).execute()
    if not empresa.data:
        return

    empresa_id = empresa.data[0]["id"]

    # Descobre qual plano pelo price_id
    items    = subscription.get("items", {}).get("data", [])
    price_id = items[0]["price"]["id"] if items else None
    plano    = PRICE_ID_PARA_PLANO.get(price_id, "basico")

    supabase.table("empresas").update({
        "plano":        plano,
        "status":       subscription.get("status", "ativo"),
        "max_usuarios": PLANOS[plano]["max_usuarios"],
        "max_veiculos": PLANOS[plano]["max_veiculos"],
    }).eq("id", empresa_id).execute()


# ─────────────────────────────────────────────
# Feature Flags — controle de acesso por plano
# ─────────────────────────────────────────────
def get_plano_atual() -> str:
    """Retorna o plano atual do tenant logado."""
    return st.session_state.get("tenant_plano", "gratuito")


def requer_plano(plano_minimo: str):
    """
    Bloqueia a execução se o tenant não tiver o plano mínimo.
    
    Uso:
        requer_plano("profissional")
        # código abaixo só executa para Pro e Enterprise
    """
    plano_atual = get_plano_atual()
    empresa_id  = st.session_state.get("empresa_id")

    if HIERARQUIA.get(plano_atual, 0) < HIERARQUIA.get(plano_minimo, 0):
        nomes = {"basico": "Básico (R$149/mês)", "profissional": "Pro (R$349/mês)", "enterprise": "Enterprise (R$899/mês)"}
        st.warning(f"🔒 Esta função requer o plano **{nomes.get(plano_minimo, plano_minimo)}**.")

        col1, col2 = st.columns(2)
        with col1:
            if st.button("🚀 Fazer upgrade agora", type="primary"):
                if empresa_id:
                    email = st.session_state.get("user_email", "")
                    url   = criar_checkout_session(plano_minimo, empresa_id, email)
                    st.markdown(f'<meta http-equiv="refresh" content="0;url={url}">', unsafe_allow_html=True)
        with col2:
            st.caption(f"Plano atual: **{plano_atual.capitalize()}**")

        st.stop()


def verificar_limite(recurso: str, quantidade_atual: int) -> bool:
    """
    Verifica se o tenant atingiu o limite do plano.
    
    Uso:
        if not verificar_limite("veiculos", total_veiculos):
            st.error("Limite de veículos atingido. Faça upgrade!")
            st.stop()
    """
    plano_atual = get_plano_atual()
    limites     = PLANOS.get(plano_atual, PLANOS["gratuito"])

    if recurso == "veiculos":
        limite = limites["max_veiculos"]
    elif recurso == "usuarios":
        limite = limites["max_usuarios"]
    else:
        return True

    if limite == -1:  # ilimitado (Enterprise)
        return True

    return quantidade_atual < limite


# ─────────────────────────────────────────────
# UI — Tela de Planos
# ─────────────────────────────────────────────
def mostrar_tela_planos():
    """Renderiza a tela de seleção de planos com integração real ao Stripe."""
    import streamlit as _st

    # ── Resolve empresa e email do usuário logado ──────────────────
    _emp_pl    = _st.session_state.get("_empresa_ativa") or {}
    empresa_id = _emp_pl.get("id", "")
    plano_atual= _emp_pl.get("plano", "gratuito")
    _auth_user = _st.session_state.get("_auth_user") or {}
    email      = (_auth_user.get("email") or
                  _st.session_state.get("_auth_email", "") or "")

    _st.markdown(
        "<h2 style='margin:0 0 4px'>🚀 Planos & Assinatura</h2>"
        "<p style='color:#666;margin:0 0 20px'>Escolha o plano ideal para sua frota.</p>",
        unsafe_allow_html=True,
    )

    if not empresa_id:
        _st.warning("Empresa não identificada. Faça login novamente.")
        return

    PLANOS_INFO = [
        {
            "key": "gratuito",
            "icon": "🆓", "nome": "Gratuito", "preco": "R$ 0/mês",
            "recursos": ["1 usuário", "10 veículos", "Consulta de postos ANP"],
        },
        {
            "key": "basico",
            "icon": "📦", "nome": "Básico", "preco": "R$ 149/mês",
            "recursos": ["5 usuários", "50 veículos", "Exportação Excel", "Suporte por e-mail"],
        },
        {
            "key": "profissional",
            "icon": "⭐", "nome": "Pro", "preco": "R$ 349/mês",
            "recursos": ["20 usuários", "200 veículos", "Relatórios avançados", "API REST", "Assistente IA"],
        },
        {
            "key": "enterprise",
            "icon": "🏢", "nome": "Enterprise", "preco": "R$ 899/mês",
            "recursos": ["Ilimitado", "SSO / SAML", "SLA 99,95%", "Suporte dedicado", "Onboarding guiado"],
        },
    ]

    cols = _st.columns(4)
    for col, plano in zip(cols, PLANOS_INFO):
        with col:
            is_atual = (plano["key"] == plano_atual)
            borda    = "2px solid #1565c0" if is_atual else "1px solid #e0e0e0"
            _st.markdown(
                f"<div style='border:{borda};border-radius:12px;padding:16px 12px;"
                f"background:{'#f0f7ff' if is_atual else '#fff'};min-height:220px'>"
                f"<div style='font-size:24px'>{plano['icon']}</div>"
                f"<div style='font-weight:700;font-size:15px;margin:4px 0'>{plano['nome']}</div>"
                f"<div style='color:#1565c0;font-weight:600;margin-bottom:10px'>{plano['preco']}</div>"
                + "".join(f"<div style='font-size:12px;color:#555;margin-bottom:2px'>✔ {r}</div>"
                          for r in plano["recursos"])
                + "</div>",
                unsafe_allow_html=True,
            )
            _st.markdown("<div style='height:8px'></div>", unsafe_allow_html=True)

            if is_atual:
                _st.button("✅ Plano atual", disabled=True,
                           key=f"btn_plano_{plano['key']}", use_container_width=True)
            elif plano["key"] == "gratuito":
                _st.button("Fazer downgrade", disabled=True,
                           key=f"btn_plano_{plano['key']}", use_container_width=True)
            else:
                if _st.button(f"Assinar {plano['nome']}",
                              key=f"btn_plano_{plano['key']}",
                              type="primary", use_container_width=True):
                    try:
                        with _st.spinner("Preparando checkout seguro..."):
                            _url = criar_checkout_session(plano["key"], empresa_id, email)
                        _st.markdown(
                            f"<div style='background:#e8f5e9;border:1px solid #a5d6a7;"
                            f"border-radius:8px;padding:12px 16px;margin-top:8px'>"
                            f"✅ <b>Checkout criado!</b><br>"
                            f"<a href='{_url}' target='_blank' style='color:#1565c0;font-weight:600'>"
                            f"👉 Clique aqui para pagar com segurança no Stripe</a></div>",
                            unsafe_allow_html=True,
                        )
                        _st.link_button(
                            f"💳 Ir para pagamento — {plano['nome']}",
                            url=_url, use_container_width=True,
                        )
                    except Exception as _e_str:
                        _st.error(f"Erro ao criar sessão de pagamento: {_e_str}")

    _st.divider()
    _st.markdown("#### ⚙️ Gerenciar assinatura existente")
    _st.caption("Altere forma de pagamento, cancele ou veja faturas anteriores.")
    if _st.button("Acessar portal do cliente Stripe", key="btn_portal_stripe"):
        try:
            with _st.spinner("Abrindo portal..."):
                _url_portal = portal_cliente(empresa_id)
            _st.link_button("🔗 Acessar portal", url=_url_portal)
        except Exception as _e_portal:
            _st.error(f"Erro ao abrir portal: {_e_portal}")

def _ts(unix_timestamp):
    """Converte timestamp Unix para ISO 8601."""
    if not unix_timestamp:
        return None
    from datetime import datetime, timezone
    return datetime.fromtimestamp(unix_timestamp, tz=timezone.utc).isoformat()
