#!/bin/bash
set -e
cd "/Users/daniel/Documents/Projetos/estudo-de-rede"

echo "== git pull (traz os commits da Central de Avisos e do Pré-Pedido) =="
git pull

cd "/Users/daniel/Documents/Projetos/estudo-de-rede/flutter"

echo "== flutter build web (isso e o que a Railway serve — sem isso nada muda no ar) =="
flutter clean
flutter build web --release

echo "== git =="
cd "/Users/daniel/Documents/Projetos/estudo-de-rede"
rm -f .git/index.lock .git/HEAD.lock .git/next-index-*.lock
git add -A
git commit -m "Build: Central de Avisos + Pré-Pedido (PWA cliente)"
git push

echo "== pronto. acompanhe o deploy na Railway. =="
