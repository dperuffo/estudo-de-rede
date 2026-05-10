# ═══════════════════════════════════════════════════════════════════
#  Estudo de Rede – Pró-Frotas
#  Versão 5.0  |  NumPy vetorizado + cache 24h + pré-carga de estados
# ═══════════════════════════════════════════════════════════════════

import base64
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
import hashlib
import io
import math
import os
import re
import time
import unicodedata
import requests
import numpy as np
import pandas as pd
import streamlit as st
import folium
from folium.plugins import MarkerCluster
from streamlit_folium import st_folium

# Diretório onde este script está — usado para localizar arquivos do repo
_DIR = os.path.dirname(os.path.abspath(__file__))

# ─── Logo Pró-Frotas ───────────────────────────────────────────────
# Aceita qualquer variação de nome/extensão que possa estar no repositório
for _logo_nome in ["Logo_profrotas.jpg", "logo_profrotas.jpg",
                   "Logo_profrotas.png", "logo_profrotas.png"]:
    _logo_candidato = os.path.join(_DIR, _logo_nome)
    if os.path.exists(_logo_candidato):
        _LOGO_PATH = _logo_candidato
        break
else:
    _LOGO_PATH = ""

if os.path.exists(_LOGO_PATH):
    with open(_LOGO_PATH, "rb") as _f:
        _logo_bytes = _f.read()
    _logo_mime = "image/jpeg" if _LOGO_PATH.lower().endswith(".jpg") else "image/png"
    _LOGO_B64 = base64.b64encode(_logo_bytes).decode()
    # Topbar azul: mix-blend-mode screen funde o fundo azul da logo com o gradiente,
    # deixando apenas o texto branco e o ícone laranja visíveis
    _LOGO_TOPBAR  = (
        f'<img src="data:{_logo_mime};base64,{_LOGO_B64}" '
        f'style="height:46px;object-fit:contain;mix-blend-mode:screen;'
        f'filter:brightness(1.15) contrast(1.05)">'
    )
    # Sidebar: logo natural sobre fundo branco (sem blend-mode)
    _LOGO_SIDEBAR = (
        f'<img src="data:{_logo_mime};base64,{_LOGO_B64}" '
        f'style="height:78px;object-fit:contain;display:block;margin:0 auto">'
    )
    _LOGO_PAGE_ICON = _LOGO_PATH
else:
    _LOGO_B64       = None
    _LOGO_TOPBAR    = '<span style="font-size:36px">⛽</span>'
    _LOGO_SIDEBAR   = '<span style="font-size:32px">⛽</span>'
    _LOGO_PAGE_ICON = "⛽"

# ─── Configuração da página ────────────────────────────────────────
st.set_page_config(
    page_title="Estudo de Rede – Pró-Frotas",
    page_icon=_LOGO_PAGE_ICON,
    layout="wide",
    initial_sidebar_state="expanded",  # sempre aberta
)

# ─── CSS Global + Responsivo ───────────────────────────────────────
st.markdown("""
<style>
/* ══ OCULTAR ELEMENTOS STREAMLIT ══════════════════════════════════ */
/* toolbarMode="viewer" no config.toml oculta a toolbar no servidor.
   CSS abaixo cobre elementos residuais.                              */

/* Menu hambúrguer */
#MainMenu                                         { display: none !important; }
/* Rodapé */
footer                                            { display: none !important; }
/* Botão Deploy */
.stDeployButton                                   { display: none !important; }
/* Manage app / Community Cloud */
[data-testid="manage-app-button"]                 { display: none !important; }
/* Status Running/Error */
[data-testid="stStatusWidget"]                    { display: none !important; }
/* Badge Streamlit */
[class*="viewerBadge"]                            { display: none !important; }
[class*="ViewerBadge"]                            { display: none !important; }
/* Decoração colorida do topo */
[data-testid="stDecoration"]                      { display: none !important; }
/* Links externos */
a[href*="streamlit.io"]                           { display: none !important; }
a[href*="github.com"]                             { display: none !important; }
/* Ícone e imagens do GitHub */
svg[data-icon="mark-github"]                      { display: none !important; }
img[alt*="github" i]                              { display: none !important; }
img[src*="github" i]                              { display: none !important; }

/* ── Seta recolher/expandir sidebar — OCULTA (menu sempre aberto) ── */
[data-testid="collapsedControl"]                  { display: none !important; }
[data-testid="stSidebarCollapseButton"]           { display: none !important; }
[data-testid="stSidebarNavCollapseButton"]        { display: none !important; }
button[data-testid="baseButton-headerNoPadding"]  { display: none !important; }

/* Header transparente */
header[data-testid="stHeader"] {
    background: transparent !important;
    box-shadow: none !important;
}

/* ══ LAYOUT GERAL ══════════════════════════════════════════════════ */
.main .block-container {
    padding: 0.25rem 1rem 0.5rem !important;
    max-width: 100% !important;
}

/* ══ TOPBAR ════════════════════════════════════════════════════════ */
.topbar {
    background: linear-gradient(135deg, #0d1b4b 0%, #1565c0 60%, #0288d1 100%);
    color: white;
    padding: 9px 24px;
    border-radius: 0 0 10px 10px;
    margin-bottom: 10px;
    display: flex;
    align-items: center;
    gap: 14px;
    box-shadow: 0 4px 12px rgba(0,0,0,0.25);
    flex-wrap: wrap;
}
.topbar-title { font-size: 22px; font-weight: 800; letter-spacing: 0.4px; }
.topbar-sub   { font-size: 11px; opacity: 0.75; margin-top: 2px; }
.topbar-badge {
    margin-left: auto;
    background: rgba(255,255,255,0.15);
    border: 1px solid rgba(255,255,255,0.3);
    border-radius: 20px;
    padding: 4px 12px;
    font-size: 12px;
    font-weight: 600;
    white-space: nowrap;
}

/* ══ SIDEBAR ═══════════════════════════════════════════════════════ */
section[data-testid="stSidebar"] > div:first-child {
    background: linear-gradient(180deg, #e6edf8 0%, #f2f6fc 60%, #f7f9fd 100%);
    border-right: 1px solid #c2d3e8;
}
section[data-testid="stSidebar"] .stButton > button {
    border-radius: 8px;
    font-weight: 600;
    min-height: 44px;
}

/* ══ MÉTRICAS ══════════════════════════════════════════════════════ */
[data-testid="stMetric"] {
    background: white;
    border-radius: 10px;
    padding: 14px 18px !important;
    box-shadow: 0 2px 6px rgba(0,0,0,0.08);
    border-left: 4px solid #1565c0;
}
[data-testid="stMetricLabel"] { font-size: 12px !important; color: #555 !important; }
[data-testid="stMetricValue"] { font-size: 24px !important; font-weight: 700 !important; }

/* ══ TABS ══════════════════════════════════════════════════════════ */
button[data-baseweb="tab"] { font-weight: 600; font-size: 13px; }

/* ══ EXPANDER ══════════════════════════════════════════════════════ */
details summary { font-weight: 700; font-size: 14px; }

/* ══ ALERTS / SEPARADORES ══════════════════════════════════════════ */
.stAlert { border-radius: 8px !important; }
hr { margin: 10px 0 !important; border-color: #c8d8e8 !important; }

/* ══ BOTÕES ════════════════════════════════════════════════════════ */
.stButton > button {
    min-height: 44px;
    border-radius: 8px;
    font-weight: 600;
}
.stButton > button[kind="primary"] {
    background: linear-gradient(135deg, #1565c0, #0d47a1);
    border: none;
    font-size: 14px;
    padding: 10px 0;
}
.stButton > button[kind="primary"]:hover {
    background: linear-gradient(135deg, #1976d2, #1565c0);
    box-shadow: 0 4px 12px rgba(21,101,192,0.4);
}

/* ══ LOADING / ANIMAÇÕES ═══════════════════════════════════════════ */
/* Fade-in suave quando o iframe do mapa aparece */
iframe {
    animation: mapFadeIn 0.45s ease-in;
}
@keyframes mapFadeIn {
    from { opacity: 0; transform: translateY(6px); }
    to   { opacity: 1; transform: translateY(0);   }
}
/* Spinner do Streamlit — aumenta levemente e centraliza */
[data-testid="stSpinner"] {
    padding: 18px 0 !important;
    text-align: center !important;
}
[data-testid="stSpinner"] > div {
    justify-content: center !important;
    font-size: 15px !important;
    color: #1565c0 !important;
    font-weight: 600 !important;
    gap: 10px !important;
}
/* Barra de progresso — cor da marca */
[data-testid="stProgress"] > div > div {
    background: linear-gradient(90deg, #0d1b4b, #1565c0, #0288d1) !important;
    border-radius: 4px !important;
}

/* ══ EMPTY STATE ═══════════════════════════════════════════════════ */
.empty-state {
    text-align: center;
    padding: 60px 40px;
    color: #90a4b0;
}
.empty-state-icon  { font-size: 64px; margin-bottom: 16px; }
.empty-state-title { font-size: 20px; font-weight: 700; color: #546e7a; margin-bottom: 8px; }
.empty-state-desc  { font-size: 14px; line-height: 1.6; }

/* ══ TABELA SCROLL HORIZONTAL ══════════════════════════════════════ */
[data-testid="stDataFrame"] { overflow-x: auto !important; }

/* ══ RESPONSIVO — TABLET (≤ 1024px) ═══════════════════════════════ */
@media (max-width: 1024px) {
    .main .block-container { padding: 0.5rem 1rem 2rem !important; }
    .topbar { padding: 12px 18px; }
    .topbar-title { font-size: 18px; }
    [data-testid="stMetricValue"] { font-size: 20px !important; }
}

/* ══ RESPONSIVO — MOBILE (≤ 768px) ════════════════════════════════ */
@media (max-width: 768px) {
    /* Layout */
    .main .block-container { padding: 0.25rem 0.5rem 2rem !important; }

    /* Topbar compacto */
    .topbar {
        padding: 10px 12px;
        border-radius: 0 0 8px 8px;
        margin-bottom: 12px;
        gap: 6px;
    }
    .topbar-title { font-size: 15px; letter-spacing: 0; }
    .topbar-sub   { font-size: 9px; }
    .topbar-badge {
        margin-left: 0;
        font-size: 10px;
        padding: 3px 8px;
        width: 100%;
        text-align: center;
        box-sizing: border-box;
    }

    /* Métricas: 2 colunas no mobile */
    [data-testid="stHorizontalBlock"] { flex-wrap: wrap !important; }
    [data-testid="stHorizontalBlock"] > [data-testid="column"] {
        flex: 0 0 48% !important;
        min-width: 48% !important;
        max-width: 48% !important;
    }
    [data-testid="stMetric"] { padding: 10px 12px !important; }
    [data-testid="stMetricValue"] { font-size: 18px !important; }
    [data-testid="stMetricLabel"] { font-size: 10px !important; }

    /* Tabs menores */
    button[data-baseweb="tab"] {
        font-size: 11px !important;
        padding: 8px 6px !important;
    }

    /* Inputs — font-size 16px evita zoom automático no iOS */
    input, select, textarea {
        font-size: 16px !important;
    }
    [data-testid="stTextInput"] input  { min-height: 44px !important; }
    [data-testid="stSelectbox"] select { min-height: 44px !important; }

    /* Botões touch-friendly */
    .stButton > button { min-height: 48px !important; font-size: 14px !important; }

    /* Mapa: altura menor no mobile */
    iframe { max-height: 380px !important; }

    /* Sidebar full-width quando aberta no mobile */
    section[data-testid="stSidebar"] {
        width: 100% !important;
        min-width: 100% !important;
    }

    /* Empty state menor */
    .empty-state       { padding: 30px 16px; }
    .empty-state-icon  { font-size: 40px; }
    .empty-state-title { font-size: 16px; }
    .empty-state-desc  { font-size: 12px; }

    /* Slider touch */
    [data-testid="stSlider"] { padding: 12px 0 !important; }

    /* Sucesso / info / aviso com texto menor */
    .stAlert { font-size: 13px !important; }
}

/* ══ RESPONSIVO — SMARTPHONE PEQUENO (≤ 480px) ════════════════════ */
@media (max-width: 480px) {
    .topbar-title { font-size: 13px; }
    .topbar-sub   { display: none; }
    [data-testid="stMetricValue"] { font-size: 16px !important; }
    button[data-baseweb="tab"]    { font-size: 10px !important; }
    iframe                        { max-height: 300px !important; }
}
</style>
<script>
// Oculta elementos do GitHub/Streamlit injetados dinamicamente.
// A seta da sidebar é intencionalmente ocultada (menu sempre fixo aberto).
(function() {
    const OCULTAR = [
        'button[title*="GitHub"]',
        'button[title*="github"]',
        'a[href*="github.com"]',
        'svg[data-icon="mark-github"]',
        '[data-testid="collapsedControl"]',
        '[data-testid="stSidebarCollapseButton"]',
        'button[data-testid="baseButton-headerNoPadding"]',
        '.stDeployButton',
        '#MainMenu',
    ];
    function aplicar() {
        OCULTAR.forEach(sel => {
            document.querySelectorAll(sel).forEach(el => {
                el.style.setProperty('display', 'none', 'important');
            });
        });
    }
    aplicar();
    new MutationObserver(aplicar).observe(document.body, { childList: true, subtree: true });
})();
</script>
""", unsafe_allow_html=True)

# ─── Constantes ───────────────────────────────────────────────────
API_BASE_URL = "https://revendedoresapi.anp.gov.br"
ENDPOINT     = "/v1/combustivel"
NOMINATIM    = "https://nominatim.openstreetmap.org/search"

