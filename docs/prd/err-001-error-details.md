# PRD — ERR-001: Structured error details across transports

- **Status:** Draft, under review
- **Tracker item:** `ERR-001` in [`TODO.md`](../../TODO.md)
- **Requirements map:** [#16](https://github.com/ishafiul/dart_orpc/issues/16)
- **Baseline:** `main` at `3d82bae`. Line references below are against this commit.

---

<overview>

## Problem Statement

- **What concrete pain point exists?**
  - Every dart_orpc error is serialized as `{"error": {"code", "message"}}`, so a server cannot attach machine-readable context such as a conflicting ID, field errors or retry hints. Clients end up parsing human-readable messages.
  - Luthor validation errors are flattened into a single string.
  - Every later error item needs a structured place for data: ERR-002 (validation issues), ERR-003 (custom codes) and ERR-004 (exception mapping).
- **Who experiences it?**
  - Application developers who throw `RpcException` from services, guards and validators.
  - Consumers of the generated Dart client.
  - API consumers who read the OpenAPI docs.
- **Why existing solutions don't work?**
  - `RpcException`, `RpcErrorBody` and the OpenAPI `RpcErrorBody` schema have no field for structured data.
  - Encoding failures on the error path behave differently per transport:
    - HTTP remaps them to a bare 500.
    - SSE ends without a terminal event.
    - WebSocket can break the connection.
  - WebSocket call failures cannot be reported to the application at all.

## Target Users & Personas

- **Server developer:**
  - Throws `RpcException.conflict('Todo exists', details: {'todoId': 7})` and expects every transport to deliver it.
  - Wants one `onError` hook to observe failures.
- **Dart client developer:** catches `RpcException` and reads `error.details?['todoId']` without parsing the message.
- **API consumer:** reads the OpenAPI `RpcErrorBody` schema and sees that `details` may be present.

## Success Metrics

- The same `details` object round-trips byte-for-byte equivalently through `POST /rpc`, REST, SSE `dart-orpc-error`, WebSocket error frames and both Dart clients. This is verified by one end-to-end test.
- Errors without details produce exactly today's wire output; existing envelope tests pass unchanged.
- No error-path encoding failure turns a thrown code into `INTERNAL_ERROR`, ends an SSE stream without a terminal event, or closes a WebSocket connection.
- Every dropped-details event and every WebSocket call failure reaches `RpcHttpServerOptions.onError`, with `transport`, `rpcMethod` and `callId` populated where applicable.

## Source Requirements & Decisions

- **Requirements map:** [#16 — [Map] ERR-001: Structured error details across transports](https://github.com/ishafiul/dart_orpc/issues/16)
- **Resolved grilling issues:**
  - [#17 — Choose the wire name and JSON type of error details](https://github.com/ishafiul/dart_orpc/issues/17) ([decision](https://github.com/ishafiul/dart_orpc/issues/17#issuecomment-6832490340))
    - The field is `error.details` and holds a JSON object only.
    - It is omitted when absent or empty.
    - `details.issues` is reserved for ERR-002.
  - [#18 — Choose the Dart API for attaching and reading error details](https://github.com/ishafiul/dart_orpc/issues/18) ([decision](https://github.com/ishafiul/dart_orpc/issues/18#issuecomment-6832660948))
    - Details are an untyped `JsonObject? details`; typed classes are deferred to ERR-005.
    - The `const` constructor is kept.
    - Every factory gains `details:`.
    - Clients treat malformed details as `null`.
  - [#19 — Decide which error details are exposed to clients](https://github.com/ishafiul/dart_orpc/issues/19) ([decision](https://github.com/ishafiul/dart_orpc/issues/19#issuecomment-6832718275))
    - Details are always sent as attached, on every code and transport.
    - There is no exposure option.
    - Docs warn that details are client-visible.
  - [#20 — Decide how unencodable or oversized error details are handled](https://github.com/ishafiul/dart_orpc/issues/20) ([revised decision](https://github.com/ishafiul/dart_orpc/issues/20#issuecomment-6832986733))
    - Details are checked at encoding time via the shared normalizer.
    - On failure, details are dropped and the real code is kept.
    - There is no size cap.
    - One shared `onError` reports for every transport.
- **Constraints carried forward:**
  - The wire change is additive.
  - The packages are `0.1.0-dev`. The `RpcHttpUpgradeHandler.handle` break is accepted (#20).
  - `annotations` and `core` stay dependency-light.
  - No runtime reflection.
  - Generated code does not change.
  - RPC, REST, SSE, WebSocket, OpenAPI and client output must not diverge (AGENTS.md).
- **Out of scope:**
  - ERR-002 structured validation issues.
  - ERR-003 custom error codes.
  - ERR-004 exception mapping and central filtering.
  - ERR-005 typed error-detail classes.
  - SEC-002 generic messages for explicit internal errors.
  - CLIENT-004 typed client transport errors.

</overview>

---

<functional-decomposition>

## Capability Tree (The WHAT)

### Capability C1: Error details contract

The core error types carry an optional details object, and one shared routine turns an error into its wire form.

#### Feature F1.1: Details on core error types

- **Description:** `RpcException` and `RpcErrorBody` carry an optional JSON-object `details`.
- **Inputs:** `JsonObject? details` passed to the `const` constructor or to any named factory.
- **Outputs:** `RpcException.details` and `RpcErrorBody.details` expose the value as given.
- **Behavior:**
  - `RpcErrorBody.toJson()` writes `details` only when it is non-null and non-empty.
  - Existing call sites compile unchanged.
  - The `const RpcException(...)` constructor stays usable in const contexts.

#### Feature F1.2: Safe error encoding

- **Description:** A single core routine encodes an `RpcException` into its wire envelope, normalizing details and falling back when they cannot be encoded.
- **Inputs:** An `RpcException`.
- **Outputs:**
  - The JSON envelope `{"error": {...}}`.
  - When details were dropped, the failure (error and stack trace) for reporting.
- **Behavior:**
  - Details pass through the same normalizer as procedure outputs (`normalizeJsonObject`), so objects with `toJson()` are converted and cycles or unsupported values fail.
  - Empty details are omitted.
  - On a normalization failure the envelope keeps the real `code` and `message` and has no `details`.
  - Errors without details have zero normalization cost.

### Capability C2: Server transport delivery

Every server transport emits the same error object.

#### Feature F2.1: HTTP RPC and REST error envelopes

- **Description:** `POST /rpc` and REST routes emit `details` in their error envelope.
- **Inputs:** An `RpcException` thrown from a procedure, guard, validator or framework path.
- **Outputs:** The HTTP response with the error's status code and the F1.2 envelope.
- **Behavior:**
  - The envelope is identical for RPC and REST.
  - A dropped-details failure is reported through `onError` with `transport: http`, in addition to any report already made for the originating error in the same exchange.

#### Feature F2.2: SSE terminal error event

- **Description:** The `dart-orpc-error` SSE event carries `details`.
- **Inputs:** A stream that fails with an `RpcException`.
- **Outputs:** The `event: dart-orpc-error` event with the F1.2 envelope as `data`.
- **Behavior:**
  - The terminal error event is always emitted, even when details have to be dropped.
  - Dropped details are reported as in F2.1.

#### Feature F2.3: WebSocket error frames

- **Description:** WebSocket `error` frames carry `details`, and oversized frames fall back without breaking the connection.
- **Inputs:** An `RpcException` for a unary or streaming WebSocket call.
- **Outputs:** An `{"type": "error", "id": …, "error": {...}}` frame.
- **Behavior:**
  - The frame uses the F1.2 envelope.
  - If the encoded frame exceeds `maxFrameBytes`, the frame is re-sent with the real `code` and `message` and no `details`.
  - The connection stays open.
  - The failure is reported with `transport: webSocket`, `rpcMethod` and `callId`.

### Capability C3: Unified error reporting

`RpcHttpServerOptions.onError` observes failures from every transport.

#### Feature F3.1: Transport-aware error events

- **Description:** `RpcHttpErrorEvent` identifies which transport and call produced it.
- **Inputs:** An error, its stack trace, the HTTP or upgrade request, and optional call metadata.
- **Outputs:** An `RpcHttpErrorEvent` with optional `transport` (`http` | `webSocket`), `rpcMethod` and `callId`.
- **Behavior:**
  - `transport` defaults to `http`, so existing construction sites and callbacks keep working.
  - The `onError` signature is unchanged.

#### Feature F3.2: Upgrade handlers report through the app

- **Description:** WebSocket call failures and dropped details reach the app's `onError`.
- **Inputs:** The error reporter passed by `RpcHttpApp` to `RpcHttpUpgradeHandler.handle`.
- **Outputs:** `RpcHttpErrorEvent`s whose `request` is the upgrade request, with `transport: webSocket` and call metadata.
- **Behavior:**
  - Reports are not limited to one per connection.
  - Failures inside the user's `onError` are isolated, matching existing HTTP behaviour (`hookErrors` metric).
  - Non-`RpcException` call failures, which are currently swallowed silently in `RpcWebSocketServer`, are reported.

### Capability C4: Client consumption

Both Dart clients expose details on the `RpcException` they throw.

#### Feature F4.1: HTTP client details

- **Description:** `HttpRpcTransport` populates `RpcException.details` from `error.details`.
- **Inputs:** An HTTP error envelope.
- **Outputs:** A thrown `RpcException` with `code`, `message` and `details`.
- **Behavior:**
  - A missing `details` value yields `null`.
  - A `details` value that is not a JSON object also yields `null`, and the exception is still thrown with the server's `code` and `message`.

#### Feature F4.2: WebSocket client details

- **Description:** The WebSocket frame codec and `WebSocketRpcTransport` carry `details` into the thrown `RpcException`.
- **Inputs:** A WebSocket `error` frame.
- **Outputs:** A thrown or emitted `RpcException` with `details`.
- **Behavior:** Same rules as F4.1. A malformed `details` value is not a protocol error.

### Capability C5: Contract documentation

The OpenAPI schema and the docs describe `details`.

#### Feature F5.1: OpenAPI schema

- **Description:** The OpenAPI `RpcErrorBody` component documents the optional `details`.
- **Inputs:** None (static component schema).
- **Outputs:** `RpcErrorBody.properties.details` as an object schema with additional properties allowed, not required, and a description noting that `issues` is reserved.
- **Behavior:** Every operation's error responses reference the updated component, with no per-operation changes.

#### Feature F5.2: Developer documentation

- **Description:** The docs explain how to attach and read details, the reserved `issues` key, client visibility, fallback behaviour and the shared `onError`.
- **Inputs:** The decisions in #17–#20.
- **Outputs:** Updated docs pages and a CHANGELOG entry noting the `RpcHttpUpgradeHandler.handle` break.
- **Behavior:**
  - The docs state that details are client-visible and must not contain secrets.
  - The docs show `onError` filtering by `transport`.

</functional-decomposition>

---

<structural-decomposition>

## Repository Structure & Modules (The HOW)

### Repository Structure

```text
packages/
├── dart_orpc_core/lib/src/
│   ├── rpc_exception.dart          # F1.1: details field, const ctor, factories
│   ├── rpc_response.dart           # F1.1: RpcErrorBody.details + toJson
│   └── rpc_error_encoding.dart     # F1.2: new — safe envelope encoding (exported)
├── dart_orpc_http/lib/src/
│   ├── rpc_http_options.dart       # F3.1: RpcHttpErrorEvent fields, RpcTransportKind
│   ├── rpc_http_app.dart           # F3.2: reporter for upgrade handlers; F2.1 top-level fallback
│   └── rpc_http_handler.dart       # F2.1 RPC/REST envelopes; F2.2 SSE terminal event
├── dart_orpc_websocket/lib/src/
│   ├── rpc_websocket_server.dart   # F2.3 error frames + fallback; F3.2 reporting
│   ├── rpc_websocket_protocol.dart # F4.2 codec decodes details
│   └── websocket_rpc_transport.dart# F4.2 thrown RpcException carries details
├── dart_orpc_client/lib/src/
│   └── http_rpc_transport.dart     # F4.1 parse details
└── dart_orpc_openapi/lib/src/
    └── openapi_document.dart       # F5.1 RpcErrorBody.details schema
doc/src/content/docs/               # F5.2 guides/errors-and-context.mdx, packages/core.mdx,
                                    #      reference/application.mdx, guides/websocket-streaming.mdx
CHANGELOG.md                        # F5.2 breaking-change note
```

### Module Definitions

#### Module: core error contract (`dart_orpc_core`)

- **Maps to capability:** C1.
- **Responsibility:** Own the error value types and the only code that turns an `RpcException` into its wire envelope.
- **Exports (public seams):**
  - **`RpcException`**
    - `const RpcException({required RpcErrorCode code, required String message, JsonObject? details})`
    - Every factory gains `{JsonObject? details}`, for example `factory RpcException.conflict(String message, {JsonObject? details})`.
    - `final JsonObject? details`
  - **`RpcErrorBody`**
    - `const RpcErrorBody({required String code, required String message, JsonObject? details})`
    - `toJson()` omits null or empty details.
  - **`RpcErrorEncoding encodeRpcError(RpcException error)`** (proposed name): returns the envelope JSON, plus `detailsError` and `detailsStackTrace` when details were dropped, plus `withoutDetails()` for the WebSocket oversize fallback.
  - **`RpcErrorDetailsEncodingException`** (proposed name)
    - Reported as the `onError` event's `error` when details are dropped.
    - Carries the originating `RpcException` and the underlying `cause`. See assumption A1.
- **Existing seams reused:** `normalizeJsonObject` and `JsonObject` from `json_utils.dart`.

#### Module: HTTP adapter (`dart_orpc_http`)

- **Maps to capability:** C2 (F2.1, F2.2) and C3.
- **Responsibility:** Write HTTP and SSE error envelopes via `encodeRpcError`, and give upgrade handlers a reporter.
- **Changes:**
  - **Envelope writers:** `_rpcErrorResponse` / `rpcHttpErrorResponse` (`rpc_http_handler.dart` L1839–1851) and the other `toResponse().toJson()` sites (L737, L1027, L1056, L1337, L1371) use `encodeRpcError`. The `const RpcErrorResponse` literals (L858, L1075) carry no details and stay as they are.
  - **SSE:** `terminateWithError` (L1433–1450) uses `encodeRpcError` and always emits the terminal event.
  - **Top-level fallback:** the `rpc_http_app.dart` catch (L430–445) writes with `encodeRpcError`.
  - **Dropped-details reporting:** goes through `onError`, bypassing the once-per-exchange `errorReported` guard (L318–330). See assumption A2.
- **Exports (public seams):**
  - **`enum RpcTransportKind { http, webSocket }`**
  - **`RpcHttpErrorEvent`**
    - Constructor: `RpcHttpErrorEvent({required RpcHttpRequest request, required Object error, required StackTrace stackTrace, RpcTransportKind transport = RpcTransportKind.http, String? rpcMethod, String? callId})`
    - New fields: `transport`, `rpcMethod`, `callId`.
  - **`typedef RpcUpgradeErrorReporter = void Function(Object error, StackTrace stackTrace, {String? rpcMethod, String? callId})`**
  - **`RpcHttpUpgradeHandler.handle(HttpRequest request, RpcContext context, RpcUpgradeErrorReporter reportError)`** — **breaking** (#20).

#### Module: WebSocket transport (`dart_orpc_websocket`)

- **Maps to capability:** C2 (F2.3), C3 (F3.2) and C4 (F4.2).
- **Responsibility:** Emit and decode error frames with details, and report call failures through the reporter it receives.
- **Changes:**
  - **`RpcWebSocketServer.handle`:** accepts the reporter.
  - **`_sendError` (L365–383):**
    - Encodes with `encodeRpcError`.
    - Catches the codec's oversize failure and re-enqueues `withoutDetails()`.
    - Reports with `transport: webSocket`, `rpcMethod` and `callId`.
  - **`_asRpcException` call sites (L308, L340):** report the original non-`RpcException` error before mapping it to `INTERNAL_ERROR`.
  - **`RpcWebSocketFrameCodec._errorBody` (L169–175):** reads `details` when it is an object, otherwise `null`.
  - **`WebSocketRpcTransport` (L186–189):** passes `details` into the thrown `RpcException`.
  - **Handshake rejection (L165–177):** unchanged; no details.

#### Module: HTTP client (`dart_orpc_client`)

- **Maps to capability:** C4 (F4.1).
- **Responsibility:** Parse `details` from HTTP error envelopes.
- **Changes:** `_parseResponse` (`http_rpc_transport.dart` L171–187) reads `error['details']` and keeps it only when it is a JSON object.

#### Module: OpenAPI (`dart_orpc_openapi`)

- **Maps to capability:** C5 (F5.1).
- **Responsibility:** Document `details` in the shared component.
- **Changes:** `_buildComponentSchemas` (`openapi_document.dart` L340–355) adds `details` to `RpcErrorBody.properties`.

</structural-decomposition>

---

<dependency-graph>

## Explicit Topological Dependency Chain

### Foundation Layer (Phase 0)

- **F1.1 Details on core error types:** no dependencies.
- **F3.1 Transport-aware error events:** no dependencies.
- **F5.1 OpenAPI schema:** no dependencies; it is a static schema.

### Core Domain Layer (Phase 1)

- **F1.2 Safe error encoding:** depends on [F1.1].
- **F4.1 HTTP client details:** depends on [F1.1].
- **F4.2 WebSocket client details:** depends on [F1.1].
- **F3.2 Upgrade handlers report through the app:** depends on [F3.1].

### Transport Layer (Phase 2)

- **F2.1 HTTP RPC and REST error envelopes:** depends on [F1.2, F3.1].
- **F2.2 SSE terminal error event:** depends on [F1.2, F3.1].
- **F2.3 WebSocket error frames:** depends on [F1.2, F3.2].

### Documentation and Acceptance (Phase 3)

- **F5.2 Developer documentation:** depends on [F2.1, F2.2, F2.3, F4.1, F4.2, F5.1].
- **End-to-end acceptance:** depends on [F2.1, F2.2, F2.3, F4.1, F4.2, F5.1].

</dependency-graph>

---

<implementation-roadmap>

## Phased Development Roadmap

### Phase 0: Foundation

- **Goal:** Add details to the core types, transport metadata to the error event, and details to the OpenAPI schema.
- **Entry criteria:** This PRD is approved on its issue.
- **Tasks:**
  - [ ] **F1.1 — `details` on `RpcException` and `RpcErrorBody`** (depends on: none)
    - Acceptance criteria:
      - The `const` constructor and every factory accept `details`.
      - `toJson()` omits null or empty details.
      - Existing tests pass unchanged.
    - Test strategy: unit tests in `dart_orpc_core/test/rpc_primitives_test.dart`.
  - [ ] **F3.1 — `RpcHttpErrorEvent.transport` / `rpcMethod` / `callId` and `RpcTransportKind`** (depends on: none)
    - Acceptance criteria:
      - The defaults keep existing construction compiling.
      - The fields are exported.
    - Test strategy: unit tests in `dart_orpc_http/test/rpc_http_options_test.dart`.
  - [ ] **F5.1 — OpenAPI `RpcErrorBody.details`** (depends on: none)
    - Acceptance criteria: the component has an optional object `details` with additional properties and a description of the reserved `issues` key.
    - Test strategy: assertion in `dart_orpc_openapi/test/openapi_document_test.dart`.
- **Exit criteria:** `dart analyze` is clean and all workspace tests pass.
- **Delivers:** Unblocks Phases 1 and 2.

### Phase 1: Core encoding, clients and reporting seam

- **Goal:** Add shared safe encoding, client parsing and the upgrade reporter.
- **Entry criteria:** Phase 0 is merged.
- **Tasks:**
  - [ ] **F1.2 — `encodeRpcError` with normalizer and fallback** (depends on: F1.1)
    - Acceptance criteria:
      - DTO-like `toJson()` values are converted.
      - Cycles and unsupported values yield an envelope without details, plus `detailsError`.
      - Empty details are omitted.
      - `withoutDetails()` works.
    - Test strategy: unit tests in core.
  - [ ] **F4.1 — HTTP client parses `details`** (depends on: F1.1)
    - Acceptance criteria:
      - Object details are exposed.
      - Missing or non-object details yield `null` while the code and message are kept.
    - Test strategy: `dart_orpc_client/test/http_rpc_transport_test.dart` and `http_rpc_transport_edge_cases_test.dart`.
  - [ ] **F4.2 — WebSocket codec and client parse `details`** (depends on: F1.1)
    - Acceptance criteria: same as F4.1. A malformed value is not a protocol error.
    - Test strategy: `dart_orpc_websocket/test/rpc_websocket_protocol_test.dart` and `websocket_rpc_transport_test.dart`.
  - [ ] **F3.2 — `RpcHttpUpgradeHandler.handle` receives `RpcUpgradeErrorReporter`** (depends on: F3.1)
    - Acceptance criteria:
      - Reports arrive at `serverOptions.onError` with `transport: webSocket` and the upgrade request.
      - There can be multiple reports per connection.
      - A throwing `onError` is isolated.
    - Test strategy: `dart_orpc_http/test/rpc_http_app_test.dart` with a fake upgrade handler.
- **Exit criteria:** Phase 1 tests pass, and `RpcWebSocketServer` compiles against the new signature.
- **Delivers:** Clients can read details, and every transport can report.

### Phase 2: Transport delivery

- **Goal:** Every server transport emits details with a safe fallback.
- **Entry criteria:** Phase 1 is merged.
- **Tasks:**
  - [ ] **F2.1 — HTTP RPC and REST envelopes use `encodeRpcError`** (depends on: F1.2, F3.1)
    - Acceptance criteria:
      - `POST /rpc` and REST return the same `error` object with details.
      - Unencodable details produce the real code with no details, plus an `onError` event (`transport: http`).
      - Errors without details are byte-identical to today's output.
    - Test strategy: `dart_orpc_http/test/rpc_http_handler_test.dart` and `http_response_contracts_test.dart`.
  - [ ] **F2.2 — SSE `dart-orpc-error` carries details** (depends on: F1.2, F3.1)
    - Acceptance criteria:
      - The terminal event includes details.
      - Unencodable details still produce the terminal event, without details.
    - Test strategy: `dart_orpc_http/test/rpc_sse_test.dart`.
  - [ ] **F2.3 — WebSocket error frames carry details, with oversize fallback and reporting** (depends on: F1.2, F3.2)
    - Acceptance criteria:
      - Unary and stream errors include details.
      - A frame over `maxFrameBytes` falls back to no details and the connection stays open.
      - `onError` receives `rpcMethod` and `callId`.
      - Non-`RpcException` call failures are reported.
    - Test strategy: `dart_orpc_websocket/test/rpc_websocket_integration_test.dart`.
- **Exit criteria:** All transport suites pass.
- **Delivers:** The feature works on every transport.

### Phase 3: Documentation and acceptance

- **Goal:** Prove alignment end to end and document the contract.
- **Entry criteria:** Phase 2 is merged.
- **Tasks:**
  - [ ] **End-to-end acceptance** (depends on: F2.1, F2.2, F2.3, F4.1, F4.2, F5.1)
    - Acceptance criteria: one procedure throwing `RpcException.conflict(..., details: {'todoId': 7})` yields equal `details` via the generated client over HTTP RPC, REST, SSE and WebSocket, and in the OpenAPI component.
    - Test strategy: extend `apps/basic_app/test/streaming_acceptance_test.dart` (QA-001).
  - [ ] **F5.2 — Docs and CHANGELOG** (depends on: all above)
    - Acceptance criteria:
      - The four docs pages are updated.
      - The client-visibility warning and the reserved `issues` key are documented.
      - The CHANGELOG notes the `RpcHttpUpgradeHandler.handle` break.
    - Test strategy: docs build passes, and code samples compile against the API.
- **Exit criteria:** The full workspace test suite and `dart analyze` pass, and `TODO.md` marks ERR-001 done.
- **Delivers:** ERR-001 is complete, and ERR-002, ERR-003 and ERR-004 are unblocked.

</implementation-roadmap>

---

<test-strategy>

## Test Strategy & Critical Scenarios

### Test Pyramid

```text
        /\
       /E2E\        ← one cross-transport acceptance test (basic_app)
      /------\
     /Integration\  ← HTTP handler, SSE, WebSocket server/client suites
    /------------\
   /  Unit Tests  \ ← core encoding, client parsing, OpenAPI component, event fields
  /----------------\
```

### Critical Test Scenarios

#### Module: core error contract

- **Happy path:** `RpcException.conflict('x', details: {'todoId': 7}).toResponse().toJson()` returns `{"error": {"code": "CONFLICT", "message": "x", "details": {"todoId": 7}}}`.
- **Edge cases:**
  - `details: {}` and `details: null` produce no `details` key.
  - A `const` instance with details works.
  - A DTO with `toJson()` nested in details is converted.
- **Error cases:** A cyclic map, or an object without `toJson()`, yields an envelope with the real code and no details, plus `detailsError`.

#### Module: HTTP adapter

- **Happy path:** RPC and REST error responses carry identical `error` objects with details and the correct status code.
- **Edge cases:**
  - Errors without details are byte-identical to today's output (regression).
  - The REST status override via `RpcHttpResponseControl` does not alter the envelope.
- **Error cases:**
  - Unencodable details return the real code, not 500.
  - `onError` is called for the dropped details even after the originating error was reported (A2).
  - SSE still emits `dart-orpc-error`.
- **Integration seams:** A fake `RpcHttpUpgradeHandler` receives the reporter, and its reports reach `onError` with `transport: webSocket`.

#### Module: WebSocket transport

- **Happy path:** Unary and stream error frames carry details, and `WebSocketRpcTransport` throws `RpcException` with equal details.
- **Edge cases:** Multiple failing calls on one connection each produce a report.
- **Error cases:**
  - Details pushing the frame over `maxFrameBytes` fall back, the connection stays open, and later calls succeed.
  - A non-object `details` from the server yields `details == null` on the client.

#### Module: HTTP client

- **Happy path:** The details object is exposed on the thrown `RpcException`.
- **Error cases:** A non-object `details` value still throws `RpcException` with the server's code and message.

#### Module: OpenAPI

- **Happy path:** `components.schemas.RpcErrorBody.properties.details` exists, is not in `required`, and allows additional properties.

#### End-to-end

- One procedure, all transports and the generated client observe equal `details`. Divergence fails the build (AGENTS.md).

</test-strategy>

---

<architecture>

## System Architecture & ADRs

- **Architecture overview:** `RpcException` (core) → `encodeRpcError` (core, single encoding path) → transport writers (HTTP JSON, SSE event, WebSocket frame) → wire `error` object → client parsers (HTTP, WebSocket codec) → `RpcException` with details. Failures on this path go through one reporter into `RpcHttpServerOptions.onError`.
- **Data models:** No persistence. The wire contract is `{"error": {"code": string, "message": string, "details"?: object}}`, where `details.issues` is reserved for ERR-002.
- **Decisions & trade-offs (ADRs):**
  - **Field name and type** (#17)
    - **Decision:** `error.details`, a JSON object only, omitted when empty.
    - **Rationale:** Avoids confusion with the success envelope's top-level `data`, and leaves room for ERR-002.
    - **Trade-offs:** No bare-list or scalar details.
    - **Alternatives considered:**
      - Naming it `data`.
      - Allowing any JSON value.
      - Google-style typed entry lists.
      - A `$`-prefixed namespace.
  - **Untyped Dart API** (#18)
    - **Decision:** `JsonObject? details`, keeping the `const` constructor, with typed classes deferred to ERR-005.
    - **Rationale:** Typed decoding needs a per-procedure, per-code key, which depends on ERR-003. Dart cannot enforce declared throws. Typed details also mean heavy generator work during GEN-001.
    - **Trade-offs:** Clients cast by hand until ERR-005.
    - **Alternatives considered:**
      - Typed detail classes now.
      - An `RpcErrorDetails` wrapper.
      - Dropping `const`.
  - **No exposure policy** (#19)
    - **Decision:** Details are always sent as attached.
    - **Rationale:** Details only leave the server deliberately, and unknown errors already reveal nothing. This matches oRPC and NestJS.
    - **Trade-offs:** Authors must avoid secrets. Central filtering is deferred to ERR-004.
    - **Alternatives considered:**
      - Stripping details on `INTERNAL_ERROR`.
      - A configurable predicate.
  - **Encoding-time validation with fallback** (#20)
    - **Decision:** Details are normalized at encoding time. On failure or an oversized WebSocket frame, the error is sent without details and the real code is kept.
    - **Rationale:** Covers the `const` constructor and every factory, keeps the client's code correct, and makes the transports behave identically.
    - **Trade-offs:** The bug surfaces in `onError`, not at the throw site.
    - **Alternatives considered:**
      - Construction-time validation.
      - Failing to `INTERNAL_ERROR`.
      - A shared size cap.
  - **One shared `onError`** (#20, revised)
    - **Decision:** `RpcHttpErrorEvent` gains `transport`, `rpcMethod` and `callId`, and `RpcHttpUpgradeHandler.handle` receives a reporter.
    - **Rationale:** One place to observe every transport's failures.
    - **Trade-offs:** A breaking change for external `RpcHttpUpgradeHandler` implementers, accepted for `0.1.0-dev`.
    - **Alternatives considered:**
      - A separate WebSocket `onError` (originally chosen, then revised).
      - A sealed event type.
      - Log-only reporting.

### Assumptions (to confirm in PRD review)

- **A1:** The `error` in a dropped-details `onError` event is a new `RpcErrorDetailsEncodingException` that carries the originating `RpcException` and the underlying `cause`, so the app can tell which error lost its details. The alternative is to report the raw normalizer error (`JsonUnsupportedObjectError` / `JsonCyclicError`).
- **A2:** A dropped-details report bypasses the HTTP once-per-exchange `errorReported` guard, so an exchange can produce two events: the originating error and the dropped details.
- **A3:** Names marked "proposed" (`encodeRpcError`, `RpcErrorEncoding`, `RpcErrorDetailsEncodingException`, `RpcTransportKind`, `RpcUpgradeErrorReporter`) may be refined during implementation without re-review, as long as the seams and behaviour above hold.

</architecture>

---

<risks>

## Risk Analysis & Mitigations

- **Technical risks:**
  - **Wire divergence between transports.**
    - Mitigation: a single `encodeRpcError` path and the end-to-end acceptance test.
  - **Error-path regressions in rarely exercised code:** SSE mid-stream errors and WebSocket shutdown frames.
    - Mitigation: byte-identical regression tests for errors without details, plus explicit fallback tests.
  - **Mutable details map.** The `const` constructor stores the map as given, so mutation after the throw is visible at encoding.
    - Mitigation: encoding copies through the normalizer, and the docs say details should be treated as immutable.
  - **Performance.** Normalization runs only when details are non-null, so the no-details path is unchanged.
    - Mitigation: the existing HTTP performance regression test must stay green.
- **Dependency risks:**
  - **Breaking `RpcHttpUpgradeHandler.handle`.** Only `RpcWebSocketServer` implements it in the workspace. External implementers break at compile time, which is visible rather than silent.
    - Mitigation: CHANGELOG note.
- **Scope risks:** The pull toward ERR-002 (validation issues), ERR-003/ERR-005 (typed codes and details) and ERR-004 (filtering) is held by the out-of-scope list. `details.issues` is only reserved and documented here, not populated.

</risks>
