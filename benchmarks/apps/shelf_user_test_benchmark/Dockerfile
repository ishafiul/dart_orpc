FROM dart:3.11.0 AS build

WORKDIR /workspace
COPY benchmarks/packages/challenge_core/ benchmarks/packages/challenge_core/
COPY benchmarks/apps/shelf_user_test_benchmark/ benchmarks/apps/shelf_user_test_benchmark/
WORKDIR /workspace/benchmarks/apps/shelf_user_test_benchmark
RUN dart pub get \
    && dart compile exe bin/server.dart -o /server

FROM debian:bookworm-slim
RUN apt-get update \
    && apt-get install --yes --no-install-recommends libsqlite3-0 ca-certificates \
    && for sqlite_library in /usr/lib/*/libsqlite3.so.0; do \
         ln -s libsqlite3.so.0 "${sqlite_library%/*}/libsqlite3.so"; \
       done \
    && rm -rf /var/lib/apt/lists/*
COPY --from=build /server /usr/local/bin/shelf-user-test-benchmark
EXPOSE 3000
ENTRYPOINT ["/usr/local/bin/shelf-user-test-benchmark"]
