#!/bin/bash
set -e
cd "/Volumes/Daniel_Externo/Projetos/estudo-de-rede/flutter"

echo "== flutter build web (isso e o que a Railway serve — sem isso nada muda no ar) =="
flutter clean
flutter build web --release

echo "== git =="
cd "/Volumes/Daniel_Externo/Projetos/estudo-de-rede"
rm -f .git/index.lock .git/HEAD.lock .git/next-index-*.lock

git add -f flutter/build/web
git add -A

git status --porcelain -- flutter/build/web

git commit -m "replicacao-grupo: botao 'Replicar para o grupo' em Parametros de Uso, Centros de Custo e Precos de Postos"
git push

echo "== pronto. acompanhe o deploy na Railway. =="
