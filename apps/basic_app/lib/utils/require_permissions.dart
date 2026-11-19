import 'package:dart_orpc/dart_orpc.dart';

const permissionMetadataKey = 'permissions';
const grantedPermissionsAttribute = 'permissions';

const _anyOfField = 'anyOf';
const _allOfField = 'allOf';
const _requirePermissionsShape =
    'RequirePermissions expects exactly one of anyOf or allOf.';
const _permissionRuleShape =
    'PermissionRule expects exactly one of anyOf or allOf.';

String _ambiguousRule(String procedure) =>
    'Permission metadata for "$procedure" must declare exactly one of '
    '"$_anyOfField" or "$_allOfField".';

String _notAList(String field, String procedure) =>
    'Permission metadata field "$field" for "$procedure" must be a list of '
    'strings.';

String _emptyPermission(String field, String procedure) =>
    'Permission metadata field "$field" for "$procedure" must contain '
    'non-empty strings.';

@RpcMetadata(permissionMetadataKey)
final class RequirePermissions {
  const RequirePermissions({this.anyOf, this.allOf})
    : assert(
        (anyOf == null) != (allOf == null),
        _requirePermissionsShape,
      );

  final List<String>? anyOf;
  final List<String>? allOf;
}

final class PermissionRule {
  const PermissionRule({this.anyOf, this.allOf})
    : assert(
        (anyOf == null) != (allOf == null),
        _permissionRuleShape,
      );

  factory PermissionRule.fromMetadata(
    JsonObject metadata, {
    required String procedure,
  }) {
    final anyOf = _readPermissionList(
      metadata,
      field: _anyOfField,
      procedure: procedure,
    );
    final allOf = _readPermissionList(
      metadata,
      field: _allOfField,
      procedure: procedure,
    );
    if ((anyOf == null) == (allOf == null)) {
      throw RpcException.internalError(_ambiguousRule(procedure));
    }

    return PermissionRule(anyOf: anyOf, allOf: allOf);
  }

  final List<String>? anyOf;
  final List<String>? allOf;
}

List<String>? _readPermissionList(
  JsonObject metadata, {
  required String field,
  required String procedure,
}) {
  final value = metadata[field];
  if (value == null) {
    return null;
  }
  if (value is! List) {
    throw RpcException.internalError(_notAList(field, procedure));
  }

  final permissions = <String>[];
  for (final item in value) {
    if (item is! String || item.trim().isEmpty) {
      throw RpcException.internalError(_emptyPermission(field, procedure));
    }
    permissions.add(item);
  }

  return permissions;
}
