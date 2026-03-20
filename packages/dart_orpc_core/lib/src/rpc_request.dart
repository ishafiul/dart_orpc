import 'json_utils.dart';
import 'rpc_exception.dart';

final class RpcRequest {
  const RpcRequest({required this.method, this.input});

  factory RpcRequest.fromJson(Object? json) {
    final object = expectJsonObject(json, context: 'RPC request');
    final method = object['method'];

    if (method is! String || method.trim().isEmpty) {
      throw RpcException.badRequest(
        'RPC request "method" must be a non-empty string.',
      );
    }

    return RpcRequest(method: method, input: object['input']);
  }

  final String method;
  final Object? input;

  JsonObject toJson() {
    return {'method': method, 'input': input};
  }
}
