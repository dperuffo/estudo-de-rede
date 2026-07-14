#!/bin/bash
set -e
cd "/Users/daniel/Documents/Projetos/estudo-de-rede/flutter"

echo "== flutter build web (isso e o que a Railway serve — sem isso nada muda no ar) =="
flutter clean
flutter build web --release

echo "== git =="
cd "/Users/daniel/Documents/Projetos/estudo-de-rede"
rm -f .git/index.lock .git/HEAD.lock .git/next-index-*.lock
git add -A
git commit -m "Inteligencia de Rede: todas as 10 abas da web portadas pro PWA (admin + cliente)"
git push

echo "== pronto. acompanhe o deploy na Railway. =="
