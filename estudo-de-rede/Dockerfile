# ════════════════════════════════════════════════════
#  Estudo de Rede – Pró-Frotas
#  Dockerfile para deploy no fly.io
# ════════════════════════════════════════════════════

FROM python:3.11-slim

# Ferramentas de sistema mínimas (curl para health-check)
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Instala dependências Python primeiro (melhor uso de cache Docker)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copia o restante da aplicação
COPY . .

EXPOSE 8501

# Verificação de saúde para o fly.io
HEALTHCHECK --interval=30s --timeout=15s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8501/_stcore/health || exit 1

ENTRYPOINT ["streamlit", "run", "estudo_de_rede.py", \
            "--server.port=8501", \
            "--server.address=0.0.0.0", \
            "--server.headless=true", \
            "--browser.gatherUsageStats=false"]
