## 0.1.0-dev.3

 - **FEAT**(http): Add reusable environment reader.
 - **FEAT**(http): Propagate default bindings across request transports.

## 0.1.0-dev.2

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

