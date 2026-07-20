#!/bin/bash
set -e
cd "/Volumes/Daniel_Externo/Projetos/estudo-de-rede/flutter"

echo "== flutter build web (isso é o que a Railway serve — sem isso nada muda no ar) =="
flutter clean
flutter build web --release

echo "== git =="
cd "/Volumes/Daniel_Externo/Projetos/estudo-de-rede"
rm -f .git/index.lock .git/HEAD.lock .git/next-index-*.lock
git add -A
git commit -m "build: publica Combustível Ideal + Pegada de Carbono (PWA cliente) no Railway"
git push

echo "== pronto. acompanhe o deploy do serviço do PWA (flutter/Dockerfile) na Railway. =="
