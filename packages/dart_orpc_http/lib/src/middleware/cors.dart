import 'cors_policy.dart';
import '../rpc_http_handler.dart';

final class CorsOptions {
  const CorsOptions({
    this.allowOrigin = '*',
    this.allowedOrigins = const [],
    this.allowOriginPredicate,
    this.allowMethods = const [
      'GET',
      'POST',
      'PUT',
      'DELETE',
      'PATCH',
      'OPTIONS',
      'HEAD',
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

  /// A wildcard is supported only without credentials. Credentialed requests
  /// require an exact origin, [allowedOrigins], or [allowOriginPredicate].
  final String allowOrigin;
  final List<String> allowedOrigins;
  final bool Function(String origin)? allowOriginPredicate;
  final List<String> allowMethods;
  final List<String> allowHeaders;
  final bool allowCredentials;
  final List<String> exposeHeaders;
  final int? maxAge;
}

/// Use RpcHttpServerOptions.cors when policies must also cover adapter failures.
RpcHttpMiddleware createCorsMiddleware([
  CorsOptions options = const CorsOptions(),
]) {
  final policy = CompiledCorsPolicy(options);
  return (next) => (request) async {
    final preflight = policy.preflightResponse(request);
    return policy.applyResponse(request, preflight ?? await next(request));
  };
}

RpcHttpResponse? corsPreflightResponse(
  RpcHttpRequest request,
  CorsOptions options,
) => CompiledCorsPolicy(options).preflightResponse(request);

RpcHttpResponse applyCorsResponse(
  RpcHttpRequest request,
  RpcHttpResponse response,
  CorsOptions options,
) => CompiledCorsPolicy(options).applyResponse(request, response);
