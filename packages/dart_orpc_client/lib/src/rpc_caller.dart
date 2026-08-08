import 'package:dart_orpc_core/dart_orpc_core.dart';

import 'rpc_client_exception.dart';
import 'rpc_call_options.dart';
import 'rpc_transport.dart';

typedef RpcResultDecoder<T> = T Function(Object? json);

final class RpcCaller {
  const RpcCaller(this._transport);

  final RpcUnaryTransport _transport;

  Future<T> call<T>({
    required String method,
    Object? input,
    RpcCallOptions? options,
    required RpcResultDecoder<T> decode,
  }) async {
    final request = RpcRequest(method: method, input: input);
    final response = options == null
        ? await _transport.send(request)
        : _transport is RpcUnaryTransportWithOptions
        ? await _transport.sendWithOptions(request, options: options)
        : throw RpcClientConfigurationException(
            'Transport does not support per-call RPC options.',
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
