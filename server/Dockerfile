# Builds the leaderboard server into a small image for Render (or any
# Docker host). Configure it with DATABASE_URL; the host supplies PORT.
FROM dart:3.13 AS build
WORKDIR /app
COPY pubspec.yaml pubspec.lock ./
RUN dart pub get
COPY . .
RUN dart pub get --offline && dart compile exe bin/server.dart -o /app/server

# /runtime holds the libraries and CA certificates a compiled Dart app needs,
# including the certificates used to verify TiDB Cloud's TLS connection.
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/server /app/server
EXPOSE 8080
CMD ["/app/server"]
