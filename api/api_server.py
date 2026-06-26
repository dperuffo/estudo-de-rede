"""
FNI Gestão de Frotas — API REST
================================
FastAPI rodando em paralelo ao Streamlit.
Porta: 8001 (Railway: serviço separado)
Auth: Google OAuth → JWT
"""
from __future__ import annotations
import os, re, json, logging
from datetime import datetime, timedelta, timezone
from typing import Optional

from fastapi import FastAPI, Depends, HTTPException, status, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError, jwt
from pydantic import BaseModel
from supabase import create_client, Client

# ── Configuração ──────────────────────────────────────────────────
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("fni-api")

JWT_SECRET  = os.environ.get("JWT_SECRET", "fni-secret-change-in-production")
JWT_ALG     = "HS256"
JWT_EXPIRY  = 60 * 24 * 7  # 7 dias em minutos
SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY", "")

app = FastAPI(
    title="FNI Gestão de Frotas API",
    description="API REST para o app mobile FNI — Flutter",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

# ── CORS — permite Flutter web e mobile ──────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # restringir em produção
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

security = HTTPBearer()

# ── Supabase client ───────────────────────────────────────────────
def get_db() -> Client:
    return create_client(SUPABASE_URL, SUPABASE_KEY)

# ── JWT helpers ───────────────────────────────────────────────────
def criar_token(data: dict) -> str:
    payload = data.copy()
    payload["exp"] = datetime.now(tz=timezone.utc) + timedelta(minutes=JWT_EXPIRY)
    payload["iat"] = datetime.now(tz=timezone.utc)
    return jwt.encode(payload, JWT_SECRET, algorithm=JWT_ALG)

def verificar_token(token: str) -> dict:
    try:
        return jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALG])
    except JWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Token inválido: {e}",
            headers={"WWW-Authenticate": "Bearer"},
        )

def usuario_atual(creds: HTTPAuthorizationCredentials = Depends(security)) -> dict:
    return verificar_token(creds.credentials)

# ── Models ────────────────────────────────────────────────────────
class GoogleAuthRequest(BaseModel):
    access_token: str      # access token Google retornado pelo Flutter Web

class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    email: str
    nome: str
    perfil: str
    empresa_id: str
    cnpj_frota: str
    plano: str

class AbastecimentoFiltros(BaseModel):
    dias: int = 30
    placa: Optional[str] = None
    produto: Optional[str] = None
    cnpj_posto: Optional[str] = None

# ── Endpoints de saúde ────────────────────────────────────────────
@app.get("/", tags=["health"])
def root():
    return {"status": "ok", "app": "FNI Gestão de Frotas API", "version": "1.0.0"}

@app.get("/health", tags=["health"])
def health():
    try:
        db = get_db()
        db.table("empresas").select("id").limit(1).execute()
        return {"status": "ok", "database": "connected"}
    except Exception as e:
        return {"status": "error", "database": str(e)}

# ── Auth: Google OAuth → JWT ──────────────────────────────────────
@app.post("/auth/google", response_model=LoginResponse, tags=["auth"])
async def auth_google(body: GoogleAuthRequest):
    """
    Recebe o Google ID Token do Flutter,
    valida no Google, busca o usuário no Supabase
    e retorna um JWT da FNI.
    """
    import httpx
    # Valida o ID token no Google
    async with httpx.AsyncClient() as client:
        resp = await client.get(
            f"https://www.googleapis.com/oauth2/v1/userinfo?access_token={body.access_token}"
        )
    if resp.status_code != 200:
        raise HTTPException(status_code=401, detail="Token Google inválido")
    
    g_data = resp.json()
    email  = g_data.get("email", "").lower().strip()
    nome   = g_data.get("name", email.split("@")[0])
    
    if not email:
        raise HTTPException(status_code=401, detail="Email não encontrado no token")
    
    # Busca usuário no Supabase
    db = get_db()
    try:
        u = db.table("usuarios_app").select(
            "email,perfil,cnpj_vinculado,empresa_nome,ativo,nome"
        ).eq("email", email).single().execute()
        user = u.data
    except Exception:
        raise HTTPException(status_code=403, detail="Usuário não autorizado")
    
    if not user or not user.get("ativo"):
        raise HTTPException(status_code=403, detail="Usuário inativo ou não encontrado")
    
    # Busca empresa
    empresa_id = user.get("empresa_nome") or ""
    cnpj_frota = re.sub(r"\D", "", user.get("cnpj_vinculado") or "")
    plano = "gratuito"
    if empresa_id:
        try:
            e = db.table("empresas").select("plano,cnpj").eq("id", empresa_id).single().execute()
            plano = e.data.get("plano", "gratuito") if e.data else "gratuito"
            if not cnpj_frota and e.data:
                cnpj_frota = re.sub(r"\D", "", e.data.get("cnpj") or "")
        except Exception:
            pass
    
    # Gera JWT FNI
    token_data = {
        "sub": email,
        "email": email,
        "nome": user.get("nome") or nome,
        "perfil": user.get("perfil", "usuario"),
        "empresa_id": empresa_id,
        "cnpj_frota": cnpj_frota,
        "plano": plano,
    }
    access_token = criar_token(token_data)
    
    return LoginResponse(
        access_token=access_token,
        email=email,
        nome=user.get("nome") or nome,
        perfil=user.get("perfil", "usuario"),
        empresa_id=empresa_id,
        cnpj_frota=cnpj_frota,
        plano=plano,
    )

@app.post("/auth/refresh", tags=["auth"])
def refresh_token(user: dict = Depends(usuario_atual)):
    """Renova o JWT sem precisar logar novamente."""
    novo_token = criar_token({k: v for k, v in user.items() if k not in ("exp","iat")})
    return {"access_token": novo_token, "token_type": "bearer"}

@app.get("/auth/me", tags=["auth"])
def me(user: dict = Depends(usuario_atual)):
    """Retorna dados do usuário autenticado."""
    return {k: v for k, v in user.items() if k not in ("exp","iat")}

