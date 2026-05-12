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

/* ══ SIDEBAR REDESIGN ══════════════════════════════════════════════ */
/* Label de seção */
[data-testid="stSidebar"] .sb-label {
    font-size: 10px;
    font-weight: 700;
    letter-spacing: 1.2px;
    text-transform: uppercase;
    color: #90a4ae;
    margin: 14px 0 6px;
}
/* Botões de modo — mais altos e com quebra de linha */
[data-testid="stSidebar"] .modo-toggle [data-testid="stButton"] > button {
    height: 62px !important;
    font-size: 13px !important;
    line-height: 1.35 !important;
    white-space: pre-wrap !important;
    padding: 6px 4px !important;
}
/* Badge de status Pró-Frotas compacto */
[data-testid="stSidebar"] .pf-badge {
    border-radius: 8px;
    padding: 7px 11px;
    font-size: 11px;
    margin-bottom: 8px;
    line-height: 1.5;
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
    # ANP canônicos
    "GASOLINA COMUM":                    "⛽ Gasolina",
    "GASOLINA ADITIVADA":                "⛽ Gasolina Aditivada",
    "ETANOL HIDRATADO COMBUSTIVEL":      "🌿 Etanol",
    "ETANOL HIDRATADO":                  "🌿 Etanol",
    "OLEO DIESEL":                       "🛢️ Diesel Comum",
    "OLEO DIESEL S10":                   "🛢️ Diesel S10",
    "GNV":                               "💨 GNV",
    "GLP":                               "🔵 GLP",
    "GAS NATURAL COMPRIMIDO":            "💨 GNV",
    "GAS NATURAL VEICULAR":              "💨 GNV",
    "GAS LIQUEFEITO DE PETROLEO":        "🔵 GLP",
    "GAS LIQUEFEITO DO PETROLEO":        "🔵 GLP",
    # Variantes comuns em planilhas de clientes (Preço Posto)
    "GASOLINA":                          "⛽ Gasolina",
    "GASOLINA C":                        "⛽ Gasolina",
    "GASOLINA ALTA OCTANAGEM":           "⛽ Gasolina Aditivada",
    "GASOLINA PREMIUM":                  "⛽ Gasolina Aditivada",
    "DIESEL":                            "🛢️ Diesel Comum",
    "DIESEL COMUM":                      "🛢️ Diesel Comum",
    "DIESEL S500":                       "🛢️ Diesel Comum",
    "DIESEL S-500":                      "🛢️ Diesel Comum",
    "DIESEL S-500 COMUM":               "🛢️ Diesel Comum",
    "DIESEL S-500 ADITIVADO":           "🛢️ Diesel Comum",
    "DIESEL S10":                        "🛢️ Diesel S10",
    "DIESEL S-10":                       "🛢️ Diesel S10",
    "DIESEL S-10 COMUM":                "🛢️ Diesel S10",
    "DIESEL S-10 ADITIVADO":            "🛢️ Diesel S10",
    "OLEO DIESEL S-10":                  "🛢️ Diesel S10",
    "ETANOL":                            "🌿 Etanol",
    "ETANOL COMUM":                      "🌿 Etanol",
    "ETANOL ADITIVADO":                  "🌿 Etanol",
    "ALCOOL":                            "🌿 Etanol",
    "ALCOOL HIDRATADO":                  "🌿 Etanol",
}

