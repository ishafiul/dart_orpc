import 'package:dart_orpc/dart_orpc.dart';

const _todoGuardPassed = 'todo.guard.passed';
const _rpcMethodAttribute = 'rpc.method';

const _log = Logger('todo.guard');

final class TodoRouteLoggerGuard implements RpcGuard {
  @override
  void canActivate(RpcGuardContext context) {
    _log.debug(
      _todoGuardPassed,
      attributes: {_rpcMethodAttribute: context.procedure.rpcMethod},
    );
  }
}
