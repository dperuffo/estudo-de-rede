# Estudo de Rede — Gestão de Frotas

**Documentação Técnica e Executiva**  
Versão 5.2 · Plataforma Web · Python / Streamlit · Plotly WebGL

| Campo | Valor |
|---|---|
| Versão | 5.2 |
| Data | Maio / 2026 |
| Tecnologia | Python 3.11+ / Streamlit / Plotly / OSRM / ANP |
| Deploy | Streamlit Community Cloud |
| Repositório | [github.com/dperuffo/estudo-de-rede](https://github.com/dperuffo/estudo-de-rede) |

> 📄 **Documentação completa em PDF:** [Gestao de Frotas.pdf](https://github.com/dperuffo/estudo-de-rede/blob/master/Gestao%20de%20Frotas.pdf)

---

## Índice

1. [Visão Geral do Projeto](#01-visão-geral-do-projeto)
2. [Funcionalidades e Modos de Operação](#02-funcionalidades--modos-de-operação)
3. [Arquitetura Técnica](#03-arquitetura-técnica)
4. [Stack Tecnológico](#04-stack-tecnológico)
5. [Fontes de Dados](#05-fontes-de-dados)
6. [Módulos e Funções Principais](#06-módulos-e-funções-principais)
7. [Algoritmos e Geometria](#07-algoritmos-e-geometria)
8. [Interface e Design](#08-interface-e-design)
9. [Deploy e Configuração](#09-deploy-e-configuração)
10. [Guia do Usuário](#10-guia-do-usuário)
11. [Changelog e Roadmap](#11-changelog--roadmap)
12. [Considerações de Segurança](#12-considerações-de-segurança)

---

## 01 Visão Geral do Projeto

O **Estudo de Rede – Gestão de Frotas** é uma plataforma web interativa desenvolvida para apoiar a análise estratégica da rede de postos de abastecimento conveniados ao programa Gestão de Frotas. A ferramenta permite visualizar, filtrar e analisar postos em todo o território nacional, calcular rotas otimizadas, comparar preços de combustíveis com dados da ANP e acompanhar a **evolução histórica de preços por posto**.

**Objetivos Principais:**
- Mapear e visualizar toda a rede de postos Gestão de Frotas no Brasil
- Calcular rotas entre pontos com identificação de postos ao longo do trajeto
- Comparar preços praticados pelos postos com as médias regionais da ANP
- Analisar cobertura geográfica e identificar lacunas de atendimento
- Permitir gestão de postos cercados (concorrentes estratégicos monitorados)
- **Rastrear histórico semanal de preços e calcular score de qualidade por posto**
- Suportar a tomada de decisão comercial e operacional da equipe de frotas

---

## 02 Funcionalidades — Modos de Operação

A aplicação é organizada em modos de análise acessíveis pela barra lateral. Cada modo oferece uma perspectiva diferente sobre a rede de postos.

### Modo 1 — Por UF/Município
Filtra e visualiza postos de um estado (UF) e, opcionalmente, de um município específico. Exibe mapa interativo com todos os postos, diferenciando Gestão de Frotas, Ipiranga RodoRede, Cercados e postos ANP (overlay). Inclui tabela de preços por combustível comparando postos GF com médias da ANP para a região. Exibe **coluna de Score** (A–D) por posto e **expander de Histórico de Preços** com gráfico evolutivo.

### Modo 2 — Rota
Calcula e traça a rota entre origem e destino com até 5 paradas intermediárias. Identifica todos os postos ao longo do trajeto dentro de um raio configurável (padrão 5 km). Usa o motor OSRM com fallback para linha reta.

### Modo 3 — Busca por Posto
Busca postos por nome, CNPJ ou razão social com autocomplete em tempo real. Permite selecionar dois postos como Origem e Destino para traçar rota direta automaticamente. Exibe métricas de distância, tempo estimado e velocidade média.

### Modo 4 — Rotas Salvas
Persiste rotas calculadas nos modos anteriores em arquivo JSON local. Permite listar, restaurar e excluir rotas salvas. As rotas são armazenadas com todos os parâmetros (origem, destino, paradas, postos encontrados).

### 📊 Dashboard
Dashboard analítico com KPIs de cobertura de rede, penetração GF por estado, comparativo de preços GF vs. ANP, ranking por distribuidora e análise de tendências. Exportação de dados em CSV.

### 🧠 Inteligência de Dados *(novo em v5.2)*
Módulo dedicado à análise inteligente da rede de postos, com três funcionalidades:

**📈 Histórico de Preços por Posto**
Rastreia a evolução semanal de preços de cada posto ao longo do tempo (até 52 semanas). Os preços são registrados automaticamente sempre que uma planilha `Preço Posto.xlsx` é carregada. O usuário pode consultar o histórico de qualquer posto pelo CNPJ e visualizar gráfico interativo com linha por combustível.

**⭐ Score de Posto**
Calcula uma pontuação composta (0–100) para cada posto com base em três dimensões:
- Preço vs. média ANP da região (peso 50%)
- Serviços disponíveis — pista caminhão, ARLA 32, conveniência (peso 30%)
- Distância até o ponto de referência da frota (peso 20%)

O score gera um conceito de A (≥ 75) a D (< 35) exibido como badge colorido na tabela de postos.

**⚠️ Relatório de Alertas**
Gera relatório Excel (.xlsx) com postos cujo preço supera o limiar configurável (padrão: média ANP + R$ 0,30/L). O relatório inclui nome, CNPJ, cidade, UF, preço praticado, referência ANP, desvio em R$ e percentual, além de aba de resumo por combustível.

### Funcionalidades Transversais
- Mapa interativo Plotly WebGL (Scattermapbox) com suporte a 10.000+ marcadores
- Diferenciação visual por tipo de posto: GF (azul/estrela), RodoRede (laranja), Cercado (vermelho), ANP (cinza)
- Filtros avançados: bandeira, perfil de venda, faixa de preço, 24h, serviços
- Upload de planilhas Excel (Gestão de Frotas, Cercados, Preços por Posto)
- Aba Configurações com senha de acesso
- Ranking Top 5 postos mais baratos com estrelas douradas no mapa
- Indicador de tendência de preço ANP semana anterior (↑ ↓ ≈)
- Exportação de base consolidada em Excel (.xlsx)
- Login com autenticação OAuth2 (Google / Microsoft)
- Logs de acesso com usuário autenticado

---

## 03 Arquitetura Técnica

A aplicação adota uma arquitetura monolítica orientada a eventos, típica de aplicações Streamlit. Todo o código reside em um único arquivo Python (`estudo_de_rede.py`), com separação lógica em seções bem definidas.

| Camada | Componente | Descrição |
|---|---|---|
| Apresentação | Streamlit + CSS | Renderização de widgets, sidebar, mapa, tabelas e métricas |
| Visualização | Plotly WebGL | Mapa interativo go.Scattermapbox com múltiplas camadas (traces) |
| Roteamento | OSRM API | Cálculo de rotas reais via router.project-osrm.org com fallback linha reta |
| Geocodificação | Nominatim (OSM) | Autocomplete de endereços e busca por nome de localidade |
| Dados GF | ANP API + XLSX | Postos Gestão de Frotas carregados de planilha; ANP via API REST |
| Cache | @st.cache_data | TTL de 24h para postos/rotas, 1h para preços |
| Persistência | JSON local | Rotas em `rotas_salvas.json`; histórico de preços em `_intel_data.json` |
| Processamento | NumPy vetorizado | Cálculo de distância posto-rota em lotes (chunks) de 4000 postos |
| Paralelismo | ThreadPoolExecutor | Precarregamento paralelo de até 27 estados com max_workers=5 |
| Autenticação | OAuth2 | Login Google / Microsoft com fluxo redirect + session_state |
| Inteligência | Score + Histórico | Score composto A–D e rastreamento histórico semanal por posto |

**Fluxo de Dados:**
1. Ao iniciar, o app carrega automaticamente arquivos do repositório GitHub (GF.xlsx, Postos Cercados.xlsx, Preço Posto.xlsx) via URL raw e armazena no session_state com cache de 24h.
2. A cada carga de planilha `Preço Posto.xlsx`, os preços são registrados automaticamente no histórico (`_intel_data.json`).
3. O usuário seleciona o modo e aplica filtros (UF, município, bandeira, perfil).
4. Os dados filtrados são passados para `criar_mapa()` que constrói as camadas Plotly (traces) por tipo de posto.
5. Rotas são calculadas via OSRM e os postos próximos são filtrados com `dist_minima_rota_np()` usando álgebra vetorial NumPy.
6. Preços são cruzados com o DataFrame ANP para exibir comparativo por posto. Score calculado em tempo real por `_calcular_score_df()`.

---

## 04 Stack Tecnológico

| Tecnologia | Função |
|---|---|
| Python 3.11+ | Linguagem principal |
| Streamlit 1.x | Framework web / UI |
| Plotly / go.Figure | Visualização de mapas WebGL |
| Pandas | Manipulação de DataFrames |
| NumPy | Álgebra vetorial / geometria |
| Requests | HTTP / REST calls |
| Folium | Mapa alternativo (legado) |
| OSRM | Motor de roteamento |
| Nominatim / OSM | Geocodificação |
| openpyxl / xlrd | Leitura de planilhas Excel |
| XlsxWriter | Geração de relatórios .xlsx |
| ThreadPoolExecutor | Paralelismo de threads |
| JSON | Persistência de rotas e histórico |
| CSS3 | Estilização customizada (glassmorphism) |
| Streamlit Cloud | Plataforma de deploy |
| GitHub | Repositório e CDN de arquivos |

---

## 05 Fontes de Dados

**GF.xlsx**
Planilha principal de postos Gestão de Frotas. Contém CNPJ, razão social, endereço, coordenadas geográficas (lat/lon), perfil de venda e bandeira. Carregada automaticamente do repositório GitHub com cache de 24h.

**Postos Cercados.xlsx**
Lista de CNPJs de postos concorrentes monitorados (cercados). Usada para destacar esses postos com marcador especial (vermelho) no mapa.

**Preço Posto.xlsx**
Planilha com preços de combustíveis praticados pelos postos GF. Suporta formatos wide (um produto por coluna) e long (linhas por produto). Cruzada com médias ANP para exibir comparativo. **Ao ser carregada, registra automaticamente os preços no histórico de inteligência.**

**API ANP — Postos Revendedores**
API REST pública da Agência Nacional do Petróleo, Gás Natural e Biocombustíveis. Retorna dados de todos os postos revendedores cadastrados, incluindo razão social, CNPJ, endereço, coordenadas e bandeira.

**OSRM — Open Source Routing Machine**
Motor de roteamento open-source baseado em dados do OpenStreetMap. Endpoints públicos: router.project-osrm.org e routing.openstreetmap.de. Fallback automático entre servidores em caso de falha.

**Nominatim / OpenStreetMap**
Serviço de geocodificação open-source. Usado para autocomplete de endereços na seleção de origem/destino (Modo 2 — Rota).

**_intel_data.json** *(novo em v5.2)*
Arquivo JSON local gerado em runtime. Armazena o histórico semanal de preços por posto (CNPJ → lista de até 52 registros). Persiste entre sessões e serve como base para os módulos de Histórico, Score e Alertas.

---

## 06 Módulos e Funções Principais

### Carregamento de Dados

| Função | Descrição |
|---|---|
| `_auto_carregar_pro_frotas_repo()` | Carrega GF.xlsx do GitHub automaticamente com cache 24h |
| `_auto_carregar_cercados_repo()` | Carrega Postos Cercados.xlsx com cache 24h |
| `_auto_carregar_precos_postos_repo()` | Carrega Preço Posto.xlsx com cache 1h |
| `buscar_postos(uf)` | Busca postos ANP por UF via REST API com cache 24h |
| `buscar_posto_por_cnpj(cnpj)` | Busca posto específico por CNPJ com cache 24h |
| `_precarregar_estados_paralelo()` | Precarrega todos os 27 estados em paralelo (ThreadPoolExecutor) |

### Processamento de Planilhas

| Função | Descrição |
|---|---|
| `_processar_bytes_pro_frotas(nome, bytes)` | Parse do XLSX GF: detecta colunas CNPJ/lat/lon automaticamente |
| `_processar_bytes_cercados(nome, bytes)` | Parse da lista de cercados com normalização de CNPJ |
| `_processar_bytes_precos_postos(nome, bytes)` | Parse de preços: suporta formato wide e long |
| `_processar_bytes_anp_postos(nome, bytes)` | Parse do arquivo de postos ANP para overlay |

### Mapa e Visualização

| Função | Descrição |
|---|---|
| `criar_mapa(df, coords_rota, ...)` | Constrói go.Figure com traces Scattermapbox por tipo de posto |
| `_renderizar_mapa(fig, height, key)` | Renderiza o mapa Plotly no Streamlit com ajuste de altura |
| `_marcador_pf(lat, lon, popup, tooltip)` | Cria marcador estrela (GF) com badge e popup detalhado |
| `_marcador_rodo_rede(lat, lon, ...)` | Cria marcador Ipiranga RodoRede com ícone especial |
| `_marcador_cercado(lat, lon, ...)` | Cria marcador circular vermelho para postos cercados |

### Roteamento e Geometria

| Função | Descrição |
|---|---|
| `calcular_rota(lat1, lon1, lat2, lon2, waypoints)` | Calcula rota OSRM com fallback linha reta |
| `dist_minima_rota_np(lats, lons, coords_rota)` | Distância mínima de cada posto à polyline (NumPy vetorizado) |
| `_haversine(lat1, lon1, lat2, lon2)` | Fórmula de Haversine — distância geodésica em metros |
| `ufs_ao_longo_rota(coords_rota)` | Detecta UFs atravessadas pela rota usando bounding boxes |

### Busca e Autocomplete

| Função | Descrição |
|---|---|
| `buscar_posto_por_texto(texto, max_results)` | Busca postos GF por nome/CNPJ com correspondência fuzzy |
| `sugestoes_nominatim(texto)` | Autocomplete de endereços via Nominatim/OSM |
| `campo_autocomplete(titulo, placeholder, ...)` | Widget Streamlit de busca interativa com seleção por clique |

### Preços e ANP

| Função | Descrição |
|---|---|
| `_anp_processar_arquivo(buf)` | Processa arquivo XLSX ANP: detecta abas e colunas automaticamente |
| `_anp_extrair_precos(sheets, uf, municipio)` | Extrai preços médios ANP por UF e/ou município |
| `_calcular_comparativo_pf_anp(df_pp, ...)` | Calcula desvio de preço GF vs. média ANP por combustível |
| `_anp_preco_ponto(sheets, label, combustivel_pk)` | Preço ANP para localização específica (UF ou município) |

### 🧠 Inteligência de Dados *(novo em v5.2)*

| Função | Descrição |
|---|---|
| `_intel_load()` | Carrega `_intel_data.json` com cache de sessão (`_intel_loaded`) |
| `_intel_save(data)` | Persiste dicionário de inteligência em JSON; invalida cache de sessão |
| `_hist_record_pp_df(pp_df)` | Registra preços da planilha normalizada no histórico; retorna nº de registros salvos |
| `_hist_get_posto(cnpj, combustivel)` | Retorna lista de registros históricos de um posto (opcionalmente filtrado por combustível) |
| `_hist_chart_posto(cnpj, nome, combustivel)` | Retorna figura Plotly com evolução de preço; eixo X categórico (sem timestamp), legenda abaixo |
| `_calcular_score_posto(row, preco_ref_anp, lat_ref, lon_ref, ...)` | Calcula score 0–100 e conceito A–D para um único posto |
| `_calcular_score_df(df, preco_ref_anp, lat_ref, lon_ref)` | Aplica score a todo o DataFrame de postos; insere coluna `⭐ Score` |
| `_score_badge_html(score, grade, tooltip, size)` | Gera HTML do badge colorido de score para exibição inline |
| `_gerar_relatorio_alertas_xlsx(df_pp, limiar, semana)` | Gera bytes de relatório Excel com postos acima do limiar de preço |

### Autenticação

| Função | Descrição |
|---|---|
| `_auth_login_page()` | Renderiza tela de login glassmorphism com gradiente animado |
| `_auth_check_session()` | Verifica sessão ativa; redireciona para login se expirada |
| `_auth_oauth_callback()` | Processa callback OAuth2 (Google / Microsoft) |

---

## 07 Algoritmos e Geometria

### Distância Posto → Rota (NumPy Vetorizado)

O algoritmo central de filtragem de postos ao longo de uma rota usa projeção geométrica de ponto em segmento de reta aplicada a todos os postos simultaneamente usando operações matriciais NumPy. Para evitar estouro de memória (limite de 1 GB no Streamlit Cloud), os postos são processados em lotes (chunks) de 4.000, consumindo ~28 MB por lote. A rota é amostrada para 150 pontos (precisão de ±50 m) antes do cálculo.

### Score Composto de Posto (v5.2)

```
score_final = 0.50 × score_preco + 0.30 × score_servicos + 0.20 × score_distancia
```

- **score_preco**: 100 × (1 − (preco − preco_min) / (preco_max − preco_min)), invertido — menor preço = maior score
- **score_servicos**: proporção de serviços disponíveis (pista caminhão, ARLA 32, conveniência) × 100
- **score_distancia**: 100 × (1 − (dist_km / dist_max)), invertido — menor distância = maior score

Conceitos: A ≥ 75 · B ≥ 55 · C ≥ 35 · D < 35

### Roteamento OSRM com Fallback

O cálculo de rotas usa dois servidores OSRM públicos em sequência. Se ambos falharem (timeout 8s, 2 tentativas), o sistema usa linha reta geodésica via Haversine como fallback. A resposta OSRM inclui polyline codificada que é decodificada para lista de [lat, lon].

### Cache em Múltiplos Níveis

| Dado | TTL | Decorator |
|---|---|---|
| Postos por UF (ANP) | 24 horas | `@st.cache_data(ttl=86400)` |
| Gestão de Frotas XLSX | 24 horas | `@st.cache_data(ttl=86400)` |
| Preços por Posto XLSX | 1 hora | `@st.cache_data(ttl=3600)` |
| Sugestões Nominatim | 1 hora | `@st.cache_data(ttl=3600)` |
| Inteligência (`_intel_data`) | Sessão | `session_state["_intel_loaded"]` |
| Logo / imagens (base64) | Sessão | `@st.cache_data` (sem TTL) |

---

## 08 Interface e Design

A interface combina os componentes nativos do Streamlit com CSS customizado extensivo injetado via `st.markdown(unsafe_allow_html=True)`. O design segue a identidade visual Gestão de Frotas (azul `#0D47A1` + laranja `#E65100`).

| Elemento | Descrição |
|---|---|
| **Tela de login** | Glassmorphism — gradiente animado escuro, card com `backdrop-filter: blur(24px)`, botões OAuth Google/Microsoft |
| **Barra lateral (Sidebar)** | Banner de imagem (Designer.jpg) com gradiente na base; menu de navegação com botões primário/secundário; filtros contextuais |
| **Topbar customizado** | Faixa azul com logo à esquerda e título à direita, substituindo o header padrão do Streamlit |
| **Mapa interativo** | Plotly Scattermapbox WebGL — suporta 10.000+ pontos com zoom, hover e click; base map Carto Positron |
| **Marcadores diferenciados** | Estrela azul (GF) · RodoRede Ipiranga · Cercado · ANP overlay · Origem/Destino |
| **Score badges** | Badges coloridos A/B/C/D inline na tabela de postos (verde/azul/amarelo/vermelho) |
| **Gráfico de histórico** | Plotly com eixo X categórico (datas DD/MM/YYYY), legenda abaixo do gráfico, sem sobreposição |
| **Bottom nav mobile** | Barra inferior fixa com ícones para os 7 modos — UF, Rota, Busca, Salvas, Dashboard, Intel, Config |
| **Responsividade** | Layout wide + CSS responsivo com media queries para mobile; sidebar recolhível |

---

## 09 Deploy e Configuração

### Estrutura de Arquivos

```
estudo-de-rede/
├── estudo_de_rede.py          # Código principal (único arquivo Python)
├── GF.xlsx                    # Planilha de postos GF (não versionada)
├── Postos Cercados.xlsx       # Lista de cercados
├── Preço Posto.xlsx           # Preços por posto
├── Designer.jpg               # Banner do sidebar
├── rotas_salvas.json          # Rotas persistidas (gerado em runtime)
├── _intel_data.json           # Histórico de preços e dados de inteligência (gerado em runtime)
├── tour_done.flag             # Flag de onboarding concluído (gerado em runtime)
├── .streamlit/
│   └── config.toml            # toolbarMode=viewer, tema, porta
└── requirements.txt           # Dependências Python
```

### Variáveis de Ambiente e Configuração

O arquivo `.streamlit/config.toml` define: `toolbarMode = "viewer"` (oculta toolbar em produção), tema com cores primárias Gestão de Frotas e porta padrão 8501. A senha de acesso ao painel de Configurações está hardcoded — recomenda-se migrar para variável de ambiente em ambiente produtivo.

### Dependências (requirements.txt)

```
streamlit          # Framework web principal
plotly             # Visualização de mapas WebGL
pandas             # Manipulação de dados tabulares
numpy              # Álgebra vetorial / geometria
requests           # Chamadas HTTP à API ANP e OSRM
folium             # Mapa alternativo (legado)
openpyxl           # Leitura/escrita de arquivos .xlsx
xlrd               # Leitura de arquivos .xls (legado)
xlsxwriter         # Geração de relatórios Excel formatados
reportlab          # Geração de relatórios PDF
```

---

## 10 Guia do Usuário

### Como usar o Modo 1 — Por UF/Município
1. Na barra lateral, selecione o Estado (UF) no seletor.
2. Opcionalmente, escolha um Município para refinar a busca.
3. O mapa é atualizado automaticamente com todos os postos da região.
4. Use os filtros de Bandeira e Perfil de Venda para refinar.
5. Role a página para ver a tabela de preços — a coluna **⭐ Score** indica a qualidade do posto.
6. Expanda **📈 Histórico de preços** para visualizar a evolução de qualquer posto.

### Como usar o Modo 2 — Rota
1. No campo Origem, digite um endereço e selecione a sugestão.
2. No campo Destino, faça o mesmo.
3. Opcionalmente, adicione até 5 paradas intermediárias.
4. Clique em **Calcular Rota** para traçar a rota.
5. O mapa mostra a rota e todos os postos GF no raio configurado.

### Como usar o Modo 3 — Busca por Posto
1. Digite o nome, CNPJ ou razão social no campo de busca.
2. Selecione o posto desejado na lista de sugestões.
3. Para traçar rota, clique **Definir como Origem** no primeiro posto.
4. Busque o segundo posto e clique **Definir como Destino**.
5. A rota é calculada automaticamente assim que O/D estiverem definidos.

### Como usar o módulo 🧠 Inteligência *(v5.2)*

**Histórico de Preços:**
1. Carregue a planilha `Preço Posto.xlsx` nas Configurações (os preços são registrados automaticamente).
2. Acesse **🧠 Inteligência** no menu lateral.
3. Na aba **📈 Histórico**, selecione o posto no seletor (exibe Razão Social, CNPJ e Cidade/UF).
4. O gráfico mostra a evolução de preços semana a semana por combustível.

**Score de Posto:**
1. Na aba **⭐ Score**, informe o preço de referência ANP e as coordenadas da frota.
2. O sistema calcula o score composto (A–D) para todos os postos com preço registrado.
3. O score também aparece diretamente na tabela do Modo 1.

**Relatório de Alertas:**
1. Na aba **⚠️ Relatório de Alertas**, configure o limiar de preço (ex: ANP + R$ 0,30).
2. Clique em **Gerar Relatório**.
3. Faça o download do arquivo Excel com todos os postos fora do padrão.

### Como carregar postos ANP
1. Acesse **Configurações** na barra lateral (senha protegida).
2. Vá para a aba **Postos ANP**.
3. Acesse gov.br/anp e baixe o arquivo XLSX de postos revendedores.
4. Faça upload do arquivo na aba.
5. Os postos ANP aparecem como overlay cinza no mapa de qualquer modo.

### Como salvar e restaurar rotas
1. Calcule uma rota em qualquer modo.
2. Clique em **Salvar Rota** no painel de resultados.
3. Acesse o **Modo 4 — Rotas Salvas** para ver todas as rotas.
4. Clique em **Restaurar** para recarregar uma rota salva.

---

## 11 Changelog & Roadmap

### Histórico de Versões

| Versão | Data | Mudanças |
|---|---|---|
| **v5.2** | **Mai 2026** | **Módulo 🧠 Inteligência de Dados** (histórico semanal, score A–D, relatório de alertas) · Login glassmorphism com gradiente animado · OAuth2 Google/Microsoft · Score na tabela Modo 1 · Selectbox com Razão Social + CNPJ + Cidade/UF · Gráfico histórico sem sobreposição de título · Logs de acesso com usuário autenticado |
| v5.1 | Mai 2026 | Postos ANP movidos para aba Configurações · Auto-cálculo de rota no Modo Busca · Métricas st.metric() de distância/tempo · Rebrand para Gestão de Frotas · Designer.jpg como banner |
| v5.0 | Abr 2026 | Modo Busca com seleção interativa O/D (pills + cards) · Validação de mesmo ponto O/D · Remoção de auto-fetch ANP falho |
| v4.x | Mar 2026 | Modo 4 — Rotas Salvas com persistência JSON · Preload paralelo de 27 estados · Exportação Excel da base consolidada · Filtro por Perfil de Venda |
| v3.x | Fev 2026 | Mapa WebGL Plotly (migração de Folium) · NumPy vetorizado para distância posto-rota · Marcadores diferenciados · Comparativo de preços GF vs. ANP |
| v2.x | Jan 2026 | Modo Rota com OSRM · Paradas intermediárias · Postos Cercados · Autocomplete Nominatim |
| v1.0 | Dez 2025 | MVP — Modo Por UF com mapa Folium · Carregamento da planilha GF · Busca básica de postos ANP por UF |

### Roadmap — Próximas Evoluções

- Integração direta com API ANP de preços (quando estável) sem necessidade de upload
- Agendamento automático de relatórios de alertas (envio por e-mail)
- Exportação de rotas em formato GPX (compatível com GPS e Google Maps)
- App mobile (PWA) com geolocalização do dispositivo como Origem automática
- Dashboard comparativo: dois estados ou duas regiões lado a lado
- Score preditivo com modelo de regressão (tendência de preço)

---

## 12 Considerações de Segurança

| Aspecto | Status |
|---|---|
| **Autenticação** | Login OAuth2 (Google / Microsoft) implementado em v5.2 · Sessão controlada por session_state com expiração |
| **Proteção de Configurações** | Painel Configurações protegido por senha · Recomenda-se migrar para `st.secrets` em produção |
| **Dados Sensíveis** | Planilhas GF (GF.xlsx, Cercados, Preços) não versionadas no repositório · Carregadas via URL raw de repositório privado |
| **Ocultação de Interface** | Elementos Streamlit (menu hambúrguer, botão Deploy, footer) ocultados via CSS |
| **Rate Limiting** | Chamadas às APIs externas (OSRM, Nominatim, ANP) incluem retry com backoff e timeouts |
| **Dados de Inteligência** | `_intel_data.json` armazena apenas dados agregados de preço — sem dados pessoais ou sensíveis |

### Recomendações para Produção
- Migrar senha de Configurações para `st.secrets` ou variável de ambiente
- Mover arquivos XLSX sensíveis para storage privado (S3, Azure Blob) com SAS token
- Configurar rate limiting próprio para chamadas à ANP e OSRM
- Habilitar HTTPS com certificado próprio em deploy dedicado

---

*Estudo de Rede – Gestão de Frotas | v5.2 | Maio 2026*  
*Desenvolvido com Python, Streamlit, Plotly e OSRM · Deploy: Streamlit Community Cloud*
