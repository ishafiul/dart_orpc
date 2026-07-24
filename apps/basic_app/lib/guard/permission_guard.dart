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
    final configuredPermissions = context.rpcContext.attributes['permissions'];
    if (configuredPermissions == null) {
      return;
    }
    if (configuredPermissions is! Iterable ||
        configuredPermissions.any((permission) => permission is! String)) {
      throw RpcException.forbidden('Invalid permission context.');
    }
    final granted = configuredPermissions.cast<String>().toSet();
    for (final rule in rules) {
      final anyOf = rule.anyOf;
      if (anyOf != null && anyOf.isNotEmpty && !anyOf.any(granted.contains)) {
        throw RpcException.forbidden('Missing required permission.');
      }
      final allOf = rule.allOf;
      if (allOf != null && !granted.containsAll(allOf)) {
        throw RpcException.forbidden('Missing required permission.');
      }
    }
  }
}
