import 'package:basic_app/utils/require_permissions.dart';
import 'package:dart_orpc/dart_orpc.dart';

const _invalidPermissionContext = 'Invalid permission context.';
const _missingPermission = 'Missing required permission.';

final class TodoPermissionGuard implements RpcGuard {
  @override
  void canActivate(RpcGuardContext context) {
    final rules = [
      for (final metadata in context.procedure.metadataValues(
        permissionMetadataKey,
      ))
        PermissionRule.fromMetadata(
          metadata,
          procedure: context.procedure.rpcMethod,
        ),
    ];
    if (rules.isEmpty) {
      return;
    }
    final configuredPermissions =
        context.rpcContext.attributes[grantedPermissionsAttribute];
    if (configuredPermissions == null) {
      return;
    }
    if (configuredPermissions is! Iterable ||
        configuredPermissions.any((permission) => permission is! String)) {
      throw RpcException.forbidden(_invalidPermissionContext);
    }
    final granted = configuredPermissions.cast<String>().toSet();
    for (final rule in rules) {
      final anyOf = rule.anyOf;
      if (anyOf != null && anyOf.isNotEmpty && !anyOf.any(granted.contains)) {
        throw RpcException.forbidden(_missingPermission);
      }
      final allOf = rule.allOf;
      if (allOf != null && !granted.containsAll(allOf)) {
        throw RpcException.forbidden(_missingPermission);
      }
    }
  }
}