# Headers que simulam um navegador — evita bloqueio 403 da API ANP
HEADERS_ANP = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept":          "application/json, text/plain, */*",
    "Accept-Language": "pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7",
    "Referer":         "https://postos.anp.gov.br/",
    "Origin":          "https://postos.anp.gov.br",
}

UFS = [
    "AC","AL","AM","AP","BA","CE","DF","ES","GO","MA","MG","MS",
    "MT","PA","PB","PE","PI","PR","RJ","RN","RO","RR","RS","SC",
    "SE","SP","TO",
]

# Mapeamento UF -> nome completo (padrão ANP nas planilhas)
UF_NOME = {
    "AC":"Acre","AL":"Alagoas","AM":"Amazonas","AP":"Amapá",
    "BA":"Bahia","CE":"Ceará","DF":"Distrito Federal","ES":"Espírito Santo",
    "GO":"Goiás","MA":"Maranhão","MG":"Minas Gerais","MS":"Mato Grosso do Sul",
    "MT":"Mato Grosso","PA":"Pará","PB":"Paraíba","PE":"Pernambuco",
    "PI":"Piauí","PR":"Paraná","RJ":"Rio de Janeiro","RN":"Rio Grande do Norte",
    "RO":"Rondônia","RR":"Roraima","RS":"Rio Grande do Sul","SC":"Santa Catarina",
    "SE":"Sergipe","SP":"São Paulo","TO":"Tocantins",
}

# URL da página de levantamento de preços semanais da ANP
ANP_PRECOS_URL = (
    "https://www.gov.br/anp/pt-br/assuntos/precos-e-defesa-da-concorrencia"
    "/precos/levantamento-de-precos-de-combustiveis-ultimas-semanas-pesquisadas"
)

# Produtos-chave exibidos (ordem de exibição)
PRODUTOS_CHAVE = [
    "GASOLINA COMUM",
    "GASOLINA ADITIVADA",
    "ETANOL HIDRATADO COMBUSTÍVEL",
    "ÓLEO DIESEL",
    "ÓLEO DIESEL S10",
    "GNV",
    "GLP",
]
# Chaves já normalizadas (sem acento, uppercase) — igual ao _anp_norm()
PRODUTO_CURTO = {
    "GASOLINA COMUM":                    "⛽ Gasolina",
    "GASOLINA ADITIVADA":                "⛽ Gasolina Aditivada",
    "ETANOL HIDRATADO COMBUSTIVEL":      "🌿 Etanol",
    "ETANOL HIDRATADO":                  "🌿 Etanol",
    "OLEO DIESEL":                       "🛢️ Diesel",
    "OLEO DIESEL S10":                   "🛢️ Diesel S10",
    "GNV":                               "💨 GNV",
    "GLP":                               "🔵 GLP",
    "GAS NATURAL COMPRIMIDO":            "💨 GNV",
    "GAS LIQUEFEITO DE PETROLEO":        "🔵 GLP",
    "GAS LIQUEFEITO DO PETROLEO":        "🔵 GLP",
}

BBOX_UFS = {
    "AC": (-11.15,-73.99,-7.11,-66.63), "AL": (-10.50,-38.24,-8.81,-35.15),
    "AM": ( -9.82,-73.80, 2.25,-56.10), "AP": ( -1.24,-52.00, 4.44,-49.87),
    "BA": (-18.36,-46.62,-8.53,-37.35), "CE": ( -7.86,-41.44,-2.77,-37.25),
    "DF": (-16.06,-48.28,-15.50,-47.31),"ES": (-21.31,-41.88,-17.87,-39.69),
    "GO": (-19.49,-53.24,-12.40,-45.92),"MA": (-10.25,-48.75,-1.02,-41.81),
    "MG": (-22.92,-51.05,-14.24,-39.86),"MS": (-24.06,-58.16,-17.16,-50.92),
    "MT": (-18.05,-61.00,-7.35,-50.22), "PA": ( -9.84,-58.90, 2.59,-46.02),
    "PB": ( -8.27,-38.82,-6.03,-34.79), "PE": ( -9.49,-41.36,-7.29,-32.41),
    "PI": (-10.95,-45.99,-2.74,-40.37), "PR": (-26.72,-54.62,-22.52,-48.02),
    "RJ": (-23.37,-44.89,-20.76,-40.96),"RN": ( -6.99,-38.60,-4.83,-34.97),
    "RO": (-13.69,-66.09,-7.96,-59.77), "RR": ( -1.55,-64.82, 5.27,-58.90),
    "RS": (-33.75,-53.70,-27.10,-49.69),"SC": (-29.36,-53.84,-25.96,-48.37),
    "SE": (-11.57,-38.25,-9.52,-36.39), "SP": (-25.31,-53.11,-19.78,-44.16),
    "TO": (-13.46,-50.74,-5.18,-45.74),
}

# Paleta de fallback — usada apenas para distribuidoras não mapeadas em CORES_MARCAS.
# Cores vibrantes e distintas entre si para fácil diferenciação visual.
CORES_FALLBACK = [
    "#00ACC1","#FB8C00","#8D6E63","#546E7A","#EC407A","#66BB6A",
    "#AB47BC","#EF5350","#26A69A","#7E57C2","#D4E157","#FF7043",
    "#29B6F6","#9CCC65","#FFA726","#26C6DA","#EF9A9A","#80CBC4",
    "#CE93D8","#A5D6A7","#FFCC02","#90CAF9",
]

# ── Cores padronizadas por marca ──────────────────────────────────────────────
# Identificadas por substring no nome da distribuidora (case-insensitive).
# A ordem importa: substrings mais específicas devem vir antes das genéricas.
CORES_MARCAS = {
    # ── Grandes redes nacionais ──────────────────────────────────
    "IPIRANGA":          "#FFB300",  # amarelo âmbar — cor da marca Ipiranga
    "ULTRAPAR":          "#FFB300",  # grupo controlador da Ipiranga
    "VIBRA":             "#43A047",  # verde — cor da marca Vibra Energy
    "BR DISTRIBUIDORA":  "#43A047",  # nome comercial anterior da Vibra
    "PETROBRAS DIST":    "#43A047",  # razão social anterior da Vibra
    "RAIZEN":            "#E53935",  # vermelho — Raízen Combustíveis/Shell
    "RAÍZEN":            "#E53935",
    "SHELL":             "#E53935",  # Raízen opera sob a marca Shell no Brasil
    "BANDEIRA BRANCA":   "#7B1FA2",  # roxo — postos independentes
    "SEM BANDEIRA":      "#7B1FA2",  # variação do nome no cadastro ANP
    # ── Redes regionais e demais ─────────────────────────────────
    "ALESAT":            "#F57C00",  # laranja — Alesat Combustíveis
    "ALE COMB":          "#F57C00",  # ALE Combustíveis
    "SABBA":             "#00838F",  # teal — Sabbá (região Norte/AM)
    "SABBÁ":             "#00838F",
    "DISLUB":            "#455A64",  # cinza ardósia — Dislub Equador
    "PETRONIT":          "#37474F",  # cinza chumbo — Petronit
    "PLURAL":            "#1976D2",  # azul — Plural Distribuidora
    "REPSOL":            "#003087",  # azul escuro — Repsol Sinopec
    "TEXACO":            "#D32F2F",  # vermelho escuro — Texaco
    "NACIONAL GAS":      "#5D4037",  # marrom — Nacional Gás
    "NACIONAL GÁS":      "#5D4037",
    "COSAN":             "#F44336",  # vermelho — Cosan (holding Raízen)
    "PETRO RIO":         "#0288D1",  # azul claro — PetroRio
    "PETROIL":           "#0097A7",  # ciano — Petroil
    "COMFORGAS":         "#558B2F",  # verde musgo — Comforgas
    "TERPASTOS":         "#795548",  # marrom — Terpastos
    "GLP":               "#FDD835",  # amarelo vivo — distribuidoras de GLP
    "LIQUIGAS":          "#1565C0",  # azul — Liquigás
    "ULTRAGAZ":          "#E91E63",  # rosa — Ultragaz
    "COPAGAZ":           "#FF6F00",  # âmbar escuro — Copagaz
    "SUPERGASB":         "#6A1B9A",  # roxo escuro — Supergasbras
    "SUPERGASB":         "#6A1B9A",
    "NACIONAL":          "#4E342E",  # marrom escuro — Nacional (genérico)
}

# Cor e estilo do marcador Pró-Frotas
COR_PF_FILL  = "#1565C0"   # azul — identificação visual do credenciamento
COR_PF_BORDA = "#0D47A1"   # azul escuro


def _cor_marca(distribuidora: str) -> str:
    """Retorna a cor do pin para qualquer distribuidora.

    Ordem de resolução:
    1. Marcas conhecidas em CORES_MARCAS → cor da identidade da marca.
    2. Desconhecidas → cor determinística via MD5 do nome (sempre igual,
       independente do estado ou ordem de carregamento).
    """
    d = str(distribuidora).upper().strip()
    for marca, cor in CORES_MARCAS.items():
        if marca in d:
            return cor
    # Fallback determinístico: mesma distribuidora → mesma cor em qualquer consulta
    h = int(hashlib.md5(d.encode()).hexdigest(), 16)
    return CORES_FALLBACK[h % len(CORES_FALLBACK)]


# Limite de marcadores no mapa. Acima disso os postos são amostrados
# (Pró-Frotas têm prioridade) e o popup é simplificado.
# → evita serializar 5-6 MB de HTML para estados como SP (4 000+ postos).
MAX_MAPA_POSTOS = 1500


# ═══════════════════════════════════════════════════════════════════
#  PRÓ-FROTAS — Upload e comparação de CNPJs
# ═══════════════════════════════════════════════════════════════════

# Nome do arquivo fixo esperado na raiz do repositório
ARQUIVO_PF_REPO = "pro_frotas.xlsx"


def normalizar_cnpj(valor):
    if pd.isna(valor):
        return ""
    return "".join(c for c in str(valor) if c.isdigit())


def detectar_coluna_cnpj(df: pd.DataFrame):
    for col in df.columns:
        if "cnpj" in col.lower():
            return col
    for col in df.columns:
        amostra = df[col].dropna().astype(str).head(5)
        if amostra.apply(lambda x: len("".join(c for c in x if c.isdigit())) >= 14).any():
            return col
    return None


def _processar_bytes_pro_frotas(nome: str, conteudo: bytes):
    """
    Núcleo de leitura da planilha Pró-Frotas.
    Aceita o nome do arquivo e seus bytes brutos.
    Retorna (set_cnpjs, msg, df_preview) ou (None, msg_erro, None).
    """
    buf = io.BytesIO(conteudo)
    nome_l = nome.lower()

    if nome_l.endswith(".csv"):
        try:
            df = pd.read_csv(buf, dtype=str, encoding="utf-8")
        except UnicodeDecodeError:
            buf.seek(0)
            df = pd.read_csv(buf, dtype=str, encoding="latin-1")
    elif nome_l.endswith(".xls"):
        df = pd.read_excel(buf, dtype=str, engine="xlrd")
    else:
        df = pd.read_excel(buf, dtype=str, engine="openpyxl")

    if df.empty:
        return None, "A planilha está vazia.", None

    col = detectar_coluna_cnpj(df)
    if col is None:
        colunas = ", ".join(df.columns.tolist())
        return None, (
            f"Coluna CNPJ não encontrada. "
            f"Colunas disponíveis: **{colunas}**. "
            "Renomeie a coluna de CNPJ para 'CNPJ'."
        ), None

    cnpjs = {c for c in df[col].dropna().apply(normalizar_cnpj) if len(c) == 14}
    if not cnpjs:
        return None, "Nenhum CNPJ válido (14 dígitos) encontrado na coluna detectada.", None

    preview = df[[col]].rename(columns={col: "CNPJ (original)"}).head(10)
    return cnpjs, f"{len(cnpjs)} CNPJs carregados (coluna: **{col}**)", preview


def ler_planilha_pro_frotas(arquivo):
    """Lê UploadedFile do Streamlit. Sem @st.cache_data (upload não é cacheável)."""
    try:
        return _processar_bytes_pro_frotas(arquivo.name, arquivo.read())
    except ImportError as e:
        return None, f"Biblioteca ausente no servidor: **{e}**.", None
    except Exception as e:
        return None, f"Erro ao processar arquivo: **{type(e).__name__}** — {e}", None


@st.cache_data(show_spinner=False, ttl=86400)   # 24 horas — lê o arquivo do repo uma vez por dia
def _auto_carregar_pro_frotas_repo():
    """
    Tenta carregar automaticamente a planilha Pró-Frotas do repositório.
    Usa o diretório do script (_DIR) para localizar o arquivo com precisão
    no Streamlit Cloud, independente do diretório de trabalho atual.
    Aceita: pro_frotas.xlsx / pro_frotas.xls / pro_frotas.csv
    Retorna (set_cnpjs, msg, df_preview) ou (None, msg_erro, None).
    """
    for nome in [ARQUIVO_PF_REPO, "pro_frotas.xls", "pro_frotas.csv"]:
        caminho = os.path.join(_DIR, nome)
        if os.path.exists(caminho):
            try:
                with open(caminho, "rb") as f:
                    conteudo = f.read()
                cnpjs, msg, preview = _processar_bytes_pro_frotas(nome, conteudo)
                if cnpjs:
                    return cnpjs, msg, preview
            except Exception as e:
                return None, f"Erro ao ler {nome} do repositório: {e}", None
    return None, f"Arquivo `{ARQUIVO_PF_REPO}` não encontrado em: {_DIR}", None


def marcar_pro_frotas(df: pd.DataFrame, cnpjs_pf: set) -> pd.DataFrame:
    df = df.copy()
    if cnpjs_pf and "cnpj" in df.columns:
        df["_cnpj_norm"] = df["cnpj"].fillna("").apply(normalizar_cnpj)
        df["_pro_frotas"] = df["_cnpj_norm"].isin(cnpjs_pf)
    else:
        df["_pro_frotas"] = False
    return df


# ═══════════════════════════════════════════════════════════════════
#  AUTOCOMPLETE — Nominatim
# ═══════════════════════════════════════════════════════════════════

@st.cache_data(show_spinner=False, ttl=3600)
def sugestoes_nominatim(texto: str):
    texto = texto.strip()
    if len(texto) < 3:
        return []
    try:
        r = requests.get(NOMINATIM, params={
            "q": f"{texto}, Brasil", "format": "json", "limit": 6,
            "countrycodes": "br", "addressdetails": 1,
        }, headers={"User-Agent": "EstudoDeRedeANP/4.0"}, timeout=8)
        opcoes, vistos = [], set()
        for item in r.json():
            addr   = item.get("address", {})
            cidade = addr.get("city") or addr.get("town") or addr.get("village") \
                     or addr.get("municipality") or addr.get("county") or ""
            estado = addr.get("state", "")
            label  = f"{cidade} – {estado}" if cidade and estado else (
                estado or ", ".join(item["display_name"].split(", ")[:2]))
            if label not in vistos:
                vistos.add(label)
                opcoes.append({"label": label, "lat": float(item["lat"]), "lon": float(item["lon"])})
        return opcoes
    except Exception:
        return []


def _formatar_cnpj(cnpj_str: str) -> str:
    """Formata string de dígitos como CNPJ: XX.XXX.XXX/XXXX-XX."""
    d = "".join(c for c in str(cnpj_str) if c.isdigit())
    if len(d) == 14:
        return f"{d[:2]}.{d[2:5]}.{d[5:8]}/{d[8:12]}-{d[12:]}"
    return cnpj_str


def buscar_posto_por_texto(texto: str, max_results: int = 6) -> list:
    """
    Busca postos por razão social (parcial) ou CNPJ nos estados já em cache.
    Usa apenas dados que já estão na memória — sem chamadas extras à API ANP.
    Retorna lista de dicts: {label, lat, lon, tipo='posto'}.
    """
    texto_clean = texto.strip()
    if len(texto_clean) < 3:
        return []

    cnpj_digits = "".join(c for c in texto_clean if c.isdigit())
    # É CNPJ se a maioria dos caracteres são dígitos (ex: "12.345" ou "123456")
    is_cnpj = (
        len(cnpj_digits) >= 6
        and len(cnpj_digits) / max(len(texto_clean.replace(" ", "")), 1) > 0.65
    )

    estados = st.session_state.get("_estados_precarregados", [])
    if not estados:
        return []

    resultados = []
    for uf in estados:
        try:
            df = buscar_postos(uf=uf)   # instantâneo se estiver em cache
            if df.empty or "razaoSocial" not in df.columns:
                continue

            if is_cnpj:
                mask = df["cnpj"].fillna("").apply(
                    lambda x: cnpj_digits in "".join(c for c in str(x) if c.isdigit())
                )
            else:
                mask = df["razaoSocial"].fillna("").str.upper().str.contains(
                    texto_clean.upper(), regex=False, na=False
                )

            for _, row in df[mask].head(3).iterrows():
                nome   = str(row.get("razaoSocial", "?"))
                cidade = str(row.get("municipio", ""))
                uf_r   = str(row.get("uf", uf))
                cnpj   = _formatar_cnpj(str(row.get("cnpj", "")))
                label  = f"⛽ {nome} — {cidade}/{uf_r} | CNPJ: {cnpj}"
                resultados.append({
                    "label": label,
                    "lat":   float(row["_lat"]),
                    "lon":   float(row["_lon"]),
                    "tipo":  "posto",
                })
                if len(resultados) >= max_results:
                    break
        except Exception:
            continue
        if len(resultados) >= max_results:
            break

    return resultados


def campo_autocomplete(titulo, placeholder, key_texto, key_estado):
    """Campo inteligente que aceita 4 tipos de entrada:
    • UF/Estado  — ex: SP, RJ, MG  (2 letras → centro do estado)
    • Cidade     — ex: Ribeirao Preto  (busca no cache ANP, sem acento)
    • Razão Social — ex: Rudnick  (busca por nome do posto)
    • CNPJ       — ex: 12.345.678/0001-99  (busca por CNPJ)
    """
    fk = st.session_state.get("_form_key", 0)
    key_txt_widget = f"{key_texto}_{fk}"
    key_sel_widget = f"_sel_{key_estado}_{fk}"

    st.markdown(f"<div style='font-weight:700;font-size:13px;margin-bottom:4px'>{titulo}</div>",
                unsafe_allow_html=True)
    texto = st.text_input(titulo, placeholder=placeholder,
                          key=key_txt_widget, label_visibility="collapsed")

    ultimo = st.session_state.get(f"_{key_estado}_txt_ant", "")
    if texto != ultimo:
        st.session_state[f"_{key_estado}_txt_ant"] = texto
        if len(texto) < 2:
            st.session_state.pop(key_estado, None)

    texto_strip = texto.strip()
    texto_up    = texto_strip.upper()
    sugestoes   = []

    if len(texto_strip) >= 2:
        cnpj_digits = "".join(c for c in texto_strip if c.isdigit())
        is_cnpj = (
            len(cnpj_digits) >= 6
            and len(cnpj_digits) / max(len(texto_strip.replace(" ", "")), 1) > 0.65
        )

        # ── 1. UF/Estado (2 letras exatas) ──────────────────────────
        if texto_up in UFS:
            bbox   = BBOX_UFS.get(texto_up, (-15.8, -47.9, -15.7, -47.8))
            lat_c  = (bbox[0] + bbox[2]) / 2
            lon_c  = (bbox[1] + bbox[3]) / 2
            sugestoes = [{
                "label": f"🗺️ Estado {texto_up}",
                "lat": lat_c, "lon": lon_c, "tipo": "estado",
            }]

        # ── 2. CNPJ (maioria dígitos) ────────────────────────────────
        elif is_cnpj:
            sugestoes = buscar_posto_por_texto(texto_strip)
            if not sugestoes:
                n_est = len(st.session_state.get("_estados_precarregados", []))
                msg = ("⚠️ Base ainda carregando — tente novamente em instantes."
                       if n_est == 0 else
                       f"⚠️ CNPJ não encontrado nos {n_est} estado(s) carregado(s).")
                st.markdown(f"<small style='color:#e65100'>{msg}</small>",
                            unsafe_allow_html=True)

        # ── 3. Cidade ou Razão Social (mín. 3 letras) ───────────────
        elif len(texto_strip) >= 3:
            # Cidade: busca no cache ANP com normalização de acentos
            sug_cidades = _buscar_cidades_cache(texto_strip)
            # Fallback Nominatim se base ainda não tiver sido carregada
            if not sug_cidades:
                sug_cidades = [
                    dict(s, tipo="cidade") for s in sugestoes_nominatim(texto_strip)
                ]
            # Razão social: busca por nome do posto
            sug_postos = buscar_posto_por_texto(texto_strip)
            sugestoes  = sug_cidades[:4] + sug_postos[:4]

        else:
            st.markdown(
                "<small style='color:#888'>"
                "Digite UF (ex: SP), cidade, nome do posto ou CNPJ…"
                "</small>",
                unsafe_allow_html=True,
            )

    elif len(texto_strip) == 1:
        st.markdown(
            "<small style='color:#888'>"
            "Digite UF (ex: SP), cidade, nome do posto ou CNPJ…"
            "</small>",
            unsafe_allow_html=True,
        )

    if sugestoes:
        labels = [s["label"] for s in sugestoes]
        idx = st.selectbox("Sugestões:", range(len(labels)),
                           format_func=lambda i: labels[i], key=key_sel_widget)
        sel = sugestoes[idx]
        st.session_state[key_estado] = sel
        tipo  = sel.get("tipo", "")
        icone = {"estado": "🗺️", "cidade": "📍", "posto": "⛽"}.get(tipo, "📍")
        st.markdown(
            f"<small style='color:#1565c0'>{icone} {sel['label']}</small>",
            unsafe_allow_html=True,
        )
        return sel
    elif len(texto_strip) >= 3 and texto_up not in UFS:
        st.markdown(
            "<small style='color:#e65100'>⚠️ Nenhuma sugestão encontrada. "
            "Tente outra grafia ou verifique se a base foi carregada.</small>",
            unsafe_allow_html=True,
        )
        return st.session_state.get(key_estado)

    return st.session_state.get(key_estado)


# ═══════════════════════════════════════════════════════════════════
#  DISTÂNCIA / GEOMETRIA
# ═══════════════════════════════════════════════════════════════════

def _haversine(lat1, lon1, lat2, lon2):
    R = 6_371_000
    φ1, φ2 = math.radians(lat1), math.radians(lat2)
    dφ, dλ = math.radians(lat2-lat1), math.radians(lon2-lon1)
    a = math.sin(dφ/2)**2 + math.cos(φ1)*math.cos(φ2)*math.sin(dλ/2)**2
    return R * 2 * math.asin(math.sqrt(a))


def dist_minima_rota_np(lats_arr, lons_arr, coords_rota, chunk=4000):
    """
    Calcula distância mínima de TODOS os postos à rota (NumPy vetorizado).
    lats_arr, lons_arr : arrays 1-D com as coordenadas dos postos (M elementos)
    coords_rota        : lista de [lat, lon] do trajeto  (N pontos)
    chunk              : processa postos em lotes para limitar uso de RAM
    Retorna            : array 1-D com distância em metros para cada posto

    Limite de memória: chunk × 150 segmentos × 6 arrays × 8 bytes ≈ 28 MB/lote
    → seguro para o limite de 1 GB do Streamlit Community Cloud.
    """
    if not coords_rota:
        return np.full(len(lats_arr), np.inf)

    # Limita a rota a 150 pontos — suficiente para precisão de ±50 m
    coords_ds = _downsample(coords_rota, 150)
    rota = np.array(coords_ds, dtype=np.float64)            # (N, 2)
    lats = np.asarray(lats_arr, dtype=np.float64)           # (M,)
    lons = np.asarray(lons_arr, dtype=np.float64)           # (M,)

    # Projeção plana local (erro < 0,1 % para distâncias até 500 km)
    R       = 6_371_000.0
    lat0    = rota[0, 0];  lon0 = rota[0, 1]
    cos_lat = np.cos(np.radians(rota[:, 0].mean()))

    # Converte para metros (eixo X = leste, Y = norte)
    rx = np.radians(rota[:, 1] - lon0) * cos_lat * R        # (N,)
    ry = np.radians(rota[:, 0] - lat0) * R                  # (N,)
    px = np.radians(lons - lon0)        * cos_lat * R        # (M,)
    py = np.radians(lats - lat0)        * R                  # (M,)

    # Vetores de cada segmento A→B
    ax = rx[:-1];  ay = ry[:-1]                              # (N-1,)
    dx = rx[1:] - ax;  dy = ry[1:] - ay                     # (N-1,)
    ab2 = dx*dx + dy*dy
    ab2 = np.where(ab2 < 1e-10, 1e-10, ab2)                 # evita /0

    # Processa em lotes para não estourar RAM (cada lote ≈ 28 MB)
    M = len(lats)
    result = np.empty(M, dtype=np.float64)
    for start in range(0, M, chunk):
        end = min(start + chunk, M)
        apx = px[start:end, None] - ax[None, :]             # (chunk, N-1)
        apy = py[start:end, None] - ay[None, :]
        t   = np.clip((apx * dx + apy * dy) / ab2, 0.0, 1.0)
        ex  = apx - t * dx
        ey  = apy - t * dy
        result[start:end] = np.sqrt((ex*ex + ey*ey).min(axis=1))

    return result                                            # (M,)


def _downsample(coords, max_pts=300):
    """Reduz o número de pontos da polyline sem perder o traçado geral."""
    if len(coords) <= max_pts:
        return coords
    step = max(1, len(coords) // max_pts)
    result = coords[::step]
    # Garante que o último ponto está incluído
    if result[-1] != coords[-1]:
        result = result + [coords[-1]]
    return result


def ufs_ao_longo_rota(coords_rota):
    ufs = set()
    passo = max(1, len(coords_rota)//80)
    for lat, lon in coords_rota[::passo]:
        for uf, (la_min, lo_min, la_max, lo_max) in BBOX_UFS.items():
            if la_min <= lat <= la_max and lo_min <= lon <= lo_max:
                ufs.add(uf)
    return sorted(ufs)


# ═══════════════════════════════════════════════════════════════════
#  ROTEAMENTO — OSRM + fallback linha reta
# ═══════════════════════════════════════════════════════════════════

_OSRM_SERVIDORES = [
    "http://router.project-osrm.org/route/v1/driving",
    "https://routing.openstreetmap.de/routed-car/route/v1/driving",
]


def _tentar_osrm(srv, lon1, lat1, lon2, lat2):
    r = requests.get(f"{srv}/{lon1},{lat1};{lon2},{lat2}",
                     params={"overview":"full","geometries":"geojson"}, timeout=15)
    d = r.json()
    if d.get("code") == "Ok":
        geo = d["routes"][0]["geometry"]["coordinates"]
        return [[c[1],c[0]] for c in geo], d["routes"][0]["distance"]/1000, d["routes"][0]["duration"]/60
    return None


def calcular_rota(lat1, lon1, lat2, lon2):
    for srv in _OSRM_SERVIDORES:
        try:
            res = _tentar_osrm(srv, lon1, lat1, lon2, lat2)
            if res: return res[0], res[1], res[2], False
        except Exception: continue
    n = 60
    coords = [[lat1+(lat2-lat1)*i/(n-1), lon1+(lon2-lon1)*i/(n-1)] for i in range(n)]
    d = _haversine(lat1, lon1, lat2, lon2)/1000
    return coords, d, (d/80)*60, True


# ═══════════════════════════════════════════════════════════════════
#  API ANP
# ═══════════════════════════════════════════════════════════════════

def _get(url, params, tentativas=4):
    """Requisição GET com retry e backoff exponencial.

    Trata 429 (rate-limit) e 5xx com espera maior.
    Levanta a exceção original após esgotar as tentativas.
    """
    for i in range(tentativas):
        try:
            r = requests.get(url, params=params, headers=HEADERS_ANP, timeout=45)
            r.raise_for_status()
            return r
        except requests.exceptions.HTTPError as e:
            status = e.response.status_code if e.response is not None else 0
            if i == tentativas - 1:
                raise
            # 429 = rate limit; 5xx = servidor sobrecarregado → espera maior
            espera = 10 if status in (429, 503, 504) else (2 ** i)
            time.sleep(espera)
        except Exception:
            if i == tentativas - 1:
                raise
            time.sleep(2 ** i)


@st.cache_data(show_spinner=False, ttl=86400)   # 24 horas
def buscar_postos(uf=None):
    params = {"numeropagina": 1}
    if uf: params["uf"] = uf
    resp = _get(f"{API_BASE_URL}{ENDPOINT}", params)
    data = resp.json()
    registros = data["data"] if isinstance(data, dict) and "data" in data else data
    if not registros: return pd.DataFrame()
    df = pd.DataFrame(registros)
    df["_lat"] = pd.to_numeric(df.get("latitude"),  errors="coerce")
    df["_lon"] = pd.to_numeric(df.get("longitude"), errors="coerce")
    df = df.dropna(subset=["_lat","_lon"])
    df = df[df["_lat"].between(-33.8,5.3) & df["_lon"].between(-73.9,-34.7)]
    return df.reset_index(drop=True)


# ═══════════════════════════════════════════════════════════════════
#  MAPA FOLIUM
# ═══════════════════════════════════════════════════════════════════

def _cor(distribuidora, mapa_cores):
    """Retorna cor do pin — delega a _cor_marca para garantir consistência."""
    return _cor_marca(distribuidora)


def _popup(row):
    pf_badge = ""
    if row.get("_pro_frotas"):
        pf_badge = (
            "<div style='background:#FFF9C4;border:2px solid #FFD700;border-radius:6px;"
            "padding:5px 10px;margin-bottom:8px;font-weight:700;color:#7B5E00;"
            "display:flex;align-items:center;gap:6px;font-size:12px'>"
            "⭐ CREDENCIADO PRÓ-FROTAS</div>"
        )
    produtos_html = ""
    try:
        prods = row.get("produtos", [])
        if isinstance(prods, list) and prods:
            linhas = "".join(
                f"<tr><td>{p.get('produto','')}</td>"
                f"<td style='text-align:center'>{p.get('tancagem','')}&nbsp;{p.get('unidMedidaTancagem','')}</td>"
                f"<td style='text-align:center'>{p.get('qtdeBicos','')}</td></tr>"
                for p in prods
            )
            produtos_html = (
                f"<details style='margin-top:6px'>"
                f"<summary style='cursor:pointer;font-weight:bold'>🛢️ Produtos ({len(prods)})</summary>"
                f"<table style='font-size:11px;width:100%;margin-top:4px'>"
                f"<tr style='background:#f5f5f5'><th>Produto</th><th>Tanc.</th><th>Bicos</th></tr>"
                f"{linhas}</table></details>"
            )
    except Exception: pass

    def v(c):
        s = str(row.get(c,"")).strip()
        return s if s and s not in ("nan","None") else "—"

    dist_txt = ""
    try:
        d = row.get("_dist_rota")
        if d is not None and pd.notna(d):
            dist_txt = f"<b>Dist. da rota:</b> {int(d)} m<br>"
    except Exception: pass

    lat = row.get("_lat", "")
    lon = row.get("_lon", "")
    sv_url   = f"https://www.google.com/maps?q=&layer=c&cbll={lat},{lon}"
    maps_url = f"https://www.google.com/maps?q={lat},{lon}"
    botoes_html = (
        f"<div style='display:flex;gap:6px;margin-top:10px'>"
        f"<a href='{sv_url}' target='_blank' style='"
        f"flex:1;background:#1a73e8;color:#fff;text-decoration:none;"
        f"border-radius:6px;padding:6px 0;text-align:center;"
        f"font-size:11px;font-weight:700;display:block'>"
        f"📷 Street View</a>"
        f"<a href='{maps_url}' target='_blank' style='"
        f"flex:1;background:#34a853;color:#fff;text-decoration:none;"
        f"border-radius:6px;padding:6px 0;text-align:center;"
        f"font-size:11px;font-weight:700;display:block'>"
        f"🗺️ Google Maps</a>"
        f"</div>"
    )

    # Marcador oculto para captura de clique no Streamlit
    nome_safe = v("razaoSocial").replace(";", ",")[:80]
    coord_tag = f"<!-- POSTO_SEL:{row.get('_lat', '')};{row.get('_lon', '')};{nome_safe} -->"

    return folium.Popup(
        f"<div style='font-family:sans-serif;font-size:12px;min-width:260px;max-width:320px'>"
        f"{pf_badge}"
        f"<b style='font-size:13px'>⛽ {v('razaoSocial')}</b><br>"
        f"<span style='color:#555;font-size:11px'>{v('distribuidora')}</span><br>"
        f"<hr style='margin:5px 0'>"
        f"<b>CNPJ:</b> {v('cnpj')}<br>"
        f"<b>Endereço:</b> {v('endereco')}{(', '+v('complemento')) if v('complemento')!='—' else ''}<br>"
        f"<b>Bairro:</b> {v('bairro')} — {v('municipio')}/{v('uf')}<br>"
        f"<b>CEP:</b> {v('cep')}<br>"
        f"<b>Autorização:</b> {v('autorizacao')}<br>"
        f"<b>Situação:</b> {v('situacaoConstatada')} | <b>SIGAF:</b> {v('statusSIGAF')}<br>"
        f"{dist_txt}"
        f"{produtos_html}"
        f"{botoes_html}"
        f"{coord_tag}"
        f"</div>",
        max_width=340
    )


def _popup_simples(row):
    """Popup compacto (~250 bytes × marcador vs ~1.2 KB do popup completo).
    Usado automaticamente quando o mapa exibe muitos postos (> MAX_MAPA_POSTOS)
    para reduzir o HTML serializado e manter o mapa responsivo.
    """
    def v(c):
        s = str(row.get(c, "")).strip()
        return s if s and s not in ("nan", "None") else "—"

    lat = row.get("_lat", ""); lon = row.get("_lon", "")
    maps_url = f"https://www.google.com/maps?q={lat},{lon}"
    pf_txt = ("<div style='color:#7B5E00;font-weight:700;font-size:11px;"
              "margin-bottom:4px'>⭐ PRÓ-FROTAS</div>"
              if row.get("_pro_frotas") else "")

    return folium.Popup(
        f"<div style='font-family:sans-serif;font-size:12px;min-width:200px;max-width:260px'>"
        f"{pf_txt}"
        f"<b>⛽ {v('razaoSocial')}</b><br>"
        f"<span style='color:#777;font-size:11px'>{v('distribuidora')}</span>"
        f"<hr style='margin:5px 0'>"
        f"<b>CNPJ:</b> {v('cnpj')}<br>"
        f"<b>📍</b> {v('municipio')} / {v('uf')}<br>"
        f"<a href='{maps_url}' target='_blank' "
        f"style='font-size:11px;color:#1a73e8'>🗺️ Ver no Google Maps</a>"
        f"</div>",
        max_width=280,
    )


def _extrair_posto_do_popup(popup_html: str):
    """Extrai lat, lon e nome do marcador oculto no HTML do popup."""
    if not popup_html:
        return None
    try:
        m = re.search(r"<!-- POSTO_SEL:([-\d.]+);([-\d.]+);(.+?) -->", popup_html)
        if not m:
            return None
        return {"lat": float(m.group(1)), "lon": float(m.group(2)),
                "label": m.group(3).strip()}
    except Exception:
        return None


def _marcador_pf(lat, lon, popup, tooltip):
    """CircleMarker azul maior para postos Pró-Frotas — destaca o credenciamento."""
    return folium.CircleMarker(
        location=[lat, lon],
        radius=14,             # maior que o marcador regular (7)
        color=COR_PF_BORDA,    # borda azul escuro
        weight=2.5,
        fill=True,
        fill_color=COR_PF_FILL,  # interior azul
        fill_opacity=0.92,
        popup=popup,
        tooltip=tooltip,
    )


def criar_mapa(df, coords_rota=None, lat_orig=None, lon_orig=None,
               lat_dest=None, lon_dest=None, label_orig="Origem", label_dest="Destino"):
    # ── Cap de marcadores — evita travar estados grandes como SP (4 000+ postos) ──
    # Acima de MAX_MAPA_POSTOS: amostra postos regulares preservando todos os PF.
    # Usa popup compacto (~250 B/marcador) em vez do completo (~1.2 KB/marcador),
    # reduzindo o HTML serializado de ~5 MB para ~400 KB.
    n_total = len(df)
    foi_limitado = False
    if not df.empty and n_total > MAX_MAPA_POSTOS:
        foi_limitado = True
        if "_pro_frotas" in df.columns:
            df_pf  = df[df["_pro_frotas"]]
            df_reg = df[~df["_pro_frotas"]]
        else:
            df_pf  = pd.DataFrame()
            df_reg = df
        n_reg_max = max(0, MAX_MAPA_POSTOS - len(df_pf))
        if len(df_reg) > n_reg_max:
            df_reg = df_reg.sample(n=n_reg_max, random_state=42)
        df = pd.concat([df_pf, df_reg], ignore_index=True)
    # Popup compacto quando o dataset é grande (>300) mesmo sem cap
    usar_popup_simples = (n_total > 300)

    if not df.empty:
        clat, clon, zoom = df["_lat"].mean(), df["_lon"].mean(), 7
    elif coords_rota:
        lats = [c[0] for c in coords_rota]; lons = [c[1] for c in coords_rota]
        clat = (min(lats)+max(lats))/2; clon = (min(lons)+max(lons))/2; zoom = 6
    else:
        clat, clon, zoom = -15.0, -47.0, 4

    m = folium.Map(location=[clat,clon], zoom_start=zoom, tiles="CartoDB positron")

    distribuidoras = sorted(df["distribuidora"].dropna().unique()) if not df.empty else []
    # _cor_marca garante cor fixa por marca — usada também para montar a legenda
    mapa_cores = {d.upper().strip(): _cor_marca(d) for d in distribuidoras}

    if coords_rota and len(coords_rota) >= 2:
        coords_poly = _downsample(coords_rota, 300)
        folium.PolyLine(coords_poly, color="#1565C0", weight=5,
                        opacity=0.85, tooltip="🗺️ Rota").add_to(m)
    if lat_orig is not None:
        folium.Marker([lat_orig,lon_orig],
                      icon=folium.Icon(color="green",icon="play",prefix="fa"),
                      tooltip=f"🟢 {label_orig}",
                      popup=folium.Popup(f"<b>Origem</b><br>{label_orig}",max_width=200)).add_to(m)
    if lat_dest is not None:
        folium.Marker([lat_dest,lon_dest],
                      icon=folium.Icon(color="red",icon="flag",prefix="fa"),
                      tooltip=f"🔴 {label_dest}",
                      popup=folium.Popup(f"<b>Destino</b><br>{label_dest}",max_width=200)).add_to(m)

    if not df.empty:
        c_reg = MarkerCluster(name="⛽ Postos").add_to(m)
        c_pf  = MarkerCluster(name="⭐ Pró-Frotas").add_to(m)
        tem_pf = "_pro_frotas" in df.columns
        _fn_popup = _popup_simples if usar_popup_simples else _popup
        for _, row in df.iterrows():
            cor   = _cor(row.get("distribuidora",""), mapa_cores)
            is_pf = tem_pf and bool(row.get("_pro_frotas"))
            tip   = f"{'⭐ PRÓ-FROTAS | ' if is_pf else ''}⛽ {row.get('razaoSocial','?')} ({row.get('distribuidora','?')})"
            pop   = _fn_popup(row)
            if is_pf:
                _marcador_pf(row["_lat"], row["_lon"], pop, tip).add_to(c_pf)
            else:
                folium.CircleMarker([row["_lat"],row["_lon"]], radius=7,
                                    color=cor, fill=True, fill_color=cor, fill_opacity=0.85,
                                    popup=pop, tooltip=tip).add_to(c_reg)

    # Aviso de limitação (overlay flutuante no mapa)
    if foi_limitado:
        m.get_root().html.add_child(folium.Element(
            f"<div style='position:fixed;top:10px;left:50%;transform:translateX(-50%);"
            f"z-index:9999;background:#fff3e0;border:1px solid #ff9800;border-radius:8px;"
            f"padding:8px 18px;font-size:12px;color:#e65100;text-align:center;"
            f"box-shadow:0 2px 8px rgba(0,0,0,.25);pointer-events:none'>"
            f"⚠️ Mapa exibindo <b>{MAX_MAPA_POSTOS:,}</b> de <b>{n_total:,}</b> postos "
            f"(Pró-Frotas priorizados). Use a aba <b>Dados Tabulares</b> para ver todos."
            f"</div>"
        ))

    if mapa_cores:
        items = "".join(
            f'<li><span style="background:{cor};display:inline-block;'
            f'width:11px;height:11px;border-radius:50%;margin-right:5px"></span>{d}</li>'
            for d,cor in list(mapa_cores.items())[:22]
        )
        m.get_root().html.add_child(folium.Element(
            "<div style='position:fixed;bottom:30px;right:10px;z-index:1000;"
            "background:white;padding:10px 14px;border-radius:10px;"
            "box-shadow:0 2px 8px rgba(0,0,0,.2);font-size:11px;max-height:320px;overflow-y:auto'>"
            f"<b style='font-size:12px'>Distribuidoras</b>"
            f"<ul style='list-style:none;padding:0;margin:6px 0 0'>{items}"
            "<li style='margin-top:6px;padding-top:6px;border-top:1px solid #eee'>"
            f"<span style='display:inline-block;width:14px;height:14px;border-radius:50%;"
            f"background:{COR_PF_FILL};border:2px solid {COR_PF_BORDA};"
            f"vertical-align:middle;margin-right:5px'></span>"
            "<b>Pró-Frotas</b> ● maior</li>"
            "</ul></div>"
        ))
    folium.LayerControl().add_to(m)
    return m


# ═══════════════════════════════════════════════════════════════════
#  PREÇOS ANP — Levantamento Semanal de Preços de Combustíveis
#
#  Estrutura real do arquivo (resumo_semanal_lpc_*.xlsx):
#    Aba CAPITAIS  — colunas: DATA INICIAL, DATA FINAL, ESTADO, MUNICÍPIO, PRODUTO, Nº POSTOS, UNIDADE, PREÇO MÉDIO
#    Aba MUNICIPIOS— mesmas colunas de CAPITAIS
#    Aba ESTADOS   — colunas: DATA INICIAL, DATA FINAL, REGIAO, ESTADOS, PRODUTO, Nº POSTOS, UNIDADE, PREÇO MÉDIO
#    Aba REGIOES   — colunas: DATA INICIAL, DATA FINAL, REGIAO, PRODUTO, Nº POSTOS, UNIDADE, PREÇO MÉDIO, DESVIO
#    Aba BRASIL    — colunas: DATA INICIAL, DATA FINAL, BRASIL, PRODUTO, Nº POSTOS, UNIDADE, PREÇO MÉDIO, DESVIO
#  Cabeçalho sempre na linha 9 (0-indexed); linhas 0-7 são título/obs.
# ═══════════════════════════════════════════════════════════════════

def _anp_norm(s):
    """Remove acentos, uppercase, strip — para comparações robustas."""
    return unicodedata.normalize("NFD", str(s)).encode("ascii", "ignore").decode("ascii").upper().strip()


def _anp_col(df, *termos):
    """Retorna a primeira coluna cujo nome normalizado contenha qualquer dos termos."""
    for col in df.columns:
        cn = _anp_norm(col)
        if any(_anp_norm(t) in cn for t in termos):
            return col
    return None


def _anp_ler_aba(xls, aba):
    """Lê aba da planilha ANP, pulando linhas de título/notas.

    O cabeçalho real fica na linha que contém 'PRODUTO' + 'DATA' +
    algum identificador geográfico. Requer 'DATA' para não confundir
    com a linha de OBS que cita o produto mas não é cabeçalho.
    """
    df_raw = pd.read_excel(xls, sheet_name=aba, header=None)
    header_row = 0
    geo_keys = ["ESTADO", "MUNICIPIO", "REGIAO", "BRASIL", "PAIS"]
    for i in range(min(20, len(df_raw))):
        row_str = _anp_norm(" ".join(str(v) for v in df_raw.iloc[i].values))
        if ("PRODUTO" in row_str and "DATA" in row_str
                and any(k in row_str for k in geo_keys)):
            header_row = i
            break
    df = pd.read_excel(xls, sheet_name=aba, header=header_row)
    df.columns = [str(c).strip() for c in df.columns]
    df = df.dropna(how="all").reset_index(drop=True)
    col_p = _anp_col(df, "produto")
    if col_p:
        df = df[df[col_p].notna() & (df[col_p].astype(str).str.strip() != "")].copy()
    return df


def _anp_processar_arquivo(buf):
    """Lê todas as abas do arquivo ANP e retorna dict {chave: DataFrame}.

    Abas reconhecidas: MUNICIPIOS, ESTADOS, CAPITAIS, REGIOES, BRASIL
    """
    xls = pd.ExcelFile(buf)
    sheets = {}
    # Nota: usar prefixos que são substrings reais dos nomes normalizados:
    #   "CAPITAL" ≠ substring de "CAPITAIS" (pos6: L vs I)
    #   "REGIAO"  ≠ substring de "REGIOES"  (pos4: A vs O, pois ã→a mas ões→oes)
    #   → usar "CAPITA" (em CAPITAIS) e "REGIO" (em REGIOES)
    mapa = {
        "municipios": ["munic"],
        "estados":    ["estado"],
        "capitais":   ["capita"],   # "CAPITA" ⊂ "CAPITAIS"
        "regioes":    ["regio"],    # "REGIO"  ⊂ "REGIOES"
        "brasil":     ["brasil", "pais", "nacional"],
    }
    for tipo, palavras in mapa.items():
        aba = next(
            (s for s in xls.sheet_names if any(_anp_norm(p) in _anp_norm(s) for p in palavras)),
            None,
        )
        if aba:
            try:
                df = _anp_ler_aba(xls, aba)
                if not df.empty:
                    sheets[tipo] = df
            except Exception:
                pass
    return sheets


@st.cache_data(show_spinner=False, ttl=86400)
def buscar_precos_anp():
    """Tenta baixar a planilha de preços ANP automaticamente.
    Retorna (bytes_xlsx | None, semana_str | None, erro_str | None).
    """
    try:
        headers_page = {**HEADERS_ANP,
                        "Accept": "text/html,application/xhtml+xml,*/*",
                        "Referer": "https://www.gov.br/anp/"}
        resp = requests.get(ANP_PRECOS_URL, headers=headers_page, timeout=20)
        resp.raise_for_status()
        from bs4 import BeautifulSoup
        soup = BeautifulSoup(resp.text, "html.parser")
        link = next(
            (a["href"] for a in soup.find_all("a", href=True)
             if a["href"].lower().endswith(".xlsx")),
            None,
        )
        if not link:
            return None, None, "Nenhum link .xlsx encontrado na página da ANP."
        if not link.startswith("http"):
            link = "https://www.gov.br" + link
        r2 = requests.get(link, headers=HEADERS_ANP, timeout=60)
        r2.raise_for_status()
        semana = link.split("/")[-1].replace(".xlsx", "")
        return r2.content, semana, None
    except Exception as ex:
        return None, None, str(ex)


