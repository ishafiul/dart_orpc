# dart_orpc development tracker

This file is the source of truth for planned fixes, features, tests, and maintenance.
Update it whenever work is discovered, started, completed, deferred, or superseded.

Do not add release, package publication, or pub.dev tasks to this tracker.

## Ready

No ready items.
## Backlog

- [ ] **DOC-001 · P2 · Documentation:** Reconcile the documented workspace tooling
  with the repository configuration.
- [ ] **OBS-001 · P1 · Feature:** Add production metrics and tracing.
- [ ] **SEC-001 · P1 · Feature:** Document the application authentication integration
  model.
- [ ] **HTTP-002 · P2 · Feature:** Add rate-limiting support.
- [ ] **CLIENT-001 · P1 · Feature:** Add client headers, authentication, timeouts,
  and cancellation.
- [ ] **CLIENT-002 · P1 · Feature:** Add an opt-in retry policy.
- [ ] **CLIENT-003 · P1 · Feature:** Add RPC batching.
- [ ] **HTTP-003 · P1 · Security:** Harden the custom HTTP implementation and expand
  security and edge-case coverage.
- [ ] **AUTH-001 · P1 · Feature:** Add JWT, session, and API-key authentication
  adapters.
- [ ] **TRANSPORT-001 · P1 · Feature:** Add multipart upload support.
- [ ] **TRANSPORT-004 · P2 · Feature:** Add opt-in WebSocket reconnection and
  resumable stream cursors.
- [ ] **TRANSPORT-005 · P2 · Feature:** Add a browser WebSocket client adapter.
- [ ] **TRANSPORT-006 · P2 · Feature:** Add client-streaming and bidirectional
  RPC after the server-streaming protocol has stabilized.
- [ ] **CLIENTGEN-001 · P1 · Feature:** Add non-Dart client generation.

## In progress

- [ ] **GEN-001 · P1 · Maintenance:** Refactor the generator into a maintainable,
  well-structured, and approachable architecture.
- [ ] **PERF-001 · P2 · Performance:** Establish performance baselines and regression
  tracking.

## Blocked

No blocked items.

## Done

- [x] **TRANSPORT-003 · P1 · Feature:** Add the versioned WebSocket unary and
  server-streaming transport with bounded output and lifecycle controls.
- [x] **TRANSPORT-002 · P1 · Feature:** Add typed server-streaming RPC and
  explicit REST/SSE derived from shared procedure metadata.
- [x] **HTTP-001 · P1 · Feature:** Add streaming HTTP bodies, request
  cancellation, connection draining, and graceful shutdown.
- [x] **DI-001 · P1 · Architecture:** Share each generated module container
  between its RPC and REST registries during application construction.
- [x] **BUG-006 · P1 · Fix:** Make workspace tests run without a globally installed
  Melos executable.
- [x] **QA-002 · P1 · Test:** Establish comprehensive generator regression coverage
  and enforce a minimum coverage threshold.
- [x] **QA-001 · P1 · Test:** Add an end-to-end generated server and client acceptance
  test covering HTTP RPC, REST, WebSocket RPC, SSE, OpenAPI, and shared guards.
- [x] **BUG-004 · P1 · Fix:** Reject duplicate RPC methods and REST routes during
  generation.
- [x] **BUG-005 · P1 · Fix:** Reject duplicate generated client namespaces.
- [x] **BUG-001 · P1 · Fix:** Fixed the CORS preflight response contract.
- [x] **BUG-002 · P1 · Fix:** Fixed static assets mounted at the root path.
- [x] **BUG-003 · P1 · Fix:** Aligned the generator guard test with the current
  generated guard contract.

## Pull requests

| Item | Branch | Pull request | Status |
| --- | --- | --- | --- |
| GEN-001 | `refactor/generator-architecture` | [#1](https://github.com/ishafiul/dart_orpc/pull/1) | In review |
| BUG-001 | `refactor/generator-architecture` | [#1](https://github.com/ishafiul/dart_orpc/pull/1) | In review |
| BUG-002 | `refactor/generator-architecture` | [#1](https://github.com/ishafiul/dart_orpc/pull/1) | In review |
| BUG-003 | `refactor/generator-architecture` | [#1](https://github.com/ishafiul/dart_orpc/pull/1) | In review |
| BUG-004 | `refactor/generator-architecture` | [#1](https://github.com/ishafiul/dart_orpc/pull/1) | In review |
| BUG-005 | `refactor/generator-architecture` | [#1](https://github.com/ishafiul/dart_orpc/pull/1) | In review |
| QA-002 | `refactor/generator-architecture` | [#1](https://github.com/ishafiul/dart_orpc/pull/1) | In review |
| BUG-006 | `refactor/generator-architecture` | [#1](https://github.com/ishafiul/dart_orpc/pull/1) | In review |
| DI-001 | `fix/di-applevel-singletone` | [#4](https://github.com/ishafiul/dart_orpc/pull/4) | In review |
