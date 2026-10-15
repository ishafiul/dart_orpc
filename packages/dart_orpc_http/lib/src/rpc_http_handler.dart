import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'rpc_http_metrics.dart';

typedef RpcHttpHandler =
    Future<RpcHttpResponse> Function(RpcHttpRequest request);
typedef RpcHttpMiddleware = RpcHttpHandler Function(RpcHttpHandler next);
typedef RestRouteHandler =
    FutureOr<Object?> Function(
      RpcContext context,
      RpcHttpRequest request,
      Map<String, String> pathParameters,
    );
typedef RestStreamRouteHandler =
    Stream<Object?> Function(
      RpcContext context,
      RpcHttpRequest request,
      Map<String, String> pathParameters,
    );
typedef RpcContextFactory =
    FutureOr<RpcContext> Function(RpcHttpRequest request);

/// Optional HTTP response control for an otherwise transport-neutral procedure.
/// Use context.binding(rpcHttpResponseKey) so WebSocket calls remain valid.
const rpcHttpResponseKey = RpcContextKey<RpcHttpResponseControl>(
  'dart_orpc.http.response',
);

final class RpcHttpResponseControl {
  int? statusCode;
  final Map<String, String> headers = {};
  final List<Cookie> cookies = [];

  RpcHttpResponse apply(RpcHttpResponse response) {
    final status = statusCode ?? response.statusCode;
    if (status < 200 || status > 599)
      throw StateError('Invalid HTTP response status.');
    final copy = response.copyWith(
      statusCode: status,
      headers: {...response.headers, ...headers},
      content: status == 204 || status == 304
          ? const RpcBufferedHttpBody(null)
          : null,
    );
    return switch (copy.content) {
      RpcBufferedHttpBody(:final value) => RpcHttpResponse(
        statusCode: copy.statusCode,
        headers: copy.headers,
        headerValues: copy.headerValues,
        cookies: [...copy.cookies, ...cookies],
        body: value,
      ),
      RpcStreamingHttpBody(:final chunks, :final flushEachChunk) =>
        RpcHttpResponse.streaming(
          statusCode: copy.statusCode,
          headers: copy.headers,
          headerValues: copy.headerValues,
          cookies: [...copy.cookies, ...cookies],
          body: chunks,
          flushEachChunk: flushEachChunk,
        ),
    };
  }
}

final class RpcHttpBasicAuth {
  const RpcHttpBasicAuth({
    required this.username,
    required this.password,
    this.realm = 'Restricted',
  });

  final String username;
  final String password;
  final String realm;
}

final class RpcHttpDocsOptions {
  const RpcHttpDocsOptions({
    this.openApiPath = '/openapi.json',
    this.docsPath = '/docs',
    this.title,
    this.html,
    this.basicAuth,
  });

  final String openApiPath;
  final String docsPath;
  final String? title;
  final String? html;
  final RpcHttpBasicAuth? basicAuth;
}

final class RpcHttpStaticOptions {
  const RpcHttpStaticOptions({
    this.path = '/',
    required this.directory,
    this.defaultDocument = 'index.html',
    this.cacheControl = 'no-cache',
  });

  final String path;
  final String directory;
  final String defaultDocument;

  /// Browser cache policy. Validators are checked on every request.
  final String cacheControl;
}

final class RpcHttpHealthOptions {
  const RpcHttpHealthOptions({
    this.path = '/health',
    this.check,
    this.livenessPath,
    this.readinessPath,
    this.readinessCheck,
    this.checkTimeout = const Duration(seconds: 5),
  });

  final String path;
  final FutureOr<bool> Function()? check;
  final String? livenessPath;
  final String? readinessPath;
  final FutureOr<bool> Function()? readinessCheck;
  final Duration checkTimeout;
}

final class RpcHttpMetricsOptions {
  const RpcHttpMetricsOptions({this.path = '/metrics'});

  final String path;
}

final class RpcHttpRequest {
  const RpcHttpRequest({
    required this.method,
    required this.path,
    this.headers = const {},
    this.queryParameters = const {},
    String body = '',
    List<int>? bodyBytes,
    this.queryParametersAll = const {},
    this.uri,
    this.remoteAddress,
    this.requestId,
    this.onError,
    this.cancellation = RpcCancellationSignal.none,
  }) : _body = body,
       _bodyBytes = bodyBytes,
       _restRouting = null;

  RpcHttpRequest._withRouting(
    this._restRouting, {
    required RpcHttpRequest request,
    String? method,
    String? path,
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    Map<String, List<String>>? queryParametersAll,
    String? body,
    List<int>? bodyBytes,
  }) : method = method ?? request.method,
       path = path ?? request.path,
       headers = headers ?? request.headers,
       queryParameters = queryParameters ?? request.queryParameters,
       queryParametersAll = queryParametersAll ?? request.queryParametersAll,
       _body = body ?? request._body,
       _bodyBytes = body != null ? null : bodyBytes ?? request._bodyBytes,
       uri = request.uri,
       remoteAddress = request.remoteAddress,
       requestId = request.requestId,
       onError = request.onError,
       cancellation = request.cancellation;

  final _ResolvedRestRequest? _restRouting;

  final String method;
  final String path;
  final Map<String, String> headers;
  final Map<String, String> queryParameters;
  final String _body;
  final List<int>? _bodyBytes;

  /// UTF-8 text decoded on demand. Binary handlers can use [bodyBytes] directly.
  String get body {
    if (_bodyBytes == null) return _body;
    try {
      return utf8.decode(_bodyBytes);
    } on FormatException {
      throw RpcException.badRequest('Request body must be valid UTF-8.');
    }
  }

  List<int> get bodyBytes =>
      _bodyBytes ?? Uint8List.fromList(utf8.encode(_body)).asUnmodifiableView();
  final Map<String, List<String>> queryParametersAll;
  final Uri? uri;
  final String? remoteAddress;
  final String? requestId;

  /// Error observer supplied by the server. Middleware should preserve it when
  /// constructing replacement requests.
  final void Function(Object error, StackTrace stackTrace)? onError;
  Map<String, String> get cookies => Map.unmodifiable({
    for (final pair in (lookupRestHeader(headers, 'cookie') ?? '').split(';'))
      if (pair.indexOf('=') case final index when index > 0)
        pair.substring(0, index).trim(): pair.substring(index + 1).trim(),
  });
  final RpcCancellationSignal cancellation;

  /// Preserve transport metadata and observers when middleware rewrites a request.
  RpcHttpRequest copyWith({
    String? method,
    String? path,
    Map<String, String>? headers,
    Map<String, String>? queryParameters,
    Map<String, List<String>>? queryParametersAll,
    String? body,
    List<int>? bodyBytes,
  }) => RpcHttpRequest._withRouting(
    (method == null || method == this.method) &&
            (path == null || path == this.path)
        ? _restRouting
        : null,
    request: this,
    method: method,
    path: path,
    headers: headers,
    queryParameters: queryParameters,
    queryParametersAll: queryParametersAll,
    body: body,
    bodyBytes: bodyBytes,
  );
}

