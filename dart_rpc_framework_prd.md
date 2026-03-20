# PRD --- Dart RPC Framework (oRPC-style)

## 1. Overview

### Product Name

**dart_orpc** *(working name)*

### Problem

The Dart ecosystem currently lacks a modern **contract-first RPC
framework** that provides:

-   Type-safe RPC communication
-   REST API exposure
-   Automatic OpenAPI / Swagger documentation
-   NestJS-like architecture (controllers, modules, services)
-   Schema-driven validation
-   Dependency injection
-   Generated typed client

Developers today must combine multiple tools manually.

### Goal

Create a Dart backend framework that provides:

-   RPC server
-   Optional REST API
-   OpenAPI generation
-   DTO validation
-   Dependency injection
-   Typed RPC client generation

All generated from **one source of truth**.

------------------------------------------------------------------------

# 2. Product Vision

The framework allows defining an API **once** and automatically
generating:

1.  RPC endpoint
2.  REST endpoint
3.  OpenAPI documentation
4.  Dart client

Example developer code:

``` dart
@Controller('user')
class UserController {
  UserController(this.userService);

  final UserService userService;

  @RpcMethod(
    name: 'getById',
    rest: RestMapping.get('/users/:id'),
  )
  Future<UserResponseDto> getById(
    RpcContext ctx,
    @RpcInput() GetUserDto input,
  ) async {
    return userService.getById(input.id);
  }
}
```

Generated outputs:

RPC

    POST /rpc
    method: user.getById

REST

    GET /users/:id

Client

``` dart
final user = await client.user.getById(GetUserDto(id: "123"));
```

Swagger

    GET /docs

------------------------------------------------------------------------

# 3. Key Principles

### Contract-First Architecture

DTO schemas define API contracts.

### Single Source of Truth

Controller definitions power:

-   RPC routing
-   REST routing
-   OpenAPI generation
-   Client generation

### NestJS-Like Architecture

Enforce structure:

    module
    controller
    service
    dto
    provider

### Schema-Driven Validation

All DTOs are automatically validated.

### Generated Client

Developers never manually write HTTP/RPC calls.

### Strong Typing

Type safety across server and client.

------------------------------------------------------------------------

# 4. Target Users

### Primary Users

Dart backend developers.

### Secondary Users

Flutter developers needing type-safe APIs.

### Example Use Cases

-   Flutter + Dart backend apps
-   Internal microservices
-   Full-stack Dart systems
-   Contract-driven APIs

------------------------------------------------------------------------

# 5. Technology Stack

  Layer                  Technology
  ---------------------- ---------------------------
  HTTP Server            dart:io HTTP server
  Schema Validation      luthor
  DTO Models             freezed
  Schema Generation      luthor_generator
  Code Generation        build_runner + source_gen
  Dependency Injection   compile-time DI
  HTTP Client            dio

------------------------------------------------------------------------

# 6. Core Architecture

The framework is composed of several packages:

    framework-core
    framework-annotations
    framework-generator
    framework-http-adapter
    framework-openapi
    framework-client
    framework-di
    framework-luthor

Each package has a focused responsibility.

------------------------------------------------------------------------

# 7. Server Architecture

## Modules

Modules group controllers and providers.

Example:

``` dart
@Module(
  controllers: [UserController],
  providers: [UserService],
)
class UserModule {}
```

Responsibilities:

-   define dependency graph
-   register controllers
-   register services/providers

------------------------------------------------------------------------

# Controllers

Controllers expose procedures.

Example:

``` dart
@Controller('user')
class UserController {
  UserController(this.userService);

  final UserService userService;

  @RpcMethod(
    name: 'getById',
    rest: RestMapping.get('/users/:id'),
  )
  Future<UserResponseDto> getById(
    RpcContext ctx,
    @RpcInput() GetUserDto input,
  ) async {
    return userService.getById(input.id);
  }
}
```

Responsibilities:

-   accept validated DTOs
-   call services
-   return DTOs

Restrictions:

-   no database logic
-   no business logic
-   no manual JSON parsing

------------------------------------------------------------------------

# Services

Services contain business logic.

Example:

``` dart
@Injectable()
class UserService {
  Future<UserResponseDto> getById(String id) async {
    final user = await repository.findById(id);
    return UserResponseDto.fromEntity(user);
  }
}
```

------------------------------------------------------------------------

# DTOs

DTOs represent API contracts.

Example:

``` dart
@freezed
class GetUserDto with _$GetUserDto {
  const factory GetUserDto({
    required String id,
  }) = _GetUserDto;
}
```

Validated using **Luthor schemas**.

------------------------------------------------------------------------

# 8. RPC System

RPC endpoint:

    POST /rpc

Request:

``` json
{
  "method": "user.getById",
  "input": {
    "id": "123"
  }
}
```