# Mapeamento PK da planilha "Preço Posto" → PK canônico ANP
# Resolve casos onde o nome do cliente difere completamente do nome ANP.
# Variantes do mesmo tipo são consolidadas no mesmo PK canônico para agrupamento.
_PP_PARA_ANP_PK: dict = {
    # ── Gasolina ──────────────────────────────────────────────────────
    "GASOLINA":                          "GASOLINA COMUM",
    "GASOLINA COMUM":                    "GASOLINA COMUM",
    "GASOLINA C":                        "GASOLINA COMUM",
    "GASOLINA ADITIVADA":                "GASOLINA ADITIVADA",
    "GASOLINA PREMIUM":                  "GASOLINA ADITIVADA",
    "GASOLINA ALTA OCTANAGEM":           "GASOLINA ADITIVADA",
    "GASOLINA PODIUM":                   "GASOLINA ADITIVADA",
    "GASOLINA FORMULA":                  "GASOLINA ADITIVADA",
    # ── Etanol / Álcool ───────────────────────────────────────────────
    "ETANOL":                            "ETANOL HIDRATADO COMBUSTIVEL",
    "ETANOL COMUM":                      "ETANOL HIDRATADO COMBUSTIVEL",
    "ETANOL ADITIVADO":                  "ETANOL HIDRATADO COMBUSTIVEL",
    "ETANOL HIDRATADO":                  "ETANOL HIDRATADO COMBUSTIVEL",
    "ETANOL HIDRATADO COMBUSTIVEL":      "ETANOL HIDRATADO COMBUSTIVEL",
    "ALCOOL":                            "ETANOL HIDRATADO COMBUSTIVEL",
    "ALCOOL HIDRATADO":                  "ETANOL HIDRATADO COMBUSTIVEL",
    # ── Diesel S500 (= Óleo Diesel / Diesel Comum) ────────────────────
    "DIESEL":                            "OLEO DIESEL",
    "DIESEL COMUM":                      "OLEO DIESEL",
    "OLEO DIESEL":                       "OLEO DIESEL",
    "DIESEL S500":                       "OLEO DIESEL",
    "DIESEL S-500":                      "OLEO DIESEL",
    "DIESEL S 500":                      "OLEO DIESEL",
    "DIESEL S-500 COMUM":               "OLEO DIESEL",
    "DIESEL S-500 ADITIVADO":           "OLEO DIESEL",
    "DIESEL S500 COMUM":                "OLEO DIESEL",
    "DIESEL S500 ADITIVADO":            "OLEO DIESEL",
    "OLEO DIESEL S500":                  "OLEO DIESEL",
    "OLEO DIESEL S-500":                 "OLEO DIESEL",
    # ── Diesel S10 ────────────────────────────────────────────────────
    "DIESEL S10":                        "OLEO DIESEL S10",
    "DIESEL S-10":                       "OLEO DIESEL S10",
    "DIESEL S 10":                       "OLEO DIESEL S10",
    "DIESEL S-10 COMUM":                "OLEO DIESEL S10",
    "DIESEL S-10 ADITIVADO":            "OLEO DIESEL S10",
    "DIESEL S10 COMUM":                  "OLEO DIESEL S10",
    "DIESEL S10 ADITIVADO":              "OLEO DIESEL S10",
    "OLEO DIESEL S10":                   "OLEO DIESEL S10",
    "OLEO DIESEL S-10":                  "OLEO DIESEL S10",
    "OLEO DIESEL S 10":                  "OLEO DIESEL S10",
    # ── GNV ───────────────────────────────────────────────────────────
    "GNV":                               "GNV",
    "GAS NATURAL VEICULAR":              "GNV",
    "GAS NATURAL COMPRIMIDO":            "GNV",
    # ── GLP ───────────────────────────────────────────────────────────
    "GLP":                               "GLP",
    "GAS LIQUEFEITO DE PETROLEO":        "GLP",
    "GAS LIQUEFEITO DO PETROLEO":        "GLP",
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

# Cor e estilo do marcador Rodo Rede (perfil de venda especial)
COR_RR_FILL  = "#6A1B9A"   # roxo/púrpura — identifica Rodo Rede
COR_RR_BORDA = "#4A148C"   # roxo escuro
PERFIL_RODO_REDE = "RODO REDE"  # valor normalizado para comparação


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
ARQUIVO_PF_REPO       = "pro_frotas.xlsx"
ARQUIVO_CERCADOS_REPO = "Postos Cercados.xlsx"
COR_CERCADO_FILL      = "#FF8F00"   # laranja âmbar — alerta visual
COR_CERCADO_BORDA     = "#E65100"   # laranja escuro
ARQUIVO_PP_REPO       = "Preço Posto.xlsx"   # planilha de preços por posto
_PP_PARSER_VERSION    = "v5"                 # incrementar aqui força re-parse automático


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


def _detectar_col(df: pd.DataFrame, termos: list) -> str | None:
    """Retorna o nome da primeira coluna cujo nome normalizado contenha algum dos termos."""
    for _c in df.columns:
        _cn = _anp_norm(_c)
        if any(t in _cn for t in termos):
            return _c
    return None


def _processar_bytes_pro_frotas(nome: str, conteudo: bytes):
    """
    Núcleo de leitura da planilha Pró-Frotas.
    Aceita o nome do arquivo e seus bytes brutos.
    Retorna (set_cnpjs, msg, df_preview, perfil_map, df_coords) ou (None, msg, None, None, None).

    df_coords: DataFrame com colunas [cnpj_norm, _lat, _lon, razaoSocial, distribuidora,
               municipio, uf] para postos que possuem coordenadas na planilha.
    perfil_map: dict {cnpj_norm: "Perfil de Venda"}.
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
        return None, "A planilha está vazia.", None, None, None

    col = detectar_coluna_cnpj(df)
    if col is None:
        colunas = ", ".join(df.columns.tolist())
        return None, (
            f"Coluna CNPJ não encontrada. "
            f"Colunas disponíveis: **{colunas}**. "
            "Renomeie a coluna de CNPJ para 'CNPJ'."
        ), None, None, None

    cnpjs = {c for c in df[col].dropna().apply(normalizar_cnpj) if len(c) == 14}
    if not cnpjs:
        return None, "Nenhum CNPJ válido (14 dígitos) encontrado na coluna detectada.", None, None, None

    # ── Detecta coluna "Perfil de Venda" ───────────────────────────
    col_perfil = _detectar_col(df, ["PERFIL DE VENDA", "PERFIL VENDA", "PERFILDEVENDA", "PERFIL"])

    perfil_map: dict = {}
    if col_perfil:
        for _, row in df.iterrows():
            cnpj_n = normalizar_cnpj(row.get(col, ""))
            if len(cnpj_n) == 14:
                perfil = str(row.get(col_perfil, "")).strip()
                if perfil and perfil.upper() not in ("NAN", "NONE", ""):
                    perfil_map[cnpj_n] = perfil

    # ── Detecta colunas de coordenadas e dados complementares ──────
    col_lat  = _detectar_col(df, ["LATITUDE", "LAT"])
    col_lon  = _detectar_col(df, ["LONGITUDE", "LON", "LNG", "LONG"])
    col_nome = _detectar_col(df, ["RAZAO SOCIAL", "RAZAO", "NOME FANTASIA", "NOME FANTASIA", "NOME"])
    col_dist = _detectar_col(df, ["DISTRIBUIDORA", "BANDEIRA", "REDE"])
    col_mun  = _detectar_col(df, ["MUNICIPIO", "CIDADE"])
    col_uf   = _detectar_col(df, ["UF", "ESTADO"])

    df_coords = pd.DataFrame()
    if col_lat and col_lon:
        rows = []
        for _, row in df.iterrows():
            cnpj_n = normalizar_cnpj(row.get(col, ""))
            if len(cnpj_n) != 14:
                continue
            try:
                lat = float(str(row[col_lat]).replace(",", "."))
                lon = float(str(row[col_lon]).replace(",", "."))
            except (ValueError, TypeError):
                continue
            if not (-33.8 <= lat <= 5.3 and -73.9 <= lon <= -34.7):
                continue
            rows.append({
                "cnpj":         cnpj_n,
                "_lat":         lat,
                "_lon":         lon,
                "razaoSocial":  str(row.get(col_nome, "")).strip() if col_nome else "",
                "distribuidora":str(row.get(col_dist, "")).strip() if col_dist else "",
                "municipio":    str(row.get(col_mun,  "")).strip() if col_mun  else "",
                "uf":           str(row.get(col_uf,   "")).strip() if col_uf   else "",
            })
        if rows:
            df_coords = pd.DataFrame(rows)
            # Limpa valores "nan" / "None" que vieram como string
            for _c in ["razaoSocial","distribuidora","municipio","uf"]:
                df_coords[_c] = df_coords[_c].replace(
                    {"nan": "", "None": "", "NaN": ""})

    preview = df[[col]].rename(columns={col: "CNPJ (original)"}).head(10)
    perfil_info  = f" · {len(set(perfil_map.values()))} perfis" if perfil_map else ""
    coords_info  = f" · {len(df_coords)} coords" if not df_coords.empty else ""
    return (cnpjs,
            f"{len(cnpjs)} CNPJs carregados (coluna: **{col}**){perfil_info}{coords_info}",
            preview,
            perfil_map,
            df_coords)


def ler_planilha_pro_frotas(arquivo):
    """Lê UploadedFile do Streamlit. Sem @st.cache_data (upload não é cacheável)."""
    try:
        return _processar_bytes_pro_frotas(arquivo.name, arquivo.read())
    except ImportError as e:
        return None, f"Biblioteca ausente no servidor: **{e}**.", None, None, None
    except Exception as e:
        return None, f"Erro ao processar arquivo: **{type(e).__name__}** — {e}", None, None, None


@st.cache_data(show_spinner=False, ttl=86400)   # 24 horas — lê o arquivo do repo uma vez por dia
def _auto_carregar_pro_frotas_repo():
    """
    Tenta carregar automaticamente a planilha Pró-Frotas do repositório.
    Aceita: pro_frotas.xlsx / pro_frotas.xls / pro_frotas.csv
    Retorna (set_cnpjs, msg, df_preview, perfil_map, df_coords) ou (None, msg, None, None, None).
    """
    for nome in [ARQUIVO_PF_REPO, "pro_frotas.xls", "pro_frotas.csv"]:
        caminho = os.path.join(_DIR, nome)
        if os.path.exists(caminho):
            try:
                with open(caminho, "rb") as f:
                    conteudo = f.read()
                cnpjs, msg, preview, perfil_map, df_coords = _processar_bytes_pro_frotas(nome, conteudo)
                if cnpjs:
                    return cnpjs, msg, preview, perfil_map, df_coords
            except Exception as e:
                return None, f"Erro ao ler {nome} do repositório: {e}", None, None, None
    return None, f"Arquivo `{ARQUIVO_PF_REPO}` não encontrado em: {_DIR}", None, None, None


# ── Postos Cercados ─────────────────────────────────────────────────

def _processar_bytes_cercados(nome: str, conteudo: bytes):
    """
    Lê planilha de Postos Cercados (CNPJ).
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
    return cnpjs, f"{len(cnpjs)} postos cercados carregados (coluna: **{col}**)", preview


def ler_planilha_cercados(arquivo):
    """Lê UploadedFile do Streamlit. Sem @st.cache_data (upload não é cacheável)."""
    try:
        return _processar_bytes_cercados(arquivo.name, arquivo.read())
    except ImportError as e:
        return None, f"Biblioteca ausente no servidor: **{e}**.", None
    except Exception as e:
        return None, f"Erro ao processar arquivo: **{type(e).__name__}** — {e}", None


@st.cache_data(show_spinner=False, ttl=86400)   # 24 h — re-lê o arquivo do repo uma vez por dia
def _auto_carregar_cercados_repo():
    """
    Tenta carregar automaticamente 'Postos Cercados.xlsx' do repositório.
    Aceita variações de nome: com/sem espaço, maiúsculo/minúsculo.
    Retorna (set_cnpjs, msg, df_preview) ou (None, msg_erro, None).
    """
    candidatos = [
        ARQUIVO_CERCADOS_REPO,          # "Postos Cercados.xlsx"
        "postos_cercados.xlsx",
        "postos_cercados.xls",
        "Postos_Cercados.xlsx",
        "postos cercados.xlsx",
    ]
    for nome in candidatos:
        caminho = os.path.join(_DIR, nome)
        if os.path.exists(caminho):
            try:
                with open(caminho, "rb") as f:
                    conteudo = f.read()
                cnpjs, msg, preview = _processar_bytes_cercados(nome, conteudo)
                if cnpjs:
                    return cnpjs, msg, preview
            except Exception as e:
                return None, f"Erro ao ler {nome} do repositório: {e}", None
    return None, f"Arquivo `{ARQUIVO_CERCADOS_REPO}` não encontrado em: {_DIR}", None


def marcar_cercados(df: pd.DataFrame, cnpjs_cercados: set) -> pd.DataFrame:
    """Adiciona coluna '_cercado' ao DataFrame com base nos CNPJs."""
    df = df.copy()
    if cnpjs_cercados and "cnpj" in df.columns:
        if "_cnpj_norm" not in df.columns:
            df["_cnpj_norm"] = df["cnpj"].fillna("").str.replace(r'\D', '', regex=True)
        df["_cercado"] = df["_cnpj_norm"].isin(cnpjs_cercados)
    else:
        df["_cercado"] = False
    return df


# ── Preço Posto (preços por CNPJ com data de atualização) ───────────

def _detectar_col_combustivel_pp(df):
    for col in df.columns:
        if any(t in _anp_norm(col) for t in ["PRODUTO","COMBUSTIVEL","FUEL","PRODUCT"]):
            return col
    return None

def _detectar_col_preco_pp(df):
    for col in df.columns:
        if any(t in _anp_norm(col) for t in ["PRECO","VALOR","PRICE","VLR","CUSTO"]):
            return col
    return None

def _detectar_col_data_pp(df):
    for col in df.columns:
        if any(t in _anp_norm(col) for t in ["DATA","DATE","ATUALIZ","UPDATE","VIGENCIA"]):
            return col
    return None


def _colunas_combustivel_wide(df):
    """
    Detecta colunas que sejam nomes de combustíveis (formato wide).
    Retorna lista de (col_original, pk_normalizado) ou [] se não for wide.
    """
    # Conjunto de tokens que indicam que a coluna É um combustível
    tokens_comb = {
        "GASOLINA", "DIESEL", "ETANOL", "ALCOOL", "GNV", "GLP",
        "OLEO", "GAS NATURAL", "GAS LIQUEFEITO",
    }
    cols_comb = []
    for col in df.columns:
        pk = _anp_norm(str(col))
        if any(tok in pk for tok in tokens_comb):
            cols_comb.append((col, pk))
    return cols_comb


def _processar_bytes_precos_postos(nome: str, conteudo: bytes):
    """
    Lê planilha de Preços por Posto.
    Aceita dois formatos:
      • Long  — colunas: CNPJ | Produto/Combustível | Preço | Data
      • Wide  — colunas: CNPJ | Gasolina | Diesel | Diesel S10 | ... | Data
                (uma coluna por combustível, valor = preço)

    Retorna (df_normalizado, msg, None) ou (None, msg_erro, None).
    df tem colunas: cnpj_norm, combustivel_pk, combustivel_label, preco, data_atualizacao
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

    col_cnpj = detectar_coluna_cnpj(df)
    if col_cnpj is None:
        return None, (
            f"Coluna CNPJ não encontrada. Disponíveis: {', '.join(df.columns.tolist())}"
        ), None

    col_data = _detectar_col_data_pp(df)

    # ── Detecção automática de formato ────────────────────────────────
    col_comb  = _detectar_col_combustivel_pp(df)
    col_preco = _detectar_col_preco_pp(df)

    # Formato WIDE: sem coluna "Produto/Combustível" mas com colunas de combustíveis
    cols_wide = _colunas_combustivel_wide(df)
    usar_wide = (col_comb is None or col_preco is None) and len(cols_wide) >= 2

    result = []

    if usar_wide:
        # ── Formato Wide ──────────────────────────────────────────────
        for _, row in df.iterrows():
            cnpj_n = normalizar_cnpj(row.get(col_cnpj, ""))
            if len(cnpj_n) != 14:
                continue
            data_str = str(row.get(col_data, "")).strip() if col_data else ""
            for col_orig, pk in cols_wide:
                raw_val = str(row.get(col_orig, "")).strip()
                if not raw_val or raw_val.upper() in ("NAN", "NONE", "", "-", "N/A"):
                    continue
                try:
                    preco = float(raw_val.replace(",", "."))
                    if preco <= 0:
                        continue
                except (ValueError, TypeError):
                    continue
                result.append({
                    "cnpj_norm":         cnpj_n,
                    "combustivel_pk":    pk,
                    "combustivel_label": str(col_orig).strip(),
                    "preco":             preco,
                    "data_atualizacao":  data_str,
                })
    else:
        # ── Formato Long ──────────────────────────────────────────────
        if col_comb is None or col_preco is None:
            faltando = []
            if col_comb  is None: faltando.append("Combustível/Produto")
            if col_preco is None: faltando.append("Preço")
            return None, (
                f"Colunas não encontradas: **{', '.join(faltando)}**. "
                f"Disponíveis: {', '.join(df.columns.tolist())}"
            ), None

        for _, row in df.iterrows():
            cnpj_n = normalizar_cnpj(row.get(col_cnpj, ""))
            if len(cnpj_n) != 14:
                continue
            comb_raw = str(row.get(col_comb, "")).strip()
            comb_pk  = _anp_norm(comb_raw)
            if not comb_pk:
                continue
            try:
                preco_str = str(row.get(col_preco, "")).replace(",", ".").strip()
                preco = float(preco_str)
                if preco <= 0:
                    continue
            except (ValueError, TypeError):
                continue
            data_str = str(row.get(col_data, "")).strip() if col_data else ""
            result.append({
                "cnpj_norm":         cnpj_n,
                "combustivel_pk":    comb_pk,
                "combustivel_label": comb_raw,
                "preco":             preco,
                "data_atualizacao":  data_str,
            })

    if not result:
        return None, "Nenhuma linha válida encontrada (verifique CNPJ e preço).", None

    df_out = pd.DataFrame(result)
    fmt = "wide" if usar_wide else "long"
    msg = (f"{len(df_out)} registros · "
           f"{df_out['cnpj_norm'].nunique()} postos · "
           f"{df_out['combustivel_pk'].nunique()} combustíveis "
           f"[formato {fmt}]")
    return df_out, msg, None


def ler_planilha_precos_postos(arquivo):
    """Lê UploadedFile do Streamlit (sem cache — upload não é cacheável)."""
    try:
        return _processar_bytes_precos_postos(arquivo.name, arquivo.read())
    except Exception as e:
        return None, f"Erro: {type(e).__name__} — {e}", None


def _normalizar_nome_arquivo(nome: str) -> str:
    """Remove acentos e normaliza nome de arquivo para comparação tolerante."""
    sem_acento = unicodedata.normalize("NFD", nome)
    sem_acento = "".join(c for c in sem_acento
                         if unicodedata.category(c) != "Mn")
    return sem_acento.lower().replace(" ", "_").replace("-", "_")


@st.cache_data(show_spinner=False, ttl=3600)   # 1 h — preços atualizam com frequência
def _auto_carregar_precos_postos_repo():
    """
    Tenta carregar a planilha de Preços Posto do diretório do repositório.
    Usa comparação tolerante a acentos e maiúsculas/minúsculas para encontrar
    o arquivo mesmo quando o nome contém caracteres especiais (ex: ç em 'Preço').
    """
    # Fragmentos-chave que o arquivo deve conter (normalizados)
    fragmentos_chave = ["preco", "posto"]

    try:
        arquivos_dir = os.listdir(_DIR)
    except Exception:
        arquivos_dir = []

    # 1ª tentativa: comparação exata (rápida)
    candidatos_exatos = [
        ARQUIVO_PP_REPO,       # "Preço Posto.xlsx"
        "Preco Posto.xlsx",
        "preco_posto.xlsx",
        "precos_postos.xlsx",
        "precos_posto.xlsx",
        "Preco_Posto.xlsx",
        "Preços Posto.xlsx",
        "Precos Posto.xlsx",
    ]
    for nome in candidatos_exatos:
        caminho = os.path.join(_DIR, nome)
        if os.path.exists(caminho):
            try:
                with open(caminho, "rb") as f:
                    conteudo = f.read()
                df, msg, _ = _processar_bytes_precos_postos(nome, conteudo)
                if df is not None:
                    return df, msg, None
            except Exception as e:
                return None, f"Erro ao ler {nome}: {e}", None

    # 2ª tentativa: varredura tolerante a acentos sobre os arquivos reais do diretório
    for arq in arquivos_dir:
        if not arq.lower().endswith((".xlsx", ".xls")):
            continue
        arq_norm = _normalizar_nome_arquivo(arq)
        if all(frag in arq_norm for frag in fragmentos_chave):
            caminho = os.path.join(_DIR, arq)
            try:
                with open(caminho, "rb") as f:
                    conteudo = f.read()
                df, msg, _ = _processar_bytes_precos_postos(arq, conteudo)
                if df is not None:
                    return df, msg, None
            except Exception as e:
                return None, f"Erro ao ler {arq}: {e}", None

    return None, f"Arquivo `{ARQUIVO_PP_REPO}` não encontrado em: {_DIR}", None


# ── Pró-Frotas ───────────────────────────────────────────────────────

def marcar_pro_frotas(df: pd.DataFrame, cnpjs_pf: set) -> pd.DataFrame:
    df = df.copy()
    if cnpjs_pf and "cnpj" in df.columns:
        df["_cnpj_norm"] = df["cnpj"].fillna("").str.replace(r'\D', '', regex=True)
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


@st.cache_data(show_spinner=False, ttl=86400)   # 24 horas — resultado por CNPJ
def buscar_posto_por_cnpj(cnpj_norm: str) -> pd.DataFrame:
    """
    Consulta a API ANP pelo CNPJ do posto (sem filtro de UF).
    Usado para encontrar postos Pró-Frotas ausentes na base do estado consultado.
    Retorna DataFrame com o posto (ou vazio se não encontrado / erro).
    """
    if len(cnpj_norm) != 14:
        return pd.DataFrame()
    # Formata CNPJ no padrão esperado pela API: XX.XXX.XXX/XXXX-XX
    cf = cnpj_norm
    cnpj_fmt = f"{cf[:2]}.{cf[2:5]}.{cf[5:8]}/{cf[8:12]}-{cf[12:]}"
    try:
        resp = _get(f"{API_BASE_URL}{ENDPOINT}",
                    {"numeropagina": 1, "cnpjRevenda": cnpj_fmt})
        data = resp.json()
        registros = data.get("data", data) if isinstance(data, dict) else data
        if not registros:
            return pd.DataFrame()
        lst = registros if isinstance(registros, list) else [registros]
        df = pd.DataFrame(lst)
        df["_lat"] = pd.to_numeric(df.get("latitude"),  errors="coerce")
        df["_lon"] = pd.to_numeric(df.get("longitude"), errors="coerce")
        df = df.dropna(subset=["_lat", "_lon"])
        df = df[df["_lat"].between(-33.8, 5.3) & df["_lon"].between(-73.9, -34.7)]
        return df.reset_index(drop=True)
    except Exception:
        return pd.DataFrame()


def _injetar_pf_ausentes(df_raw: pd.DataFrame, cnpjs_pf: set, uf_atual: str = "") -> pd.DataFrame:
    """
    Verifica quais CNPJs Pró-Frotas estão ausentes em df_raw E pertencem ao
    estado uf_atual, e os injeta usando as coordenadas da planilha (pf_coords_df).
    Filtra por UF para evitar injetar postos de outros estados.
    Não faz chamadas à API ANP — usa exclusivamente os dados da planilha.
    Retorna df_raw enriquecido com os postos encontrados.
    """
    df_coords = st.session_state.get("pf_coords_df", pd.DataFrame())
    if df_coords.empty or not cnpjs_pf:
        return df_raw

    # CNPJs já presentes no dataset do estado (vetorizado)
    if not df_raw.empty and "cnpj" in df_raw.columns:
        cnpjs_presentes = set(df_raw["cnpj"].fillna("").str.replace(r'\D', '', regex=True))
    else:
        cnpjs_presentes = set()

    ausentes = cnpjs_pf - cnpjs_presentes
    if not ausentes:
        return df_raw

    # Filtra df_coords para os ausentes
    df_novos = df_coords[df_coords["cnpj"].isin(ausentes)].copy()
    if df_novos.empty:
        return df_raw

    # ── FILTRO POR UF — só injeta postos do estado atual ─────────────
    # Sem isso, postos de SP/PR/GO que não existem no MT seriam injetados
    # no dataset do MT (porque "ausentes" = todos os PF - CNPJs do MT).
    if uf_atual and "uf" in df_novos.columns:
        df_novos = df_novos[
            df_novos["uf"].fillna("").str.upper().str.strip() == uf_atual.upper().strip()
        ]
        if df_novos.empty:
            return df_raw

    # Constrói linhas compatíveis com a estrutura do df_raw da API ANP
    # Colunas obrigatórias para o mapa: cnpj, _lat, _lon, razaoSocial, distribuidora, municipio, uf
    # Demais colunas do df_raw ficam como NaN (não afetam o funcionamento)
    for _col in df_raw.columns if not df_raw.empty else []:
        if _col not in df_novos.columns:
            df_novos[_col] = pd.NA

    if df_raw.empty:
        return df_novos.reset_index(drop=True)

    return pd.concat([df_raw, df_novos], ignore_index=True)


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


def _marcador_cercado(lat, lon, popup, tooltip):
    """Marcador laranja com ⚠️ para postos cercados — destaca a situação competitiva."""
    icon = folium.DivIcon(
        html=(
            f"<div style='"
            f"background:{COR_CERCADO_FILL};"
            f"border:2.5px solid {COR_CERCADO_BORDA};"
            f"border-radius:50%;"
            f"width:26px;height:26px;"
            f"display:flex;align-items:center;justify-content:center;"
            f"font-size:14px;line-height:1;"
            f"box-shadow:0 2px 6px rgba(0,0,0,.5);"
            f"'>⚠️</div>"
        ),
        icon_size=(26, 26),
        icon_anchor=(13, 13),
    )
    return folium.Marker(
        location=[lat, lon],
        icon=icon,
        popup=popup,
        tooltip=tooltip,
    )


@st.cache_data(show_spinner=False)
def _img_pro_frotas_b64() -> str:
    """
    Carrega logo_profrotas.jpg do repositório e retorna data-URL base64.
    Tenta variações de nome e extensão. Retorna "" se não encontrado.
    """
    for nome in ["logo_profrotas.jpg", "logo_profrotas.jpeg", "logo_profrotas.png",
                 "Logo_profrotas.jpg", "Logo_Profrotas.jpg", "logo_ProFrotas.jpg",
                 "profrotas.jpg", "profrotas.png"]:
        caminho = os.path.join(_DIR, nome)
        if os.path.exists(caminho):
            ext = nome.rsplit(".", 1)[-1].lower()
            mime = "image/jpeg" if ext in ("jpg", "jpeg") else "image/png"
            with open(caminho, "rb") as f:
                dados = base64.b64encode(f.read()).decode()
            return f"data:{mime};base64,{dados}"
    return ""


def _marcador_pf(lat, lon, popup, tooltip):
    """Marcador Pró-Frotas: usa logo_profrotas.jpg se disponível, senão círculo azul."""
    img_b64 = _img_pro_frotas_b64()

    if img_b64:
        html_icon = (
            f"<div style='"
            f"width:36px;height:36px;"
            f"border-radius:50%;"
            f"border:3px solid {COR_PF_BORDA};"
            f"box-shadow:0 2px 8px rgba(0,0,0,.5);"
            f"overflow:hidden;"
            f"background:#fff;'>"
            f"<img src='{img_b64}' "
            f"style='width:100%;height:100%;object-fit:cover;display:block;'/>"
            f"</div>"
        )
        icon = folium.DivIcon(html=html_icon, icon_size=(36, 36), icon_anchor=(18, 18))
        return folium.Marker(
            location=[lat, lon],
            icon=icon,
            popup=popup,
            tooltip=tooltip,
        )
    else:
        # Fallback: círculo azul original
        return folium.CircleMarker(
            location=[lat, lon],
            radius=14,
            color=COR_PF_BORDA,
            weight=2.5,
            fill=True,
            fill_color=COR_PF_FILL,
            fill_opacity=0.92,
            popup=popup,
            tooltip=tooltip,
        )


@st.cache_data(show_spinner=False)
def _img_rodo_rede_b64() -> str:
    """
    Carrega RodoRede.jpg do repositório e retorna data-URL base64.
    Tenta extensões .jpg, .jpeg e .png. Retorna "" se não encontrado.
    """
    for nome in ["RodoRede.jpg", "RodoRede.jpeg", "RodoRede.png",
                 "rodorede.jpg", "rodorede.jpeg", "rodorede.png"]:
        caminho = os.path.join(_DIR, nome)
        if os.path.exists(caminho):
            ext = nome.rsplit(".", 1)[-1].lower()
            mime = "image/jpeg" if ext in ("jpg", "jpeg") else "image/png"
            with open(caminho, "rb") as f:
                dados = base64.b64encode(f.read()).decode()
            return f"data:{mime};base64,{dados}"
    return ""


@st.cache_data(show_spinner=False)
def _logos_bandeiras_b64() -> dict:
    """
    Carrega logos de bandeiras do repositório e retorna dict
    {SUBSTRING_UPPER: data_url_base64}.
    Adicione mais entradas para suportar outras bandeiras no futuro.
    Ex: {"IPIRANGA": "data:image/jpeg;base64,..."}
    """
    # Mapeamento: substring da distribuidora → lista de nomes de arquivo candidatos
    MAPA = {
        "IPIRANGA": ["Ipiranga.jpg", "ipiranga.jpg", "Ipiranga.jpeg",
                     "ipiranga.jpeg", "Ipiranga.png", "ipiranga.png"],
    }
    resultado = {}
    for marca, candidatos in MAPA.items():
        for nome in candidatos:
            caminho = os.path.join(_DIR, nome)
            if os.path.exists(caminho):
                ext  = nome.rsplit(".", 1)[-1].lower()
                mime = "image/jpeg" if ext in ("jpg", "jpeg") else "image/png"
                with open(caminho, "rb") as f:
                    dados = base64.b64encode(f.read()).decode()
                resultado[marca] = f"data:{mime};base64,{dados}"
                break
    return resultado


def _logo_para_distribuidora(distribuidora: str, logos: dict) -> str:
    """Retorna a data-URL da logo se a distribuidora tiver logo cadastrada, senão ''."""
    d = str(distribuidora).upper().strip()
    for marca, url in logos.items():
        if marca in d:
            return url
    return ""


def _marcador_logo_bandeira(lat, lon, popup, tooltip, img_b64: str, cor_borda: str):
    """Marcador circular com a logo da bandeira para postos regulares."""
    html_icon = (
        f"<div style='"
        f"width:28px;height:28px;"
        f"border-radius:50%;"
        f"border:2px solid {cor_borda};"
        f"box-shadow:0 2px 6px rgba(0,0,0,.5);"
        f"overflow:hidden;"
        f"background:#fff;'>"
        f"<img src='{img_b64}' "
        f"style='width:100%;height:100%;object-fit:cover;display:block;'/>"
        f"</div>"
    )
    icon = folium.DivIcon(html=html_icon, icon_size=(28, 28), icon_anchor=(14, 14))
    return folium.Marker(location=[lat, lon], icon=icon, popup=popup, tooltip=tooltip)


def _marcador_pf_bandeira(lat, lon, popup, tooltip, img_b64: str):
    """
    Marcador para posto Pró-Frotas que tem logo de bandeira reconhecida (ex: Ipiranga).
    Usa a logo da bandeira com borda azul PF + anel dourado externo para diferenciar
    de postos regulares da mesma bandeira.
    Tamanho maior (36px) que o pin regular (28px) para destacar o credenciamento PF.
    """
    html_icon = (
        f"<div style='"
        f"width:36px;height:36px;"
        f"border-radius:50%;"
        # Borda interna azul PF + sombra dourada = indicação visual de credenciado
        f"border:3px solid {COR_PF_BORDA};"
        f"box-shadow:0 0 0 2px #FFD700, 0 3px 8px rgba(0,0,0,.55);"
        f"overflow:hidden;"
        f"background:#fff;"
        f"'>"
        f"<img src='{img_b64}' "
        f"style='width:100%;height:100%;object-fit:cover;display:block;'/>"
        f"</div>"
    )
    icon = folium.DivIcon(html=html_icon, icon_size=(36, 36), icon_anchor=(18, 18))
    return folium.Marker(location=[lat, lon], icon=icon, popup=popup, tooltip=tooltip)


def _marcador_rodo_rede(lat, lon, popup, tooltip):
    """Marcador com logo Rodo Rede para postos Pró-Frotas com Perfil de Venda = Rodo Rede."""
    img_b64 = _img_rodo_rede_b64()

    if img_b64:
        # Pin com a imagem RodoRede.jpg — circular com borda roxa
        html_icon = (
            f"<div style='"
            f"width:40px;height:40px;"
            f"border-radius:50%;"
            f"border:3px solid {COR_RR_BORDA};"
            f"box-shadow:0 2px 8px rgba(0,0,0,.6);"
            f"overflow:hidden;"
            f"background:#fff;'>"
            f"<img src='{img_b64}' "
            f"style='width:100%;height:100%;object-fit:cover;display:block;'/>"
            f"</div>"
        )
        icon_size   = (40, 40)
        icon_anchor = (20, 20)
    else:
        # Fallback: emoji 🚛 roxo se imagem não encontrada
        html_icon = (
            f"<div style='"
            f"background:{COR_RR_FILL};"
            f"border:3px solid {COR_RR_BORDA};"
            f"border-radius:50%;"
            f"width:34px;height:34px;"
            f"display:flex;align-items:center;justify-content:center;"
            f"font-size:17px;line-height:1;"
            f"box-shadow:0 2px 8px rgba(0,0,0,.55);'>"
            f"🚛"
            f"</div>"
        )
        icon_size   = (34, 34)
        icon_anchor = (17, 17)

    icon = folium.DivIcon(html=html_icon, icon_size=icon_size, icon_anchor=icon_anchor)
    return folium.Marker(
        location=[lat, lon],
        icon=icon,
        popup=popup,
        tooltip=tooltip,
    )


def marcar_perfil_venda(df: pd.DataFrame, perfil_map: dict) -> pd.DataFrame:
    """Adiciona colunas '_perfil_venda' e '_rodo_rede' ao DataFrame."""
    df = df.copy()
    # Garante que _cnpj_norm existe mesmo que marcar_pro_frotas não tenha criado
    if "_cnpj_norm" not in df.columns and "cnpj" in df.columns:
        df["_cnpj_norm"] = df["cnpj"].fillna("").str.replace(r'\D', '', regex=True)
    if perfil_map and "_cnpj_norm" in df.columns:
        df["_perfil_venda"] = df["_cnpj_norm"].map(perfil_map).fillna("")
        df["_rodo_rede"] = df["_perfil_venda"].str.upper().str.strip() == PERFIL_RODO_REDE
    else:
        df["_perfil_venda"] = ""
        df["_rodo_rede"] = False
    return df


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
        tem_pf_col  = "_pro_frotas" in df.columns
        tem_cer_col = "_cercado"    in df.columns
        tem_rr_col  = "_rodo_rede"  in df.columns
        # Preserva Pró-Frotas, Rodo Rede e Cercados no cap
        _mask_prio = pd.Series(False, index=df.index)
        if tem_pf_col:
            _mask_prio |= df["_pro_frotas"].fillna(False)
        if tem_cer_col:
            _mask_prio |= df["_cercado"].fillna(False)
        if tem_rr_col:
            _mask_prio |= df["_rodo_rede"].fillna(False)
        df_prio = df[_mask_prio]
        df_reg  = df[~_mask_prio]
        n_reg_max = max(0, MAX_MAPA_POSTOS - len(df_prio))
        if len(df_reg) > n_reg_max:
            df_reg = df_reg.sample(n=n_reg_max, random_state=42)
        df = pd.concat([df_prio, df_reg], ignore_index=True)
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
    # Logos de bandeiras (Ipiranga, etc.) — carregadas uma vez por sessão (cache)
    _logos_band = _logos_bandeiras_b64()

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
        c_rr  = MarkerCluster(name="🚛 Rodo Rede").add_to(m)
        c_cer = MarkerCluster(name="⚠️ Postos Cercados").add_to(m)
        tem_pf  = "_pro_frotas" in df.columns
        tem_cer = "_cercado"    in df.columns
        tem_rr  = "_rodo_rede"  in df.columns
        _fn_popup = _popup_simples if usar_popup_simples else _popup
        for _, row in df.iterrows():
            cor    = _cor(row.get("distribuidora",""), mapa_cores)
            is_pf  = tem_pf  and bool(row.get("_pro_frotas"))
            is_cer = tem_cer and bool(row.get("_cercado"))
            is_rr  = tem_rr  and bool(row.get("_rodo_rede"))
            perfil = str(row.get("_perfil_venda", "")).strip()
            tip    = (
                f"{'⚠️ CERCADO | ' if is_cer else ''}"
                f"{'🚛 RODO REDE | ' if is_rr else ('⭐ PRÓ-FROTAS | ' if is_pf else '')}"
                f"⛽ {row.get('razaoSocial','?')} ({row.get('distribuidora','?')})"
                f"{(' | ' + perfil) if perfil and is_pf else ''}"
            )
            pop = _fn_popup(row)
            if is_cer:
                _marcador_cercado(row["_lat"], row["_lon"], pop, tip).add_to(c_cer)
            elif is_rr:
                _marcador_rodo_rede(row["_lat"], row["_lon"], pop, tip).add_to(c_rr)
            elif is_pf:
                # PF com bandeira reconhecida → logo da bandeira + borda PF azul/dourada
                _logo_pf = _logo_para_distribuidora(row.get("distribuidora", ""), _logos_band)
                if _logo_pf:
                    _marcador_pf_bandeira(
                        row["_lat"], row["_lon"], pop, tip, _logo_pf
                    ).add_to(c_pf)
                else:
                    _marcador_pf(row["_lat"], row["_lon"], pop, tip).add_to(c_pf)
            else:
                # Pins regulares sempre como círculo colorido.
                # Logos de bandeira NÃO são embutidas nos pins do mapa para evitar
                # que o HTML do Folium fique enorme (50+ MB para estados grandes como SP).
                # As logos aparecem apenas na legenda.
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
        # ── Legenda: apenas marcas reconhecidas (de CORES_MARCAS) presentes ──
        # Nomes brutos da API (códigos, razões sociais longas) ficam em "Outras".
        # Nomes canônicos mais legíveis para exibição na legenda.
        _NOMES_EXIB = {
            "IPIRANGA":         "Ipiranga",
            "ULTRAPAR":         "Ipiranga",
            "VIBRA":            "Vibra / BR",
            "BR DISTRIBUIDORA": "Vibra / BR",
            "PETROBRAS DIST":   "Vibra / BR",
            "RAIZEN":           "Shell / Raízen",
            "RAÍZEN":           "Shell / Raízen",
            "SHELL":            "Shell / Raízen",
            "BANDEIRA BRANCA":  "Bandeira Branca",
            "SEM BANDEIRA":     "Sem Bandeira",
            "ALESAT":           "Ale / Alesat",
            "ALE COMB":         "Ale / Alesat",
            "SABBA":            "Sabbá",
            "SABBÁ":            "Sabbá",
            "DISLUB":           "Dislub",
            "PETRONIT":         "Petronit",
            "PLURAL":           "Plural",
            "REPSOL":           "Repsol",
            "TEXACO":           "Texaco",
            "NACIONAL GAS":     "Nacional Gás",
            "NACIONAL GÁS":     "Nacional Gás",
            "COSAN":            "Cosan",
            "PETRO RIO":        "PetroRio",
            "PETROIL":          "Petroil",
            "COMFORGAS":        "Comforgas",
            "TERPASTOS":        "Terpastos",
            "GLP":              "GLP",
            "LIQUIGAS":         "Liquigás",
            "ULTRAGAZ":         "Ultragaz",
            "COPAGAZ":          "Copagaz",
            "SUPERGASB":        "Supergasbras",
            "NACIONAL":         "Nacional",
            "PLURAL":           "Plural",
        }
        _nomes_dist = {str(d).upper().strip() for d in distribuidoras}
        _legenda: dict = {}           # nome_exib → cor
        _cores_leg_usadas: set = set()
        for _mk, _mk_cor in CORES_MARCAS.items():
            if _mk_cor in _cores_leg_usadas:
                continue              # mesma cor já representada → pula alias
            if any(_mk in _nd for _nd in _nomes_dist):
                _nome_exib = _NOMES_EXIB.get(_mk, _mk.title())
                if _nome_exib not in _legenda:   # evita duplicar nomes canônicos
                    _legenda[_nome_exib] = _mk_cor
                    _cores_leg_usadas.add(_mk_cor)
        # Verifica se há distribuidoras não reconhecidas nos dados
        _tem_outras_leg = any(
            not any(mk in _nd for mk in CORES_MARCAS)
            for _nd in _nomes_dist
        )

        def _leg_icon(marca: str, cor: str) -> str:
            """Ícone da legenda: logo se disponível, senão círculo colorido."""
            _url = _logo_para_distribuidora(marca, _logos_band)
            if _url:
                return (
                    f"<span style='display:inline-block;width:16px;height:16px;"
                    f"border-radius:50%;border:1.5px solid {cor};"
                    f"overflow:hidden;vertical-align:middle;margin-right:5px;background:#fff;'>"
                    f"<img src='{_url}' style='width:100%;height:100%;object-fit:cover;display:block;'/>"
                    f"</span>"
                )
            return (
                f'<span style="background:{cor};display:inline-block;'
                f'width:11px;height:11px;border-radius:50%;'
                f'vertical-align:middle;margin-right:5px"></span>'
            )

        items = "".join(
            f'<li style="display:flex;align-items:center;margin-bottom:2px">'
            f'{_leg_icon(d, cor)}{d}</li>'
            for d, cor in _legenda.items()
        )
        if _tem_outras_leg:
            _cor_out = "#9E9E9E"
            items += (
                f'<li style="display:flex;align-items:center;margin-bottom:2px">'
                f'<span style="background:{_cor_out};display:inline-block;'
                f'width:11px;height:11px;border-radius:50%;'
                f'vertical-align:middle;margin-right:5px"></span>Outras</li>'
            )
        # Item Pró-Frotas: usa logo_profrotas.jpg se disponível, senão círculo azul
        _pf_img_b64 = _img_pro_frotas_b64()
        if _pf_img_b64:
            _pf_icon_html = (
                f"<span style='display:inline-block;width:22px;height:22px;"
                f"border-radius:50%;border:2px solid {COR_PF_BORDA};"
                f"overflow:hidden;vertical-align:middle;margin-right:5px;background:#fff;'>"
                f"<img src='{_pf_img_b64}' style='width:100%;height:100%;object-fit:cover;display:block;'/>"
                f"</span>"
            )
        else:
            _pf_icon_html = (
                f"<span style='display:inline-block;width:14px;height:14px;border-radius:50%;"
                f"background:{COR_PF_FILL};border:2px solid {COR_PF_BORDA};"
                f"vertical-align:middle;margin-right:5px'></span>"
            )

        # Item Rodo Rede: usa a imagem se disponível, senão emoji fallback
        _rr_img_b64 = _img_rodo_rede_b64()
        if _rr_img_b64:
            _rr_icon_html = (
                f"<span style='display:inline-block;width:22px;height:22px;"
                f"border-radius:50%;border:2px solid {COR_RR_BORDA};"
                f"overflow:hidden;vertical-align:middle;margin-right:5px;background:#fff;'>"
                f"<img src='{_rr_img_b64}' style='width:100%;height:100%;object-fit:cover;display:block;'/>"
                f"</span>"
            )
        else:
            _rr_icon_html = (
                f"<span style='display:inline-block;width:20px;height:20px;border-radius:50%;"
                f"background:{COR_RR_FILL};border:2px solid {COR_RR_BORDA};"
                f"vertical-align:middle;margin-right:5px;text-align:center;"
                f"font-size:11px;line-height:20px'>🚛</span>"
            )
        # ── Entradas PF com bandeira na legenda ─────────────────────
        # Para cada bandeira com logo que tiver postos PF, exibe ícone diferenciado
        _pf_band_items = ""
        _cnpjs_pf_leg = st.session_state.get("cnpjs_pro_frotas", set())
        if _cnpjs_pf_leg and not df.empty and "_pro_frotas" in df.columns and "_cnpj_norm" in df.columns:
            _df_pf_leg = df[df["_pro_frotas"].fillna(False)]
            for _mk_leg, _url_leg in _logos_band.items():
                _tem_pf_marca = (
                    not _df_pf_leg.empty
                    and "distribuidora" in _df_pf_leg.columns
                    and _df_pf_leg["distribuidora"].fillna("").str.upper().str.contains(_mk_leg, regex=False).any()
                )
                if _tem_pf_marca:
                    _pf_band_items += (
                        f"<li style='margin-top:4px;display:flex;align-items:center'>"
                        f"<span style='display:inline-block;width:20px;height:20px;"
                        f"border-radius:50%;border:2px solid {COR_PF_BORDA};"
                        f"box-shadow:0 0 0 1.5px #FFD700;"
                        f"overflow:hidden;vertical-align:middle;margin-right:5px;background:#fff;'>"
                        f"<img src='{_url_leg}' style='width:100%;height:100%;object-fit:cover;display:block;'/>"
                        f"</span>"
                        f"<b>PF {_mk_leg.title()}</b></li>"
                    )

        m.get_root().html.add_child(folium.Element(
            "<div style='position:fixed;bottom:30px;right:10px;z-index:1000;"
            "background:white;padding:10px 14px;border-radius:10px;"
            "box-shadow:0 2px 8px rgba(0,0,0,.2);font-size:11px;max-height:320px;overflow-y:auto'>"
            f"<b style='font-size:12px'>Distribuidoras</b>"
            f"<ul style='list-style:none;padding:0;margin:6px 0 0'>{items}"
            "<li style='margin-top:6px;padding-top:6px;border-top:1px solid #eee'>"
            f"{_pf_icon_html}"
            "<b>Pró-Frotas</b></li>"
            f"{_pf_band_items}"
            f"<li style='margin-top:4px'>{_rr_icon_html}<b>Rodo Rede</b></li>"
            "<li style='margin-top:4px'>"
            f"<span style='display:inline-block;width:14px;height:14px;border-radius:50%;"
            f"background:{COR_CERCADO_FILL};border:2px solid {COR_CERCADO_BORDA};"
            f"vertical-align:middle;margin-right:5px;text-align:center;font-size:9px;line-height:14px'>⚠</span>"
            "<b>Posto Cercado</b></li>"
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


def _brl(v, d=2):
    """Formata número no padrão monetário brasileiro: ponto para milhar, vírgula para decimal.
    Exemplo: _brl(1234.5) → '1.234,50'  |  _brl(1.329, 3) → '1,329'
    """
    s = f"{v:,.{d}f}"          # '1,234.50' (padrão US)
    return s.replace(",", "X").replace(".", ",").replace("X", ".")


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


def buscar_precos_anp():
    """Tenta baixar a planilha de preços ANP automaticamente.
    Retorna (bytes_xlsx | None, semana_str | None, erro_str | None).
    NÃO usa @st.cache_data para que falhas não fiquem em cache.
    O resultado bem-sucedido é guardado em st.session_state pelo chamador.
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


def _parse_label_localizacao(label: str) -> tuple:
    """Extrai (municipio_str | None, uf_str | None) de um label de seleção de local.

    Formatos suportados:
      "CAMPINAS – SP"          → ("CAMPINAS", "SP")
      "Campinas – São Paulo"   → ("Campinas", "SP")
      "São Paulo"              → (None, "SP")   se for nome de estado
      "PALMAS – TO | Posto X"  → ("PALMAS", "TO")
    """
    if not label:
        return None, None

    # Remove sufixo de posto, se houver
    label = label.split(" | ")[0].strip()

    if " – " in label or " - " in label:
        sep = " – " if " – " in label else " - "
        parts = label.split(sep, 1)
        cidade     = parts[0].strip()
        uf_ou_est  = parts[1].strip()

        # 2-letter UF code
        if len(uf_ou_est) == 2 and uf_ou_est.upper() in UF_NOME:
            return cidade, uf_ou_est.upper()

        # Full state name → reverse lookup
        n = _anp_norm(uf_ou_est)
        for uf_k, nome_k in UF_NOME.items():
            if _anp_norm(nome_k) == n:
                return cidade, uf_k
        # Partial match
        for uf_k, nome_k in UF_NOME.items():
            if _anp_norm(nome_k) in n or n in _anp_norm(nome_k):
                return cidade, uf_k
        return cidade, None

    # Sem separador — pode ser nome de estado, sigla, ou "Estado XX"
    # Trata "Estado SP" / "Estado São Paulo" / "estado ES"
    label_strip = label.strip()
    prefixos = ("estado ", "state ", "uf ")
    label_sem_prefixo = label_strip
    for pfx in prefixos:
        if _anp_norm(label_strip).startswith(_anp_norm(pfx)):
            label_sem_prefixo = label_strip[len(pfx):].strip()
            break

    # Sigla de UF (2 letras)
    if len(label_sem_prefixo) == 2 and label_sem_prefixo.upper() in UF_NOME:
        return None, label_sem_prefixo.upper()

    # Nome completo de estado
    n = _anp_norm(label_sem_prefixo)
    for uf_k, nome_k in UF_NOME.items():
        if _anp_norm(nome_k) == n:
            return None, uf_k

    # Tentativa com label original (sem remover prefixo)
    n_orig = _anp_norm(label_strip)
    for uf_k, nome_k in UF_NOME.items():
        if _anp_norm(nome_k) == n_orig:
            return None, uf_k

    return label_strip, None


def _anp_preco_ponto(sheets: dict, label: str, combustivel_pk: str) -> tuple:
    """Resolve o preço médio de um combustível para um ponto (label de cidade/estado).

    Hierarquia: Município → Capital → Estado → Região → Brasil
    Retorna (preco_float | None, nivel_str, descricao_str).
    """
    municipio, uf = _parse_label_localizacao(label)
    if not uf and not municipio:
        return None, "—", "—"

    # Tenta extrair preço pelo nível mais detalhado disponível
    rows = _anp_extrair_precos(sheets, uf=uf, municipio=municipio)
    if rows:
        for r in rows:
            if r["_pk"] == combustivel_pk:
                desc = municipio or UF_NOME.get(uf or "", uf or "")
                return r["Preço Médio"], r["Nível"], desc

    # Fallback: apenas estado
    if uf:
        rows_uf = _anp_extrair_precos(sheets, uf=uf)
        for r in rows_uf:
            if r["_pk"] == combustivel_pk:
                return r["Preço Médio"], "Estado", UF_NOME.get(uf, uf)

    # Fallback: Brasil
    if "brasil" in sheets:
        df_b   = sheets["brasil"]
        b_prod = _anp_col(df_b, "produto")
        b_med  = _anp_col(df_b, "medio revenda", "media revenda", "preco medio")
        b_uni  = _anp_col(df_b, "unidade")
        b_npos = _anp_col(df_b, "postos pesq", "numero de postos", "n postos")
        if b_prod and b_med:
            for r in _anp_preco_medio(df_b, None, None, b_prod, b_med, b_uni, b_npos):
                if r["_pk"] == combustivel_pk:
                    return r["Preço Médio"], "Brasil", "Média Nacional"

    return None, "—", "—"


def _anp_precos_por_fuel_brasil(sheets):
    """Retorna dict {fuel_pk: preco_medio} do nível Brasil."""
    if "brasil" not in sheets:
        return {}
    df_b  = sheets["brasil"]
    c_prod = _anp_col(df_b, "produto")
    c_med  = _anp_col(df_b, "medio revenda", "media revenda", "preco medio")
    c_uni  = _anp_col(df_b, "unidade")
    c_npos = _anp_col(df_b, "postos pesq", "numero de postos")
    if not c_prod or not c_med:
        return {}
    return {r["_pk"]: r["Preço Médio"]
            for r in _anp_preco_medio(df_b, None, None, c_prod, c_med, c_uni, c_npos)}


def _anp_precos_por_fuel_ufs(sheets, ufs):
    """Retorna dict {fuel_pk: preco_medio} média dos estados listados."""
    acum: dict = {}
    for uf in ufs:
        for r in _anp_extrair_precos(sheets, uf=uf):
            acum.setdefault(r["_pk"], []).append(r["Preço Médio"])
    return {pk: sum(v) / len(v) for pk, v in acum.items()}


def _anp_precos_por_fuel_por_uf(sheets, ufs):
    """Retorna dict {fuel_pk: {uf: preco_medio}} para cada estado."""
    result: dict = {}
    for uf in ufs:
        for r in _anp_extrair_precos(sheets, uf=uf):
            result.setdefault(r["_pk"], {})[uf] = r["Preço Médio"]
    return result


def _calcular_comparativo_pf_anp(df_pp, cnpjs_pf, sheets_anp, ufs=None):
    """
    Calcula comparativo Pró-Frotas (Preço Posto) vs ANP.

    Retorna lista de dicts com:
      combustivel_label, combustivel_pk,
      preco_pf_med, preco_pf_min, preco_pf_max, n_postos_pf,
      preco_anp, nivel_anp,
      delta_abs, delta_pct, economia_100l, data_atualizacao
    """
    if df_pp is None or df_pp.empty or not cnpjs_pf or sheets_anp is None:
        return []

    # Filtra só postos Pró-Frotas
    df_pf = df_pp[df_pp["cnpj_norm"].isin(cnpjs_pf)].copy()
    if df_pf.empty:
        return []

    # Normaliza os PKs da planilha PP → PKs canônicos ANP
    # Isso consolida variantes como "DIESEL S-10 COMUM" + "DIESEL S-10 ADITIVADO"
    # em um único grupo "OLEO DIESEL S10" para gerar um card por tipo de combustível.
    df_pf["combustivel_pk"] = df_pf["combustivel_pk"].map(
        lambda pk: _PP_PARA_ANP_PK.get(pk, pk)
    )

    # Preços ANP de referência
    if ufs:
        precos_anp = _anp_precos_por_fuel_ufs(sheets_anp, ufs)
        nivel_anp  = UF_NOME.get(ufs[0], ufs[0]) if len(ufs) == 1 else f"{len(ufs)} estados"
    else:
        precos_anp = _anp_precos_por_fuel_brasil(sheets_anp)
        nivel_anp  = "Brasil"

    resultado = []
    for pk, grp in df_pf.groupby("combustivel_pk"):
        # ── Resolução de PK: PP → ANP ──────────────────────────────
        # 1) Tenta match direto no dicionário ANP
        preco_anp = precos_anp.get(pk)

        # 2) Usa tabela de mapeamento explícita (cobre "DIESEL COMUM" → "OLEO DIESEL" etc.)
        if preco_anp is None:
            anp_canonical = _PP_PARA_ANP_PK.get(pk)
            if anp_canonical:
                preco_anp = precos_anp.get(anp_canonical)

        # 3) Fallback: substring bidirecional (último recurso)
        if preco_anp is None:
            for anp_pk, anp_p in precos_anp.items():
                if pk in anp_pk or anp_pk in pk:
                    preco_anp = anp_p
                    break

        if preco_anp is None:
            continue

        preco_pf_med = grp["preco"].mean()
        preco_pf_min = grp["preco"].min()
        preco_pf_max = grp["preco"].max()
        n_postos     = int(grp["cnpj_norm"].nunique())
        # Label: usa PRODUTO_CURTO com o pk direto, depois tenta o canonical ANP, depois raw
        anp_can_lbl = _PP_PARA_ANP_PK.get(pk, pk)
        label = (PRODUTO_CURTO.get(pk)
                 or PRODUTO_CURTO.get(anp_can_lbl)
                 or grp["combustivel_label"].iloc[0].title())
        data_atz     = ""
        datas = grp["data_atualizacao"].dropna()
        if not datas.empty:
            data_atz = datas.iloc[0]

        delta_abs    = preco_pf_med - preco_anp
        delta_pct    = (delta_abs / preco_anp) * 100 if preco_anp else 0
        economia_100 = (preco_anp - preco_pf_med) * 100   # economia em 100 L

        # Detalhamento por estado (só quando há múltiplos UFs)
        por_uf = []
        if ufs and len(ufs) > 1:
            _pp_uf = _anp_precos_por_fuel_por_uf(sheets_anp, ufs)
            # Usa PK canonico ANP para buscar no dicionário por-UF
            _pk_anp = _PP_PARA_ANP_PK.get(pk, pk)
            for uf_i in ufs:
                p_uf = (_pp_uf.get(pk, {}).get(uf_i)
                        or _pp_uf.get(_pk_anp, {}).get(uf_i))
                if p_uf is not None:
                    d_abs_i = preco_pf_med - p_uf
                    d_pct_i = (d_abs_i / p_uf) * 100 if p_uf else 0
                    por_uf.append({
                        "uf":        uf_i,
                        "nome":      UF_NOME.get(uf_i, uf_i),
                        "preco_anp": round(p_uf, 3),
                        "delta_abs": round(d_abs_i, 3),
                        "delta_pct": round(d_pct_i, 1),
                    })

        resultado.append({
            "combustivel_label": label,
            "combustivel_pk":    pk,
            "preco_pf_med":      round(preco_pf_med, 3),
            "preco_pf_min":      round(preco_pf_min, 3),
            "preco_pf_max":      round(preco_pf_max, 3),
            "n_postos_pf":       n_postos,
            "preco_anp":         round(preco_anp, 3),
            "nivel_anp":         nivel_anp,
            "delta_abs":         round(delta_abs, 3),
            "delta_pct":         round(delta_pct, 1),
            "economia_100l":     round(economia_100, 2),
            "data_atualizacao":  data_atz,
            "por_uf":            por_uf,
        })

    resultado.sort(key=lambda x: x["combustivel_label"])
    return resultado


def _renderizar_comparativo_pf_anp(comparativo, subtitulo=""):
    """Renderiza cards de comparativo Pró-Frotas vs ANP — visual aprimorado."""
    if not comparativo:
        st.info("ℹ️ Sem dados suficientes para o comparativo. "
                "Carregue a planilha **Preço Posto** e a planilha **ANP** em ⚙️ Configurações.")
        return

    # ── Cabeçalho ─────────────────────────────────────────────────────────
    st.markdown(
        f"<div style='background:linear-gradient(135deg,#0d1b4b 0%,#1565c0 100%);"
        f"border-radius:14px;padding:18px 24px 14px;margin-bottom:20px'>"
        f"<div style='color:#fff;font-size:18px;font-weight:800;letter-spacing:.3px'>"
        f"📊 Preços Pró-Frotas vs ANP</div>"
        f"<div style='color:rgba(255,255,255,.8);font-size:13px;margin-top:4px'>"
        f"{subtitulo or 'Comparativo por combustível — preço médio dos postos credenciados'}"
        f"</div>"
        f"</div>",
        unsafe_allow_html=True,
    )

    # ── Grade de cards — 3 colunas (máx 6 combustíveis → 2 linhas × 3) ───
    n_cols = min(len(comparativo), 3)
    cols   = st.columns(n_cols)

    for i, item in enumerate(comparativo):
        cheaper   = item["delta_abs"] < 0
        cor_brd   = "#2e7d32" if cheaper else "#c62828"
        cor_hd    = "#2e7d32" if cheaper else "#c62828"
        cor_bg    = "#e8f5e9" if cheaper else "#ffebee"
        cor_delta = "#1b5e20" if cheaper else "#b71c1c"
        sinal     = "▼" if cheaper else "▲"
        icone_eco = "💚" if cheaper else "🔴"
        txt_eco   = (f"Economia de R$ {_brl(abs(item['economia_100l']))}/100 L"
                     if cheaper
                     else f"Custo adicional de R$ {_brl(abs(item['economia_100l']))}/100 L")

        # ── Breakdown por estado (só rota com múltiplos UFs) ──────────────
        por_uf = item.get("por_uf", [])
        if por_uf:
            linhas_uf = ""
            for pu in por_uf:
                c_uf  = "#1b5e20" if pu["delta_abs"] < 0 else "#b71c1c"
                s_uf  = "▼" if pu["delta_abs"] < 0 else "▲"
                linhas_uf += (
                    f"<tr style='border-top:1px solid #e8e8e8'>"
                    f"<td style='padding:4px 6px;color:#333'>{pu['nome']}</td>"
                    f"<td style='padding:4px 6px;text-align:right;color:#555'>"
                    f"R$ {_brl(pu['preco_anp'], 3)}</td>"
                    f"<td style='padding:4px 6px;text-align:right;font-weight:700;color:{c_uf}'>"
                    f"{s_uf} {abs(pu['delta_pct']):.1f}%</td>"
                    f"</tr>"
                )
            tabela_uf_html = (
                f"<div style='margin-top:12px;border-top:1px solid #ddd;padding-top:10px'>"
                f"<div style='font-size:10px;font-weight:700;color:#888;letter-spacing:.8px;"
                f"margin-bottom:6px'>PREÇO ANP POR ESTADO</div>"
                f"<table style='width:100%;font-size:11px;border-collapse:collapse'>"
                f"<thead><tr style='color:#999'>"
                f"<th style='text-align:left;padding:2px 6px;font-weight:600'>Estado</th>"
                f"<th style='text-align:right;padding:2px 6px;font-weight:600'>ANP</th>"
                f"<th style='text-align:right;padding:2px 6px;font-weight:600'>vs PF</th>"
                f"</tr></thead>"
                f"<tbody>{linhas_uf}</tbody>"
                f"</table>"
                f"</div>"
            )
        else:
            tabela_uf_html = ""

        data_footer = (
            f"<div style='font-size:10px;color:#aaa;text-align:right;margin-top:8px'>"
            f"{item['n_postos_pf']} posto{'s' if item['n_postos_pf'] != 1 else ''} PF"
            f"{' · atualizado ' + item['data_atualizacao'] if item['data_atualizacao'] else ''}"
            f"</div>"
        )

        with cols[i % n_cols]:
            st.markdown(
                # Card container
                f"<div style='border:2px solid {cor_brd};border-radius:14px;"
                f"overflow:hidden;margin-bottom:14px;"
                f"box-shadow:0 3px 10px rgba(0,0,0,.1)'>"
                # Header: fuel name
                f"<div style='background:{cor_hd};padding:10px 16px;"
                f"display:flex;justify-content:space-between;align-items:center'>"
                f"<span style='color:#fff;font-weight:800;font-size:15px'>"
                f"⛽ {item['combustivel_label']}</span>"
                f"<span style='color:rgba(255,255,255,.85);font-size:11px'>"
                f"ref. ANP: {item['nivel_anp']}</span>"
                f"</div>"
                # Body
                f"<div style='padding:14px 16px'>"
                # PF price (hero left) vs ANP (secondary right)
                f"<div style='display:flex;justify-content:space-between;"
                f"align-items:baseline;margin-bottom:6px'>"
                f"<div>"
                f"<div style='font-size:10px;color:#888;margin-bottom:2px'>⭐ Pró-Frotas médio</div>"
                f"<div style='font-size:24px;font-weight:900;color:#1565c0;line-height:1'>"
                f"R$ {_brl(item['preco_pf_med'], 3)}</div>"
                f"</div>"
                f"<div style='text-align:right'>"
                f"<div style='font-size:10px;color:#888;margin-bottom:2px'>📊 Ref. ANP</div>"
                f"<div style='font-size:18px;font-weight:700;color:#555;line-height:1'>"
                f"R$ {_brl(item['preco_anp'], 3)}</div>"
                f"</div>"
                f"</div>"
                # Delta badge (hero)
                f"<div style='background:{cor_bg};border-radius:10px;"
                f"padding:10px 14px;margin-top:10px;"
                f"display:flex;justify-content:space-between;align-items:center'>"
                f"<div style='color:{cor_delta};font-size:28px;font-weight:900;line-height:1'>"
                f"{sinal} {abs(item['delta_pct']):.1f}%</div>"
                f"<div style='text-align:right'>"
                f"<div style='color:{cor_delta};font-size:16px;font-weight:800'>"
                f"{sinal} R$ {_brl(abs(item['delta_abs']), 3)}/L</div>"
                f"<div style='color:{cor_delta};font-size:11px;margin-top:2px'>"
                f"{icone_eco} {txt_eco}</div>"
                f"</div>"
                f"</div>"
                # Intervalo min/max PF
                f"<div style='display:flex;justify-content:space-between;"
                f"font-size:10px;color:#999;margin-top:8px'>"
                f"<span>PF mín: R$ {_brl(item['preco_pf_min'], 3)}</span>"
                f"<span>PF máx: R$ {_brl(item['preco_pf_max'], 3)}</span>"
                f"</div>"
                # Per-state table (rota)
                f"{tabela_uf_html}"
                # Footer
                f"{data_footer}"
                f"</div>"  # end body
                f"</div>",  # end card
                unsafe_allow_html=True,
            )


def _renderizar_precos_anp(uf, municipio=None, ufs_multiplas=None):
    """Renderiza aba de preços ANP.

    Modo 1 (sem rota): indicadores por Município/Capital/Estado + referências Região e Brasil
    Modo 2 (com rota): tabela pivot Estado × Combustível + referências regional e nacional

    Fluxo de carregamento:
      1. Se já há dados em session_state → exibe direto
      2. Se não há dados → tenta auto-fetch (uma vez por sessão)
      3. Se auto-fetch falha ou nunca tentado → exibe widget de upload limpo
    """
    _cache = st.session_state.get("_precos_anp_cache", {})
    sheets = _cache.get("sheets")
    semana = _cache.get("semana")

    # ── 1. Auto-fetch na primeira abertura da aba (uma vez por sessão) ──
    if sheets is None and not st.session_state.get("_anp_fetch_tentado"):
        st.session_state["_anp_fetch_tentado"] = True
        with st.spinner("📡 Buscando planilha de preços ANP automaticamente…"):
            _raw, _sem, _err = buscar_precos_anp()
        if _raw:
            _sheets = _anp_processar_arquivo(io.BytesIO(_raw))
            if _sheets:
                st.session_state["_precos_anp_cache"] = {"sheets": _sheets, "semana": _sem}
                sheets  = _sheets
                semana  = _sem
                st.session_state["_anp_fetch_erro"] = None

    # ── 2. Se ainda sem dados → UI de carregamento prominente ──────────
    if sheets is None:
        st.markdown(
            "<div style='font-size:15px;font-weight:600;margin-bottom:8px'>"
            "💰 Preços Médios ANP</div>",
            unsafe_allow_html=True,
        )

        # Botão de retry (tenta de novo sem esperar próxima sessão)
        col_btn, col_link = st.columns([1, 2])
        with col_btn:
            if st.button("🔄 Tentar buscar automaticamente", use_container_width=True,
                         key="btn_buscar_precos"):
                with st.spinner("📡 Baixando planilha da ANP…"):
                    _raw, _sem, _err = buscar_precos_anp()
                if _raw:
                    _sheets = _anp_processar_arquivo(io.BytesIO(_raw))
                    if _sheets:
                        st.session_state["_precos_anp_cache"] = {"sheets": _sheets, "semana": _sem}
                        st.session_state["_anp_fetch_erro"] = None
                        st.rerun()
                    else:
                        st.session_state["_anp_fetch_erro"] = "Planilha baixada mas não reconhecida."
                else:
                    st.session_state["_anp_fetch_erro"] = _err
        with col_link:
            st.markdown(
                "<div style='margin-top:8px;font-size:12px;color:#555'>"
                "Ou baixe manualmente em "
                "<a href='https://www.gov.br/anp/pt-br/assuntos/precos-e-defesa-da-concorrencia"
                "/precos/levantamento-de-precos-de-combustiveis-ultimas-semanas-pesquisadas' "
                "target='_blank'>gov.br/anp → Levantamento de Preços</a> "
                "e faça upload abaixo.</div>",
                unsafe_allow_html=True,
            )

        _erro = st.session_state.get("_anp_fetch_erro")
        if _erro:
            st.warning(
                f"⚠️ Busca automática indisponível neste momento "
                f"(o site da ANP bloqueou o acesso direto).  \n"
                f"**Faça upload manual** da planilha abaixo — "
                f"ela fica salva durante toda a sessão."
            )

        # Upload direto (sem expander)
        st.markdown("**📎 Upload da planilha ANP (.xlsx)**")
        arq = st.file_uploader(
            "Selecione o arquivo resumo_semanal_lpc_*.xlsx",
            type=["xlsx", "xls"],
            key="upload_precos_anp",
        )
        if arq:
            with st.spinner("🔍 Processando planilha…"):
                try:
                    _sheets = _anp_processar_arquivo(io.BytesIO(arq.read()))
                    if not _sheets:
                        st.error("❌ Nenhuma aba reconhecida. Verifique se é a planilha correta.")
                    else:
                        _sem = arq.name.replace(".xlsx", "").replace(".xls", "")
                        st.session_state["_precos_anp_cache"] = {"sheets": _sheets, "semana": _sem}
                        st.session_state["_anp_fetch_erro"] = None
                        st.rerun()
                except Exception as ex:
                    st.error(f"❌ Erro ao ler arquivo: {ex}")
        return

    # ── 3. Dados disponíveis ── cabeçalho compacto com opção de trocar ──
    with st.expander(f"✅ Planilha carregada: **{semana}** · {', '.join(sheets.keys())}",
                     expanded=False):
        col_re, col_up2 = st.columns([1, 2])
        with col_re:
            if st.button("🔄 Recarregar da ANP", key="btn_reload_precos",
                         use_container_width=True):
                st.session_state.pop("_anp_fetch_tentado", None)
                st.session_state.pop("_precos_anp_cache", None)
                st.rerun()
        with col_up2:
            arq2 = st.file_uploader(
                "Substituir por outro arquivo", type=["xlsx", "xls"],
                key="upload_precos_anp_sub", label_visibility="collapsed",
            )
            if arq2:
                try:
                    _sh2 = _anp_processar_arquivo(io.BytesIO(arq2.read()))
                    if _sh2:
                        _sem2 = arq2.name.replace(".xlsx", "")
                        st.session_state["_precos_anp_cache"] = {"sheets": _sh2, "semana": _sem2}
                        st.rerun()
                except Exception:
                    pass

    st.divider()

    # ══════════════════════════════════════════════════════════════
    # MODO 2 — Rota: cards por combustível + referências
    # ══════════════════════════════════════════════════════════════
    if ufs_multiplas:

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

        # ══════════════════════════════════════════════════════════
        # CALCULADORA DE CUSTO DA ROTA
        # ══════════════════════════════════════════════════════════
        label_orig = st.session_state.get("label_orig", "")
        label_dest = st.session_state.get("label_dest", "")
        dist_km    = st.session_state.get("dist_km", 0)

        # Combustíveis disponíveis na planilha (ordenados)
        comb_disponiveis = df_rota.drop_duplicates("Combustível")[["Combustível","_pk"]].values.tolist()
        comb_nomes = [c[0] for c in comb_disponiveis]
        comb_pks   = {c[0]: c[1] for c in comb_disponiveis}

        # Filtra combustíveis relevantes para frota (não GLP)
        comb_frota = [c for c in comb_nomes if "GLP" not in c.upper()]

        st.markdown(
            "<div style='background:linear-gradient(135deg,#0d1b4b 0%,#1565c0 100%);"
            "border-radius:14px;padding:20px 24px 16px;margin-bottom:20px'>"
            "<div style='color:#fff;font-size:18px;font-weight:700;margin-bottom:4px'>"
            "⛽ Calculadora de Custo da Rota</div>"
            f"<div style='color:rgba(255,255,255,.75);font-size:13px'>"
            f"{label_orig or '—'}  →  {label_dest or '—'}"
            f"{'  ·  ' + str(round(dist_km)) + ' km' if dist_km else ''}</div>"
            "</div>",
            unsafe_allow_html=True,
        )

        col_comb, col_cons = st.columns([2, 1])
        with col_comb:
            comb_sel = st.selectbox(
                "Combustível", comb_frota or comb_nomes,
                key="calc_comb_sel",
                label_visibility="visible",
            )
        with col_cons:
            consumo = st.number_input(
                "Consumo (km/L)", min_value=1.0, max_value=40.0,
                value=12.0, step=0.5, key="calc_consumo",
                help="Consumo médio do veículo em km por litro",
            )

        if comb_sel and dist_km and consumo:
            pk_sel = comb_pks.get(comb_sel, _anp_norm(comb_sel))

            # Preço origem
            p_orig,  niv_orig,  desc_orig  = _anp_preco_ponto(sheets, label_orig, pk_sel)
            # Preço destino
            p_dest,  niv_dest,  desc_dest  = _anp_preco_ponto(sheets, label_dest, pk_sel)
            # Preços por estado da rota
            precos_rota = {}
            for uf_r in ufs_multiplas:
                rows_u = _anp_extrair_precos(sheets, uf=uf_r)
                for r in rows_u:
                    if r["_pk"] == pk_sel:
                        precos_rota[uf_r] = r["Preço Médio"]
            p_med_rota = round(sum(precos_rota.values()) / len(precos_rota), 3) if precos_rota else None
            p_min_rota = min(precos_rota.values()) if precos_rota else None
            uf_min_rota = min(precos_rota, key=precos_rota.get) if precos_rota else None

            litros = dist_km / consumo

            def _custo(p):
                return round(p * litros, 2) if p else None

            custo_orig  = _custo(p_orig)
            custo_dest  = _custo(p_dest)
            custo_med   = _custo(p_med_rota)
            custo_min   = _custo(p_min_rota)

            # Montagem do HTML dos cards de custo
            def _card_custo(titulo, subtitulo, preco, custo, nivel, cor_header="#1565c0", destaque=False):
                if preco is None:
                    return (f"<div class='cc-card'>"
                            f"<div class='cc-head' style='background:{cor_header}'>"
                            f"<div class='cc-titulo'>{titulo}</div>"
                            f"<div class='cc-sub'>{subtitulo}</div></div>"
                            f"<div class='cc-body'><div class='cc-nd'>Preço não disponível</div></div></div>")
                econ = ""
                if custo_orig and custo and custo < custo_orig:
                    econ_val = custo_orig - custo
                    econ = (f"<div class='cc-econ'>💚 Economia de "
                            f"<b>R$ {_brl(econ_val)}</b> vs origem</div>")
                badge = "<span class='cc-best'>✦ MAIS BARATO</span>" if destaque else ""
                return (
                    f"<div class='cc-card{' cc-best-card' if destaque else ''}'>"
                    f"<div class='cc-head' style='background:{cor_header}'>"
                    f"<div class='cc-titulo'>{titulo}{badge}</div>"
                    f"<div class='cc-sub'>{subtitulo} · {nivel}</div></div>"
                    f"<div class='cc-body'>"
                    f"<div class='cc-preco-label'>Preço médio</div>"
                    f"<div class='cc-preco'>R$ {_brl(preco, 3)}<span class='cc-unidade'>/L</span></div>"
                    f"<div class='cc-litros'>{litros:.1f} L necessários</div>"
                    f"<div class='cc-custo-label'>Custo estimado</div>"
                    f"<div class='cc-custo'>R$ {_brl(custo)}</div>"
                    f"{econ}"
                    f"</div></div>"
                )

            # Determina qual é o mais barato
            opcoes_preco = {k: v for k, v in {
                "orig": p_orig, "dest": p_dest, "min": p_min_rota
            }.items() if v is not None}
            mais_barato = min(opcoes_preco, key=opcoes_preco.get) if opcoes_preco else None

            cards_html = (
                _card_custo(
                    f"📍 {label_orig or 'Origem'}",
                    desc_orig, p_orig, custo_orig, niv_orig,
                    cor_header="#1565c0",
                    destaque=(mais_barato == "orig"),
                ) +
                _card_custo(
                    f"🏁 {label_dest or 'Destino'}",
                    desc_dest, p_dest, custo_dest, niv_dest,
                    cor_header="#37474f",
                    destaque=(mais_barato == "dest"),
                ) +
                _card_custo(
                    f"🟢 Menor preço ({uf_min_rota or '—'})",
                    UF_NOME.get(uf_min_rota or "", uf_min_rota or "—"),
                    p_min_rota, custo_min, "Estado",
                    cor_header="#2e7d32",
                    destaque=(mais_barato == "min"),
                )
            )

            # Adiciona card de preço médio da rota se diferente do mínimo
            if p_med_rota and p_med_rota != p_min_rota:
                custo_med_val = _custo(p_med_rota)
                cards_html += (
                    f"<div class='cc-card'>"
                    f"<div class='cc-head' style='background:#4527a0'>"
                    f"<div class='cc-titulo'>📊 Média da Rota</div>"
                    f"<div class='cc-sub'>{len(precos_rota)} estados</div></div>"
                    f"<div class='cc-body'>"
                    f"<div class='cc-preco-label'>Preço médio</div>"
                    f"<div class='cc-preco'>R$ {_brl(p_med_rota, 3)}<span class='cc-unidade'>/L</span></div>"
                    f"<div class='cc-litros'>{litros:.1f} L necessários</div>"
                    f"<div class='cc-custo-label'>Custo estimado</div>"
                    f"<div class='cc-custo'>R$ {_brl(custo_med_val)}</div>"
                    f"</div></div>"
                )

            # ── Card Pró-Frotas (Preço Posto real) ───────────────────
            _pp_df_calc    = st.session_state.get("_pp_df")
            _cnpjs_pf_calc = st.session_state.get("cnpjs_pro_frotas", set())
            if _pp_df_calc is not None and _cnpjs_pf_calc:
                _df_pf_calc = _pp_df_calc[_pp_df_calc["cnpj_norm"].isin(_cnpjs_pf_calc)]
                # Filtra pelo pk do combustível selecionado (match exato ou parcial)
                _pk_mask = _df_pf_calc["combustivel_pk"].apply(
                    lambda x: x == pk_sel or pk_sel in x or x in pk_sel)
                _df_pf_fuel = _df_pf_calc[_pk_mask]
                if not _df_pf_fuel.empty:
                    _p_pf_real   = _df_pf_fuel["preco"].mean()
                    _n_pf_real   = _df_pf_fuel["cnpj_norm"].nunique()
                    _custo_pf    = _custo(_p_pf_real)
                    _data_pf     = _df_pf_fuel["data_atualizacao"].dropna().iloc[0] \
                                   if not _df_pf_fuel["data_atualizacao"].dropna().empty else ""
                    # Delta vs ANP médio da rota
                    _delta_pf    = _p_pf_real - p_med_rota if p_med_rota else None
                    _delta_pct   = (_delta_pf / p_med_rota * 100) if p_med_rota and _delta_pf is not None else None
                    _delta_html  = ""
                    if _delta_pf is not None:
                        _d_cor   = "#2e7d32" if _delta_pf < 0 else "#c62828"
                        _d_sinal = "▼" if _delta_pf < 0 else "▲"
                        _d_txt   = "abaixo" if _delta_pf < 0 else "acima"
                        _delta_html = (
                            f"<div style='font-size:10px;color:{_d_cor};"
                            f"background:{'#e8f5e9' if _delta_pf<0 else '#ffebee'};"
                            f"border-radius:4px;padding:3px 6px;margin-top:6px;text-align:center'>"
                            f"{_d_sinal} R$ {_brl(abs(_delta_pf), 3)} "
                            f"({abs(_delta_pct):.1f}%) {_d_txt} da média ANP</div>"
                        )
                    _pf_dest = (_custo_pf is not None and
                                all(v is None or _custo_pf <= v
                                    for v in [custo_orig, custo_dest, custo_min, custo_med_val]))
                    _pf_best_cls   = " cc-best-card" if _pf_dest else ""
                    _pf_best_badge = "<span class='cc-best'>✦ MAIS BARATO</span>" if _pf_dest else ""
                    _pf_data_html  = f" · {_data_pf}" if _data_pf else ""
                    cards_html += (
                        f"<div class='cc-card{_pf_best_cls}'>"
                        f"<div class='cc-head' style='background:#0d47a1'>"
                        f"<div class='cc-titulo'>⭐ Pró-Frotas{_pf_best_badge}</div>"
                        f"<div class='cc-sub'>{_n_pf_real} postos{_pf_data_html}</div></div>"
                        f"<div class='cc-body'>"
                        f"<div class='cc-preco-label'>Preço médio real</div>"
                        f"<div class='cc-preco'>R$ {_brl(_p_pf_real, 3)}"
                        f"<span class='cc-unidade'>/L</span></div>"
                        f"<div class='cc-litros'>{litros:.1f} L necessários</div>"
                        f"<div class='cc-custo-label'>Custo estimado</div>"
                        f"<div class='cc-custo'>R$ {_brl(_custo_pf)}</div>"
                        f"{_delta_html}"
                        f"</div></div>"
                    )

            st.markdown(f"""
<style>
.cc-grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(200px,1fr));
          gap:12px;margin-bottom:24px}}
.cc-card{{border-radius:12px;overflow:hidden;
          box-shadow:0 2px 10px rgba(0,0,0,.12);background:#fff}}
.cc-best-card{{box-shadow:0 4px 16px rgba(46,125,50,.35);
               outline:2px solid #2e7d32}}
.cc-head{{padding:12px 16px 10px;color:#fff}}
.cc-titulo{{font-size:13px;font-weight:700;line-height:1.3;
            display:flex;align-items:center;gap:6px;flex-wrap:wrap}}
.cc-sub{{font-size:11px;opacity:.8;margin-top:3px}}
.cc-best{{background:rgba(255,255,255,.25);font-size:9px;font-weight:800;
          padding:2px 6px;border-radius:8px;letter-spacing:.4px}}
.cc-body{{padding:14px 16px 12px}}
.cc-preco-label,.cc-custo-label{{font-size:10px;color:#888;
                                  text-transform:uppercase;letter-spacing:.5px}}
.cc-preco{{font-size:22px;font-weight:800;color:#0d1b4b;margin:2px 0 4px}}
.cc-unidade{{font-size:12px;font-weight:400;color:#666}}
.cc-litros{{font-size:11px;color:#888;margin-bottom:10px}}
.cc-custo{{font-size:20px;font-weight:800;color:#1565c0}}
.cc-nd{{font-size:13px;color:#999;padding:20px 0;text-align:center}}
.cc-econ{{font-size:11px;color:#2e7d32;margin-top:6px;
          background:#e8f5e9;padding:4px 8px;border-radius:6px}}
</style>
<div class='cc-grid'>{cards_html}</div>
""", unsafe_allow_html=True)

            # Nota de rodapé
            st.caption(
                f"*Cálculo baseado em {dist_km:.0f} km ÷ {consumo:.1f} km/L = {litros:.1f} litros."
                f" Preços: ANP semana {semana or '—'}. Valores estimados.*"
            )

        st.divider()

        # ── Cabeçalho visual ──────────────────────────────────────
        ufs_ord = list(dict.fromkeys(df_rota["UF"].tolist()))   # ordem original da rota
        st.markdown(
            "<h3 style='margin:0 0 4px 0;font-size:20px;color:#0d1b4b'>💰 Preços Médios por Estado</h3>"
            f"<p style='margin:0 0 18px 0;font-size:13px;color:#555'>Rota: "
            f"{'  →  '.join(f'<b>{u}</b>' for u in ufs_ord)}"
            f" &nbsp;·&nbsp; Semana: <b>{semana or '—'}</b></p>",
            unsafe_allow_html=True,
        )

        # ── Cards de combustível × estado ─────────────────────────
        combustiveis = df_rota["Combustível"].unique().tolist()
        ordem_comb = {_anp_norm(k): i for i, k in enumerate(PRODUTOS_CHAVE)}
        combustiveis.sort(key=lambda c: ordem_comb.get(_anp_norm(c), 99))

        for comb in combustiveis:
            df_c = df_rota[df_rota["Combustível"] == comb]
            precos = {row["UF"]: row["Preço Médio"] for _, row in df_c.iterrows()}
            if not precos: continue

            p_vals   = list(precos.values())
            p_min    = min(p_vals)
            p_max    = max(p_vals)
            unidade  = df_c["Unidade"].iloc[0] if not df_c.empty else "R$/L"

            # Linha HTML por combustível
            cells = ""
            for uf_r in ufs_ord:
                preco = precos.get(uf_r)
                if preco is None:
                    cells += f"<div class='pc-cell pc-na'><span class='pc-uf'>{uf_r}</span><span class='pc-val'>—</span></div>"
                    continue
                diff = preco - p_min
                pct  = (diff / (p_max - p_min) * 100) if p_max > p_min else 0
                # Cor: verde (min) → amarelo → vermelho (max)
                if pct < 1:
                    bg, txt, badge = "#e8f5e9", "#1b5e20", "MIN"
                elif pct > 98:
                    bg, txt, badge = "#ffebee", "#b71c1c", "MAX"
                else:
                    bg, txt, badge = "#fff8e1", "#4e342e", ""
                badge_html = f"<span class='pc-badge' style='background:{txt};color:#fff'>{badge}</span>" if badge else ""
                cells += (
                    f"<div class='pc-cell' style='background:{bg}'>"
                    f"<span class='pc-uf'>{uf_r}</span>"
                    f"<span class='pc-val' style='color:{txt}'>R$ {_brl(preco, 3)}</span>"
                    f"<span class='pc-uni'>{unidade}</span>"
                    f"{badge_html}</div>"
                )

            st.markdown(f"""
<div class='pc-row'>
  <div class='pc-label'>{comb}</div>
  <div class='pc-cells'>{cells}</div>
</div>""", unsafe_allow_html=True)

        # CSS injetado uma vez
        st.markdown("""
<style>
.pc-row{display:flex;align-items:stretch;margin-bottom:8px;border-radius:10px;
        overflow:hidden;box-shadow:0 1px 4px rgba(0,0,0,.08)}
.pc-label{min-width:160px;max-width:160px;background:#0d1b4b;color:#fff;
          display:flex;align-items:center;padding:10px 14px;
          font-size:13px;font-weight:600;line-height:1.3}
.pc-cells{display:flex;flex:1;flex-wrap:wrap}
.pc-cell{flex:1;min-width:110px;display:flex;flex-direction:column;
         align-items:center;justify-content:center;padding:10px 8px;
         border-right:1px solid rgba(0,0,0,.06);gap:2px}
.pc-cell:last-child{border-right:none}
.pc-na{background:#f5f5f5}
.pc-uf{font-size:11px;font-weight:700;color:#555;letter-spacing:.5px;text-transform:uppercase}
.pc-val{font-size:15px;font-weight:700}
.pc-uni{font-size:10px;color:#888}
.pc-badge{font-size:9px;font-weight:700;padding:1px 5px;border-radius:10px;
          margin-top:2px;letter-spacing:.3px}
</style>""", unsafe_allow_html=True)

        # ── Referências (Região + Brasil) ─────────────────────────
        regioes_rota = [r for r in df_rota["Nome Região"].dropna().unique() if r]
        ref_rows: dict = {}   # pk → {brasil, regioes...}

        if "brasil" in sheets:
            df_b  = sheets["brasil"]
            b_p   = _anp_col(df_b, "produto")
            b_m   = _anp_col(df_b, "medio revenda", "media revenda", "preco medio")
            b_u   = _anp_col(df_b, "unidade")
            b_n   = _anp_col(df_b, "postos pesq", "numero de postos", "n postos")
            if b_p and b_m:
                for r in _anp_preco_medio(df_b, None, None, b_p, b_m, b_u, b_n):
                    ref_rows.setdefault(r["Combustível"], {})["🌎 Brasil"] = r["Preço Médio"]

        if regioes_rota and "regioes" in sheets:
            df_reg = sheets["regioes"]
            rg_r   = _anp_col(df_reg, "regiao")
            rg_p   = _anp_col(df_reg, "produto")
            rg_m   = _anp_col(df_reg, "medio revenda", "media revenda", "preco medio")
            rg_u   = _anp_col(df_reg, "unidade")
            rg_n   = _anp_col(df_reg, "postos pesq", "numero de postos", "n postos")
            if rg_r and rg_p and rg_m:
                for reg in regioes_rota:
                    for r in _anp_preco_medio(df_reg, rg_r, reg, rg_p, rg_m, rg_u, rg_n):
                        ref_rows.setdefault(r["Combustível"], {})[f"📍 {reg.title()}"] = r["Preço Médio"]

        if ref_rows:
            st.markdown(
                "<div style='margin:24px 0 10px;font-size:14px;font-weight:700;"
                "color:#0d1b4b;border-left:4px solid #1565c0;padding-left:10px'>"
                "Referências: Região e Brasil</div>",
                unsafe_allow_html=True,
            )
            # Constrói tabela HTML de referência
            combust_keys = [c for c in [row["Combustível"] for row in linhas_rota] if c in ref_rows]
            seen = set(); combust_keys = [x for x in combust_keys if not (x in seen or seen.add(x))]
            ref_cols = []
            for v in ref_rows.values():
                for k in v: 
                    if k not in ref_cols: ref_cols.append(k)

            header_cells = "".join(f"<th>{c}</th>" for c in ref_cols)
            rows_html = ""
            for comb in combust_keys:
                vals = ref_rows.get(comb, {})
                row_cells = ""
                for col in ref_cols:
                    v = vals.get(col)
                    row_cells += f"<td>{'R$ '+_brl(v,3) if v else '—'}</td>"
                rows_html += f"<tr><td class='rt-comb'>{comb}</td>{row_cells}</tr>"

            st.markdown(f"""
<style>
.ref-table{{width:100%;border-collapse:collapse;font-size:13px;margin-bottom:16px}}
.ref-table th{{background:#1565c0;color:#fff;padding:8px 12px;text-align:right;font-weight:600}}
.ref-table th:first-child{{text-align:left}}
.ref-table td{{padding:7px 12px;border-bottom:1px solid #e8eaf6;text-align:right;color:#333}}
.ref-table tr:hover td{{background:#f3f4ff}}
.ref-table .rt-comb{{text-align:left;font-weight:600;color:#0d1b4b}}
.ref-table tr:last-child td{{border-bottom:none}}
</style>
<table class='ref-table'>
<thead><tr><th>Combustível</th>{header_cells}</tr></thead>
<tbody>{rows_html}</tbody>
</table>""", unsafe_allow_html=True)
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
        municipio if nivel in ("Município", "Capital")
        else UF_NOME.get(uf or "", uf or "")
    )
    uf_label = f" ({uf})" if uf else ""

    # ── Cabeçalho visual ──────────────────────────────────────────
    st.markdown(
        f"<h3 style='margin:0 0 2px 0;font-size:20px;color:#0d1b4b'>💰 Preços em {scope_label}{uf_label}</h3>"
        + (f"<p style='margin:0 0 18px 0;font-size:13px;color:#555'>"
           f"Região: <b>{nome_regiao.title()}</b>  ·  Nível: <i>{nivel}</i>"
           f"  ·  Semana: <b>{semana or '—'}</b></p>" if nome_regiao else
           f"<p style='margin:0 0 18px 0;font-size:13px;color:#555'>"
           f"Nível: <i>{nivel}</i>  ·  Semana: <b>{semana or '—'}</b></p>"),
        unsafe_allow_html=True,
    )

    # ── Cards de combustível com comparativo hierárquico ──────────
    col_est = f"Estado ({UF_NOME.get(uf or '', uf or '')})"
    col_reg = f"Região ({nome_regiao.title()})" if nome_regiao else "Região"
    col_br  = "Base Nacional"

    # Cabeçalho de níveis
    st.markdown(f"""
<style>
.pr-grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:12px;margin-bottom:20px}}
.pr-card{{border-radius:12px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,.10);background:#fff}}
.pr-card-head{{padding:10px 14px 8px;background:#0d1b4b;color:#fff}}
.pr-card-head .pr-nome{{font-size:13px;font-weight:700}}
.pr-card-head .pr-preco{{font-size:24px;font-weight:800;letter-spacing:-.3px;margin:2px 0}}
.pr-card-head .pr-uni{{font-size:10px;opacity:.75}}
.pr-card-body{{padding:10px 14px}}
.pr-ref-row{{display:flex;justify-content:space-between;align-items:center;
             padding:4px 0;border-bottom:1px solid #f0f0f0;font-size:12px}}
.pr-ref-row:last-child{{border-bottom:none}}
.pr-ref-label{{color:#777;font-weight:500}}
.pr-ref-val{{font-weight:700;color:#333}}
.pr-delta-up{{color:#c62828;font-size:10px;margin-left:4px}}
.pr-delta-dn{{color:#2e7d32;font-size:10px;margin-left:4px}}
.pr-postos{{font-size:10px;color:#aaa;margin-top:6px;text-align:right}}
</style>
<div class='pr-grid'>""", unsafe_allow_html=True)

    for r in rows:
        pm     = r["Preço Médio"]
        r_est  = r.get("Ref. Estado")
        r_reg  = r.get("Ref. Região")
        r_br   = r.get("Ref. Brasil")
        uni    = r.get("Unidade", "R$/L")
        postos = r.get("Postos") or "?"

        def _delta_html(ref, label):
            if ref is None:
                return (f"<div class='pr-ref-row'>"
                        f"<span class='pr-ref-label'>{label}</span>"
                        f"<span class='pr-ref-val'>—</span></div>")
            diff = pm - ref
            cls  = "pr-delta-up" if diff > 0 else "pr-delta-dn"
            seta = "▲" if diff > 0 else "▼"
            arrow = f"<span class='{cls}'>{seta} {_brl(abs(diff), 3)}</span>"
            return (f"<div class='pr-ref-row'>"
                    f"<span class='pr-ref-label'>{label}</span>"
                    f"<span class='pr-ref-val'>R$ {_brl(ref, 3)}{arrow}</span>"
                    f"</div>")

        refs_html = ""
        if nivel in ("Município", "Capital"):
            refs_html += _delta_html(r_est, col_est)
        refs_html += _delta_html(r_reg, col_reg)
        refs_html += _delta_html(r_br,  col_br)

        st.markdown(f"""
<div class='pr-card'>
  <div class='pr-card-head'>
    <div class='pr-nome'>{r['Combustível']}</div>
    <div class='pr-preco'>R$ {_brl(pm, 3)}</div>
    <div class='pr-uni'>{uni}</div>
  </div>
  <div class='pr-card-body'>
    {refs_html}
    <div class='pr-postos'>{postos} postos pesquisados</div>
  </div>
</div>""", unsafe_allow_html=True)

    st.markdown("</div>", unsafe_allow_html=True)


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