def _anp_preco_medio(df, col_geo, val_geo, col_prod, col_med, col_uni, col_npos):
    """Extrai preços médios por produto de um DataFrame ANP, opcionalmente filtrado por geo."""
    ordem = {_anp_norm(k): i for i, k in enumerate(PRODUTOS_CHAVE)}
    linhas = []
    df_fil = df.copy()
    if val_geo is not None and col_geo:
        df_fil = df_fil[df_fil[col_geo].apply(_anp_norm) == _anp_norm(str(val_geo))]
    if df_fil.empty:
        return linhas
    for prod_raw, grp in df_fil.groupby(col_prod):
        pk  = _anp_norm(str(prod_raw))
        med = pd.to_numeric(grp[col_med], errors="coerce").mean()
        if pd.isna(med):
            continue
        uni = str(grp[col_uni].iloc[0]).strip() if col_uni else "R$/L"
        nps = int(pd.to_numeric(grp[col_npos], errors="coerce").sum()) if col_npos else None
        linhas.append({
            "_ordem":      ordem.get(pk, 99),
            "_pk":         pk,
            "Combustível": PRODUTO_CURTO.get(pk, str(prod_raw).title()),
            "Preço Médio": round(float(med), 3),
            "Unidade":     uni,
            "Postos":      nps,
        })
    linhas.sort(key=lambda x: x["_ordem"])
    return linhas


