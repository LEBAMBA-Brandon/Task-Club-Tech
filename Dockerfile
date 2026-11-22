FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app
COPY pubspec.yaml pubspec.lock* ./
RUN flutter pub get
COPY . .
RUN flutter build web --release

FROM python:3.12-alpine
WORKDIR /app
COPY --from=build /app/build/web /app/web
CMD ["sh", "-c", "python3 -m http.server ${PORT:-8080} --bind 0.0.0.0 --directory /app/web"]
