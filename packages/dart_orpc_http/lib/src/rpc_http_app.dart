import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart_orpc_core/dart_orpc_core.dart';

import 'rpc_http_handler.dart';
import 'rpc_http_options.dart';
import 'rpc_http_metrics.dart';
import 'middleware/cors_policy.dart';

const int _defaultMaxRequestBodyBytes = 1024 * 1024;
const Duration _defaultGracePeriod = Duration(seconds: 30);

abstract interface class RpcHttpUpgradeHandler {
  bool canHandle(HttpRequest request);

  Future<void> handle(HttpRequest request, RpcContext context);

  Future<void> close({required Duration gracePeriod});
}

final class RpcHttpServer {
  RpcHttpServer._({
    required HttpServer server,
    required _RpcRequestTracker requests,
    required List<RpcHttpUpgradeHandler> upgradeHandlers,
    required Future<void> Function() closeProviders,
  }) : _server = server,
       _requests = requests,
       _upgradeHandlers = upgradeHandlers,
       _closeProviders = closeProviders;

  final HttpServer _server;
  final _RpcRequestTracker _requests;
  final List<RpcHttpUpgradeHandler> _upgradeHandlers;
  final Future<void> Function() _closeProviders;
  Future<void>? _closing;

  int get port => _server.port;
  InternetAddress get address => _server.address;

  Future<void> close({
    Duration gracePeriod = _defaultGracePeriod,
    bool force = false,
  }) {
    return _closing ??= _close(gracePeriod: gracePeriod, force: force);
  }

  Future<void> _close({
    required Duration gracePeriod,
    required bool force,
  }) async {
    _requests.stopAccepting();
    (Object, StackTrace)? failure;
    try {
      await _closeServer(gracePeriod: gracePeriod, force: force);
    } catch (error, stackTrace) {
      failure = (error, stackTrace);
    }
    try {
      await _closeProviders();
    } catch (error, stackTrace) {
      failure ??= (error, stackTrace);
    }

    final closeFailure = failure;
    if (closeFailure != null) {
      Error.throwWithStackTrace(closeFailure.$1, closeFailure.$2);
    }
  }

  Future<void> _closeServer({
    required Duration gracePeriod,
    required bool force,
  }) async {
    final serverClosing = _server.close(force: force);
    if (force) {
      _requests.cancelAll();
      await Future.wait([
        for (final handler in _upgradeHandlers)
          handler.close(gracePeriod: Duration.zero),
      ]);
      await serverClosing;
      return;
    }

    final handlerClosing = Future.wait([
      for (final handler in _upgradeHandlers)
        handler.close(gracePeriod: gracePeriod),
    ]);
    final drained = await Future.any([
      Future.wait([_requests.whenIdle, handlerClosing]).then((_) => true),
      Future<void>.delayed(gracePeriod).then((_) => false),
    ]);

    if (!drained) {
      _requests.cancelAll();
      await Future.wait([
        for (final handler in _upgradeHandlers)
          handler.close(gracePeriod: Duration.zero),
      ]);
      await _server.close(force: true);
    }
    await serverClosing;
  }
}

