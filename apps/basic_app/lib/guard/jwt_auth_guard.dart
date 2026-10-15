import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dart_orpc/dart_orpc.dart';

import '../environment/app_env.dart';

/// Verifies Basic App bearer tokens using application-owned JWT policy.
final class BasicAppJwtAuthGuard implements RpcGuard {
  @override
  void canActivate(RpcGuardContext context) {
    final authorization = _findHeader(
      context.rpcContext.headers,
      'authorization',
    );
    if (authorization == null) {
      throw RpcException.unauthorized('Bearer token is required.');
    }

    final parts = authorization.trim().split(RegExp(r'\s+'));
    if (parts.length != 2 || parts.first.toLowerCase() != 'bearer') {
      throw RpcException.unauthorized(
        'Authorization header must use Bearer scheme.',
      );
    }

    final env = context.rpcContext.requireBinding(appEnvKey);
    try {
      JWT.verify(parts[1], SecretKey(env.jwtSecret), issuer: env.jwtIssuer);
    } on Object {
      throw RpcException.unauthorized('Invalid or expired bearer token.');
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
