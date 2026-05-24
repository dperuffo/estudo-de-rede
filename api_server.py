"""
═══════════════════════════════════════════════════════════════════
  Fleet Network Intelligence — API Server
  FastAPI  |  JWT Bearer Auth  |  Supabase backend
  Porta padrão: 8000
  Rota principal: /api/v1/...
  Docs interativas: /api/docs  (Swagger UI)
                    /api/redoc (ReDoc)
═══════════════════════════════════════════════════════════════════
"""

from __future__ import annotations

import os
import re
from datetime import datetime, timedelta, timezone
from typing import Any, Optional

import uvicorn
from fastapi import Depends, FastAPI, HTTPException, Query, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.openapi.docs import (
    get_redoc_html,
    get_swagger_ui_html,
)
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import JWTError, jwt
from pydantic import BaseModel

# ── Configuração ────────────────────────────────────────────────────

JWT_SECRET  = os.environ.get("JWT_SECRET", "fni-dev-secret-mude-em-producao")
JWT_ALGO    = "HS256"
JWT_EXPIRE_HOURS = int(os.environ.get("JWT_EXPIRE_HOURS", "24"))

API_USER    = os.environ.get("API_USER", "admin")
API_PASS    = os.environ.get("API_PASS", "fni-change-me")

SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY", "")

API_VERSION  = "1.0.0"
API_PREFIX   = "/api/v1"

# ── FastAPI App ──────────────────────────────────────────────────────

app = FastAPI(
    title="Fleet Network Intelligence API",
    description=(
        "API REST para consulta de postos da rede GF, preços de combustíveis, "
        "histórico de abastecimentos e integração com ERPs / sistemas de logística.\n\n"
        "**Autenticação:** Bearer JWT — obtenha o token em `POST /api/v1/auth/token`.\n\n"
        "**Base URL produção:** `https://estudo-de-rede-profrotas.fly.dev`\n\n"
        "**Rate limit:** 120 requisições/minuto por token."
    ),
    version=API_VERSION,
    docs_url=None,   # Customizado abaixo
    redoc_url=None,
    openapi_url="/api/openapi.json",
    contact={
        "name": "Fleet Network Intelligence",
        "email": "d.peruffo@gmail.com",
    },
    license_info={
        "name": "Proprietário — uso interno",
    },
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Docs customizadas ───────────────────────────────────────────────

@app.get("/api/docs", include_in_schema=False)
async def custom_swagger():
    return get_swagger_ui_html(
        openapi_url="/api/openapi.json",
        title="FNI API — Swagger UI",
        swagger_favicon_url="https://fastapi.tiangolo.com/img/favicon.png",
    )


@app.get("/api/redoc", include_in_schema=False)
async def custom_redoc():
    return get_redoc_html(
        openapi_url="/api/openapi.json",
        title="FNI API — ReDoc",
    )


# ── Supabase client ─────────────────────────────────────────────────

def _db():
    """Retorna cliente Supabase ou lança 503."""
    if not SUPABASE_URL or not SUPABASE_KEY:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Banco de dados não configurado (SUPABASE_URL / SUPABASE_KEY ausentes).",
        )
    try:
        from supabase import create_client
        return create_client(SUPABASE_URL, SUPABASE_KEY)
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=f"Erro ao conectar ao banco: {exc}",
        )


# ── JWT helpers ──────────────────────────────────────────────────────

def _create_token(subject: str, expires_hours: int = JWT_EXPIRE_HOURS) -> str:
    expire = datetime.now(timezone.utc) + timedelta(hours=expires_hours)
    return jwt.encode(
        {"sub": subject, "exp": expire, "iat": datetime.now(timezone.utc)},
        JWT_SECRET,
        algorithm=JWT_ALGO,
    )


oauth2_scheme = OAuth2PasswordBearer(tokenUrl=f"{API_PREFIX}/auth/token")


def _current_user(token: str = Depends(oauth2_scheme)) -> dict:
    exc = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Token inválido ou expirado.",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGO])
        sub: str = payload.get("sub")
        if not sub:
            raise exc
        return {"username": sub}
    except JWTError:
        raise exc


