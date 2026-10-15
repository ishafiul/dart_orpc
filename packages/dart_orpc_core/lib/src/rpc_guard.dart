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
  final iterator = guards.iterator;
  if (!iterator.moveNext()) return;
  final guardContext = RpcGuardContext(
    rpcContext: rpcContext,
    procedure: procedure,
    input: input,
  );
  do {
    await iterator.current.canActivate(guardContext);
  } while (iterator.moveNext());
}
