from __future__ import annotations
import os
import json
import base64
import streamlit as st
from datetime import datetime, timezone

ADMIN_EMAIL     = "contato@fxgestaodefrotasonline.com"
MAX_ARQUIVO_MB  = 1
MAX_TOTAL_MB    = 5
MAX_ARQUIVO_B   = MAX_ARQUIVO_MB * 1024 * 1024
MAX_TOTAL_B     = MAX_TOTAL_MB   * 1024 * 1024

TIPOS_PERMITIDOS = ["pdf","png","jpg","jpeg","xlsx","xls","csv","docx","doc","txt"]

STATUS_LABEL = {
    "aberto":     "🟡 Aberto",
    "em_analise": "🔵 Em análise",
    "resolvido":  "🟢 Resolvido",
    "fechado":    "⚫ Fechado",
}
PRIORIDADE_LABEL = {
    "baixa":   "🟢 Baixa",
    "media":   "🟡 Média",
    "alta":    "🟠 Alta",
    "critica": "🔴 Crítica",
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

def _email():
    try:
        return (st.session_state.get("_auth_user") or {}).get("email","")
    except Exception:
        return ""

def _validar_anexos(arquivos: list) -> tuple[bool, str]:
    total = 0
    for arq in arquivos:
        ext = arq.name.rsplit(".",1)[-1].lower()
        if ext not in TIPOS_PERMITIDOS:
            return False, f"Tipo não permitido: .{ext}"
        if arq.size > MAX_ARQUIVO_B:
            return False, f"{arq.name} excede {MAX_ARQUIVO_MB}MB"
        total += arq.size
    if total > MAX_TOTAL_B:
        return False, f"Total de anexos excede {MAX_TOTAL_MB}MB"
    return True, ""

def _salvar_ticket(tipo: str, titulo: str, descricao: str, prioridade: str, anexos_info: list) -> str | None:
    db = _db()
    if not db:
        return None
    try:
        res = db.table("tickets").insert({
            "empresa_id":  _empresa_id(),
            "user_email":  _email(),
            "tipo":        tipo,
            "titulo":      titulo,
            "descricao":   descricao,
            "prioridade":  prioridade,
            "status":      "aberto",
            "anexos":      json.dumps(anexos_info),
        }).execute()
        return res.data[0]["id"] if res.data else None
    except Exception as e:
        st.error(f"Erro ao salvar ticket: {e}")
        return None

def _listar_tickets(so_minha_empresa: bool = True) -> list:
    db = _db()
    if not db:
        return []
    try:
        q = db.table("tickets").select("*, numero").order("numero", desc=True)
        if so_minha_empresa:
            eid = _empresa_id()
            if eid:
                q = q.eq("empresa_id", eid)
            else:
                q = q.eq("user_email", _email())
        return q.execute().data or []
    except Exception:
        return []

def _atualizar_status(ticket_id: str, status: str, resposta: str = "") -> bool:
    db = _db()
    if not db:
        return False
    try:
        upd = {"status": status, "atualizado_em": datetime.now(tz=timezone.utc).isoformat()}
        if resposta:
            upd["resposta_admin"] = resposta
        db.table("tickets").update(upd).eq("id", ticket_id).execute()
        return True
    except Exception:
        return False

def _notificar_admin(tipo: str, titulo: str, descricao: str, email_usuario: str, prioridade: str):
    try:
        from emails import _enviar, _base
        emoji = "🚨" if tipo == "incidente" else "💡"
        _enviar(
            ADMIN_EMAIL,
            f"{emoji} [{tipo.upper()}] {titulo} — {email_usuario}",
            _base(f"""
            <h3>{emoji} Novo {tipo} registrado</h3>
            <table>
            <tr><td><b>Usuário</b></td><td>{email_usuario}</td></tr>
            <tr><td><b>Título</b></td><td>{titulo}</td></tr>
            <tr><td><b>Prioridade</b></td><td>{prioridade}</td></tr>
            <tr><td><b>Descrição</b></td><td>{descricao[:500]}</td></tr>
            </table>
            """, f"Novo {tipo}")
        )
    except Exception:
        pass

def mostrar_painel_tickets():
    st.markdown("## 🎫 Suporte & Melhorias")
    st.caption("Registre incidentes ou solicite melhorias para a plataforma")

    try:
        _meus = _listar_tickets(so_minha_empresa=True)
        if _meus:
            _tk1,_tk2,_tk3,_tk4,_tk5 = st.columns(5)
            _tk1.metric("📋 Meus tickets", len(_meus))
            _tk2.metric("🟡 Abertos",      len([t for t in _meus if t["status"]=="aberto"]),     help="Aguardando análise")
            _tk3.metric("🔵 Em Análise",   len([t for t in _meus if t["status"]=="em_analise"]), help="Em andamento")
            _tk4.metric("🟢 Resolvidos",   len([t for t in _meus if t["status"]=="resolvido"]),  help="Já resolvidos")
            _tk5.metric("🚨 Incidentes",   len([t for t in _meus if t["tipo"]=="incidente"]),    help="Total de incidentes")
            st.markdown("---")
    except Exception:
        pass

    aba1, aba2 = st.tabs(["➕ Novo ticket", "📋 Meus tickets"])

    with aba1:
        tipo = st.radio(
            "Tipo de solicitação",
            ["incidente", "melhoria"],
            format_func=lambda x: "🚨 Incidente / Problema" if x == "incidente" else "💡 Melhoria / Sugestão",
            horizontal=True
        )

        with st.form("form_ticket", clear_on_submit=True):
            titulo = st.text_input(
                "Título *",
                placeholder="Resumo claro do problema ou melhoria",
                max_chars=120
            )
            descricao = st.text_area(
                "Descrição detalhada *",
                placeholder="Descreva com detalhes o problema ou a melhoria desejada...",

    try:
        _meus = _listar_tickets(so_minha_empresa=True)
        if _meus:
            _tk1,_tk2,_tk3,_tk4,_tk5 = st.columns(5)
            _tk1.metric("📋 Meus tickets", len(_meus))
            _tk2.metric("🟡 Abertos",      len([t for t in _meus if t["status"]=="aberto"]),     help="Aguardando análise")
            _tk3.metric("🔵 Em Análise",   len([t for t in _meus if t["status"]=="em_analise"]), help="Em andamento")
            _tk4.metric("🟢 Resolvidos",   len([t for t in _meus if t["status"]=="resolvido"]),  help="Já resolvidos")
            _tk5.metric("🚨 Incidentes",   len([t for t in _meus if t["tipo"]=="incidente"]),    help="Total de incidentes")
            st.markdown("---")
    except Exception:
        pass


    try:
        _meus = _listar_tickets(so_minha_empresa=True)
        if _meus:
            _tk1,_tk2,_tk3,_tk4,_tk5 = st.columns(5)
            _tk1.metric("📋 Meus tickets", len(_meus))
            _tk2.metric("🟡 Abertos",      len([t for t in _meus if t["status"]=="aberto"]),     help="Aguardando análise")
            _tk3.metric("🔵 Em Análise",   len([t for t in _meus if t["status"]=="em_analise"]), help="Em andamento")
            _tk4.metric("🟢 Resolvidos",   len([t for t in _meus if t["status"]=="resolvido"]),  help="Já resolvidos")
            _tk5.metric("🚨 Incidentes",   len([t for t in _meus if t["tipo"]=="incidente"]),    help="Total de incidentes")
            st.markdown("---")
    except Exception:
        pass

                height=150,
                max_chars=2000
            )
            prioridade = st.select_slider(
                "Prioridade",
                options=["baixa","media","alta","critica"],
                value="media",
                format_func=lambda x: PRIORIDADE_LABEL[x]
            )
            anexos = st.file_uploader(
                f"Anexos (máx. {MAX_ARQUIVO_MB}MB por arquivo, {MAX_TOTAL_MB}MB total)",
                type=TIPOS_PERMITIDOS,
                accept_multiple_files=True,
                help=f"Tipos: {', '.join(TIPOS_PERMITIDOS)}"
            )
            enviado = st.form_submit_button("📨 Enviar ticket", type="primary", use_container_width=True)

        if enviado:
            erros = []
            if not titulo.strip():
                erros.append("Título é obrigatório.")
            if not descricao.strip():
                erros.append("Descrição é obrigatória.")
            if erros:
                for e in erros:
                    st.error(e)
            else:
                # Validar anexos
                ok_anx, msg_anx = _validar_anexos(anexos or [])
                if not ok_anx:
                    st.error(f"❌ Anexo inválido: {msg_anx}")
                else:
                    # Processar anexos
                    anexos_info = []
                    for arq in (anexos or []):
                        conteudo = base64.b64encode(arq.read()).decode()
                        anexos_info.append({
                            "nome":      arq.name,
                            "tipo_mime": arq.type,
                            "tamanho":   arq.size,
                            "conteudo":  conteudo,
                        })

                    with st.spinner("Enviando ticket..."):
                        tid = _salvar_ticket(tipo, titulo.strip(), descricao.strip(), prioridade, anexos_info)

                    if tid:
                        _notificar_admin(tipo, titulo.strip(), descricao.strip(), _email(), prioridade)
                        # Buscar numero gerado
                        _t_criado = _db().table("tickets").select("numero").eq("id", tid).execute()
                        _num_criado = _t_criado.data[0]["numero"] if _t_criado.data else "—"
                        st.success(f"✅ Ticket **#{_num_criado}** registrado com sucesso!")
                        st.info("📧 O administrador foi notificado e retornará em breve.")
                    else:
                        st.error("Erro ao registrar ticket. Tente novamente.")

    with aba2:
        tickets = _listar_tickets()
        if not tickets:
            st.info("Nenhum ticket registrado ainda.")
        else:
            for t in tickets:
                tipo_emoji = "🚨" if t["tipo"] == "incidente" else "💡"
                status_lbl = STATUS_LABEL.get(t["status"], t["status"])
                prio_lbl   = PRIORIDADE_LABEL.get(t.get("prioridade","media"), "")
                data       = t["criado_em"][:10] if t.get("criado_em") else ""

                _num = t.get("numero") or "—"
                with st.expander(f"#{_num} {tipo_emoji} {t['titulo']} — {status_lbl} · {data}"):
                    col1, col2 = st.columns(2)
                    with col1:
                        st.caption(f"**Tipo:** {t['tipo'].capitalize()}")
                        st.caption(f"**Prioridade:** {prio_lbl}")
                    with col2:
                        st.caption(f"**Status:** {status_lbl}")
                        st.caption(f"**Ticket:** #{t.get('numero','—')}")
                        st.caption(f"**ID:** `{t['id'][:8]}...`")

                    st.markdown("**Descrição:**")
                    st.write(t["descricao"])

                    # Anexos
                    anexos_salvos = t.get("anexos") or "[]"
                    if isinstance(anexos_salvos, str):
                        try:
                            anexos_salvos = json.loads(anexos_salvos)
                        except Exception:
                            anexos_salvos = []
                    if anexos_salvos:
                        st.markdown("**Anexos:**")
                        for anx in anexos_salvos:
                            if anx.get("conteudo"):
                                st.download_button(
                                    label=f"⬇️ {anx['nome']} ({round(anx.get('tamanho',0)/1024,1)}KB)",
                                    data=base64.b64decode(anx["conteudo"]),
                                    file_name=anx["nome"],
                                    mime=anx.get("tipo_mime","application/octet-stream"),
                                    key=f"anx_{t['id']}_{anx['nome']}"
                                )

                    # Resposta do admin
                    if t.get("resposta_admin"):
                        st.markdown("---")
                        st.markdown("**💬 Resposta do administrador:**")
                        st.info(t["resposta_admin"])


def mostrar_painel_admin_tickets():
    """Painel do admin para gerenciar todos os tickets."""
    st.markdown("## 🎫 Gerenciar Tickets")

    tickets = _listar_tickets(so_minha_empresa=False)
    if not tickets:
        st.info("Nenhum ticket registrado.")
        return


    _abertos  = [t for t in tickets if t["status"] == "aberto"]
    _analise  = [t for t in tickets if t["status"] == "em_analise"]
    _resolv   = [t for t in tickets if t["status"] == "resolvido"]
    _fechados = [t for t in tickets if t["status"] == "fechado"]
    _incid    = [t for t in tickets if t["tipo"] == "incidente"]
    _criticos = [t for t in tickets if t.get("prioridade") == "critica"]
    _ki1,_ki2,_ki3,_ki4,_ki5,_ki6,_ki7 = st.columns(7)
    _ki1.metric("📋 Total",      len(tickets))
    _ki2.metric("🟡 Abertos",    len(_abertos),  help="Aguardando análise")
    _ki3.metric("🔵 Em Análise", len(_analise),  help="Em andamento")
    _ki4.metric("🟢 Resolvidos", len(_resolv),   help="Já resolvidos")
    _ki5.metric("⚫ Fechados",   len(_fechados), help="Encerrados")
    _ki6.metric("🚨 Incidentes", len(_incid),    help="Total de incidentes")
    _ki7.metric("🔴 Críticos",   len(_criticos),
        delta=f"{len(_criticos)} urgente(s)" if _criticos else None,
        delta_color="inverse", help="Prioridade crítica")
    st.markdown("---")


    _abertos  = [t for t in tickets if t["status"] == "aberto"]
    _analise  = [t for t in tickets if t["status"] == "em_analise"]
    _resolv   = [t for t in tickets if t["status"] == "resolvido"]
    _fechados = [t for t in tickets if t["status"] == "fechado"]
    _incid    = [t for t in tickets if t["tipo"] == "incidente"]
    _criticos = [t for t in tickets if t.get("prioridade") == "critica"]
    _ki1,_ki2,_ki3,_ki4,_ki5,_ki6,_ki7 = st.columns(7)
    _ki1.metric("📋 Total",      len(tickets))
    _ki2.metric("🟡 Abertos",    len(_abertos),  help="Aguardando análise")
    _ki3.metric("🔵 Em Análise", len(_analise),  help="Em andamento")
    _ki4.metric("🟢 Resolvidos", len(_resolv),   help="Já resolvidos")
    _ki5.metric("⚫ Fechados",   len(_fechados), help="Encerrados")
    _ki6.metric("🚨 Incidentes", len(_incid),    help="Total de incidentes")
    _ki7.metric("🔴 Críticos",   len(_criticos),
        delta=f"{len(_criticos)} urgente(s)" if _criticos else None,
        delta_color="inverse", help="Prioridade crítica")
    st.markdown("---")

    # Filtros
    col1, col2, col3 = st.columns(3)
    with col1:
        filtro_status = st.selectbox("Status", ["Todos","aberto","em_analise","resolvido","fechado"])
    with col2:
        filtro_tipo = st.selectbox("Tipo", ["Todos","incidente","melhoria"])
    with col3:
        filtro_prio = st.selectbox("Prioridade", ["Todos","critica","alta","media","baixa"])

    # Aplicar filtros
    if filtro_status != "Todos":
        tickets = [t for t in tickets if t["status"] == filtro_status]
    if filtro_tipo != "Todos":
        tickets = [t for t in tickets if t["tipo"] == filtro_tipo]
    if filtro_prio != "Todos":
        tickets = [t for t in tickets if t.get("prioridade") == filtro_prio]

    st.markdown(f"**{len(tickets)} ticket(s) encontrado(s)**")

    for t in tickets:
        tipo_emoji = "🚨" if t["tipo"] == "incidente" else "💡"
        status_lbl = STATUS_LABEL.get(t["status"], t["status"])
        prio_lbl   = PRIORIDADE_LABEL.get(t.get("prioridade","media"),"")
        data       = t["criado_em"][:10] if t.get("criado_em") else ""

        _num_adm = t.get("numero") or "—"
        with st.expander(f"#{_num_adm} {tipo_emoji} {t['titulo']} — {status_lbl} · {t['user_email']} · {data}"):
            col1, col2 = st.columns(2)
            with col1:
                st.caption(f"**Empresa ID:** {t.get('empresa_id','—')}")
                st.caption(f"**Usuário:** {t['user_email']}")
                st.caption(f"**Prioridade:** {prio_lbl}")
            with col2:
                st.caption(f"**Tipo:** {t['tipo'].capitalize()}")
                st.caption(f"**Status:** {status_lbl}")
                st.caption(f"**Ticket:** #{t.get('numero','—')}")
                st.caption(f"**ID:** `{t['id'][:8]}...`")

            st.markdown("**Descrição:**")
            st.write(t["descricao"])

            # Anexos
            anexos_salvos = t.get("anexos") or "[]"
            if isinstance(anexos_salvos, str):
                try:
                    anexos_salvos = json.loads(anexos_salvos)
                except Exception:
                    anexos_salvos = []
            if anexos_salvos:
                st.markdown("**Anexos:**")
                for anx in anexos_salvos:
                    if anx.get("conteudo"):
                        st.download_button(
                            label=f"⬇️ {anx['nome']} ({round(anx.get('tamanho',0)/1024,1)}KB)",
                            data=base64.b64decode(anx["conteudo"]),
                            file_name=anx["nome"],
                            mime=anx.get("tipo_mime","application/octet-stream"),
                            key=f"adm_anx_{t['id']}_{anx['nome']}"
                        )

            # Resposta e mudança de status
            st.markdown("---")
            with st.form(f"form_resp_{t['id']}"):
                novo_status = st.selectbox(
                    "Alterar status",
                    ["aberto","em_analise","resolvido","fechado"],
                    index=["aberto","em_analise","resolvido","fechado"].index(t["status"]),
                    format_func=lambda x: STATUS_LABEL[x],
                    key=f"sel_status_{t['id']}"
                )
                resposta = st.text_area(
                    "Resposta ao usuário",
                    value=t.get("resposta_admin","") or "",
                    height=100,
                    key=f"resp_{t['id']}"
                )
                if st.form_submit_button("💾 Salvar", use_container_width=True):
                    if _atualizar_status(t["id"], novo_status, resposta):
                        # Notificar usuário
                        try:
                            from emails import _enviar, _base
                            _enviar(
                                t["user_email"],
                                f"Atualização do seu ticket: {t['titulo']}",
                                _base(f"""
                                <h3>Seu ticket foi atualizado</h3>
                                <p><b>Status:</b> {STATUS_LABEL[novo_status]}</p>
                                <p><b>Resposta:</b> {resposta or 'Sem resposta adicional'}</p>
                                """, "Ticket atualizado")
                            )
                        except Exception:
                            pass
                        st.success("✅ Ticket atualizado!")
                        st.rerun()
