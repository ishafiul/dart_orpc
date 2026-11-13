# dart_orpc development tracker

This file is the source of truth for planned fixes, features, tests, and maintenance.
Update it whenever work is discovered, started, completed, deferred, or superseded.

Do not add release, package publication, or pub.dev tasks to this tracker.

## Ready

No ready items.
## Backlog

- [ ] **DOC-001 · P2 · Documentation:** Reconcile the documented workspace tooling
  with the repository configuration.
- [ ] **OBS-001 · P1 · Feature:** Add structured logging and trace propagation
  (OpenTelemetry). Route metrics already exist via `RpcHttpMetricsOptions` and
  `onComplete`.
- [ ] **SEC-001 · P1 · Feature:** Document the application authentication integration
  model.
- [ ] **SEC-002 · P2 · Security:** Stop leaking internal details in explicit
  internal-error messages: Luthor output-validation failures send DTO field names
  to clients. Send a generic message and report the real one through `onError`.
  Split out of ERR-001 ([#19](https://github.com/ishafiul/dart_orpc/issues/19)).
- [ ] **CLIENT-001 · P1 · Feature:** Add per-call client timeouts and cancellation
  to `RpcCallOptions`. Headers and bearer tokens already exist.
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
- [ ] **CLIENTGEN-002 · P1 · Architecture:** Generate the Dart client and its DTO
  contracts into a server-free output so client apps no longer depend on the
  server package (today `AppClient` lives in the server's `app.orpc.dart`).
- [ ] **PKG-001 · P1 · Architecture:** Add a client-only facade without `dart:io`
  (for example `package:dart_orpc/client.dart`) so Flutter web can import it; the
  current facade re-exports `dart_orpc_http` and `dart_orpc_websocket`.
- [ ] **TRANSPORT-007 · P1 · Feature:** Add an SSE or HTTP-stream client transport
  that works on web; server streams are only consumable through the `dart:io`
  WebSocket transport.
- [ ] **CORE-001 · P1 · Feature:** Let guards and middleware attach typed context
  bindings (for example the authenticated user) that handlers can read.
- [ ] **BUG-007 · P1 · Fix:** Make the `basic_app` `TodoPermissionGuard` fail closed;
  it allows every request because nothing sets `attributes['permissions']`.
  Depends on CORE-001.
- [ ] **ERR-002 · P1 · Feature:** Return structured validation issues (field path
  and message) from the Luthor bridge instead of one flattened string.
- [ ] **ERR-003 · P1 · Feature:** Allow application-defined typed error codes beyond
  the closed `RpcErrorCode` enum.
- [ ] **ERR-004 · P1 · Feature:** Add a centralized exception-mapping hook that turns
  domain exceptions into `RpcException` for every transport.
- [ ] **ERR-005 · P2 · Feature:** Add typed error-detail classes that the generated
  client decodes from `error.details`, keyed by error code and designed together
  with ERR-003. Deferred from ERR-001
  ([#18](https://github.com/ishafiul/dart_orpc/issues/18)), which ships untyped
  `JsonObject` details on the same wire field.
- [ ] **DI-002 · P1 · Feature:** Support async provider factories.
- [ ] **DI-003 · P1 · Feature:** Add a provider initialization lifecycle hook to pair
  with `RpcDisposable`.
- [ ] **DI-004 · P1 · Feature:** Add provider overrides to generated app builders for
  tests.
- [ ] **QA-003 · P1 · Test:** Add an in-process test harness (test app builder plus an
  in-memory client transport) for application tests.
- [ ] **OAPI-001 · P2 · Feature:** Document RPC-only procedures in OpenAPI; procedures
  without a REST mapping are currently omitted.
- [ ] **OAPI-002 · P2 · Feature:** Emit only the error responses each procedure can
  produce instead of every `RpcErrorCode`.
- [ ] **OAPI-003 · P2 · Feature:** Add operation summaries, deprecation, examples,
  and enum schemas to OpenAPI output.
- [ ] **GEN-003 · P2 · Feature:** Support enums, `DateTime`, and repeated list query
  parameters in REST path, query, and header bindings.
- [ ] **GEN-004 · P2 · Feature:** Support sealed-union and generic DTO outputs (for
  example `Paginated<T>`) and add pagination helpers.
- [ ] **CORE-002 · P2 · Feature:** Add procedure-level interceptors with access to
  procedure metadata.
- [ ] **CLIENT-004 · P2 · Feature:** Expose typed client transport errors instead of
  message-only `RpcClientException`s.
## In progress

- [ ] **ERR-001 · P1 · Feature:** Add a `details` payload to `RpcException` and the
  error envelope across RPC, REST, WebSocket, OpenAPI, and the client.
  Tracked by [#16](https://github.com/ishafiul/dart_orpc/issues/16); core task #22 done,
  error reporting task #24 done; F2.1 in review.
- [ ] **GEN-001 · P1 · Maintenance:** Refactor the generator into a maintainable,
  well-structured, and approachable architecture.
- [ ] **PERF-001 · P2 · Performance:** Establish performance baselines and regression
  tracking.

## Blocked

No blocked items.

## Done

- [x] **HTTP-002 · P2 · Feature:** Add rate-limiting support
  (`RpcHttpRateLimitOptions`, sliding-window limiter with tests).
- [x] **GEN-002 · P1 · Feature:** Support JSON-native scalar and `void` procedure
  outputs across generated RPC, REST, OpenAPI, and Dart clients.
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
