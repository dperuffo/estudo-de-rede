# ═══════════════════════════════════════════════════════════════════════════
#  FNI PRÓ-FROTAS — Onboarding Self-Service
#  Fase 3: cadastro → trial → pagamento → ativação
#
#  Como usar no estudo_de_rede.py:
#      from onboarding import mostrar_tela_onboarding
#      mostrar_tela_onboarding()
# ═══════════════════════════════════════════════════════════════════════════

from __future__ import annotations
import os
import re
import streamlit as st
from datetime import datetime, timezone, timedelta
from typing import Any


# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURAÇÃO
# ─────────────────────────────────────────────────────────────────────────────

TRIAL_DIAS = 14          # duração do trial em dias
PLANO_TRIAL = "profissional"   # plano liberado durante o trial


# ─────────────────────────────────────────────────────────────────────────────
# HELPERS INTERNOS
# ─────────────────────────────────────────────────────────────────────────────

def _db():
    """Retorna o cliente Supabase configurado no app principal."""
    try:
        from supabase import create_client
        url = os.environ.get("SUPABASE_URL", "")
        key = os.environ.get("SUPABASE_KEY", "")
        if url and key:
            return create_client(url, key)
    except Exception:
        pass
    return None


def _validar_cnpj(cnpj: str) -> bool:
    """Valida formato básico de CNPJ (14 dígitos, ignora pontuação)."""
    cnpj = re.sub(r"\D", "", cnpj)
    return len(cnpj) == 14 and not cnpj == cnpj[0] * 14


def _formatar_cnpj(cnpj: str) -> str:
    """Formata CNPJ como XX.XXX.XXX/XXXX-XX."""
    cnpj = re.sub(r"\D", "", cnpj)
    if len(cnpj) == 14:
        return f"{cnpj[:2]}.{cnpj[2:5]}.{cnpj[5:8]}/{cnpj[8:12]}-{cnpj[12:]}"
    return cnpj


def _trial_ends_at() -> str:
    """Retorna ISO timestamp do fim do trial (hoje + TRIAL_DIAS)."""
    fim = datetime.now(tz=timezone.utc) + timedelta(days=TRIAL_DIAS)
    return fim.isoformat()


# ─────────────────────────────────────────────────────────────────────────────
# OPERAÇÕES DE BANCO
# ─────────────────────────────────────────────────────────────────────────────

def _empresa_existe_por_cnpj(cnpj: str) -> bool:
    """Verifica se já existe empresa cadastrada com esse CNPJ."""
    db = _db()
    if not db:
        return False
    try:
        cnpj_limpo = re.sub(r"\D", "", cnpj)
        res = (
            db.table("empresas")
            .select("id")
            .eq("cnpj", cnpj_limpo)
            .limit(1)
            .execute()
        )
        return len(res.data or []) > 0
    except Exception:
        return False


def _criar_empresa_trial(nome: str, cnpj: str, email: str) -> dict | None:
    """
    Cria empresa com status='trial' e associa o usuário como 'admin'.
    Retorna o registro criado ou None em caso de erro.
    """
    db = _db()
    if not db:
        return None
    try:
        cnpj_limpo = re.sub(r"\D", "", cnpj)
        trial_end = _trial_ends_at()

        # 1. Criar empresa
        res_empresa = (
            db.table("empresas")
            .insert({
                "nome":          nome.strip(),
                "cnpj":          cnpj_limpo,
                "ativo":         True,
                "plano":         PLANO_TRIAL,
                "status":        "trial",
                "trial_ends_at": trial_end,
                "max_usuarios":  20,   # limite do plano profissional
                "max_veiculos":  200,
            })
            .execute()
        )
        empresa = res_empresa.data[0] if res_empresa.data else None
        if not empresa:
            return None

        empresa_id = empresa["id"]

        # 2. Associar usuário como admin da empresa
        db.table("usuarios_empresas").insert({
            "empresa_id": empresa_id,
            "user_email": email.lower().strip(),
            "role":       "admin",
            "ativo":      True,
        }).execute()

        # 3. Registrar consentimento LGPD
        try:
            from tenant_utils import registrar_consentimento
            registrar_consentimento(
                db_client=db,
                email=email,
                empresa_id=empresa_id,
                tipo="cadastro_trial",
            )
        except Exception:
            pass  # não bloquear o fluxo por falha de auditoria

        return empresa

    except Exception as e:
        st.error(f"Erro ao criar empresa: {e}")
        return None


