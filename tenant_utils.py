# ═══════════════════════════════════════════════════════════════════════════
#  FNI PRÓ-FROTAS — Tenant Utilities
#  Fase 1: Multitenância, Feature Flags, Guards de Segurança
#
#  Importe no estudo_de_rede.py:
#      from tenant_utils import plano_permite, require_empresa_id, LIMITES_PLANO
# ═══════════════════════════════════════════════════════════════════════════

from __future__ import annotations
import functools
import os
from typing import Any, Callable

# ─────────────────────────────────────────────────────────────────────────────
# DEFINIÇÃO DOS PLANOS E LIMITES
# ─────────────────────────────────────────────────────────────────────────────

ORDEM_PLANOS = {"gratuito": 0, "basico": 1, "profissional": 2, "enterprise": 3}

LIMITES_PLANO: dict[str, dict] = {
    "gratuito": {
        "max_usuarios":        1,
        "max_veiculos":        10,
        "max_postos":          2,
        "historico_dias":      0,      # sem histórico ANP
        "mfa_obrigatorio":     False,
        "exportacao_excel":    False,
        "relatorios_avancados":False,
        "api_rest":            False,
        "sso_empresarial":     False,
        "preco_mes":           0,
    },
    "basico": {
        "max_usuarios":        5,
        "max_veiculos":        50,
        "max_postos":          10,
        "historico_dias":      30,
        "mfa_obrigatorio":     False,
        "exportacao_excel":    True,
        "relatorios_avancados":False,
        "api_rest":            False,
        "sso_empresarial":     False,
        "preco_mes":           149_00,  # centavos
    },
    "profissional": {
        "max_usuarios":        20,
        "max_veiculos":        200,
        "max_postos":          999_999,
        "historico_dias":      365,
        "mfa_obrigatorio":     True,
        "exportacao_excel":    True,
        "relatorios_avancados":True,
        "api_rest":            True,
        "sso_empresarial":     False,
        "preco_mes":           349_00,
    },
    "enterprise": {
        "max_usuarios":        999_999,
        "max_veiculos":        999_999,
        "max_postos":          999_999,
        "historico_dias":      36500,  # ~100 anos = completo
        "mfa_obrigatorio":     True,
        "exportacao_excel":    True,
        "relatorios_avancados":True,
        "api_rest":            True,
        "sso_empresarial":     True,
        "preco_mes":           0,      # negociado
    },
}


# ─────────────────────────────────────────────────────────────────────────────
# FUNÇÕES DE FEATURE FLAG
# ─────────────────────────────────────────────────────────────────────────────

def get_plano_atual() -> str:
    """
    Retorna o plano da empresa ativa na sessão.
    Fallback para 'gratuito' se não houver empresa ou plano definido.
    """
    try:
        import streamlit as st
        empresa_ativa = st.session_state.get("_empresa_ativa") or {}
        return empresa_ativa.get("plano", "gratuito")
    except Exception:
        return "gratuito"


def plano_permite(funcionalidade: str) -> bool:
    """
    Retorna True se o plano atual da empresa permite a funcionalidade.

    Uso:
        if not plano_permite("exportacao_excel"):
            st.warning("Faça upgrade para exportar.")
            return
    """
    plano = get_plano_atual()
    limites = LIMITES_PLANO.get(plano, LIMITES_PLANO["gratuito"])
    return bool(limites.get(funcionalidade, False))


def plano_minimo_para(funcionalidade: str) -> str:
    """Retorna o plano mínimo necessário para uma funcionalidade."""
    for plano in ["gratuito", "basico", "profissional", "enterprise"]:
        if LIMITES_PLANO[plano].get(funcionalidade):
            return plano
    return "enterprise"


def get_limite(campo: str) -> int:
    """
    Retorna o limite numérico do plano atual para um campo.
    Ex: get_limite("max_veiculos") → 50 (plano básico)
    """
    plano = get_plano_atual()
    limites = LIMITES_PLANO.get(plano, LIMITES_PLANO["gratuito"])
    return int(limites.get(campo, 0))


def verificar_limite(campo: str, quantidade_atual: int) -> tuple[bool, int, int]:
    """
    Verifica se a quantidade atual está dentro do limite do plano.
    Retorna (dentro_do_limite, quantidade_atual, limite_max).
    """
    limite = get_limite(campo)
    return (quantidade_atual < limite, quantidade_atual, limite)