sealed class RpcHttpBody {
  const RpcHttpBody();
}

final class RpcBufferedHttpBody extends RpcHttpBody {
  const RpcBufferedHttpBody(this.value);

  final Object? value;
}

final class RpcStreamingHttpBody extends RpcHttpBody {
  const RpcStreamingHttpBody(this.chunks, {this.flushEachChunk = true});

  final Stream<List<int>> chunks;

  /// Flush each chunk for low latency, or use HTTP buffering for throughput.
  final bool flushEachChunk;
}

final class RpcHttpResponse {
  const RpcHttpResponse({
    required this.statusCode,
    this.headers = const {},
    this.headerValues = const {},
    this.cookies = const [],
    Object? body,
  }) : _body = body,
       _stream = null,
       _flushEachChunk = true;

  RpcHttpResponse.streaming({
    required this.statusCode,
    this.headers = const {},
    this.headerValues = const {},
    this.cookies = const [],
    required Stream<List<int>> body,
    bool flushEachChunk = true,
  }) : _body = null,
       _stream = body,
       _flushEachChunk = flushEachChunk;

  final int statusCode;
  final Map<String, String> headers;

  /// Repeated headers such as Set-Cookie, kept separate instead of comma-joined.
  final Map<String, List<String>> headerValues;
  final List<Cookie> cookies;

  factory RpcHttpResponse.redirect(
    Uri location, {
    int statusCode = HttpStatus.found,
  }) {
    if (statusCode < 300 || statusCode > 399 || statusCode == 304)
      throw ArgumentError.value(statusCode, 'statusCode');
    return RpcHttpResponse(
      statusCode: statusCode,
      headers: {'location': location.toString()},
    );
  }

  static Future<RpcHttpResponse> download(
    File file, {
    String? filename,
    String contentType = 'application/octet-stream',
  }) async {
    final name = filename ?? file.uri.pathSegments.last;
    if (name.contains(RegExp(r'[\r\n]')))
      throw ArgumentError.value(filename, 'filename');
    final escaped = name.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
    return RpcHttpResponse.streaming(
      statusCode: HttpStatus.ok,
      headers: {
        'content-type': contentType,
        'content-length': '${await file.length()}',
        'content-disposition': 'attachment; filename="$escaped"',
      },
      body: file.openRead(),
      flushEachChunk: false,
    );
  }

  final Object? _body;
  final Stream<List<int>>? _stream;
  final bool _flushEachChunk;

  RpcHttpBody get content => _stream == null
      ? RpcBufferedHttpBody(_body)
      : RpcStreamingHttpBody(_stream, flushEachChunk: _flushEachChunk);

  Object? get body => _stream ?? _body;

  bool get isStreaming => _stream != null;

  RpcHttpResponse copyWith({
    int? statusCode,
    Map<String, String>? headers,
    Map<String, List<String>>? headerValues,
    List<Cookie>? cookies,
    RpcHttpBody? content,
  }) {
    final effectiveContent = content ?? this.content;
    return switch (effectiveContent) {
      RpcBufferedHttpBody(:final value) => RpcHttpResponse(
        statusCode: statusCode ?? this.statusCode,
        headers: headers ?? this.headers,
        headerValues: headerValues ?? this.headerValues,
        cookies: cookies ?? this.cookies,
        body: value,
      ),
      RpcStreamingHttpBody(:final chunks, :final flushEachChunk) =>
        RpcHttpResponse.streaming(
          statusCode: statusCode ?? this.statusCode,
          headers: headers ?? this.headers,
          headerValues: headerValues ?? this.headerValues,
          cookies: cookies ?? this.cookies,
          body: chunks,
          flushEachChunk: flushEachChunk,
        ),
    };
  }
}

sealed class RegisteredRestRoute {
  const RegisteredRestRoute({
    required this.method,
    required this.path,
    this.metadata,
    this.guards = const [],
  });

  final String method;
  final String path;
  final ProcedureMetadata? metadata;
  final List<RpcGuard> guards;
}

final class RestUnaryRoute extends RegisteredRestRoute {
  const RestUnaryRoute({
    required super.method,
    required super.path,
    required this.handler,
    super.metadata,
    super.guards,
  });

  final RestRouteHandler handler;
}

final class RestStreamRoute extends RegisteredRestRoute {
  const RestStreamRoute({
    required super.path,
    required this.handler,
    super.metadata,
    super.guards,
  }) : super(method: 'GET');

  final RestStreamRouteHandler handler;
}

typedef RestRoute = RestUnaryRoute;

final class RestRouteMatch {
  const RestRouteMatch({required this.route, required this.pathParameters});

  final RegisteredRestRoute route;
  final Map<String, String> pathParameters;
}

final class _IndexedRestRoute {
  const _IndexedRestRoute({
    required this.route,
    required this.registrationIndex,
    required this.parameterSlots,
  });

  final RegisteredRestRoute route;
  final int registrationIndex;
  final List<({int index, String name})> parameterSlots;
  bool get hasPathParameters => parameterSlots.isNotEmpty;
}

final class _RestRouteTrieNode {
  final Map<String, _RestRouteTrieNode> literalChildren = {};
  final Map<String, _IndexedRestRoute> routesByMethod = {};
  _RestRouteTrieNode? parameterChild;
  final Map<String, int> firstRegistrationByMethod = {};

  int firstRegistrationFor(String method) =>
      firstRegistrationByMethod[method] ?? 1 << 62;

  void includeRoute(String method, int registrationIndex) {
    firstRegistrationByMethod.putIfAbsent(method, () => registrationIndex);
  }
}

final class _RestRequestPath {
  _RestRequestPath(String path) : normalized = _normalizePath(path);

  final String normalized;
  late final List<String> segments = _splitPathSegments(normalized);
  late final String canonical =
      normalized.contains('//') ||
          (normalized.length > 1 && normalized.endsWith('/'))
      ? _canonicalPathForSegments(segments)
      : normalized;
}

final class _ResolvedRestRequest {
  _ResolvedRestRequest(this.registry, RpcHttpRequest request)
    : path = _RestRequestPath(request.path) {
    match =
        registry._match(request.method, path) ??
        (request.method.toUpperCase() == 'HEAD'
            ? registry._match('GET', path)
            : null);
  }

  final RestRouteRegistry registry;
  final _RestRequestPath path;
  late final RestRouteMatch? match;
  late final List<String> allowedMethods = registry._allowedMethodsFor(path);
}

