# Fase Deploy-Automático-PWA (02/09/2026, achado real do Daniel: "por ser um
# PWA nao tem um comando diferente de commit e push? Ja tivemos problemas
# para atualizacao de PWAs") — antes deste multi-stage, este Dockerfile só
# copiava a pasta `build/web` já compilada do repo pro nginx. Isso exigia
# rodar `flutter build web` numa máquina LOCAL antes de todo commit — passo
# manual fácil de esquecer, e que já causou 2 incidentes reais de produção
# rodando código velho mesmo com o deploy do Railway aparecendo "SUCCESS"
# (#242, e de novo logo antes desta correção: o commit da fila de aprovação
# de abastecimentos manuais subiu, o deploy teve sucesso, mas o `build/web`
# copiado ainda era de 2 dias antes — sem a tela nova nenhuma).
#
# Agora o Railway builda o Flutter sozinho, na nuvem, a partir do
# lib/pubspec.yaml — `git push` sozinho já é suficiente, sem passo manual.
# Imagem `cirruslabs/flutter` porque é a imagem Docker oficial-de-fato pra
# CI de Flutter (mantida ativamente, usada pelo próprio flutter.dev em
# exemplos de CI) — instala o SDK Flutter completo, algo que não existe
# pronto na Docker Hub oficial (o time do Flutter não publica uma).
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get
COPY . .
RUN flutter build web --release

FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