Response:

``` json
{
  "data": {
    "id": "123",
    "name": "John"
  }
}
```

Error:

``` json
{
  "error": {
    "code": "NOT_FOUND",
    "message": "User not found"
  }
}
```

------------------------------------------------------------------------

# 9. REST API

Controllers can optionally expose REST endpoints.

Example:

``` dart
@RpcMethod(
  name: 'getById',
  rest: RestMapping.get('/users/:id'),
)
```

This produces:

    GET /users/:id

Parameter mapping annotations:

    @PathParam
    @QueryParam
    @Body

------------------------------------------------------------------------

# 10. OpenAPI Generation

Framework automatically generates:

    GET /openapi.json

and

    GET /docs

Swagger UI.

Generated from:

-   DTO schemas
-   controller metadata
-   REST mapping metadata

------------------------------------------------------------------------

# 11. Dependency Injection

The framework supports **constructor injection**.

Example:

``` dart
class UserController {
  UserController(this.userService);

  final UserService userService;
}
```

The container must:

-   resolve providers
-   build dependency graph
-   instantiate controllers

Prefer **compile-time DI**.

------------------------------------------------------------------------

# 12. Client Generation

Goal: generate a typed Dart client.

Example usage:

``` dart
final client = AppClient(
  transport: DioRpcTransport(baseUrl: "https://api.app.com"),
);

final user = await client.user.getById(
  GetUserDto(id: "123"),
);
```

------------------------------------------------------------------------

# Client Architecture

## Transport Layer

``` dart
abstract class RpcTransport {
  Future<Object?> send(RpcRequest request);
}
```

Default transport:

    DioRpcTransport

------------------------------------------------------------------------

# Request Envelope

``` dart
class RpcRequest {
  String method;
  Object? input;
}
```

------------------------------------------------------------------------

# Generated Client

Example:

``` dart
class UserClient {
  UserClient(this._transport);

  final RpcTransport _transport;

  Future<UserResponseDto> getById(GetUserDto input) async {
    final raw = await _transport.send(
      RpcRequest(
        method: 'user.getById',
        input: input.toJson(),
      ),
    );

    return UserResponseDto.fromJson(raw);
  }
}
```

------------------------------------------------------------------------

# Root Client

``` dart
class AppClient {
  AppClient({
    required RpcTransport transport,
  }) : user = UserClient(transport);

  final UserClient user;
}
```

------------------------------------------------------------------------

# 13. Code Generation

Use:

    build_runner
    source_gen

Generator responsibilities:

-   scan annotations
-   generate procedure registry
-   generate REST routes
-   generate OpenAPI spec
-   generate client

Command:

    dart run build_runner build

------------------------------------------------------------------------

# 14. Middleware System

Future feature.

Types:

    auth guards
    logging
    rate limiting
    interceptors

Example:

``` dart
@UseGuard(AuthGuard)
```

------------------------------------------------------------------------

# 15. Error System

Standard framework errors:

    BAD_REQUEST
    UNAUTHORIZED
    FORBIDDEN
    NOT_FOUND
    CONFLICT
    INTERNAL_ERROR

Mapped to:

-   RPC error envelope
-   HTTP status codes
-   OpenAPI responses

------------------------------------------------------------------------

# 16. Project Structure

Recommended structure:

    lib/
      modules/
        user/
          dto/
          controller/
          service/
          repository/
          user.module.dart

------------------------------------------------------------------------

# 17. MVP Scope

Version 0.1 supports:

-   modules
-   controllers
-   services
-   DTO validation
-   RPC endpoint
-   REST endpoint mapping
-   OpenAPI generation
-   generated Dart client

------------------------------------------------------------------------

# 18. Future Features

### v0.2

-   guards
-   interceptors
-   auth system
-   pagination helpers

### v0.3

-   file uploads
-   streaming RPC
-   WebSocket transport

### v1.0

-   GraphQL adapter
-   multi-language client generation

------------------------------------------------------------------------

# 19. Success Criteria

Framework enables:

1.  Define controller once\
2.  Automatically expose RPC + REST\
3.  Automatically generate OpenAPI\
4.  Automatically generate Dart client

------------------------------------------------------------------------

# 20. Example Developer Experience

Server:

``` dart
final app = RpcApp(
  modules: [
    UserModule(),
  ],
);

await app.listen(3000);
```

Client:

``` dart
final client = AppClient(
  transport: DioRpcTransport(baseUrl: "http://localhost:3000"),
);

final user = await client.user.getById(
  GetUserDto(id: "1"),
);
```

------------------------------------------------------------------------

# Final Notes

The framework prioritizes:

-   developer experience
-   type safety
-   clean architecture
-   minimal boilerplate

The system is **RPC-first**, with REST and OpenAPI generated from the
same contracts.