final class RestRouteRegistry {
  RestRouteRegistry(Iterable<RegisteredRestRoute> routes)
    : _routes = List<RegisteredRestRoute>.unmodifiable(routes) {
    _ensureUniqueRoutes(_routes);

    for (var index = 0; index < _routes.length; index++) {
      final route = _routes[index];
      final method = route.method.toUpperCase();
      final segments = _splitPathSegments(route.path);
      final indexedRoute = _IndexedRestRoute(
        route: route,
        registrationIndex: index,
        parameterSlots: [
          for (var index = 0; index < segments.length; index++)
            if (segments[index].startsWith(':'))
              (index: index, name: segments[index].substring(1)),
        ],
      );

      if (!indexedRoute.hasPathParameters) {
        final canonicalPath = _canonicalPathForSegments(segments);
        _exactRoutes.putIfAbsent(method, () => {})[canonicalPath] =
            indexedRoute;
        _exactMethodsByPath.putIfAbsent(canonicalPath, () => {}).add(method);
        continue;
      }

      var node = _parameterizedRouteRoot;
      node.includeRoute(method, index);
      for (final segment in segments) {
        if (segment.startsWith(':')) {
          final parameterChild = node.parameterChild ??= _RestRouteTrieNode();
          node = parameterChild;
        } else {
          node = node.literalChildren.putIfAbsent(
            segment,
            _RestRouteTrieNode.new,
          );
        }
        node.includeRoute(method, index);
      }
      node.routesByMethod[method] = indexedRoute;
    }
  }

  final List<RegisteredRestRoute> _routes;
  final Map<String, Map<String, _IndexedRestRoute>> _exactRoutes = {};
  final Map<String, Set<String>> _exactMethodsByPath = {};
  final _RestRouteTrieNode _parameterizedRouteRoot = _RestRouteTrieNode();

  Iterable<RegisteredRestRoute> get routes => _routes;

  /// Retains one resolution through body/header copies of this request.
  /// Rewriting method/path or using another registry invalidates the result.
  RpcHttpRequest prepareRequest(RpcHttpRequest request) {
    if (identical(request._restRouting?.registry, this)) return request;
    return RpcHttpRequest._withRouting(
      _ResolvedRestRequest(this, request),
      request: request,
    );
  }

  /// Resolves explicit HEAD routes before falling back to GET.
  RestRouteMatch? matchRequest(RpcHttpRequest request) =>
      _resolve(request).match;

  _ResolvedRestRequest _resolve(RpcHttpRequest request) {
    final cached = request._restRouting;
    return cached != null && identical(cached.registry, this)
        ? cached
        : _ResolvedRestRequest(this, request);
  }

  RestRouteMatch? match({required String method, required String path}) {
    return _match(method, _RestRequestPath(path));
  }

  RestRouteMatch? _match(String method, _RestRequestPath path) {
    final normalizedMethod = method.toUpperCase();
    final exactRoute = _exactRoutes[normalizedMethod]?[path.canonical];
    final needsTrieSearch =
        _parameterizedRouteRoot.firstRegistrationFor(normalizedMethod) <
        (exactRoute?.registrationIndex ?? 1 << 62);
    final matchedRoute = needsTrieSearch
        ? _findParameterizedRestRoute(
            node: _parameterizedRouteRoot,
            pathSegments: path.segments,
            pathIndex: 0,
            method: normalizedMethod,
            bestMatch: exactRoute,
          )
        : exactRoute;

    if (matchedRoute == null) {
      return null;
    }

    final pathParameters = matchedRoute.hasPathParameters
        ? _pathParametersFor(matchedRoute.parameterSlots, path.segments)
        : const <String, String>{};
    return RestRouteMatch(
      route: matchedRoute.route,
      pathParameters: pathParameters,
    );
  }

  List<String> allowedMethodsFor(String path) {
    return _allowedMethodsFor(_RestRequestPath(path));
  }

  List<String> _allowedMethodsFor(_RestRequestPath path) {
    final methods = <String>{...?_exactMethodsByPath[path.canonical]};
    if (_parameterizedRouteRoot.firstRegistrationByMethod.isNotEmpty) {
      _collectParameterizedRestMethods(
        node: _parameterizedRouteRoot,
        pathSegments: path.segments,
        pathIndex: 0,
        methods: methods,
      );
    }

    final sorted = methods.toList(growable: false)..sort();
    return sorted;
  }

  static void _ensureUniqueRoutes(List<RegisteredRestRoute> routes) {
    final seenSignatures = <String>{};

    for (final route in routes) {
      final signature =
          '${route.method.toUpperCase()} ${_normalizeRouteSignature(route.path)}';
      if (!seenSignatures.add(signature)) {
        throw StateError('Duplicate REST route "$signature".');
      }
    }
  }
}