def upgrade_banner(funcionalidade: str, mensagem: str = "") -> None:
    """
    Exibe banner de upgrade quando funcionalidade não está disponível no plano.
    Integrado com Streamlit.
    """
    try:
        import streamlit as st
        plano_min = plano_minimo_para(funcionalidade)
        preco = LIMITES_PLANO[plano_min]["preco_mes"]
        preco_fmt = f"R$ {preco // 100}/mês" if preco else "sob consulta"
        msg = mensagem or f"Esta funcionalidade requer o plano **{plano_min.capitalize()}** ({preco_fmt})."
        st.warning(
            f"🔒 {msg}  \n"
            f"Seu plano atual: **{get_plano_atual().capitalize()}**.",
            icon="⬆️"
        )
    except Exception:
        pass


def requer_plano(funcionalidade: str, mensagem: str = "") -> Callable:
    """
    Decorator que bloqueia uma função se o plano atual não suporta a funcionalidade.

    Uso como decorator:
        @requer_plano("api_rest")
        def minha_pagina_api():
            ...

    Uso inline:
        if not requer_plano_inline("exportacao_excel"):
            return
    """
    def decorator(func: Callable) -> Callable:
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            if not plano_permite(funcionalidade):
                upgrade_banner(funcionalidade, mensagem)
                return None
            return func(*args, **kwargs)
        return wrapper
    return decorator


# ─────────────────────────────────────────────────────────────────────────────
# GUARDS DE SEGURANÇA — isolamento de tenant
# ─────────────────────────────────────────────────────────────────────────────

class TenantContextError(RuntimeError):
    """Raised quando uma operação sensível é executada sem empresa_id definido."""
    pass


def require_empresa_id(empresa_id: str | None, operacao: str = "operação") -> str:
    """
    Garante que empresa_id está definido antes de operações de escrita.
    Lança TenantContextError se for None.

    Uso:
        eid = require_empresa_id(_db_empresa_id(), "salvar abastecimento")
        db.table("frota_abastecimentos").insert({"empresa_id": eid, ...})
    """
    if not empresa_id:
        raise TenantContextError(
            f"Tentativa de {operacao} sem empresa_id definido. "
            "Contexto de tenant não está inicializado."
        )
    return empresa_id


def safe_empresa_id(empresa_id: str | None, fallback_from_session: bool = True) -> str | None:
    """
    Versão segura que tenta recuperar empresa_id da sessão se None.
    Retorna None apenas se realmente não houver empresa ativa.
    """
    if empresa_id:
        return empresa_id
    if fallback_from_session:
        try:
            import streamlit as st
            return (st.session_state.get("_empresa_ativa") or {}).get("id")
        except Exception:
            pass
    return None


def inject_empresa_id(record: dict, empresa_id: str | None) -> dict:
    """
    Injeta empresa_id em um dicionário de registro se o campo ainda não estiver presente.
    Ignora silenciosamente se empresa_id for None.

    Uso:
        record = inject_empresa_id({"nome": "Truck A"}, _db_empresa_id())
        db.table("frota_veiculos_fipe").insert(record)
    """
    if empresa_id and "empresa_id" not in record:
        record["empresa_id"] = empresa_id
    return record


def inject_empresa_id_list(records: list[dict], empresa_id: str | None) -> list[dict]:
    """Injeta empresa_id em uma lista de registros."""
    if not empresa_id:
        return records
    return [inject_empresa_id(dict(r), empresa_id) for r in records]


# ─────────────────────────────────────────────────────────────────────────────
# STATUS DO TENANT
# ─────────────────────────────────────────────────────────────────────────────

def get_status_tenant() -> str:
    """Retorna o status do tenant ativo: 'ativo'|'trial'|'suspenso'|'cancelado'."""
    try:
        import streamlit as st
        empresa = st.session_state.get("_empresa_ativa") or {}
        return empresa.get("status", "ativo")
    except Exception:
        return "ativo"


def tenant_ativo() -> bool:
    """True se o tenant está ativo ou em trial."""
    return get_status_tenant() in ("ativo", "trial")


def banner_tenant_suspenso() -> bool:
    """
    Exibe banner e bloqueia navegação se tenant estiver suspenso/cancelado.
    Retorna True se bloqueado.
    """
    status = get_status_tenant()
    if status in ("suspenso", "cancelado"):
        try:
            import streamlit as st
            st.error(
                "⚠️ **Sua assinatura está suspensa.**  \n"
                "Atualize seus dados de pagamento para continuar acessando a plataforma.  \n"
                "Dúvidas: d.peruffo@gmail.com",
                icon="🔒"
            )
            st.stop()
        except Exception:
            pass
        return True
    return False


