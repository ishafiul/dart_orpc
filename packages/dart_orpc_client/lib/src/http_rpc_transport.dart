import 'dart:convert';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:http/http.dart' as http;

import 'http_rpc_interceptor.dart';
import 'rpc_client_exception.dart';
import 'rpc_call_options.dart';
import 'rpc_transport.dart';

final class HttpRpcTransport implements RpcUnaryTransportWithOptions {
  HttpRpcTransport({
    required String baseUrl,
    String endpointPath = '/rpc',
    http.Client? client,
    List<RpcInterceptorCore> interceptors = const [],
    Map<String, String> headers = const {},
    this.bearerTokenProvider,
  }) : _baseUri = Uri.parse(baseUrl),
       _endpointPath = _normalizeEndpointPath(endpointPath),
       _client = client ?? http.Client(),
       _interceptors = List.unmodifiable(interceptors),
       _headers = Map.unmodifiable(headers),
       _ownsClient = client == null;

  final Uri _baseUri;
  final String _endpointPath;
  final http.Client _client;
  final List<RpcInterceptorCore> _interceptors;
  final Map<String, String> _headers;
  final RpcBearerTokenProvider? bearerTokenProvider;
  final bool _ownsClient;

  Uri get endpointUri => _baseUri.resolve(_endpointPath);

  @override
  Future<Object?> send(RpcRequest request) => sendWithOptions(request);

  @override
  Future<Object?> sendWithOptions(
    RpcRequest request, {
    RpcCallOptions? options,
  }) async {
    final body = _encodeRequest(request);
    final httpRequest = HttpRpcRequest(
      method: 'POST',
      uri: endpointUri,
      headers: await _buildHeaders(options),
      body: body,
      rpcRequest: request,
    );

    final HttpRpcResponse response;
    try {
      response = await _HttpRpcPipeline(
        interceptors: _interceptors,
        terminal: _sendHttpRequest,
      ).send(httpRequest);
    } on RpcClientException {
      rethrow;
    } on Object catch (error) {
      throw RpcClientException(
        'Failed to send RPC request to ${httpRequest.uri}: $error',
      );
    }

    return _parseResponse(response);
  }

  Future<Map<String, String>> _buildHeaders(RpcCallOptions? options) async {
    final headers = <String, String>{
      'content-type': 'application/json; charset=utf-8',
      'accept': 'application/json',
      ..._headers,
      if (bearerTokenProvider != null)
        ..._authorizationHeader(await bearerTokenProvider!()),
      ...?options?.headers,
    };
    final bearerToken = options?.bearerToken;
    if (bearerToken != null) {
      headers['authorization'] = _formatBearerToken(bearerToken);
    }
    return _normalizeHeaderNames(headers);
  }

  static String _formatBearerToken(String token) => 'Bearer $token';

  static Map<String, String> _authorizationHeader(String? token) {
    return token == null
        ? const {}
        : {'authorization': _formatBearerToken(token)};
  }

  static Map<String, String> _normalizeHeaderNames(
    Map<String, String> headers,
  ) {
    final normalized = <String, String>{};
    for (final entry in headers.entries) {
      String? existingKey;
      for (final key in normalized.keys) {
        if (key.toLowerCase() == entry.key.toLowerCase()) {
          existingKey = key;
          break;
        }
      }
      if (existingKey != null) {
        normalized.remove(existingKey);
      }
      normalized[entry.key] = entry.value;
    }
    return Map.unmodifiable(normalized);
  }

  Future<HttpRpcResponse> _sendHttpRequest(HttpRpcRequest request) async {
    final http.Response response;
    try {
      final rawRequest = http.Request(request.method, request.uri)
        ..headers.addAll(request.headers)
        ..body = request.body;
      final streamedResponse = await _client.send(rawRequest);
      response = await http.Response.fromStream(streamedResponse);
    } on Object catch (error) {
      throw RpcClientException(
        'Failed to send RPC request to ${request.uri}: $error',
      );
    }

    return HttpRpcResponse(
      statusCode: response.statusCode,
      headers: response.headers,
      body: response.body,
      request: request,
    );
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  String _encodeRequest(RpcRequest request) {
    try {
      return jsonEncode(request.toJson());
    } on Object catch (error) {
      throw RpcClientException(
        'Failed to encode RPC request for "${request.method}": $error',
      );
    }
  }

  Object? _parseResponse(HttpRpcResponse response) {
    final responseUri = response.request.uri;
    if (response.body.isEmpty) {
      throw RpcClientException('RPC response from $responseUri was empty.');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw RpcClientException(
        'RPC response from $responseUri was not valid JSON.',
      );
    }

    final object = _expectClientJsonObject(
      value: decoded,
      context: 'RPC response from $responseUri',
    );
    if (object.containsKey('error')) {
      final error = _expectClientJsonObject(
        value: object['error'],
        context: 'RPC error response from $responseUri',
      );
      final code = _expectClientStringField(error, 'code');
      final message = _expectClientStringField(error, 'message');
      final parsedCode = RpcErrorCode.tryParseWireName(code);

      if (parsedCode == null) {
        throw RpcClientException(
          'RPC response from $responseUri returned unknown error code "$code".',
        );
      }

      throw RpcException(code: parsedCode, message: message);
    }

    if (response.statusCode >= 400) {
      throw RpcClientException(
        'RPC response from $responseUri returned HTTP ${response.statusCode} without an RPC error envelope.',
      );
    }

    if (!object.containsKey('data')) {
      throw RpcClientException(
        'RPC response from $responseUri must contain a "data" field.',
      );
    }

    return object['data'];
  }

  static String _normalizeEndpointPath(String endpointPath) {
    if (endpointPath.isEmpty) {
      return '/rpc';
    }

    return endpointPath.startsWith('/') ? endpointPath : '/$endpointPath';
  }

  static JsonObject _expectClientJsonObject({
    required Object? value,
    required String context,
  }) {
    try {
      return expectJsonObject(value, context: context);
    } on RpcException catch (error) {
      throw RpcClientException(error.message);
    }
  }

  static String _expectClientStringField(JsonObject json, String field) {
    try {
      return expectStringField(json, field, nonEmpty: true);
    } on RpcException catch (error) {
      throw RpcClientException(error.message);
    }
  }
}

typedef _HttpRpcTerminal =
    Future<HttpRpcResponse> Function(HttpRpcRequest request);

final class _HttpRpcPipeline {
  const _HttpRpcPipeline({required this.interceptors, required this.terminal});

  final List<RpcInterceptorCore> interceptors;
  final _HttpRpcTerminal terminal;

  Future<HttpRpcResponse> send(HttpRpcRequest request) {
    return _HttpRpcPipelineHandler(
      interceptors: interceptors,
      terminal: terminal,
      index: 0,
    ).next(request);
  }
}

final class _HttpRpcPipelineHandler implements HttpRpcHandler {
  const _HttpRpcPipelineHandler({
    required this.interceptors,
    required this.terminal,
    required this.index,
  });

  final List<RpcInterceptorCore> interceptors;
  final _HttpRpcTerminal terminal;
  final int index;

  @override
  Future<HttpRpcResponse> next(HttpRpcRequest request) {
    if (index == interceptors.length) {
      return terminal(request);
    }

    return interceptors[index].intercept(
      request,
      _HttpRpcPipelineHandler(
        interceptors: interceptors,
        terminal: terminal,
        index: index + 1,
      ),
    );
  }
}
