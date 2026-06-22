"""
FNI Gestão de Frotas — Sistema de Tradução PT/EN
Estratégia: monkey-patch das funções do Streamlit para traduzir automaticamente
"""

# ══════════════════════════════════════════════════════════════════
# DICIONÁRIO DE TRADUÇÕES
# ══════════════════════════════════════════════════════════════════
TRANSLATIONS = {
    # ── Navegação principal ────────────────────────────────────────
    "📈 Dashboard":                         {"en": "📈 Dashboard"},
    "📍 Por UF/Município":                  {"en": "📍 By State/City"},
    "📍 Consulta por UF/Município":         {"en": "📍 Search by State/City"},
    "🗺️ Consulta por Rota":                {"en": "🗺️ Route Search"},
    "🔍 Consulta por Posto":               {"en": "🔍 Station Search"},
    "👥 Análise de Cliente":                {"en": "👥 Client Analysis"},
    "👥 Análise do Cliente":                {"en": "👥 Client Analysis"},
    "📑 Relatórios":                        {"en": "📑 Reports"},
    "🤖 Recomendador IA":                   {"en": "🤖 AI Recommender"},
    "💰 Painel Financeiro":                 {"en": "💰 Financial Panel"},
    "🔧 Manutenção de Frota":              {"en": "🔧 Fleet Maintenance"},
    "🔧 Manutenção":                        {"en": "🔧 Maintenance"},
    "💼 Centros de Custo":                  {"en": "💼 Cost Centers"},
    "🤝 Acordos de Preço":                  {"en": "🤝 Price Agreements"},
    "⚡ API & Integrações":                 {"en": "⚡ API & Integrations"},
    "⚙️ Configurações":                    {"en": "⚙️ Settings"},
    "🚀 Planos & Assinatura":              {"en": "🚀 Plans & Subscription"},
    "📚 Documentação":                      {"en": "📚 Documentation"},
    "☀️ Comece seu dia!":                   {"en": "☀️ Start your day!"},
    "🎯 Recomendador IA":                   {"en": "🎯 AI Recommender"},
    # ── Abas comuns ────────────────────────────────────────────────
    "🗺️ Mapa Interativo":                  {"en": "🗺️ Interactive Map"},
    "📋 Dados Tabulares":                   {"en": "📋 Tabular Data"},
    "📊 Análise por Bandeira":              {"en": "📊 Brand Analysis"},
    "🏆 Melhores Scores":                   {"en": "🏆 Best Scores"},
    "🗺️ Mapa da Rota":                     {"en": "🗺️ Route Map"},
    "⛽ Abastecimento":                     {"en": "⛽ Fueling"},
    "💰 Custo da Viagem":                   {"en": "💰 Trip Cost"},
    "📋 Resumo":                            {"en": "📋 Summary"},
    "📈 Histórico de Preços":               {"en": "📈 Price History"},
    "⭐ Score de Postos":                   {"en": "⭐ Station Scores"},
    "⚠️ Relatório de Alertas":             {"en": "⚠️ Alert Report"},
    "🗺️ Frota":                            {"en": "🗺️ Fleet"},
    "📥 Importar":                          {"en": "📥 Import"},
    "⛽ Histórico":                         {"en": "⛽ History"},
    "📊 Consumo":                           {"en": "📊 Consumption"},
    "⚠️ Alertas":                           {"en": "⚠️ Alerts"},
    "📈 Projeção de Volume":                {"en": "📈 Volume Forecast"},
    "➕ Novo Acordo":                       {"en": "➕ New Agreement"},
    "📋 Acordos Vigentes":                  {"en": "📋 Active Agreements"},
    "📁 Importar Planilha":                 {"en": "📁 Import Spreadsheet"},
    "📋 Centros cadastrados":               {"en": "📋 Registered Centers"},
    "➕ Novo centro":                       {"en": "➕ New Center"},
    "🚛 Alocar veículos":                   {"en": "🚛 Allocate Vehicles"},
    "👥 Perfis & Permissões":              {"en": "👥 Profiles & Permissions"},
    "🏢 Empresas & Usuários":              {"en": "🏢 Companies & Users"},
    "🔑 Controle de Acesso":               {"en": "🔑 Access Control"},
    "🌐 Domínios Corporativos":            {"en": "🌐 Corporate Domains"},
    "📋 Logs de Atividade":                {"en": "📋 Activity Logs"},
    "🛡️ Matriz de Permissões":            {"en": "🛡️ Permission Matrix"},
    "📊 Relatório Executivo":              {"en": "📊 Executive Report"},
    "🌎 Oportunidades Comerciais":         {"en": "🌎 Commercial Opportunities"},
    "⭐ Performance por Posto":            {"en": "⭐ Performance by Station"},
    "🎯 Score × Performance":              {"en": "🎯 Score × Performance"},
    "🔍 Anomalias":                        {"en": "🔍 Anomalies"},
    "🚘 Frota FIPE":                       {"en": "🚘 Fleet FIPE"},
    "🗂️ Relatórios Personalizados":       {"en": "🗂️ Custom Reports"},
    # ── Botões comuns ──────────────────────────────────────────────
    "← Voltar":                            {"en": "← Back"},
    "→ Configurações":                     {"en": "→ Settings"},
    "💾 Salvar":                           {"en": "💾 Save"},
    "🔄 Atualizar":                        {"en": "🔄 Update"},
    "🗑️ Excluir":                         {"en": "🗑️ Delete"},
    "✅ Confirmar":                         {"en": "✅ Confirm"},
    "❌ Cancelar":                          {"en": "❌ Cancel"},
    "🔍 Buscar":                           {"en": "🔍 Search"},
    "📥 Importar":                          {"en": "📥 Import"},
    "📤 Exportar":                          {"en": "📤 Export"},
    "⬇️ Baixar":                           {"en": "⬇️ Download"},
    "➕ Adicionar":                         {"en": "➕ Add"},
    "✏️ Editar":                           {"en": "✏️ Edit"},
    "🔄 Sincronizar":                       {"en": "🔄 Sync"},
    "▶ Reiniciar auto-sync":               {"en": "▶ Restart auto-sync"},
    "↩ Sair / trocar usuário":             {"en": "↩ Logout / switch user"},
    "⎋  Sair para logar com outro usuário":{"en": "⎋  Logout to use another account"},
    "💾 Salvar perfil":                    {"en": "💾 Save profile"},
    "🗑️ Excluir este perfil":            {"en": "🗑️ Delete this profile"},
    "🗑️ Remover Preços ANP":            {"en": "🗑️ Remove ANP Prices"},
    "🔄 Verificar novamente após criar as tabelas": {"en": "🔄 Check again after creating tables"},
    "🚀 Planos & Assinatura":              {"en": "🚀 Plans & Subscription"},
    "👁️ Preview Onboarding":             {"en": "👁️ Preview Onboarding"},
    "⭐ Avaliar plataforma":               {"en": "⭐ Rate platform"},
    "🎫 Suporte & Melhorias":             {"en": "🎫 Support & Improvements"},
    "🔒 Privacidade & LGPD":             {"en": "🔒 Privacy & LGPD"},
    "💾 Salvar no banco":                 {"en": "💾 Save to database"},
    "🔎 Consultar":                        {"en": "🔎 Search"},
    "📊 Gerar Relatório":                  {"en": "📊 Generate Report"},
    "🗺️ Ver no Mapa":                    {"en": "🗺️ View on Map"},
    "📄 Gerar PDF":                        {"en": "📄 Generate PDF"},
    "📍 Gerar Rota":                       {"en": "📍 Generate Route"},
    "🧮 Calcular":                         {"en": "🧮 Calculate"},
    "Calcular Rota":                       {"en": "Calculate Route"},
    "Exportar GPX":                        {"en": "Export GPX"},
    "Card PNG":                            {"en": "Card PNG"},
    "Gerar PDF":                           {"en": "Generate PDF"},
    "Salvar":                              {"en": "Save"},
    # ── Labels de formulários ──────────────────────────────────────
    "Período":                             {"en": "Period"},
    "Período de análise":                  {"en": "Analysis period"},
    "Filtrar combustível":                 {"en": "Filter fuel"},
    "Combustível":                         {"en": "Fuel"},
    "Estado (UF)":                         {"en": "State (UF)"},
    "Município":                           {"en": "City"},
    "Placa":                               {"en": "License plate"},
    "Motorista":                           {"en": "Driver"},
    "Posto":                               {"en": "Station"},
    "Cliente":                             {"en": "Client"},
    "Empresa":                             {"en": "Company"},
    "Perfil padrão":                       {"en": "Default profile"},
    "🏢 Centro de custo *":               {"en": "🏢 Cost center *"},
    "Remover veículo":                     {"en": "Remove vehicle"},
    "Mês":                                 {"en": "Month"},
    "Cliente Gestão de Frotas":           {"en": "Fleet Management Client"},
    "Fonte dos dados:":                    {"en": "Data source:"},
    "Visão":                               {"en": "View"},
    "Filtrar:":                            {"en": "Filter:"},
    "Comparar por:":                       {"en": "Compare by:"},
    "Selecionar cliente":                  {"en": "Select client"},
    "Período":                             {"en": "Period"},
    "Nome para salvar":                    {"en": "Name to save"},
    # ── Métricas ───────────────────────────────────────────────────
    "💰 Custo total":                      {"en": "💰 Total cost"},
    "⛽ Combustíveis":                     {"en": "⛽ Fuels"},
    "🔧 Manutenções":                      {"en": "🔧 Maintenances"},
    "🚗 Veículos":                         {"en": "🚗 Vehicles"},
    "📊 Abastecimentos":                   {"en": "📊 Fuelings"},
    "⛽ Litros":                           {"en": "⛽ Liters"},
    "💰 Total":                            {"en": "💰 Total"},

    # ── Botões adicionais ──────────────────────────────────────────
    "🔄 Recarregar do banco":              {"en": "🔄 Reload from database"},
    "📸 Exportar mapa":                    {"en": "📸 Export map"},
    "↩ Sair / trocar usuário":             {"en": "↩ Logout / switch user"},
    "Fechar preview":                      {"en": "Close preview"},
    "✕ Limpar":                            {"en": "✕ Clear"},
    "Adicionar":                           {"en": "Add"},
    "➕ Adicionar Parada":                 {"en": "➕ Add Stop"},
    "🔄 Sincronizar agora":                {"en": "🔄 Sync now"},
    "🗑️ Limpar cache":                    {"en": "🗑️ Clear cache"},
    "▶ Reiniciar auto-sync":               {"en": "▶ Restart auto-sync"},
    "↩ Sair para logar com outro usuário": {"en": "↩ Logout to use another account"},
    "⭐ Avaliar plataforma":               {"en": "⭐ Rate platform"},
    "🎫 Suporte & Melhorias":             {"en": "🎫 Support & Improvements"},
    "🔒 Privacidade & LGPD":             {"en": "🔒 Privacy & LGPD"},
    "👁️ Preview Onboarding":             {"en": "👁️ Preview Onboarding"},
    "💾 Salvar perfil":                   {"en": "💾 Save profile"},
    "🗑️ Excluir este perfil":            {"en": "🗑️ Delete this profile"},
    "🗑️ Remover Preços ANP":            {"en": "🗑️ Remove ANP Prices"},
    "🔄 Verificar novamente após criar as tabelas": {"en": "🔄 Check again after creating tables"},
    # ── Selectbox labels ───────────────────────────────────────────
    "Período":                             {"en": "Period"},
    "Combustível":                         {"en": "Fuel"},
    "Filtrar combustível":                 {"en": "Filter fuel"},
    "Estado (UF)":                         {"en": "State (UF)"},
    "Município":                           {"en": "City"},
    "Placa":                               {"en": "License plate"},
    "Motorista":                           {"en": "Driver"},
    "Cliente":                             {"en": "Client"},
    "Período de análise":                  {"en": "Analysis period"},
    "Selecionar cliente":                  {"en": "Select client"},
    # ── Métricas ───────────────────────────────────────────────────
    "💰 Custo total":                      {"en": "💰 Total cost"},
    "⛽ Combustíveis":                     {"en": "⛽ Fuels"},
    "🔧 Manutenções":                      {"en": "🔧 Maintenances"},
    "🚗 Veículos":                         {"en": "🚗 Vehicles"},
    "📊 Abastecimentos":                   {"en": "📊 Fuelings"},
    "⛽ Litros":                           {"en": "⛽ Liters"},
    "💰 Total":                            {"en": "💰 Total"},
    # ── Radio labels ───────────────────────────────────────────────
    "Fonte dos dados:":                    {"en": "Data source:"},
    "Visão":                               {"en": "View"},
    "Filtrar:":                            {"en": "Filter:"},
    "Comparar por:":                       {"en": "Compare by:"},

    # ── Mensagens comuns ───────────────────────────────────────────
    "Carregando...":                       {"en": "Loading..."},
    "Sem dados":                           {"en": "No data"},
    "Nenhum resultado encontrado":         {"en": "No results found"},
    "Erro ao carregar dados":              {"en": "Error loading data"},
    "Salvo com sucesso!":                  {"en": "Saved successfully!"},
    "Excluído com sucesso!":               {"en": "Deleted successfully!"},
    # ── Estratégia de otimização ────────────────────────────────────
    "💰 Economia":                         {"en": "💰 Economy"},
    "⚖️ Equilíbrio":                      {"en": "⚖️ Balance"},
    "⭐ Qualidade":                        {"en": "⭐ Quality"},
    "🔴 Mínimas Paradas":                  {"en": "🔴 Minimum Stops"},
}