def _marcar_df_completo(df_raw: pd.DataFrame) -> pd.DataFrame:
    """
    Aplica todas as marcações (pro_frotas, cercados, perfil_venda) em UMA ÚNICA cópia
    do DataFrame, usando operações vetorizadas (str.replace em vez de apply).
    Resultado é guardado em session_state para evitar reprocessamento a cada rerun.
    """
    cnpjs_pf   = st.session_state.get("cnpjs_pro_frotas", set())
    cnpjs_cer  = st.session_state.get("cnpjs_cercados",   set())
    perfil_map = st.session_state.get("perfil_venda_map", {})

    df = df_raw.copy()   # ← única cópia

    # ── CNPJ normalizado (vetorizado, C-level) ───────────────────────
    if "cnpj" in df.columns:
        df["_cnpj_norm"] = df["cnpj"].fillna("").str.replace(r'\D', '', regex=True)
    else:
        df["_cnpj_norm"] = ""

    # ── Pró-Frotas ───────────────────────────────────────────────────
    df["_pro_frotas"] = (
        df["_cnpj_norm"].isin(cnpjs_pf) if cnpjs_pf else False
    )

    # ── Cercados ─────────────────────────────────────────────────────
    df["_cercado"] = (
        df["_cnpj_norm"].isin(cnpjs_cer) if cnpjs_cer else False
    )

    # ── Perfil de Venda / Rodo Rede ──────────────────────────────────
    if perfil_map:
        df["_perfil_venda"] = df["_cnpj_norm"].map(perfil_map).fillna("")
        df["_rodo_rede"] = df["_perfil_venda"].str.upper().str.strip() == PERFIL_RODO_REDE
    else:
        df["_perfil_venda"] = ""
        df["_rodo_rede"] = False

    return df


