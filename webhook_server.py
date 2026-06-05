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
import uvicorn
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import JSONResponse
from stripe_billing import processar_webhook

app = FastAPI()

@app.post("/webhook/stripe")
async def stripe_webhook(request: Request):
    payload    = await request.body()
    sig_header = request.headers.get("stripe-signature", "")

    if not sig_header:
        raise HTTPException(status_code=400, detail="Header stripe-signature ausente")

    resultado = processar_webhook(payload, sig_header)

    if resultado["status"] == "erro":
        raise HTTPException(status_code=400, detail=resultado["mensagem"])

    return JSONResponse({"received": True, "detail": resultado["mensagem"]})


@app.get("/health")
async def health():
    return {"status": "ok"}


if __name__ == "__main__":
    port = int(os.environ.get("WEBHOOK_PORT", 8081))
    uvicorn.run(app, host="0.0.0.0", port=port)
