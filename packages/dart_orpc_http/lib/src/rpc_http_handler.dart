import 'dart:convert';
import 'dart:io';

import 'package:dart_orpc_core/dart_orpc_core.dart';

typedef RpcHttpHandler =
    Future<RpcHttpResponse> Function(RpcHttpRequest request);

final class RpcHttpRequest {
  const RpcHttpRequest({
    required this.method,
    required this.path,
    this.headers = const {},
    this.body = '',
  });

  final String method;
  final String path;
  final Map<String, String> headers;
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

RpcHttpHandler createRpcHttpHandler({
  required RpcProcedureRegistry procedures,
}) {
  return (request) async {
    final path = _normalizePath(request.path);
    if (path != '/rpc') {
      return const RpcHttpResponse(
        statusCode: HttpStatus.notFound,
        headers: {'content-type': 'text/plain; charset=utf-8'},
        body: 'Not Found',
      );
    }

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
      final context = RpcContext(
        headers: Map<String, String>.unmodifiable(request.headers),
        httpMethod: request.method,
        path: path,
      );

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
  };
}

String _normalizePath(String path) {
  if (path.isEmpty) {
    return '/';
  }

  return path.startsWith('/') ? path : '/$path';
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
