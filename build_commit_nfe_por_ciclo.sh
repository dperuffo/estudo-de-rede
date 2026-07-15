#!/bin/bash
set -e
cd "/Users/daniel/Documents/Projetos/estudo-de-rede/flutter"

echo "== flutter analyze (checagem antes do build) =="
flutter analyze || true

echo "== flutter build web (isso e o que a Railway serve — sem isso nada muda no ar) =="
flutter clean
flutter build web --release

echo "== git =="
cd "/Users/daniel/Documents/Projetos/estudo-de-rede"
rm -f .git/index.lock .git/HEAD.lock .git/next-index-*.lock
git add -A
git commit -m "Notas Fiscais: percentual de recolha por ciclo de faturamento (nao mais janela fixa de 90 dias)"
git push

echo "== pronto. acompanhe o deploy na Railway. =="