# ── Abastecimentos ────────────────────────────────────────────────
@app.get("/abastecimentos", tags=["abastecimentos"])
def listar_abastecimentos(
    dias: int = 30,
    placa: Optional[str] = None,
    produto: Optional[str] = None,
    limit: int = 100,
    offset: int = 0,
    user: dict = Depends(usuario_atual)
):
    """Lista abastecimentos da frota com filtros."""
    db = get_db()
    cnpj = user.get("cnpj_frota", "")
    if not cnpj:
        raise HTTPException(status_code=400, detail="CNPJ da frota não encontrado")
    
    from datetime import date, timedelta
    dt_ini = (date.today() - timedelta(days=dias)).isoformat()
    
    q = (db.table("profrotas_abastecimentos")
         .select("id,data_abastecimento,veiculo_placa,item_nome,item_quantidade,"
                 "item_valor_unitario,item_valor_total,pv_razao_social,pv_municipio,pv_uf,hodometro")
         .eq("cnpj_frota", cnpj)
         .eq("item_tipo", 1)
         .gte("data_abastecimento", dt_ini)
         .order("data_abastecimento", desc=True)
         .range(offset, offset + limit - 1))
    
    if placa:
        q = q.eq("veiculo_placa", placa.upper().strip())
    if produto:
        q = q.ilike("item_nome", f"%{produto}%")
    
    r = q.execute()
    return {
        "total": len(r.data or []),
        "offset": offset,
        "limit": limit,
        "data": r.data or []
    }

@app.get("/abastecimentos/resumo", tags=["abastecimentos"])
def resumo_abastecimentos(
    dias: int = 30,
    user: dict = Depends(usuario_atual)
):
    """Resumo de abastecimentos: total litros, gasto, média/dia, por combustível."""
    import pandas as pd
    from datetime import date, timedelta
    
    db = get_db()
    cnpj = user.get("cnpj_frota", "")
    dt_ini = (date.today() - timedelta(days=dias)).isoformat()
    
    r = db.table("profrotas_abastecimentos").select(
        "data_abastecimento,item_nome,item_quantidade,item_valor_total,veiculo_placa"
    ).eq("cnpj_frota", cnpj).eq("item_tipo", 1).gte(
        "data_abastecimento", dt_ini
    ).execute()
    
    df = pd.DataFrame(r.data or [])
    if df.empty:
        return {"total_litros": 0, "total_gasto": 0, "n_abastecimentos": 0, "por_combustivel": []}
    
    df["item_quantidade"]  = pd.to_numeric(df["item_quantidade"],  errors="coerce").fillna(0)
    df["item_valor_total"] = pd.to_numeric(df["item_valor_total"], errors="coerce").fillna(0)
    
    por_comb = df.groupby("item_nome").agg(
        litros=("item_quantidade", "sum"),
        gasto=("item_valor_total", "sum"),
        n=("item_quantidade", "count")
    ).reset_index().to_dict("records")
    
    return {
        "total_litros":      round(float(df["item_quantidade"].sum()), 2),
        "total_gasto":       round(float(df["item_valor_total"].sum()), 2),
        "n_abastecimentos":  len(df),
        "n_veiculos":        int(df["veiculo_placa"].nunique()),
        "media_dia":         round(float(df["item_quantidade"].sum()) / max(dias, 1), 2),
        "por_combustivel":   por_comb,
    }

# ── Frota / Veículos ──────────────────────────────────────────────
@app.get("/frota/veiculos", tags=["frota"])
def listar_veiculos(user: dict = Depends(usuario_atual)):
    """Lista veículos únicos da frota com último hodômetro."""
    import pandas as pd
    db = get_db()
    cnpj = user.get("cnpj_frota", "")
    
    r = db.table("profrotas_abastecimentos").select(
        "veiculo_placa,hodometro,data_abastecimento,item_nome"
    ).eq("cnpj_frota", cnpj).eq("item_tipo", 1).order(
        "data_abastecimento", desc=True
    ).limit(5000).execute()
    
    df = pd.DataFrame(r.data or [])
    if df.empty:
        return {"total": 0, "data": []}
    
    df["hodometro"] = pd.to_numeric(df["hodometro"], errors="coerce").fillna(0)
    veiculos = df.groupby("veiculo_placa").agg(
        ultimo_hodometro=("hodometro", "max"),
        ultimo_abastecimento=("data_abastecimento", "max"),
        combustivel=("item_nome", lambda x: x.mode().iloc[0] if len(x.mode()) > 0 else ""),
        n_abastecimentos=("item_nome", "count")
    ).reset_index().to_dict("records")
    
    return {"total": len(veiculos), "data": veiculos}

# ── Manutenção ────────────────────────────────────────────────────
@app.get("/manutencao", tags=["manutencao"])
def listar_manutencoes(
    placa: Optional[str] = None,
    limit: int = 50,
    user: dict = Depends(usuario_atual)
):
    """Lista manutenções registradas."""
    db = get_db()
    cnpj = re.sub(r"\D", "", user.get("cnpj_frota", ""))
    
    q = (db.table("manutencoes_realizadas")
         .select("*")
         .eq("cnpj_frota", cnpj)
         .order("data_manutencao", desc=True)
         .limit(limit))
    if placa:
        q = q.eq("placa", placa.upper().strip())
    
    r = q.execute()
    return {"total": len(r.data or []), "data": r.data or []}

# ── Tickets / Suporte ─────────────────────────────────────────────
@app.get("/tickets", tags=["tickets"])
def listar_tickets(user: dict = Depends(usuario_atual)):
    """Lista tickets do usuário."""
    db = get_db()
    email = user.get("email", "")
    empresa_id = user.get("empresa_id", "")
    perfil = user.get("perfil", "usuario")
    
    if perfil in ("admin", "super_admin"):
        r = db.table("tickets").select("*").order("criado_em", desc=True).limit(100).execute()
    else:
        r = db.table("tickets").select("*").eq("empresa_id", empresa_id).order(
            "criado_em", desc=True
        ).execute()
    
    return {"total": len(r.data or []), "data": r.data or []}

@app.post("/tickets", tags=["tickets"])
def criar_ticket(
    titulo: str,
    descricao: str,
    tipo: str = "melhoria",
    prioridade: str = "media",
    user: dict = Depends(usuario_atual)
):
    """Cria um novo ticket de suporte."""
    db = get_db()
    payload = {
        "titulo": titulo,
        "descricao": descricao,
        "tipo": tipo,
        "prioridade": prioridade,
        "status": "aberto",
        "user_email": user.get("email"),
        "empresa_id": user.get("empresa_id"),
        "comentarios": "[]",
        "anexos": "[]",
        "criado_em": datetime.now(tz=timezone.utc).isoformat(),
    }
    r = db.table("tickets").insert(payload).execute()
    return {"ok": True, "ticket": r.data[0] if r.data else {}}