def _anp_extrair_precos(sheets, uf=None, municipio=None):
    """Extrai preços para UF/município com referências em múltiplos níveis.

    Hierarquia de dados: Município → Capital → Estado → Região → Brasil
    """
    nome_uf = _anp_norm(UF_NOME.get(uf or "", "")) if uf else None

    def _cols(df):
        return {
            "est":  _anp_col(df, "estado", "estados"),
            "mun":  _anp_col(df, "munic"),
            "reg":  _anp_col(df, "regiao"),
            "prod": _anp_col(df, "produto"),
            "med":  _anp_col(df, "medio revenda", "media revenda", "preco medio"),
            "uni":  _anp_col(df, "unidade"),
            "npos": _anp_col(df, "postos pesq", "numero de postos", "n postos", "numero postos"),
        }

    # ── Referência Brasil ──────────────────────────────────────────
    ref_brasil: dict = {}
    if "brasil" in sheets:
        df_b = sheets["brasil"]
        c = _cols(df_b)
        if c["prod"] and c["med"]:
            for r in _anp_preco_medio(df_b, None, None, c["prod"], c["med"], c["uni"], c["npos"]):
                ref_brasil[r["_pk"]] = r["Preço Médio"]

    # ── Referência Região (descobre a região do estado) ────────────
    ref_regiao: dict = {}
    nome_regiao = None
    if "regioes" in sheets and uf and "estados" in sheets:
        df_reg = sheets["regioes"]
        cr = _cols(df_reg)
        df_est = sheets["estados"]
        ce = _cols(df_est)
        if ce["est"] and ce["reg"] and nome_uf and cr["reg"] and cr["prod"] and cr["med"]:
            row_est = df_est[df_est[ce["est"]].apply(_anp_norm) == nome_uf]
            if not row_est.empty:
                nome_regiao = _anp_norm(str(row_est.iloc[0][ce["reg"]]))
                for r in _anp_preco_medio(df_reg, cr["reg"], nome_regiao,
                                          cr["prod"], cr["med"], cr["uni"], cr["npos"]):
                    ref_regiao[r["_pk"]] = r["Preço Médio"]

    # ── Referência Estado ──────────────────────────────────────────
    ref_estado: dict = {}
    if "estados" in sheets and uf:
        df_est = sheets["estados"]
        ce = _cols(df_est)
        if ce["est"] and ce["prod"] and ce["med"] and nome_uf:
            for r in _anp_preco_medio(df_est, ce["est"], nome_uf,
                                       ce["prod"], ce["med"], ce["uni"], ce["npos"]):
                ref_estado[r["_pk"]] = r["Preço Médio"]

    # ── Nível primário ─────────────────────────────────────────────
    linhas_base = []
    nivel_real  = "Estado"

    # 1. Município
    if municipio and "municipios" in sheets:
        df_mun = sheets["municipios"]
        cm = _cols(df_mun)
        if cm["est"] and cm["mun"] and cm["prod"] and cm["med"] and nome_uf:
            mun_n = _anp_norm(municipio)
            df_fil = df_mun[
                (df_mun[cm["est"]].apply(_anp_norm) == nome_uf) &
                (df_mun[cm["mun"]].apply(_anp_norm).str.contains(mun_n, na=False))
            ]
            if not df_fil.empty:
                linhas_base = _anp_preco_medio(df_fil, None, None,
                                               cm["prod"], cm["med"], cm["uni"], cm["npos"])
                nivel_real = "Município"

    # 2. Capital (fallback se município não encontrado em MUNICIPIOS)
    if not linhas_base and municipio and "capitais" in sheets:
        df_cap = sheets["capitais"]
        cc = _cols(df_cap)
        if cc["est"] and cc["mun"] and cc["prod"] and cc["med"] and nome_uf:
            mun_n = _anp_norm(municipio)
            df_fil = df_cap[
                (df_cap[cc["est"]].apply(_anp_norm) == nome_uf) &
                (df_cap[cc["mun"]].apply(_anp_norm).str.contains(mun_n, na=False))
            ]
            if not df_fil.empty:
                linhas_base = _anp_preco_medio(df_fil, None, None,
                                               cc["prod"], cc["med"], cc["uni"], cc["npos"])
                nivel_real = "Capital"

    # 3. Estado
    if not linhas_base and uf and "estados" in sheets:
        df_est = sheets["estados"]
        ce = _cols(df_est)
        if ce["est"] and ce["prod"] and ce["med"] and nome_uf:
            linhas_base = _anp_preco_medio(df_est, ce["est"], nome_uf,
                                           ce["prod"], ce["med"], ce["uni"], ce["npos"])
            nivel_real = "Estado"

    if not linhas_base:
        return []

    resultado = []
    for r in linhas_base:
        pk = r["_pk"]
        resultado.append({
            **r,
            "Nível":        nivel_real,
            "Ref. Estado":  ref_estado.get(pk),
            "Ref. Região":  ref_regiao.get(pk),
            "Ref. Brasil":  ref_brasil.get(pk),
            "Nome Região":  nome_regiao,
        })
    return resultado