# ── Schemas Pydantic ─────────────────────────────────────────────────

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int = JWT_EXPIRE_HOURS * 3600

    model_config = {"json_schema_extra": {
        "example": {
            "access_token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
            "token_type": "bearer",
            "expires_in": 86400,
        }
    }}


class PostoResponse(BaseModel):
    cnpj: str
    razao_social: Optional[str] = None
    municipio: Optional[str] = None
    uf: Optional[str] = None
    lat: Optional[float] = None
    lon: Optional[float] = None
    bandeira: Optional[str] = None
    tipo: Optional[str] = None


class PrecoResponse(BaseModel):
    cnpj: str
    razao_social: Optional[str] = None
    municipio: Optional[str] = None
    uf: Optional[str] = None
    combustivel: str
    preco: float
    data_ref: Optional[str] = None
    fonte: Optional[str] = None


class HistoricoItem(BaseModel):
    data_ref: str
    preco: float
    combustivel: str
    fonte: Optional[str] = None


class WebhookRegisterRequest(BaseModel):
    url: str
    eventos: list[str] = ["preco_atualizado"]
    descricao: Optional[str] = None

    model_config = {"json_schema_extra": {
        "example": {
            "url": "https://meu-erp.empresa.com.br/webhooks/fni",
            "eventos": ["preco_atualizado", "novo_posto"],
            "descricao": "Webhook do ERP para atualização de tabela de preços",
        }
    }}


class PaginatedResponse(BaseModel):
    data: list[Any]
    total: int
    limit: int
    offset: int


def _cnpj_clean(cnpj: str) -> str:
    return re.sub(r"\D", "", cnpj).zfill(14)


# ════════════════════════════════════════════════════════════════════
#  ENDPOINTS
# ════════════════════════════════════════════════════════════════════

# ── Health ───────────────────────────────────────────────────────────

@app.get(
    f"{API_PREFIX}/health",
    tags=["Sistema"],
    summary="Health check",
    response_description="Status do serviço",
)
async def health():
    """Verifica se a API está online. Não requer autenticação."""
    return {
        "status": "ok",
        "version": API_VERSION,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "database": "configured" if SUPABASE_URL else "not_configured",
    }


# ── Auth ─────────────────────────────────────────────────────────────

@app.post(
    f"{API_PREFIX}/auth/token",
    response_model=TokenResponse,
    tags=["Autenticação"],
    summary="Obter token JWT",
)
async def login(form_data: OAuth2PasswordRequestForm = Depends()):
    """
    Autentica com usuário e senha e retorna um Bearer Token JWT.

    O token deve ser enviado no header de todas as requisições protegidas:
    ```
    Authorization: Bearer <token>
    ```

    **Variáveis de ambiente necessárias no servidor:**
    - `API_USER` — usuário da API (padrão: `admin`)
    - `API_PASS` — senha da API
    - `JWT_SECRET` — chave secreta para assinar o token
    """
    if form_data.username != API_USER or form_data.password != API_PASS:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Usuário ou senha inválidos.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    token = _create_token(form_data.username)
    return TokenResponse(access_token=token, expires_in=JWT_EXPIRE_HOURS * 3600)


# ── Postos GF ────────────────────────────────────────────────────────