def _usuario_tem_empresa(email: str) -> bool:
    """Verifica se o usuário já tem alguma empresa associada."""
    db = _db()
    if not db:
        return False
    try:
        res = (
            db.table("usuarios_empresas")
            .select("empresa_id")
            .eq("user_email", email.lower())
            .eq("ativo", True)
            .limit(1)
            .execute()
        )
        return len(res.data or []) > 0
    except Exception:
        return False


# ─────────────────────────────────────────────────────────────────────────────
# ETAPAS DO WIZARD
# ─────────────────────────────────────────────────────────────────────────────

def _etapa_boas_vindas(email: str) -> None:
    """Etapa 0: tela de boas-vindas antes do cadastro."""
    st.markdown("## 🚀 Comece seu teste grátis de 14 dias")
    st.markdown(
        f"Olá! Você está logado como **{email}**. "
        "Vamos configurar sua empresa para começar a usar o FNI Pró-Frotas."
    )

    col1, col2, col3 = st.columns(3)
    with col1:
        st.info("**⏱️ 14 dias grátis**\nSem cartão de crédito")
    with col2:
        st.info("**⭐ Plano Profissional**\nTodos os recursos liberados")
    with col3:
        st.info("**🔒 Sem compromisso**\nCancele quando quiser")

    st.markdown("---")
    if st.button("Começar cadastro →", type="primary", use_container_width=True):
        st.session_state["_onboard_etapa"] = 1
        st.rerun()


def _etapa_dados_empresa(email: str) -> None:
    """Etapa 1: coleta nome e CNPJ da empresa."""
    st.markdown("## 📋 Dados da sua empresa")
    st.caption("Etapa 1 de 2 — Informações básicas")

    st.progress(0.5)

    with st.form("form_empresa"):
        nome = st.text_input(
            "Nome da empresa *",
            placeholder="Ex: Transportadora Silva Ltda",
            max_chars=120,
        )
        cnpj = st.text_input(
            "CNPJ *",
            placeholder="00.000.000/0000-00",
            max_chars=18,
            help="Digite apenas os números ou com pontuação",
        )
        aceite = st.checkbox(
            "Li e aceito os [Termos de Uso](https://fni.com.br/termos) "
            "e a [Política de Privacidade](https://fni.com.br/privacidade) *"
        )

        col_voltar, col_avancar = st.columns([1, 3])
        with col_voltar:
            voltar = st.form_submit_button("← Voltar")
        with col_avancar:
            avancar = st.form_submit_button("Continuar →", type="primary", use_container_width=True)

    if voltar:
        st.session_state["_onboard_etapa"] = 0
        st.rerun()

    if avancar:
        erros = []
        if not nome.strip():
            erros.append("Nome da empresa é obrigatório.")
        if not cnpj.strip():
            erros.append("CNPJ é obrigatório.")
        elif not _validar_cnpj(cnpj):
            erros.append("CNPJ inválido. Verifique os dígitos.")
        if not aceite:
            erros.append("Você precisa aceitar os Termos de Uso para continuar.")

        if erros:
            for e in erros:
                st.error(e)
            return

        # Verificar se CNPJ já está cadastrado
        if _empresa_existe_por_cnpj(cnpj):
            st.warning(
                "Este CNPJ já está cadastrado. "
                "Se você já tem uma conta, faça login normalmente. "
                "Em caso de dúvidas, contate d.peruffo@gmail.com"
            )
            return

        # Salvar dados na sessão e avançar
        st.session_state["_onboard_nome"]  = nome.strip()
        st.session_state["_onboard_cnpj"]  = cnpj.strip()
        st.session_state["_onboard_etapa"] = 2
        st.rerun()