def _renderizar_precos_anp(uf, municipio=None, ufs_multiplas=None):
    """Renderiza aba de preços ANP.

    Modo 1 (sem rota): indicadores por Município/Capital/Estado + referências Região e Brasil
    Modo 2 (com rota): tabela pivot Estado × Combustível + referências regional e nacional
    """
    _cache = st.session_state.get("_precos_anp_cache", {})
    sheets = _cache.get("sheets")
    semana = _cache.get("semana")

    # ── Painel de carregamento ────────────────────────────────────
    with st.expander("📂 Carregar planilha de preços ANP", expanded=(sheets is None)):
        col_btn, col_up = st.columns([1, 1])
        with col_btn:
            if st.button("🔄 Buscar automaticamente", use_container_width=True,
                         key="btn_buscar_precos"):
                with st.spinner("📡 Baixando planilha da ANP…"):
                    _raw, _sem, _err = buscar_precos_anp()
                if _err or _raw is None:
                    st.error(f"❌ Download automático falhou: {_err or 'sem dados'}\n\n"
                             "Use o upload manual ao lado.")
                else:
                    _sheets = _anp_processar_arquivo(io.BytesIO(_raw))
                    if not _sheets:
                        st.error("❌ Planilha não reconhecida.")
                    else:
                        st.session_state["_precos_anp_cache"] = {"sheets": _sheets, "semana": _sem}
                        st.success(f"✅ {_sem} — abas: {', '.join(_sheets.keys())}")
                        st.rerun()
        with col_up:
            arq = st.file_uploader(
                "Upload manual (.xlsx)", type=["xlsx", "xls"],
                key="upload_precos_anp", label_visibility="collapsed",
            )
            if arq:
                try:
                    _sheets = _anp_processar_arquivo(io.BytesIO(arq.read()))
                    if not _sheets:
                        st.error("❌ Nenhuma aba reconhecida na planilha.")
                    else:
                        _sem = arq.name.replace(".xlsx", "").replace(".xls", "")
                        st.session_state["_precos_anp_cache"] = {"sheets": _sheets, "semana": _sem}
                        sheets = _sheets
                        semana = _sem
                        st.success(f"✅ {arq.name} — abas: {', '.join(_sheets.keys())}")
                        st.rerun()
                except Exception as ex:
                    st.error(f"❌ Erro ao ler arquivo: {ex}")
        st.markdown(
            "<div style='font-size:11px;color:#888;margin-top:6px'>"
            "Baixe em: <a href='https://www.gov.br/anp/pt-br/assuntos/precos-e-defesa-da-concorrencia"
            "/precos/levantamento-de-precos-de-combustiveis-ultimas-semanas-pesquisadas' "
            "target='_blank'>gov.br/anp → Levantamento de Preços</a></div>",
            unsafe_allow_html=True,
        )

    if sheets is None:
        st.info("👆 Carregue a planilha de preços da ANP para ver os indicadores.")
        return

    if semana:
        st.caption(f"📅 Pesquisa ANP: **{semana}** · abas: {', '.join(sheets.keys())}")

    st.divider()

    # ══════════════════════════════════════════════════════════════
    # MODO 2 — Rota: pivot Estado × Combustível
    # ══════════════════════════════════════════════════════════════
    if ufs_multiplas:
        st.markdown("### 💰 Preços Médios por Estado — Rota")

        if "estados" not in sheets:
            st.warning("Aba de estados não encontrada na planilha.")
            return

        linhas_rota = []
        for uf_r in ufs_multiplas:
            for r in _anp_extrair_precos(sheets, uf=uf_r):
                linhas_rota.append({"UF": uf_r, "Estado": UF_NOME.get(uf_r, uf_r), **r})

        if not linhas_rota:
            st.info("Preços não encontrados para os estados desta rota na planilha carregada.")
            return

        df_rota = pd.DataFrame(linhas_rota)

        # Pivot: Combustível × UF
        try:
            pivot = df_rota.pivot_table(
                index="Combustível", columns="UF",
                values="Preço Médio", aggfunc="mean",
            ).round(3)
            pivot.columns.name = None
            st.markdown("**Preço Médio Revenda (R$) — 🟢 menor · 🔴 maior preço na rota:**")
            st.dataframe(
                pivot.style
                    .format("R$ {:.3f}")
                    .highlight_min(axis=1, color="#d4edda")
                    .highlight_max(axis=1, color="#f8d7da"),
                use_container_width=True,
            )
        except Exception:
            st.dataframe(
                df_rota[["UF", "Combustível", "Preço Médio", "Unidade", "Postos"]],
                use_container_width=True,
            )

        # Regiões percorridas
        regioes_rota = [r for r in df_rota["Nome Região"].dropna().unique() if r]
        if regioes_rota and "regioes" in sheets:
            st.markdown("**Referência Regional:**")
            df_reg_sheet = sheets["regioes"]
            cr_reg  = _anp_col(df_reg_sheet, "regiao")
            cr_prod = _anp_col(df_reg_sheet, "produto")
            cr_med  = _anp_col(df_reg_sheet, "medio revenda", "media revenda", "preco medio")
            cr_uni  = _anp_col(df_reg_sheet, "unidade")
            cr_npos = _anp_col(df_reg_sheet, "postos pesq", "numero de postos", "n postos")
            if cr_reg and cr_prod and cr_med:
                linhas_reg = []
                for reg in regioes_rota:
                    for r in _anp_preco_medio(df_reg_sheet, cr_reg, reg,
                                              cr_prod, cr_med, cr_uni, cr_npos):
                        linhas_reg.append({"Região": reg.title(), **r})
                if linhas_reg:
                    df_reg_tab = pd.DataFrame(linhas_reg)
                    try:
                        pivot_reg = df_reg_tab.pivot_table(
                            index="Combustível", columns="Região",
                            values="Preço Médio", aggfunc="mean",
                        ).round(3)
                        pivot_reg.columns.name = None
                        st.dataframe(pivot_reg.style.format("R$ {:.3f}"),
                                     use_container_width=True)
                    except Exception:
                        st.dataframe(df_reg_tab[["Região", "Combustível", "Preço Médio"]],
                                     use_container_width=True)

        # Média Brasil
        if "brasil" in sheets:
            df_b  = sheets["brasil"]
            b_prod = _anp_col(df_b, "produto")
            b_med  = _anp_col(df_b, "medio revenda", "media revenda", "preco medio")
            b_uni  = _anp_col(df_b, "unidade")
            b_npos = _anp_col(df_b, "postos pesq", "numero de postos", "n postos")
            if b_prod and b_med:
                rows_br = _anp_preco_medio(df_b, None, None, b_prod, b_med, b_uni, b_npos)
                if rows_br:
                    st.markdown("**Referência: Média Brasil**")
                    cols_br = st.columns(min(len(rows_br), 4))
                    for i, r in enumerate(rows_br[:4]):
                        cols_br[i].metric(
                            r["Combustível"], f"R$ {r['Preço Médio']:.3f}",
                            help=f"{r['Unidade']} | {r['Postos']} postos",
                        )
        return

    # ══════════════════════════════════════════════════════════════
    # MODO 1 — UF / Município selecionado
    # ══════════════════════════════════════════════════════════════
    rows = _anp_extrair_precos(sheets, uf=uf, municipio=municipio or None)

    if not rows:
        st.warning(
            f"Preços não encontrados para "
            f"**{municipio or UF_NOME.get(uf or '', uf or '')}** na planilha carregada."
        )
        return

    nivel       = rows[0]["Nível"]
    nome_regiao = rows[0].get("Nome Região")
    scope_label = (
        f"**{municipio}** ({uf})" if nivel in ("Município", "Capital")
        else f"**{UF_NOME.get(uf or '', uf or '')}** ({uf})"
    )
    st.markdown(f"### 💰 Preços em {scope_label}")
    if nome_regiao:
        st.caption(f"Região: **{nome_regiao.title()}**  ·  nível dos dados: *{nivel}*")

    # Cards de métricas
    for i in range(0, len(rows), 4):
        grupo    = rows[i : i + 4]
        cols_row = st.columns(len(grupo))
        for j, r in enumerate(grupo):
            ref = r.get("Ref. Estado") if nivel in ("Município", "Capital") else r.get("Ref. Brasil")
            delta = None
            if ref and ref != r["Preço Médio"]:
                diff      = r["Preço Médio"] - ref
                ref_label = "vs estado" if nivel in ("Município", "Capital") else "vs Brasil"
                delta     = f"{'+' if diff > 0 else ''}{diff:.3f} {ref_label}"
            cols_row[j].metric(
                label=r["Combustível"],
                value=f"R$ {r['Preço Médio']:.3f}",
                delta=delta,
                delta_color="inverse",
                help=f"{r['Unidade']} | {r['Postos'] or '?'} postos pesquisados",
            )

    # Tabela comparativa
    st.divider()
    st.markdown("**Comparativo de Preços (R$)**")

    col_nivel  = nivel
    col_estado = f"Estado ({UF_NOME.get(uf or '', uf or '')})"
    col_regiao = f"Região ({nome_regiao.title()})" if nome_regiao else "Região"
    col_brasil = "Base Nacional"

    df_disp = pd.DataFrame([{
        "Combustível": r["Combustível"],
        col_nivel:     f"R$ {r['Preço Médio']:.3f}",
        col_estado:    f"R$ {r['Ref. Estado']:.3f}" if r.get("Ref. Estado") else "—",
        col_regiao:    f"R$ {r['Ref. Região']:.3f}" if r.get("Ref. Região") else "—",
        col_brasil:    f"R$ {r['Ref. Brasil']:.3f}" if r.get("Ref. Brasil") else "—",
        "Postos":      r.get("Postos") or "—",
        "Unidade":     r.get("Unidade", "R$/L"),
    } for r in rows])
    st.dataframe(df_disp, use_container_width=True, hide_index=True)

# ═══════════════════════════════════════════════════════════════════
#  EXPORTAÇÃO — Base Nacional de Postos (Excel)
# ═══════════════════════════════════════════════════════════════════

def _gerar_excel_base_brasil() -> tuple:
    """Consolida todos os estados em cache, marca Pró-Frotas e gera um .xlsx.

    Retorna (bytes_do_arquivo | None, mensagem_str).

    Estrutura do arquivo:
      • Aba "Postos ANP"  — todos os postos, ordenados por UF > Município > Razão Social
      • Cabeçalho azul escuro (#0D47A1) com texto branco
      • Linhas Pró-Frotas destacadas em azul claro via formatação condicional
        (avaliado pelo Excel, sem loop Python linha-a-linha — suporta 60 000+ linhas)
      • Coluna "Pró-Frotas" com valor "SIM" nos postos credenciados
    """
    from openpyxl.styles import PatternFill, Font, Alignment, Border, Side
    from openpyxl.formatting.rule import FormulaRule
    from openpyxl.utils import get_column_letter

    estados = st.session_state.get("_estados_precarregados", [])
    if not estados:
        return None, "⚠️ Base não carregada. Use 'Pré-carregar Base Nacional' primeiro."

    # ── Consolida todos os estados ────────────────────────────────
    frames = []
    for uf in estados:
        try:
            df_uf = buscar_postos(uf=uf)
            if not df_uf.empty:
                frames.append(df_uf)
        except Exception:
            continue

    if not frames:
        return None, "❌ Nenhum dado encontrado nos estados carregados."

    df_all = pd.concat(frames, ignore_index=True)

    # ── Marca Pró-Frotas ──────────────────────────────────────────
    cnpjs_pf = st.session_state.get("cnpjs_pro_frotas", set())
    df_all   = marcar_pro_frotas(df_all, cnpjs_pf)

    # ── Formata CNPJ ──────────────────────────────────────────────
    if "cnpj" in df_all.columns:
        df_all["cnpj"] = df_all["cnpj"].fillna("").apply(
            lambda x: _formatar_cnpj(str(x)) if x else "")

    # Coluna legível para Pró-Frotas
    df_all["_pf_txt"] = df_all["_pro_frotas"].map({True: "SIM", False: ""})

    # ── Seleciona e renomeia colunas ──────────────────────────────
    _COL_MAP = [
        ("uf",                "UF"),
        ("municipio",         "Município"),
        ("razaoSocial",       "Razão Social"),
        ("cnpj",              "CNPJ"),
        ("distribuidora",     "Distribuidora / Bandeira"),
        ("_pf_txt",           "Pró-Frotas"),
        ("endereco",          "Endereço"),
        ("bairro",            "Bairro"),
        ("cep",               "CEP"),
        ("autorizacao",       "Autorização ANP"),
        ("situacaoConstatada","Situação"),
        ("statusSIGAF",       "Status SIGAF"),
        ("_lat",              "Latitude"),
        ("_lon",              "Longitude"),
    ]
    cols_src = [c for c, _ in _COL_MAP if c in df_all.columns]
    cols_dst = [d for c, d in _COL_MAP if c in df_all.columns]

    df_exp = (df_all[cols_src]
              .rename(columns=dict(zip(cols_src, cols_dst)))
              .sort_values(["UF", "Município", "Razão Social"])
              .reset_index(drop=True))

    n_total = len(df_exp)
    n_pf_exp = int(df_exp["Pró-Frotas"].eq("SIM").sum()) if "Pró-Frotas" in df_exp.columns else 0

    # ── Gera Excel em memória ─────────────────────────────────────
    buf = io.BytesIO()
    with pd.ExcelWriter(buf, engine="openpyxl") as writer:
        df_exp.to_excel(writer, index=False, sheet_name="Postos ANP")
        ws = writer.sheets["Postos ANP"]

        n_rows = n_total + 1   # +1 cabeçalho
        n_cols = len(df_exp.columns)

        # Estilos base
        hdr_fill  = PatternFill("solid", fgColor="0D47A1")
        hdr_font  = Font(color="FFFFFF", bold=True, size=10)
        hdr_align = Alignment(horizontal="center", vertical="center", wrap_text=True)
        thin_side = Side(style="thin", color="C5CAE9")
        thin_brd  = Border(left=thin_side, right=thin_side,
                           top=thin_side, bottom=thin_side)

        # Cabeçalho formatado
        ws.row_dimensions[1].height = 28
        for col_idx, cell in enumerate(ws[1], start=1):
            cell.fill  = hdr_fill
            cell.font  = hdr_font
            cell.alignment = hdr_align
            cell.border    = thin_brd

        # Formatação condicional — linhas Pró-Frotas em azul claro
        # Usa fórmula Excel avaliada pelo próprio app (rápido para 60 000+ linhas)
        if "Pró-Frotas" in df_exp.columns:
            pf_col_idx    = df_exp.columns.get_loc("Pró-Frotas") + 1   # 1-based
            pf_col_letter = get_column_letter(pf_col_idx)
            last_cell     = f"{get_column_letter(n_cols)}{n_rows}"
            pf_fill       = PatternFill("solid", fgColor="DBEAFE")
            pf_font       = Font(bold=True, size=10)
            # A fórmula usa referência absoluta na coluna PF e relativa na linha
            formula = [f'${pf_col_letter}2="SIM"']
            ws.conditional_formatting.add(
                f"A2:{last_cell}",
                FormulaRule(formula=formula, fill=pf_fill, font=pf_font),
            )

        # Painel informativo — linha abaixo dos dados
        info_row = n_rows + 2
        ws.cell(info_row, 1,
                f"Gerado em: {_agora()}  |  "
                f"{_n(n_total)} postos  |  "
                f"{_n(len(estados))} estados  |  "
                f"{_n(n_pf_exp)} Pró-Frotas  |  "
                f"Fonte: API ANP — revendedoresapi.anp.gov.br"
                ).font = Font(italic=True, color="757575", size=9)

        # Largura automática das colunas (amostragem das primeiras 500 linhas)
        for col_idx, col_cells in enumerate(ws.iter_cols(
                min_row=1, max_row=min(n_rows, 501), max_col=n_cols), start=1):
            max_len = max((len(str(c.value or "")) for c in col_cells), default=8)
            ws.column_dimensions[get_column_letter(col_idx)].width = min(max_len + 3, 42)

        # Congela linha do cabeçalho
        ws.freeze_panes = "A2"

        # Filtro automático
        ws.auto_filter.ref = f"A1:{get_column_letter(n_cols)}1"

    buf.seek(0)
    data = buf.read()
    msg  = (f"✅ {_n(n_total)} postos exportados "
            f"({_n(len(estados))} estados)  |  "
            f"⭐ {_n(n_pf_exp)} Pró-Frotas identificados")
    return data, msg


