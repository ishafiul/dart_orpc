# AGENTS.md

## Mission

Build `dart_orpc`, a contract-first Dart framework that lets developers define API contracts once and generate:

- RPC endpoints
- Optional REST endpoints
- OpenAPI output
- Typed Dart clients

The framework is RPC-first. REST and OpenAPI are derived views of the same contract, not separate sources of truth.

## Primary Source Material

Read [`dart_rpc_framework_prd.md`](/Users/shafiulislam/Documents/dev/dart_orpc/dart_rpc_framework_prd.md) before making structural decisions. If implementation details conflict with the PRD, keep the PRD intent and update this file only when the product direction changes.

## Agent Memory

Use the repo-local memory store in `.agent-memory/` as the durable project context layer.

- Read `.agent-memory/project/abstract.md`, `.agent-memory/project/overview.md`, and `.agent-memory/architecture/invariants.md` before making structural decisions.
- Prefer the MCP server in `tools/agent_memory_mcp/bin/agent_memory_mcp.dart` for retrieving and updating memory from agents.
- Keep memory focused on durable project facts: decisions, invariants, milestones, gotchas, and current progress.
- Do not dump raw chat logs into memory. Compress conversations into reusable project knowledge.
- After meaningful architecture or workflow changes, update the relevant memory files or write new ones under `.agent-memory/`.

## Product Principles

- Keep one source of truth: DTO schemas, controller annotations, and module definitions drive everything else.
- Favor compile-time generation over runtime reflection or dynamic registration.
- Preserve strong typing across server, validation, transport, OpenAPI, and generated client code.
- Keep the developer experience close to NestJS/oRPC concepts, but expressed in idiomatic Dart.
- Optimize for low boilerplate and predictable generated code.

## MVP Scope

Version `0.1` should include only:

- modules
- controllers
- services/providers
- DTO validation
- `POST /rpc`
- REST route mapping from controller metadata
- OpenAPI generation
- generated Dart client

Do not expand the first working version with:

- auth systems
- guards/interceptors
- file uploads
- streaming RPC
- WebSocket transport
- GraphQL
- non-Dart client generation

Those belong after the core vertical slice works end to end.

## Recommended Workspace Shape

Use a Melos-managed multi-package workspace. Prefer `packages/` plus `apps/`.

Expose a single consumer-facing runtime package, `packages/dart_orpc`, that re-exports the stable public APIs from the internal runtime packages. Keep build-time generation in `dart_orpc_generator`.

Suggested packages:

- `packages/dart_orpc_annotations`
  Public annotations such as `@Module`, `@Controller`, `@RpcMethod`, `@RpcInput`, `@PathParam`, `@QueryParam`, and `@Body`.
- `packages/dart_orpc_core`
  Core contracts and runtime types: metadata models, `RpcContext`, request/response envelopes, framework errors, registry interfaces, and app bootstrap abstractions.
- `packages/dart_orpc_generator`
  `source_gen` / `build_runner` generators that scan annotations and emit metadata registries, route bindings, OpenAPI artifacts, and client code.
- `packages/dart_orpc_http`
  Pure-Dart HTTP adapter for request handling, `/rpc`, REST endpoint exposure, error mapping, and docs wiring.
- `packages/dart_orpc_openapi`
  OpenAPI model generation and Swagger UI integration built from shared metadata, not independent controller parsing.
- `packages/dart_orpc_client`
  Client-side transport abstractions, generated client support, and a default Dio transport.
- `packages/dart_orpc_di`
  Compile-time DI container or DI integration seam for constructor injection.
- `packages/dart_orpc_luthor`
  Validation/schema bridge for DTOs and Luthor-generated schemas.

Add `apps/basic_app` early and keep it working as the acceptance target for the framework.

## Architecture Rules

- Controllers expose procedures and orchestrate application flow only.
- Services contain business logic.
- Repositories or infrastructure concerns must stay outside controllers.
- DTOs are API contracts; treat them as immutable and serializable.
- Validation must be schema-driven and automatic.
- REST routes, OpenAPI docs, and clients must be generated from the same metadata model used for RPC routing.
- Error handling must be centralized so RPC, REST, and OpenAPI stay aligned.
- The transport abstraction must not depend on Dio directly; Dio is the default implementation, not the core contract.
- Keep `annotations` and `core` dependency-light so the rest of the workspace can build on them cleanly.
- Do not hand-write duplicate registries or route tables when generators can derive them.

## Package Dependency Direction

Maintain a clean dependency flow:

- `annotations` should depend on almost nothing.
- `core` may depend on `annotations` only if strictly necessary; prefer shared contracts over circular coupling.
- `generator` can depend on `annotations` and `core`.
- `http`, `openapi`, `client`, `di`, and `luthor` should depend on `core`.
- Apps should prefer the `dart_orpc` facade package for runtime APIs and depend on `dart_orpc_generator` only as a build-time tool.

Avoid cycles. If two packages need the same concept, move that concept into a lower-level package instead of crossing boundaries.

## Execution Order

Build the framework in this order unless there is a strong reason not to:

1. Workspace scaffolding and package layout
2. Annotations package
3. Core runtime contracts and error model
4. Generator metadata model and code generation pipeline
5. DI wiring for modules, providers, and controllers
6. HTTP adapter with `POST /rpc`
7. REST mapping from the same generated metadata
8. OpenAPI and `/docs`
9. Generated Dart client and transport layer
10. Example app and integration tests

Do not start with advanced middleware or auxiliary features before the vertical slice above is functioning.

## Coding Constraints

- Avoid `dynamic` in public APIs unless the boundary is truly untyped.
- Prefer explicit typed abstractions over ad hoc maps in core runtime code.
- Generated code should be deterministic and easy to inspect.
- Never require manual route registration for annotated controllers in normal usage.
- Avoid runtime mirrors; prefer static analysis and generation.
- Keep framework extension points explicit. Hidden conventions are acceptable only when they reduce boilerplate without obscuring control flow.

## Testing Requirements

Every major capability needs automated coverage:

- unit tests for metadata extraction and validation behavior
- unit tests for error mapping and request/response envelopes
- integration tests for `POST /rpc`
- integration tests for REST endpoint generation
- snapshot or golden-style verification for generated OpenAPI and client output where practical
- an example app proving the end-to-end developer experience from the PRD

If RPC, REST, OpenAPI, and client outputs ever diverge, treat that as a framework bug.

## Decision Heuristics For Agents

When multiple designs are possible:

- choose compile-time generation over runtime discovery
- choose shared metadata over duplicated configuration
- choose clear public APIs over clever abstractions
- choose adapter isolation over leaking transport or server specifics into core
- choose MVP completeness over breadth

## Non-Goals For Early Work

Do not turn this into:

- a generic MVC framework
- a reflection-heavy runtime container
- a REST-first framework with optional RPC
- a codebase where OpenAPI or client generation is maintained separately from server contracts

The core bet is one contract model powering multiple outputs.

## First Acceptance Slice

The first meaningful milestone should support the PRD example:

- a `UserModule`
- a `UserController`
- a `UserService`
- a validated `GetUserDto`
- `POST /rpc` calling `user.getById`
- generated `GET /users/:id`
- generated OpenAPI output
- generated Dart client calling `client.user.getById(...)`

Do not move past early architecture decisions until this slice is demonstrably working.
