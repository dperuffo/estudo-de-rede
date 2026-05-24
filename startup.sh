#!/bin/bash
# ═══════════════════════════════════════════════════════
#  Fleet Network Intelligence — Startup Script
#  Inicia: FastAPI (porta 8000) + Streamlit (porta 8501)
#  Nginx (porta 80) faz proxy reverso:
#    /api/*  →  FastAPI  :8000
#    /*      →  Streamlit :8501
# ═══════════════════════════════════════════════════════

set -e

echo "▶ Iniciando Fleet Network Intelligence..."

# ── FastAPI ──────────────────────────────────────────────
echo "  → API server  (porta 8000)"
uvicorn api_server:app \
  --host 127.0.0.1 \
  --port 8000 \
  --workers 2 \
  --log-level info &

API_PID=$!

# ── Streamlit ────────────────────────────────────────────
echo "  → Streamlit   (porta 8501)"
streamlit run estudo_de_rede.py \
  --server.port=8501 \
  --server.address=127.0.0.1 \
  --server.headless=true \
  --browser.gatherUsageStats=false &

ST_PID=$!

# ── Aguarda serviços subirem ─────────────────────────────
sleep 3

# ── Nginx (proxy reverso na porta 80) ────────────────────
echo "  → Nginx       (porta 80)"
nginx -g "daemon off;" &

NGINX_PID=$!

echo "✅ Todos os serviços iniciados."
echo "   Streamlit: http://localhost:8501"
echo "   API:       http://localhost/api"
echo "   Swagger:   http://localhost/api/docs"

# ── Aguarda qualquer processo encerrar ──────────────────
wait -n $API_PID $ST_PID $NGINX_PID
echo "❌ Um processo encerrou — encerrando container."
kill $API_PID $ST_PID $NGINX_PID 2>/dev/null || true
