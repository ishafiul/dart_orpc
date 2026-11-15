# PRD — ERR-002: Structured validation issues

- **Status** — Proposed, awaiting issue-level approval.
- **Requirements map** — [#54](https://github.com/ishafiul/dart_orpc/issues/54)
- **Trackers** — `ERR-002` and `SEC-002` in [TODO.md](../../TODO.md)
- **Prerequisites** — [ERR-001](https://github.com/ishafiul/dart_orpc/issues/16) reserved `error.details.issues`. [DEPS-001](https://github.com/ishafiul/dart_orpc/issues/61) shipped Luthor 1.1. Both are complete.

<overview>

## Problem and success criteria

App developers need to associate validation failures with form fields. Today they must parse a flattened `BAD_REQUEST` message, and REST binding can reject a request before DTO validation runs. API consumers need the issue shape in OpenAPI. Server developers need diagnostics when a procedure produces an invalid DTO, while clients should receive a generic server error.

One issue contract serves HTTP RPC, REST, and WebSocket. Dart clients can read issues by field path, and equivalent field failures report the same path and code. Output validation reports the procedure and failure to the existing server hook across HTTP RPC, REST, SSE, and WebSocket.

## Source decisions

| Decision | Requirement |
| --- | --- |
| [#55](https://github.com/ishafiul/dart_orpc/issues/55#issuecomment-6860296588) | Use the structured Luthor API after DEPS-001. The completed migration shipped Luthor 1.1. |
| [#56](https://github.com/ishafiul/dart_orpc/issues/56#issuecomment-6894508490) | Require typed `path`, open string `code`, and human-readable `message`. |
| [#57](https://github.com/ishafiul/dart_orpc/issues/57#issuecomment-6894589158) | Cover Luthor input validation and REST input decoding. Use the agreed REST paths and codes. |
| [#58](https://github.com/ishafiul/dart_orpc/issues/58#issuecomment-6894869838) | Preserve public input error messages, all emitted issues in order, and the WebSocket size fallback. |
| [#59](https://github.com/ishafiul/dart_orpc/issues/59#issuecomment-6895153844) | Include SEC-002 with generic public output errors and server diagnostics. |
| [#60](https://github.com/ishafiul/dart_orpc/issues/60#issuecomment-6895244061) | Provide a shared Dart getter and optional issues in the shared OpenAPI error schema. |

Scope excludes Luthor `params`, a REST `location` field, generic core JSON and RPC envelope errors, issue count caps, localization, per-status schemas (OAPI-002), the general typed-details API (ERR-005), and exception mapping (ERR-004). Application-defined error codes and typed transport errors remain in ERR-003 and CLIENT-004.

</overview>

<functional-decomposition>

## Capabilities (WHAT)

### C1. Shared validation issue contract

#### F1.1. Issue model and JSON

An issue carries a path, code, and message. Object keys are strings, list indexes are integers, and a whole-value failure uses `[]`. Preserve literal keys such as `["a.b"]` and numeric string keys such as `["0"]` as individual string segments. Codes form an open set. The message is human-readable.

```json
{
  "error": {
    "code": "BAD_REQUEST",
    "message": "Invalid RPC input for \"todo.getById\": id: Expected an integer.",
    "details": {
      "issues": [
        {"path": ["id"], "code": "invalidType", "message": "Expected an integer."}
      ]
    }
  }
}
```

Example message wording is illustrative. The emitted top-level message follows each existing error path.

### C2. Structured input failures

#### F2.1. Luthor DTO failures

Convert each emitted Luthor issue into the shared model using its typed path, `IssueCode.name`, and message. Preserve validator order and multiple issues at the same path. Keep the existing top-level message and `BAD_REQUEST` code. Strict DTO unknown keys use Luthor's `unrecognizedKey`. Generic object and envelope checks keep their existing behavior.

#### F2.2. REST parameter and body failures

Emit one issue when adapter decoding fails. For a DTO-bound field use its public JSON key, including when the REST wire parameter is aliased. For a standalone REST parameter use its external name. For whole-body failures use `[]`. Preserve structured errors received from Luthor.

| Adapter failure | Issue code |
| --- | --- |
| Missing required input | `required` |
| Failed scalar conversion or wrong JSON type | `invalidType` |
| Malformed JSON body | `invalidJson` |
| Body decoder fails without a more specific issue | `invalidBody` |

For example, REST `GET /todos/nope` and RPC input `{"id":"nope"}` for the same procedure both identify `["id"]` with `invalidType`. Their existing top-level messages can differ.

### C3. Server-only output validation diagnostics

#### F3.1. Safe output failure and reporting

When a Luthor output validator fails, send `INTERNAL_ERROR` with `Internal server error.` and no validation details. Direct callers of either public bridge helper still receive a `RpcException` with that code. The existing server `onError` hook, when configured, receives the procedure and validation diagnostic. Keep raw DTO payloads out of the report. Cover unary results and stream events. Keep the application exception exposure policy from [ERR-001 #19](https://github.com/ishafiul/dart_orpc/issues/19#issuecomment-6832718275).

### C4. Client and OpenAPI exposure

#### F4.1. Typed Dart access

Both Dart transports already preserve the raw details map. `RpcException.validationIssues` returns `RpcValidationIssue` entries in wire order. Unknown string codes remain readable. Malformed entries are skipped. An absent, invalid, or empty issue list yields an empty result. Raw `details` remains accessible.

#### F4.2. Shared OpenAPI error schema

Describe optional `details.issues` in `RpcErrorBody`. Each entry requires `path`, `code`, and `message`. Path array items use `oneOf` with string and integer schemas. Codes remain open strings. Keep application keys in `details` and use the existing error response references. [OpenAPI 3.0.3 Schema Object](https://spec.openapis.org/oas/v3.0.3#schema-object)

#### F4.3. Acceptance and documentation

Add a `basic_app` acceptance slice that exercises equivalent HTTP RPC, REST, and WebSocket input failures, typed client access, and generated OpenAPI. Document eligible failures, root paths, open codes, preserved messages, and the WebSocket size fallback. Mark ERR-002 and SEC-002 complete in `TODO.md` when their acceptance criteria pass.

</functional-decomposition>

<structural-decomposition>

## Repository modules (HOW)

| Module | Responsibility and seams |
| --- | --- |
| `dart_orpc_core` | Export `RpcValidationIssue` through core and the existing facade. Centralize issue serialization and tolerant parsing. Add the getter to `RpcException`. Keep diagnostics separate from serialized error fields. Inspect both unary and streaming encoder wrappers to preserve the output diagnostic. |
| `dart_orpc_luthor` | Map typed `ValidationIssue` values to the shared contract in `decodeRpcInputWithLuthor`. Redact and retain a private diagnostic at the output validation boundary shared by `encodeRpcOutputWithLuthor` and `encodeRpcOutputJsonWithLuthor`. |
| `dart_orpc_http` and `dart_orpc_generator` | Reuse REST decoding helpers and pass DTO field identity from generated bindings where needed. Keep current public helper callers working and regenerate checked-in examples. Verify standalone REST parameters and the explicit body path, plus SSE terminal errors. |
| `dart_orpc_websocket` | Use existing frame encoding and the HTTP upgrade error reporter. Report framework output-validation diagnostics through that reporter. Scope the change to output validation because WebSocket call reporting currently skips explicit `RpcException`s. |
| `dart_orpc_client` and `dart_orpc_openapi` | Reuse the existing HTTP and WebSocket exception paths. Add the issue shape to the shared OpenAPI error component and update the golden. |
| `apps/basic_app` and `doc/` | Prove parity and document both client access and output diagnostics. |

The diagnostic carrier is an implementation seam for PR review. It must survive encoder wrappers, stay outside the response and attached details, and remain available to `onError` on each transport. No new runtime dependency is needed.

</structural-decomposition>

<dependency-graph>

## Dependency graph

- **Foundation** — F1.1 has no pending feature prerequisites.
- **Input integration** — F2.1 and F2.2 depend on F1.1.
- **Output safety** — F3.1 can proceed alongside F1.1. Land the redaction and reporting together.
- **Exposure** — F4.1 and F4.2 depend on F1.1.
- **Acceptance and rollout** — F4.3 depends on F2.1, F2.2, F3.1, F4.1, and F4.2.

</dependency-graph>

<implementation-roadmap>

## Roadmap

- [ ] **Phase 0** — Establish the core issue shape and serialization (F1.1).
- [ ] **Phase 1** — Add Luthor and REST issue producers (F2.1, F2.2) and deliver SEC-002 across transports (F3.1).
- [ ] **Phase 2** — Expose the model through Dart and OpenAPI (F4.1, F4.2). These can start as soon as phase 0 lands.
- [ ] **Phase 3** — Run the acceptance slice, update docs and tracker, and verify workspace checks (F4.3).

</implementation-roadmap>

<test-strategy>

## Verification

| Seam | Required checks |
| --- | --- |
| Core and clients | Round-trip string keys and integer indexes, including dotted keys, numeric string keys, and root paths. Parse mixed valid and malformed entries without losing order, unknown codes, or raw details. Check absent details and default responses from older servers. |
| Luthor and REST input | Assert unchanged top-level messages and exact structured issue codes and paths. Cover multiple issues per path, strict unknown keys, aliased REST bindings, standalone parameters, and each REST body failure class. Preserve Luthor issues from REST and verify RPC protocol and generic JSON failures keep their previous shape. |
| Output and hooks | Test both bridge helpers and unary and streaming dispatch. Assert exact generic output errors on HTTP RPC, REST, SSE, and WebSocket. Assert the server hook receives the diagnostic without the raw DTO. Check existing application errors still follow ERR-001. |
| Wire and OpenAPI | Check parity through the live example, typed HTTP and WebSocket access, and the generated OpenAPI golden. Exercise the WebSocket oversize retry with details omitted and with the short fallback message. |

Run focused package checks during implementation, then generation, workspace analysis, tests and coverage gates, and the docs build. Exercise the normal generated entry points.

</test-strategy>

<architecture>

## Architecture and trade-offs

Use a shared wire shape across adapters and clients. Keep the current additive error envelope. Luthor supplies typed path segments and open codes directly. REST owns conversion errors that occur before the DTO reaches Luthor. The shared OpenAPI component describes the contract at its current level of detail.

</architecture>

<risks>

## Risks and assumptions

- Retaining the flattened message alongside the ordered issue list can grow frames. Use the existing byte-based WebSocket fallback from [ERR-001 #20](https://github.com/ishafiul/dart_orpc/issues/20) and verify both retry steps.
- REST aliases can drift from DTO names. Verify generated aliases using the public JSON key, and keep whole-body failures distinct.
- Output diagnostics can leak if copied into the public message, details, or a frame. Verify wire redaction and server hook delivery together on every transport.
- New Luthor codes can appear over time. Treat codes as open strings and preserve human-readable messages.

</risks>
