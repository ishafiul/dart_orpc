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
- [ ] **HTTP-001 · P1 · Feature:** Add production request lifecycle controls and
  graceful shutdown.
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
- [ ] **TRANSPORT-002 · P1 · Feature:** Add streaming RPC.
- [ ] **TRANSPORT-003 · P1 · Feature:** Add WebSocket transport.
- [ ] **CLIENTGEN-001 · P1 · Feature:** Add non-Dart client generation.
- [ ] **QA-001 · P1 · Test:** Add an end-to-end generated server and client acceptance
  test.
- [ ] **PERF-001 · P2 · Performance:** Establish performance baselines and regression
  tracking.

## In progress

- [ ] **GEN-001 · P1 · Maintenance:** Refactor the generator into a maintainable,
  well-structured, and approachable architecture.

## Blocked

No blocked items.

## Done

- [x] **BUG-006 · P1 · Fix:** Make workspace tests run without a globally installed
  Melos executable.
- [x] **QA-002 · P1 · Test:** Establish comprehensive generator regression coverage
  and enforce a minimum coverage threshold.
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
