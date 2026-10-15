# dart_orpc User Test Benchmark server

This app implements User Test Benchmark API:

- `GET /health`
- `GET /feed`
- `GET /posts/:id`
- `POST /posts`
- `POST /posts/:id/like`

All endpoints are generated from `dart_orpc` controller metadata. The runner
provisions SQLite schema and seed data. The server uses the supplied
database without adding or changing schema objects. Every read queries SQLite;
JWT signatures are verified for each authenticated request.

Run the official correctness suite and capacity benchmark from the repository
root:

```bash
bash benchmarks/user_test_benchmark/run.sh
```

The runner requires Dart 3.11+, Docker, k6, Node.js 18+, SQLite CLI, Git, curl,
jq, and OpenSSL. It prepares pinned fixture files in an ignored local cache,
generates the seed database, runs the correctness suite, builds a Linux AOT
image, then starts each load run with an
independent fresh database under Docker's 1 CPU / 2 GiB / no-swap limit.

The generated report and raw k6/resource files are saved under
`benchmarks/results/`. Defaults match benchmark profile. Environment
overrides for a shorter local pass are documented by `run.sh --help`.
