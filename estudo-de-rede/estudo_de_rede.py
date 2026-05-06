# ═══════════════════════════════════════════════════════════════════
#  Estudo de Rede – Pró-Frotas
#  Versão 4.0  |  Interface redesenhada + Pró-Frotas + Roteamento
# ═══════════════════════════════════════════════════════════════════

import io
import math
import time
import requests
import pandas as pd
import streamlit as st
import folium
from folium.plugins import MarkerCluster
from streamlit_folium import st_folium

# ─── Configuração da página ────────────────────────────────────────
st.set_page_config(
    page_title="Estudo de Rede – Pró-Frotas",
    page_icon="⛽",
    layout="wide",
)

# ─── CSS Global ────────────────────────────────────────────────────
st.markdown("""
<style>
/* ── Esconde cabeçalho padrão do Streamlit ── */
header[data-testid="stHeader"] { display: none !important; }
#MainMenu { display: none !important; }
footer    { display: none !important; }

/* ── Barra superior personalizada ── */
.topbar {
    background: linear-gradient(135deg, #0d1b4b 0%, #1565c0 60%, #0288d1 100%);
    color: white;
    padding: 14px 28px;
    border-radius: 0 0 12px 12px;
    margin-bottom: 20px;
    display: flex;
    align-items: center;
    gap: 14px;
    box-shadow: 0 4px 12px rgba(0,0,0,0.25);
}
.topbar-icon  { font-size: 36px; }
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

/* ── Sidebar ── */
section[data-testid="stSidebar"] > div:first-child {
    background: #f0f4f9;
    border-right: 1px solid #d0dce8;
}
section[data-testid="stSidebar"] .stButton > button {
    border-radius: 8px;
    font-weight: 600;
}

/* ── Cards de métricas ── */
[data-testid="stMetric"] {
    background: white;
    border-radius: 10px;
    padding: 14px 18px !important;
    box-shadow: 0 2px 6px rgba(0,0,0,0.08);
    border-left: 4px solid #1565c0;
}
[data-testid="stMetricLabel"] { font-size: 12px !important; color: #555 !important; }
[data-testid="stMetricValue"] { font-size: 24px !important; font-weight: 700 !important; }

/* ── Tabs ── */
button[data-baseweb="tab"] {
    font-weight: 600;
    font-size: 13px;
}

/* ── Expander Pró-Frotas ── */
details summary {
    font-weight: 700;
    font-size: 14px;
}

/* ── Caixa de info/sucesso/aviso ── */
.stAlert { border-radius: 8px !important; }

/* ── Separador sidebar ── */
hr { margin: 10px 0 !important; border-color: #c8d8e8 !important; }

/* ── Botão primário ── */
.stButton > button[kind="primary"] {
    background: linear-gradient(135deg, #1565c0, #0d47a1);
    border: none;
    font-size: 14px;
    padding: 10px 0;
    border-radius: 8px;
}
.stButton > button[kind="primary"]:hover {
    background: linear-gradient(135deg, #1976d2, #1565c0);
    box-shadow: 0 4px 12px rgba(21,101,192,0.4);
}

/* ── Empty state ── */
.empty-state {
    text-align: center;
    padding: 60px 40px;
    color: #90a4b0;
}
.empty-state-icon { font-size: 64px; margin-bottom: 16px; }
.empty-state-title { font-size: 20px; font-weight: 700; color: #546e7a; margin-bottom: 8px; }
.empty-state-desc  { font-size: 14px; line-height: 1.6; }
</style>
""", unsafe_allow_html=True)

# ─── Constantes ───────────────────────────────────────────────────
API_BASE_URL = "https://revendedoresapi.anp.gov.br"
ENDPOINT     = "/v1/combustivel"
NOMINATIM    = "https://nominatim.openstreetmap.org/search"

UFS = [
    "AC","AL","AM","AP","BA","CE","DF","ES","GO","MA","MG","MS",
    "MT","PA","PB","PE","PI","PR","RJ","RN","RO","RR","RS","SC",
    "SE","SP","TO",
]

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

CORES = [
    "#e6194b","#3cb44b","#4363d8","#f58231","#911eb4","#42d4f4",
    "#f032e6","#bfef45","#fabed4","#469990","#dcbeff","#9A6324",
    "#fffac8","#800000","#aaffc3","#808000","#ffd8b1","#000075",
    "#a9a9a9","#e6beff","#ffe119","#000000",
]
COR_PF_BORDA = "#FFD700"


