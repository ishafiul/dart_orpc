import 'package:basic_app/environment/app_env.dart';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dart_orpc/dart_orpc.dart';

const _authorizationHeader = 'authorization';
const _bearerScheme = 'bearer';
const _whitespacePattern = r'\s+';
const _missingToken = 'Bearer token is required.';
const _wrongScheme = 'Authorization header must use Bearer scheme.';
const _invalidToken = 'Invalid or expired bearer token.';

final class BasicAppJwtAuthGuard implements RpcGuard {
  static final RegExp _whitespace = RegExp(_whitespacePattern);

  @override
  void canActivate(RpcGuardContext context) {
    final authorization = _findHeader(
      context.rpcContext.headers,
      _authorizationHeader,
    );
    if (authorization == null) {
      throw RpcException.unauthorized(_missingToken);
    }

    final parts = authorization.trim().split(_whitespace);
    if (parts.length != 2 || parts.first.toLowerCase() != _bearerScheme) {
      throw RpcException.unauthorized(_wrongScheme);
    }

    final env = context.rpcContext.requireBinding(appEnvKey);
    try {
      JWT.verify(parts[1], SecretKey(env.jwtSecret), issuer: env.jwtIssuer);
    } on JWTException {
      throw RpcException.unauthorized(_invalidToken);
    }
  }
}

String? _findHeader(Map<String, String> headers, String name) {
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == name) {
      return entry.value;
    }
  }
  return null;
}
