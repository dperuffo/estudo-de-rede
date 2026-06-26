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
    
    df["hodometro"] = pd.to_numeric(df["hodometro"], errors="coerce")
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

# ── Entry point (desenvolvimento local) ──────────────────────────
if __name__ == "__main__":
    import uvicorn
    uvicorn.run("api_server:app", host="0.0.0.0", port=8001, reload=True)
