import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_orpc_core/dart_orpc_core.dart';

typedef RpcHttpHandler =
    Future<RpcHttpResponse> Function(RpcHttpRequest request);
typedef RpcHttpMiddleware = RpcHttpHandler Function(RpcHttpHandler next);
typedef RestRouteHandler =
    FutureOr<Object?> Function(
      RpcContext context,
      RpcHttpRequest request,
      Map<String, String> pathParameters,
    );

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
  });

  final String path;
  final String directory;
  final String defaultDocument;
}

final class RpcHttpHealthOptions {
  const RpcHttpHealthOptions({this.path = '/health', this.check});

  final String path;
  final FutureOr<bool> Function()? check;
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
    this.body = '',
  });

  final String method;
  final String path;
  final Map<String, String> headers;
  final Map<String, String> queryParameters;
  final String body;
}

final class RpcHttpResponse {
  const RpcHttpResponse({
    required this.statusCode,
    this.headers = const {},
    this.body,
  });

  final int statusCode;
  final Map<String, String> headers;
  final Object? body;
}

final class RestRoute {
  const RestRoute({
    required this.method,
    required this.path,
    required this.handler,
    this.metadata,
    this.guards = const [],
  });

  final String method;
  final String path;
  final RestRouteHandler handler;
  final ProcedureMetadata? metadata;
  final List<RpcGuard> guards;
}

final class RestRouteMatch {
  const RestRouteMatch({required this.route, required this.pathParameters});

  final RestRoute route;
  final Map<String, String> pathParameters;
}

final class RestRouteRegistry {
  RestRouteRegistry(Iterable<RestRoute> routes)
    : _routes = List<RestRoute>.unmodifiable(routes) {
    _ensureUniqueRoutes(_routes);
  }

  final List<RestRoute> _routes;

  Iterable<RestRoute> get routes => _routes;

  RestRouteMatch? match({required String method, required String path}) {
    final normalizedMethod = method.toUpperCase();
    final normalizedPath = _normalizePath(path);

    for (final route in _routes) {
      if (route.method.toUpperCase() != normalizedMethod) {
        continue;
      }

      final pathParameters = _matchPathPattern(route.path, normalizedPath);
      if (pathParameters != null) {
        return RestRouteMatch(route: route, pathParameters: pathParameters);
      }
    }

    return null;
  }

  List<String> allowedMethodsFor(String path) {
    final normalizedPath = _normalizePath(path);
    final methods = <String>{};

    for (final route in _routes) {
      if (_matchPathPattern(route.path, normalizedPath) != null) {
        methods.add(route.method.toUpperCase());
      }
    }

    final sorted = methods.toList(growable: false)..sort();
    return sorted;
  }

