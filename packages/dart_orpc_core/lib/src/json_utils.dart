import 'dart:convert';
import 'dart:collection';

import 'rpc_exception.dart';

typedef JsonObject = Map<String, Object?>;

JsonObject expectJsonObject(Object? value, {required String context}) {
  if (value is Map<String, Object?>) {
    return value;
  }

  if (value is Map) {
    return Map<String, Object?>.from(value);
  }

  throw RpcException.badRequest('$context must be a JSON object.');
}

Null expectNoRpcInput(Object? value, {required String context}) {
  if (value == null) {
    return null;
  }

  if (value is Map && value.isEmpty) {
    return null;
  }

  throw RpcException.badRequest('$context does not accept input.');
}

String expectStringField(
  JsonObject json,
  String field, {
  bool nonEmpty = false,
}) {
  final value = json[field];
  if (value is! String) {
    throw RpcException.badRequest('Field "$field" must be a string.');
  }

  if (nonEmpty && value.trim().isEmpty) {
    throw RpcException.badRequest('Field "$field" must not be empty.');
  }

  return value;
}

JsonObject normalizeJsonObject(Object? value, {required String context}) {
  return expectJsonObject(_JsonNormalizer().copy(value), context: context);
}

final class _JsonNormalizer {
  final Set<Object> _active = HashSet.identity();

  Object? copy(Object? value, {bool allowToJson = true}) {
    if (value == null ||
        value is String ||
        value is bool ||
        (value is num && value.isFinite))
      return value;
    if (value is List) {
      _enter(value);
      try {
        final length = value.length;
        return [
          for (var index = 0; index < length; index++) copy(value[index]),
        ];
      } finally {
        _active.remove(value);
      }
    }
    if (value is Map) {
      // Match JsonEncoder's snapshot before invoking nested toJson methods.
      final pairs = <Object?>[];
      var stringKeys = true;
      for (final entry in value.entries) {
        if (entry.key is! String) stringKeys = false;
        pairs.add(entry.key);
        pairs.add(entry.value);
      }
      if (stringKeys) {
        _enter(value);
        try {
          return <String, Object?>{
            for (var index = 0; index < pairs.length; index += 2)
              pairs[index] as String: copy(pairs[index + 1]),
          };
        } finally {
          _active.remove(value);
        }
      }
    }
    if (!allowToJson) throw JsonUnsupportedObjectError(value);
    final object = value;
    _enter(object);
    try {
      // toJson is intentionally an untyped serialization boundary, as in jsonEncode.
      final Object? encoded = (object as dynamic).toJson();
      return copy(encoded, allowToJson: false);
    } catch (error) {
      throw JsonUnsupportedObjectError(object, cause: error);
    } finally {
      _active.remove(object);
    }
  }

  void _enter(Object value) {
    if (!_active.add(value)) throw JsonCyclicError(value);
  }
}
