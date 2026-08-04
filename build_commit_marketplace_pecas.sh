#!/bin/bash
set -e
cd "/Volumes/Daniel_Externo/Projetos/estudo-de-rede/flutter"

echo "== flutter build web (isso e o que a Railway serve — sem isso nada muda no ar) =="
flutter clean
flutter build web --release

echo "== git =="
cd "/Volumes/Daniel_Externo/Projetos/estudo-de-rede"
rm -f .git/index.lock .git/HEAD.lock .git/next-index-*.lock

# build/web ja ficou rastreado pelo -f da fase anterior, mas o -f aqui e de
# graca (nao faz nada se ja rastreado) e evita repetir o silencio do
# .gitignore caso algo tenha saido do rastreamento entre as fases.
git add -f flutter/build/web
git add -A

git status --porcelain -- flutter/build/web

git commit -m "marketplace-pecas: cotacao multi-fornecedor (pedido -> N propostas) no PWA Cliente"
git push

echo "== pronto. acompanhe o deploy na Railway. =="
