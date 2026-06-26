# Stage 1: Build Flutter Web
FROM ghcr.io/cirruslabs/flutter:stable AS builder
WORKDIR /app
COPY . .
RUN flutter pub get
RUN flutter build web --release --base-href "/"

# Stage 2: Serve com Nginx
FROM nginx:alpine
COPY --from=builder /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