# ═══════════════════════════════════════════════════════════════════
#  HELPER
# ═══════════════════════════════════════════════════════════════════

def preparar_df(df_raw, distribuidoras_filtro):
    cnpjs_pf = st.session_state.get("cnpjs_pro_frotas", set())
    df = marcar_pro_frotas(df_raw, cnpjs_pf)
    if distribuidoras_filtro:
        df = df[df["distribuidora"].isin(distribuidoras_filtro)]
    return df


def n_pf(df):
    return int(df["_pro_frotas"].sum()) if "_pro_frotas" in df.columns else 0


def _agora() -> str:
    """Retorna data e hora atual formatada: 06/05/2026 às 20:53."""
    return datetime.now().strftime("%d/%m/%Y às %H:%M")


def _n(valor, dec: int = 0) -> str:
    """Formata número com ponto como separador de milhar (padrão BR).
    Exemplos: _n(1234) → '1.234'  |  _n(1234.5, 1) → '1.234,5'
    """
    if dec == 0:
        return f"{int(round(valor)):,}".replace(",", ".")
    s = f"{valor:,.{dec}f}"
    return s.replace(",", "X").replace(".", ",").replace("X", ".")


def _sem_acento(texto: str) -> str:
    """Remove acentos e retorna texto normalizado em maiúsculas.
    Permite comparar 'Ribeirao Preto' com 'RIBEIRÃO PRETO'.
    """
    return "".join(
        c for c in unicodedata.normalize("NFD", texto.upper())
        if unicodedata.category(c) != "Mn"
    )


def _precarregar_estados_paralelo(max_workers: int = 5):
    """Carrega todos os 27 estados em paralelo (até max_workers simultâneos).
    - Hits de cache são instantâneos (< 1s total).
    - Chamadas reais à API rodam em paralelo: ~5-10s no lugar de ~50s sequencial.
    Retorna (lista_ok, lista_err).
    """
    def _load(uf):
        try:
            df = buscar_postos(uf=uf)
            return uf, not df.empty
        except Exception:
            return uf, False

    ok, err = [], []
    with ThreadPoolExecutor(max_workers=max_workers) as ex:
        futures = {ex.submit(_load, uf): uf for uf in UFS}
        for f in as_completed(futures):
            uf, success = f.result()
            (ok if success else err).append(uf)
    return sorted(ok), sorted(err)


def _buscar_cidades_cache(texto: str, max_results: int = 6) -> list:
    """Busca municípios diretamente no cache ANP — sem depender do Nominatim.
    Normaliza acentos, então 'Ribeirao Preto' encontra 'RIBEIRÃO PRETO'.
    Retorna lista de dicts {label, lat, lon, tipo='cidade'}.
    """
    texto_norm = _sem_acento(texto.strip())
    if len(texto_norm) < 2:
        return []

    estados = st.session_state.get("_estados_precarregados", [])
    if not estados:
        return []

    vistos: set = set()
    resultados: list = []

    for uf in estados:
        try:
            df = buscar_postos(uf=uf)
            if df.empty or "municipio" not in df.columns:
                continue
            mask = df["municipio"].fillna("").apply(
                lambda x: texto_norm in _sem_acento(x)
            )
            for mun, grupo in df[mask].groupby("municipio"):
                chave = f"{mun}|{uf}"
                if chave in vistos:
                    continue
                vistos.add(chave)
                resultados.append({
                    "label": f"{mun} – {uf}",
                    "lat":   float(grupo["_lat"].mean()),
                    "lon":   float(grupo["_lon"].mean()),
                    "tipo":  "cidade",
                })
                if len(resultados) >= max_results:
                    return resultados
        except Exception:
            continue

    return resultados


# ═══════════════════════════════════════════════════════════════════
#  INTERFACE — BARRA SUPERIOR
# ═══════════════════════════════════════════════════════════════════

cnpjs_pf_ativos = st.session_state.get("cnpjs_pro_frotas", set())
pf_badge_html = (
    f'<span class="topbar-badge">⭐ Pró-Frotas: {len(cnpjs_pf_ativos)} CNPJs ativos</span>'
    if cnpjs_pf_ativos else
    '<span class="topbar-badge">⭐ Pró-Frotas não carregado</span>'
)

st.markdown(f"""
<div class="topbar">
  <div>
    <div class="topbar-title">Estudo de Rede – Pró-Frotas</div>
    <div class="topbar-sub">ANP · Agência Nacional do Petróleo, Gás Natural e Biocombustíveis</div>
  </div>
  {pf_badge_html}
</div>
""", unsafe_allow_html=True)


# ═══════════════════════════════════════════════════════════════════
#  AUTO-CARGA DA BASE NACIONAL (uma vez por sessão)
#  Carrega os 27 estados em paralelo ao abrir o app.
#  - Hits de cache (24h): quase instantâneo.
#  - Cache frio (1ª abertura ou restart): ~5-15s com 5 workers paralelos.
#  Garante que buscas por cidade, nome e CNPJ funcionem imediatamente.
# ═══════════════════════════════════════════════════════════════════

if not st.session_state.get("_base_auto_ok"):
    with st.spinner("⏳ Carregando base nacional de postos… (apenas na primeira abertura)"):
        _auto_ok, _auto_err = _precarregar_estados_paralelo(max_workers=5)
    st.session_state.update({
        "_estados_precarregados": _auto_ok,
        "_preload_brasil_em":     _agora(),
        "_preload_brasil_ok":     len(_auto_ok),
        "_preload_brasil_err":    _auto_err,
        "_base_auto_ok":          True,
    })
    st.rerun()


# ═══════════════════════════════════════════════════════════════════
#  SIDEBAR
# ═══════════════════════════════════════════════════════════════════