def preparar_df(df_raw, distribuidoras_filtro, perfis_filtro=None):
    """
    Retorna df filtrado e marcado.
    A etapa de marcação (cara) é cacheada em session_state:
    só reprocessa quando df_raw ou os conjuntos PF/cercados/perfis mudam.
    """
    cnpjs_pf   = st.session_state.get("cnpjs_pro_frotas", set())
    cnpjs_cer  = st.session_state.get("cnpjs_cercados",   set())
    perfil_map = st.session_state.get("perfil_venda_map", {})

    # Chave de cache: muda só quando os dados ou marcadores mudam
    _mark_key = (
        id(df_raw),          # mesmo objeto Python → mesma chave
        len(df_raw),         # detecta injeção de novos postos PF
        len(cnpjs_pf),
        len(cnpjs_cer),
        len(perfil_map),
    )

    if st.session_state.get("_df_marcado_key") == _mark_key:
        df = st.session_state["_df_marcado"]
    else:
        df = _marcar_df_completo(df_raw)
        st.session_state["_df_marcado"]     = df
        st.session_state["_df_marcado_key"] = _mark_key

    # Filtros leves (indexação booleana — sem cópia extra desnecessária)
    if distribuidoras_filtro:
        df = df[df["distribuidora"].isin(distribuidoras_filtro)]
    if perfis_filtro and "_perfil_venda" in df.columns:
        df = df[df["_perfil_venda"].isin(perfis_filtro)]
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
        _cnpjs_repo, _msg_repo, _prev_repo, _perfil_repo, _coords_repo = _auto_carregar_pro_frotas_repo()
        if _cnpjs_repo:
            st.session_state["cnpjs_pro_frotas"]  = _cnpjs_repo
            st.session_state["_pf_fonte"]         = "repo"
            st.session_state["_pf_carregado_em"]  = _agora()
        if _perfil_repo:
            st.session_state["perfil_venda_map"]    = _perfil_repo
            st.session_state["perfis_pf_lista"]     = sorted(set(_perfil_repo.values()))
        if _coords_repo is not None and not _coords_repo.empty:
            st.session_state["pf_coords_df"] = _coords_repo

    # Fallback: CNPJs já carregados mas perfil_venda_map ainda ausente
    # (ocorre quando a sessão foi iniciada antes desta funcionalidade ser adicionada)
    if st.session_state.get("cnpjs_pro_frotas") and not st.session_state.get("perfil_venda_map"):
        _cnpjs_r2, _, _, _perfil_r2, _coords_r2 = _auto_carregar_pro_frotas_repo()
        if _perfil_r2:
            st.session_state["perfil_venda_map"]  = _perfil_r2
            st.session_state["perfis_pf_lista"]   = sorted(set(_perfil_r2.values()))
        if _coords_r2 is not None and not _coords_r2.empty:
            st.session_state.setdefault("pf_coords_df", _coords_r2)

    # Auto-load Postos Cercados (uma vez por sessão)
    if not st.session_state.get("cnpjs_cercados") and not st.session_state.get("_cercados_tentado"):
        st.session_state["_cercados_tentado"] = True
        _cnpjs_cer, _msg_cer, _ = _auto_carregar_cercados_repo()
        if _cnpjs_cer:
            st.session_state["cnpjs_cercados"]          = _cnpjs_cer
            st.session_state["_cercados_fonte"]         = "repo"
            st.session_state["_cercados_carregado_em"]  = _agora()

    # Auto-load Preço Posto — re-parseia se a versão do parser mudou
    _pp_ver_atual = st.session_state.get("_pp_parser_ver")
    if _pp_ver_atual != _PP_PARSER_VERSION:
        # Parser foi atualizado: descarta dado antigo e re-parseia
        st.session_state.pop("_pp_df", None)
        st.session_state.pop("_pp_tentado", None)
        _auto_carregar_precos_postos_repo.clear()
        st.session_state["_pp_parser_ver"] = _PP_PARSER_VERSION

    if st.session_state.get("_pp_df") is None and not st.session_state.get("_pp_tentado"):
        st.session_state["_pp_tentado"] = True
        _pp_df_tmp, _pp_msg_tmp, _ = _auto_carregar_precos_postos_repo()
        if _pp_df_tmp is not None:
            st.session_state["_pp_df"]         = _pp_df_tmp
            st.session_state["_pp_fonte"]       = "repo"
            st.session_state["_pp_carregado_em"] = _agora()

    # ── Modo de consulta — toggle buttons ─────────────────────
    st.markdown("<div class='sb-label'>Modo de Consulta</div>", unsafe_allow_html=True)
    if "modo_selecionado" not in st.session_state:
        st.session_state["modo_selecionado"] = "📍 Por Estado/Município"
    _modo_atual = st.session_state["modo_selecionado"]
    _col_m1, _col_m2 = st.columns(2)
    with _col_m1:
        if st.button(
            "📍\nEstado",
            use_container_width=True,
            type="primary" if _modo_atual == "📍 Por Estado/Município" else "secondary",
            key="btn_modo_estado",
        ):
            st.session_state["modo_selecionado"] = "📍 Por Estado/Município"
            st.rerun()
    with _col_m2:
        if st.button(
            "🗺️\nRota",
            use_container_width=True,
            type="primary" if _modo_atual == "🗺️ Por Rota" else "secondary",
            key="btn_modo_rota",
        ):
            st.session_state["modo_selecionado"] = "🗺️ Por Rota"
            st.rerun()
    modo = _modo_atual
    st.divider()

    # ── Modo 1 ────────────────────────────────────────────────
    if modo == "📍 Por Estado/Município":
        _fk_m1 = st.session_state.get("_form_key_m1", 0)
        st.markdown("<div class='sb-label'>Localização</div>", unsafe_allow_html=True)
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
            st.markdown("<div class='sb-label'>Filtrar por Bandeira</div>", unsafe_allow_html=True)
            distribuidoras_filtro = st.multiselect(
                "Bandeiras", st.session_state["distribuidoras_disponiveis"],
                placeholder="Todas as bandeiras", label_visibility="collapsed",
                key=f"mult_dist_{_fk_m1}")

        # Filtro de Perfil de Venda (Pró-Frotas)
        perfis_filtro_m1 = []
        _perfis_lista_m1 = st.session_state.get("perfis_pf_lista", [])
        if _perfis_lista_m1:
            st.markdown("<div class='sb-label'>Perfil de Venda ⭐</div>", unsafe_allow_html=True)
            perfis_filtro_m1 = st.multiselect(
                "Perfil de Venda", _perfis_lista_m1,
                placeholder="Todos os perfis", label_visibility="collapsed",
                key=f"mult_perfil_{_fk_m1}",
                help="Filtra os postos Pró-Frotas pelo perfil de venda. Postos não-PF sempre exibidos.",
            )

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

        st.markdown("<div class='sb-label'>Raio da rota</div>", unsafe_allow_html=True)
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
            st.markdown("<div class='sb-label'>Filtrar por Bandeira</div>", unsafe_allow_html=True)
            distribuidoras_filtro = st.multiselect(
                "Bandeiras", st.session_state["distribuidoras_rota"],
                placeholder="Todas as bandeiras", label_visibility="collapsed")

        # Filtro de Perfil de Venda — Modo Rota
        perfis_filtro_m2 = []
        _perfis_lista_m2 = st.session_state.get("perfis_pf_lista", [])
        if _perfis_lista_m2:
            st.markdown("<div class='sb-label'>Perfil de Venda ⭐</div>", unsafe_allow_html=True)
            perfis_filtro_m2 = st.multiselect(
                "Perfil de Venda", _perfis_lista_m2,
                placeholder="Todos os perfis", label_visibility="collapsed",
                key="mult_perfil_m2",
                help="Filtra os postos Pró-Frotas pelo perfil de venda.",
            )

    # ── Configurações (Pró-Frotas · Cercados · Preços PP · Base · Exportar) ──
    st.markdown("---")
    _pf_fonte  = st.session_state.get("_pf_fonte",  "manual")
    _pf_set    = st.session_state.get("cnpjs_pro_frotas", set())
    _pf_ts     = st.session_state.get("_pf_carregado_em", "")
    _cer_set   = st.session_state.get("cnpjs_cercados",   set())
    _cer_fonte = st.session_state.get("_cercados_fonte",  "manual")
    _cer_ts    = st.session_state.get("_cercados_carregado_em", "")
    _pp_df_sb  = st.session_state.get("_pp_df")
    _pp_fonte  = st.session_state.get("_pp_fonte",  "manual")
    _pp_ts     = st.session_state.get("_pp_carregado_em", "")

    # Mini-badges compactos acima do expander
    _col_b1, _col_b2 = st.columns(2)
    with _col_b1:
        if _pf_set:
            _pf_cor, _pf_brd, _pf_txt, _pf_ic = (
                ("#e8f5e9","#a5d6a7","#2e7d32","✅") if _pf_fonte == "repo"
                else ("#fff8e1","#ffe082","#f57f17","⭐")
            )
            st.markdown(
                f"<div style='background:{_pf_cor};border:1px solid {_pf_brd};"
                f"border-radius:8px;padding:6px 8px;font-size:10px;color:{_pf_txt};text-align:center'>"
                f"{_pf_ic} <b>Pró-Frotas</b><br>{len(_pf_set):,} CNPJs</div>",
                unsafe_allow_html=True,
            )
        else:
            st.markdown(
                "<div style='background:#fff3e0;border:1px solid #ffcc80;"
                "border-radius:8px;padding:6px 8px;font-size:10px;color:#e65100;text-align:center'>"
                "⚠️ <b>Pró-Frotas</b><br>não carregado</div>",
                unsafe_allow_html=True,
            )
    with _col_b2:
        if _cer_set:
            _cer_cor = "#fff8e1" if _cer_fonte == "manual" else "#fff3e0"
            _cer_brd = "#ffe082" if _cer_fonte == "manual" else "#ffcc80"
            st.markdown(
                f"<div style='background:{_cer_cor};border:1px solid {_cer_brd};"
                f"border-radius:8px;padding:6px 8px;font-size:10px;color:#e65100;text-align:center'>"
                f"⚠️ <b>Cercados</b><br>{len(_cer_set):,} postos</div>",
                unsafe_allow_html=True,
            )
        else:
            st.markdown(
                "<div style='background:#f5f5f5;border:1px solid #ddd;"
                "border-radius:8px;padding:6px 8px;font-size:10px;color:#999;text-align:center'>"
                "⚠️ <b>Cercados</b><br>não carregado</div>",
                unsafe_allow_html=True,
            )

    # Terceiro badge — Preços PP
    if _pp_df_sb is not None:
        _pp_n = len(_pp_df_sb["cnpj_norm"].unique()) if "cnpj_norm" in _pp_df_sb.columns else 0
        st.markdown(
            f"<div style='background:#e3f2fd;border:1px solid #90caf9;"
            f"border-radius:8px;padding:6px 10px;font-size:10px;color:#1565c0;"
            f"text-align:center;margin-bottom:6px'>"
            f"💲 <b>Preços PP</b><br>{_pp_n:,} postos</div>",
            unsafe_allow_html=True,
        )
    else:
        st.markdown(
            "<div style='background:#f5f5f5;border:1px solid #ddd;"
            "border-radius:8px;padding:6px 10px;font-size:10px;color:#999;"
            "text-align:center;margin-bottom:6px'>"
            "💲 <b>Preços PP</b><br>não carregado</div>",
            unsafe_allow_html=True,
        )

    with st.expander("⚙️  Configurações", expanded=False):
        tab_pf, tab_cer, tab_pp, tab_base = st.tabs(
            ["⭐ Pró-Frotas", "⚠️ Cercados", "💲 Preços PP", "🗃️ Base"]
        )

        # ── Tab Pró-Frotas ────────────────────────────────────
        with tab_pf:
            _pf_ts_html = (f"<br><span style='font-size:10px;opacity:.8'>🕐 {_pf_ts}</span>"
                           if _pf_ts else "")
            if _pf_set:
                _c = ("#e8f5e9","#a5d6a7","#2e7d32","✅") if _pf_fonte == "repo" \
                     else ("#fff8e1","#ffe082","#f57f17","⭐")
                _src = (f"<span style='font-size:10px;opacity:.8'>"
                        f"Fonte: <code>{ARQUIVO_PF_REPO}</code></span>"
                        if _pf_fonte == "repo" else "")
                st.markdown(
                    f"<div style='background:{_c[0]};border:1px solid {_c[1]};"
                    f"border-radius:8px;padding:8px 11px;font-size:11px;color:{_c[2]}'>"
                    f"{_c[3]} <b>{len(_pf_set):,} CNPJs</b> carregados"
                    f"{_pf_ts_html}<br>{_src}</div>",
                    unsafe_allow_html=True,
                )
            else:
                st.markdown(
                    f"<div style='background:#fff3e0;border:1px solid #ffcc80;"
                    f"border-radius:8px;padding:8px 11px;font-size:11px;color:#e65100'>"
                    f"⚠️ <b>Não carregado</b><br>"
                    f"<span style='font-size:10px'>Adicione <code>{ARQUIVO_PF_REPO}</code> "
                    f"ou faça upload.</span></div>",
                    unsafe_allow_html=True,
                )
            st.markdown("")
            if st.button("🔄 Recarregar do repositório", use_container_width=True,
                         help="Força nova leitura do pro_frotas.xlsx no GitHub",
                         key="btn_reload_pf_cfg"):
                _auto_carregar_pro_frotas_repo.clear()
                with st.spinner(f"Lendo `{ARQUIVO_PF_REPO}`…"):
                    _cnpjs_r, _msg_r, _prev_r, _perfil_r, _coords_r = _auto_carregar_pro_frotas_repo()
                if _cnpjs_r:
                    st.session_state["cnpjs_pro_frotas"] = _cnpjs_r
                    st.session_state["_pf_fonte"]        = "repo"
                    st.session_state["_pf_carregado_em"] = _agora()
                    if _perfil_r:
                        st.session_state["perfil_venda_map"]  = _perfil_r
                        st.session_state["perfis_pf_lista"]   = sorted(set(_perfil_r.values()))
                    if _coords_r is not None and not _coords_r.empty:
                        st.session_state["pf_coords_df"] = _coords_r
                    st.success(f"✅ {_msg_r}")
                    time.sleep(1)
                    st.rerun()
                else:
                    st.error(_msg_r or f"❌ `{ARQUIVO_PF_REPO}` não encontrado.")
            st.markdown("<small><b>Upload manual</b></small>", unsafe_allow_html=True)
            arquivo_pf = st.file_uploader(
                "Planilha Pró-Frotas", type=["xlsx","xls","csv"],
                key="upload_pf", label_visibility="collapsed",
            )
            if arquivo_pf is not None:
                _pf_file_id = f"{arquivo_pf.name}_{arquivo_pf.size}"
                if st.session_state.get("_pf_last_upload_id") != _pf_file_id:
                    with st.spinner("Lendo planilha…"):
                        cnpjs_pf, msg_pf, preview_pf, perfil_pf, coords_pf = ler_planilha_pro_frotas(arquivo_pf)
                    if cnpjs_pf is not None:
                        st.session_state["cnpjs_pro_frotas"]    = cnpjs_pf
                        st.session_state["_pf_fonte"]            = "manual"
                        st.session_state["_pf_carregado_em"]     = _agora()
                        st.session_state["_pf_last_upload_id"]   = _pf_file_id
                        if perfil_pf:
                            st.session_state["perfil_venda_map"] = perfil_pf
                            st.session_state["perfis_pf_lista"]  = sorted(set(perfil_pf.values()))
                        if coords_pf is not None and not coords_pf.empty:
                            st.session_state["pf_coords_df"] = coords_pf
                        st.success(msg_pf)
                        if preview_pf is not None:
                            with st.expander("Ver amostra dos CNPJs"):
                                st.dataframe(preview_pf, use_container_width=True)
                        st.rerun()
                    else:
                        st.error(msg_pf)
            if _pf_set:
                if st.button("🗑️ Remover Pró-Frotas", use_container_width=True,
                             key="btn_rm_pf_cfg"):
                    st.session_state.pop("cnpjs_pro_frotas", None)
                    st.session_state.pop("_pf_fonte", None)
                    st.rerun()

        # ── Tab Postos Cercados ───────────────────────────────
        with tab_cer:
            _cer_ts_html = (f"<br><span style='font-size:10px;opacity:.8'>🕐 {_cer_ts}</span>"
                            if _cer_ts else "")
            if _cer_set:
                _cc = ("#fff8e1","#ffe082","#e65100") if _cer_fonte == "manual" \
                      else ("#fff3e0","#ffcc80","#bf360c")
                _src_cer = (
                    f"<span style='font-size:10px;opacity:.8'>"
                    f"Fonte: <code>{ARQUIVO_CERCADOS_REPO}</code></span>"
                    if _cer_fonte == "repo" else
                    "<span style='font-size:10px;opacity:.8'>Carregado manualmente</span>"
                )
                st.markdown(
                    f"<div style='background:{_cc[0]};border:1px solid {_cc[1]};"
                    f"border-radius:8px;padding:8px 11px;font-size:11px;color:{_cc[2]}'>"
                    f"⚠️ <b>{len(_cer_set):,} postos cercados</b> identificados"
                    f"{_cer_ts_html}<br>{_src_cer}</div>",
                    unsafe_allow_html=True,
                )
            else:
                st.markdown(
                    f"<div style='background:#f5f5f5;border:1px solid #ddd;"
                    f"border-radius:8px;padding:8px 11px;font-size:11px;color:#666'>"
                    f"Planilha não carregada.<br>"
                    f"<span style='font-size:10px'>Adicione <code>{ARQUIVO_CERCADOS_REPO}</code> "
                    f"ao repositório ou faça upload manual.</span></div>",
                    unsafe_allow_html=True,
                )
            st.markdown("")
            if st.button("🔄 Recarregar do repositório", use_container_width=True,
                         help=f"Força nova leitura de '{ARQUIVO_CERCADOS_REPO}' no GitHub",
                         key="btn_reload_cercados"):
                _auto_carregar_cercados_repo.clear()
                with st.spinner(f"Lendo `{ARQUIVO_CERCADOS_REPO}`…"):
                    _cnpjs_cer2, _msg_cer2, _ = _auto_carregar_cercados_repo()
                if _cnpjs_cer2:
                    st.session_state["cnpjs_cercados"]          = _cnpjs_cer2
                    st.session_state["_cercados_fonte"]         = "repo"
                    st.session_state["_cercados_carregado_em"]  = _agora()
                    st.success(f"✅ {_msg_cer2}")
                    time.sleep(1)
                    st.rerun()
                else:
                    st.error(_msg_cer2 or f"❌ `{ARQUIVO_CERCADOS_REPO}` não encontrado.")

            st.markdown("<small><b>Upload manual</b> — substitui nesta sessão:</small>",
                        unsafe_allow_html=True)
            arquivo_cer = st.file_uploader(
                "Planilha Postos Cercados", type=["xlsx","xls","csv"],
                key="upload_cercados", label_visibility="collapsed",
            )
            if arquivo_cer is not None:
                _cer_file_id = f"{arquivo_cer.name}_{arquivo_cer.size}"
                if st.session_state.get("_cer_last_upload_id") != _cer_file_id:
                    with st.spinner("Lendo planilha…"):
                        cnpjs_cer_up, msg_cer_up, prev_cer = ler_planilha_cercados(arquivo_cer)
                    if cnpjs_cer_up is not None:
                        st.session_state["cnpjs_cercados"]          = cnpjs_cer_up
                        st.session_state["_cercados_fonte"]         = "manual"
                        st.session_state["_cercados_carregado_em"]  = _agora()
                        st.session_state["_cer_last_upload_id"]     = _cer_file_id
                        st.success(msg_cer_up)
                        if prev_cer is not None:
                            with st.expander("Ver amostra"):
                                st.dataframe(prev_cer, use_container_width=True)
                        st.rerun()
                    else:
                        st.error(msg_cer_up)

            if _cer_set:
                if st.button("🗑️ Remover Cercados", use_container_width=True,
                             key="btn_rm_cercados"):
                    st.session_state.pop("cnpjs_cercados", None)
                    st.session_state.pop("_cercados_fonte", None)
                    st.session_state.pop("_cercados_carregado_em", None)
                    st.rerun()

        # ── Tab Preços PP ─────────────────────────────────────
        with tab_pp:
            _pp_ts_html = (f"<br><span style='font-size:10px;opacity:.8'>🕐 {_pp_ts}</span>"
                           if _pp_ts else "")
            if _pp_df_sb is not None:
                _pp_n2 = _pp_df_sb["cnpj_norm"].nunique() if "cnpj_norm" in _pp_df_sb.columns else 0
                _pp_c  = _pp_df_sb["combustivel_pk"].nunique() if "combustivel_pk" in _pp_df_sb.columns else 0
                _pp_src = (f"<span style='font-size:10px;opacity:.8'>Fonte: <code>{ARQUIVO_PP_REPO}</code></span>"
                           if _pp_fonte == "repo" else
                           "<span style='font-size:10px;opacity:.8'>Carregado manualmente</span>")
                st.markdown(
                    f"<div style='background:#e3f2fd;border:1px solid #90caf9;"
                    f"border-radius:8px;padding:8px 11px;font-size:11px;color:#1565c0'>"
                    f"💲 <b>{_pp_n2:,} postos</b> · {_pp_c} combustíveis"
                    f"{_pp_ts_html}<br>{_pp_src}</div>",
                    unsafe_allow_html=True,
                )
                # ── Diagnóstico de combustíveis detectados ──────────
                if "combustivel_pk" in _pp_df_sb.columns:
                    _pks_pp = sorted(_pp_df_sb["combustivel_pk"].dropna().unique().tolist())
                    _cnpjs_pf_diag = st.session_state.get("cnpjs_pro_frotas", set())
                    # Abre automaticamente se detectou menos de 4 combustíveis
                    _diag_auto = len(_pks_pp) < 4
                    with st.expander(
                        f"🔍 Combustíveis detectados: {len(_pks_pp)}",
                        expanded=_diag_auto,
                    ):
                        if _diag_auto:
                            st.warning(
                                "⚠️ Menos de 4 combustíveis detectados. "
                                "Verifique os nomes abaixo e os nomes das colunas da planilha."
                            )
                        st.caption("PKs lidos (após normalização) → mapeamento ANP:")
                        for _pk_d in _pks_pp:
                            _lbl_d = PRODUTO_CURTO.get(_pk_d) or PRODUTO_CURTO.get(
                                _PP_PARA_ANP_PK.get(_pk_d, ""), "—")
                            _n_rows = int((_pp_df_sb["combustivel_pk"] == _pk_d).sum())
                            _n_pf_d = 0
                            if _cnpjs_pf_diag:
                                _n_pf_d = int(
                                    _pp_df_sb[
                                        (_pp_df_sb["combustivel_pk"] == _pk_d) &
                                        (_pp_df_sb["cnpj_norm"].isin(_cnpjs_pf_diag))
                                    ]["cnpj_norm"].nunique()
                                )
                            _match_anp = _PP_PARA_ANP_PK.get(_pk_d, "❌ SEM MATCH")
                            _cor_match = "#2e7d32" if "❌" not in _match_anp else "#c62828"
                            st.markdown(
                                f"<div style='font-size:11px;padding:4px 0;"
                                f"border-bottom:1px solid #eee'>"
                                f"<b><code>{_pk_d}</code></b> → {_lbl_d} "
                                f"<span style='color:#888'>({_n_rows} linhas · {_n_pf_d} postos PF)</span>"
                                f"<br><span style='font-size:10px;color:{_cor_match}'>"
                                f"ANP: <code>{_match_anp}</code></span>"
                                f"</div>",
                                unsafe_allow_html=True,
                            )
                        # Nomes brutos dos labels (para identificar variantes)
                        if "combustivel_label" in _pp_df_sb.columns:
                            _labels_raw = sorted(
                                _pp_df_sb["combustivel_label"].dropna().unique().tolist()
                            )
                            st.caption(f"Nomes originais na planilha ({len(_labels_raw)}):")
                            st.code(", ".join(_labels_raw), language=None)
            else:
                st.markdown(
                    f"<div style='background:#f5f5f5;border:1px solid #ddd;"
                    f"border-radius:8px;padding:8px 11px;font-size:11px;color:#666'>"
                    f"Planilha não carregada.<br>"
                    f"<span style='font-size:10px'>Adicione <code>{ARQUIVO_PP_REPO}</code> "
                    f"ao repositório ou faça upload manual.</span></div>",
                    unsafe_allow_html=True,
                )
            st.markdown("")
            if st.button("🔄 Recarregar do repositório", use_container_width=True,
                         help=f"Força nova leitura de '{ARQUIVO_PP_REPO}' (cache 1 h)",
                         key="btn_reload_pp"):
                _auto_carregar_precos_postos_repo.clear()
                st.session_state["_pp_tentado"] = False
                with st.spinner(f"Lendo `{ARQUIVO_PP_REPO}`…"):
                    _pp_tmp, _pp_msg_tmp, _ = _auto_carregar_precos_postos_repo()
                if _pp_tmp is not None:
                    st.session_state["_pp_df"]          = _pp_tmp
                    st.session_state["_pp_fonte"]        = "repo"
                    st.session_state["_pp_carregado_em"] = _agora()
                    st.success(f"✅ {_pp_msg_tmp}")
                    time.sleep(1)
                    st.rerun()
                else:
                    st.error(_pp_msg_tmp or f"❌ `{ARQUIVO_PP_REPO}` não encontrado.")
            st.markdown("<small><b>Upload manual</b> — substitui nesta sessão:</small>",
                        unsafe_allow_html=True)
            arquivo_pp = st.file_uploader(
                "Planilha Preço Posto", type=["xlsx","xls","csv"],
                key="upload_pp", label_visibility="collapsed",
            )
            if arquivo_pp is not None:
                # Evita loop infinito: só processa se for um arquivo novo
                _pp_file_id = f"{arquivo_pp.name}_{arquivo_pp.size}"
                if st.session_state.get("_pp_last_upload_id") != _pp_file_id:
                    with st.spinner("Lendo planilha…"):
                        _pp_up, _pp_msg_up, _ = ler_planilha_precos_postos(arquivo_pp)
                    if _pp_up is not None:
                        st.session_state["_pp_df"]             = _pp_up
                        st.session_state["_pp_fonte"]           = "manual"
                        st.session_state["_pp_carregado_em"]    = _agora()
                        st.session_state["_pp_last_upload_id"]  = _pp_file_id
                        st.success(_pp_msg_up)
                        st.rerun()
                    else:
                        st.error(_pp_msg_up)
            if _pp_df_sb is not None:
                if st.button("🗑️ Remover Preços PP", use_container_width=True,
                             key="btn_rm_pp"):
                    st.session_state.pop("_pp_df", None)
                    st.session_state.pop("_pp_fonte", None)
                    st.session_state.pop("_pp_carregado_em", None)
                    st.session_state["_pp_tentado"] = False
                    st.rerun()

        # ── Tab Base Nacional ─────────────────────────────────
        with tab_base:
            st.markdown(
                "<small>Carrega postos de <b>todos os 27 estados</b> antecipadamente "
                "e mantém em cache por <b>24 h</b>. "
                "Após isso, buscas por rota ficam <b>instantâneas</b>.</small>",
                unsafe_allow_html=True,
            )
            _preload_ts  = st.session_state.get("_preload_brasil_em", "")
            _preload_ok  = st.session_state.get("_preload_brasil_ok", 0)
            _preload_err = st.session_state.get("_preload_brasil_err", [])
            if _preload_ts:
                _cor_b = "#e8f5e9" if not _preload_err else "#fff8e1"
                _brd_b = "#a5d6a7" if not _preload_err else "#ffe082"
                _txt_b = "#2e7d32" if not _preload_err else "#f57f17"
                _ic_b  = "✅" if not _preload_err else "⚠️"
                _err_b = (f"<br><span style='font-size:10px'>Falha: {', '.join(_preload_err)}</span>"
                          if _preload_err else "")
                st.markdown(
                    f"<div style='background:{_cor_b};border:1px solid {_brd_b};"
                    f"border-radius:8px;padding:8px 11px;font-size:11px;color:{_txt_b};margin:6px 0'>"
                    f"{_ic_b} <b>{_preload_ok} estado(s)</b>{_err_b}<br>"
                    f"<span style='font-size:10px;opacity:.8'>🕐 {_preload_ts}</span>"
                    f"</div>",
                    unsafe_allow_html=True,
                )
            st.markdown("")
            if st.button("⚡ Carregar todos os estados",
                         use_container_width=True, key="btn_preload"):
                buscar_postos.clear()
                with st.spinner("📡 Recarregando base em paralelo…"):
                    carregados_pl, erros_pl = _precarregar_estados_paralelo(max_workers=5)
                st.session_state["_estados_precarregados"] = carregados_pl
                st.session_state["_preload_brasil_em"]     = _agora()
                st.session_state["_preload_brasil_ok"]     = len(carregados_pl)
                st.session_state["_preload_brasil_err"]    = erros_pl
                st.session_state["_base_auto_ok"]          = True
                if erros_pl:
                    st.warning(f"✅ {len(carregados_pl)} estados. ⚠️ Falha: {', '.join(erros_pl)}")
                else:
                    st.success(f"✅ Todos os {len(UFS)} estados carregados!")
                st.rerun()

            # ── Exportar (abaixo do botão Carregar) ──────────────
            st.markdown("---")
            st.markdown(
                "<small>📥 <b>Exportar:</b> gera <b>Excel (.xlsx)</b> com todos os postos "
                "dos estados carregados, com destaque para <b>Pró-Frotas</b>.</small>",
                unsafe_allow_html=True,
            )
            st.markdown("")
            _n_est_exp = len(st.session_state.get("_estados_precarregados", []))
            if _n_est_exp == 0:
                st.warning("⚠️ Carregue a base primeiro (botão acima).")
            else:
                st.markdown(
                    f"<div style='font-size:11px;color:#555;margin-bottom:6px'>"
                    f"📦 <b>{_n_est_exp} estado(s)</b> disponíveis</div>",
                    unsafe_allow_html=True,
                )
                if st.button("📊 Gerar arquivo Excel",
                             use_container_width=True, key="btn_export_base"):
                    with st.spinner(f"⏳ Consolidando {_n_est_exp} estado(s)…"):
                        _exp_bytes, _exp_msg = _gerar_excel_base_brasil()
                    if _exp_bytes:
                        st.session_state["_base_export_bytes"] = _exp_bytes
                        st.session_state["_base_export_msg"]   = _exp_msg
                    else:
                        st.error(_exp_msg)
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


