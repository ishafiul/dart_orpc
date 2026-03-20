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
