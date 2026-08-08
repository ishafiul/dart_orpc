import 'package:dart_orpc_core/dart_orpc_core.dart';

import 'rpc_client_exception.dart';
import 'rpc_call_options.dart';

abstract interface class RpcUnaryTransport {
  Future<Object?> send(RpcRequest request);
}

abstract interface class RpcStreamTransport {
  Stream<Object?> subscribe(RpcRequest request);
}

abstract interface class RpcUnaryTransportWithOptions
    implements RpcUnaryTransport {
  Future<Object?> sendWithOptions(
    RpcRequest request, {
    RpcCallOptions? options,
  });
}

abstract interface class RpcStreamTransportWithOptions
    implements RpcStreamTransport {
  Stream<Object?> subscribeWithOptions(
    RpcRequest request, {
    RpcCallOptions? options,
  });
}

abstract interface class RpcDuplexTransport
    implements RpcUnaryTransport, RpcStreamTransport {}

final class RpcClientTransports {
  const RpcClientTransports.unary(RpcUnaryTransport transport)
    : unary = transport,
      streaming = null;

  const RpcClientTransports.streaming(RpcStreamTransport transport)
    : unary = null,
      streaming = transport;

  const RpcClientTransports.duplex(RpcDuplexTransport transport)
    : unary = transport,
      streaming = transport;

  const RpcClientTransports.split({
    required this.unary,
    required this.streaming,
  });

  final RpcUnaryTransport? unary;
  final RpcStreamTransport? streaming;

  RpcUnaryTransport requireUnary(String method) {
    return unary ??
        (throw RpcClientConfigurationException.missingUnary(method));
  }

  RpcStreamTransport requireStreaming(String method) {
    return streaming ??
        (throw RpcClientConfigurationException.missingStreaming(method));
  }
}

typedef RpcTransport = RpcUnaryTransport;
