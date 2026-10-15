# dart_orpc_http

Pure-Dart HTTP runtime for `dart_orpc`. It serves HTTP RPC, generated REST
routes, SSE streams, health endpoints, static assets, and API documentation
from the shared generated procedure registry.

Most applications should use the
[`dart_orpc`](https://pub.dev/packages/dart_orpc) facade package.

## HTTP performance options

Generated `buildRpcApp()` helpers and `RpcHttpApp` accept:

```dart
final app = AppModule().buildRpcApp(
  encodeJsonToBytes: true,
  maxConcurrentRequests: 256,
  requestBodyIdleTimeout: const Duration(seconds: 10),
);
```

`encodeJsonToBytes` defaults to `false` for middleware compatibility. Enable it
to encode successful RPC/REST JSON directly to UTF-8 bytes; middleware must
accept both `String` and `List<int>` buffered bodies. `RpcJsonBytes` REST outputs
keep their existing byte fast path regardless of this option.

`maxConcurrentRequests` defaults to unlimited. It counts requests from body
reading through response completion, including SSE streams and upgrades.
Excess requests receive HTTP 503 with `UNAVAILABLE` before middleware
runs. Choose a limit based on application memory and downstream capacity.

`requestBodyIdleTimeout` defaults to disabled. It limits the wait for the next
body chunk, rather than total request duration. Idle bodies receive HTTP 408
with `REQUEST_TIMEOUT`; timed-out and oversized uploads close their connection.

SSE flushes every chunk by default. Set `sseFlushEachChunk: false` to use HTTP
output buffering for higher throughput when immediate delivery is unnecessary.
`RpcHttpResponse.streaming()` and `RpcStreamingHttpBody` expose the same policy
as `flushEachChunk`; response copies and CORS preserve it.

OpenAPI is serialized once when constructing the handler. Treat its document
as a startup snapshot; rebuild the handler to publish a changed document.

Static files use buffered streaming with `Content-Length`, `ETag`, and
`Last-Modified`. Conditional GET/HEAD requests can return 304 without reading
file contents. `RpcHttpStaticOptions.cacheControl` defaults to `no-cache`
(browser storage with revalidation); set an explicit policy for versioned
assets. Filesystem containment and symlink checks still run on each request.
Static responses returned directly from the handler now have streaming content;
consume `RpcStreamingHttpBody.chunks` instead of casting `body` to `List<int>`.

## Server policies and lifecycle hooks

```dart
final app = const AppModule().buildRpcApp(
  metrics: const RpcHttpMetricsOptions(),
  health: RpcHttpHealthOptions(
    livenessPath: '/live',
    readinessPath: '/ready',
    readinessCheck: () => database.isReady,
    checkTimeout: const Duration(seconds: 2),
  ),
  serverOptions: RpcHttpServerOptions(
    cors: const CorsOptions(
      allowCredentials: true,
      allowedOrigins: ['https://app.example.com'],
      exposeHeaders: ['X-Request-ID'],
    ),
    maxHeaderBytes: 16 * 1024,
    bodyTimeout: const Duration(seconds: 20),
    handlerTimeout: const Duration(seconds: 10),
    compress: true,
    rateLimit: const RpcHttpRateLimitOptions(maxRequests: 120),
    onError: (event) => logger.error(event.error, event.stackTrace),
    onComplete: (event) => logger.info(
      '${event.request.requestId} ${event.route} ${event.statusCode}',
    ),
  ),
);
```

Server policies run before controller dispatch. `serverOptions.cors` finalizes
all responses, including 408/413/429/431/503 and middleware failures. Use this
option when CORS must cover adapter errors; `createCorsMiddleware` remains
available for handler-only pipelines. Credentialed CORS now requires an explicit
origin, `allowedOrigins`, or `allowOriginPredicate`; wildcard origin reflection
has been removed. Preflight validates methods and requested headers. Origin
responses carry `Vary: Origin` while preserving existing cache variation.

Each HTTP request receives `X-Request-ID`, also available through
`context.binding(rpcRequestIdKey)`. Supplied IDs are ignored unless
`trustRequestId: true`; only bounded, header-safe IDs are accepted. A custom
`requestIdFactory` can provide application IDs. Proxy address headers are never
trusted implicitly.

Error observers receive the original exception and stack at most once per
request; explicit error responses without an exception are visible to completion
observers. Completion observers run once after response completion or abort,
including streams. Hooks are synchronous; send events to an application-owned
queue for asynchronous exporters. Hook failures are isolated and counted.
Public error responses keep internal exception details private. Typed transport
errors include `REQUEST_TIMEOUT`, `PAYLOAD_TOO_LARGE`, `HEADERS_TOO_LARGE`,
`DEADLINE_EXCEEDED`, and `UNAVAILABLE`; concurrency rejection now uses
`UNAVAILABLE`/503, while rate limiting uses `RESOURCE_EXHAUSTED`/429.

`bodyTimeout` bounds total body reading; `requestBodyIdleTimeout` bounds the
wait between chunks. `handlerTimeout` bounds construction of the response,
including context, guards and middleware. It does not limit a returned stream's
lifetime. Cancellation is cooperative: handlers must observe
`context.cancellation`, and downstream operations need their own cancellation
support. Disconnects detected by HTTP I/O cancel upstream streams. SSE
heartbeats provide detection even while no application events are flowing;
disabling heartbeats delays detection until another write. No adapter can
forcibly stop an arbitrary Dart Future.

Rate limiting uses a bounded process-local fixed-window store, keyed by direct
peer address unless a `key` function is supplied. `maxKeys` bounds identities;
new identities are rejected while full. Multiple processes need coordinated
application/proxy limits when a shared quota is required. Rejections include
`Retry-After`. Admission limits and rate limits are independent.

The optional metrics endpoint reports active requests/streams, errors,
rejections, body bytes, and cumulative duration histograms. Labels use registered
route templates and one `/unmatched` label rather than arbitrary URLs. Body byte
counts exclude HTTP framing. Exporters and logging packages remain app choices.
Liveness is independent of dependency readiness; readiness also observes
server draining. Probe checks have a bounded deadline.

## Request and response contracts

`RpcHttpRequest.bodyBytes` exposes buffered raw bytes. `body` decodes UTF-8 on
demand, so binary handlers need not decode text. Body limits still apply before
middleware. `queryParametersAll` retains repeated values; `uri`, `remoteAddress`
and parsed `cookies` expose HTTP request metadata. Use `request.copyWith()` in
middleware to preserve cancellation, correlation IDs, raw bytes and observers.

Declared REST response metadata is shared with generated OpenAPI:

```dart
@RpcMethod(path: RestMapping.post(
  '/items',
  statusCode: 201,
  headers: {'X-API-Version': '1'},
))
Future<ItemDto> create(RpcContext context, @RpcInput() CreateItemDto input) async {
  context.binding(rpcHttpResponseKey)?.cookies.add(
    Cookie('session', 'value')..httpOnly = true,
  );
  return service.create(input);
}
```

The optional `RpcHttpResponseControl` binding supports request-specific REST
status, headers and cookies without changing a procedure's DTO return type.
Use a nullable binding lookup for procedures also called through WebSocket.
HTTP RPC preserves its success status and `{data: ...}` envelope; cookies and
headers can still be applied. Declare REST statuses in `RestMapping` so docs
match runtime behavior. `RpcHttpResponse` can also be returned directly from
custom HTTP route handlers; redirects, downloads, repeated `headerValues`, and
`cookies` are supported. CORS and response copies preserve repeated headers and
streaming policies.

GET REST routes also handle HEAD unless an explicit HEAD route exists. HEAD
sends headers without a body. Static files support single byte ranges,
`Content-Range`, 206/416, and date-based `If-Range`; multiple ranges are ignored
and receive the full representation. Weak ETags are not accepted for If-Range.
Optional gzip honors encoding quality values and preserves `Vary` headers.
SSE and partial range responses are excluded from compression.
