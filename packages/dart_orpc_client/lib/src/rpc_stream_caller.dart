import 'package:dart_orpc_core/dart_orpc_core.dart';

import 'rpc_client_exception.dart';
import 'rpc_caller.dart';
import 'rpc_transport.dart';

final class RpcStreamCaller {
  const RpcStreamCaller(this._transport);

  final RpcStreamTransport _transport;

  Stream<T> call<T>({
    required String method,
    Object? input,
    required RpcResultDecoder<T> decode,
  }) async* {
    final events = _transport.subscribe(
      RpcRequest(method: method, input: input),
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