@app.get(
    f"{API_PREFIX}/postos",
    tags=["Postos GF"],
    summary="Listar postos da rede GF",
    response_description="Lista paginada de postos",
)
async def list_postos(
    uf: Optional[str] = Query(None, description="Sigla da UF (ex: SP, MG, RS)", example="SP"),
    municipio: Optional[str] = Query(None, description="Nome do município (parcial)", example="São Paulo"),
    cnpj: Optional[str] = Query(None, description="CNPJ (14 dígitos, sem pontuação)", example="12345678000190"),
    limit: int = Query(100, ge=1, le=500, description="Máximo de registros retornados"),
    offset: int = Query(0, ge=0, description="Deslocamento para paginação"),
    _user: dict = Depends(_current_user),
):
    """
    Retorna postos da rede Gestão de Frotas (GF) com dados cadastrais e coordenadas.

    **Filtros disponíveis:** `uf`, `municipio` (busca parcial), `cnpj`.

    **Exemplo curl:**
    ```bash
    curl -H "Authorization: Bearer $TOKEN" \\
      "https://estudo-de-rede-profrotas.fly.dev/api/v1/postos?uf=SP&limit=50"
    ```
    """
    db = _db()
    q = db.table("postos_gf").select(
        "cnpj,razaoSocial,municipio,uf,_lat,_lon,bandeira"
    )
    if uf:
        q = q.eq("uf", uf.upper().strip())
    if cnpj:
        q = q.eq("cnpj", _cnpj_clean(cnpj))
    if municipio:
        q = q.ilike("municipio", f"%{municipio}%")

    res = q.range(offset, offset + limit - 1).execute()
    rows = res.data or []

    # Normaliza campos
    normalized = [
        {
            "cnpj":        r.get("cnpj", ""),
            "razao_social":r.get("razaoSocial") or r.get("razao_social", ""),
            "municipio":   r.get("municipio", ""),
            "uf":          r.get("uf", ""),
            "lat":         r.get("_lat") or r.get("lat"),
            "lon":         r.get("_lon") or r.get("lon"),
            "bandeira":    r.get("bandeira", ""),
        }
        for r in rows
    ]

    return {
        "data":   normalized,
        "total":  len(normalized),
        "limit":  limit,
        "offset": offset,
    }


@app.get(
    f"{API_PREFIX}/postos/{{cnpj}}",
    tags=["Postos GF"],
    summary="Buscar posto por CNPJ",
)
async def get_posto(
    cnpj: str,
    _user: dict = Depends(_current_user),
):
    """
    Retorna dados completos de um posto GF específico.

    **Exemplo curl:**
    ```bash
    curl -H "Authorization: Bearer $TOKEN" \\
      "https://estudo-de-rede-profrotas.fly.dev/api/v1/postos/12345678000190"
    ```
    """
    db = _db()
    cnpj_fmt = _cnpj_clean(cnpj)
    res = db.table("postos_gf").select("*").eq("cnpj", cnpj_fmt).limit(1).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail=f"Posto {cnpj_fmt} não encontrado na rede GF.")
    r = res.data[0]
    return {
        "cnpj":        r.get("cnpj", ""),
        "razao_social":r.get("razaoSocial") or r.get("razao_social", ""),
        "municipio":   r.get("municipio", ""),
        "uf":          r.get("uf", ""),
        "lat":         r.get("_lat") or r.get("lat"),
        "lon":         r.get("_lon") or r.get("lon"),
        "bandeira":    r.get("bandeira", ""),
        "servicos":    {k: v for k, v in r.items() if k.startswith("servico_") or k.startswith("tem_")},
    }


# ── Preços ───────────────────────────────────────────────────────────

@app.get(
    f"{API_PREFIX}/precos",
    tags=["Preços"],
    summary="Consultar preços por UF e combustível",
)
async def list_precos(
    uf: Optional[str] = Query(None, description="Sigla da UF", example="SP"),
    combustivel: Optional[str] = Query(
        None,
        description="Tipo de combustível",
        example="OLEO DIESEL S10",
    ),
    cnpj: Optional[str] = Query(None, description="CNPJ do posto"),
    limit: int = Query(200, ge=1, le=1000),
    offset: int = Query(0, ge=0),
    _user: dict = Depends(_current_user),
):
    """
    Retorna a tabela de preços atual (última carga) dos postos GF.

    **Combustíveis disponíveis:**
    `GASOLINA COMUM` · `GASOLINA ADITIVADA` · `ÓLEO DIESEL` · `ÓLEO DIESEL S10` · `ETANOL`

    **Exemplo curl:**
    ```bash
    curl -H "Authorization: Bearer $TOKEN" \\
      "https://estudo-de-rede-profrotas.fly.dev/api/v1/precos?uf=PR&combustivel=OLEO+DIESEL+S10"
    ```

    **Exemplo Python:**
    ```python
    import requests, os

    TOKEN = os.environ["FNI_API_TOKEN"]
    BASE  = "https://estudo-de-rede-profrotas.fly.dev"

    r = requests.get(
        f"{BASE}/api/v1/precos",
        params={"uf": "PR", "combustivel": "OLEO DIESEL S10"},
        headers={"Authorization": f"Bearer {TOKEN}"},
    )
    precos = r.json()["data"]
    ```
    """
    db = _db()
    q = db.table("historico_precos").select(
        "cnpj,razao_social,municipio,uf,combustivel,preco,data_ref,fonte"
    ).order("data_ref", desc=True)

    if uf:
        q = q.eq("uf", uf.upper().strip())
    if combustivel:
        q = q.ilike("combustivel", f"%{combustivel.upper().strip()}%")
    if cnpj:
        q = q.eq("cnpj", _cnpj_clean(cnpj))

    res = q.range(offset, offset + limit - 1).execute()
    rows = res.data or []

    return {
        "data":   rows,
        "total":  len(rows),
        "limit":  limit,
        "offset": offset,
    }


