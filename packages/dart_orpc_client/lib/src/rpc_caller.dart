import 'package:dart_orpc_core/dart_orpc_core.dart';

import 'rpc_client_exception.dart';
import 'rpc_transport.dart';

typedef RpcResultDecoder<T> = T Function(Object? json);

final class RpcCaller {
  const RpcCaller(this._transport);

  final RpcTransport _transport;

  Future<T> call<T>({
    required String method,
    Object? input,
    required RpcResultDecoder<T> decode,
  }) async {
    final response = await _transport.send(
      RpcRequest(method: method, input: input),
    );

    try {
      return decode(response);
    } on RpcClientException {
      rethrow;
    } catch (error) {
      throw RpcClientException(
        'Failed to decode RPC response for "$method": $error',
      );
    }
  }
}
