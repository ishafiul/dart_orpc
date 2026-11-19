import 'dart:io';

import 'package:dart_orpc/dart_orpc.dart';

String _guardLine(RpcGuardContext context) =>
    '[todo-guard] ${context.procedure.rpcMethod} '
    '(${context.rpcContext.httpMethod} ${context.rpcContext.path})';

final class TodoRouteLoggerGuard implements RpcGuard {
  @override
  void canActivate(RpcGuardContext context) {
    stdout.writeln(_guardLine(context));
  }
}
