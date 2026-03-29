import 'package:dart_orpc/dart_orpc.dart';

final class TodoRouteLoggerGuard implements RpcGuard {
  @override
  void canActivate(RpcGuardContext context) {
    print(
      '[todo-guard] ${context.procedure.rpcMethod} '
      '(${context.rpcContext.httpMethod} ${context.rpcContext.path})',
    );
  }
}
