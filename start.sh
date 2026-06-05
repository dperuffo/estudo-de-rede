#!/bin/bash
set -e

echo "📦 Instalando dependências..."
pip install stripe fastapi uvicorn python-multipart httpx --quiet

echo "🚀 Iniciando Streamlit..."
streamlit run estudo_de_rede.py \
  --server.port 8501 \
  --server.address 0.0.0.0 \
  --server.headless true \
  --server.enableCORS false \
  --server.enableXsrfProtection true &

echo "⏳ Aguardando Streamlit..."
sleep 8

echo "🔗 Iniciando Webhook Server..."
python webhook_server.py
