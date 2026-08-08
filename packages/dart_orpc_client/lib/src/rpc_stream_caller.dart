import 'package:dart_orpc_core/dart_orpc_core.dart';

import 'rpc_client_exception.dart';
import 'rpc_caller.dart';
import 'rpc_call_options.dart';
import 'rpc_transport.dart';

final class RpcStreamCaller {
  const RpcStreamCaller(this._transport);

  final RpcStreamTransport _transport;

  Stream<T> call<T>({
    required String method,
    Object? input,
    RpcCallOptions? options,
    required RpcResultDecoder<T> decode,
  }) async* {
    final request = RpcRequest(method: method, input: input);
    final events = options == null
        ? _transport.subscribe(request)
        : _transport is RpcStreamTransportWithOptions
        ? _transport.subscribeWithOptions(request, options: options)
        : Stream<Object>.error(
            RpcClientConfigurationException(
              'Transport does not support per-call RPC options.',
            ),
          );

    await for (final event in events) {
      try {
        yield decode(event);
      } on RpcClientException {
        rethrow;
      } catch (error) {
        throw RpcClientException(
          'Failed to decode RPC stream event for "$method": $error',
        );
      }
    }
  }
}
