import 'dart:io';

import '../rpc_http_handler.dart';

/// Options for configuring CORS middleware.
final class CorsOptions {
  /// Creates a new [CorsOptions] instance.
  const CorsOptions({
    this.allowOrigin = '*',
    this.allowMethods = const [
      'GET',
      'POST',
      'PUT',
      'DELETE',
      'PATCH',
      'OPTIONS',
    ],
    this.allowHeaders = const [
      'Content-Type',
      'Authorization',
      'X-Requested-With',
    ],
    this.allowCredentials = false,
    this.exposeHeaders = const [],
    this.maxAge,
  });

  /// The value for the `Access-Control-Allow-Origin` header.
  ///
  /// If [allowCredentials] is true, this value is ignored and the request's
  /// `Origin` header is used instead.
  final String allowOrigin;

  /// The values for the `Access-Control-Allow-Methods` header.
  final List<String> allowMethods;

  /// The values for the `Access-Control-Allow-Headers` header.
  final List<String> allowHeaders;

  /// Whether to allow credentials (e.g. cookies, authorization headers).
  ///
  /// If true, `Access-Control-Allow-Credentials: true` is added to the response,
  /// and `Access-Control-Allow-Origin` is set to the request's `Origin` header.
  final bool allowCredentials;

  /// The values for the `Access-Control-Expose-Headers` header.
  final List<String> exposeHeaders;

  /// The value for the `Access-Control-Max-Age` header (in seconds).
  final int? maxAge;
}

/// Creates a CORS middleware with the given [options].
RpcHttpMiddleware createCorsMiddleware([
  CorsOptions options = const CorsOptions(),
]) {
  return (next) => (request) async {
    final isOptions = request.method.toUpperCase() == 'OPTIONS';
    final origin = lookupRestHeader(request.headers, 'origin');

    if (isOptions) {
      final headers = <String, String>{};
      _addCorsHeaders(headers, options, origin);

      // Preflight responses typically have no body and 204 No Content.
      return RpcHttpResponse(statusCode: HttpStatus.noContent, headers: headers);
    }

    final response = await next(request);

    final headers = Map<String, String>.from(response.headers);
    _addCorsHeaders(headers, options, origin);

    return RpcHttpResponse(
      statusCode: response.statusCode,
      headers: Map<String, String>.unmodifiable(headers),
      body: response.body,
    );
  };
}

void _addCorsHeaders(
  Map<String, String> headers,
  CorsOptions options,
  String? origin,
) {
  if (options.allowCredentials) {
    if (origin != null) {
      headers['access-control-allow-origin'] = origin;
      headers['access-control-allow-credentials'] = 'true';
    }
  } else {
    headers['access-control-allow-origin'] = options.allowOrigin;
  }

  if (options.allowMethods.isNotEmpty) {
    headers['access-control-allow-methods'] = options.allowMethods.join(', ');
  }

  if (options.allowHeaders.isNotEmpty) {
    headers['access-control-allow-headers'] = options.allowHeaders.join(', ');
  }

  if (options.exposeHeaders.isNotEmpty) {
    headers['access-control-expose-headers'] = options.exposeHeaders.join(', ');
  }

  if (options.maxAge != null) {
    headers['access-control-max-age'] = options.maxAge.toString();
  }
}