with st.sidebar:

    # ── Logo / título lateral ─────────────────────────────────
    st.markdown(f"""
    <div style='
        margin: -1rem -1rem 0 -1rem;
        background: #ffffff;
        padding: 22px 16px 14px;
        text-align: center;
        border-bottom: 4px solid transparent;
        border-image: linear-gradient(90deg, #0d1b4b 0%, #1565c0 55%, #0288d1 100%) 1;
        box-shadow: 0 4px 14px rgba(13,27,75,0.10);
        margin-bottom: 14px;
    '>
      {_LOGO_SIDEBAR}
      <div style='
          font-size: 10px;
          color: #1565c0;
          margin-top: 9px;
          letter-spacing: 1px;
          text-transform: uppercase;
          font-weight: 700;
          opacity: 0.75;
      '>Estudo de Rede · ANP</div>
    </div>
    """, unsafe_allow_html=True)

    # ── Auto-carregamento do repositório ─────────────────────
    # Tenta UMA VEZ por sessão — usa flag para não repetir
    if not st.session_state.get("cnpjs_pro_frotas") and not st.session_state.get("_repo_tentado"):
        st.session_state["_repo_tentado"] = True   # evita loop
        _cnpjs_repo, _msg_repo, _prev_repo = _auto_carregar_pro_frotas_repo()
        if _cnpjs_repo:
            st.session_state["cnpjs_pro_frotas"]  = _cnpjs_repo
            st.session_state["_pf_fonte"]         = "repo"
            st.session_state["_pf_carregado_em"]  = _agora()

    # ── Pró-Frotas ────────────────────────────────────────────
    _pf_fonte = st.session_state.get("_pf_fonte", "manual")
    _pf_set   = st.session_state.get("cnpjs_pro_frotas", set())

    # Badge de status acima do expander
    _pf_ts = st.session_state.get("_pf_carregado_em", "")
    _pf_ts_html = (f"<br><span style='font-size:10px;opacity:.8'>🕐 Carregado em: {_pf_ts}</span>"
                   if _pf_ts else "")
    if _pf_set:
        if _pf_fonte == "repo":
            st.markdown(
                f"<div style='background:#e8f5e9;border:1px solid #a5d6a7;border-radius:8px;"
                f"padding:8px 12px;font-size:12px;color:#2e7d32;margin-bottom:8px'>"
                f"✅ <b>Pró-Frotas carregado automaticamente</b><br>"
                f"📋 {_n(len(_pf_set))} CNPJs · atualiza a cada 24 h"
                f"{_pf_ts_html}<br>"
                f"<span style='font-size:10px;opacity:.8'>Fonte: <code>{ARQUIVO_PF_REPO}</code> no repositório</span>"
                f"</div>",
                unsafe_allow_html=True,
            )
        else:
            st.markdown(
                f"<div style='background:#fff8e1;border:1px solid #ffe082;border-radius:8px;"
                f"padding:8px 12px;font-size:12px;color:#f57f17;margin-bottom:8px'>"
                f"⭐ <b>Pró-Frotas carregado manualmente</b><br>"
                f"📋 {_n(len(_pf_set))} CNPJs ativos nesta sessão"
                f"{_pf_ts_html}"
                f"</div>",
                unsafe_allow_html=True,
            )
    else:
        st.markdown(
            "<div style='background:#fff3e0;border:1px solid #ffcc80;border-radius:8px;"
            "padding:8px 12px;font-size:12px;color:#e65100;margin-bottom:8px'>"
            "⚠️ <b>Pró-Frotas não carregado</b><br>"
            f"<span style='font-size:10px'>Adicione <code>{ARQUIVO_PF_REPO}</code> ao repositório<br>"
            "ou faça upload manual abaixo.</span>"
            "</div>",
            unsafe_allow_html=True,
        )

    with st.expander("⭐  Gerenciar Pró-Frotas", expanded=not bool(_pf_set)):
        if st.button("🔄 Recarregar do repositório", use_container_width=True,
                     help="Força nova leitura do pro_frotas.xlsx no GitHub"):
            _auto_carregar_pro_frotas_repo.clear()
            with st.spinner(f"Lendo `{ARQUIVO_PF_REPO}` do repositório…"):
                _cnpjs_r, _msg_r, _prev_r = _auto_carregar_pro_frotas_repo()
            if _cnpjs_r:
                st.session_state["cnpjs_pro_frotas"] = _cnpjs_r
                st.session_state["_pf_fonte"]        = "repo"
                st.session_state["_pf_carregado_em"] = _agora()
                st.success(f"✅ {_msg_r}")
                time.sleep(1)
                st.rerun()
            else:
                st.error(_msg_r or f"❌ `{ARQUIVO_PF_REPO}` não encontrado no repositório.")

        st.divider()
        st.markdown(
            "<small><b>Upload manual</b> — substitui os dados do repositório nesta sessão:</small>",
            unsafe_allow_html=True,
        )
        st.markdown("")
        arquivo_pf = st.file_uploader(
            "Selecionar planilha", type=["xlsx","xls","csv"],
            key="upload_pf", label_visibility="collapsed",
        )
        if arquivo_pf is not None:
            with st.spinner("Lendo planilha…"):
                cnpjs_pf, msg_pf, preview_pf = ler_planilha_pro_frotas(arquivo_pf)
            if cnpjs_pf is not None:
                st.session_state["cnpjs_pro_frotas"] = cnpjs_pf
                st.session_state["_pf_fonte"]        = "manual"
                st.session_state["_pf_carregado_em"] = _agora()
                st.success(msg_pf)
                if preview_pf is not None:
                    with st.expander("Ver amostra dos CNPJs"):
                        st.dataframe(preview_pf, use_container_width=True)
                st.rerun()
            else:
                st.error(msg_pf)

        if _pf_set:
            st.divider()
            if st.button("🗑️ Remover Pró-Frotas", use_container_width=True):
                st.session_state.pop("cnpjs_pro_frotas", None)
                st.session_state.pop("_pf_fonte", None)
                st.rerun()

    st.divider()

    # ── Pré-carregar Base Nacional ────────────────────────────
    with st.expander("🗃️  Pré-carregar Base Nacional", expanded=False):
        st.markdown(
            "<small>Carrega postos de <b>todos os 27 estados</b> antecipadamente "
            "e mantém em cache por <b>24 horas</b>.<br>"
            "Após isso, qualquer busca por rota fica <b>instantânea</b> "
            "sem aguardar a API.</small>",
            unsafe_allow_html=True,
        )
        # Exibe info da última carga se existir
        _preload_ts  = st.session_state.get("_preload_brasil_em", "")
        _preload_ok  = st.session_state.get("_preload_brasil_ok", 0)
        _preload_err = st.session_state.get("_preload_brasil_err", [])
        if _preload_ts:
            _cor_card = "#e8f5e9" if not _preload_err else "#fff8e1"
            _brd_card = "#a5d6a7" if not _preload_err else "#ffe082"
            _txt_cor  = "#2e7d32" if not _preload_err else "#f57f17"
            _ic       = "✅" if not _preload_err else "⚠️"
            _err_txt  = (f"<br><span style='font-size:10px'>Falha em: {', '.join(_preload_err)}</span>"
                         if _preload_err else "")
            st.markdown(
                f"<div style='background:{_cor_card};border:1px solid {_brd_card};"
                f"border-radius:8px;padding:8px 12px;font-size:12px;color:{_txt_cor};margin:8px 0'>"
                f"{_ic} <b>{_preload_ok} estado(s) carregado(s)</b>{_err_txt}<br>"
                f"<span style='font-size:10px;opacity:.8'>🕐 Última carga: {_preload_ts}</span>"
                f"</div>",
                unsafe_allow_html=True,
            )
        st.markdown("")
        if st.button("⚡ Recarregar todos os estados agora",
                     use_container_width=True, key="btn_preload"):
            buscar_postos.clear()   # limpa cache para forçar nova leitura da API
            with st.spinner("📡 Recarregando base em paralelo…"):
                carregados_pl, erros_pl = _precarregar_estados_paralelo(max_workers=5)
            st.session_state["_estados_precarregados"] = carregados_pl
            st.session_state["_preload_brasil_em"]     = _agora()
            st.session_state["_preload_brasil_ok"]     = len(carregados_pl)
            st.session_state["_preload_brasil_err"]    = erros_pl
            st.session_state["_base_auto_ok"]          = True
            if erros_pl:
                st.warning(f"✅ {len(carregados_pl)} estados carregados. "
                           f"⚠️ Falha em: {', '.join(erros_pl)}")
            else:
                st.success(f"✅ Todos os {len(UFS)} estados carregados! "
                           "Buscas por cidade, nome e CNPJ são instantâneas por 24 h.")
            st.rerun()

    st.divider()

    # ── Exportar Base Nacional ────────────────────────────────
    with st.expander("📥  Exportar Base Nacional", expanded=False):
        _n_est_exp = len(st.session_state.get("_estados_precarregados", []))
        st.markdown(
            "<small>Gera um arquivo <b>Excel (.xlsx)</b> com todos os postos "
            "dos estados já carregados, identificando os <b>Pró-Frotas</b> "
            "com destaque em azul.</small>",
            unsafe_allow_html=True,
        )
        st.markdown("")
        if _n_est_exp == 0:
            st.warning(
                "⚠️ Carregue a base primeiro usando "
                "**⚡ Recarregar todos os estados agora** acima.",
                icon=None,
            )
        else:
            st.markdown(
                f"<div style='font-size:12px;color:#555;margin-bottom:8px'>"
                f"📦 <b>{_n_est_exp} estado(s)</b> disponíveis para exportação</div>",
                unsafe_allow_html=True,
            )
            if st.button("📊 Gerar arquivo Excel",
                         use_container_width=True,
                         key="btn_export_base"):
                with st.spinner(f"⏳ Consolidando {_n_est_exp} estado(s)…"):
                    _exp_bytes, _exp_msg = _gerar_excel_base_brasil()
                if _exp_bytes:
                    st.session_state["_base_export_bytes"] = _exp_bytes
                    st.session_state["_base_export_msg"]   = _exp_msg
                else:
                    st.error(_exp_msg)

        # Download button persiste após geração (sobrevive ao rerun)
        if st.session_state.get("_base_export_bytes"):
            st.download_button(
                label="⬇️  Baixar Excel",
                data=st.session_state["_base_export_bytes"],
                file_name=f"postos_anp_{datetime.now().strftime('%Y%m%d')}.xlsx",
                mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                use_container_width=True,
                key="btn_download_base",
            )
            st.success(st.session_state.get("_base_export_msg", ""))
            if st.button("🗑️ Limpar exportação", use_container_width=True,
                         key="btn_clear_export"):
                st.session_state.pop("_base_export_bytes", None)
                st.session_state.pop("_base_export_msg", None)
                st.rerun()

    st.divider()

    # ── Modo de exibição ──────────────────────────────────────
    st.markdown("<div style='font-weight:700;font-size:13px;margin-bottom:8px'>🧭 Modo de exibição</div>",
                unsafe_allow_html=True)
    modo = st.radio("Modo", ["📍 Por Estado/Município", "🗺️ Por Rota"],
                    label_visibility="collapsed")
    st.divider()

    # ── Modo 1 ────────────────────────────────────────────────
    if modo == "📍 Por Estado/Município":
        _fk_m1 = st.session_state.get("_form_key_m1", 0)
        st.markdown("<div style='font-weight:700;font-size:13px;margin-bottom:6px'>🗺️ Localização</div>",
                    unsafe_allow_html=True)
        uf = st.selectbox("Estado (UF)", ["— Selecione —"] + UFS, index=0,
                          key=f"sel_uf_{_fk_m1}",
                          help="Selecione o estado para carregar os postos")
        uf = "" if uf == "— Selecione —" else uf

        municipio_input = st.text_input("🏙️ Município (opcional)",
                                         placeholder="Ex: Teresina",
                                         key=f"txt_mun_{_fk_m1}",
                                         help="Filtra os postos por município dentro do estado")

        if st.button("🗑️ Limpar Consulta", use_container_width=True,
                     help="Limpa estado, município, filtros e seleção de rota"):
            for _k in ["_map_orig", "_map_dest", "_map_rota_result", "_map_posto_sel",
                       "_uf_carregada", "df_raw_full", "distribuidoras_disponiveis"]:
                st.session_state.pop(_k, None)
            st.session_state["_form_key_m1"] = _fk_m1 + 1
            st.rerun()

        distribuidoras_filtro = []
        if st.session_state.get("distribuidoras_disponiveis"):
            st.markdown("<div style='font-weight:700;font-size:13px;margin:10px 0 6px'>🏷️ Filtrar por Bandeira</div>",
                        unsafe_allow_html=True)
            distribuidoras_filtro = st.multiselect(
                "Bandeiras", st.session_state["distribuidoras_disponiveis"],
                placeholder="Todas as bandeiras", label_visibility="collapsed",
                key=f"mult_dist_{_fk_m1}")

    # ── Modo 2 ────────────────────────────────────────────────
    else:
        st.markdown(
            "<div style='background:#e3f2fd;border-radius:8px;padding:10px 12px;"
            "font-size:12px;color:#1565c0;margin-bottom:12px'>"
            "💡 Busque por <b>UF</b> (ex: SP), <b>cidade</b> (ex: Ribeirão Preto), "
            "<b>razão social</b> (ex: Rudnick) ou <b>CNPJ</b> (dígitos) "
            "e selecione nas sugestões.</div>",
            unsafe_allow_html=True,
        )
        orig_sel = campo_autocomplete(
            "🟢 Origem — UF, cidade, razão social ou CNPJ",
            "Ex: SP  ·  Ribeirão Preto  ·  Rudnick  ·  12.345.678/0001-99",
            "txt_origem", "orig_sel",
        )
        st.markdown("")
        dest_sel = campo_autocomplete(
            "🔴 Destino — UF, cidade, razão social ou CNPJ",
            "Ex: RJ  ·  Campinas  ·  Auto Posto  ·  98.765.432/0001-00",
            "txt_destino", "dest_sel",
        )
        st.divider()

        st.markdown("<div style='font-weight:700;font-size:13px;margin-bottom:6px'>📏 Raio da rota</div>",
                    unsafe_allow_html=True)
        raio = st.slider("Raio (m)", min_value=200, max_value=2000, value=500, step=100,
                         label_visibility="collapsed",
                         help="Postos dentro deste raio ao redor da rota serão exibidos")
        st.caption(f"Mostrando postos a até **{raio} m** da rota")

        buscar_rota_btn = st.button("🗺️ Traçar Rota e Buscar Postos",
                                    use_container_width=True, type="primary")

        if st.button("🗑️ Limpar Consulta", use_container_width=True,
                     help="Remove os resultados e limpa os campos de origem e destino"):
            for _k in [
                "df_rota", "coords_rota",
                "lat_orig", "lon_orig", "label_orig",
                "lat_dest", "lon_dest", "label_dest",
                "dist_km", "dur_min", "raio_usado", "linha_reta",
                "distribuidoras_rota",
                "orig_sel", "dest_sel",
                "_orig_sel_txt_ant", "_dest_sel_txt_ant",
            ]:
                st.session_state.pop(_k, None)
            # Incrementa o sufixo dos widgets — força criação de novos campos em branco
            st.session_state["_form_key"] = st.session_state.get("_form_key", 0) + 1
            st.rerun()

        distribuidoras_filtro = []
        if st.session_state.get("distribuidoras_rota"):
            st.divider()
            st.markdown("<div style='font-weight:700;font-size:13px;margin-bottom:6px'>🏷️ Filtrar por Bandeira</div>",
                        unsafe_allow_html=True)
            distribuidoras_filtro = st.multiselect(
                "Bandeiras", st.session_state["distribuidoras_rota"],
                placeholder="Todas as bandeiras", label_visibility="collapsed")


# ═══════════════════════════════════════════════════════════════════
#  MODO 1 — Por Estado / Município
# ═══════════════════════════════════════════════════════════════════

if modo == "📍 Por Estado/Município":

    if uf:
        # Carrega o estado inteiro apenas quando a UF muda (aproveita cache 24h)
        if uf != st.session_state.get("_uf_carregada"):
            with st.spinner(f"⏳ Carregando postos de **{uf}**…"):
                try:
                    df_raw_full = buscar_postos(uf=uf)
                except Exception as _api_err:
                    st.error(
                        f"❌ A API ANP retornou um erro ao buscar postos de **{uf}**.\n\n"
                        f"Isso costuma ser temporário — tente novamente em alguns instantes.\n\n"
                        f"Detalhe técnico: `{type(_api_err).__name__}`"
                    )
                    st.stop()
            st.session_state.update({"df_raw_full": df_raw_full, "_uf_carregada": uf})
            if not df_raw_full.empty and "distribuidora" in df_raw_full.columns:
                st.session_state["distribuidoras_disponiveis"] = sorted(
                    df_raw_full["distribuidora"].dropna().unique().tolist())
            # Registra UF como disponível para busca por nome/CNPJ
            precar = st.session_state.get("_estados_precarregados", [])
            if uf not in precar:
                st.session_state["_estados_precarregados"] = precar + [uf]
        else:
            df_raw_full = st.session_state.get("df_raw_full", pd.DataFrame())

        # Filtra por município localmente (instantâneo, sem nova chamada à API)
        mun = municipio_input.strip()
        if mun:
            df_raw = df_raw_full[
                df_raw_full["municipio"].fillna("").str.upper().str.contains(
                    mun.upper(), regex=False, na=False
                )
            ].copy()
        else:
            df_raw = df_raw_full

        df_show = preparar_df(df_raw, distribuidoras_filtro)

        # ── Métricas ──────────────────────────────────────────
        _n_total_show = len(df_show)
        _n_mapa_show  = min(_n_total_show, MAX_MAPA_POSTOS)
        _mapa_label   = (f"⛽ Postos ({_n(MAX_MAPA_POSTOS)} no mapa)"
                         if _n_total_show > MAX_MAPA_POSTOS else "⛽ Postos")
        c1, c2, c3, c4 = st.columns(4)
        c1.metric(_mapa_label,          _n(_n_total_show))
        c2.metric("⭐ Credenciados PF",  _n(n_pf(df_show)))
        c3.metric("🏷️ Bandeiras",       _n(df_show['distribuidora'].nunique()) if not df_show.empty else "0")
        c4.metric("📍 Estado",          uf)

        tab_mapa, tab_dados, tab_analise, tab_precos = st.tabs([
            "🗺️  Mapa Interativo", "📋  Dados Tabulares",
            "📊  Análise por Bandeira", "💰  Preços ANP"])

        with tab_mapa:
            # Chave ESTÁVEL "mapa_m1" — nunca muda entre reruns.
            # Chave dinâmica (ex: mapa_estado_SP) faz o React desmontar/remontar
            # o componente a cada troca de UF, deixando o iframe em branco.
            # Com chave fixa, o componente é reutilizado; o HTML do mapa (prop)
            # muda normalmente quando os dados mudam, e o iframe re-renderiza.
            with st.spinner(f"🗺️ Carregando mapa — {_n(len(df_show))} postos…"):
                st_folium(
                    criar_mapa(df_show), use_container_width=True, height=660,
                    returned_objects=["last_object_clicked"],
                    key="mapa_m1",
                )

            # ── Busca rápida — selecionar posto como Origem / Destino ─
            # Filtra o DataFrame local: sem rerender do mapa, sem round-trip JS
            st.markdown("---")
            st.markdown(
                "<div style='font-weight:700;font-size:13px;margin-bottom:6px'>"
                "🔍 Selecionar posto como Origem / Destino</div>",
                unsafe_allow_html=True,
            )
            _col_busca_m, _col_limpa_m = st.columns([5, 1])
            _busca_txt = _col_busca_m.text_input(
                "Buscar posto",
                placeholder="Digite parte do nome ou CNPJ do posto…",
                key="busca_posto_mapa",
                label_visibility="collapsed",
            )
            if _col_limpa_m.button("🗑️", key="limpa_sel_mapa",
                                    help="Limpar Origem e Destino selecionados"):
                for _k in ["_map_orig", "_map_dest", "_map_rota_result"]:
                    st.session_state.pop(_k, None)
                st.rerun()

            if _busca_txt and len(_busca_txt.strip()) >= 2 and not df_show.empty:
                _bt = _busca_txt.strip().upper()
                _mask_busca = df_show["razaoSocial"].fillna("").str.upper().str.contains(
                    _bt, regex=False, na=False)
                if "cnpj" in df_show.columns:
                    _btd = "".join(c for c in _busca_txt if c.isdigit())
                    if _btd:
                        _mask_cnpj = df_show["cnpj"].fillna("").apply(
                            lambda x: _btd in "".join(c for c in str(x) if c.isdigit()))
                        _mask_busca = _mask_busca | _mask_cnpj

                _res = df_show[_mask_busca].head(6)
                if not _res.empty:
                    for _idx_r, _row_r in _res.iterrows():
                        _ic = "⭐" if bool(_row_r.get("_pro_frotas")) else "⛽"
                        _lbl_r = (f"{str(_row_r.get('razaoSocial', '?'))[:50]}"
                                  f" — {_row_r.get('municipio','')}/{_row_r.get('uf','')}")
                        _c1r, _c2r, _c3r = st.columns([5, 1, 1])
                        _c1r.markdown(f"{_ic} {_lbl_r}")
                        if _c2r.button("🟢", key=f"set_orig_{_idx_r}", help="Definir como Origem"):
                            st.session_state["_map_orig"] = {
                                "lat":      float(_row_r["_lat"]),
                                "lon":      float(_row_r["_lon"]),
                                "label":    str(_row_r.get("razaoSocial", "Posto")),
                                "municipio": str(_row_r.get("municipio", "")),
                                "uf":       str(_row_r.get("uf", "")),
                                "cnpj":     _formatar_cnpj(str(_row_r.get("cnpj", ""))),
                            }
                            st.session_state.pop("_map_rota_result", None)
                            st.rerun()
                        if _c3r.button("🔴", key=f"set_dest_{_idx_r}", help="Definir como Destino"):
                            st.session_state["_map_dest"] = {
                                "lat":      float(_row_r["_lat"]),
                                "lon":      float(_row_r["_lon"]),
                                "label":    str(_row_r.get("razaoSocial", "Posto")),
                                "municipio": str(_row_r.get("municipio", "")),
                                "uf":       str(_row_r.get("uf", "")),
                                "cnpj":     _formatar_cnpj(str(_row_r.get("cnpj", ""))),
                            }
                            st.session_state.pop("_map_rota_result", None)
                            st.rerun()
                else:
                    st.caption("⚠️ Nenhum posto encontrado. Tente outro nome ou CNPJ.")

            # ── Painel Origem / Destino selecionados ──────────────
            _map_o = st.session_state.get("_map_orig")
            _map_d = st.session_state.get("_map_dest")

            def _card_sel(icone, cor, sel):
                if not sel:
                    return (f"<div style='border:1px dashed #ccc;border-radius:8px;"
                            f"padding:10px 14px;font-size:12px;color:#999'>"
                            f"{icone} Não definido</div>")
                nome = sel.get("label", "?")
                mun  = sel.get("municipio", "")
                uf   = sel.get("uf", "")
                cnpj = sel.get("cnpj", "—")
                loc  = f"{mun} / {uf}" if mun else uf
                return (
                    f"<div style='border-left:4px solid {cor};background:#f8fafc;"
                    f"border-radius:0 8px 8px 0;padding:10px 14px;font-size:12px'>"
                    f"<div style='font-weight:700;font-size:13px;color:#1a1a1a'>{icone} {nome}</div>"
                    f"<div style='color:#555;margin-top:4px'>📍 {loc}</div>"
                    f"<div style='color:#555'>🪪 CNPJ: {cnpj}</div>"
                    f"</div>"
                )

            if _map_o or _map_d:
                _co, _cd = st.columns(2)
                _co.markdown(_card_sel("🟢 Origem", "#43a047", _map_o), unsafe_allow_html=True)
                _cd.markdown(_card_sel("🔴 Destino", "#e53935", _map_d), unsafe_allow_html=True)
                st.markdown("")

            # ── Botão Traçar Rota ──────────────────────────────────
            if _map_o and _map_d:
                _col_btn, _col_clr = st.columns([3, 1])
                if _col_btn.button("🗺️ Traçar Rota entre os postos selecionados",
                                   use_container_width=True, type="primary",
                                   key="btn_tracar_mapa"):
                    with st.spinner("Calculando rota…"):
                        _cr, _dk, _dm, _lr = calcular_rota(
                            _map_o["lat"], _map_o["lon"],
                            _map_d["lat"], _map_d["lon"])
                    st.session_state["_map_rota_result"] = {
                        "coords": _cr, "dist_km": _dk, "dur_min": _dm,
                        "linha_reta": _lr,
                        "orig": _map_o, "dest": _map_d,
                    }
                    st.rerun()
                if _col_clr.button("🗑️ Limpar seleção", use_container_width=True,
                                   key="btn_clr_mapa_sel"):
                    for _k in ["_map_orig", "_map_dest", "_map_rota_result"]:
                        st.session_state.pop(_k, None)
                    st.rerun()

            # ── Resultado da rota traçada pelo mapa ───────────────
            _rr = st.session_state.get("_map_rota_result")
            if _rr:
                if _rr["linha_reta"]:
                    st.warning("⚠️ OSRM indisponível — rota exibida como linha reta.")
                st.markdown("---")
                _m1, _m2, _m3, _m4 = st.columns(4)
                _m1.metric("🛣️ Distância",      f"{_n(_rr['dist_km'])} km")
                _m2.metric("⏱️ Tempo estimado", f"{int(_rr['dur_min']//60)}h {int(_rr['dur_min']%60)}min")
                _m3.metric("🟢 Origem",  _rr["orig"]["label"][:25])
                _m4.metric("🔴 Destino", _rr["dest"]["label"][:25])
                st.success(f"✅ **{_rr['orig']['label']}** → **{_rr['dest']['label']}**"
                           f" | {_n(_rr['dist_km'])} km")
                with st.spinner("🗺️ Atualizando mapa com a rota…"):
                    _mapa_rota = criar_mapa(
                        df_show, coords_rota=_rr["coords"],
                        lat_orig=_rr["orig"]["lat"], lon_orig=_rr["orig"]["lon"],
                        lat_dest=_rr["dest"]["lat"], lon_dest=_rr["dest"]["lon"],
                        label_orig=_rr["orig"]["label"], label_dest=_rr["dest"]["label"],
                    )
                    st_folium(_mapa_rota, use_container_width=True, height=580,
                              returned_objects=["last_object_clicked"], key="mapa_rota_estado")

        with tab_dados:
            cols = [c for c in ["razaoSocial","cnpj","distribuidora","_pro_frotas",
                                 "endereco","bairro","municipio","uf","cep","autorizacao","statusSIGAF"]
                    if c in df_show.columns]
            df_exib = df_show[cols].copy()
            if "_pro_frotas" in df_exib.columns:
                df_exib = df_exib.rename(columns={"_pro_frotas":"Pró-Frotas ⭐"})
            st.dataframe(df_exib, use_container_width=True, height=450)
            st.download_button("⬇️ Baixar dados em CSV",
                               df_show.to_csv(index=False).encode("utf-8"),
                               f"postos_{uf}.csv", "text/csv", use_container_width=True)

        with tab_analise:
            if not df_show.empty and "distribuidora" in df_show.columns:
                contagem = df_show["distribuidora"].value_counts().reset_index()
                contagem.columns = ["Distribuidora","Quantidade"]
                st.markdown("**Distribuição de postos por bandeira**")
                st.bar_chart(contagem.set_index("Distribuidora"), height=400)
                if n_pf(df_show) > 0:
                    st.markdown("**Postos Pró-Frotas por bandeira**")
                    pf_dist = df_show[df_show["_pro_frotas"]]["distribuidora"].value_counts().reset_index()
                    pf_dist.columns = ["Distribuidora","Pró-Frotas"]
                    st.bar_chart(pf_dist.set_index("Distribuidora"), height=300)

        with tab_precos:
            _renderizar_precos_anp(uf, municipio_input.strip() or None)

    else:
        # Instrução como overlay dentro do mapa — sem desperdiçar área acima
        _mapa_vazio_m1 = criar_mapa(pd.DataFrame())
        _mapa_vazio_m1.get_root().html.add_child(folium.Element(
            "<div style='position:fixed;bottom:28px;left:50%;transform:translateX(-50%);"
            "z-index:1000;background:rgba(13,27,75,0.88);color:#fff;border-radius:24px;"
            "padding:10px 24px;font-size:13px;font-weight:600;pointer-events:none;"
            "box-shadow:0 4px 12px rgba(0,0,0,.3);white-space:nowrap'>"
            "👈 Selecione um Estado na barra lateral para carregar os postos"
            "</div>"
        ))
        st_folium(_mapa_vazio_m1, use_container_width=True, height=680,
                  returned_objects=["last_object_clicked"], key="mapa_m1_vazio")


