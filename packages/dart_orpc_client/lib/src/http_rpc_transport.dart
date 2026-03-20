import 'dart:convert';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:http/http.dart' as http;

import 'rpc_client_exception.dart';
import 'rpc_transport.dart';

final class HttpRpcTransport implements RpcTransport {
  HttpRpcTransport({
    required String baseUrl,
    String endpointPath = '/rpc',
    http.Client? client,
  }) : _baseUri = Uri.parse(baseUrl),
       _endpointPath = _normalizeEndpointPath(endpointPath),
       _client = client ?? http.Client(),
       _ownsClient = client == null;

  final Uri _baseUri;
  final String _endpointPath;
  final http.Client _client;
  final bool _ownsClient;

  Uri get endpointUri => _baseUri.resolve(_endpointPath);

  @override
  Future<Object?> send(RpcRequest request) async {
    final body = _encodeRequest(request);

    late final http.Response response;
    try {
      response = await _client.post(
        endpointUri,
        headers: const {
          'content-type': 'application/json; charset=utf-8',
          'accept': 'application/json',
        },
        body: body,
      );
    } on Exception catch (error) {
      throw RpcClientException(
        'Failed to send RPC request to $endpointUri: $error',
      );
    }

    return _parseResponse(response);
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

  Object? _parseResponse(http.Response response) {
    if (response.body.isEmpty) {
      throw RpcClientException('RPC response from $endpointUri was empty.');
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw RpcClientException(
        'RPC response from $endpointUri was not valid JSON.',
      );
    }

    final object = _expectClientJsonObject(
      value: decoded,
      context: 'RPC response from $endpointUri',
    );
    if (object.containsKey('error')) {
      final error = _expectClientJsonObject(
        value: object['error'],
        context: 'RPC error response from $endpointUri',
      );
      final code = _expectClientStringField(error, 'code');
      final message = _expectClientStringField(error, 'message');
      final parsedCode = RpcErrorCode.tryParseWireName(code);

      if (parsedCode == null) {
        throw RpcClientException(
          'RPC response from $endpointUri returned unknown error code "$code".',
        );
      }

      throw RpcException(code: parsedCode, message: message);
    }

    if (response.statusCode >= 400) {
      throw RpcClientException(
        'RPC response from $endpointUri returned HTTP ${response.statusCode} without an RPC error envelope.',
      );
    }

    if (!object.containsKey('data')) {
      throw RpcClientException(
        'RPC response from $endpointUri must contain a "data" field.',
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