/// Creates a handler with string JSON bodies by default. [encodeJsonToBytes]
/// opts into UTF-8 bodies for successful RPC/REST calls and OpenAPI output.
/// [openApiDocument] is serialized once at construction as a startup snapshot.
/// Disabling [sseFlushEachChunk] trades immediate SSE delivery for buffering.
RpcHttpHandler createRpcHttpHandler({
  required RpcProcedureRegistry procedures,
  RestRouteRegistry? restRoutes,
  JsonObject? openApiDocument,
  String openApiPath = '/openapi.json',
  String? docsHtml,
  String docsPath = '/docs',
  RpcHttpBasicAuth? docsBasicAuth,
  RpcHttpStaticOptions? staticAssets,
  RpcHttpHealthOptions? health,
  RpcHttpMetricsOptions? metrics,
  RpcHttpMetricsCollector? metricsCollector,
  bool Function()? isReady,
  RpcContextBindings bindings = const RpcContextBindings.empty(),
  RpcContextFactory? contextFactory,
  Duration sseHeartbeatInterval = const Duration(seconds: 15),
  bool sseFlushEachChunk = true,
  bool encodeJsonToBytes = false,
  Iterable<RpcHttpMiddleware> middleware = const [],
}) {
  final effectiveRestRoutes = restRoutes ?? RestRouteRegistry(const []);
  final normalizedOpenApiPath = _normalizePath(openApiPath);
  final normalizedDocsPath = _normalizePath(docsPath);
  final normalizedStaticPath = staticAssets != null
      ? _normalizePath(staticAssets.path)
      : null;
  final normalizedHealthPath = health != null
      ? _normalizePath(health.path)
      : null;
  final normalizedMetricsPath = metrics != null
      ? _normalizePath(metrics.path)
      : null;
  final Object Function(Object?) encodeJson = encodeJsonToBytes
      ? JsonUtf8Encoder().convert
      : jsonEncode;
  // The generated document is a startup snapshot, shared by all requests.
  final encodedDocument = openApiDocument == null
      ? null
      : encodeJson(openApiDocument);
  final encodedOpenApiDocument = encodedDocument is List<int>
      ? Uint8List.fromList(encodedDocument).asUnmodifiableView()
      : encodedDocument;

  final baseHandler = (RpcHttpRequest request) async {
    final path = _normalizePath(request.path);
    if (docsBasicAuth != null &&
        (path == normalizedOpenApiPath || path == normalizedDocsPath)) {
      final unauthorizedResponse = _requireDocsBasicAuth(
        request,
        docsBasicAuth,
      );
      if (unauthorizedResponse != null) {
        return unauthorizedResponse;
      }
    }

    if (normalizedHealthPath != null && path == normalizedHealthPath) {
      return _handleHealthRequest(request, options: health!);
    }
    if (health?.livenessPath != null &&
        path == _normalizePath(health!.livenessPath!)) {
      return _handleHealthRequest(request, options: health, check: () => true);
    }
    if (health?.readinessPath != null &&
        path == _normalizePath(health!.readinessPath!)) {
      return _handleHealthRequest(
        request,
        options: health,
        check: () async =>
            (isReady?.call() ?? true) &&
            await (health.readinessCheck?.call() ??
                health.check?.call() ??
                true),
      );
    }

    if (normalizedMetricsPath != null && path == normalizedMetricsPath) {
      return _handleMetricsRequest(
        request,
        options: metrics!,
        collector: metricsCollector,
      );
    }

    if (path == normalizedOpenApiPath) {
      return _handleOpenApiRequest(
        request,
        encodedDocument: encodedOpenApiDocument,
      );
    }

    if (path == normalizedDocsPath) {
      return _handleDocsRequest(request, docsHtml: docsHtml);
    }

    if (path == '/rpc') {
      return _handleRpcRequest(
        request,
        path: path,
        procedures: procedures,
        bindings: bindings,
        contextFactory: contextFactory,
        encodeJson: encodeJson,
      );
    }

    final restResolution = effectiveRestRoutes._resolve(request);
    final restMatch = restResolution.match;
    if (restMatch != null) {
      return _handleRestRequest(
        request,
        path: path,
        match: restMatch,
        bindings: bindings,
        contextFactory: contextFactory,
        sseHeartbeatInterval: sseHeartbeatInterval,
        sseFlushEachChunk: sseFlushEachChunk,
        encodeJson: encodeJson,
      );
    }

    final allowedMethods = restResolution.allowedMethods.toList();
    if (allowedMethods.contains('GET') && !allowedMethods.contains('HEAD')) {
      allowedMethods.add('HEAD');
      allowedMethods.sort();
    }
    if (allowedMethods.isNotEmpty) {
      final allowHeader = allowedMethods.join(', ');
      return _jsonResponse(
        HttpStatus.methodNotAllowed,
        RpcException.badRequest(
          'REST endpoint only accepts $allowHeader requests.',
        ).toResponse().toJson(),
        extraHeaders: {'allow': allowHeader},
      );
    }

    if (normalizedStaticPath != null) {
      final isAtStaticPath = path == normalizedStaticPath;
      final isSubPath = normalizedStaticPath == '/'
          ? true
          : path.startsWith('$normalizedStaticPath/');

      if (isAtStaticPath || isSubPath) {
        final staticResponse = await _handleStaticRequest(
          request,
          options: staticAssets!,
        );
        if (staticResponse.statusCode != HttpStatus.notFound) {
          return staticResponse;
        }
      }
    }

    return const RpcHttpResponse(
      statusCode: HttpStatus.notFound,
      headers: {'content-type': 'text/plain; charset=utf-8'},
      body: 'Not Found',
    );
  };

  return _applyMiddleware(baseHandler, middleware);
}

RpcHttpHandler _applyMiddleware(
  RpcHttpHandler handler,
  Iterable<RpcHttpMiddleware> middleware,
) {
  final pipeline = middleware.toList(growable: false);
  var current = handler;
  for (final layer in pipeline.reversed) {
    current = layer(current);
  }
  return current;
}

RpcHttpResponse? _requireDocsBasicAuth(
  RpcHttpRequest request,
  RpcHttpBasicAuth basicAuth,
) {
  final authorization = lookupRestHeader(request.headers, 'authorization');
  if (authorization == null) {
    return _docsUnauthorizedResponse(basicAuth.realm);
  }

  const prefix = 'basic ';
  if (authorization.length < prefix.length ||
      authorization.substring(0, prefix.length).toLowerCase() != prefix) {
    return _docsUnauthorizedResponse(basicAuth.realm);
  }

  final encoded = authorization.substring(prefix.length).trim();
  if (encoded.isEmpty) {
    return _docsUnauthorizedResponse(basicAuth.realm);
  }

  late final String decoded;
  try {
    decoded = utf8.decode(base64Decode(encoded));
  } catch (_) {
    return _docsUnauthorizedResponse(basicAuth.realm);
  }

  final separatorIndex = decoded.indexOf(':');
  if (separatorIndex == -1) {
    return _docsUnauthorizedResponse(basicAuth.realm);
  }

  final username = decoded.substring(0, separatorIndex);
  final password = decoded.substring(separatorIndex + 1);
  if (username != basicAuth.username || password != basicAuth.password) {
    return _docsUnauthorizedResponse(basicAuth.realm);
  }

  return null;
}

RpcHttpResponse _docsUnauthorizedResponse(String realm) {
  final escapedRealm = realm.replaceAll('"', r'\"');
  return RpcHttpResponse(
    statusCode: HttpStatus.unauthorized,
    headers: {
      'content-type': 'text/plain; charset=utf-8',
      'www-authenticate': 'Basic realm="$escapedRealm"',
    },
    body: 'Unauthorized',
  );
}

String _normalizePath(String path) {
  if (path.isEmpty) {
    return '/';
  }

  final normalized = path.startsWith('/') ? path : '/$path';
  if (normalized.length > 1 && normalized.endsWith('/')) {
    return normalized.substring(0, normalized.length - 1);
  }

  return normalized;
}

Future<RpcHttpResponse> _handleRpcRequest(
  RpcHttpRequest request, {
  required String path,
  required RpcProcedureRegistry procedures,
  required RpcContextBindings bindings,
  RpcContextFactory? contextFactory,
  required Object Function(Object?) encodeJson,
}) async {
  if (request.method != 'POST') {
    return _jsonResponse(
      HttpStatus.methodNotAllowed,
      const RpcErrorResponse(
        error: RpcErrorBody(
          code: 'BAD_REQUEST',
          message: 'RPC endpoint only accepts POST requests.',
        ),
      ).toJson(),
      extraHeaders: const {'allow': 'POST'},
    );
  }

  try {
    final contentType = lookupRestHeader(
      request.headers,
      'content-type',
    )?.split(';').first.trim().toLowerCase();
    if (contentType != null &&
        contentType != 'application/json' &&
        !contentType.endsWith('+json')) {
      throw const RpcException(
        code: RpcErrorCode.unsupportedMediaType,
        message: 'RPC requests require a JSON content type.',
      );
    }
    final Object? jsonBody;
    try {
      jsonBody = jsonDecode(request.body);
    } on FormatException catch (error, stack) {
      request.onError?.call(error, stack);
      return _rpcErrorResponse(
        RpcException.badRequest('RPC request body must be valid JSON.'),
      );
    }
    final rpcRequest = RpcRequest.fromJson(jsonBody);
    final context = await _buildContext(
      request,
      path: path,
      bindings: bindings,
      contextFactory: contextFactory,
    );

    final data = await procedures.dispatchUnary(context, rpcRequest);
    final response = _jsonResponse(
      HttpStatus.ok,
      RpcSuccessResponse(data: data).toJson(),
      encodeJson: encodeJson,
    );
    final control = context.binding(rpcHttpResponseKey);
    // REST-specific status changes must not remove or change the RPC envelope.
    return control == null
        ? response
        : response.copyWith(
            headers: {...response.headers, ...control.headers},
            cookies: [...response.cookies, ...control.cookies],
          );
  } on RpcException catch (error, stack) {
    request.onError?.call(error, stack);
    return _rpcErrorResponse(error);
  } catch (error, stack) {
    request.onError?.call(error, stack);
    return _rpcErrorResponse(RpcException.internalError());
  }
}

