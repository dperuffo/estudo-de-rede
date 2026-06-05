"""
webhook_server.py — Servidor de Webhooks Stripe
================================================
Roda junto ao Streamlit para receber eventos do Stripe.

Como funciona:
    - O Streamlit roda na porta $PORT
    - Este servidor roda na porta $PORT+1 (ex: 8081)
    - O Cloudflare roteia /webhook/stripe → porta 8081

Para rodar junto ao Streamlit, adicione ao Procfile:
    web: python webhook_server.py & streamlit run estudo_de_rede.py ...
"""

import os
import stripe
import uvicorn
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import JSONResponse, Response
import httpx

app = FastAPI()

STREAMLIT_PORT = int(os.environ.get("STREAMLIT_PORT", 8501))
WEBHOOK_SECRET = os.environ.get("STRIPE_WEBHOOK_SECRET", "")

@app.post("/webhook/stripe")
async def stripe_webhook(request: Request):
    payload    = await request.body()
    sig_header = request.headers.get("stripe-signature", "")
    if not sig_header:
        raise HTTPException(status_code=400, detail="Header ausente")
    try:
        from stripe_billing import processar_webhook
        resultado = processar_webhook(payload, sig_header)
        if resultado["status"] == "erro":
            raise HTTPException(status_code=400, detail=resultado["mensagem"])
        return JSONResponse({"received": True})
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.api_route("/{path:path}", methods=["GET","POST","PUT","DELETE","PATCH","HEAD","OPTIONS"])
async def proxy(path: str, request: Request):
    url = f"http://localhost:{STREAMLIT_PORT}/{path}"
    async with httpx.AsyncClient() as client:
        resp = await client.request(
            method=request.method,
            url=url,
            headers=dict(request.headers),
            content=await request.body(),
            params=request.query_params,
            follow_redirects=True,
        )
    return Response(content=resp.content, status_code=resp.status_code, headers=dict(resp.headers))

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)
