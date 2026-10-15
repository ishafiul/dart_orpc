import 'dart:io';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import '../rpc_http_handler.dart';
import 'cors.dart';

/// Immutable startup snapshot; dynamic origin predicates still run per request.
final class CompiledCorsPolicy {
  CompiledCorsPolicy(CorsOptions options)
    : _allowOrigin = options.allowOrigin,
      _allowCredentials = options.allowCredentials,
      _originPredicate = options.allowOriginPredicate,
      _origins = Set.unmodifiable(options.allowedOrigins),
      _methods = Set.unmodifiable(
        options.allowMethods.map((value) => value.toUpperCase()),
      ),
      _headers = Set.unmodifiable(
        options.allowHeaders.map((value) => value.toLowerCase()),
      ),
      _staticHeaders = Map.unmodifiable({
        if (options.allowMethods.isNotEmpty)
          'access-control-allow-methods': options.allowMethods.join(', '),
        if (options.allowHeaders.isNotEmpty)
          'access-control-allow-headers': options.allowHeaders.join(', '),
        if (options.exposeHeaders.isNotEmpty)
          'access-control-expose-headers': options.exposeHeaders.join(', '),
        if (options.maxAge != null)
          'access-control-max-age': '${options.maxAge}',
      });

  final String _allowOrigin;
  final bool _allowCredentials;
  final bool Function(String)? _originPredicate;
  final Set<String> _origins;
  final Set<String> _methods;
  final Set<String> _headers;
  final Map<String, String> _staticHeaders;

  RpcHttpResponse? preflightResponse(RpcHttpRequest request) {
    if (request.method.toUpperCase() != 'OPTIONS') return null;
    final origin = lookupRestHeader(request.headers, 'origin');
    final method = lookupRestHeader(
      request.headers,
      'access-control-request-method',
    );
    final requestedHeaders = lookupRestHeader(
      request.headers,
      'access-control-request-headers',
    );
    if (origin != null && method != null) {
      final denied =
          !_allowsOrigin(origin) ||
          !_methods.contains(method.toUpperCase()) ||
          (requestedHeaders != null &&
              requestedHeaders
                  .split(',')
                  .any(
                    (value) => !_headers.contains(value.trim().toLowerCase()),
                  ));
      if (denied)
        return rpcHttpErrorResponse(
          RpcException.forbidden('CORS preflight rejected.'),
        );
    }
    return const RpcHttpResponse(statusCode: HttpStatus.noContent);
  }

  RpcHttpResponse applyResponse(
    RpcHttpRequest request,
    RpcHttpResponse response,
  ) {
    final origin = lookupRestHeader(request.headers, 'origin');
    final headers = <String, String>{...response.headers};
    headers.removeWhere(
      (name, _) => const {
        'access-control-allow-origin',
        'access-control-allow-credentials',
      }.contains(name.toLowerCase()),
    );
    final varies = <String>[];
    if (_allowOrigin == '*' &&
        !_allowCredentials &&
        _origins.isEmpty &&
        _originPredicate == null) {
      headers['access-control-allow-origin'] = '*';
    } else if (!_allowCredentials &&
        origin == null &&
        _allowOrigin != '*' &&
        _origins.isEmpty &&
        _originPredicate == null) {
      headers['access-control-allow-origin'] = _allowOrigin;
    } else {
      varies.add('Origin');
      if (origin != null && _allowsOrigin(origin)) {
        headers['access-control-allow-origin'] = origin;
        if (_allowCredentials)
          headers['access-control-allow-credentials'] = 'true';
      }
    }
    if (request.method.toUpperCase() == 'OPTIONS') {
      varies.addAll([
        'Access-Control-Request-Method',
        'Access-Control-Request-Headers',
      ]);
    }
    headers.addAll(_staticHeaders);
    if (varies.isNotEmpty) {
      final previous = lookupRestHeader(headers, 'vary');
      final values =
          previous?.split(',').map((value) => value.trim()).toList() ??
          <String>[];
      for (final value in varies) {
        if (!values.any(
          (existing) =>
              existing.toLowerCase() == value.toLowerCase() || existing == '*',
        ))
          values.add(value);
      }
      headers.removeWhere((key, _) => key.toLowerCase() == 'vary');
      headers['vary'] = values.join(', ');
    }
    return response.copyWith(headers: Map.unmodifiable(headers));
  }

  bool _allowsOrigin(String origin) =>
      _origins.contains(origin) ||
      _originPredicate?.call(origin) == true ||
      (_allowOrigin != '*' && _allowOrigin == origin) ||
      (!_allowCredentials &&
          _allowOrigin == '*' &&
          _origins.isEmpty &&
          _originPredicate == null);
}