# ── Financeiro ────────────────────────────────────────────────────
@app.get("/financeiro/resumo", tags=["financeiro"])
def resumo_financeiro(
    mes: Optional[str] = None,  # formato: "2026-06"
    user: dict = Depends(usuario_atual)
):
    """Resumo financeiro do mês: abastecimentos + manutenção por centro de custo."""
    import pandas as pd
    from datetime import date
    
    db = get_db()
    cnpj = re.sub(r"\D", "", user.get("cnpj_frota", ""))
    
    if mes:
        ano, m = mes.split("-")
        dt_ini = f"{ano}-{m}-01"
        import calendar
        last_day = calendar.monthrange(int(ano), int(m))[1]
        dt_fim = f"{ano}-{m}-{last_day:02d}"
    else:
        hoje = date.today()
        dt_ini = f"{hoje.year}-{hoje.month:02d}-01"
        dt_fim = hoje.isoformat()
    
    # Abastecimentos
    r = db.table("profrotas_abastecimentos").select(
        "item_valor_total,item_quantidade,veiculo_placa"
    ).eq("cnpj_frota", cnpj).eq("item_tipo", 1).gte(
        "data_abastecimento", dt_ini
    ).lte("data_abastecimento", dt_fim + "T23:59:59").execute()
    
    df = pd.DataFrame(r.data or [])
    total_comb = 0.0
    total_litros = 0.0
    if not df.empty:
        df["item_valor_total"] = pd.to_numeric(df["item_valor_total"], errors="coerce").fillna(0)
        df["item_quantidade"]  = pd.to_numeric(df["item_quantidade"],  errors="coerce").fillna(0)
        total_comb   = float(df["item_valor_total"].sum())
        total_litros = float(df["item_quantidade"].sum())
    
    # Manutenção
    r2 = db.table("manutencoes_realizadas").select(
        "custo_total,placa"
    ).eq("cnpj_frota", cnpj).gte("data_manutencao", dt_ini).lte(
        "data_manutencao", dt_fim
    ).execute()
    
    total_manut = sum(float(row.get("custo_total") or 0) for row in (r2.data or []))
    
    return {
        "periodo": {"inicio": dt_ini, "fim": dt_fim},
        "combustivel": {"total_gasto": round(total_comb, 2), "total_litros": round(total_litros, 2)},
        "manutencao": {"total_gasto": round(total_manut, 2), "n_registros": len(r2.data or [])},
        "total_geral": round(total_comb + total_manut, 2),
    }


# ── Manutenção Resumo ─────────────────────────────────────────────
@app.get("/manutencao/resumo", tags=["manutencao"])
def resumo_manutencao(
    dias: int = 30,
    user: dict = Depends(usuario_atual)
):
    """Resumo de manutenções: total gasto, por tipo, por veículo."""
    import pandas as pd
    from datetime import date, timedelta
    db = get_db()
    cnpj = re.sub(r"\D", "", user.get("cnpj_frota", ""))
    dt_ini = (date.today() - timedelta(days=dias)).isoformat()

    r = db.table("manutencoes_realizadas").select(
        "placa,custo_total,data_manutencao,hodometro,tecnico,oficina,itens_realizados,obs_gerais"
    ).eq("cnpj_frota", cnpj).gte("data_manutencao", dt_ini).order(
        "data_manutencao", desc=True
    ).execute()

    dados = r.data or []
    if not dados:
        return {"total_gasto": 0, "n_registros": 0, "por_oficina": [], "por_veiculo": [], "ultimas": []}

    df = pd.DataFrame(dados)
    df["custo_total"] = pd.to_numeric(df["custo_total"], errors="coerce").fillna(0)

    por_oficina = df.groupby("oficina").agg(
        total=("custo_total", "sum"),
        n=("custo_total", "count")
    ).reset_index().sort_values("total", ascending=False).head(10).to_dict("records")

    por_veiculo = df.groupby("placa").agg(
        total=("custo_total", "sum"),
        n=("custo_total", "count")
    ).reset_index().sort_values("total", ascending=False).head(10).to_dict("records")

    for d in por_oficina: d["total"] = round(float(d["total"]), 2)
    for d in por_veiculo: d["total"] = round(float(d["total"]), 2)

    df = df.fillna("")
    ultimas = df.head(20).to_dict("records")
    for u in ultimas:
        u["custo_total"] = float(u["custo_total"]) if u["custo_total"] != "" else 0.0
        if isinstance(u.get("itens_realizados"), list):
            u["itens_realizados"] = ", ".join(u["itens_realizados"])

    return {
        "total_gasto": round(float(df["custo_total"].sum()), 2),
        "n_registros": len(df),
        "n_veiculos": int(df["placa"].nunique()),
        "por_oficina": por_oficina,
        "por_veiculo": por_veiculo,
        "ultimas": ultimas,
    }


# ── Dashboard ─────────────────────────────────────────────────────
@app.get("/dashboard/resumo", tags=["dashboard"])
def dashboard_resumo(
    dias: int = 30,
    user: dict = Depends(usuario_atual)
):
    import pandas as pd
    from datetime import date, timedelta
    db = get_db()
    cnpj = re.sub(r"\D", "", user.get("cnpj_frota", ""))
    dt_ini = (date.today() - timedelta(days=dias)).isoformat()

    # Abastecimentos
    r = db.table("profrotas_abastecimentos").select(
        "data_abastecimento,item_quantidade,item_valor_total,veiculo_placa,pv_uf,pv_municipio"
    ).eq("cnpj_frota", cnpj).eq("item_tipo", 1).gte("data_abastecimento", dt_ini).execute()

    df = pd.DataFrame(r.data or [])
    if df.empty:
        return {"periodo": {"inicio": dt_ini, "fim": date.today().isoformat()},
                "abastecimentos": {}, "frota": {}, "manutencao": {}, "top_ufs": [], "top_veiculos": []}

    df["item_quantidade"]  = pd.to_numeric(df["item_quantidade"],  errors="coerce").fillna(0)
    df["item_valor_total"] = pd.to_numeric(df["item_valor_total"], errors="coerce").fillna(0)

    top_ufs = []
    if "pv_uf" in df.columns:
        top_ufs = df.groupby("pv_uf").agg(
            litros=("item_quantidade", "sum"),
            gasto=("item_valor_total", "sum"),
            n=("item_quantidade", "count")
        ).reset_index().sort_values("gasto", ascending=False).head(5).fillna("").to_dict("records")
        for t in top_ufs:
            t["litros"] = round(float(t["litros"]), 2)
            t["gasto"]  = round(float(t["gasto"]), 2)

    top_veiculos = df.groupby("veiculo_placa").agg(
        litros=("item_quantidade", "sum"),
        gasto=("item_valor_total", "sum"),
        n=("item_quantidade", "count")
    ).reset_index().sort_values("gasto", ascending=False).head(5).fillna("").to_dict("records")
    for t in top_veiculos:
        t["litros"] = round(float(t["litros"]), 2)
        t["gasto"]  = round(float(t["gasto"]), 2)

    # Manutenção
    r2 = db.table("manutencoes_realizadas").select("custo_total").eq(
        "cnpj_frota", cnpj).gte("data_manutencao", dt_ini).execute()
    total_manut = sum(float(x.get("custo_total") or 0) for x in (r2.data or []))

    return {
        "periodo": {"inicio": dt_ini, "fim": date.today().isoformat()},
        "abastecimentos": {
            "total_litros": round(float(df["item_quantidade"].sum()), 2),
            "total_gasto":  round(float(df["item_valor_total"].sum()), 2),
            "n_registros":  len(df),
            "n_veiculos":   int(df["veiculo_placa"].nunique()),
            "n_ufs":        int(df["pv_uf"].nunique()) if "pv_uf" in df.columns else 0,
            "media_litros_dia": round(float(df["item_quantidade"].sum()) / max(dias, 1), 2),
        },
        "manutencao": {"total_gasto": round(total_manut, 2), "n_registros": len(r2.data or [])},
        "total_geral": round(float(df["item_valor_total"].sum()) + total_manut, 2),
        "top_ufs": top_ufs,
        "top_veiculos": top_veiculos,
    }

