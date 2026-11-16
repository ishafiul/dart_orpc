## 0.1.0-dev.7

> Note: This release has breaking changes.

 - **FIX**(luthor): Hide output validation failures and report diagnostics (#105) (#112).
 - **FEAT**(core): Expose validation issues to clients and OpenAPI, and prove parity (#101) (#113).
 - **FEAT**(core): Add the structured validation issue model (#102) (#109).
 - **FEAT**(generator): Support luthor 1.1 unknown-key modes in DTO metadata and OpenAPI (#90) (#94).
 - **FEAT**(core): Add the DTO schema metadata model (#74) (#85).
 - **BREAKING** **BUILD**(deps): Switch to luthor 1.1 and latest dependencies (#71) (#93).

## 0.1.0-dev.6

 - **FEAT**(core): Add encodeRpcError with safe details fallback (#28) (#41).
 - **FEAT**(core): Add optional details to RpcException and RpcErrorBody (#40).

## 0.1.0-dev.5

 - **FEAT**(core): Add disposable lifecycle, json bytes optimization, and enhanced cancellation.

## 0.1.0-dev.4

 - **FEAT**: Add contract-driven headers and bearer security (#13).

## 0.1.0-dev.3

 - **FEAT**(core): Add typed RPC context bindings.

## 0.1.0-dev.2

 - **REFACTOR**: replace manual beforeInvoke guards with a declarative guards property in RpcProcedure and RestRoute definitions.
 - **FEAT**: Streaming Core (#6).
 - **FEAT**(todos): Add TodoPermissionGuard and RequirePermissions for enhanced access control.
 - **FEAT**(todos): Implement TodoRouteLoggerGuard for logging RPC and REST requests.
 - **FEAT**(todos): Introduce todos database and update todo analysis tags.
 - **FEAT**(core): Expose procedures iterable on registry.
 - **FEAT**: Add OpenAPI docs and DTO-based REST input binding.
 - **FEAT**: Add generated REST route support.

