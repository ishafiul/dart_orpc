# Framework benchmarks

This suite compares `dart_orpc`, Shelf, Dart Frog, and Serverpod using small,
equivalent HTTP workloads. It is deliberately separate from the root Melos
workspace so each framework keeps its own dependency graph and lockfile.

## Included scenarios

All four fixtures expose the same response body and content type:

| Scenario | Request | Response |
| --- | --- | --- |
| Plain text | `GET /plaintext` | `Hello, World!` |
| JSON | `GET /json` | `{"message":"Hello, World!"}` |
| Echo | `POST /echo` | The submitted JSON value |

The HTTP track measures comparable routing, body parsing, and serialization.
The `dart_orpc` fixture also exposes `benchmark.echo` through `POST /rpc`, and
the Serverpod fixture generates a native `benchmark.echo` endpoint. Those
belong in a separate framework-native track because their wire protocols are
not equivalent to the HTTP routes.

`dart_orpc` currently serializes every registered REST result as JSON. Its
plain-text endpoint is therefore implemented as the outermost framework
middleware, while its JSON and echo endpoints use `RestRouteRegistry`.

## Requirements

- Dart 3.11 or newer
- `oha` for load generation
- A quiet machine with no competing builds or test runs

For publishable numbers, run the load generator on a separate machine and pin
the server process to a fixed CPU allocation. Local runs are useful for
regression checks, but not for cross-machine comparisons.

## Build and verify

From the repository root:

```bash
dart run benchmarks/tool/benchmark.dart build
dart run benchmarks/tool/benchmark.dart verify
```

`build` resolves each fixture independently, regenerates Serverpod bindings,
generates Dart Frog's production server, and compiles all four servers to AOT
executables under `benchmarks/build/`.

`verify` starts those executables, checks the status and decoded body of all
nine HTTP responses, and then shuts every server down. A load result should
not be accepted unless this command passes first.

## Run load tests

```bash
dart run benchmarks/tool/benchmark.dart load \
  --scenario plaintext \
  --duration 60s \
  --connections 64

dart run benchmarks/tool/benchmark.dart load \
  --scenario json \
  --duration 60s \
  --connections 64

dart run benchmarks/tool/benchmark.dart load \
  --scenario echo \
  --duration 60s \
  --connections 64

# Optionally isolate one framework per invocation.
dart run benchmarks/tool/benchmark.dart load \
  --fixture serverpod \
  --scenario json \
  --duration 60s \
  --connections 64
```

The runner starts one AOT executable for each framework and writes the raw
`oha` JSON into `benchmarks/results/`. This is a closed-loop concurrency test;
latency correction only applies to `oha` rate-limited (`-q`) runs, so it is not
enabled here. The runner does not parse away any of the source data.

## Result directory convention

Every new benchmark session must use a separate directory containing the local
date and tested Git commit:

```text
benchmarks/results/YYYY-MM-DD-<short-commit>/
```

If the worktree has uncommitted changes, use the current `HEAD` short hash and
record `worktree: dirty` plus the relevant diff or change description in the
session metadata. Never overwrite raw results from an earlier duration,
scenario, configuration, or session.

A complete session directory should contain:

```text
YYYY-MM-DD-<short-commit>/
├── README.md                 # configuration, tables, interpretation, caveats
├── metadata.json             # commit, worktree state, OS, CPU, RAM, Dart, oha
├── load/                     # raw oha JSON, separated by scenario and duration
├── resources/                # CPU and RSS samples
└── gc/                       # verbose-GC logs and parsed summaries
```

Raw filenames must include enough configuration to remain unique, for example:

```text
load/dart_orpc-json-30s-c64.json
resources/dart_orpc-json-60s-c64-q20000.tsv
gc/dart_orpc-json-60s-c64-q20000.log
```

Keep the human-readable summary beside the raw evidence. A benchmark result is
not complete until its commit, dirty-worktree status, scenario, duration,
connections, requested rate, fixture order, success/error counts, and machine
metadata are recorded.

Run each scenario at connections `1`, `16`, `64`, and `256`, repeat each
combination at least five times, and use the median. Randomize framework order
when producing public results; the bundled runner uses a stable order for
repeatable local regression checks.

## What to report

- Requests per second
- p50, p90, p99, and p99.9 latency
- Error and timeout percentage
- CPU utilization and peak resident memory
- Dart SDK, operating system, CPU, dependency locks, and Git commit
- AOT executable size and build time

Average latency on its own is not an acceptable comparison. Database results
must be a separate suite using the same PostgreSQL schema, data, indexes, and
connection-pool size.

## Ports

| Fixture | HTTP comparison | Native API |
| --- | ---: | ---: |
| `dart_orpc` | 18081 | 18081 (`POST /rpc`) |
| Shelf | 18082 | N/A |
| Dart Frog | 18083 | N/A |
| Serverpod | 18085 | 18084 |

The Serverpod fixture uses the official database-free mini configuration. It
retains endpoint sessions and generated native bindings without introducing a
PostgreSQL dependency into the HTTP baseline.
