# dart_orpc

Contract-first Dart: define your API once, get **RPC**, **REST/SSE**, **OpenAPI**, and a **typed Dart client** from the same annotations and DTOs. RPC is the source of truth; HTTP, WebSocket, REST/SSE, and docs are transport views of that contract.

## Why use it

- One module graph drives procedures, REST routes, OpenAPI schemas, and client stubs.
- Strongly typed inputs/outputs end-to-end (with Luthor-backed validation where configured).
- Unary RPC over HTTP or WebSocket and typed server streams over WebSocket or explicit REST/SSE.
- **Scalar** API reference UI out of the box (`/docs`), wired to live OpenAPI (`/openapi.json`).
- One `dart:io` server and port for HTTP RPC, REST, SSE, and opt-in WebSocket upgrades.

## What this repo contains

Melos workspace packages include:

- `packages/dart_orpc` — public runtime facade
- `packages/dart_orpc_annotations` — `@Module`, `@Controller`, `@RpcMethod`, `@RpcInput`, REST `RestMapping`, etc.
- `packages/dart_orpc_core` — envelopes, errors, registries
- `packages/dart_orpc_http` — `POST /rpc`, REST/SSE dispatch, streaming bodies, lifecycle, static files, health/metrics hooks
- `packages/dart_orpc_websocket` — `dart-orpc.v1` protocol, server upgrade handler, and VM client transport
- `packages/dart_orpc_openapi` — OpenAPI document + Scalar HTML helper
- `packages/dart_orpc_client` — unary/streaming transport capabilities and `HttpRpcTransport`
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

## Server streaming with WebSocket and SSE

A typed `Stream<T>` is a server-streaming RPC procedure. Without a REST mapping it is WebSocket-only; `RestMapping.sse` explicitly adds a GET SSE view.

```dart
@RpcMethod(
  name: 'watch',
  path: RestMapping.sse('/todos/events'),
)
Stream<TodoResponseDto> watch(RpcContext context) async* {
  final snapshot = await todoService.list();
  for (final todo in snapshot.items) {
    context.cancellation.throwIfCancelled();
    yield todo;
  }
}
```

The generator derives all of these from that one declaration:

- WebSocket method `todo.watch` using subprotocol `dart-orpc.v1`
- `GET /todos/events` with `text/event-stream`
- `Stream<TodoResponseDto> watch()` on the generated Dart client
- OpenAPI SSE metadata including the event schema and terminal event names

The basic app also exposes the long-lived `todo.watchLive` WebSocket method and
`GET /todos/live-events` SSE route. Its generated
`Stream<TodoChangeResponseDto>` reports typed `created`, `updated`, and
`deleted` events after successful mutations.

Only unary and server-to-client streams are supported. Reconnection, replay, client streaming, bidirectional streaming, and browser clients are intentionally deferred.

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
  webSocket: const RpcWebSocketServerOptions(),
);
final server = await app.listen(3000);

// Stop accepting work, drain active calls, then cancel at the deadline.
await server.close(gracePeriod: const Duration(seconds: 30));
```

See `apps/basic_app/bin/server.dart` for CORS, static assets, health, and metrics.

## Generated client

After codegen, your root module exposes `createClient`:

```dart
import 'package:basic_app/basic_app.dart';
import 'package:dart_orpc/dart_orpc.dart';

Future<void> main() async {
  final http = HttpRpcTransport(baseUrl: 'http://127.0.0.1:3000');
  final webSocket = await WebSocketRpcTransport.connect(
    Uri.parse('ws://127.0.0.1:3000/rpc/ws'),
  );
  final client = const AppModule().createClient(
    transports: RpcClientTransports.split(
      unary: http,
      streaming: webSocket,
    ),
  );

  final list = await client.todo.list();
  final one = await client.todo.getById(GetTodoDto(id: 1));
  await for (final todo in client.todo.watch()) {
    print(todo);
  }

  http.close();
  await webSocket.close();
}
```

Use `RpcClientTransports.duplex(webSocket)` to send both unary calls and streams over one socket. A generated method throws `RpcClientConfigurationException` when its required capability was not configured. The full split-transport flow lives in `apps/client_app/bin/client.dart`.

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
| **WebSocket RPC** | `ws://127.0.0.1:3000/rpc/ws` (`dart-orpc.v1`) |
| **Todo SSE example** | `GET http://127.0.0.1:3000/todos/events` |

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
