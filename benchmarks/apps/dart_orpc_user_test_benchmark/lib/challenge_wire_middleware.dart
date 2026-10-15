import 'dart:convert';
import 'dart:io';

import 'package:dart_orpc/dart_orpc.dart';

RpcHttpHandler challengeWireMiddleware(RpcHttpHandler next) {
  return (request) async {
    final response = await next(request);
    if (response.isStreaming) {
      return response;
    }

    if (response.statusCode >= HttpStatus.badRequest) {
      return _challengeErrorResponse(request, response);
    }
    if (request.method == 'POST' && request.path == '/posts') {
      return response.copyWith(statusCode: HttpStatus.created);
    }
    if (request.method == 'POST' &&
        RegExp(r'^/posts/[^/]+/like$').hasMatch(request.path)) {
      final alreadyLiked = _readAlreadyLiked(response.body);
      if (alreadyLiked != null) {
        return response.copyWith(
          statusCode: alreadyLiked ? HttpStatus.ok : HttpStatus.created,
        );
      }
    }
    return response;
  };
}

RpcHttpResponse _challengeErrorResponse(
  RpcHttpRequest request,
  RpcHttpResponse response,
) {
  final message =
      _postBodyValidationError(request) ??
      _challengeNotFoundMessage(request, response.statusCode) ??
      _readFrameworkError(response.body) ??
      _defaultErrorMessage(response.statusCode);
  return RpcHttpResponse(
    statusCode: response.statusCode,
    headers: const {'content-type': 'application/json; charset=utf-8'},
    body: jsonEncode({'error': message}),
  );
}

String? _postBodyValidationError(RpcHttpRequest request) {
  if (request.method != 'POST' || request.path != '/posts') {
    return null;
  }

  Object? decodedBody;
  try {
    decodedBody = jsonDecode(request.body);
  } on FormatException {
    return 'malformed JSON body';
  }
  if (decodedBody is! Map<String, dynamic>) {
    return 'malformed JSON body';
  }

  final body = decodedBody['body'];
  if (body is! String || body.trim().isEmpty) {
    return 'body is required';
  }
  if (body.trim().runes.length > 500) {
    return 'body must be at most 500 characters';
  }
  return null;
}

String? _readFrameworkError(Object? responseBody) {
  if (responseBody is! String) {
    return null;
  }
  try {
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) {
      return null;
    }
    final error = decoded['error'];
    if (error is String) {
      return error;
    }
    if (error is Map<String, dynamic>) {
      final message = error['message'];
      if (message is String) {
        return message;
      }
    }
  } on FormatException {
    return null;
  }
  return null;
}

bool? _readAlreadyLiked(Object? responseBody) {
  if (responseBody is! String) {
    return null;
  }
  try {
    final decoded = jsonDecode(responseBody);
    if (decoded is Map<String, dynamic> && decoded['already_liked'] is bool) {
      return decoded['already_liked'] as bool;
    }
  } on FormatException {
    return null;
  }
  return null;
}

String _defaultErrorMessage(int statusCode) {
  if (statusCode == HttpStatus.notFound) {
    return 'not found';
  }
  if (statusCode == HttpStatus.internalServerError) {
    return 'internal server error';
  }
  return 'request failed';
}

String? _challengeNotFoundMessage(RpcHttpRequest request, int statusCode) {
  if (statusCode != HttpStatus.notFound) {
    return null;
  }
  final isPostLookup =
      request.method == 'GET' &&
      RegExp(r'^/posts/[^/]+$').hasMatch(request.path);
  final isLikeRequest =
      request.method == 'POST' &&
      RegExp(r'^/posts/[^/]+/like$').hasMatch(request.path);
  return isPostLookup || isLikeRequest ? 'post not found' : 'not found';
}
