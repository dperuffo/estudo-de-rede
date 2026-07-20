#!/bin/bash
set -e
cd "/Volumes/Daniel_Externo/Projetos/estudo-de-rede/flutter"

echo "== flutter build web =="
flutter clean
flutter build web --release

echo "== git =="
cd "/Volumes/Daniel_Externo/Projetos/estudo-de-rede"
rm -f .git/index.lock .git/HEAD.lock .git/next-index-*.lock
git add -A
git commit -m "build: publica filtro de placa (Combustível Ideal PWA) no Railway"
git push

echo "== pronto =="
