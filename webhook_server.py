import os
import uvicorn
from fastapi import FastAPI, Request, HTTPException
from fastapi.responses import JSONResponse

app = FastAPI()

@app.get("/health")
async def health():
    return {"status": "ok"}

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

if __name__ == "__main__":
    port = int(os.environ.get("WEBHOOK_PORT", 8081))
    uvicorn.run(app, host="0.0.0.0", port=port)