# ═══════════════════════════════════════════════════════════════════
#  MODO 1 — Por Estado / Município
# ═══════════════════════════════════════════════════════════════════

if modo == "📍 Por Estado/Município":

    if uf:
        _cnpjs_pf_atual = st.session_state.get("cnpjs_pro_frotas", set())

        # ── Passo 1: carrega estado se mudou (aproveita cache 24h) ──
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
            st.session_state["df_raw_full"]  = df_raw_full
            st.session_state["_uf_carregada"] = uf
            if not df_raw_full.empty and "distribuidora" in df_raw_full.columns:
                st.session_state["distribuidoras_disponiveis"] = sorted(
                    df_raw_full["distribuidora"].dropna().unique().tolist())
            precar = st.session_state.get("_estados_precarregados", [])
            if uf not in precar:
                st.session_state["_estados_precarregados"] = precar + [uf]
            # Nova UF: invalida cache de marcação e marca para reinjetar PF
            st.session_state.pop("_df_marcado",     None)
            st.session_state.pop("_df_marcado_key", None)
            st.session_state.pop("_pf_injetados_uf", None)

        # ── Passo 2: injeta PF ausentes (via planilha) se ainda não feito nesta UF ──
        if _cnpjs_pf_atual and uf != st.session_state.get("_pf_injetados_uf"):
            _df_base = st.session_state.get("df_raw_full", pd.DataFrame())
            with st.spinner("🔍 Verificando postos Pró-Frotas ausentes na base ANP…"):
                _df_injetado = _injetar_pf_ausentes(_df_base, _cnpjs_pf_atual, uf_atual=uf)
            if len(_df_injetado) > len(_df_base):
                st.session_state["df_raw_full"] = _df_injetado
                # Novos postos adicionados → invalida cache de marcação
                st.session_state.pop("_df_marcado",     None)
                st.session_state.pop("_df_marcado_key", None)
                if "distribuidora" in _df_injetado.columns:
                    st.session_state["distribuidoras_disponiveis"] = sorted(
                        _df_injetado["distribuidora"].dropna().unique().tolist())
            st.session_state["_pf_injetados_uf"] = uf

        # ── Passo 3: sempre lê df_raw_full do session_state ──────────
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

        df_show = preparar_df(df_raw, distribuidoras_filtro, perfis_filtro=perfis_filtro_m1)

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

        # ── Cards comparativo PF vs ANP (quando dados disponíveis) ────
        _pp_df_m1    = st.session_state.get("_pp_df")
        _cnpjs_pf_m1 = st.session_state.get("cnpjs_pro_frotas", set())
        _cache_m1    = st.session_state.get("_precos_anp_cache", {})
        _sheets_m1   = _cache_m1.get("sheets")
        if _pp_df_m1 is not None and _sheets_m1 is not None and _cnpjs_pf_m1:
            _comp_m1 = _calcular_comparativo_pf_anp(
                _pp_df_m1, _cnpjs_pf_m1, _sheets_m1, ufs=[uf] if uf else None
            )
            if _comp_m1:
                _renderizar_comparativo_pf_anp(
                    _comp_m1,
                    subtitulo=f"Postos Pró-Frotas vs preço médio ANP — {UF_NOME.get(uf, uf)}"
                )

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
            # Injeta postos Pró-Frotas ausentes (podem estar em outros estados)
            _cnpjs_pf_r = st.session_state.get("cnpjs_pro_frotas", set())
            if _cnpjs_pf_r and not df_rota.empty:
                with st.spinner("🔍 Verificando postos Pró-Frotas ausentes na rota…"):
                    _df_rota_enr = _injetar_pf_ausentes(df_rota, _cnpjs_pf_r)
                if len(_df_rota_enr) > len(df_rota):
                    # Recalcula distância para os postos injetados (sem coordenadas de rota)
                    _novos = _df_rota_enr.iloc[len(df_rota):]
                    _dists_n = dist_minima_rota_np(
                        _novos["_lat"].values, _novos["_lon"].values, coords_rota)
                    _df_rota_enr.loc[_novos.index, "_dist_rota"] = _dists_n
                    df_rota = _df_rota_enr

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

        df_show_r = preparar_df(df_rota, distribuidoras_filtro, perfis_filtro=perfis_filtro_m2)

        c1,c2,c3,c4 = st.columns(4)
        c1.metric("🛣️ Distância",       f"{_n(dist_km)} km")
        c2.metric("⏱️ Tempo estimado",  f"{int(dur_min//60)}h {int(dur_min%60)}min")
        c3.metric("⛽ Postos na rota",  _n(len(df_show_r)))
        c4.metric("⭐ Pró-Frotas",      _n(n_pf(df_show_r)))

        st.success(f"✅ **{label_orig}** → **{label_dest}** | {_n(len(df_show_r))} postos a até {raio_usado} m")

        # ── Cards comparativo PF vs ANP para a rota ───────────────────
        _pp_df_m2    = st.session_state.get("_pp_df")
        _cnpjs_pf_m2 = st.session_state.get("cnpjs_pro_frotas", set())
        _cache_m2    = st.session_state.get("_precos_anp_cache", {})
        _sheets_m2   = _cache_m2.get("sheets")
        _ufs_rota_m2 = list(st.session_state.get("_ufs_rota_atual", []))
        if _pp_df_m2 is not None and _sheets_m2 is not None and _cnpjs_pf_m2:
            _comp_m2 = _calcular_comparativo_pf_anp(
                _pp_df_m2, _cnpjs_pf_m2, _sheets_m2,
                ufs=_ufs_rota_m2 if _ufs_rota_m2 else None
            )
            if _comp_m2:
                _renderizar_comparativo_pf_anp(
                    _comp_m2,
                    subtitulo=f"Postos Pró-Frotas vs preço médio ANP — estados da rota"
                )

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