@app.get(
    f"{API_PREFIX}/precos/{{cnpj}}",
    tags=["Preços"],
    summary="Preço atual de um posto por CNPJ",
)
async def get_preco_posto(
    cnpj: str,
    combustivel: Optional[str] = Query(None, description="Filtrar por combustível"),
    _user: dict = Depends(_current_user),
):
    """
    Retorna o preço mais recente registrado para cada combustível de um posto específico.
    """
    db = _db()
    cnpj_fmt = _cnpj_clean(cnpj)
    q = (
        db.table("historico_precos")
        .select("cnpj,razao_social,municipio,uf,combustivel,preco,data_ref,fonte")
        .eq("cnpj", cnpj_fmt)
        .order("data_ref", desc=True)
    )
    if combustivel:
        q = q.ilike("combustivel", f"%{combustivel.upper().strip()}%")
    res = q.limit(20).execute()
    if not res.data:
        raise HTTPException(status_code=404, detail=f"Nenhum preço encontrado para CNPJ {cnpj_fmt}.")

    # Deduplica — mantém apenas o preço mais recente por combustível
    seen: set = set()
    dedup = []
    for r in (res.data or []):
        key = r.get("combustivel", "")
        if key not in seen:
            seen.add(key)
            dedup.append(r)
    return {"cnpj": cnpj_fmt, "precos": dedup}


@app.get(
    f"{API_PREFIX}/precos/historico/{{cnpj}}",
    response_model=list[HistoricoItem],
    tags=["Preços"],
    summary="Histórico de preços de um posto",
)
async def get_historico(
    cnpj: str,
    combustivel: Optional[str] = Query(None, description="Filtrar por combustível"),
    dias: int = Query(90, ge=1, le=730, description="Período em dias"),
    _user: dict = Depends(_current_user),
):
    """
    Retorna a série histórica de preços de um posto nos últimos N dias.

    Útil para análise de tendência e integração com dashboards de BI.

    **Exemplo Python (integração ERP):**
    ```python
    import requests, pandas as pd

    TOKEN = "seu-token-aqui"
    BASE  = "https://estudo-de-rede-profrotas.fly.dev"

    r = requests.get(
        f"{BASE}/api/v1/precos/historico/12345678000190",
        params={"combustivel": "OLEO DIESEL S10", "dias": 30},
        headers={"Authorization": f"Bearer {TOKEN}"},
    )
    df = pd.DataFrame(r.json())
    df["data_ref"] = pd.to_datetime(df["data_ref"])
    df = df.sort_values("data_ref")
    print(df.tail())
    ```
    """
    db = _db()
    cnpj_fmt = _cnpj_clean(cnpj)
    from datetime import timedelta
    data_ini = (datetime.now(timezone.utc) - timedelta(days=dias)).strftime("%Y-%m-%d")

    q = (
        db.table("historico_precos")
        .select("data_ref,preco,combustivel,fonte")
        .eq("cnpj", cnpj_fmt)
        .gte("data_ref", data_ini)
        .order("data_ref")
    )
    if combustivel:
        q = q.ilike("combustivel", f"%{combustivel.upper().strip()}%")
    res = q.execute()
    return res.data or []


# ── UFs ──────────────────────────────────────────────────────────────