# ── Inteligência ──────────────────────────────────────────────────
@app.get("/inteligencia/resumo", tags=["inteligencia"])
def inteligencia_resumo(
    dias: int = 90,
    user: dict = Depends(usuario_atual)
):
    import pandas as pd
    from datetime import date, timedelta
    db = get_db()
    cnpj = re.sub(r"\D", "", user.get("cnpj_frota", ""))
    dt_ini = (date.today() - timedelta(days=dias)).isoformat()

    r = db.table("profrotas_abastecimentos").select(
        "data_abastecimento,item_quantidade,item_valor_total,item_valor_unitario,veiculo_placa,pv_uf,pv_municipio,pv_razao_social"
    ).eq("cnpj_frota", cnpj).eq("item_tipo", 1).gte("data_abastecimento", dt_ini).execute()

    df = pd.DataFrame(r.data or [])
    if df.empty:
        return {"por_uf": [], "por_municipio": [], "por_veiculo": [], "preco_medio": 0}

    for col in ["item_quantidade", "item_valor_total", "item_valor_unitario"]:
        df[col] = pd.to_numeric(df[col], errors="coerce").fillna(0)

    por_uf = []
    if "pv_uf" in df.columns:
        por_uf = df.groupby("pv_uf").agg(
            litros=("item_quantidade", "sum"),
            gasto=("item_valor_total", "sum"),
            preco_medio=("item_valor_unitario", "mean"),
            n=("item_quantidade", "count")
        ).reset_index().sort_values("gasto", ascending=False).fillna(0).to_dict("records")
        for t in por_uf:
            t["litros"] = round(float(t["litros"]), 2)
            t["gasto"]  = round(float(t["gasto"]), 2)
            t["preco_medio"] = round(float(t["preco_medio"]), 4)

    por_municipio = []
    if "pv_municipio" in df.columns:
        por_municipio = df.groupby(["pv_municipio", "pv_uf"] if "pv_uf" in df.columns else ["pv_municipio"]).agg(
            litros=("item_quantidade", "sum"),
            gasto=("item_valor_total", "sum"),
            n=("item_quantidade", "count")
        ).reset_index().sort_values("gasto", ascending=False).head(20).fillna("").to_dict("records")
        for t in por_municipio:
            t["litros"] = round(float(t["litros"]), 2)
            t["gasto"]  = round(float(t["gasto"]), 2)

    por_veiculo = df.groupby("veiculo_placa").agg(
        litros=("item_quantidade", "sum"),
        gasto=("item_valor_total", "sum"),
        preco_medio=("item_valor_unitario", "mean"),
        n=("item_quantidade", "count")
    ).reset_index().sort_values("gasto", ascending=False).fillna(0).to_dict("records")
    for t in por_veiculo:
        t["litros"] = round(float(t["litros"]), 2)
        t["gasto"]  = round(float(t["gasto"]), 2)
        t["preco_medio"] = round(float(t["preco_medio"]), 4)

    preco_medio_geral = round(float(df["item_valor_unitario"].mean()), 4) if not df.empty else 0

    return {
        "por_uf": por_uf,
        "por_municipio": por_municipio,
        "por_veiculo": por_veiculo,
        "preco_medio": preco_medio_geral,
    }

# ── Variação de Preços ────────────────────────────────────────────
@app.get("/precos/variacao", tags=["precos"])
def precos_variacao(
    dias: int = 90,
    user: dict = Depends(usuario_atual)
):
    import pandas as pd
    from datetime import date, timedelta
    db = get_db()
    cnpj = re.sub(r"\D", "", user.get("cnpj_frota", ""))
    dt_ini = (date.today() - timedelta(days=dias)).isoformat()

    r = db.table("profrotas_abastecimentos").select(
        "data_abastecimento,item_nome,item_valor_unitario,pv_uf"
    ).eq("cnpj_frota", cnpj).eq("item_tipo", 1).gte(
        "data_abastecimento", dt_ini
    ).order("data_abastecimento").execute()

    df = pd.DataFrame(r.data or [])
    if df.empty:
        return {"por_combustivel": [], "serie_temporal": []}

    df["item_valor_unitario"] = pd.to_numeric(df["item_valor_unitario"], errors="coerce").fillna(0)
    df["data_abastecimento"]  = pd.to_datetime(df["data_abastecimento"], errors="coerce")
    df["mes"] = df["data_abastecimento"].dt.to_period("M").astype(str)

    por_combustivel = df.groupby("item_nome").agg(
        preco_medio=("item_valor_unitario", "mean"),
        preco_min=("item_valor_unitario", "min"),
        preco_max=("item_valor_unitario", "max"),
        n=("item_valor_unitario", "count")
    ).reset_index().fillna(0).to_dict("records")
    for t in por_combustivel:
        t["preco_medio"] = round(float(t["preco_medio"]), 4)
        t["preco_min"]   = round(float(t["preco_min"]), 4)
        t["preco_max"]   = round(float(t["preco_max"]), 4)

    serie = df.groupby(["mes", "item_nome"]).agg(
        preco_medio=("item_valor_unitario", "mean")
    ).reset_index().fillna(0).to_dict("records")
    for t in serie:
        t["preco_medio"] = round(float(t["preco_medio"]), 4)

    return {"por_combustivel": por_combustivel, "serie_temporal": serie}