# ═══════════════════════════════════════════════════════════════════
#  PRÓ-FROTAS — Upload e comparação de CNPJs
# ═══════════════════════════════════════════════════════════════════

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


@st.cache_data(show_spinner=False)
def ler_planilha_pro_frotas(conteudo: bytes, nome: str):
    try:
        df = pd.read_csv(io.BytesIO(conteudo), dtype=str) if nome.lower().endswith(".csv") \
             else pd.read_excel(io.BytesIO(conteudo), dtype=str)
        col = detectar_coluna_cnpj(df)
        if col is None:
            return None, "Coluna CNPJ não encontrada. Certifique-se que há uma coluna chamada 'CNPJ'.", None
        cnpjs = {c for c in df[col].dropna().apply(normalizar_cnpj) if len(c) == 14}
        preview = df[[col]].rename(columns={col: "CNPJ (original)"}).head(10)
        return cnpjs, f"{len(cnpjs)} CNPJs Pró-Frotas carregados (coluna: **{col}**)", preview
    except Exception as e:
        return None, f"Erro ao ler arquivo: {e}", None


def marcar_pro_frotas(df: pd.DataFrame, cnpjs_pf: set) -> pd.DataFrame:
    df = df.copy()
    if cnpjs_pf:
        df["_cnpj_norm"] = df["cnpj"].apply(normalizar_cnpj)
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


def campo_autocomplete(titulo, placeholder, key_texto, key_estado):
    st.markdown(f"<div style='font-weight:700;font-size:13px;margin-bottom:4px'>{titulo}</div>",
                unsafe_allow_html=True)
    texto = st.text_input(titulo, placeholder=placeholder,
                          key=key_texto, label_visibility="collapsed")
    ultimo = st.session_state.get(f"_{key_estado}_txt_ant", "")
    if texto != ultimo:
        st.session_state[f"_{key_estado}_txt_ant"] = texto
        if len(texto) < 3:
            st.session_state.pop(key_estado, None)

    sugestoes = sugestoes_nominatim(texto) if len(texto.strip()) >= 3 else []
    if sugestoes:
        labels = [s["label"] for s in sugestoes]
        idx = st.selectbox("Sugestões:", range(len(labels)),
                           format_func=lambda i: labels[i], key=f"_sel_{key_estado}")
        sel = sugestoes[idx]
        st.session_state[key_estado] = sel
        st.markdown(f"<small style='color:#1565c0'>📍 {sel['label']}</small>", unsafe_allow_html=True)
        return sel
    elif len(texto.strip()) >= 3:
        st.markdown("<small style='color:#e65100'>⚠️ Nenhuma sugestão encontrada.</small>",
                    unsafe_allow_html=True)
        return st.session_state.get(key_estado)
    elif len(texto.strip()) > 0:
        st.markdown("<small style='color:#888'>Continue digitando (mín. 3 letras)…</small>",
                    unsafe_allow_html=True)
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


def _dist_ponto_segmento(lat, lon, la1, lo1, la2, lo2):
    cos_lat = math.cos(math.radians((la1+la2)/2))
    R = 6_371_000
    def xy(φ, λ): return math.radians(λ-lo1)*cos_lat*R, math.radians(φ-la1)*R
    bx, by = xy(la2, lo2)
    px, py = xy(lat, lon)
    ab2 = bx*bx + by*by
    if ab2 == 0: return math.hypot(px, py)
    t = max(0.0, min(1.0, (px*bx+py*by)/ab2))
    return math.hypot(px-t*bx, py-t*by)


def dist_minima_rota(lat, lon, coords):
    if not coords: return float("inf")
    if len(coords) == 1: return _haversine(lat, lon, coords[0][0], coords[0][1])
    return min(_dist_ponto_segmento(lat, lon, coords[i][0], coords[i][1],
                                    coords[i+1][0], coords[i+1][1])
               for i in range(len(coords)-1))


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

def _get(url, params, tentativas=3):
    for i in range(tentativas):
        try:
            r = requests.get(url, params=params, timeout=30)
            r.raise_for_status()
            return r
        except Exception:
            if i == tentativas-1: raise
            time.sleep(1.5)


@st.cache_data(show_spinner=False, ttl=1800)
def buscar_postos(uf=None, municipio=None):
    params = {"numeropagina": 1}
    if uf:        params["uf"]        = uf
    if municipio: params["municipio"] = municipio
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
    return mapa_cores.get(str(distribuidora).upper().strip(), "#808080")


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
        f"{produtos_html}</div>",
        max_width=340
    )


