#!/bin/bash
set -e
cd "/Volumes/Daniel_Externo/Projetos/estudo-de-rede"

echo "== 1) o git está ignorando o build? (se aparecer uma linha abaixo, é isso) =="
git check-ignore -v flutter/build/web/main.dart.js || echo "(nao esta sendo ignorado por nenhuma regra)"

echo ""
echo "== 2) o build aparece como alteracao pendente? =="
git status --porcelain -- flutter/build/web | head -20

echo ""
echo "== 3) forcando a inclusao do build (ignora .gitignore de propósito) =="
git add -f flutter/build/web
git add -A
git commit -m "reorganizacao-menu: forcar build atualizado no deploy" --allow-empty
git push

echo ""
echo "== 4) confirmando o que FOI commitado de verdade =="
git show --stat HEAD | head -30

echo ""
echo "== pronto. confira agora no painel da Railway se um deploy novo comecou. =="
