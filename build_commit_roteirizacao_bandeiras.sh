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
git commit -m "Roteirizacao: bolinhas coloridas por bandeira/distribuidora + legenda + filtros (score, bandeira, municipio, UF, CNPJ, razao social)"
git push

echo "== pronto. acompanhe o deploy na Railway. =="