final class RpcHttpApp {
  RpcHttpApp({
    required this.procedures,
    RestRouteRegistry? restRoutes,
    this.openApiDocument,
    this.openApiPath = '/openapi.json',
    this.docsHtml,
    this.docsPath = '/docs',
    this.docsBasicAuth,
    this.staticAssets,
    this.health,
    this.metrics,
    this.bindings = const RpcContextBindings.empty(),
    this.contextFactory,
    this.sseHeartbeatInterval = const Duration(seconds: 15),
    this.sseFlushEachChunk = true,
    this.encodeJsonToBytes = false,
    this.maxRequestBodyBytes = _defaultMaxRequestBodyBytes,
    this.maxConcurrentRequests,
    this.requestBodyIdleTimeout,
    this.serverOptions = const RpcHttpServerOptions(),
    this.onClose,
    Iterable<RpcHttpUpgradeHandler> upgradeHandlers = const [],
    Iterable<RpcHttpMiddleware> middleware = const [],
  }) : restRoutes = restRoutes ?? RestRouteRegistry(const []),
       upgradeHandlers = List.unmodifiable(upgradeHandlers),
       middleware = List.unmodifiable(middleware) {
    for (final value in [
      maxRequestBodyBytes,
      maxConcurrentRequests,
      serverOptions.maxHeaderBytes,
    ]) {
      if (value != null && value <= 0)
        throw ArgumentError('HTTP limits must be positive.');
    }
    for (final timeout in [
      requestBodyIdleTimeout,
      serverOptions.bodyTimeout,
      serverOptions.handlerTimeout,
      health?.checkTimeout,
    ]) {
      if (timeout != null && timeout <= Duration.zero)
        throw ArgumentError('HTTP deadlines must be positive.');
    }
    _rateLimiter = serverOptions.rateLimit == null
        ? null
        : RpcHttpRateLimiter(serverOptions.rateLimit!);
    _metrics = metrics == null ? null : RpcHttpMetricsCollector();
    final cors = serverOptions.cors;
    _cors = cors == null ? null : CompiledCorsPolicy(cors);
    handler = createRpcHttpHandler(
      procedures: procedures,
      restRoutes: this.restRoutes,
      openApiDocument: openApiDocument,
      openApiPath: openApiPath,
      docsHtml: docsHtml,
      docsPath: docsPath,
      docsBasicAuth: docsBasicAuth,
      staticAssets: staticAssets,
      health: health,
      metrics: metrics,
      metricsCollector: _metrics,
      isReady: () => _requests.isAccepting,
      bindings: bindings,
      contextFactory: contextFactory,
      sseHeartbeatInterval: sseHeartbeatInterval,
      sseFlushEachChunk: sseFlushEachChunk,
      encodeJsonToBytes: encodeJsonToBytes,
      middleware: this.middleware,
    );
  }

  final RpcProcedureRegistry procedures;
  final RestRouteRegistry restRoutes;
  final JsonObject? openApiDocument;
  final String openApiPath;
  final String? docsHtml;
  final String docsPath;
  final RpcHttpBasicAuth? docsBasicAuth;
  final RpcHttpStaticOptions? staticAssets;
  final RpcHttpHealthOptions? health;
  final RpcHttpMetricsOptions? metrics;
  final RpcContextBindings bindings;
  final RpcContextFactory? contextFactory;
  final Duration sseHeartbeatInterval;
  final bool sseFlushEachChunk;

  /// Successful JSON bodies become UTF-8 bytes when enabled.
  final bool encodeJsonToBytes;
  final int? maxRequestBodyBytes;
  final int? maxConcurrentRequests;
  final Duration? requestBodyIdleTimeout;
  final RpcHttpServerOptions serverOptions;
  final FutureOr<void> Function()? onClose;
  final List<RpcHttpUpgradeHandler> upgradeHandlers;
  final List<RpcHttpMiddleware> middleware;
  late final RpcHttpHandler handler;
  late final RpcHttpRateLimiter? _rateLimiter;
  late final RpcHttpMetricsCollector? _metrics;
  late final CompiledCorsPolicy? _cors;
  final _requests = _RpcRequestTracker();
  final _random = Random.secure();
  Future<void>? _providersClosing;
  Future<void>? _closing;
  Future<void>? _listenAttempt;
  RpcHttpServer? _server;
  var _listenPending = false;

  /// Gracefully stops this app and disposes its generated provider container.
  ///
  /// When [listen] has returned a server, this is equivalent to closing that
  /// server. Before listening, it disposes providers without opening a socket.
  Future<void> close({
    Duration gracePeriod = _defaultGracePeriod,
    bool force = false,
  }) {
    return _closing ??= _close(gracePeriod: gracePeriod, force: force);
  }

  Future<void> _close({
    required Duration gracePeriod,
    required bool force,
  }) async {
    var server = _server;
    if (server != null) {
      await server.close(gracePeriod: gracePeriod, force: force);
      return;
    }
    _requests.stopAccepting();
    final listenAttempt = _listenAttempt;
    if (listenAttempt != null) {
      await listenAttempt;
      server = _server;
    }
    if (server != null) {
      await server.close(gracePeriod: gracePeriod, force: force);
      return;
    }
    await _closeProviders();
  }

