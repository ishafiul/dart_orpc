# Change Log

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

## 2026-07-27

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`dart_orpc_generator` - `v0.1.0-dev.4`](#dart_orpc_generator---v010-dev4)
 - [`dart_orpc_http` - `v0.1.0-dev.4`](#dart_orpc_http---v010-dev4)
 - [`dart_orpc_openapi` - `v0.1.0-dev.4`](#dart_orpc_openapi---v010-dev4)
 - [`dart_orpc` - `v0.1.0-dev.4`](#dart_orpc---v010-dev4)
 - [`dart_orpc_websocket` - `v0.1.0-dev.4`](#dart_orpc_websocket---v010-dev4)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `dart_orpc` - `v0.1.0-dev.4`
 - `dart_orpc_websocket` - `v0.1.0-dev.4`

---

#### `dart_orpc_generator` - `v0.1.0-dev.4`

 - **FEAT**: support scalar and void outputs with structured benchmarks (#12).

#### `dart_orpc_http` - `v0.1.0-dev.4`

 - **FEAT**: support scalar and void outputs with structured benchmarks (#12).

#### `dart_orpc_openapi` - `v0.1.0-dev.4`

 - **FEAT**: support scalar and void outputs with structured benchmarks (#12).


## 2026-07-25

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`dart_orpc_core` - `v0.1.0-dev.3`](#dart_orpc_core---v010-dev3)
 - [`dart_orpc_generator` - `v0.1.0-dev.3`](#dart_orpc_generator---v010-dev3)
 - [`dart_orpc_http` - `v0.1.0-dev.3`](#dart_orpc_http---v010-dev3)
 - [`dart_orpc_websocket` - `v0.1.0-dev.3`](#dart_orpc_websocket---v010-dev3)
 - [`dart_orpc` - `v0.1.0-dev.3`](#dart_orpc---v010-dev3)
 - [`dart_orpc_client` - `v0.1.0-dev.3`](#dart_orpc_client---v010-dev3)
 - [`dart_orpc_luthor` - `v0.1.0-dev.3`](#dart_orpc_luthor---v010-dev3)
 - [`dart_orpc_openapi` - `v0.1.0-dev.3`](#dart_orpc_openapi---v010-dev3)

Packages with dependency updates only:

> Packages listed below depend on other packages in this workspace that have had changes. Their versions have been incremented to bump the minimum dependency versions of the packages they depend upon in this project.

 - `dart_orpc` - `v0.1.0-dev.3`
 - `dart_orpc_client` - `v0.1.0-dev.3`
 - `dart_orpc_luthor` - `v0.1.0-dev.3`
 - `dart_orpc_openapi` - `v0.1.0-dev.3`

---

#### `dart_orpc_core` - `v0.1.0-dev.3`

 - **FEAT**(core): Add typed RPC context bindings.

#### `dart_orpc_generator` - `v0.1.0-dev.3`

 - **FEAT**(generator): Expose context bindings in generated app builders.

#### `dart_orpc_http` - `v0.1.0-dev.3`

 - **FEAT**(http): Add reusable environment reader.
 - **FEAT**(http): Propagate default bindings across request transports.

#### `dart_orpc_websocket` - `v0.1.0-dev.3`

 - **FEAT**(http): Propagate default bindings across request transports.


## 2026-07-25

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`dart_orpc_cli` - `v0.1.0-dev.3`](#dart_orpc_cli---v010-dev3)

---

#### `dart_orpc_cli` - `v0.1.0-dev.3`

 - **FEAT**: Add create command for generating minimal hello-world dart_orpc app.


## 2026-07-25

### Changes

---

Packages with breaking changes:

 - There are no breaking changes in this release.

Packages with other changes:

 - [`dart_orpc` - `v0.1.0-dev.2`](#dart_orpc---v010-dev2)
 - [`dart_orpc_annotations` - `v0.1.0-dev.2`](#dart_orpc_annotations---v010-dev2)
 - [`dart_orpc_client` - `v0.1.0-dev.2`](#dart_orpc_client---v010-dev2)
 - [`dart_orpc_core` - `v0.1.0-dev.2`](#dart_orpc_core---v010-dev2)
 - [`dart_orpc_generator` - `v0.1.0-dev.2`](#dart_orpc_generator---v010-dev2)
 - [`dart_orpc_http` - `v0.1.0-dev.2`](#dart_orpc_http---v010-dev2)
 - [`dart_orpc_luthor` - `v0.1.0-dev.2`](#dart_orpc_luthor---v010-dev2)
 - [`dart_orpc_openapi` - `v0.1.0-dev.2`](#dart_orpc_openapi---v010-dev2)
 - [`dart_orpc_websocket` - `v0.1.0-dev.2`](#dart_orpc_websocket---v010-dev2)

---

#### `dart_orpc` - `v0.1.0-dev.2`

 - **FEAT**: Websocket Transport (#9).
 - **FEAT**: Streaming Core (#6).
 - **FEAT**(todos): Add TodoPermissionGuard and RequirePermissions for enhanced access control.
 - **FEAT**(todos): Implement TodoRouteLoggerGuard for logging RPC and REST requests.
 - **FEAT**(middleware): RPC app with middleware support.
 - **FEAT**(openapi): Enhance OpenAPI document generation with customizable options and basic auth for documentation access.
 - **FEAT**(annotations): Add Module imports and exports.
 - **FEAT**: Add OpenAPI docs and DTO-based REST input binding.

#### `dart_orpc_annotations` - `v0.1.0-dev.2`

 - **FEAT**: HTTP SSE Lifecycle (#8).
 - **FEAT**(todos): Add TodoPermissionGuard and RequirePermissions for enhanced access control.
 - **FEAT**(todos): Implement TodoRouteLoggerGuard for logging RPC and REST requests.
 - **FEAT**(annotations): Add Module imports and exports.
 - **FEAT**: Add OpenAPI docs and DTO-based REST input binding.
 - **FEAT**: Add generated REST route support.

#### `dart_orpc_client` - `v0.1.0-dev.2`

 - **FEAT**: Streaming Client Transports (#7).
 - **FEAT**(client): add HTTP RPC interceptors (#3).

#### `dart_orpc_core` - `v0.1.0-dev.2`

 - **REFACTOR**: replace manual beforeInvoke guards with a declarative guards property in RpcProcedure and RestRoute definitions.
 - **FEAT**: Streaming Core (#6).
 - **FEAT**(todos): Add TodoPermissionGuard and RequirePermissions for enhanced access control.
 - **FEAT**(todos): Implement TodoRouteLoggerGuard for logging RPC and REST requests.
 - **FEAT**(todos): Introduce todos database and update todo analysis tags.
 - **FEAT**(core): Expose procedures iterable on registry.
 - **FEAT**: Add OpenAPI docs and DTO-based REST input binding.
 - **FEAT**: Add generated REST route support.

#### `dart_orpc_generator` - `v0.1.0-dev.2`

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

#### `dart_orpc_http` - `v0.1.0-dev.2`

 - **REFACTOR**(generator): Improve architecture and regression coverage (#1).
 - **REFACTOR**: replace manual beforeInvoke guards with a declarative guards property in RpcProcedure and RestRoute definitions.
 - **FIX**(http): prevent static path traversal and limit request body size.
 - **FEAT**: HTTP SSE Lifecycle (#8).
 - **FEAT**(static-assets): Implement static asset serving, health checks, and metrics endpoints in RpcHttpApp.
 - **FEAT**: add CORS middleware support and export it for use in HTTP applications.
 - **FEAT**(middleware): RPC app with middleware support.
 - **FEAT**(openapi): Enhance OpenAPI document generation with customizable options and basic auth for documentation access.
 - **FEAT**: Add OpenAPI docs and DTO-based REST input binding.
 - **FEAT**: Add generated REST route support.

#### `dart_orpc_luthor` - `v0.1.0-dev.2`

 - **FEAT**(todos): Introduce todos database and update todo analysis tags.

#### `dart_orpc_openapi` - `v0.1.0-dev.2`

 - **FEAT**: HTTP SSE Lifecycle (#8).
 - **FEAT**(openapi): Enhance OpenAPI document generation with customizable options and basic auth for documentation access.
 - **FEAT**: Add OpenAPI docs and DTO-based REST input binding.

#### `dart_orpc_websocket` - `v0.1.0-dev.2`

 - **FEAT**: Websocket Transport (#9).

