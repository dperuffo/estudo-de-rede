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
    """Renderiza a tela de seleção de planos."""
    st.title("🚀 Escolha seu plano")
    st.caption("Comece grátis. Faça upgrade quando precisar.")

    empresa_id = st.session_state.get("empresa_id", "")
    email      = st.session_state.get("user_email", "")

    col1, col2, col3, col4 = st.columns(4)

    with col1:
        st.markdown("### 🆓 Gratuito")
        st.markdown("**R$ 0/mês**")
        st.markdown("- 1 usuário\n- 10 veículos\n- 2 postos")
        st.button("Plano atual", disabled=True, key="btn_gratuito")

    with col2:
        st.markdown("### 📦 Básico")
        st.markdown("**R$ 149/mês**")
        st.markdown("- 5 usuários\n- 50 veículos\n- 10 postos\n- Exportação Excel")
        if st.button("Assinar Básico", key="btn_basico", type="primary"):
            url = criar_checkout_session("basico", empresa_id, email)
            st.markdown(f'<meta http-equiv="refresh" content="0;url={url}">', unsafe_allow_html=True)

    with col3:
        st.markdown("### ⭐ Pro")
        st.markdown("**R$ 349/mês**")
        st.markdown("- 20 usuários\n- 200 veículos\n- Postos ilimitados\n- Relatórios avançados\n- API REST")
        if st.button("Assinar Pro", key="btn_pro", type="primary"):
            url = criar_checkout_session("profissional", empresa_id, email)
            st.markdown(f'<meta http-equiv="refresh" content="0;url={url}">', unsafe_allow_html=True)

    with col4:
        st.markdown("### 🏢 Enterprise")
        st.markdown("**R$ 899/mês**")
        st.markdown("- Ilimitado\n- SSO SAML\n- SLA 99,95%\n- Suporte dedicado")
        if st.button("Assinar Enterprise", key="btn_enterprise", type="primary"):
            url = criar_checkout_session("enterprise", empresa_id, email)
            st.markdown(f'<meta http-equiv="refresh" content="0;url={url}">', unsafe_allow_html=True)

    st.divider()
    if st.button("⚙️ Gerenciar assinatura atual"):
        url = portal_cliente(empresa_id)
        st.markdown(f'<meta http-equiv="refresh" content="0;url={url}">', unsafe_allow_html=True)


# ─────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────
def _ts(unix_timestamp):
    """Converte timestamp Unix para ISO 8601."""
    if not unix_timestamp:
        return None
    from datetime import datetime, timezone
    return datetime.fromtimestamp(unix_timestamp, tz=timezone.utc).isoformat()
