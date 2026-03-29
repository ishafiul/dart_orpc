import 'dart:async';

import 'procedure_metadata.dart';
import 'rpc_context.dart';

final class RpcGuardContext {
  const RpcGuardContext({
    required this.rpcContext,
    required this.procedure,
    this.input,
  });

  final RpcContext rpcContext;
  final ProcedureMetadata procedure;
  final Object? input;
}

abstract interface class RpcGuard {
  FutureOr<void> canActivate(RpcGuardContext context);
}

Future<void> runRpcGuards(
  Iterable<RpcGuard> guards, {
  required RpcContext rpcContext,
  required ProcedureMetadata procedure,
  Object? input,
}) async {
  final guardContext = RpcGuardContext(
    rpcContext: rpcContext,
    procedure: procedure,
    input: input,
  );
  for (final guard in guards) {
    await guard.canActivate(guardContext);
  }
}
