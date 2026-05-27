#!/bin/bash
set -e

# Inicia o nginx em background
nginx -g "daemon off;" &

# Inicia o API server em background
python api_server.py &

# Inicia o Streamlit (processo principal)
exec streamlit run estudo_de_rede.py --server.port=8501 --server.address=0.0.0.0
