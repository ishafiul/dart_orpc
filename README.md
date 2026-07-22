# dart_orpc

Contract-first Dart: define your API once, get **RPC**, **REST**, **OpenAPI**, and a **typed Dart client** from the same annotations and DTOs. RPC is the source of truth; REST and docs are generated views of that contract.

## Why use it

- One module graph drives procedures, REST routes, OpenAPI schemas, and client stubs.
- Strongly typed inputs/outputs end-to-end (with Luthor-backed validation where configured).
- **Scalar** API reference UI out of the box (`/docs`), wired to live OpenAPI (`/openapi.json`).
- Pure Dart `dart:io` HTTP server adapter—no framework lock-in for the transport shape.

## What this repo contains

Melos workspace packages include:

- `packages/dart_orpc` — public runtime facade
- `packages/dart_orpc_annotations` — `@Module`, `@Controller`, `@RpcMethod`, `@RpcInput`, REST `RestMapping`, etc.
- `packages/dart_orpc_core` — envelopes, errors, registries
- `packages/dart_orpc_http` — `POST /rpc`, REST dispatch, static files, health/metrics hooks
- `packages/dart_orpc_openapi` — OpenAPI document + Scalar HTML helper
- `packages/dart_orpc_client` — `RpcTransport`, `HttpRpcTransport`
- `packages/dart_orpc_generator` — `build_runner` / `source_gen` codegen
- `packages/dart_orpc_cli` — `serve` and `watch` for apps
- `apps/basic_app` — todo + analysis example server (acceptance target)
- `apps/client_app` — tiny CLI that calls the generated `AppClient` against a running server

## Quick taste: controller + REST + RPC

```dart
@Controller('todo')
final class TodoController {
  TodoController(this.todoService);
  final TodoService todoService;

  @RpcMethod(
    name: 'getById',
    path: RestMapping.get('/todos/:id'),
    description: 'Get a single todo by id.',
    tags: ['todo'],
  )
  Future<TodoResponseDto> getById(RpcContext _, @RpcInput() GetTodoDto input) {
    return todoService.getById(input.id);
  }
}
```

Same procedure is reachable as **`todo.getById`** over `POST /rpc` and as **`GET /todos/:id`** over REST.

## Module and HTTP app

```dart
@Module(imports: [TodoModule, TodoAnalysisModule])
final class AppModule {
  const AppModule();
}
```

```dart
final app = const AppModule().buildRpcApp(
  openApi: const OpenApiDocumentOptions(
    title: 'Basic App API',
    description: 'Example todo API built with dart_orpc.',
  ),
  docs: const RpcHttpDocsOptions(
    title: 'Basic App Docs',
    basicAuth: RpcHttpBasicAuth(
      username: 'admin',
      password: 'secret',
      realm: 'Basic App Docs',
    ),
  ),
);
final server = await app.listen(3000);
```

See `apps/basic_app/bin/server.dart` for CORS, static assets, health, and metrics.

## Generated client

After codegen, your root module exposes `createClient`:

```dart
import 'package:basic_app/basic_app.dart';
import 'package:dart_orpc/dart_orpc.dart';

Future<void> main() async {
  final transport = HttpRpcTransport(baseUrl: 'http://127.0.0.1:3000');
  final client = const AppModule().createClient(transport: transport);

  final list = await client.todo.list();
  final one = await client.todo.getById(GetTodoDto(id: 1));

  transport.close();
}
```

Full flow (RPC + analysis call + error handling) lives in `apps/client_app/bin/client.dart`.

### RPC HTTP interceptors

`HttpRpcTransport` accepts transport-independent interceptors for authentication,
logging, retries, caching, and request or response transformation. Interceptors
run in list order for requests and reverse order for responses.

```dart
final class AuthInterceptor implements RpcInterceptorCore {
  const AuthInterceptor(this.token);

  final String token;

  @override
  Future<HttpRpcResponse> intercept(
    HttpRpcRequest request,
    HttpRpcHandler next,
  ) {
    return next.next(
      request.copyWith(
        headers: {
          ...request.headers,
          'authorization': 'Bearer $token',
        },
      ),
    );
  }
}

final transport = HttpRpcTransport(
  baseUrl: 'https://api.example.com',
  interceptors: [AuthInterceptor(token)],
);
```

An interceptor can inspect or replace the response after `next.next`, recover
from errors with `try`/`catch`, return a response without sending a request, or
implement a bounded retry by calling the same downstream handler again.

```dart
final class LoggingInterceptor extends RpcInterceptor {
  @override
  Future<HttpRpcRequest> onRequest(HttpRpcRequest request) async {
    print('RPC ${request.rpcRequest.method} started');
    return request;
  }

  @override
  Future<HttpRpcResponse> onResponse(HttpRpcResponse response) async {
    print('RPC completed with HTTP ${response.statusCode}');
    return response;
  }

  @override
  Future<HttpRpcResponse> onError(
    Object error,
    StackTrace stackTrace,
    HttpRpcRequest request,
  ) async {
    print('RPC ${request.rpcRequest.method} failed: $error');
    Error.throwWithStackTrace(error, stackTrace);
  }
}

final class RetryInterceptor implements RpcInterceptorCore {
  const RetryInterceptor({this.maxAttempts = 3});

  final int maxAttempts;

  @override
  Future<HttpRpcResponse> intercept(
    HttpRpcRequest request,
    HttpRpcHandler next,
  ) async {
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await next.next(request);
      } catch (_) {
        if (attempt == maxAttempts) rethrow;
      }
    }
    throw StateError('Retry attempts exhausted');
  }
}
```

The same `try`/`catch` pattern can return a synthetic `HttpRpcResponse` to
recover from a failure, while returning one before `next.next` implements a
cache or other short-circuit behavior.

## Scalar docs and OpenAPI JSON

With `basic_app` running (default port **3000**):

| What | URL |
|------|-----|
| **Scalar** (interactive API reference) | [http://127.0.0.1:3000/docs](http://127.0.0.1:3000/docs) |
| **OpenAPI document** (JSON) | [http://127.0.0.1:3000/openapi.json](http://127.0.0.1:3000/openapi.json) |
| **RPC endpoint** | `POST http://127.0.0.1:3000/rpc` |

The sample server protects **`/docs`** (and the OpenAPI URL the UI loads) with HTTP Basic Auth: username **`admin`**, password **`secret`**. Your browser will prompt once; `curl` needs `-u admin:secret`.

**There is no checked-in `openapi.json` file** in the repo. The spec is **built in memory** from generated procedure metadata and served at **`/openapi.json`** while the server runs. Defaults for paths come from `RpcHttpDocsOptions` (`openApiPath`: `/openapi.json`, `docsPath`: `/docs`).

## Workspace commands

```sh
dart pub get
dart run melos run analyze
dart run melos test
dart run melos run format
dart run melos run dev:basic-app
dart run melos run serve:basic-app
dart run melos run run:client-app
```

CLI:

```sh
dart run dart_orpc_cli:dart_orpc serve --project apps/basic_app
dart run dart_orpc_cli:dart_orpc watch --project apps/basic_app
```

Global install from this repo:

```sh
dart pub global activate --source path packages/dart_orpc_cli
cd /path/to/dart_orpc_app
dart_orpc serve
dart_orpc watch
```

`serve` and `watch` require a valid `dart_orpc` app. `watch` needs `build_runner` and `dart_orpc_generator` in the target app.

## Source of truth

For product direction and architecture rules:

- `AGENTS.md`
- `dart_rpc_framework_prd.md`