# ═══════════════════════════════════════════════════════════════════
#  MODO 2 — Por Rota
# ═══════════════════════════════════════════════════════════════════

else:

    if buscar_rota_btn:
        orig_sel = st.session_state.get("orig_sel")
        dest_sel = st.session_state.get("dest_sel")
        if not orig_sel:
            st.warning("⚠️ Confirme o **ponto de Origem** selecionando uma sugestão.")
        elif not dest_sel:
            st.warning("⚠️ Confirme o **ponto de Destino** selecionando uma sugestão.")
        elif orig_sel["label"] == dest_sel["label"]:
            st.warning("⚠️ Origem e Destino não podem ser o mesmo ponto.")
        else:
            lo, ld = orig_sel, dest_sel
            with st.spinner("🗺️ Calculando rota…"):
                coords_rota, dist_km, dur_min, linha_reta = calcular_rota(
                    lo["lat"], lo["lon"], ld["lat"], ld["lon"])
            if linha_reta:
                st.warning("⚠️ Servidor de roteamento indisponível. Usando **linha reta** como aproximação.")
            ufs_rota = ufs_ao_longo_rota(coords_rota)
            if not ufs_rota:
                st.error("❌ Não foi possível detectar estados ao longo da rota. Verifique os pontos de origem e destino.")
                ufs_rota = []

            frames = []
            erros_uf = []
            if ufs_rota:
                st.info(f"🗺️ Estados detectados na rota: **{', '.join(ufs_rota)}**")
                prog = st.progress(0, text="Buscando postos nos estados da rota…")
                for idx_uf, uf_b in enumerate(ufs_rota):
                    prog.progress((idx_uf) / len(ufs_rota), text=f"⛽ Carregando postos de **{uf_b}**…")
                    try:
                        df_uf = buscar_postos(uf=uf_b)
                        if not df_uf.empty:
                            frames.append(df_uf)
                            # Registra UF como disponível para busca por nome/CNPJ
                            precar = st.session_state.get("_estados_precarregados", [])
                            if uf_b not in precar:
                                st.session_state["_estados_precarregados"] = precar + [uf_b]
                    except Exception as e:
                        erros_uf.append(f"**{uf_b}**: {type(e).__name__} — {e}")
                    time.sleep(0.5)  # pausa entre UFs para não sobrecarregar a API
                prog.progress(1.0, text="✅ Busca concluída!")
                time.sleep(0.5)
                prog.empty()

            # erros de API (ex: 403) são silenciosos para o usuário final
            # — os estados com cache já resolvem a maioria dos casos

            df_todos = pd.concat(frames, ignore_index=True) if frames else pd.DataFrame()
            if not df_todos.empty:
                with st.spinner("📏 Calculando distâncias…"):
                    # NumPy vetorizado: calcula todas as distâncias de uma vez (~100× mais rápido)
                    dists = dist_minima_rota_np(
                        df_todos["_lat"].values,
                        df_todos["_lon"].values,
                        coords_rota,
                    )
                    df_todos["_dist_rota"] = dists
                df_rota = df_todos[df_todos["_dist_rota"] <= raio].copy().sort_values("_dist_rota").reset_index(drop=True)
                if df_rota.empty:
                    st.warning(
                        f"⚠️ Foram encontrados **{_n(len(df_todos))}** postos nos estados, mas nenhum está "
                        f"dentro de **{raio} m** da rota. Tente aumentar o raio na barra lateral."
                    )
            else:
                if not erros_uf:
                    st.error(
                        "❌ Nenhum posto retornado pela API ANP para os estados da rota. "
                        "Verifique se a API está acessível: https://revendedoresapi.anp.gov.br"
                    )
                df_rota = pd.DataFrame()
            st.session_state.update({
                "df_rota": df_rota, "coords_rota": coords_rota,
                "lat_orig": lo["lat"], "lon_orig": lo["lon"], "label_orig": lo["label"],
                "lat_dest": ld["lat"], "lon_dest": ld["lon"], "label_dest": ld["label"],
                "dist_km": dist_km, "dur_min": dur_min, "raio_usado": raio, "linha_reta": linha_reta,
                "_ufs_rota_atual": ufs_rota,   # para aba de preços
            })
            if not df_rota.empty and "distribuidora" in df_rota.columns:
                st.session_state["distribuidoras_rota"] = sorted(df_rota["distribuidora"].dropna().unique().tolist())
            else:
                st.session_state.pop("distribuidoras_rota", None)

    if "df_rota" in st.session_state:
        df_rota    = st.session_state["df_rota"]
        coords_rota= st.session_state.get("coords_rota",[])
        lat_orig   = st.session_state.get("lat_orig"); lon_orig = st.session_state.get("lon_orig")
        lat_dest   = st.session_state.get("lat_dest"); lon_dest = st.session_state.get("lon_dest")
        label_orig = st.session_state.get("label_orig","Origem")
        label_dest = st.session_state.get("label_dest","Destino")
        dist_km    = st.session_state.get("dist_km",0)
        dur_min    = st.session_state.get("dur_min",0)
        raio_usado = st.session_state.get("raio_usado",500)

        if st.session_state.get("linha_reta"):
            st.warning("⚠️ Rota exibida como **linha reta** (OSRM indisponível).")

        df_show_r = preparar_df(df_rota, distribuidoras_filtro)

        c1,c2,c3,c4 = st.columns(4)
        c1.metric("🛣️ Distância",       f"{_n(dist_km)} km")
        c2.metric("⏱️ Tempo estimado",  f"{int(dur_min//60)}h {int(dur_min%60)}min")
        c3.metric("⛽ Postos na rota",  _n(len(df_show_r)))
        c4.metric("⭐ Pró-Frotas",      _n(n_pf(df_show_r)))

        st.success(f"✅ **{label_orig}** → **{label_dest}** | {_n(len(df_show_r))} postos a até {raio_usado} m")

        tab_m, tab_d, tab_preco_r = st.tabs([
            "🗺️  Mapa da Rota", "📋  Postos na Rota", "💰  Preços ANP"])

        with tab_m:
            with st.spinner(f"🗺️ Carregando mapa da rota — {_n(len(df_show_r))} postos…"):
                m = criar_mapa(df_show_r, coords_rota=coords_rota,
                               lat_orig=lat_orig, lon_orig=lon_orig,
                               lat_dest=lat_dest, lon_dest=lon_dest,
                               label_orig=label_orig, label_dest=label_dest)
                st_folium(m, use_container_width=True, height=660,
                          returned_objects=["last_object_clicked"],
                          key="mapa_rota")

            # ── Busca rápida — refinar Origem/Destino com posto da rota ─
            if not df_show_r.empty:
                st.markdown("---")
                st.markdown(
                    "<div style='font-weight:700;font-size:13px;margin-bottom:6px'>"
                    "🔍 Selecionar posto da rota como nova Origem / Destino</div>",
                    unsafe_allow_html=True,
                )
                _busca_r = st.text_input(
                    "Buscar posto na rota",
                    placeholder="Digite parte do nome ou CNPJ do posto…",
                    key="busca_posto_rota",
                    label_visibility="collapsed",
                )
                if _busca_r and len(_busca_r.strip()) >= 2:
                    _br = _busca_r.strip().upper()
                    _mask_r = df_show_r["razaoSocial"].fillna("").str.upper().str.contains(
                        _br, regex=False, na=False)
                    if "cnpj" in df_show_r.columns:
                        _brd = "".join(c for c in _busca_r if c.isdigit())
                        if _brd:
                            _mask_r_cnpj = df_show_r["cnpj"].fillna("").apply(
                                lambda x: _brd in "".join(c for c in str(x) if c.isdigit()))
                            _mask_r = _mask_r | _mask_r_cnpj

                    _res_r = df_show_r[_mask_r].head(6)
                    if not _res_r.empty:
                        for _idx_rr, _row_rr in _res_r.iterrows():
                            _ic_r = "⭐" if bool(_row_rr.get("_pro_frotas")) else "⛽"
                            _dist_r = int(_row_rr["_dist_rota"]) if pd.notna(_row_rr.get("_dist_rota")) else 0
                            _lbl_r2 = (f"{str(_row_rr.get('razaoSocial','?'))[:45]}"
                                       f" — {_row_rr.get('municipio','')}/{_row_rr.get('uf','')} | {_dist_r} m da rota")
                            _c1rr, _c2rr, _c3rr = st.columns([5, 1, 1])
                            _c1rr.markdown(f"{_ic_r} {_lbl_r2}")
                            _sel_r = {
                                "lat":   float(_row_rr["_lat"]),
                                "lon":   float(_row_rr["_lon"]),
                                "label": str(_row_rr.get("razaoSocial", "Posto")),
                            }
                            if _c2rr.button("🟢", key=f"rota_orig_{_idx_rr}", help="Nova Origem"):
                                st.session_state["orig_sel"] = _sel_r
                                st.session_state["_form_key"] = st.session_state.get("_form_key", 0) + 1
                                st.rerun()
                            if _c3rr.button("🔴", key=f"rota_dest_{_idx_rr}", help="Novo Destino"):
                                st.session_state["dest_sel"] = _sel_r
                                st.session_state["_form_key"] = st.session_state.get("_form_key", 0) + 1
                                st.rerun()
                    else:
                        st.caption("⚠️ Nenhum posto encontrado na rota com esse nome.")

        with tab_d:
            cols_r = [c for c in ["razaoSocial","distribuidora","_pro_frotas",
                                   "municipio","uf","endereco","cep","_dist_rota"]
                      if c in df_show_r.columns]
            df_exib = df_show_r[cols_r].copy()
            if "_pro_frotas" in df_exib.columns:
                df_exib = df_exib.rename(columns={"_pro_frotas":"Pró-Frotas ⭐"})
            if "_dist_rota" in df_exib.columns:
                df_exib = df_exib.rename(columns={"_dist_rota":"Dist. da Rota (m)"})
                df_exib["Dist. da Rota (m)"] = df_exib["Dist. da Rota (m)"].round(0).astype(int)
            st.dataframe(df_exib, use_container_width=True, height=450)
            st.download_button("⬇️ Baixar dados em CSV",
                               df_show_r.to_csv(index=False).encode("utf-8"),
                               "postos_rota.csv","text/csv", use_container_width=True)

        with tab_preco_r:
            _ufs_rota = st.session_state.get("_ufs_rota_atual", [])
            _renderizar_precos_anp(None, ufs_multiplas=_ufs_rota)

    else:
        # Instrução como overlay dentro do mapa — sem desperdiçar área acima
        _mapa_vazio_m2 = criar_mapa(pd.DataFrame())
        _mapa_vazio_m2.get_root().html.add_child(folium.Element(
            "<div style='position:fixed;bottom:28px;left:50%;transform:translateX(-50%);"
            "z-index:1000;background:rgba(13,27,75,0.88);color:#fff;border-radius:24px;"
            "padding:10px 24px;font-size:13px;font-weight:600;pointer-events:none;"
            "box-shadow:0 4px 12px rgba(0,0,0,.3);white-space:nowrap'>"
            "👈 Preencha Origem e Destino na barra lateral e clique em Traçar Rota"
            "</div>"
        ))
        st_folium(_mapa_vazio_m2, use_container_width=True, height=680,
                  returned_objects=["last_object_clicked"], key="mapa_m2_vazio")
