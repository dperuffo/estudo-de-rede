#!/bin/bash
pip install stripe fastapi uvicorn python-multipart httpx --quiet
streamlit run estudo_de_rede.py --server.port 8501 --server.address 0.0.0.0 --server.headless true --server.enableCORS false --server.enableXsrfProtection true &
sleep 8
python webhook_server.py
