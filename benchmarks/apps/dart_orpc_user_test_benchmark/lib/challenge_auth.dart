import 'dart:convert';
import 'dart:io';

import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:dart_orpc/dart_orpc.dart';

const _identityAttribute = 'challenge.identity';

final class ChallengeIdentity {
  const ChallengeIdentity({required this.userId, required this.username});

  final int userId;
  final String username;
}

final class ChallengeBearerGuard implements RpcGuard {
  @override
  void canActivate(RpcGuardContext context) {
    final identity = context.rpcContext.attributes[_identityAttribute];
    if (identity is! ChallengeIdentity) {
      throw RpcException.unauthorized('missing bearer token');
    }
  }
}

RpcContext challengeContextFactory(RpcHttpRequest request) {
  final identity = _requiresAuthentication(request)
      ? _authenticate(request.headers)
      : null;
  return RpcContext(
    headers: request.headers,
    httpMethod: request.method,
    path: request.path,
    attributes: {if (identity != null) _identityAttribute: identity},
  );
}

ChallengeIdentity identityFromContext(RpcContext context) {
  final identity = context.attributes[_identityAttribute];
  if (identity is ChallengeIdentity) {
    return identity;
  }
  throw RpcException.unauthorized('missing bearer token');
}

bool _requiresAuthentication(RpcHttpRequest request) {
  if (request.method != 'POST') {
    return false;
  }
  return request.path == '/posts' ||
      RegExp(r'^/posts/[^/]+/like$').hasMatch(request.path);
}

ChallengeIdentity _authenticate(Map<String, String> headers) {
  final authorization = _findHeader(headers, 'authorization');
  if (authorization == null || !authorization.startsWith('Bearer ')) {
    throw RpcException.unauthorized('missing bearer token');
  }

  final token = authorization.substring('Bearer '.length);
  final payload = _verifiedPayload(token);
  if (payload is! Map<String, dynamic>) {
    throw RpcException.unauthorized('invalid token payload');
  }

  final subject = payload['sub'];
  final username = payload['username'];
  if (subject is! String || username is! String) {
    throw RpcException.unauthorized('invalid token payload');
  }
  final userId = int.tryParse(subject);
  if (userId == null || userId <= 0 || subject != '$userId') {
    throw RpcException.unauthorized('invalid token payload');
  }
  return ChallengeIdentity(userId: userId, username: username);
}

Object? _verifiedPayload(String token) {
  try {
    _requireHs256(token);
    final verified = JWT.verify(
      token,
      SecretKey(
        Platform.environment['JWT_SECRET'] ?? 'twelve-dollar-challenge',
      ),
    );
    return verified.payload;
  } on Object {
    throw RpcException.unauthorized('invalid or expired token');
  }
}

void _requireHs256(String token) {
  final segments = token.split('.');
  if (segments.length != 3 || segments.first.isEmpty) {
    throw const FormatException('Malformed JWT.');
  }
  final encodedHeader = base64Url.normalize(segments.first);
  final header = jsonDecode(utf8.decode(base64Url.decode(encodedHeader)));
  if (header is! Map<String, dynamic> || header['alg'] != 'HS256') {
    throw const FormatException('JWT must use HS256.');
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
