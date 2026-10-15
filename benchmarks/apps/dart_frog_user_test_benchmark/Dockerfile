FROM dart:3.11.0 AS build

WORKDIR /workspace
COPY benchmarks/packages/challenge_core/ benchmarks/packages/challenge_core/
COPY benchmarks/apps/dart_frog_user_test_benchmark/ benchmarks/apps/dart_frog_user_test_benchmark/
WORKDIR /workspace/benchmarks/apps/dart_frog_user_test_benchmark
RUN dart pub get \
    && dart run dart_frog_cli:dart_frog build \
    && mkdir -p bin \
    && dart compile exe build/bin/server.dart -o /server

FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install --yes --no-install-recommends libsqlite3-0 ca-certificates \
    && for sqlite_library in /usr/lib/*/libsqlite3.so.0; do \
         ln -s libsqlite3.so.0 "${sqlite_library%/*}/libsqlite3.so"; \
       done \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /server /usr/local/bin/dart-frog-user-test-benchmark
EXPOSE 3000
ENTRYPOINT ["/usr/local/bin/dart-frog-user-test-benchmark"]