Future<RpcHttpResponse> _handleRestRequest(
  RpcHttpRequest request, {
  required String path,
  required RestRouteMatch match,
  required RpcContextBindings bindings,
  RpcContextFactory? contextFactory,
  required Duration sseHeartbeatInterval,
  required bool sseFlushEachChunk,
  required Object Function(Object?) encodeJson,
}) async {
  try {
    final context = await _buildContext(
      request,
      path: path,
      bindings: bindings,
      contextFactory: contextFactory,
    );

    final metadata = match.route.metadata;
    if (metadata != null && match.route.guards.isNotEmpty) {
      await runRpcGuards(
        match.route.guards,
        rpcContext: context,
        procedure: metadata,
      );
    }

    final response = switch (match.route) {
      RestUnaryRoute() => await _handleRestUnaryRoute(
        match.route as RestUnaryRoute,
        context,
        request,
        match.pathParameters,
        encodeJson,
      ),
      RestStreamRoute(:final handler) => RpcHttpResponse.streaming(
        statusCode: metadata?.path?.statusCode ?? HttpStatus.ok,
        headers: {
          'content-type': 'text/event-stream; charset=utf-8',
          'cache-control': 'no-cache',
          'connection': 'keep-alive',
          'x-accel-buffering': 'no',
          ...?metadata?.path?.headers,
        },
        body: encodeSseResponseBody(
          handler(context, request, match.pathParameters),
          heartbeatInterval: sseHeartbeatInterval,
          cancellation: context.cancellation,
          onError: request.onError,
        ),
        flushEachChunk: sseFlushEachChunk,
      ),
    };
    return context.binding(rpcHttpResponseKey)?.apply(response) ?? response;
  } on RpcException catch (error, stack) {
    request.onError?.call(error, stack);
    return _rpcErrorResponse(error);
  } catch (error, stack) {
    request.onError?.call(error, stack);
    return _rpcErrorResponse(RpcException.internalError());
  }
}

Future<RpcHttpResponse> _handleRestUnaryRoute(
  RestUnaryRoute route,
  RpcContext context,
  RpcHttpRequest request,
  Map<String, String> pathParameters,
  Object Function(Object?) encodeJson,
) async {
  final output = await route.handler(context, request, pathParameters);
  if (output is RpcHttpResponse) return output;
  final status = route.metadata?.path?.statusCode;
  final headers = route.metadata?.path?.headers ?? const <String, String>{};
  if (route.metadata?.outputTypeCode == 'void') {
    return RpcHttpResponse(
      statusCode: status ?? HttpStatus.noContent,
      headers: headers,
    );
  }
  if (status == 204 || status == 304)
    return RpcHttpResponse(statusCode: status!, headers: headers);
  return RpcHttpResponse(
    statusCode: status ?? HttpStatus.ok,
    headers: {'content-type': 'application/json; charset=utf-8', ...headers},
    body: output is RpcJsonBytes ? output.toJsonBytes() : encodeJson(output),
  );
}

Future<RpcHttpResponse> _handleOpenApiRequest(
  RpcHttpRequest request, {
  required Object? encodedDocument,
}) async {
  if (encodedDocument == null) {
    return const RpcHttpResponse(
      statusCode: HttpStatus.notFound,
      headers: {'content-type': 'text/plain; charset=utf-8'},
      body: 'Not Found',
    );
  }

  if (request.method != 'GET') {
    return _jsonResponse(
      HttpStatus.methodNotAllowed,
      RpcException.badRequest(
        'OpenAPI endpoint only accepts GET requests.',
      ).toResponse().toJson(),
      extraHeaders: const {'allow': 'GET'},
    );
  }

  return RpcHttpResponse(
    statusCode: HttpStatus.ok,
    headers: const {'content-type': 'application/json; charset=utf-8'},
    body: encodedDocument,
  );
}

Future<RpcHttpResponse> _handleDocsRequest(
  RpcHttpRequest request, {
  required String? docsHtml,
}) async {
  if (docsHtml == null) {
    return const RpcHttpResponse(
      statusCode: HttpStatus.notFound,
      headers: {'content-type': 'text/plain; charset=utf-8'},
      body: 'Not Found',
    );
  }

  if (request.method != 'GET') {
    return _jsonResponse(
      HttpStatus.methodNotAllowed,
      RpcException.badRequest(
        'Docs endpoint only accepts GET requests.',
      ).toResponse().toJson(),
      extraHeaders: const {'allow': 'GET'},
    );
  }

  return RpcHttpResponse(
    statusCode: HttpStatus.ok,
    headers: const {'content-type': 'text/html; charset=utf-8'},
    body: docsHtml,
  );
}

Future<RpcHttpResponse> _handleStaticRequest(
  RpcHttpRequest request, {
  required RpcHttpStaticOptions options,
}) async {
  if (request.method != 'GET' && request.method != 'HEAD') {
    return _jsonResponse(
      HttpStatus.methodNotAllowed,
      const RpcErrorResponse(
        error: RpcErrorBody(
          code: 'BAD_REQUEST',
          message: 'Static assets only accept GET or HEAD requests.',
        ),
      ).toJson(),
      extraHeaders: const {'allow': 'GET, HEAD'},
    );
  }

  final normalizedPath = _normalizePath(request.path);
  final normalizedStaticPath = _normalizePath(options.path);
  var relativePath = normalizedPath.substring(normalizedStaticPath.length);
  if (relativePath.startsWith('/')) {
    relativePath = relativePath.substring(1);
  }
  if (relativePath.isEmpty) {
    relativePath = options.defaultDocument;
  }

  final baseDirectory = Directory(options.directory);
  if (!await baseDirectory.exists()) {
    return const RpcHttpResponse(statusCode: HttpStatus.notFound);
  }

  final basePath = await _resolveExistingEntityPath(baseDirectory);
  if (basePath == null) {
    return const RpcHttpResponse(statusCode: HttpStatus.notFound);
  }

  final candidatePath = File.fromUri(
    baseDirectory.uri.resolve(relativePath),
  ).path;
  final file = File(candidatePath);
  if (!await file.exists()) {
    // If it's a directory, try index.html
    final directory = Directory(file.path);
    if (await directory.exists()) {
      final resolvedDirectoryPath = await _resolveExistingEntityPath(directory);
      if (resolvedDirectoryPath == null ||
          !_isPathWithinBase(basePath, resolvedDirectoryPath)) {
        return const RpcHttpResponse(statusCode: HttpStatus.notFound);
      }

      final indexPath = File.fromUri(
        directory.uri.resolve(options.defaultDocument),
      ).path;
      final indexFile = File(indexPath);
      if (await indexFile.exists()) {
        final resolvedIndexPath = await _resolveExistingEntityPath(indexFile);
        if (resolvedIndexPath == null ||
            !_isPathWithinBase(basePath, resolvedIndexPath)) {
          return const RpcHttpResponse(statusCode: HttpStatus.notFound);
        }

        return _serveFile(indexFile, request, options);
      }
    }

    return const RpcHttpResponse(statusCode: HttpStatus.notFound);
  }

  final resolvedFilePath = await _resolveExistingEntityPath(file);
  if (resolvedFilePath == null ||
      !_isPathWithinBase(basePath, resolvedFilePath)) {
    return const RpcHttpResponse(statusCode: HttpStatus.notFound);
  }

  return _serveFile(file, request, options);
}