def dias_restantes_trial() -> int | None:
    """Retorna dias restantes do trial, ou None se não estiver em trial."""
    try:
        import streamlit as st
        from datetime import datetime, timezone
        empresa = st.session_state.get("_empresa_ativa") or {}
        if empresa.get("status") != "trial":
            return None
        trial_end = empresa.get("trial_ends_at")
        if not trial_end:
            return None
        if isinstance(trial_end, str):
            trial_end = datetime.fromisoformat(trial_end.replace("Z", "+00:00"))
        now = datetime.now(tz=timezone.utc)
        delta = (trial_end - now).days
        return max(0, delta)
    except Exception:
        return None


def banner_trial() -> None:
    """Exibe banner de trial se estiver ativo."""
    dias = dias_restantes_trial()
    if dias is None:
        return
    try:
        import streamlit as st
        if dias <= 3:
            st.warning(
                f"⏰ **Seu período de trial expira em {dias} dia(s).**  \n"
                "Faça upgrade agora para não perder o acesso.",
                icon="⚠️"
            )
        elif dias <= 7:
            st.info(
                f"🗓️ Seu trial expira em **{dias} dias**. "
                "Aproveite para explorar todas as funcionalidades!",
                icon="ℹ️"
            )
    except Exception:
        pass


# ─────────────────────────────────────────────────────────────────────────────
# AUDITORIA LGPD
# ─────────────────────────────────────────────────────────────────────────────

def registrar_consentimento(
    db_client: Any,
    email: str,
    empresa_id: str,
    ip: str = "",
    user_agent: str = "",
    tipo: str = "cadastro",
) -> bool:
    """
    Registra consentimento LGPD na tabela lgpd_consents.
    Cria a tabela se não existir.
    """
    if not db_client:
        return False
    try:
        from datetime import datetime, timezone
        db_client.table("lgpd_consents").insert({
            "email":       email,
            "empresa_id":  empresa_id,
            "tipo":        tipo,
            "ip":          ip,
            "user_agent":  user_agent,
            "timestamp":   datetime.now(tz=timezone.utc).isoformat(),
        }).execute()
        return True
    except Exception:
        return False


# ─────────────────────────────────────────────────────────────────────────────
# UTILITÁRIOS DE DIAGNÓSTICO
# ─────────────────────────────────────────────────────────────────────────────

def get_tenant_info() -> dict:
    """
    Retorna dict com informações completas do tenant ativo.
    Útil para logging e debug.
    """
    try:
        import streamlit as st
        empresa = st.session_state.get("_empresa_ativa") or {}
        return {
            "empresa_id":   empresa.get("id"),
            "empresa_nome": empresa.get("nome", "—"),
            "plano":        empresa.get("plano", "gratuito"),
            "status":       empresa.get("status", "desconhecido"),
            "role":         empresa.get("role", "viewer"),
        }
    except Exception:
        return {"empresa_id": None, "plano": "gratuito", "status": "desconhecido"}


def assert_tenant_isolation(
    db_client: Any,
    empresa_id_a: str,
    empresa_id_b: str,
    tabelas: list[str] | None = None,
) -> dict[str, bool]:
    """
    Utilitário de teste: verifica que empresa_id_a não vê dados de empresa_id_b.
    Retorna dict {tabela: isolado} para cada tabela testada.
    """
    if tabelas is None:
        tabelas = [
            "frota_abastecimentos", "postos_gf", "acordos_precos",
            "frota_veiculos_fipe", "rotas_salvas", "preferencias",
        ]
    resultados = {}
    for tabela in tabelas:
        try:
            res = (
                db_client.table(tabela)
                .select("empresa_id")
                .eq("empresa_id", empresa_id_b)
                .limit(1)
                .execute()
            )
            # Se retornou dados de empresa_b, isolamento falhou
            resultados[tabela] = len(res.data or []) == 0
        except Exception:
            resultados[tabela] = True  # erro = tabela não existe ou vazia
    return resultados


# ─────────────────────────────────────────────────────────────────────────────
# STRIPE CHECKOUT
# ─────────────────────────────────────────────────────────────────────────────

STRIPE_PRICE_IDS = {
    "basico":       "price_1Tf2ftRoRAomG8bP8hqJDGNC",
    "profissional": "price_1Tf2gJRoRAomG8bPxUCKnKZy",
    "enterprise":   "price_1Tf2goRoRAomG8bPU40Yll9M",
}

APP_URL = os.environ.get("APP_URL", "https://fxgestaodefrotasonline.com")


