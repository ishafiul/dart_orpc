## 0.1.0-dev.11

> Note: This release has breaking changes.

 - **BREAKING** **FEAT**(dart_orpc_http): Faster request hot path and byte JSON by default (#121).

## 0.1.0-dev.10

 - **FIX**(dart_orpc_generator): Share one output encoder across RPC and REST and drop dead registry code (#120).

## 0.1.0-dev.9

 - Update a dependency to the latest release.

## 0.1.0-dev.8

> Note: This release has breaking changes.

 - **FEAT**(http): Attach structured issues to REST decoding failures (#104) (#111).
 - **FEAT**(generator): Support luthor 1.1 unknown-key modes in DTO metadata and OpenAPI (#90) (#94).
 - **FEAT**(generator): Emit DTO schema metadata registries (#76) (#87).
 - **FEAT**(generator): Extract DTO schema metadata at build time (#75) (#86).
 - **BREAKING** **FEAT**(openapi): Render OpenAPI schemas from DTO metadata and drop luthor (#77) (#92).
 - **BREAKING** **BUILD**(deps): Switch to luthor 1.1 and latest dependencies (#71) (#93).

## 0.1.0-dev.7

 - **REFACTOR**(generator): Extract shared graph and contract primitives.

## Unreleased

- Share DTO field discovery between module and field-reference generators;
  reuse parsed REST route patterns for binding, collision checks, and metadata.
- Extract internal graph algorithms; use iterative DFS for module traversal and
  cycle diagnostics, and Kahn ordering for providers while preserving declaration
  order, optional injection, and disposal behavior.

## 0.1.0-dev.6

 - **FEAT**(generator): Support provider bindings and custom REST status and headers.

## 0.1.0-dev.5

 - **FEAT**: Add root-scoped global modules (#14).
 - **FEAT**: Add contract-driven headers and bearer security (#13).

## 0.1.0-dev.4

 - **FEAT**: support scalar and void outputs with structured benchmarks (#12).

## 0.1.0-dev.3

 - **FEAT**(generator): Expose context bindings in generated app builders.

## 0.1.0-dev.2

 - **REFACTOR**(generator): Improve architecture and regression coverage (#1).
 - **REFACTOR**: replace manual beforeInvoke guards with a declarative guards property in RpcProcedure and RestRoute definitions.
 - **REFACTOR**(generator): Split RPC module generator into focused parts.
 - **FEAT**: Streaming Code Generation (#10).
 - **FEAT**(di): share module containers across transports (#4).
 - **FEAT**(generator): Update RPC app generation to include additional options for static assets, health checks, and metrics.
 - **FEAT**(todos): Add TodoPermissionGuard and RequirePermissions for enhanced access control.
 - **FEAT**(todos): Implement TodoRouteLoggerGuard for logging RPC and REST requests.
 - **FEAT**(middleware): RPC app with middleware support.
 - **FEAT**(openapi): Enhance OpenAPI document generation with customizable options and basic auth for documentation access.
 - **FEAT**(generator): Enhance module export functionality and update basic app structure.
 - **FEAT**: Add standalone .orpc generation and todo-based basic app.
 - **FEAT**(generator): Compose imported module outputs.
 - **FEAT**: Add OpenAPI docs and DTO-based REST input binding.
 - **FEAT**: Add generated REST route support.

