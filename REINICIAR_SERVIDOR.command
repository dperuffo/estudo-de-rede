#!/bin/bash
# Reinicia o servidor Gestão de Frotas
# Dê dois cliques neste arquivo no Finder para executar

cd "$(dirname "$0")"
echo "🔄 Encerrando servidor anterior..."

# Mata qualquer processo usando a porta 8080
lsof -ti tcp:8080 | xargs kill -9 2>/dev/null

# Também tenta pelo nome do script, por garantia
pkill -9 -f "python3 server.py" 2>/dev/null
pkill -9 -f "python server.py" 2>/dev/null

# Aguarda a porta ser liberada
sleep 2

echo "🚀 Iniciando servidor atualizado..."
python3 server.py