Future<String?> _resolveExistingEntityPath(FileSystemEntity entity) async {
  try {
    return await entity.resolveSymbolicLinks();
  } catch (_) {
    return null;
  }
}

bool _isPathWithinBase(String basePath, String targetPath) {
  final separator = Platform.pathSeparator;
  final normalizedBase = _trimTrailingSeparator(basePath, separator: separator);
  final normalizedTarget = _trimTrailingSeparator(
    targetPath,
    separator: separator,
  );

  if (normalizedBase == normalizedTarget) {
    return true;
  }

  return normalizedTarget.startsWith('$normalizedBase$separator');
}

String _trimTrailingSeparator(String path, {required String separator}) {
  if (path.length > separator.length && path.endsWith(separator)) {
    return path.substring(0, path.length - separator.length);
  }

  return path;
}

Future<RpcHttpResponse> _serveFile(
  File file,
  RpcHttpRequest request,
  RpcHttpStaticOptions options,
) async {
  final stat = await file.stat();
  if (stat.type != FileSystemEntityType.file) {
    return const RpcHttpResponse(statusCode: HttpStatus.notFound);
  }
  final contentType = _getContentType(file.path);
  final etag =
      'W/"${stat.modified.microsecondsSinceEpoch.toRadixString(16)}-${stat.size.toRadixString(16)}"';
  final headers = {
    'content-type': contentType,
    'cache-control': options.cacheControl,
    'etag': etag,
    'last-modified': HttpDate.format(stat.modified),
    'accept-ranges': 'bytes',
  };

  if (_isFileNotModified(request, etag, stat.modified)) {
    return RpcHttpResponse(
      statusCode: HttpStatus.notModified,
      headers: headers,
    );
  }

  final range = lookupRestHeader(request.headers, 'range');
  final ifRange = lookupRestHeader(request.headers, 'if-range');
  var canRange = ifRange == null;
  if (ifRange != null &&
      !ifRange.startsWith('W/') &&
      !ifRange.startsWith('"')) {
    try {
      canRange =
          stat.modified.millisecondsSinceEpoch ~/ 1000 <=
          HttpDate.parse(ifRange).millisecondsSinceEpoch ~/ 1000;
    } on HttpException {
      canRange = false;
    }
  }
  if (request.method == 'GET' &&
      range != null &&
      canRange &&
      range.startsWith('bytes=') &&
      !range.contains(',')) {
    final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(range);
    if (match != null && (match[1]!.isNotEmpty || match[2]!.isNotEmpty)) {
      final suffix = match[1]!.isEmpty;
      final first = int.tryParse(match[1]!);
      final last = int.tryParse(match[2]!);
      final start = suffix ? stat.size - (last ?? 0) : first ?? stat.size;
      final end = suffix || match[2]!.isEmpty ? stat.size - 1 : last ?? -1;
      if (stat.size == 0 ||
          (!suffix && start >= stat.size) ||
          end < 0 ||
          (!suffix && start > end) ||
          (suffix && (last ?? 0) <= 0)) {
        return RpcHttpResponse(
          statusCode: HttpStatus.requestedRangeNotSatisfiable,
          headers: {...headers, 'content-range': 'bytes */${stat.size}'},
        );
      }
      final boundedStart = start < 0 ? 0 : start;
      final boundedEnd = end >= stat.size ? stat.size - 1 : end;
      return RpcHttpResponse.streaming(
        statusCode: HttpStatus.partialContent,
        headers: {
          ...headers,
          'content-range': 'bytes $boundedStart-$boundedEnd/${stat.size}',
          'content-length': '${boundedEnd - boundedStart + 1}',
        },
        body: file.openRead(boundedStart, boundedEnd + 1),
        flushEachChunk: false,
      );
    }
  }
  headers['content-length'] = '${stat.size}';
  if (request.method == 'HEAD') {
    return RpcHttpResponse(statusCode: HttpStatus.ok, headers: headers);
  }

  return RpcHttpResponse.streaming(
    statusCode: HttpStatus.ok,
    headers: headers,
    body: file.openRead(),
    flushEachChunk: false,
  );
}

bool _isFileNotModified(
  RpcHttpRequest request,
  String etag,
  DateTime modified,
) {
  final ifNoneMatch = lookupRestHeader(request.headers, 'if-none-match');
  if (ifNoneMatch != null) {
    return ifNoneMatch.split(',').any((value) {
      final candidate = value.trim();
      return candidate == '*' ||
          candidate == etag ||
          candidate == etag.substring(2);
    });
  }

  final ifModifiedSince = lookupRestHeader(
    request.headers,
    'if-modified-since',
  );
  if (ifModifiedSince == null) {
    return false;
  }
  try {
    final since = HttpDate.parse(ifModifiedSince);
    return modified.millisecondsSinceEpoch ~/ 1000 <=
        since.millisecondsSinceEpoch ~/ 1000;
  } on HttpException {
    return false;
  }
}

String _getContentType(String path) {
  final extension = path.split('.').lastOrNull?.toLowerCase();
  switch (extension) {
    case 'html':
      return 'text/html; charset=utf-8';
    case 'js':
      return 'application/javascript; charset=utf-8';
    case 'css':
      return 'text/css; charset=utf-8';
    case 'json':
      return 'application/json; charset=utf-8';
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'gif':
      return 'image/gif';
    case 'svg':
      return 'image/svg+xml';
    case 'ico':
      return 'image/x-icon';
    case 'txt':
      return 'text/plain; charset=utf-8';
    default:
      return 'application/octet-stream';
  }
}

