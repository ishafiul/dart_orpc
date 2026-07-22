# Preliminary local benchmark — 2026-07-22

This is a smoke benchmark, not a publishable performance claim. Each result
is one closed-loop run on the same machine for 10 seconds at 64 concurrent
HTTP/1.1 connections. All responses succeeded, but the suite has not yet been
randomized or repeated to produce five-run medians.

## Environment

- macOS 26.5 (25F71)
- Apple M4, 10 logical CPUs
- Dart 3.11.0 stable, macOS arm64
- oha 1.15.0
- Production AOT executables
- Load generator and servers on the same machine

## Results

| Scenario | Framework | Requests/sec | p50 | p95 | p99 | Success |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Plaintext | dart_orpc | 46,801 | 1.241 ms | 2.062 ms | 2.775 ms | 100% |
| Plaintext | Serverpod | 32,136 | 1.892 ms | 2.351 ms | 3.663 ms | 100% |
| Plaintext | Shelf | 31,324 | 1.875 ms | 3.087 ms | 4.266 ms | 100% |
| Plaintext | Dart Frog | 15,495 | 4.155 ms | 5.575 ms | 10.010 ms | 100% |
| JSON | dart_orpc | 47,193 | 1.166 ms | 2.410 ms | 3.714 ms | 100% |
| JSON | Shelf | 37,539 | 1.611 ms | 1.974 ms | 3.553 ms | 100% |
| JSON | Serverpod | 32,716 | 1.897 ms | 2.290 ms | 2.800 ms | 100% |
| JSON | Dart Frog | 31,309 | 1.943 ms | 2.520 ms | 3.269 ms | 100% |
| Echo | dart_orpc | 56,798 | 1.100 ms | 1.305 ms | 1.466 ms | 100% |
| Echo | Shelf | 33,579 | 1.825 ms | 2.247 ms | 3.099 ms | 100% |
| Echo | Serverpod | 28,373 | 2.161 ms | 2.818 ms | 3.640 ms | 100% |
| Echo | Dart Frog | 26,206 | 2.334 ms | 2.728 ms | 3.665 ms | 100% |

## Interpretation limits

- `dart_orpc` plaintext is implemented as framework middleware because its
  registered REST routes serialize results as JSON; the other plaintext cases
  use their normal route layer.
- This compares the shared HTTP routes, not native dart_orpc and Serverpod RPC
  wire protocols.
- One short run is sensitive to thermal state, process order, background work,
  and JIT activity in the load generator.
- The load generator shares CPU and memory bandwidth with the servers.

Before publishing, run at connections 1, 16, 64, and 256, repeat every sample
at least five times in randomized order, and report medians plus dispersion.