def _icone_pf(cor):
    return folium.DivIcon(html=f"""
        <div style="position:relative;width:28px;height:28px">
          <div style="width:22px;height:22px;background:{cor};
               border:3px solid {COR_PF_BORDA};border-radius:50%;
               position:absolute;top:3px;left:3px;
               box-shadow:0 0 6px {COR_PF_BORDA}88"></div>
          <div style="position:absolute;top:-7px;right:-5px;
               font-size:15px;filter:drop-shadow(0 0 2px #555)">⭐</div>
        </div>""", icon_size=(32,32), icon_anchor=(14,14))


def criar_mapa(df, coords_rota=None, lat_orig=None, lon_orig=None,
               lat_dest=None, lon_dest=None, label_orig="Origem", label_dest="Destino"):
    if not df.empty:
        clat, clon, zoom = df["_lat"].mean(), df["_lon"].mean(), 7
    elif coords_rota:
        lats = [c[0] for c in coords_rota]; lons = [c[1] for c in coords_rota]
        clat = (min(lats)+max(lats))/2; clon = (min(lons)+max(lons))/2; zoom = 6
    else:
        clat, clon, zoom = -15.0, -47.0, 4

    m = folium.Map(location=[clat,clon], zoom_start=zoom, tiles="CartoDB positron")

    distribuidoras = sorted(df["distribuidora"].dropna().unique()) if not df.empty else []
    mapa_cores = {d.upper().strip(): CORES[i%len(CORES)] for i,d in enumerate(distribuidoras)}

    if coords_rota and len(coords_rota) >= 2:
        folium.PolyLine(coords_rota, color="#1565C0", weight=5,
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
        for _, row in df.iterrows():
            cor   = _cor(row.get("distribuidora",""), mapa_cores)
            is_pf = tem_pf and bool(row.get("_pro_frotas"))
            tip   = f"{'⭐ PRÓ-FROTAS | ' if is_pf else ''}⛽ {row.get('razaoSocial','?')} ({row.get('distribuidora','?')})"
            pop   = _popup(row)
            if is_pf:
                folium.Marker([row["_lat"],row["_lon"]], icon=_icone_pf(cor),
                              popup=pop, tooltip=tip).add_to(c_pf)
            else:
                folium.CircleMarker([row["_lat"],row["_lon"]], radius=7,
                                    color=cor, fill=True, fill_color=cor, fill_opacity=0.85,
                                    popup=pop, tooltip=tip).add_to(c_reg)

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
            "<span style='font-size:13px;margin-right:4px'>⭐</span><b>Pró-Frotas</b></li>"
            "</ul></div>"
        ))
    folium.LayerControl().add_to(m)
    return m


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
  <div class="topbar-icon">⛽</div>
  <div>
    <div class="topbar-title">Estudo de Rede – Pró-Frotas</div>
    <div class="topbar-sub">ANP · Agência Nacional do Petróleo, Gás Natural e Biocombustíveis</div>
  </div>
  {pf_badge_html}
