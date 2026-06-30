# ════════════════════════════════════════════════════
#  Fleet Network Intelligence
#  Dockerfile para deploy no fly.io
#
#  Processos no container:
#    • nginx      — porta 80  (proxy reverso)
#    • FastAPI    — porta 8000 (/api/*)
#    • Streamlit  — porta 8501 (/*)
# ════════════════════════════════════════════════════

FROM python:3.11-slim

# Ferramentas de sistema: curl (health-check) + nginx (proxy reverso)
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
        nginx \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Instala dependências Python primeiro (melhor cache Docker)
COPY requirements.txt .
# Cache bust: 1782853200
RUN pip install --no-cache-dir -r requirements.txt

# Copia o restante da aplicação
COPY . .

# Configura nginx
COPY nginx.conf /etc/nginx/nginx.conf

# Torna o startup script executável
RUN chmod +x startup.sh

# Expõe as três portas
EXPOSE 80 8000 8501

# Health-check via nginx (proxy da porta 80 → Streamlit)
HEALTHCHECK --interval=30s --timeout=15s --start-period=50s --retries=3 \
    CMD curl -f http://localhost/healthz 2>/dev/null || \
        curl -f http://localhost:8501/_stcore/health || exit 1

ENTRYPOINT ["./startup.sh"]
