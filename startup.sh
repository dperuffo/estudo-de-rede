#!/bin/bash
set -e

python /app/worker_sync.py >> /var/log/worker_sync.log 2>&1 &
nginx -g "daemon off;" &
python api_server.py &
exec streamlit run estudo_de_rede.py --server.port=8501 --server.address=0.0.0.0
