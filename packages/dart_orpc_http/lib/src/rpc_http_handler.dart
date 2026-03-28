import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_orpc_core/dart_orpc_core.dart';

typedef RpcHttpHandler =
    Future<RpcHttpResponse> Function(RpcHttpRequest request);
typedef RestRouteHandler =
    FutureOr<Object?> Function(
      RpcContext context,
      RpcHttpRequest request,
      Map<String, String> pathParameters,
    );

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
    this.body = '',
  });

  final int statusCode;
  final Map<String, String> headers;
  final String body;
}

final class RestRoute {
  const RestRoute({
    required this.method,
    required this.path,
    required this.handler,
  });

  final String method;
  final String path;
  final RestRouteHandler handler;
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
}) {
  final effectiveRestRoutes = restRoutes ?? RestRouteRegistry(const []);
  final normalizedOpenApiPath = _normalizePath(openApiPath);
  final normalizedDocsPath = _normalizePath(docsPath);

  return (request) async {
    final path = _normalizePath(request.path);
    if (path == normalizedOpenApiPath) {
      return _handleOpenApiRequest(request, openApiDocument: openApiDocument);
    }

    if (path == normalizedDocsPath) {
      return _handleDocsRequest(request, docsHtml: docsHtml);
    }

    if (path == '/rpc') {
      return _handleRpcRequest(request, path: path, procedures: procedures);
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
