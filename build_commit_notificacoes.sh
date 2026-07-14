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
git commit -m "Notificacoes: bolinhas de contagem no menu (chamados, negociacoes, ajustes de abastecimento, anomalias, acessos de clientes, avaliacoes, documentos pendentes) - posto, cliente e admin"
git push

echo "== pronto. acompanhe o deploy na Railway. =="
