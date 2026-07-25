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