Future<RpcHttpResponse> _handleHealthRequest(
  RpcHttpRequest request, {
  required RpcHttpHealthOptions options,
  FutureOr<bool> Function()? check,
}) async {
  if (request.method != 'GET') {
    return _jsonResponse(
      HttpStatus.methodNotAllowed,
      RpcException.badRequest(
        'Health endpoint only accepts GET requests.',
      ).toResponse().toJson(),
      extraHeaders: const {'allow': 'GET'},
    );
  }

  var isHealthy = true;
  try {
    final evaluate = check ?? options.check;
    isHealthy =
        evaluate == null ||
        await Future<bool>.sync(evaluate).timeout(options.checkTimeout);
  } catch (_) {
    isHealthy = false;
  }

  return _jsonResponse(
    isHealthy ? HttpStatus.ok : HttpStatus.serviceUnavailable,
    {
      'status': isHealthy ? 'up' : 'down',
      'timestamp': DateTime.now().toIso8601String(),
    },
  );
}

Future<RpcHttpResponse> _handleMetricsRequest(
  RpcHttpRequest request, {
  required RpcHttpMetricsOptions options,
  RpcHttpMetricsCollector? collector,
}) async {
  if (request.method != 'GET') {
    return _jsonResponse(
      HttpStatus.methodNotAllowed,
      RpcException.badRequest(
        'Metrics endpoint only accepts GET requests.',
      ).toResponse().toJson(),
      extraHeaders: const {'allow': 'GET'},
    );
  }

  return _jsonResponse(HttpStatus.ok, {
    'pid': pid,
    'memory_usage': ProcessInfo.currentRss,
    'uptime_seconds':
        (DateTime.now().millisecondsSinceEpoch - _startTime) ~/ 1000,
    ...?collector?.snapshot(),
  });
}

final _startTime = DateTime.now().millisecondsSinceEpoch;

Future<RpcContext> _buildContext(
  RpcHttpRequest request, {
  required String path,
  required RpcContextBindings bindings,
  RpcContextFactory? contextFactory,
}) async {
  final localBindings = bindings.toBuilder()
    ..set(rpcHttpResponseKey, RpcHttpResponseControl());
  if (request.requestId case final id?) {
    localBindings.set(rpcRequestIdKey, id);
  }
  if (contextFactory != null) {
    final context = await contextFactory(request);
    return context.copyWith(
      bindings: (localBindings..addAll(context.bindings)).build(),
      cancellation: request.cancellation,
    );
  }

  return RpcContext(
    headers: request.headers,
    httpMethod: request.method,
    path: path,
    bindings: localBindings.build(),
    cancellation: request.cancellation,
  );
}

Stream<List<int>> encodeSseResponseBody(
  Stream<Object?> events, {
  Duration heartbeatInterval = const Duration(seconds: 15),
  RpcCancellationSignal cancellation = RpcCancellationSignal.none,
  void Function(Object error, StackTrace stackTrace)? onError,
}) {
  late StreamController<List<int>> controller;
  StreamSubscription<Object?>? subscription;
  Timer? heartbeat;
  RpcCancellationRegistration? cancellationRegistration;
  var terminated = false;

  void addText(String value) {
    if (!controller.isClosed) {
      controller.add(utf8.encode(value));
    }
  }

  Future<void> terminateWithError(Object error, StackTrace stack) async {
    if (terminated) {
      return;
    }
    terminated = true;
    cancellationRegistration?.dispose();
    cancellationRegistration = null;
    onError?.call(error, stack);
    final rpcError = error is RpcException
        ? error
        : RpcException.internalError();
    addText(
      'event: dart-orpc-error\n'
      'data: ${jsonEncode(rpcError.toResponse().toJson())}\n\n',
    );
    heartbeat?.cancel();
    await subscription?.cancel();
    await controller.close();
  }

  Future<void> complete() async {
    if (terminated) {
      return;
    }
    terminated = true;
    cancellationRegistration?.dispose();
    cancellationRegistration = null;
    addText('event: dart-orpc-complete\ndata: {}\n\n');
    heartbeat?.cancel();
    await controller.close();
  }

  Future<void> cancelFromSignal() async {
    if (terminated) {
      return;
    }
    terminated = true;
    cancellationRegistration?.dispose();
    cancellationRegistration = null;
    heartbeat?.cancel();
    await subscription?.cancel();
    if (!controller.isClosed) {
      await controller.close();
    }
  }

  controller = StreamController<List<int>>(
    onListen: () {
      cancellationRegistration = cancellation.onCancel(
        () => unawaited(cancelFromSignal()),
      );
      subscription = events.listen(
        (event) {
          if (terminated) {
            return;
          }
          try {
            addText('data: ${jsonEncode(event)}\n\n');
          } catch (error, stack) {
            unawaited(terminateWithError(error, stack));
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          unawaited(terminateWithError(error, stackTrace));
        },
        onDone: () {
          unawaited(complete());
        },
        cancelOnError: false,
      );
      if (heartbeatInterval > Duration.zero) {
        heartbeat = Timer.periodic(heartbeatInterval, (_) {
          if (!terminated && !controller.isPaused) {
            addText(': dart-orpc-ping\n\n');
          }
        });
      }
    },
    onPause: () => subscription?.pause(),
    onResume: () => subscription?.resume(),
    onCancel: () async {
      terminated = true;
      cancellationRegistration?.dispose();
      cancellationRegistration = null;
      heartbeat?.cancel();
      await subscription?.cancel();
    },
  );

  return controller.stream;
}

_IndexedRestRoute? _findParameterizedRestRoute({
  required _RestRouteTrieNode node,
  required List<String> pathSegments,
  required int pathIndex,
  required String method,
  required _IndexedRestRoute? bestMatch,
}) {
  if (node.firstRegistrationFor(method) >=
      (bestMatch?.registrationIndex ?? 1 << 62)) {
    return bestMatch;
  }

  if (pathIndex == pathSegments.length) {
    final candidate = node.routesByMethod[method];
    if (candidate != null &&
        (bestMatch == null ||
            candidate.registrationIndex < bestMatch.registrationIndex)) {
      return candidate;
    }
    return bestMatch;
  }

  final segment = pathSegments[pathIndex];
  final literalChild = node.literalChildren[segment];
  final parameterChild = node.parameterChild;
  if (literalChild == null) {
    if (parameterChild == null) {
      return bestMatch;
    }
    return _findParameterizedRestRoute(
      node: parameterChild,
      pathSegments: pathSegments,
      pathIndex: pathIndex + 1,
      method: method,
      bestMatch: bestMatch,
    );
  }
  if (parameterChild == null) {
    return _findParameterizedRestRoute(
      node: literalChild,
      pathSegments: pathSegments,
      pathIndex: pathIndex + 1,
      method: method,
      bestMatch: bestMatch,
    );
  }

  if (literalChild.firstRegistrationFor(method) <=
      parameterChild.firstRegistrationFor(method)) {
    bestMatch = _findParameterizedRestRoute(
      node: literalChild,
      pathSegments: pathSegments,
      pathIndex: pathIndex + 1,
      method: method,
      bestMatch: bestMatch,
    );
    return _findParameterizedRestRoute(
      node: parameterChild,
      pathSegments: pathSegments,
      pathIndex: pathIndex + 1,
      method: method,
      bestMatch: bestMatch,
    );
  }

  bestMatch = _findParameterizedRestRoute(
    node: parameterChild,
    pathSegments: pathSegments,
    pathIndex: pathIndex + 1,
    method: method,
    bestMatch: bestMatch,
  );
  return _findParameterizedRestRoute(
    node: literalChild,
    pathSegments: pathSegments,
    pathIndex: pathIndex + 1,
    method: method,
    bestMatch: bestMatch,
  );
}

void _collectParameterizedRestMethods({
  required _RestRouteTrieNode node,
  required List<String> pathSegments,
  required int pathIndex,
  required Set<String> methods,
}) {
  if (pathIndex == pathSegments.length) {
    methods.addAll(node.routesByMethod.keys);
    return;
  }

  final literalChild = node.literalChildren[pathSegments[pathIndex]];
  if (literalChild != null) {
    _collectParameterizedRestMethods(
      node: literalChild,
      pathSegments: pathSegments,
      pathIndex: pathIndex + 1,
      methods: methods,
    );
  }

  final parameterChild = node.parameterChild;
  if (parameterChild != null) {
    _collectParameterizedRestMethods(
      node: parameterChild,
      pathSegments: pathSegments,
      pathIndex: pathIndex + 1,
      methods: methods,
    );
  }
}

Map<String, String> _pathParametersFor(
  List<({int index, String name})> parameterSlots,
  List<String> pathSegments,
) => Map<String, String>.unmodifiable({
  for (final slot in parameterSlots) slot.name: pathSegments[slot.index],
});

String _canonicalPathForSegments(List<String> segments) {
  return segments.isEmpty ? '/' : '/${segments.join('/')}';
}

List<String> _splitPathSegments(String path) {
  if (path == '/') {
    return const [];
  }

  return path
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList(growable: false);
}

String _normalizeRouteSignature(String path) {
  final normalizedPath = _normalizePath(path);
  if (normalizedPath == '/') {
    return normalizedPath;
  }

  final segments = _splitPathSegments(
    normalizedPath,
  ).map((segment) => segment.startsWith(':') ? ':*' : segment).join('/');
  return '/$segments';
}

String? lookupRestHeader(Map<String, String> headers, String name) {
  final normalizedName = name.toLowerCase();

  final direct = headers[normalizedName];
  if (direct != null) {
    return direct;
  }

  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == normalizedName) {
      return entry.value;
    }
  }

  return null;
}