</div>
""", unsafe_allow_html=True)


# ═══════════════════════════════════════════════════════════════════
#  SIDEBAR
# ═══════════════════════════════════════════════════════════════════

with st.sidebar:

    # ── Logo / título lateral ─────────────────────────────────
    st.markdown("""
    <div style='text-align:center;padding:10px 0 6px'>
      <div style='font-size:32px'>⛽</div>
      <div style='font-weight:800;font-size:15px;color:#0d1b4b'>Estudo de Rede</div>
      <div style='font-size:11px;color:#666;margin-top:2px'>Pró-Frotas · ANP</div>
    </div>
    """, unsafe_allow_html=True)

    st.divider()

    # ── Pró-Frotas ────────────────────────────────────────────
    with st.expander("⭐  Carga Postos Pró-Frotas", expanded=False):
        st.markdown(
            "<small>Carregue um arquivo <b>Excel</b> ou <b>CSV</b> com os CNPJs "
            "dos postos credenciados. O sistema identificará automaticamente "
            "cada posto com uma <b>estrela dourada ⭐</b> no mapa.</small>",
            unsafe_allow_html=True,
        )
        st.markdown("")
        arquivo_pf = st.file_uploader(
            "Selecionar planilha", type=["xlsx","xls","csv"],
            key="upload_pf", label_visibility="collapsed",
        )
        if arquivo_pf is not None:
            cnpjs_pf, msg_pf, preview_pf = ler_planilha_pro_frotas(arquivo_pf.read(), arquivo_pf.name)
            if cnpjs_pf is not None:
                st.session_state["cnpjs_pro_frotas"] = cnpjs_pf
                st.success(msg_pf)
                if preview_pf is not None:
                    with st.expander("Ver amostra"):
                        st.dataframe(preview_pf, use_container_width=True)
            else:
                st.error(msg_pf)

        pf_set = st.session_state.get("cnpjs_pro_frotas", set())
        if pf_set:
            st.info(f"📋 **{len(pf_set)}** CNPJs ativos")
            if st.button("🗑️ Remover Pró-Frotas", use_container_width=True):
                st.session_state.pop("cnpjs_pro_frotas", None)
                st.rerun()
        else:
            st.caption("Nenhuma planilha carregada ainda.")

    st.divider()

    # ── Modo de exibição ──────────────────────────────────────
    st.markdown("<div style='font-weight:700;font-size:13px;margin-bottom:8px'>🧭 Modo de exibição</div>",
                unsafe_allow_html=True)
    modo = st.radio("Modo", ["📍 Por Estado/Município", "🗺️ Por Rota"],
                    label_visibility="collapsed")
    st.divider()

    # ── Modo 1 ────────────────────────────────────────────────
    if modo == "📍 Por Estado/Município":
        st.markdown("<div style='font-weight:700;font-size:13px;margin-bottom:6px'>🗺️ Localização</div>",
                    unsafe_allow_html=True)
        uf = st.selectbox("Estado (UF)", ["— Selecione —"] + UFS, index=0,
                          help="Selecione o estado para carregar os postos")
        uf = "" if uf == "— Selecione —" else uf

        municipio_input = st.text_input("🏙️ Município (opcional)",
                                         placeholder="Ex: Teresina",
                                         help="Filtra os postos por município dentro do estado")
        distribuidoras_filtro = []
        if st.session_state.get("distribuidoras_disponiveis"):
            st.markdown("<div style='font-weight:700;font-size:13px;margin:10px 0 6px'>🏷️ Filtrar por Bandeira</div>",
                        unsafe_allow_html=True)
            distribuidoras_filtro = st.multiselect(
                "Bandeiras", st.session_state["distribuidoras_disponiveis"],
                placeholder="Todas as bandeiras", label_visibility="collapsed")

    # ── Modo 2 ────────────────────────────────────────────────
    else:
        st.markdown(
            "<div style='background:#e3f2fd;border-radius:8px;padding:10px 12px;"
            "font-size:12px;color:#1565c0;margin-bottom:12px'>"
            "💡 Digite a cidade e selecione nas sugestões para confirmar o ponto.</div>",
            unsafe_allow_html=True,
        )
        orig_sel = campo_autocomplete("🟢 Ponto de Origem", "Ex: São Paulo", "txt_origem", "orig_sel")
        st.markdown("")
        dest_sel = campo_autocomplete("🔴 Ponto de Destino", "Ex: Rio de Janeiro", "txt_destino", "dest_sel")
        st.divider()

        st.markdown("<div style='font-weight:700;font-size:13px;margin-bottom:6px'>📏 Raio da rota</div>",
                    unsafe_allow_html=True)
        raio = st.slider("Raio (m)", min_value=200, max_value=2000, value=500, step=100,
                         label_visibility="collapsed",
                         help="Postos dentro deste raio ao redor da rota serão exibidos")
        st.caption(f"Mostrando postos a até **{raio} m** da rota")

        buscar_rota_btn = st.button("🗺️ Traçar Rota e Buscar Postos",
                                    use_container_width=True, type="primary")

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
        if uf != st.session_state.get("_uf_carregada") or municipio_input != st.session_state.get("_mun_carregado"):
            with st.spinner(f"⏳ Carregando postos de **{uf}**…"):
                df_raw = buscar_postos(uf=uf, municipio=municipio_input or None)
            st.session_state.update({"df_raw": df_raw, "_uf_carregada": uf, "_mun_carregado": municipio_input})
            if not df_raw.empty and "distribuidora" in df_raw.columns:
                st.session_state["distribuidoras_disponiveis"] = sorted(
                    df_raw["distribuidora"].dropna().unique().tolist())
        else:
            df_raw = st.session_state.get("df_raw", pd.DataFrame())

        df_show = preparar_df(df_raw, distribuidoras_filtro)

        # ── Métricas ──────────────────────────────────────────
        c1, c2, c3, c4 = st.columns(4)
        c1.metric("⛽ Postos exibidos",  f"{len(df_show):,}")
        c2.metric("⭐ Credenciados PF",  f"{n_pf(df_show):,}")
        c3.metric("🏷️ Bandeiras",       f"{df_show['distribuidora'].nunique():,}" if not df_show.empty else "0")
        c4.metric("📍 Estado",          uf)

        tab_mapa, tab_dados, tab_analise = st.tabs([
            "🗺️  Mapa Interativo", "📋  Dados Tabulares", "📊  Análise por Bandeira"])

        with tab_mapa:
            st_folium(criar_mapa(df_show), use_container_width=True, height=620, returned_objects=[])

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
    else:
        st.markdown("""
        <div class="empty-state">
          <div class="empty-state-icon">🗺️</div>
          <div class="empty-state-title">Selecione um Estado para começar</div>
          <div class="empty-state-desc">
            Escolha o estado (UF) na barra lateral à esquerda.<br>
            Os postos serão carregados automaticamente da base ANP<br>
            e exibidos no mapa com suas respectivas bandeiras.
          </div>
        </div>
        """, unsafe_allow_html=True)
        st_folium(criar_mapa(pd.DataFrame()), use_container_width=True, height=520, returned_objects=[])


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
            with st.spinner(f"⛽ Buscando postos em {', '.join(ufs_rota)}…"):
                frames = []
                for uf_b in ufs_rota:
                    try:
                        df_uf = buscar_postos(uf=uf_b)
                        if not df_uf.empty: frames.append(df_uf)
                    except Exception: pass
            df_todos = pd.concat(frames, ignore_index=True) if frames else pd.DataFrame()
            if not df_todos.empty:
                with st.spinner("📏 Calculando distâncias…"):
                    df_todos["_dist_rota"] = df_todos.apply(
                        lambda r: dist_minima_rota(r["_lat"], r["_lon"], coords_rota), axis=1)
                df_rota = df_todos[df_todos["_dist_rota"] <= raio].copy().sort_values("_dist_rota").reset_index(drop=True)
            else:
                df_rota = pd.DataFrame()
            st.session_state.update({
                "df_rota": df_rota, "coords_rota": coords_rota,
                "lat_orig": lo["lat"], "lon_orig": lo["lon"], "label_orig": lo["label"],
                "lat_dest": ld["lat"], "lon_dest": ld["lon"], "label_dest": ld["label"],
                "dist_km": dist_km, "dur_min": dur_min, "raio_usado": raio, "linha_reta": linha_reta,
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
        c1.metric("🛣️ Distância",       f"{dist_km:,.0f} km")
        c2.metric("⏱️ Tempo estimado",  f"{int(dur_min//60)}h {int(dur_min%60)}min")
        c3.metric("⛽ Postos na rota",  f"{len(df_show_r):,}")
        c4.metric("⭐ Pró-Frotas",      f"{n_pf(df_show_r):,}")

        st.success(f"✅ **{label_orig}** → **{label_dest}** | {len(df_show_r):,} postos a até {raio_usado} m")

        tab_m, tab_d = st.tabs(["🗺️  Mapa da Rota", "📋  Postos na Rota"])

        with tab_m:
            m = criar_mapa(df_show_r, coords_rota=coords_rota,
                           lat_orig=lat_orig, lon_orig=lon_orig,
                           lat_dest=lat_dest, lon_dest=lon_dest,
                           label_orig=label_orig, label_dest=label_dest)
            st_folium(m, use_container_width=True, height=650, returned_objects=[])

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
    else:
        st.markdown("""
        <div class="empty-state">
          <div class="empty-state-icon">🛣️</div>
          <div class="empty-state-title">Defina Origem e Destino para traçar a rota</div>
          <div class="empty-state-desc">
            Preencha os campos <b>Ponto de Origem</b> e <b>Ponto de Destino</b> na barra lateral,<br>
            ajuste o raio desejado e clique em <b>Traçar Rota e Buscar Postos</b>.<br><br>
            O mapa mostrará a rota em azul e todos os postos no raio configurado.
          </div>
        </div>
        """, unsafe_allow_html=True)
        st_folium(criar_mapa(pd.DataFrame()), use_container_width=True, height=520, returned_objects=[])
