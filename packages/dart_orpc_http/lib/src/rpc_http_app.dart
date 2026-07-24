import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_orpc_core/dart_orpc_core.dart';

import 'rpc_http_handler.dart';

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
  }) : _server = server,
       _requests = requests,
       _upgradeHandlers = upgradeHandlers;

  final HttpServer _server;
  final _RpcRequestTracker _requests;
  final List<RpcHttpUpgradeHandler> _upgradeHandlers;
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
    required RpcProcedureRegistry procedures,
    RestRouteRegistry? restRoutes,
    this.openApiDocument,
    this.openApiPath = '/openapi.json',
    this.docsHtml,
    this.docsPath = '/docs',
    this.docsBasicAuth,
    this.staticAssets,
    this.health,
    this.metrics,
    this.contextFactory,
    this.sseHeartbeatInterval = const Duration(seconds: 15),
    this.maxRequestBodyBytes = _defaultMaxRequestBodyBytes,
    Iterable<RpcHttpUpgradeHandler> upgradeHandlers = const [],
    Iterable<RpcHttpMiddleware> middleware = const [],
  }) : assert(
         maxRequestBodyBytes == null || maxRequestBodyBytes > 0,
         'maxRequestBodyBytes must be greater than zero when set.',
       ),
       procedures = procedures,
       restRoutes = restRoutes ?? RestRouteRegistry(const []),
       upgradeHandlers = List<RpcHttpUpgradeHandler>.unmodifiable(
         upgradeHandlers,
       ),
       middleware = List<RpcHttpMiddleware>.unmodifiable(middleware),
       handler = createRpcHttpHandler(
         procedures: procedures,
         restRoutes: restRoutes,
         openApiDocument: openApiDocument,
         openApiPath: openApiPath,
         docsHtml: docsHtml,
         docsPath: docsPath,
         docsBasicAuth: docsBasicAuth,
         staticAssets: staticAssets,
         health: health,
         metrics: metrics,
         contextFactory: contextFactory,
         sseHeartbeatInterval: sseHeartbeatInterval,
         middleware: middleware,
       );

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
  final RpcContextFactory? contextFactory;
  final Duration sseHeartbeatInterval;
  final int? maxRequestBodyBytes;
  final List<RpcHttpUpgradeHandler> upgradeHandlers;
  final List<RpcHttpMiddleware> middleware;
  final RpcHttpHandler handler;
  final _requests = _RpcRequestTracker();

  Future<RpcHttpServer> listen(int port, {String hostname = '0.0.0.0'}) async {
    final server = await HttpServer.bind(hostname, port);
    unawaited(_serve(server));
    return RpcHttpServer._(
      server: server,
      requests: _requests,
      upgradeHandlers: upgradeHandlers,
    );
  }

  Future<void> _serve(HttpServer server) async {
    await for (final request in server) {
      unawaited(_handle(request));
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final cancellation = _requests.begin();
    if (cancellation == null) {
      request.response
        ..statusCode = HttpStatus.serviceUnavailable
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode(
            RpcException.resourceExhausted(
              'Server is shutting down.',
            ).toResponse().toJson(),
          ),
        );
      await request.response.close();
      return;
    }
    try {
      for (final upgradeHandler in upgradeHandlers) {
        if (upgradeHandler.canHandle(request)) {
          final rpcRequest = _toRpcRequest(
            request,
            cancellation: cancellation.signal,
          );
          final context = await _createContext(rpcRequest);
          await upgradeHandler.handle(request, context);
          return;
        }
      }

      final requestBody = await _readRequestBody(request);
      final response = await handler(
        _toRpcRequest(
          request,
          body: requestBody,
          cancellation: cancellation.signal,
        ),
      );

      request.response.statusCode = response.statusCode;
      response.headers.forEach(request.response.headers.set);
      switch (response.content) {
        case RpcBufferedHttpBody(:final value):
          if (value is List<int>) {
            request.response.add(value);
          } else if (value != null) {
            request.response.write(value);
          }
        case RpcStreamingHttpBody(:final chunks):
          request.response.bufferOutput = false;
          request.response.headers.chunkedTransferEncoding = true;
          await for (final chunk in chunks) {
            request.response.add(chunk);
            await request.response.flush();
          }
      }
      await request.response.close();
    } on _PayloadTooLargeException {
      request.response.statusCode = HttpStatus.requestEntityTooLarge;
      request.response.headers.set(
        'content-type',
        'application/json; charset=utf-8',
      );
      request.response.write(
        jsonEncode({
          'error': {
            'code': 'PAYLOAD_TOO_LARGE',
            'message':
                'Request body exceeds the maximum allowed size of '
                '$maxRequestBodyBytes bytes.',
          },
        }),
      );
      await request.response.close();
    } catch (_) {
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.headers.set(
        'content-type',
        'application/json; charset=utf-8',
      );
      request.response.write(
        jsonEncode(RpcException.internalError().toResponse().toJson()),
      );
      await request.response.close();
    } finally {
      cancellation.cancel();
      _requests.end(cancellation);
    }
  }

  RpcHttpRequest _toRpcRequest(
    HttpRequest request, {
    String body = '',
    required RpcCancellationSignal cancellation,
  }) {
    return RpcHttpRequest(
      method: request.method,
      path: request.uri.path.isEmpty ? '/' : request.uri.path,
      headers: _flattenHeaders(request.headers),
      queryParameters: request.uri.queryParameters,
      body: body,
      cancellation: cancellation,
    );
  }

  Future<RpcContext> _createContext(RpcHttpRequest request) async {
    final customContext = await contextFactory?.call(request);
    if (customContext != null) {
      return customContext.copyWith(cancellation: request.cancellation);
    }
    return RpcContext(
      headers: request.headers,
      httpMethod: request.method,
      path: request.path,
      cancellation: request.cancellation,
    );
  }

  Future<String> _readRequestBody(HttpRequest request) async {
    final limit = maxRequestBodyBytes;

    final announcedLength = request.contentLength;
    if (limit != null && announcedLength > limit) {
      throw const _PayloadTooLargeException();
    }

    final bytes = <int>[];
    var receivedBytes = 0;

    await for (final chunk in request) {
      receivedBytes += chunk.length;
      if (limit != null && receivedBytes > limit) {
        throw const _PayloadTooLargeException();
      }
      bytes.addAll(chunk);
    }

    return utf8.decode(bytes);
  }

  Map<String, String> _flattenHeaders(HttpHeaders headers) {
    final flattened = <String, String>{};
    headers.forEach((name, values) {
      if (values.isNotEmpty) {
        flattened[name] = values.join(',');
      }
    });

    return Map<String, String>.unmodifiable(flattened);
  }
}

final class _PayloadTooLargeException implements Exception {
  const _PayloadTooLargeException();
}

final class _RpcRequestTracker {
  final Set<RpcCancellationSource> _active = {};
  Completer<void>? _idle;
  var _accepting = true;

  RpcCancellationSource? begin() {
    if (!_accepting) {
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
