# Fixed-rate CPU, memory, and GC benchmark — 2026-07-23

This is a single-machine diagnostic run, not a publishable baseline. Each AOT
fixture served the JSON scenario at a fixed target of 20,000 requests/second
for 60 seconds with 64 connections. Fixtures ran one at a time. CPU and RSS
were sampled approximately every 500 ms, and `DART_VM_OPTIONS=--verbose-gc`
captured garbage-collection activity.

## Environment

- Apple M4, 16 GiB RAM
- macOS 26.5 (25F71), arm64
- Dart 3.11.0 stable
- `oha` 1.15.0
- Production AOT executables
- Git base `af24b1a`, with uncommitted shared module-runtime DI changes

## CPU and memory

RSS values are MiB. Every fixture sustained approximately 20,000 requests/s
with a 100% completed-response success rate.

| Framework | Average CPU | Peak CPU | Idle RSS | Peak RSS | Cooldown RSS |
| --- | ---: | ---: | ---: | ---: | ---: |
| dart_orpc | **61.0%** | **73.4%** | **13.3** | **23.6** | 21.9 |
| Shelf | 67.9% | 84.7% | 15.4 | 25.2 | 22.7 |
| Dart Frog | 77.6% | 105.2% | 14.3 | 47.5 | **20.1** |
| Serverpod | 76.1% | 106.8% | 20.9 | 60.0 | 30.4 |

At the same completed request rate, dart_orpc used approximately 10% less
average CPU than Shelf, 21% less than Dart Frog, and 20% less than Serverpod.
It also had the lowest idle and peak RSS. Dart Frog had the lowest RSS after
the five-second cooldown, about 1.8 MiB below dart_orpc.

## Latency at fixed rate

| Framework | Actual requests/s | p50 | p99 |
| --- | ---: | ---: | ---: |
| dart_orpc | 19,998 | **0.433 ms** | **1.791 ms** |
| Shelf | 19,999 | 0.533 ms | 3.554 ms |
| Serverpod | 20,000 | 0.639 ms | 4.709 ms |
| Dart Frog | 19,999 | 0.656 ms | 4.590 ms |

## Garbage collection

Pause values come from Dart's verbose-GC `time (ms)` field. Counts include GC
events logged during startup, the 60-second load, and the five-second cooldown.

| Framework | GC events | Major/concurrent events | Total GC time | Average pause | Maximum pause |
| --- | ---: | ---: | ---: | ---: | ---: |
| dart_orpc | **6,388** | **0** | 495.1 ms | 0.078 ms | **0.7 ms** |
| Shelf | 7,754 | **0** | **396.2 ms** | 0.051 ms | 4.0 ms |
| Dart Frog | 40,984 | 466 | 598.1 ms | **0.015 ms** | 8.3 ms |
| Serverpod | 9,703 | 288 | 890.2 ms | 0.092 ms | 2.9 ms |

dart_orpc performed the fewest collections, avoided major/concurrent
old-generation events in this run, and had the lowest maximum pause. Shelf
spent less total time in GC because its individual scavenges were shorter.
Dart Frog collected far more frequently, partly because its observed new-space
capacity was 2 MiB rather than the 8 MiB used by the other fixtures; GC event
counts therefore should not be treated as direct allocation counts.

## Limitations

- One stable-order run is sensitive to thermal and background-system noise.
- `ps` CPU percentages are process-level samples, not hardware counters.
- Verbose GC adds diagnostic overhead and can affect timing.
- A five-second cooldown is too short to make a memory-leak claim.
- Provider-heavy applications, authentication, databases, and large payloads
  may produce different allocation behavior.
- Publishable evidence requires randomized repeated runs and a longer soak.
