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

git commit -m "agendamento-patio: YMS leve, agenda de carga/descarga por frete no PWA Cliente"
git push

echo "== pronto. acompanhe o deploy na Railway. =="
