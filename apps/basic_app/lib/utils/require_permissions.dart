import 'package:dart_orpc/dart_orpc.dart';

@RpcMetadata('permissions')
final class RequirePermissions {
  const RequirePermissions({this.anyOf, this.allOf})
    : assert(
        (anyOf == null) != (allOf == null),
        'RequirePermissions expects exactly one of anyOf or allOf.',
      );

  final List<String>? anyOf;
  final List<String>? allOf;
}

final class PermissionRule {
  const PermissionRule({this.anyOf, this.allOf})
    : assert(
        (anyOf == null) != (allOf == null),
        'PermissionRule expects exactly one of anyOf or allOf.',
      );

  final List<String>? anyOf;
  final List<String>? allOf;

  factory PermissionRule.fromMetadata(
    JsonObject metadata, {
    required String procedure,
  }) {
    final anyOf = _readPermissionList(
      metadata,
      field: 'anyOf',
      procedure: procedure,
    );
    final allOf = _readPermissionList(
      metadata,
      field: 'allOf',
      procedure: procedure,
    );
    if ((anyOf == null) == (allOf == null)) {
      throw RpcException.internalError(
        'Permission metadata for "$procedure" must declare exactly one of '
        '"anyOf" or "allOf".',
      );
    }

    return PermissionRule(anyOf: anyOf, allOf: allOf);
  }
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
    throw RpcException.internalError(
      'Permission metadata field "$field" for "$procedure" must be a list of strings.',
    );
  }

  final permissions = <String>[];
  for (final item in value) {
    if (item is! String || item.trim().isEmpty) {
      throw RpcException.internalError(
        'Permission metadata field "$field" for "$procedure" must contain non-empty strings.',
      );
    }
    permissions.add(item);
  }

  return permissions;
}