T decodeRestScalarParameter<T>({
  required String? rawValue,
  required String source,
  required String name,
  required String route,
}) {
  final typeName = '$T';

  if (rawValue == null) {
    if (null is T) {
      return null as T;
    }

    throw RpcException.badRequest(
      'Missing required $source "$name" for "$route".',
    );
  }

  if (typeName == 'String' || typeName == 'String?') {
    return rawValue as T;
  }

  if (typeName == 'int' || typeName == 'int?') {
    final parsed = int.tryParse(rawValue);
    if (parsed == null) {
      throw RpcException.badRequest(
        '$source "$name" for "$route" must be a valid int.',
      );
    }

    return parsed as T;
  }

  if (typeName == 'double' || typeName == 'double?') {
    final parsed = double.tryParse(rawValue);
    if (parsed == null) {
      throw RpcException.badRequest(
        '$source "$name" for "$route" must be a valid double.',
      );
    }

    return parsed as T;
  }

  if (typeName == 'bool' || typeName == 'bool?') {
    final normalized = rawValue.toLowerCase();
    if (normalized == 'true' || normalized == '1') {
      return true as T;
    }

    if (normalized == 'false' || normalized == '0') {
      return false as T;
    }

    throw RpcException.badRequest(
      '$source "$name" for "$route" must be a valid bool.',
    );
  }

  throw RpcException.internalError(
    'Unsupported REST scalar type "$typeName" for "$route".',
  );
}

T decodeRestBody<T>({
  required String rawBody,
  required String route,
  required String parameterName,
  required T Function(Object? rawJson) decode,
}) {
  final trimmedBody = rawBody.trim();
  if (trimmedBody.isEmpty) {
    if (null is T) {
      return null as T;
    }

    throw RpcException.badRequest('Missing required JSON body for "$route".');
  }

  final rawJson = _decodeRestBodyJson(trimmedBody, route: route);
  if (rawJson == null && null is T) {
    return null as T;
  }

  try {
    return decode(rawJson);
  } on RpcException {
    rethrow;
  } catch (_) {
    throw RpcException.badRequest(
      'Failed to decode REST body parameter "$parameterName" for "$route".',
    );
  }
}

T decodeRestJsonValue<T>({
  required Object? rawValue,
  required String source,
  required String name,
  required String route,
}) {
  final typeName = '$T';

  if (rawValue == null) {
    if (null is T) {
      return null as T;
    }

    throw RpcException.badRequest(
      'Missing required $source "$name" for "$route".',
    );
  }

  if (typeName == 'String' || typeName == 'String?') {
    if (rawValue is String) {
      return rawValue as T;
    }
  } else if (typeName == 'int' || typeName == 'int?') {
    if (rawValue is int) {
      return rawValue as T;
    }
  } else if (typeName == 'double' || typeName == 'double?') {
    if (rawValue is num) {
      return rawValue.toDouble() as T;
    }
  } else if (typeName == 'bool' || typeName == 'bool?') {
    if (rawValue is bool) {
      return rawValue as T;
    }
  } else {
    throw RpcException.internalError(
      'Unsupported REST JSON value type "$typeName" for "$route".',
    );
  }

  throw RpcException.badRequest(
    '$source "$name" for "$route" has an invalid JSON type.',
  );
}

Object? _decodeRestBodyJson(String rawBody, {required String route}) {
  try {
    return jsonDecode(rawBody);
  } on FormatException {
    throw RpcException.badRequest(
      'REST request body for "$route" must be valid JSON.',
    );
  }
}

RpcHttpResponse _rpcErrorResponse(RpcException error) {
  return _jsonResponse(error.statusCode, error.toResponse().toJson());
}

/// Shared adapter error encoding; the wire code always comes from core.
RpcHttpResponse rpcHttpErrorResponse(
  RpcException error, {
  Map<String, String> headers = const {},
}) => _jsonResponse(
  error.statusCode,
  error.toResponse().toJson(),
  extraHeaders: headers,
);

RpcHttpResponse _jsonResponse(
  int statusCode,
  Map<String, Object?> body, {
  Map<String, String> extraHeaders = const {},
  Object Function(Object?) encodeJson = jsonEncode,
}) {
  return RpcHttpResponse(
    statusCode: statusCode,
    body: encodeJson(body),
    headers: {
      'content-type': 'application/json; charset=utf-8',
      ...extraHeaders,
    },
  );
}