  Future<void> _closeProviders() {
    return _providersClosing ??= Future<void>.sync(() async {
      await onClose?.call();
    });
  }

  Future<RpcHttpServer> listen(
    int port, {
    String hostname = '0.0.0.0',
    bool shared = false,
  }) async {
    if (!_requests.isAccepting)
      throw StateError(
        'This app has been shut down. Create another app to listen again.',
      );
    if (_server != null || _listenPending) {
      throw StateError('This app is already listening.');
    }
    _listenPending = true;
    final listenAttempt = Completer<void>();
    _listenAttempt = listenAttempt.future;
    try {
      final server = await HttpServer.bind(hostname, port, shared: shared);
      if (!_requests.isAccepting) {
        await server.close(force: true);
        throw StateError('This app was closed while it was starting.');
      }
      final rpcServer = RpcHttpServer._(
        server: server,
        requests: _requests,
        upgradeHandlers: upgradeHandlers,
        closeProviders: _closeProviders,
      );
      _server = rpcServer;
      unawaited(_serve(server));
      return rpcServer;
    } finally {
      _listenPending = false;
      _listenAttempt = null;
      listenAttempt.complete();
    }
  }

  Future<void> _serve(HttpServer server) async {
    try {
      await for (final request in server) {
        unawaited(_handle(request));
      }
    } on SocketException {
      // Server socket errors have no request context; request errors are handled below.
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final admitted = _requests.begin(maxConcurrentRequests);
    final cancellation = admitted ?? RpcCancellationSource();
    final exchange = _HttpExchange(cancellation);
    exchange.request = RpcHttpRequest(
      method: request.method,
      path: '/',
      cancellation: cancellation.signal,
    );
    _metrics?.begin();
    StreamIterator<List<int>>? requestChunks;
    var upgraded = false;
    void report(Object error, StackTrace stack) {
      if (exchange.errorReported || exchange.finished) return;
      exchange.errorReported = true;
      try {
        serverOptions.onError?.call(
          RpcHttpErrorEvent(
            request: exchange.request,
            error: error,
            stackTrace: stack,
          ),
        );
      } catch (_) {
        _metrics?.hookErrors++;
      }
    }

    unawaited(
      request.response.done.then(
        (_) {
          if (!exchange.finishedWriting && !upgraded) {
            exchange.disconnected = true;
            cancellation.cancel();
          }
        },
        onError: (Object error, StackTrace stack) {
          if (!exchange.finishedWriting && !upgraded) {
            exchange.disconnected = true;
            report(error, stack);
            cancellation.cancel();
          }
        },
      ),
    );
    try {
      exchange.request = _toRpcRequest(
        request,
        cancellation: cancellation.signal,
        requestId: _requestId(request),
        onError: report,
      );
      if (_metrics != null || serverOptions.onComplete != null) {
        exchange.request = restRoutes.prepareRequest(exchange.request);
        exchange.route = _routeLabel(exchange.request);
      }
      if (admitted == null) {
        throw RpcException.unavailable(
          _requests.isAccepting
              ? 'Server has reached its concurrent request limit.'
              : 'Server is shutting down.',
        );
      }
      _checkHeaderLimit(request);
      final preflight = _cors?.preflightResponse(exchange.request);
      if (preflight != null) {
        await _writeResponse(request, preflight, exchange);
        return;
      }
      final retryAfter = _rateLimiter?.check(exchange.request);
      if (retryAfter != null) {
        final error = RpcException.resourceExhausted(
          'HTTP request rate limit exceeded.',
        );
        report(error, StackTrace.current);
        request.response.persistentConnection = false;
        await _writeResponse(
          request,
          rpcHttpErrorResponse(
            error,
            headers: {
              'retry-after':
                  '${max(1, (retryAfter.inMicroseconds + Duration.microsecondsPerSecond - 1) ~/ Duration.microsecondsPerSecond)}',
            },
          ),
          exchange,
        );
        return;
      }
      for (final upgradeHandler in upgradeHandlers) {
        if (upgradeHandler.canHandle(request)) {
          final context = await _createContext(exchange.request);
          upgraded = true;
          exchange.statusCode = HttpStatus.switchingProtocols;
          await upgradeHandler.handle(request, context);
          return;
        }
      }
      requestChunks = StreamIterator(
        _cancellableChunks(request, cancellation.signal),
      );
      final bytes = await _readRequestBody(request, requestChunks, exchange);
      exchange.bodyRead = true;
      exchange.request = exchange.request.copyWith(bodyBytes: bytes);
      final deadline = serverOptions.handlerTimeout;
      final responseFuture = Future<RpcHttpResponse>.sync(
        () => handler(exchange.request),
      );
      final response = await Future.any<RpcHttpResponse>([
        if (deadline == null)
          responseFuture
        else
          responseFuture.timeout(
            deadline,
            onTimeout: () {
              throw RpcException.deadlineExceeded(
                'HTTP handler deadline exceeded.',
              );
            },
          ),
        cancellation.signal.cancelled.then(
          (_) => throw RpcException.cancelled(),
        ),
      ]);
      await _writeResponse(request, response, exchange);
    } catch (error, stack) {
      if (exchange.startedWriting &&
          (error is SocketException || error is HttpException))
        exchange.disconnected = true;
      if (exchange.bodyRead) cancellation.cancel();
      report(error, stack);
      final mapped = error is RpcException
          ? error
          : error is FormatException
          ? RpcException.badRequest('Request body must be valid UTF-8.')
          : RpcException.internalError();
      if (!exchange.startedWriting && !exchange.disconnected && !upgraded) {
        request.response.headers.clear();
        request.response.persistentConnection = false;
        try {
          await _writeResponse(request, rpcHttpErrorResponse(mapped), exchange);
        } catch (_) {
          await _abortConnection(request.response);
        }
      } else {
        if (exchange.disconnected)
          exchange.statusCode = RpcErrorCode.cancelled.statusCode;
        exchange.finishedWriting = true;
        await _abortConnection(request.response);
      }
    } finally {
      exchange.finished = true;
      cancellation.cancel();
      if (admitted != null) _requests.end(admitted);
      // Send rejections before cancelling input, which can close the socket.
      try {
        await requestChunks?.cancel();
      } on Object {
        /* Connection may already be gone. */
      }
      final completed = RpcHttpCompletion(
        request: exchange.request,
        route: exchange.route,
        statusCode: exchange.statusCode,
        elapsed: exchange.watch.elapsed,
        receivedBytes: exchange.receivedBytes,
        sentBytes: exchange.sentBytes,
        streaming: exchange.streaming,
        disconnected: exchange.disconnected,
        failed: exchange.errorReported,
      );
      _metrics?.complete(completed);
      try {
        serverOptions.onComplete?.call(completed);
      } catch (_) {
        _metrics?.hookErrors++;
      }
    }
  }

  Future<void> _writeResponse(
    HttpRequest native,
    RpcHttpResponse response,
    _HttpExchange exchange,
  ) async {
    final cors = _cors;
    if (cors != null) response = cors.applyResponse(exchange.request, response);
    if (serverOptions.compress)
      response = _compressResponse(exchange.request, response);
    exchange.statusCode = response.statusCode;
    final output = native.response;
    output.statusCode = response.statusCode;
    response.headers.forEach(output.headers.set);
    output.cookies.addAll(response.cookies);
    for (final entry in response.headerValues.entries) {
      for (final value in entry.value) {
        output.headers.add(entry.key, value);
      }
    }
    if (exchange.request.requestId case final id?)
      output.headers.set('x-request-id', id);
    final isSse = output.headers.contentType?.mimeType == 'text/event-stream';
    if (isSse || response.statusCode == 206)
      output.headers.set('content-encoding', 'identity');
    if (native.method == 'HEAD' ||
        response.statusCode == 204 ||
        response.statusCode == 304) {
      exchange.finishedWriting = true;
      await output.close();
      return;
    }
    switch (response.content) {
      case RpcBufferedHttpBody(:final value):
        if (value != null) {
          final bytes = value is List<int>
              ? value
              : utf8.encode(value.toString());
          exchange.startedWriting = true;
          exchange.sentBytes += bytes.length;
          output.add(bytes);
        }
      case RpcStreamingHttpBody(:final chunks, :final flushEachChunk):
        exchange.streaming = true;
        _metrics?.beginStream();
        final counted =
            _cancellableChunks(
              chunks,
              exchange.cancellation.signal,
              onConsumerCancel: () {
                exchange.disconnected = true;
                exchange.statusCode = RpcErrorCode.cancelled.statusCode;
                exchange.request.onError?.call(
                  RpcException.cancelled('HTTP consumer disconnected.'),
                  StackTrace.current,
                );
                exchange.cancellation.cancel();
              },
            ).map((bytes) {
              exchange.startedWriting = true;
              exchange.sentBytes += bytes.length;
              return bytes;
            });
        if (flushEachChunk) {
          output.bufferOutput = false;
        }
        // IOSink owns stream cancellation on socket failure. Disabling output
        // buffering retains immediate SSE delivery without a manual write loop.
        await output.addStream(counted);
    }
    exchange.finishedWriting = true;
    await output.close();
  }

  Future<List<int>> _readRequestBody(
    HttpRequest request,
    StreamIterator<List<int>> chunks,
    _HttpExchange exchange,
  ) async {
    if (request.contentLength == 0) return const [];
    final limit = maxRequestBodyBytes;
    if (limit != null && request.contentLength > limit) {
      throw RpcException.payloadTooLarge(
        'Request body exceeds the maximum allowed size of $limit bytes.',
      );
    }
    final bytes = BytesBuilder(copy: false);
    final clock = Stopwatch()..start();
    while (true) {
      final total = serverOptions.bodyTimeout;
      final remaining = total == null ? null : total - clock.elapsed;
      if (remaining != null && remaining <= Duration.zero)
        throw RpcException.requestTimeout('Request body deadline exceeded.');
      final idle = requestBodyIdleTimeout;
      final wait = remaining == null
          ? idle
          : idle == null || remaining < idle
          ? remaining
          : idle;
      final next = chunks.moveNext();
      final available = await (wait == null
          ? next
          : next.timeout(
              wait,
              onTimeout: () => throw RpcException.requestTimeout(
                remaining != null && (idle == null || remaining <= idle)
                    ? 'Request body deadline exceeded.'
                    : 'Request body idle timeout exceeded.',
              ),
            ));
      if (!available) break;
      final chunk = chunks.current;
      exchange.receivedBytes += chunk.length;
      if (limit != null && exchange.receivedBytes > limit) {
        throw RpcException.payloadTooLarge(
          'Request body exceeds the maximum allowed size of $limit bytes.',
        );
      }
      bytes.add(chunk);
    }
    exchange.cancellation.signal.throwIfCancelled();
    return bytes.takeBytes().asUnmodifiableView();
  }

  RpcHttpRequest _toRpcRequest(
    HttpRequest request, {
    List<int>? bodyBytes,
    required RpcCancellationSignal cancellation,
    String? requestId,
    void Function(Object, StackTrace)? onError,
  }) {
    final headers = <String, String>{};
    request.headers.forEach((key, values) {
      if (values.isNotEmpty)
        headers[key] = values.length == 1 ? values.single : values.join(',');
    });
    return RpcHttpRequest(
      method: request.method,
      path: request.uri.path.isEmpty ? '/' : request.uri.path,
      uri: request.uri,
      remoteAddress: request.connectionInfo?.remoteAddress.address,
      headers: UnmodifiableMapView(headers),
      queryParameters: request.uri.queryParameters,
      queryParametersAll: Map.unmodifiable(
        request.uri.queryParametersAll.map(
          (key, values) => MapEntry(key, List<String>.unmodifiable(values)),
        ),
      ),
      bodyBytes: bodyBytes,
      cancellation: cancellation,
      requestId: requestId,
      onError: onError,
    );
  }

  Future<RpcContext> _createContext(RpcHttpRequest request) async {
    var effectiveBindings = bindings;
    if (request.requestId case final id?)
      effectiveBindings = effectiveBindings.withValue(rpcRequestIdKey, id);
    final custom = await contextFactory?.call(request);
    return custom == null
        ? RpcContext(
            headers: request.headers,
            httpMethod: request.method,
            path: request.path,
            bindings: effectiveBindings,
            cancellation: request.cancellation,
          )
        : custom.copyWith(
            bindings: effectiveBindings.merge(custom.bindings),
            cancellation: request.cancellation,
          );
  }

  String _requestId(HttpRequest request) {
    final incoming = serverOptions.trustRequestId
        ? request.headers['x-request-id']?.singleOrNull
        : null;
    if (serverOptions.trustRequestId &&
        incoming != null &&
        RegExp(r'^[A-Za-z0-9._-]{1,128}$').hasMatch(incoming))
      return incoming;
    final created =
        serverOptions.requestIdFactory?.call() ??
        List.generate(
          4,
          (_) => _random.nextInt(0x100000000).toRadixString(16).padLeft(8, '0'),
        ).join();
    if (!RegExp(r'^[A-Za-z0-9._-]{1,128}$').hasMatch(created))
      throw StateError('requestIdFactory returned an invalid request ID.');
    return created;
  }

  void _checkHeaderLimit(HttpRequest request) {
    final limit = serverOptions.maxHeaderBytes;
    if (limit == null) return;
    var size = utf8
        .encode('${request.method} ${request.uri} HTTP/1.1\r\n')
        .length;
    request.headers.forEach((name, values) {
      for (final value in values) {
        size += utf8.encode('$name: $value\r\n').length;
      }
    });
    if (size + 2 > limit)
      throw const RpcException(
        code: RpcErrorCode.headersTooLarge,
        message: 'HTTP request headers exceed the maximum allowed size.',
      );
  }

  String _routeLabel(RpcHttpRequest request) {
    final path = request.path;
    final route = restRoutes.matchRequest(request)?.route;
    if (route != null) return route.path;
    if (path == '/rpc') return '/rpc';
    for (final known in [
      openApiPath,
      docsPath,
      health?.path,
      health?.readinessPath,
      health?.livenessPath,
      metrics?.path,
    ]) {
      if (known != null && path == known) return known;
    }
    return '/unmatched';
  }
}

final class _HttpExchange {
  _HttpExchange(this.cancellation);
  final RpcCancellationSource cancellation;
  final watch = Stopwatch()..start();
  late RpcHttpRequest request;
  String route = '/unmatched';
  int statusCode = 500;
  int receivedBytes = 0;
  int sentBytes = 0;
  bool streaming = false;
  bool startedWriting = false;
  bool finishedWriting = false;
  bool finished = false;
  bool disconnected = false;
  bool errorReported = false;
  bool bodyRead = false;
}

Stream<List<int>> _cancellableChunks(
  Stream<List<int>> input,
  RpcCancellationSignal signal, {
  void Function()? onConsumerCancel,
}) {
  late StreamController<List<int>> controller;
  StreamSubscription<List<int>>? subscription;
  var ended = false;
  var failed = false;
  controller = StreamController<List<int>>(
    onListen: () {
      if (signal.isCancelled) {
        ended = true;
        unawaited(controller.close());
        return;
      }
      subscription = input.listen(
        controller.add,
        onError: (Object error, StackTrace stack) {
          failed = true;
          controller.addError(error, stack);
        },
        onDone: () {
          ended = true;
          unawaited(controller.close());
        },
      );
      unawaited(
        signal.cancelled.then((_) async {
          if (!ended) {
            ended = true;
            await subscription?.cancel();
            await controller.close();
          }
        }),
      );
    },
    onPause: () => subscription?.pause(),
    onResume: () => subscription?.resume(),
    onCancel: () async {
      if (!ended && !failed && !signal.isCancelled) onConsumerCancel?.call();
      ended = true;
      await subscription?.cancel();
    },
  );
  return controller.stream;
}

RpcHttpResponse _compressResponse(
  RpcHttpRequest request,
  RpcHttpResponse response,
) {
  final contentType =
      lookupRestHeader(
        response.headers,
        'content-type',
      )?.split(';').first.toLowerCase() ??
      '';
  final compressible =
      contentType.startsWith('text/') && contentType != 'text/event-stream' ||
      const {
        'application/json',
        'application/javascript',
        'application/xml',
        'image/svg+xml',
      }.contains(contentType) ||
      contentType.endsWith('+json');
  if (!compressible ||
      response.statusCode == 206 ||
      response.statusCode == 204 ||
      response.statusCode == 304 ||
      lookupRestHeader(response.headers, 'content-encoding') != null)
    return response;
  final headers = <String, String>{...response.headers};
  final vary =
      lookupRestHeader(
        headers,
        'vary',
      )?.split(',').map((value) => value.trim()).toList() ??
      <String>[];
  if (!vary.any(
    (value) => value.toLowerCase() == 'accept-encoding' || value == '*',
  ))
    vary.add('Accept-Encoding');
  headers.removeWhere((key, _) => key.toLowerCase() == 'vary');
  headers['vary'] = vary.join(', ');
  double? gzipQuality;
  double? wildcardQuality;
  for (final value
      in (lookupRestHeader(request.headers, 'accept-encoding') ?? '').split(
        ',',
      )) {
    final parts = value.trim().toLowerCase().split(';');
    var quality = 1.0;
    for (final parameter in parts.skip(1)) {
      final pair = parameter.trim().split('=');
      if (pair.first == 'q')
        quality = pair.length == 2 ? double.tryParse(pair[1]) ?? 0 : 0;
    }
    if (!quality.isFinite || quality < 0 || quality > 1) quality = 0;
    if (parts.first == 'gzip') gzipQuality = quality;
    if (parts.first == '*') wildcardQuality = quality;
  }
  if ((gzipQuality ?? wildcardQuality ?? 0) <= 0)
    return response.copyWith(headers: headers);
  headers.removeWhere((key, _) => key.toLowerCase() == 'content-length');
  headers['content-encoding'] = 'gzip';
  if (request.method == 'HEAD') return response.copyWith(headers: headers);
  switch (response.content) {
    case RpcBufferedHttpBody(:final value):
      if (value == null) return response.copyWith(headers: headers);
      final encoded = gzip.encode(
        value is List<int> ? value : utf8.encode(value.toString()),
      );
      headers['content-length'] = '${encoded.length}';
      return response.copyWith(
        headers: headers,
        content: RpcBufferedHttpBody(encoded),
      );
    case RpcStreamingHttpBody(:final chunks, :final flushEachChunk):
      return response.copyWith(
        headers: headers,
        content: RpcStreamingHttpBody(
          chunks.transform(gzip.encoder),
          flushEachChunk: flushEachChunk,
        ),
      );
  }
}

Future<void> _abortConnection(HttpResponse response) async {
  try {
    // detachSocket cannot be used after headers have been written. A response
    // deadline closes the underlying connection even after a partial body.
    response.deadline = Duration.zero;
  } on Object {
    /* The peer or HttpServer may already have closed the connection. */
  }
}

final class _RpcRequestTracker {
  final Set<RpcCancellationSource> _active = {};
  Completer<void>? _idle;
  var _accepting = true;

  bool get isAccepting => _accepting;

  RpcCancellationSource? begin(int? limit) {
    if (!_accepting || (limit != null && _active.length >= limit)) {
      return null;
    }
    final source = RpcCancellationSource();
    _active.add(source);
    return source;
  }

  void stopAccepting() {
    _accepting = false;
  }

  void end(RpcCancellationSource source) {
    _active.remove(source);
    if (_active.isEmpty) {
      _idle?.complete();
      _idle = null;
    }
  }

  Future<void> get whenIdle {
    if (_active.isEmpty) {
      return Future<void>.value();
    }
    return (_idle ??= Completer<void>()).future;
  }

  void cancelAll() {
    for (final source in _active.toList(growable: false)) {
      source.cancel();
    }
  }
}