# ── Relatórios ────────────────────────────────────────────────────
@app.get("/relatorios/abastecimentos", tags=["relatorios"])
def relatorio_abastecimentos(
    dias: int = 30,
    placa: Optional[str] = None,
    uf: Optional[str] = None,
    user: dict = Depends(usuario_atual)
):
    from datetime import date, timedelta
    db = get_db()
    cnpj = re.sub(r"\D", "", user.get("cnpj_frota", ""))
    dt_ini = (date.today() - timedelta(days=dias)).isoformat()

    q = db.table("profrotas_abastecimentos").select(
        "data_abastecimento,veiculo_placa,item_nome,item_quantidade,item_valor_unitario,item_valor_total,pv_razao_social,pv_municipio,pv_uf,hodometro"
    ).eq("cnpj_frota", cnpj).eq("item_tipo", 1).gte(
        "data_abastecimento", dt_ini
    ).order("data_abastecimento", desc=True).limit(500)

    if placa:
        q = q.eq("veiculo_placa", placa.upper().strip())
    if uf:
        q = q.eq("pv_uf", uf.upper().strip())

    r = q.execute()
    data = r.data or []
    for row in data:
        for k in ["item_quantidade", "item_valor_unitario", "item_valor_total"]:
            try: row[k] = round(float(row[k] or 0), 4)
            except: row[k] = 0.0

    return {"total": len(data), "data": data}


# ── Admin: Usuários ───────────────────────────────────────────────
@app.get("/admin/usuarios", tags=["admin"])
def listar_usuarios(user: dict = Depends(usuario_atual)):
    if user.get("perfil") != "admin":
        raise HTTPException(status_code=403, detail="Acesso restrito a admins")
    db = get_db()
    r = db.table("usuarios_app").select(
        "email,nome,perfil,cnpj_vinculado,empresa_nome,ativo,created_at"
    ).order("created_at", desc=True).execute()
    return {"total": len(r.data or []), "data": r.data or []}

@app.post("/admin/usuarios", tags=["admin"])
def criar_usuario(body: dict, user: dict = Depends(usuario_atual)):
    if user.get("perfil") != "admin":
        raise HTTPException(status_code=403, detail="Acesso restrito a admins")
    db = get_db()
    try:
        r = db.table("usuarios_app").insert(body).execute()
        return {"ok": True, "data": r.data}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.put("/admin/usuarios/{email}", tags=["admin"])
def atualizar_usuario(email: str, body: dict, user: dict = Depends(usuario_atual)):
    if user.get("perfil") != "admin":
        raise HTTPException(status_code=403, detail="Acesso restrito a admins")
    db = get_db()
    try:
        r = db.table("usuarios_app").update(body).eq("email", email).execute()
        return {"ok": True, "data": r.data}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.delete("/admin/usuarios/{email}", tags=["admin"])
def excluir_usuario(email: str, user: dict = Depends(usuario_atual)):
    if user.get("perfil") != "admin":
        raise HTTPException(status_code=403, detail="Acesso restrito a admins")
    db = get_db()
    try:
        db.table("usuarios_app").delete().eq("email", email).execute()
        return {"ok": True}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

# ── Acordos de Preço ──────────────────────────────────────────────
@app.get("/acordos", tags=["acordos"])
def listar_acordos(user: dict = Depends(usuario_atual)):
    db = get_db()
    cnpj = re.sub(r"\D", "", user.get("cnpj_frota", ""))
    r = db.table("acordos_precos").select(
        "id,cnpj_posto,nome_posto,combustivel,preco_negociado,va_desconto,dt_vigencia_inicio,dt_vigencia_fim,ativo"
    ).eq("cnpj_frota", cnpj).eq("ativo", True).execute()
    return {"total": len(r.data or []), "data": r.data or []}

# ── Roteirização ──────────────────────────────────────────────────
@app.get("/roteirizacao/postos", tags=["roteirizacao"])
def buscar_postos(
    uf: Optional[str] = None,
    municipio: Optional[str] = None,
    limit: int = 50,
    user: dict = Depends(usuario_atual)
):
    import pandas as pd
    db = get_db()
    cnpj = re.sub(r"\D", "", user.get("cnpj_frota", ""))
    q = db.table("profrotas_abastecimentos").select(
        "pv_cnpj,pv_razao_social,pv_municipio,pv_uf,pv_latitude,pv_longitude,item_nome"
    ).eq("cnpj_frota", cnpj).eq("item_tipo", 1)
    if uf:
        q = q.eq("pv_uf", uf.upper().strip())
    if municipio:
        q = q.ilike("pv_municipio", f"%{municipio}%")
    r = q.limit(1000).execute()
    df = pd.DataFrame(r.data or [])
    if df.empty:
        return {"total": 0, "data": []}
    postos = df.groupby("pv_cnpj").agg(
        razao_social=("pv_razao_social", "first"),
        municipio=("pv_municipio", "first"),
        uf=("pv_uf", "first"),
        lat=("pv_latitude", "first"),
        lon=("pv_longitude", "first"),
        combustiveis=("item_nome", lambda x: ", ".join(sorted(set(x.dropna())))),
        n_abastecimentos=("pv_cnpj", "count"),
    ).reset_index().fillna("").head(limit).to_dict("records")
    return {"total": len(postos), "data": postos}

@app.get("/roteirizacao/ufs", tags=["roteirizacao"])
def listar_ufs(user: dict = Depends(usuario_atual)):
    db = get_db()
    cnpj = re.sub(r"\D", "", user.get("cnpj_frota", ""))
    r = db.table("profrotas_abastecimentos").select("pv_uf").eq(
        "cnpj_frota", cnpj).eq("item_tipo", 1).execute()
    ufs = sorted(set(x["pv_uf"] for x in (r.data or []) if x.get("pv_uf")))
    return {"data": ufs}

