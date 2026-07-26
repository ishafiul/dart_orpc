# Framework benchmarks

This suite compares `dart_orpc`, Shelf, Dart Frog, and Serverpod using
equivalent HTTP workloads ranging from transport microbenchmarks to realistic
API reads and writes. It is deliberately separate from the root Melos workspace
so each framework keeps its own dependency graph and lockfile.

## Included scenarios

All four fixtures expose the same response body and content type:

| Scenario | Request | Response |
| --- | --- | --- |
| Plain text | `GET /plaintext` | `Hello, World!` |
| JSON | `GET /json` | `{"message":"Hello, World!"}` |
| Echo | `POST /echo` | The submitted JSON value |
| Catalog read | `GET /catalog?category=books&page=2&limit=10` | Ten nested product records plus pagination and filter metadata |
| Checkout write | `POST /checkout` | A validated order summary with calculated line totals, discount, tax, shipping, and total |

The suite has two explicitly different tracks:

- `plaintext`, `json`, and `echo` are low-level HTTP adapter microbenchmarks.
  The dart_orpc fixture implements these in outer middleware so they do not
  claim to represent the full framework application pipeline.
- `catalog` and `checkout` are application benchmarks. The dart_orpc fixture
  uses an annotated module, controller, service, Luthor-validated DTOs,
  generated route registries, and the public `buildRpcApp()` bootstrap.
  Checkout uses typed nested customer/item DTOs and calls the shared typed
  calculation directly. Do not convert the validated DTO back to a map in the
  service; that benchmark-only round trip is unlike a normal typed application
  and creates avoidable allocation pressure.

`catalog` represents a typical paginated API read with query coercion and a
roughly 2.5 KiB nested response. `checkout` represents a typical write path with
a nested request, generated validation, domain validation, integer money
calculations, and a structured DTO response.

The realistic workload contracts and deterministic business logic live in
`benchmarks/packages/benchmark_workloads`. Every fixture uses that same package,
so the framework adapters differ only in routing, HTTP parsing, error mapping,
and serialization. Its map-based checkout entry point is a boundary adapter for
untyped fixtures; both it and dart_orpc delegate to the same
`calculateCheckout` implementation.

The `dart_orpc` fixture also exposes `benchmark.echo` through `POST /rpc`, and
the Serverpod fixture generates a native `benchmark.echo` endpoint. Those
belong in a separate framework-native track because their wire protocols are
not equivalent to the HTTP routes.

The dart_orpc fixture source for application scenarios is
`apps/dart_orpc_benchmark/lib/benchmark_app.dart`; its generated registry is
rebuilt before every AOT build. Do not replace these routes with manual
`RestRouteRegistry` entries, because doing so bypasses the runtime framework
costs this track is intended to measure.

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

`verify` starts those executables, checks every successful response body and
the invalid-request status for realistic workloads, and then shuts every server
down. A load result should not be accepted unless this command passes first.

## Run a benchmark session

```bash
dart run melos run benchmark -- \
  --duration 10s \
  --connections 64
```

This is the standard benchmark command. It runs plaintext, JSON, echo, catalog,
and checkout for all four frameworks. Each framework is started and measured
in isolation, warmed up before measurement, and sampled for CPU and RSS
throughout the load window.

Every invocation creates a unique
`benchmarks/results/YYYY-MM-DD-HHmmss-<short-commit>/` directory containing:

```text
README.md       # same generated tables, comparisons, and caveats every run
metadata.json   # Git, machine, tools, configuration, and aggregate success
load/           # unmodified oha JSON for every framework/scenario
resources/      # CPU and RSS samples for every framework/scenario
logs/           # captured server output for every framework/scenario
gc/             # raw Dart VM verbose-GC output
```

The generated Markdown always reports both benchmark tracks and explains, per
scenario, whether dart_orpc had higher or lower throughput, latency, CPU, and
memory than the strongest competitor, including the percentage difference.
Each comparison uses 🟢 when dart_orpc is better and 🔴 when it is worse.
Saturation runs compare CPU efficiency as requests/second per CPU percentage
point; raw CPU is not ranked when frameworks complete different amounts of
work. GC reporting includes measured-window event and major/concurrent counts,
total time, time per 100,000 completed requests, and average/maximum pause.

Optional controls:

```bash
# Run only selected scenarios.
dart run melos run benchmark -- \
  --duration 30s \
  --connections 64 \
  --scenarios plaintext,json,echo

# Increase resource sampling frequency and change post-load cooldown.
dart run melos run benchmark -- \
  --sample-ms 100 \
  --warmup 3s \
  --cooldown-seconds 5

# Compare raw CPU fairly at the same requested throughput.
dart run melos run benchmark -- \
  --duration 30s \
  --connections 64 \
  --rate 20000
```

`--duration` defaults to `10s`, `--connections` to `64`, resource sampling to
`250` ms, warm-up to two seconds, and cooldown to two seconds. Without `--rate`,
the benchmark is closed-loop saturation and reports normalized CPU efficiency.
With `--rate`, `oha` applies coordinated omission correction and the report can
compare raw CPU when every framework achieves at least 98% of the requested
rate with 100% success. Fixed-rate throughput is reported as target attainment
instead of ranking small scheduler differences. The lower-level `load` command
remains available for targeted diagnostics, but it does not create a complete
session report.

## Result directory convention

The `suite` command creates a separate timestamped directory containing the
local date, time, and tested Git commit:

```text
benchmarks/results/YYYY-MM-DD-HHmmss-<short-commit>/
```

If the worktree has uncommitted changes, use the current `HEAD` short hash and
record `worktree: dirty` plus the relevant diff or change description in the
session metadata. Never overwrite raw results from an earlier duration,
scenario, configuration, or session.

A complete generated session directory contains:

```text
YYYY-MM-DD-HHmmss-<short-commit>/
├── README.md                 # configuration, tables, interpretation, caveats
├── metadata.json             # commit, worktree state, OS, CPU, RAM, Dart, oha
├── load/                     # raw oha JSON, separated by scenario and duration
├── resources/                # CPU and RSS samples
├── logs/                     # captured server stdout and stderr
└── gc/                       # raw Dart VM verbose-GC output
```

Raw filenames must include enough configuration to remain unique, for example:

```text
load/dart_orpc-json-30s-c64.json
resources/dart_orpc-json-60s-c64.tsv
logs/dart_orpc-json-60s-c64.log
gc/dart_orpc-json-60s-c64.log
```

Keep the human-readable summary beside the raw evidence. A benchmark result is
not complete until its commit, dirty-worktree status, scenario, duration,
connections, warm-up, requested rate or saturation mode, fixture order,
success/error counts, and machine metadata are recorded.

Run each scenario at connections `1`, `16`, `64`, and `256`, repeat each
combination at least five times, and use the median. Randomize framework order
when producing public results; the bundled runner uses a stable order for
repeatable local regression checks.

## What to report

- Requests per second
- p50, p90, p99, and p99.9 latency
- Error and timeout percentage
- CPU utilization and peak resident memory
- GC events, major/concurrent events, normalized GC time, and maximum pause
- Dart SDK, operating system, CPU, dependency locks, and Git commit
- AOT executable size and build time

Average latency on its own is not an acceptable comparison. Database results
must be a separate suite using the same PostgreSQL schema, data, indexes, and
connection-pool size.

Verbose GC is enabled for every suite fixture so comparisons remain matched,
but it adds diagnostic overhead. Use the same setting across compared runs and
do not compare GC-enabled absolute throughput directly with older runs that did
not enable verbose GC.

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
