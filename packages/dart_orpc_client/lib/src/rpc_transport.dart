import 'package:dart_orpc_core/dart_orpc_core.dart';

abstract interface class RpcTransport {
  Future<Object?> send(RpcRequest request);
}