# ── Assistente IA ─────────────────────────────────────────────────
@app.post("/assistente/chat", tags=["assistente"])
async def assistente_chat(body: dict, user: dict = Depends(usuario_atual)):
    import httpx
    import pandas as pd
    from datetime import date, timedelta
    pergunta = body.get("pergunta", "")
    cnpj = re.sub(r"\D", "", user.get("cnpj_frota", ""))
    if not pergunta:
        raise HTTPException(status_code=400, detail="Pergunta nao informada")

    anthropic_key = os.environ.get("ANTHROPIC_API_KEY", "")
    if not anthropic_key:
        return {"resposta": "Assistente IA nao configurado. Configure ANTHROPIC_API_KEY no Railway."}

    db = get_db()
    dt_ini = (date.today() - timedelta(days=90)).isoformat()
    try:
        r = db.table("profrotas_abastecimentos").select(
            "data_abastecimento,veiculo_placa,item_nome,item_quantidade,item_valor_unitario,item_valor_total,pv_municipio,pv_uf,motorista_nome"
        ).eq("cnpj_frota", cnpj).eq("item_tipo", 1).gte("data_abastecimento", dt_ini).execute()
        df = pd.DataFrame(r.data or [])
        if not df.empty:
            for col in ["item_quantidade","item_valor_unitario","item_valor_total"]:
                df[col] = pd.to_numeric(df[col], errors="coerce").fillna(0)
            resumo = f"""
DADOS REAIS DA FROTA (ultimos 90 dias):
- Total abastecimentos: {len(df)}
- Total litros: {df["item_quantidade"].sum():.0f} L
- Total gasto combustivel: R$ {df["item_valor_total"].sum():.2f}
- Preco medio por litro: R$ {df["item_valor_unitario"].mean():.4f}
- Veiculos ativos: {df["veiculo_placa"].nunique()}
- Estados visitados: {df["pv_uf"].nunique() if "pv_uf" in df.columns else "N/A"}

Por combustivel:
{df.groupby("item_nome").agg(litros=("item_quantidade","sum"), gasto=("item_valor_total","sum"), n=("item_nome","count")).to_string()}

Top 5 veiculos por gasto:
{df.groupby("veiculo_placa")["item_valor_total"].sum().sort_values(ascending=False).head(5).to_string()}

Por mes (aproximado):
{df.groupby(df["data_abastecimento"].str[:7])["item_valor_total"].sum().to_string()}
"""
        else:
            resumo = "Nenhum dado de abastecimento encontrado para os ultimos 90 dias."
        r2 = db.table("manutencoes_realizadas").select(
            "placa,custo_total,data_manutencao,oficina"
        ).eq("cnpj_frota", cnpj).gte("data_manutencao", dt_ini).execute()
        df2 = pd.DataFrame(r2.data or [])
        if not df2.empty:
            df2["custo_total"] = pd.to_numeric(df2["custo_total"], errors="coerce").fillna(0)
            resumo += f"""
MANUTENCAO (ultimos 90 dias):
- Total registros: {len(df2)}
- Total gasto: R$ {df2["custo_total"].sum():.2f}
- Veiculos: {df2["placa"].nunique()}
"""
    except Exception as e:
        resumo = f"Dados disponiveis. Erro interno: {type(e).__name__}: {str(e)[:200]}"

    sistema = f"""Voce e um assistente especializado em gestao de frotas da FNI.
O usuario e {user.get("nome", "gestor")} com perfil {user.get("perfil", "usuario")}.
CNPJ da frota: {cnpj}.
Data atual: {date.today().isoformat()}

{resumo}

Use os dados acima para responder perguntas sobre a frota do cliente.
Responda de forma objetiva, pratica e use os numeros reais dos dados acima.
Responda sempre em portugues brasileiro.
Se perguntarem sobre dados fora do periodo de 90 dias, informe que so tem dados dos ultimos 90 dias."""

    async with httpx.AsyncClient() as client:
        resp = await client.post(
            "https://api.anthropic.com/v1/messages",
            headers={"x-api-key": anthropic_key, "anthropic-version": "2023-06-01",
                     "content-type": "application/json"},
            json={"model": "claude-haiku-4-5-20251001", "max_tokens": 1024,
                  "system": sistema,
                  "messages": [{"role": "user", "content": pergunta}]},
            timeout=60,
        )
    if resp.status_code != 200:
        raise HTTPException(status_code=500, detail="Erro ao chamar IA")
    data = resp.json()
    resposta = data["content"][0]["text"] if data.get("content") else "Sem resposta"
    return {"resposta": resposta}

# ── Centro de Custo ───────────────────────────────────────────────
@app.get("/centros-custo", tags=["centros_custo"])
def listar_centros_custo(user: dict = Depends(usuario_atual)):
    db = get_db()
    cnpj = re.sub(r"\D", "", user.get("cnpj_frota", ""))
    r = db.table("centros_custo").select("*").eq("cnpj_frota", cnpj).execute()
    return {"total": len(r.data or []), "data": r.data or []}


# ── Manutenção CRUD ───────────────────────────────────────────────
@app.post("/manutencao", tags=["manutencao"])
def criar_manutencao(body: dict, user: dict = Depends(usuario_atual)):
    db = get_db()
    cnpj = re.sub(r"\D", "", user.get("cnpj_frota", ""))
    body["cnpj_frota"] = cnpj
    body["criado_por"] = user.get("email", "")
    try:
        r = db.table("manutencoes_realizadas").insert(body).execute()
        return {"ok": True, "data": r.data}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.put("/manutencao/{id}", tags=["manutencao"])
def atualizar_manutencao(id: int, body: dict, user: dict = Depends(usuario_atual)):
    db = get_db()
    cnpj = re.sub(r"\D", "", user.get("cnpj_frota", ""))
    try:
        r = db.table("manutencoes_realizadas").update(body).eq("id", id).eq("cnpj_frota", cnpj).execute()
        return {"ok": True, "data": r.data}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.delete("/manutencao/{id}", tags=["manutencao"])
def deletar_manutencao(id: int, user: dict = Depends(usuario_atual)):
    db = get_db()
    cnpj = re.sub(r"\D", "", user.get("cnpj_frota", ""))
    try:
        db.table("manutencoes_realizadas").delete().eq("id", id).eq("cnpj_frota", cnpj).execute()
        return {"ok": True}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

# ── Centros de Custo CRUD ─────────────────────────────────────────
@app.post("/centros-custo", tags=["centros_custo"])
def criar_centro_custo(body: dict, user: dict = Depends(usuario_atual)):
    db = get_db()
    cnpj = re.sub(r"\D", "", user.get("cnpj_frota", ""))
    body["cnpj_frota"] = cnpj
    body["criado_por"] = user.get("email", "")
    try:
        r = db.table("centros_custo").insert(body).execute()
        return {"ok": True, "data": r.data}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.put("/centros-custo/{id}", tags=["centros_custo"])
def atualizar_centro_custo(id: str, body: dict, user: dict = Depends(usuario_atual)):
    db = get_db()
    cnpj = re.sub(r"\D", "", user.get("cnpj_frota", ""))
    try:
        r = db.table("centros_custo").update(body).eq("id", id).eq("cnpj_frota", cnpj).execute()
        return {"ok": True, "data": r.data}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.delete("/centros-custo/{id}", tags=["centros_custo"])