  static void _ensureUniqueRoutes(List<RestRoute> routes) {
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
  Iterable<RpcHttpMiddleware> middleware = const [],
}) {
  final effectiveRestRoutes = restRoutes ?? RestRouteRegistry(const []);
  final normalizedOpenApiPath = _normalizePath(openApiPath);
  final normalizedDocsPath = _normalizePath(docsPath);
  final normalizedStaticPath =
      staticAssets != null ? _normalizePath(staticAssets.path) : null;
  final normalizedHealthPath =
      health != null ? _normalizePath(health.path) : null;
  final normalizedMetricsPath =
      metrics != null ? _normalizePath(metrics.path) : null;

  final baseHandler = (RpcHttpRequest request) async {
    final path = _normalizePath(request.path);
    if (docsBasicAuth != null &&
        (path == normalizedOpenApiPath || path == normalizedDocsPath)) {
      final unauthorizedResponse = _requireDocsBasicAuth(request, docsBasicAuth);
      if (unauthorizedResponse != null) {
        return unauthorizedResponse;
      }
    }

    if (normalizedHealthPath != null && path == normalizedHealthPath) {
      return _handleHealthRequest(request, options: health!);
    }

    if (normalizedMetricsPath != null && path == normalizedMetricsPath) {
      return _handleMetricsRequest(request, options: metrics!);
    }

    if (path == normalizedOpenApiPath) {
      return _handleOpenApiRequest(request, openApiDocument: openApiDocument);
    }

    if (path == normalizedDocsPath) {
      return _handleDocsRequest(request, docsHtml: docsHtml);
    }

    if (path == '/rpc') {
      return _handleRpcRequest(request, path: path, procedures: procedures);
    }

    if (normalizedStaticPath != null) {
      final isAtStaticPath = path == normalizedStaticPath;
      final isSubPath =
          normalizedStaticPath == '/'
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

    final restMatch = effectiveRestRoutes.match(
      method: request.method,
      path: path,
    );
    if (restMatch != null) {
      return _handleRestRequest(request, path: path, match: restMatch);
    }

    final allowedMethods = effectiveRestRoutes.allowedMethodsFor(path);
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
    final jsonBody = jsonDecode(request.body);
    final rpcRequest = RpcRequest.fromJson(jsonBody);
    final context = _buildContext(request, path: path);

    final data = await procedures.dispatch(context, rpcRequest);
    return _jsonResponse(
      HttpStatus.ok,
      RpcSuccessResponse(data: data).toJson(),
    );
  } on FormatException {
    return _rpcErrorResponse(
      RpcException.badRequest('RPC request body must be valid JSON.'),
    );
  } on RpcException catch (error) {
    return _rpcErrorResponse(error);
  } catch (_) {
    return _rpcErrorResponse(RpcException.internalError());
  }
}

Future<RpcHttpResponse> _handleRestRequest(
  RpcHttpRequest request, {
  required String path,
  required RestRouteMatch match,
}) async {
  try {
    final context = _buildContext(request, path: path);

    final metadata = match.route.metadata;
    if (metadata != null) {
      await runRpcGuards(
        match.route.guards,
        rpcContext: context,
        procedure: metadata,
      );
    }

    final data = await match.route.handler(
      context,
      request,
      match.pathParameters,
    );
    return RpcHttpResponse(
      statusCode: HttpStatus.ok,
      headers: const {'content-type': 'application/json; charset=utf-8'},
      body: jsonEncode(data),
    );
  } on RpcException catch (error) {
    return _rpcErrorResponse(error);
  } catch (_) {
    return _rpcErrorResponse(RpcException.internalError());
  }
}

Future<RpcHttpResponse> _handleOpenApiRequest(
  RpcHttpRequest request, {
  required JsonObject? openApiDocument,
}) async {
  if (openApiDocument == null) {
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

  return _jsonResponse(HttpStatus.ok, openApiDocument);
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

  final file = File('${options.directory}/$relativePath');
  if (!await file.exists()) {
    // If it's a directory, try index.html
    if (await FileSystemEntity.isDirectory(file.path)) {
      final indexFile = File('${file.path}/${options.defaultDocument}');
      if (await indexFile.exists()) {
        return _serveFile(indexFile, request.method == 'HEAD');
      }
    }

    return const RpcHttpResponse(statusCode: HttpStatus.notFound);
  }

  return _serveFile(file, request.method == 'HEAD');
}

Future<RpcHttpResponse> _serveFile(File file, bool isHead) async {
  final contentType = _getContentType(file.path);
  final headers = {'content-type': contentType};

  if (isHead) {
    return RpcHttpResponse(statusCode: HttpStatus.ok, headers: headers);
  }

  final body = await file.readAsBytes();
  return RpcHttpResponse(
    statusCode: HttpStatus.ok,
    headers: headers,
    body: body,
  );
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
}) async {
  final isHealthy = options.check == null || await options.check!();

  return _jsonResponse(
    isHealthy ? HttpStatus.ok : HttpStatus.serviceUnavailable,
    {'status': isHealthy ? 'up' : 'down', 'timestamp': DateTime.now().toIso8601String()},
  );
}

Future<RpcHttpResponse> _handleMetricsRequest(
  RpcHttpRequest request, {
  required RpcHttpMetricsOptions options,
}) async {
  // TODO: Implement actual metrics collection. 
  // For now, return basic info.
  return _jsonResponse(HttpStatus.ok, {
    'pid': pid,
    'memory_usage': ProcessInfo.currentRss,
    'uptime_seconds': (DateTime.now().millisecondsSinceEpoch - _startTime) ~/ 1000,
  });
}

final _startTime = DateTime.now().millisecondsSinceEpoch;

RpcContext _buildContext(RpcHttpRequest request, {required String path}) {
  return RpcContext(
    headers: Map<String, String>.unmodifiable(request.headers),
    httpMethod: request.method,
    path: path,
  );
}

Map<String, String>? _matchPathPattern(String pattern, String actualPath) {
  final normalizedPattern = _normalizePath(pattern);
  final normalizedPath = _normalizePath(actualPath);
  final patternSegments = _splitPathSegments(normalizedPattern);
  final pathSegments = _splitPathSegments(normalizedPath);

  if (patternSegments.length != pathSegments.length) {
    return null;
  }

  final pathParameters = <String, String>{};

  for (var index = 0; index < patternSegments.length; index++) {
    final patternSegment = patternSegments[index];
    final pathSegment = pathSegments[index];
    if (patternSegment.startsWith(':')) {
      pathParameters[patternSegment.substring(1)] = pathSegment;
      continue;
    }

    if (patternSegment != pathSegment) {
      return null;
    }
  }

  return Map<String, String>.unmodifiable(pathParameters);
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

RpcHttpResponse _jsonResponse(
  int statusCode,
  Map<String, Object?> body, {
  Map<String, String> extraHeaders = const {},
}) {
  return RpcHttpResponse(
    statusCode: statusCode,
    body: jsonEncode(body),
    headers: {
      'content-type': 'application/json; charset=utf-8',
      ...extraHeaders,
    },
  );
}