def _etapa_confirmacao(email: str) -> None:
    """Etapa 2: resumo e confirmação antes de criar a empresa."""
    st.markdown("## ✅ Confirme seus dados")
    st.caption("Etapa 2 de 2 — Revisão e ativação")

    st.progress(1.0)

    nome = st.session_state.get("_onboard_nome", "")
    cnpj = st.session_state.get("_onboard_cnpj", "")

    st.markdown(f"""
    | Campo | Valor |
    |---|---|
    | **Empresa** | {nome} |
    | **CNPJ** | {_formatar_cnpj(cnpj)} |
    | **E-mail admin** | {email} |
    | **Plano trial** | Profissional (14 dias grátis) |
    | **Trial expira em** | {(datetime.now() + timedelta(days=TRIAL_DIAS)).strftime('%d/%m/%Y')} |
    """)

    st.info(
        "Após a ativação, você terá acesso completo ao plano Profissional por 14 dias. "
        "No D+12 você receberá um aviso para escolher seu plano definitivo."
    )

    col_voltar, col_ativar = st.columns([1, 3])
    with col_voltar:
        if st.button("← Editar"):
            st.session_state["_onboard_etapa"] = 1
            st.rerun()
    with col_ativar:
        if st.button("🚀 Ativar meu trial grátis!", type="primary", use_container_width=True):
            with st.spinner("Criando sua conta..."):
                empresa = _criar_empresa_trial(nome, cnpj, email)

            if empresa:
                st.session_state["_onboard_etapa"]    = 3
                st.session_state["_onboard_empresa_id"] = empresa["id"]
                st.rerun()
            else:
                st.error(
                    "Não foi possível criar sua conta. "
                    "Tente novamente ou contate d.peruffo@gmail.com"
                )


def _etapa_sucesso(email: str) -> None:
    """Etapa 3: tela de sucesso após criação do trial."""
    empresa_nome = st.session_state.get("_onboard_nome", "sua empresa")

    st.balloons()
    st.success("### 🎉 Conta criada com sucesso!")
    st.markdown(f"""
    **{empresa_nome}** está pronta! Seu trial de **14 dias** do plano Profissional começa agora.

    **Próximos passos sugeridos:**
    1. 🚗 Cadastre seus veículos
    2. ⛽ Registre seu primeiro abastecimento
    3. 📊 Explore os relatórios de consumo
    """)

    st.info(
        f"📧 Um e-mail de boas-vindas foi enviado para **{email}** "
        "com dicas para começar. Verifique sua caixa de entrada."
    )

    if st.button("Entrar na plataforma →", type="primary", use_container_width=True):
        # Limpar estado do onboarding e recarregar o app
        for k in ["_onboard_etapa", "_onboard_nome", "_onboard_cnpj", "_onboard_empresa_id"]:
            st.session_state.pop(k, None)
        st.rerun()


# ─────────────────────────────────────────────────────────────────────────────
# FUNÇÃO PRINCIPAL — CHAMADA PELO APP
# ─────────────────────────────────────────────────────────────────────────────

def mostrar_tela_onboarding(email: str | None = None) -> None:
    """
    Exibe o wizard de onboarding self-service.

    Chame esta função quando o usuário está autenticado mas
    ainda não tem nenhuma empresa associada.

    Uso no estudo_de_rede.py:
        from onboarding import mostrar_tela_onboarding, usuario_precisa_onboarding

        if usuario_precisa_onboarding(email):
            mostrar_tela_onboarding(email)
            st.stop()
    """
    # Resolver e-mail do usuário logado
    if not email:
        try:
            email = st.session_state.get("_usuario_email") or \
                    st.session_state.get("email") or \
                    st.session_state.get("user_email") or ""
        except Exception:
            email = ""

    if not email:
        st.error("Usuário não identificado. Faça login novamente.")
        return

    # Inicializar etapa se necessário
    if "_onboard_etapa" not in st.session_state:
        st.session_state["_onboard_etapa"] = 0

    etapa = st.session_state["_onboard_etapa"]

    # Indicador de progresso no topo
    if etapa > 0:
        st.markdown(
            f"<p style='color:gray;font-size:12px'>Cadastro de empresa — Etapa {min(etapa, 2)} de 2</p>",
            unsafe_allow_html=True,
        )

    # Roteamento de etapas
    if etapa == 0:
        _etapa_boas_vindas(email)
    elif etapa == 1:
        _etapa_dados_empresa(email)
    elif etapa == 2:
        _etapa_confirmacao(email)
    elif etapa >= 3:
        _etapa_sucesso(email)


def usuario_precisa_onboarding(email: str) -> bool:
    """
    Retorna True se o usuário autenticado ainda não tem empresa.
    Use como guard no fluxo principal do app.

    Exemplo:
        if usuario_precisa_onboarding(email_logado):
            mostrar_tela_onboarding(email_logado)
            st.stop()
    """
    if not email:
        return False
    return not _usuario_tem_empresa(email)
