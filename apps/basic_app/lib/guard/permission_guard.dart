import 'package:basic_app/utils/require_permissions.dart';
import 'package:dart_orpc/dart_orpc.dart';

const todoPermissionMetadataKey = 'permissions';

final class TodoPermissionGuard implements RpcGuard {
  @override
  void canActivate(RpcGuardContext context) {
    final rules = [
      for (final metadata in context.procedure.metadataValues(
        todoPermissionMetadataKey,
      ))
        PermissionRule.fromMetadata(
          metadata,
          procedure: context.procedure.rpcMethod,
        ),
    ];
    if (rules.isEmpty) {
      return;
    }
    print(rules.map((rule) => rule.anyOf?.join(', ')));
    print(rules.map((rule) => rule.allOf?.join(', ')));
  }
}