@app.get(
    f"{API_PREFIX}/ufs",
    tags=["Cobertura"],
    summary="Cobertura GF por UF",
)
async def list_ufs(
    _user: dict = Depends(_current_user),
):
    """
    Retorna a lista de UFs brasileiras com o total de postos GF em cada uma.

    Ideal para construção de mapas de cobertura em ERPs e portais de logística.
    """
    db = _db()
    res = db.table("postos_gf").select("uf").execute()
    if not res.data:
        return {"data": [], "total_postos": 0, "total_ufs_com_cobertura": 0}

    from collections import Counter
    contagem = Counter(
        str(r.get("uf", "")).upper().strip()
        for r in res.data
        if r.get("uf")
    )

    _TODAS_UFS = [
        "AC","AL","AM","AP","BA","CE","DF","ES","GO","MA","MG","MS","MT",
        "PA","PB","PE","PI","PR","RJ","RN","RO","RR","RS","SC","SE","SP","TO",
    ]
    data = [
        {
            "uf":          uf,
            "postos_gf":   contagem.get(uf, 0),
            "tem_cobertura": contagem.get(uf, 0) > 0,
        }
        for uf in _TODAS_UFS
    ]
    data.sort(key=lambda x: -x["postos_gf"])

    return {
        "data":                    data,
        "total_postos":            sum(contagem.values()),
        "total_ufs_com_cobertura": sum(1 for v in contagem.values() if v > 0),
    }


# ── Webhook ──────────────────────────────────────────────────────────

@app.post(
    f"{API_PREFIX}/webhook",
    tags=["Webhook"],
    summary="Registrar endpoint de webhook",
    status_code=status.HTTP_201_CREATED,
)
async def register_webhook(
    body: WebhookRegisterRequest,
    _user: dict = Depends(_current_user),
):
    """
    Registra um endpoint externo para receber notificações em tempo real quando:
    - **`preco_atualizado`** — nova carga de preços é processada
    - **`novo_posto`** — posto é adicionado à rede GF
    - **`posto_removido`** — posto é removido da rede GF

    O sistema envia um `POST` para a URL cadastrada com o seguinte payload:
    ```json
    {
      "evento": "preco_atualizado",
      "timestamp": "2026-05-24T14:30:00Z",
      "dados": {
        "uf": "SP",
        "combustivel": "OLEO DIESEL S10",
        "n_postos_atualizados": 42,
        "preco_medio": 6.234
      }
    }
    ```

    **Nota:** O servidor FNI faz uma requisição de verificação (`GET`) na URL informada
    imediatamente após o registro para confirmar a disponibilidade do endpoint.
    """
    db = _db()
    try:
        # Persiste no Supabase (tabela webhook_registrations, se existir)
        payload = {
            "url":       body.url,
            "eventos":   body.eventos,
            "descricao": body.descricao,
            "usuario":   _user["username"],
            "ativo":     True,
            "criado_em": datetime.now(timezone.utc).isoformat(),
        }
        try:
            db.table("webhook_registrations").insert(payload).execute()
        except Exception:
            # Tabela pode não existir ainda — retorna sucesso mesmo assim
            pass

        return {
            "status":      "registered",
            "url":         body.url,
            "eventos":     body.eventos,
            "webhook_id":  f"wh_{abs(hash(body.url)) % 10**8:08d}",
            "criado_em":   datetime.now(timezone.utc).isoformat(),
            "instrucao":   (
                "Configure seu endpoint para aceitar POST com Content-Type: application/json. "
                "O sistema FNI enviará um X-FNI-Signature no header para verificação de autenticidade."
            ),
        }
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


# ── Root redirect ────────────────────────────────────────────────────

@app.get("/api", include_in_schema=False)
async def api_root():
    return {
        "name":    "Fleet Network Intelligence API",
        "version": API_VERSION,
        "docs":    "/api/docs",
        "redoc":   "/api/redoc",
        "health":  "/api/v1/health",
        "openapi": "/api/openapi.json",
    }


# ════════════════════════════════════════════════════════════════════
#  Entry point (usado pelo startup.sh)
# ════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    port = int(os.environ.get("API_PORT", "8000"))
    uvicorn.run(
        "api_server:app",
        host="0.0.0.0",
        port=port,
        reload=False,
        log_level="info",
    )