def deletar_centro_custo(id: str, user: dict = Depends(usuario_atual)):
    db = get_db()
    cnpj = re.sub(r"\D", "", user.get("cnpj_frota", ""))
    try:
        db.table("centros_custo").delete().eq("id", id).eq("cnpj_frota", cnpj).execute()
        return {"ok": True}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

# ── Acordos CRUD ──────────────────────────────────────────────────
@app.post("/acordos", tags=["acordos"])
def criar_acordo(body: dict, user: dict = Depends(usuario_atual)):
    db = get_db()
    cnpj = re.sub(r"\D", "", user.get("cnpj_frota", ""))
    body["cnpj_frota"] = cnpj
    body["ativo"] = True
    try:
        r = db.table("acordos_precos").insert(body).execute()
        return {"ok": True, "data": r.data}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.put("/acordos/{id}", tags=["acordos"])
def atualizar_acordo(id: str, body: dict, user: dict = Depends(usuario_atual)):
    db = get_db()
    try:
        r = db.table("acordos_precos").update(body).eq("id", id).execute()
        return {"ok": True, "data": r.data}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.delete("/acordos/{id}", tags=["acordos"])
def deletar_acordo(id: str, user: dict = Depends(usuario_atual)):
    db = get_db()
    try:
        db.table("acordos_precos").update({"ativo": False}).eq("id", id).execute()
        return {"ok": True}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

# ── Perfis de Veículo CRUD ────────────────────────────────────────
@app.get("/frota/perfis", tags=["frota"])
def listar_perfis_veiculo(user: dict = Depends(usuario_atual)):
    db = get_db()
    email = user.get("email", "")
    cnpj  = re.sub(r"\D", "", user.get("cnpj_frota", ""))
    r = db.table("perfis_veiculo").select("*").eq("empresa_id", cnpj).execute()
    if not r.data:
        r = db.table("perfis_veiculo").select("*").eq("usuario_email", email).execute()
    return {"total": len(r.data or []), "data": r.data or []}

@app.post("/frota/perfis", tags=["frota"])
def criar_perfil_veiculo(body: dict, user: dict = Depends(usuario_atual)):
    db = get_db()
    body["usuario_email"] = user.get("email", "")
    body["empresa_id"]    = re.sub(r"\D", "", user.get("cnpj_frota", ""))
    try:
        r = db.table("perfis_veiculo").insert(body).execute()
        return {"ok": True, "data": r.data}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.put("/frota/perfis/{id}", tags=["frota"])
def atualizar_perfil_veiculo(id: str, body: dict, user: dict = Depends(usuario_atual)):
    db = get_db()
    try:
        r = db.table("perfis_veiculo").update(body).eq("id", id).execute()
        return {"ok": True, "data": r.data}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.delete("/frota/perfis/{id}", tags=["frota"])
def deletar_perfil_veiculo(id: str, user: dict = Depends(usuario_atual)):
    db = get_db()
    try:
        db.table("perfis_veiculo").delete().eq("id", id).execute()
        return {"ok": True}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

# ── Roteirização: veículos com perfil ────────────────────────────
@app.get("/roteirizacao/veiculos", tags=["roteirizacao"])
def veiculos_para_rota(user: dict = Depends(usuario_atual)):
    db = get_db()
    email = user.get("email", "")
    cnpj  = re.sub(r"\D", "", user.get("cnpj_frota", ""))
    r = db.table("perfis_veiculo").select("*").eq("empresa_id", cnpj).execute()
    if not r.data:
        r = db.table("perfis_veiculo").select("*").eq("usuario_email", email).execute()
    return {"total": len(r.data or []), "data": r.data or []}