def get_lang():
    """Retorna o idioma atual da sessão."""
    try:
        import streamlit as st
        return st.session_state.get("_lang", "pt")
    except Exception:
        return "pt"

def t(text: str) -> str:
    """
    Traduz um texto para o idioma atual.
    Se não houver tradução, retorna o texto original.
    """
    lang = get_lang()
    if lang == "pt":
        return text
    entry = TRANSLATIONS.get(text)
    if entry:
        return entry.get(lang, text)
    return text

def set_lang(lang: str):
    """Define o idioma da sessão e salva no Supabase."""
    try:
        import streamlit as st
        st.session_state["_lang"] = lang
        # Salva no perfil do usuário no Supabase
        try:
            from supabase import create_client
            import os
            _url = os.environ.get("SUPABASE_URL","")
            _key = os.environ.get("SUPABASE_KEY","")
            _email = st.session_state.get("_auth_email","")
            if _url and _key and _email:
                db = create_client(_url, _key)
                db.table("user_preferences").upsert({"email": _email, "lang": lang, "updated_at": "now()"}, on_conflict="email").execute()
        except Exception:
            pass
    except Exception:
        pass

def render_lang_selector():
    """
    Renderiza o seletor de idioma com bandeiras.
    Usar na sidebar da aplicação.
    """
    try:
        import streamlit as st
        lang = get_lang()
        st.markdown(
            "<div style='display:flex;gap:6px;align-items:center;"
            "padding:8px 0;border-top:1px solid rgba(255,255,255,0.08);"
            "margin-top:8px'>",
            unsafe_allow_html=True
        )
        col_pt, col_en = st.columns(2)
        with col_pt:
            if st.button(
                "🇧🇷 PT",
                use_container_width=True,
                type="primary" if lang == "pt" else "secondary",
                key="lang_btn_pt"
            ):
                set_lang("pt")
                st.rerun()
        with col_en:
            if st.button(
                "🇺🇸 EN",
                use_container_width=True,
                type="primary" if lang == "en" else "secondary",
                key="lang_btn_en"
            ):
                set_lang("en")
                st.rerun()
        st.markdown("</div>", unsafe_allow_html=True)
    except Exception:
        pass

def load_user_lang():
    """
    Carrega o idioma salvo do perfil do usuário no Supabase.
    Chamar no startup da sessão.
    """
    try:
        import streamlit as st
        if "_lang" in st.session_state:
            return
        from supabase import create_client
        import os
        _url = os.environ.get("SUPABASE_URL","")
        _key = os.environ.get("SUPABASE_KEY","")
        _email = st.session_state.get("_auth_email","")
        if _url and _key and _email:
            db = create_client(_url, _key)
            r = db.table("user_preferences").select("lang").eq("email", _email).limit(1).execute()
            if r.data and r.data[0].get("lang"):
                st.session_state["_lang"] = r.data[0]["lang"]
                return
        st.session_state["_lang"] = "pt"
    except Exception:
        st.session_state["_lang"] = "pt"
