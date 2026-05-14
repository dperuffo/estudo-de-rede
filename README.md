Estudo de Rede
Gestão_Frotas
Documentação Técnica e Executiva | Technical & Executive Documentation
Versão 5.1 • Plataforma Web • Python / Streamlit • Plotly WebGL
Aplicação Estudo de Rede – Gestão_Frotas
Versão 5.1
Data Maio / 2026
Tecnologia Python 3.11+ / Streamlit / Plotly / OSRM / ANP
Deploy Streamlit Community Cloud
Repositório GitHub (estudo-de-rede)
Estudo de Rede – Gestão_Frotas | Documentação Técnica e Executiva | Página 1
00 Índice | Table of Contents
01 Visão Geral do Projeto 02 Funcionalidades 03 Arquitetura Técnica 04 Stack Tecnológico 05 Fontes de Dados 06 Módulos e Funções Principais 07 Algoritmos e Geometria 08 Interface e Design 09 Deploy e Configuração 10 Guia do Usuário 11 Evolução e Histórico 12 Considerações de Segurança Project Overview
Features & Modes
Technical Architecture
Technology Stack
Data Sources
Core Modules & Functions
Algorithms & Geometry
UI / Design
Deployment & Configuration
User Guide
Changelog & Roadmap
Security Considerations
Estudo de Rede – Gestão_Frotas | Documentação Técnica e Executiva | Página 2
01 Visão Geral do Projeto
Project Overview
O Estudo de Rede – Gestão_Frotas é uma plataforma web interativa desenvolvida para apoiar a análise
estratégica da rede de postos de abastecimento conveniados ao programa Gestão_Frotas. A ferramenta permite
visualizar, filtrar e analisar postos em todo o território nacional, calcular rotas otimizadas e comparar preços de
combustíveis com dados da ANP (Agência Nacional do Petróleo).
The Fuel Station Network Analysis Tool (Estudo de Rede) is an interactive web platform designed to support strategic
analysis of the fuel station network affiliated with Gestão_Frotas Gestão_Frotas program. It enables visualization, filtering and
analysis of stations nationwide, optimized route calculation, and fuel price comparison against ANP data.
Objetivos Principais
Main Objectives
• Mapear e visualizar toda a rede de postos Gestão_Frotas no Brasil
• Calcular rotas entre pontos com identificação de postos ao longo do trajeto
• Comparar preços praticados pelos postos com as médias regionais da ANP
• Analisar cobertura geográfica e identificar lacunas de atendimento
• Permitir gestão de postos cercados (concorrentes estratégicos monitorados)
• Suportar a tomada de decisão comercial e operacional da equipe de frotas
Contexto de Negócio
Business Context
O programa Gestão_Frotas oferece condições diferenciadas de abastecimento a empresas com frotas de veículos.
O sistema permite aos gestores do programa analisar a distribuição geográfica dos postos credenciados, verificar
preços praticados, planejar expansão da rede e monitorar a concorrência — tudo em uma única interface visual.
Gestão_Frotas offers specialized fueling conditions to corporate fleets. The system allows program managers to analyze the
geographic distribution of accredited stations, verify fuel prices, plan network expansion, and monitor competition — all within
a single visual interface.
Estudo de Rede – Gestão_Frotas | Documentação Técnica e Executiva | Página 3
02 Funcionalidades — Modos de Operação
Features & Operating Modes
A aplicação é organizada em quatro modos principais de análise, acessíveis pela barra lateral (sidebar). Cada
modo oferece uma perspectiva diferente sobre a rede de postos.
The application is organized in four main analysis modes, accessible via the sidebar. Each mode provides a different
perspective on the station network.
■ Modo 1 — Por UF/Município
Filtra e visualiza postos de um estado (UF) e, opcionalmente, de um município específico. Exibe mapa interativo com
todos os postos, diferenciando Gestão_Frotas, Ipiranga RodoRede, Cercados e postos ANP (overlay). Inclui tabela de
preços por combustível comparando postos GF com médias da ANP para a região.
Filter and visualize stations by state (UF) and optionally by city. Interactive map shows all stations differentiating GF,
RodoRede, Surrounded (Cercados) and ANP stations. Includes fuel price table comparing GF stations vs. ANP regional
averages.
■■ Modo 2 — Rota
Calcula e traça a rota entre origem e destino com até 5 paradas intermediárias. Identifica todos os postos ao longo do
trajeto dentro de um raio configurável (padrão 5 km). Usa o motor OSRM (Open Source Routing Machine) com
fallback para linha reta.
Calculates and traces a route between origin and destination with up to 5 intermediate stops. Identifies all stations along the
route within a configurable radius (default 5 km). Uses OSRM engine with straight-line fallback.
■ Modo 3 — Busca por Posto
Busca postos por nome, CNPJ ou razão social com autocomplete em tempo real. Permite selecionar dois postos
como Origem e Destino para traçar rota direta automaticamente. Exibe métricas de distância, tempo estimado e
velocidade média.
Searches stations by name, CNPJ or company name with real-time autocomplete. Allows selecting two stations as Origin and
Destination for automatic direct route tracing. Displays distance, estimated time and average speed metrics.
■ Modo 4 — Rotas Salvas
Persiste rotas calculadas nos modos anteriores em arquivo JSON local. Permite listar, restaurar e excluir rotas salvas.
As rotas são armazenadas com todos os parâmetros (origem, destino, paradas, postos encontrados).
Persists calculated routes from previous modes in a local JSON file. Allows listing, restoring and deleting saved routes.
Routes are stored with all parameters (origin, destination, stops, found stations).
Funcionalidades Transversais
Cross-cutting Features
• Mapa interativo Plotly WebGL (Scattermapbox) com suporte a 10.000+ marcadores
• Diferenciação visual por tipo de posto: GF (azul/estrela), RodoRede (laranja), Cercado (vermelho), ANP (cinza)
• Filtros por Bandeira (distribuidora) e Perfil de Venda
• Upload de planilhas Excel (Gestão_Frotas, Cercados, Preços por Posto)
• Aba ■■ Configurações com senha de acesso (proteção de dados sensíveis)
• Carregamento antecipado (preload) de todos os estados com cache de 24h
• Exportação de base consolidada em Excel (.xlsx)
• Overlay de postos ANP carregados via upload manual
Estudo de Rede – Gestão_Frotas | Documentação Técnica e Executiva | Página 4
• Comparativo de preços GF vs. médias ANP por UF e município
Estudo de Rede – Gestão_Frotas | Documentação Técnica e Executiva | Página 5
03 Arquitetura Técnica
Technical Architecture
A aplicação adota uma arquitetura monolítica orientada a eventos, típica de aplicações Streamlit. Todo o código
reside em um único arquivo Python (`estudo_de_rede.py`), com separação lógica em seções bem definidas.
The application follows an event-driven monolithic architecture typical of Streamlit apps. All code resides in a single Python
file with logical separation into well-defined sections.
Camada Componente Descrição
Apresentação Streamlit + CSS Renderização de widgets, sidebar, mapa, tabelas e métricas
Visualização Plotly WebGL Mapa interativo go.Scattermapbox com múltiplas camadas
(traces)
Roteamento OSRM API Cálculo de rotas reais via router.project-osrm.org com fallback
linha reta
Geocodificação Nominatim (OSM) Autocomplete de endereços e busca por nome de localidade
Dados GF ANP API + XLSX Postos Gestão_Frotas carregados de planilha; ANP via API
REST
Cache @st.cache_data TTL de 24h para postos/rotas, 1h para preços
Persistência JSON local Rotas salvas em rotas_salvas.json no diretório do projeto
Processamento NumPy vetorizado Cálculo de distância posto-rota em lotes (chunks) de 4000
postos
Paralelismo ThreadPoolExecutor Precarregamento paralelo de até 27 estados com
max_workers=5
Fluxo de Dados
Data Flow
1. Ao iniciar, o app carrega automaticamente arquivos do repositório GitHub (GF.xlsx, Postos Cercados.xlsx, Preço
Posto.xlsx) via URL raw e armazena no session_state com cache de 24h.
2. O usuário seleciona o modo e aplica filtros (UF, município, bandeira, perfil).
3. Os dados filtrados são passados para criar_mapa() que constrói as camadas Plotly (traces) por tipo de posto.
4. Rotas são calculadas via OSRM e os postos próximos são filtrados com dist_minima_rota_np() usando álgebra
vetorial NumPy.
5. Preços são cruzados com o DataFrame ANP para exibir comparativo por posto.
1. On startup, the app auto-loads files from GitHub repository via raw URL with 24h cache. 2. User selects mode and applies
filters. 3. Filtered data is passed to criar_mapa() which builds Plotly traces per station type. 4. Routes calculated via OSRM;
nearby stations filtered with NumPy-vectorized dist_minima_rota_np(). 5. Prices cross-referenced with ANP DataFrame.
Estudo de Rede – Gestão_Frotas | Documentação Técnica e Executiva | Página 6
04 Stack Tecnológico
Technology Stack
Tecnologia / Technology PT — Função Python 3.11+ Linguagem principal Streamlit 1.x Framework web / UI Plotly / go.Figure Visualização de mapas WebGL Pandas Manipulação de DataFrames NumPy Álgebra vetorial / geometria Requests HTTP / REST calls Folium Mapa alternativo (legado) OSRM Motor de roteamento Nominatim / OSM Geocodificação openpyxl / xlrd Leitura de planilhas Excel ThreadPoolExecutor Paralelismo de threads JSON Persistência de rotas CSS3 Estilização customizada Streamlit Cloud Plataforma de deploy GitHub Repositório e CDN de arquivos EN — Purpose
Core programming language
Web framework / UI layer
WebGL map visualization
DataFrame manipulation
Vector algebra / geometry
HTTP / REST calls
Alternative map (legacy)
Routing engine
Geocoding
Excel spreadsheet reading
Thread-level parallelism
Route persistence
Custom styling
Deployment platform
Repository and file CDN
Estudo de Rede – Gestão_Frotas | Documentação Técnica e Executiva | Página 7
05 Fontes de Dados
Data Sources
GF.xlsx
Planilha principal de postos Gestão_Frotas. Contém CNPJ, razão social, endereço, coordenadas geográficas (lat/lon),
perfil de venda e bandeira. Carregada automaticamente do repositório GitHub com cache de 24h.
Main GF station spreadsheet. Contains CNPJ, company name, address, geo-coordinates, sales profile and brand.
Auto-loaded from GitHub with 24h cache.
Postos Cercados.xlsx
Lista de CNPJs de postos concorrentes monitorados (cercados). Usada para destacar esses postos com marcador
especial (vermelho) no mapa.
List of monitored competitor station CNPJs. Used to highlight these stations with a special marker (red) on the map.
Preço Posto.xlsx
Planilha com preços de combustíveis praticados pelos postos GF. Suporta formatos wide (um produto por coluna) e
long (linhas por produto). Cruzada com médias ANP para exibir comparativo.
Spreadsheet with fuel prices for GF stations. Supports wide (one product per column) and long (rows per product) formats.
Cross-referenced with ANP averages.
API ANP — Postos Revendedores
API REST pública da Agência Nacional do Petróleo, Gás Natural e Biocombustíveis. Retorna dados de todos os
postos revendedores cadastrados, incluindo razão social, CNPJ, endereço, coordenadas e bandeira. Endpoint:
dados.gov.br/api/postos.
ANP (Brazilian Petroleum Agency) public REST API. Returns all registered reseller stations data: name, CNPJ, address,
coordinates and brand.
OSRM — Open Source Routing Machine
Motor de roteamento open-source baseado em dados do OpenStreetMap. Endpoints públicos: router.project-osrm.org
e routing.openstreetmap.de. Fallback automático entre servidores em caso de falha.
Open-source routing engine based on OpenStreetMap data. Public endpoints with automatic fallback between servers.
Nominatim / OpenStreetMap
Serviço de geocodificação open-source. Usado para autocomplete de endereços na seleção de origem/destino (Modo
2 — Rota).
Open-source geocoding service. Used for address autocomplete in origin/destination selection (Mode 2 — Route).
Estudo de Rede – Gestão_Frotas | Documentação Técnica e Executiva | Página 8
06 Módulos e Funções Principais
Core Modules & Functions
Carregamento de Dados | Data Loading
Função / Function Descrição / Description
_auto_carregar_pro_frotas_repo() Carrega GF.xlsx do GitHub automaticamente com cache 24h
_auto_carregar_cercados_repo() Carrega Postos Cercados.xlsx com cache 24h
_auto_carregar_precos_postos_repo() Carrega Preço Posto.xlsx com cache 1h
buscar_postos(uf) Busca postos ANP por UF via REST API com cache 24h
buscar_posto_por_cnpj(cnpj) Busca posto específico por CNPJ com cache 24h
_precarregar_estados_paralelo() Precarrega todos os 27 estados em paralelo
(ThreadPoolExecutor)
Processamento de Planilhas | Spreadsheet Processing
Função / Function Descrição / Description
_processar_bytes_pro_frotas(nome, bytes) Parse do XLSX GF: detecta colunas CNPJ/lat/lon
automaticamente
_processar_bytes_cercados(nome, bytes) Parse da lista de cercados com normalização de CNPJ
_processar_bytes_precos_postos(nome,
bytes)
Parse de preços: suporta formato wide e long
_processar_bytes_anp_postos(nome, bytes) Parse do arquivo de postos ANP para overlay
Mapa e Visualização | Map & Visualization
Função / Function Descrição / Description
criar_mapa(df, coords_rota, ...) Constrói go.Figure com traces Scattermapbox por tipo de posto
_renderizar_mapa(fig, height, key) Renderiza o mapa Plotly no Streamlit com ajuste de altura
_marcador_pf(lat, lon, popup, tooltip) Cria marcador estrela (GF) com badge e popup detalhado
_marcador_rodo_rede(lat, lon, ...) Cria marcador Ipiranga RodoRede com ícone especial
_marcador_cercado(lat, lon, ...) Cria marcador circular vermelho para postos cercados
Estudo de Rede – Gestão_Frotas | Documentação Técnica e Executiva | Página 9
Roteamento e Geometria | Routing & Geometry
Função / Function Descrição / Description
calcular_rota(lat1, lon1, lat2, lon2,
waypoints)
Calcula rota OSRM com fallback linha reta; retorna coords,
dist_km, dur_min, linha_reta
dist_minima_rota_np(lats, lons,
coords_rota)
Distância mínima de cada posto à polyline (NumPy vetorizado,
chunks de 4000)
_haversine(lat1, lon1, lat2, lon2) Fórmula de Haversine — distância geodésica em metros
ufs_ao_longo_rota(coords_rota) Detecta UFs atravessadas pela rota usando bounding boxes
_downsample(coords, max_pts) Reduz polyline a max_pts pontos preservando forma geral
Busca e Autocomplete | Search & Autocomplete
Função / Function Descrição / Description
buscar_posto_por_texto(texto,
max_results)
Busca postos GF por nome/CNPJ com correspondência fuzzy
sugestoes_nominatim(texto) Autocomplete de endereços via Nominatim/OSM
campo_autocomplete(titulo, placeholder,
Widget Streamlit de busca interativa com seleção por clique
...)
_campo_rota_compacto(...) Campo compacto de origem/destino para Modo 2 (Rota)
Preços e ANP | Prices & ANP
Função / Function Descrição / Description
_anp_processar_arquivo(buf) Processa arquivo XLSX ANP: detecta abas e colunas
automaticamente
_anp_extrair_precos(sheets, uf,
municipio)
Extrai preços médios ANP por UF e/ou município
_calcular_comparativo_pf_anp(df_pp, ...) Calcula desvio de preço GF vs. média ANP por combustível
_anp_preco_ponto(sheets, label,
combustivel_pk)
Preço ANP para localização específica (UF ou município)
Estudo de Rede – Gestão_Frotas | Documentação Técnica e Executiva | Página 10
07 Algoritmos e Geometria
Algorithms & Geometry
Distância Posto → Rota (NumPy Vetorizado)
Station-to-Route Distance (NumPy Vectorized)
O algoritmo central de filtragem de postos ao longo de uma rota usa projeção geométrica de ponto em segmento
de reta aplicada a todos os postos simultaneamente usando operações matriciais NumPy.
Para evitar estouro de memória (limite de 1 GB no Streamlit Cloud), os postos são processados em lotes (chunks)
de 4.000, consumindo ~28 MB por lote. A rota é amostrada para 150 pontos (precisão de ±50 m) antes do cálculo.
The core station-filtering algorithm uses geometric point-to-segment projection applied to all stations simultaneously via
NumPy matrix operations. To avoid memory overflow (1 GB Streamlit Cloud limit), stations are processed in chunks of 4,000
(~28 MB/chunk). The route is downsampled to 150 points (±50 m precision) before calculation.
Roteamento OSRM com Fallback
OSRM Routing with Fallback
O cálculo de rotas usa dois servidores OSRM públicos em sequência. Se ambos falharem (timeout 8s, 2 tentativas), o
sistema usa linha reta geodésica via Haversine como fallback. A resposta OSRM inclui polyline codificada que é
decodificada para lista de [lat, lon].
Route calculation tries two public OSRM servers sequentially. On both failing (8s timeout, 2 retries), system falls back to
geodesic straight line via Haversine. OSRM response includes encoded polyline decoded to [lat, lon] list.
Cache em Múltiplos Níveis
Multi-Level Caching
Dado TTL Decorator
Postos por UF (ANP) 24 horas @st.cache_data(ttl=86400)
Gestão_Frotas XLSX 24 horas @st.cache_data(ttl=86400)
Preços por Posto XLSX 1 hora @st.cache_data(ttl=3600)
Sugestões Nominatim 1 hora @st.cache_data(ttl=3600)
Logo / imagens (base64) Sessão @st.cache_data (sem TTL)
Estudo de Rede – Gestão_Frotas | Documentação Técnica e Executiva | Página 11
08 Interface e Design
UI & Design
A interface combina os componentes nativos do Streamlit com CSS customizado extensivo injetado via
st.markdown(unsafe_allow_html=True). O design segue a identidade visual Gestão_Frotas (azul #0D47A1 + laranja
#E65100).
The interface combines native Streamlit components with extensive custom CSS injected via st.markdown. Design follows
Gestão_Frotas visual identity (blue #0D47A1 + orange #E65100).
Barra lateral (Sidebar) Banner de imagem (Designer.jpg) com gradiente na base; menu de seleção de
modo; filtros contextuais por modo; expander ■■ Configurações com proteção por
senha
Topbar customizado Faixa azul com logo à esquerda e título à direita, substituindo o header padrão do
Streamlit
Cards de progresso O/D Indicadores visuais de Origem e Destino sempre visíveis no Modo Busca, com
botões de limpar
Mapa interativo Plotly Scattermapbox WebGL — suporta 10.000+ pontos com zoom, hover e click;
base map Carto Positron
Marcadores diferenciados ■ Estrela azul (GF) • ■ RodoRede Ipiranga • ■ Cercado • ■ ANP overlay • ■/■
Origem/Destino
Métricas de rota st.metric() para Distância (km), Tempo estimado e Velocidade média, exibidos
após traçado de rota
Pills de progresso Indicadores de passo-a-passo (1→2) para seleção interativa de O/D no Modo
Busca
Responsividade Layout wide + CSS responsivo com media queries para mobile; sidebar recolhível
Ocultação de elementos CSS remove menu hambúrguer, footer, botão Deploy, badge Streamlit e links
externos
Estudo de Rede – Gestão_Frotas | Documentação Técnica e Executiva | Página 12
09 Deploy e Configuração
Deployment & Configuration
Estrutura de Arquivos
File Structure
estudo-de-rede/
■■■ estudo_de_rede.py # Código principal (único arquivo Python)
■■■ GF.xlsx # Planilha de postos GF (não versionada)
■■■ Postos Cercados.xlsx # Lista de cercados
■■■ Preço Posto.xlsx # Preços por posto
■■■ Designer.jpg # Banner do sidebar
■■■ rotas_salvas.json # Rotas persistidas (gerado em runtime)
■■■ .streamlit/
■ ■■■ config.toml # toolbarMode=viewer, tema, porta
■■■ requirements.txt # Dependências Python
Variáveis de Ambiente e Configuração
Environment Variables & Config
O arquivo .streamlit/config.toml define: toolbarMode = "viewer" (oculta toolbar em produção), tema com cores
primárias Gestão_Frotas e porta padrão 8501. A senha de acesso ao painel de Configurações está hardcoded como
"***********" — recomenda-se migrar para variável de ambiente em ambiente produtivo.
config.toml sets toolbarMode=viewer, Gestão_Frotas color theme and default port. Configuration panel password is
hardcoded — recommended to migrate to environment variable for production.
Dependências (requirements.txt)
Dependencies
streamlit Framework web principal
plotly Visualização de mapas WebGL
pandas Manipulação de dados tabulares
numpy Álgebra vetorial / geometria
requests Chamadas HTTP à API ANP e OSRM
folium Mapa alternativo (legado — mantido por compatibilidade)
openpyxl Leitura de arquivos .xlsx
xlrd Leitura de arquivos .xls (legado)
Estudo de Rede – Gestão_Frotas | Documentação Técnica e Executiva | Página 13
10 Guia do Usuário
User Guide
Como usar o Modo 1 — Por UF/Município
1. Na barra lateral, selecione o Estado (UF) no seletor.
2. Opcionalmente, escolha um Município para refinar a busca.
3. O mapa é atualizado automaticamente com todos os postos da região.
4. Use os filtros de Bandeira e Perfil de Venda para refinar.
5. Role a página para ver a tabela de preços por combustível.
Como usar o Modo 2 — Rota
1. No campo Origem, digite um endereço e selecione a sugestão.
2. No campo Destino, faça o mesmo.
3. Opcionalmente, adicione até 5 paradas intermediárias.
4. Clique em ■■ Calcular Rota para traçar a rota.
5. O mapa mostra a rota e todos os postos GF no raio configurado.
Como usar o Modo 3 — Busca por Posto
1. Digite o nome, CNPJ ou razão social no campo de busca.
2. Selecione o posto desejado na lista de sugestões.
3. Para traçar rota, clique ■ Definir como Origem no primeiro posto.
4. Busque o segundo posto e clique ■ Definir como Destino.
5. A rota é calculada automaticamente assim que O/D estiverem definidos.
Como carregar postos ANP
1. Acesse ■■ Configurações na barra lateral (senha: ***********).
2. Vá para a aba ■ Postos ANP.
3. Acesse gov.br/anp e baixe o arquivo XLSX de postos revendedores.
4. Faça upload do arquivo na aba.
5. Os postos ANP aparecem como overlay cinza no mapa de qualquer modo.
Como salvar e restaurar rotas
1. Calcule uma rota em qualquer modo.
2. Clique em ■ Salvar Rota no painel de resultados.
3. Acesse o Modo 4 — Rotas Salvas para ver todas as rotas.
4. Clique em ■ Restaurar para recarregar uma rota salva.
5. Clique em ■■ Excluir para remover uma rota.
Estudo de Rede – Gestão_Frotas | Documentação Técnica e Executiva | Página 14
11 Changelog & Roadmap
Evolução e Histórico de Versões
Versão Data Mudanças / Changes
v5.1 Maio 2026 Postos ANP movidos para aba Configurações • Auto-cálculo de rota no Modo Busca •
Métricas st.metric() de distância/tempo • Rebrand para Gestão_Frotas • PF→GF em
labels • RodoRede→Ipiranga RodoRede • Designer.jpg como banner • Upload ANP
manual com guia 3 passos
v5.0 Abr 2026 Modo Busca com seleção interativa O/D (pills + cards) • Validação de mesmo ponto
O/D • Botão UF substituindo Estado • Remoção de auto-fetch ANP falho
v4.x Mar 2026 Modo 4 — Rotas Salvas com persistência JSON • Preload paralelo de 27 estados •
Exportação Excel da base consolidada • Filtro por Perfil de Venda
v3.x Fev 2026 Mapa WebGL Plotly (migração de Folium) • NumPy vetorizado para distância
posto-rota • Marcadores diferenciados por tipo de posto • Comparativo de preços GF
vs. ANP
v2.x Jan 2026 Modo Rota com OSRM • Paradas intermediárias • Postos Cercados • Autocomplete
Nominatim
v1.0 Dez 2025 MVP — Modo Por UF com mapa Folium • Carregamento da planilha GF • Busca básica
de postos ANP por UF
Roadmap — Próximas Evoluções
Roadmap — Upcoming Enhancements
• Autenticação por usuário (multi-tenant) com níveis de acesso diferenciados
• Dashboard analítico com KPIs de cobertura geográfica e penetração GF por estado
• Integração direta com API ANP de preços (quando estável) sem necessidade de upload
• Notificações automáticas de postos GF com preço acima da média ANP
• Exportação de rotas em formato GPX (compatível com GPS e Google Maps)
• Modo comparativo: dois estados ou duas regiões lado a lado
• App mobile (PWA) com geolocalização do dispositivo como Origem automática
Estudo de Rede – Gestão_Frotas | Documentação Técnica e Executiva | Página 15
12 Considerações de Segurança
Security Considerations
Por se tratar de um protótipo em fase de validação, o sistema adota medidas básicas de segurança adequadas ao
contexto:
As a prototype in validation phase, the system adopts basic security measures appropriate to the context:
Proteção de Configurações O painel ■■ Configurações é protegido por senha (***********). Recomenda-se migrar
para variável de ambiente (st.secrets) antes de ir para produção.
Dados Sensíveis As planilhas GF (GF.xlsx, Cercados, Preços) não são versionadas no repositório. São
carregadas via URL raw do GitHub em repositório privado.
Ocultação de Interface Elementos Streamlit como menu hambúrguer, botão Deploy e footer são ocultados
via CSS para evitar que usuários finais acessem configurações avançadas da
plataforma.
Rate Limiting As chamadas às APIs externas (OSRM, Nominatim, ANP) incluem retry com backoff
e timeouts configurados para evitar bloqueios e sobrecarga dos servidores públicos.
Sem Autenticação por
Usuário
Atualmente não há sistema de login individual. Toda a aplicação é acessível
publicamente via URL do Streamlit Cloud. Implementar auth é item do roadmap.
Recomendações para Produção
Production Recommendations
• Migrar senha de Configurações para st.secrets ou variável de ambiente
• Implementar autenticação OAuth2 (Google/Microsoft) para controle de acesso
• Mover arquivos XLSX sensíveis para storage privado (S3, Azure Blob) com SAS token
• Adicionar logging de uso (quem acessa, quais modos, quais UFs)
• Configurar rate limiting próprio para chamadas à ANP e OSRM
• Habilitar HTTPS com certificado próprio em deploy dedicado (não Streamlit Cloud)
Estudo de Rede – Gestão_Frotas | Documentação Técnica e Executiva | v5.1 | Maio 2026
Desenvolvido com Python, Streamlit, Plotly e OSRM • Deploy: Streamlit Community Cloud