# ── Roteirização: Calcular Rota + Postos Sugeridos ───────────────
@app.post("/roteirizacao/calcular", tags=["roteirizacao"])
async def calcular_rota_api(body: dict, user: dict = Depends(usuario_atual)):
    """
    Calcula rota entre origem e destino, sugere postos ao longo da rota.
    Body: {
        origem: {lat, lon, nome},
        destino: {lat, lon, nome},
        paradas: [{lat, lon, nome}],  # opcional
        veiculo: {tanque, autonomia, combustivel},
        raio_km: 5,  # raio para buscar postos ao longo da rota
        pesos: {preco: 0.6, score: 0.2, desvio: 0.2}
    }
    """
    import httpx, math
    from datetime import date, timedelta

    origem   = body.get("origem", {})
    destino  = body.get("destino", {})
    paradas  = body.get("paradas", [])
    veiculo  = body.get("veiculo", {})
    raio_km  = float(body.get("raio_km", 5))
    pesos    = body.get("pesos", {"preco": 0.6, "score": 0.2, "desvio": 0.2})

    if not origem.get("lat") or not destino.get("lat"):
        raise HTTPException(status_code=400, detail="Origem e destino obrigatorios")

    rcap = float(veiculo.get("tanque", 80))
    raut = float(veiculo.get("autonomia", 10))
    comb = veiculo.get("combustivel", "")

    # 1. Calcular rota via OSRM
    pontos = [[origem["lat"], origem["lon"]]]
    for p in paradas:
        pontos.append([p["lat"], p["lon"]])
    pontos.append([destino["lat"], destino["lon"]])

    coords_str = ";".join(f"{lon},{lat}" for lat, lon in pontos)
    osrm_url = f"https://router.project-osrm.org/route/v1/driving/{coords_str}"

    coords_rota = []
    dist_km = 0
    dur_min = 0
    linha_reta = False

    try:
        async with httpx.AsyncClient() as client:
            resp = await client.get(osrm_url,
                params={"overview": "full", "geometries": "geojson"}, timeout=10)
        d = resp.json()
        if d.get("code") == "Ok":
            geo = d["routes"][0]["geometry"]["coordinates"]
            coords_rota = [[c[1], c[0]] for c in geo]
            dist_km = d["routes"][0]["distance"] / 1000
            dur_min = d["routes"][0]["duration"] / 60
        else:
            linha_reta = True
    except Exception:
        linha_reta = True

    if linha_reta or not coords_rota:
        # Fallback linha reta
        coords_rota = []
        for i in range(len(pontos) - 1):
            la1, lo1 = pontos[i]; la2, lo2 = pontos[i+1]
            for j in range(20):
                t = j / 20
                coords_rota.append([la1 + (la2-la1)*t, lo1 + (lo2-lo1)*t])
        coords_rota.append(pontos[-1])
        dist_km = sum(
            math.sqrt((pontos[i][0]-pontos[i+1][0])**2 + (pontos[i][1]-pontos[i+1][1])**2) * 111
            for i in range(len(pontos)-1)
        )
        dur_min = (dist_km / 80) * 60

    # 2. Buscar postos da frota ao longo da rota
    db = get_db()
    cnpj = re.sub(r"\D", "", user.get("cnpj_frota", ""))
    dt_ini = (date.today() - timedelta(days=180)).isoformat()

    r = db.table("profrotas_abastecimentos").select(
        "pv_cnpj,pv_razao_social,pv_municipio,pv_uf,pv_latitude,pv_longitude,item_nome,item_valor_unitario"
    ).eq("cnpj_frota", cnpj).eq("item_tipo", 1).gte("data_abastecimento", dt_ini).execute()

    import pandas as pd
    df = pd.DataFrame(r.data or [])
    postos_candidatos = []

    if not df.empty:
        df["item_valor_unitario"] = pd.to_numeric(df["item_valor_unitario"], errors="coerce").fillna(0)
        df["pv_latitude"]  = pd.to_numeric(df["pv_latitude"],  errors="coerce")
        df["pv_longitude"] = pd.to_numeric(df["pv_longitude"], errors="coerce")
        df = df.dropna(subset=["pv_latitude","pv_longitude"])
        if comb:
            df_comb = df[df["item_nome"].str.contains(comb, case=False, na=False)]
            if not df_comb.empty:
                df = df_comb

        # Preco medio por posto
        precos = df.groupby("pv_cnpj").agg(
            razao_social=("pv_razao_social","first"),
            municipio=("pv_municipio","first"),
            uf=("pv_uf","first"),
            lat=("pv_latitude","first"),
            lon=("pv_longitude","first"),
            combustivel=("item_nome","first"),
            preco=("item_valor_unitario","mean"),
        ).reset_index()

        # Filtra postos próximos à rota
        step = max(1, len(coords_rota) // 50)
        rota_sample = coords_rota[::step]

        for _, posto in precos.iterrows():
            plat, plon = posto["lat"], posto["lon"]
            if pd.isna(plat) or pd.isna(plon):
                continue
            # Distância mínima a qualquer ponto da rota
            min_dev = min(
                math.sqrt((plat - rlat)**2 + (plon - rlon)**2) * 111
                for rlat, rlon in rota_sample
            )
            if min_dev > raio_km:
                continue
            # Posição aproximada na rota (km)
            km_na_rota = min(
                (i / len(rota_sample)) * dist_km
                for i, (rlat, rlon) in enumerate(rota_sample)
                if math.sqrt((plat-rlat)**2 + (plon-rlon)**2)*111 < raio_km + 1
            ) if rota_sample else 0

            postos_candidatos.append({
                "cnpj": posto["pv_cnpj"],
                "razao_social": posto["razao_social"],
                "municipio": posto["municipio"],
                "uf": posto["uf"],
                "lat": round(float(plat), 6),
                "lon": round(float(plon), 6),
                "combustivel": posto["combustivel"],
                "preco": round(float(posto["preco"]), 4),
                "_km": round(km_na_rota, 1),
                "_dev": round(min_dev, 2),
            })

        postos_candidatos.sort(key=lambda x: x["_km"])

    # 3. Motor de otimização greedy
    sugestoes = []
    if postos_candidatos and rcap > 0 and raut > 0:
        rmin = rcap * 0.25
        PCT_BAIXO = 0.65
        VANT_PRECO = 0.03
        _precos = [e["preco"] for e in postos_candidatos if e["preco"] > 0]
        _pmin = min(_precos) if _precos else 0
        _pmax = max(_precos) if _precos else 1

        def _met(e):
            _p = 1.0 - (e["preco"] - _pmin) / max(_pmax - _pmin, 0.01)
            _d = 1.0 - min(e.get("_dev", 0) / 5.0, 1.0)
            return pesos.get("preco", 0.6) * _p + pesos.get("desvio", 0.2) * _d

        pos = 0.0
        fuel = float(rcap)
        seen = set()
        ult_preco = None

        for _ in range(30):
            if pos >= dist_km:
                break
            can_go = (fuel - rmin) * raut
            must = pos + can_go
            if must >= dist_km:
                break

            janela = [e for e in postos_candidatos if pos < e["_km"] <= must and e["cnpj"] not in seen]
            if not janela:
                alem = [e for e in postos_candidatos if e["_km"] > pos and e["cnpj"] not in seen]
                if not alem:
                    break
                best = dict(min(alem, key=lambda x: x["_km"]))
                best["motivo"] = "emergencia"
            else:
                best = dict(max(janela, key=_met))
                best["motivo"] = "otimizado"

            km_ate = best["_km"] - pos
            fuel_chegada = max(0.0, fuel - km_ate / raut)
            pct_chegada = fuel_chegada / rcap * 100

            if (best.get("motivo") != "emergencia"
                    and pct_chegada >= PCT_BAIXO * 100
                    and ult_preco is not None
                    and best.get("preco", 9999) >= ult_preco * (1 - VANT_PRECO)):
                pos = best["_km"]
                fuel = fuel_chegada
                seen.add(best["cnpj"])
                continue

            dist_rest = dist_km - best["_km"]
            litros_sug = min(rcap - fuel_chegada, rcap * 0.95 - fuel_chegada)
            litros_sug = max(0, litros_sug)
            custo = round(litros_sug * best["preco"], 2)
            fuel_apos = fuel_chegada + litros_sug

            best["litros_sugeridos"] = round(litros_sug, 1)
            best["custo_abast"] = custo
            best["fuel_chegada_pct"] = round(pct_chegada, 1)
            best["fuel_apos_pct"] = round(fuel_apos / rcap * 100, 1)
            sugestoes.append(best)

            pos = best["_km"]
            fuel = fuel_apos
            ult_preco = best["preco"]
            seen.add(best["cnpj"])

    custo_total = sum(s.get("custo_abast", 0) for s in sugestoes)
    litros_total = sum(s.get("litros_sugeridos", 0) for s in sugestoes)

    return {
        "rota": {
            "coords": coords_rota[::max(1, len(coords_rota)//200)],  # max 200 pontos
            "dist_km": round(dist_km, 1),
            "dur_min": round(dur_min, 1),
            "linha_reta": linha_reta,
        },
        "veiculo": {"tanque": rcap, "autonomia": raut, "combustivel": comb},
        "sugestoes": sugestoes,
        "resumo": {
            "n_paradas": len(sugestoes),
            "custo_total": round(custo_total, 2),
            "litros_total": round(litros_total, 1),
            "custo_por_km": round(custo_total / max(dist_km, 1), 4),
        },
        "origem": origem,
        "destino": destino,
    }

# ── Entry point (desenvolvimento local) ──────────────────────────
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("api_server:app", host="0.0.0.0", port=8001, reload=True)