def criar_checkout_url(plano: str, empresa_id: str, email: str) -> str | None:
    """
    Cria sessão de checkout no Stripe e retorna a URL de pagamento.
    """
    try:
        import stripe
        from supabase import create_client
        stripe.api_key = os.environ.get("STRIPE_SECRET_KEY")
        sb = create_client(os.environ.get("SUPABASE_URL", ""), os.environ.get("SUPABASE_KEY", ""))

        # Busca ou cria customer
        empresa = sb.table("empresas").select("stripe_customer_id").eq("id", empresa_id).single().execute()
        customer_id = empresa.data.get("stripe_customer_id") if empresa.data else None

        if not customer_id:
            customer = stripe.Customer.create(email=email, metadata={"empresa_id": empresa_id})
            customer_id = customer.id
            sb.table("empresas").update({"stripe_customer_id": customer_id}).eq("id", empresa_id).execute()

        session = stripe.checkout.Session.create(
            customer=customer_id,
            payment_method_types=["card"],
            line_items=[{"price": STRIPE_PRICE_IDS[plano], "quantity": 1}],
            mode="subscription",
            success_url=f"{APP_URL}?checkout=success",
            cancel_url=f"{APP_URL}?checkout=cancelled",
            metadata={"empresa_id": empresa_id, "plano": plano},
        )
        return session.url
    except Exception as e:
        return None


def criar_portal_url(empresa_id: str) -> str | None:
    """Retorna URL do portal de billing do Stripe."""
    try:
        import stripe
        from supabase import create_client
        stripe.api_key = os.environ.get("STRIPE_SECRET_KEY")
        sb = create_client(os.environ.get("SUPABASE_URL", ""), os.environ.get("SUPABASE_KEY", ""))

        empresa = sb.table("empresas").select("stripe_customer_id").eq("id", empresa_id).single().execute()
        customer_id = empresa.data.get("stripe_customer_id") if empresa.data else None
        if not customer_id:
            return None

        portal = stripe.billing_portal.Session.create(
            customer=customer_id,
            return_url=APP_URL,
        )
        return portal.url
    except Exception:
        return None


def mostrar_tela_planos() -> None:
    """Renderiza tela de upgrade de planos no Streamlit."""
    import streamlit as st
    empresa = st.session_state.get("_empresa_ativa") or {}
    empresa_id = empresa.get("id", "")
    email = st.session_state.get("user_email", "")
    plano_atual = empresa.get("plano", "gratuito")

    st.title("🚀 Planos FNI Pró-Frotas")
    st.caption("Escolha o plano ideal para sua frota.")

    col1, col2, col3, col4 = st.columns(4)

    with col1:
        st.markdown("### 🆓 Gratuito")
        st.markdown("**R$ 0/mês**")
        st.markdown("- 1 usuário\n- 10 veículos\n- 2 postos")
        if plano_atual == "gratuito":
            st.button("Plano atual", disabled=True, key="btn_gr")

    with col2:
        st.markdown("### 📦 Básico")
        st.markdown("**R$ 149/mês**")
        st.markdown("- 5 usuários\n- 50 veículos\n- 10 postos\n- Exportação Excel")
        if plano_atual != "basico":
            if st.button("Assinar Básico", key="btn_ba", type="primary"):
                url = criar_checkout_url("basico", empresa_id, email)
                if url:
                    st.markdown(f'<meta http-equiv="refresh" content="0;url={url}">', unsafe_allow_html=True)

    with col3:
        st.markdown("### ⭐ Pro")
        st.markdown("**R$ 349/mês**")
        st.markdown("- 20 usuários\n- 200 veículos\n- Postos ilimitados\n- Relatórios\n- API REST")
        if plano_atual != "profissional":
            if st.button("Assinar Pro", key="btn_pr", type="primary"):
                url = criar_checkout_url("profissional", empresa_id, email)
                if url:
                    st.markdown(f'<meta http-equiv="refresh" content="0;url={url}">', unsafe_allow_html=True)

    with col4:
        st.markdown("### 🏢 Enterprise")
        st.markdown("**R$ 899/mês**")
        st.markdown("- Ilimitado\n- SSO SAML\n- SLA 99,95%\n- Suporte dedicado")
        if plano_atual != "enterprise":
            if st.button("Assinar Enterprise", key="btn_en", type="primary"):
                url = criar_checkout_url("enterprise", empresa_id, email)
                if url:
                    st.markdown(f'<meta http-equiv="refresh" content="0;url={url}">', unsafe_allow_html=True)

    st.divider()
    if st.button("⚙️ Gerenciar assinatura atual"):
        url = criar_portal_url(empresa_id)
        if url:
            st.markdown(f'<meta http-equiv="refresh" content="0;url={url}">', unsafe_allow_html=True)
