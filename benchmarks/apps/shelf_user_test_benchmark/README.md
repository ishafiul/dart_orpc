# Shelf User Test Benchmark server

Runs the benchmark API using Shelf routing and shared
`challenge_core` SQLite queries and JWT validation.

From the repository root, run the same correctness suite and k6 profile used
for `dart_orpc`:

```bash
FRAMEWORK=shelf bash benchmarks/user_test_benchmark/run.sh
```
