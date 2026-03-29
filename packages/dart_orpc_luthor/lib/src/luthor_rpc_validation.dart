import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:luthor/luthor.dart';

typedef LuthorSchemaValidator<T> =
    SchemaValidationResult<T> Function(Map<String, dynamic> json);

T decodeRpcInputWithLuthor<T>({
  required Object? rawInput,
  required String method,
  required LuthorSchemaValidator<T> validate,
}) {
  final object = expectJsonObject(
    rawInput,
    context: 'RPC method "$method" input',
  );
  final result = validate(Map<String, dynamic>.from(object));

  return switch (result) {
    SchemaValidationSuccess<T>(data: final data) => data,
    SchemaValidationError<T>(errors: final errors) =>
      throw RpcException.badRequest(
        'Invalid RPC input for "$method": ${_formatLuthorErrors(errors)}',
      ),
  };
}

JsonObject encodeRpcOutputWithLuthor<T>({
  required T output,
  required String method,
  required JsonObject Function(T output) toJson,
  required LuthorSchemaValidator<T> validate,
}) {
  final json = normalizeJsonObject(
    toJson(output),
    context: 'RPC method "$method" output',
  );
  final result = validate(Map<String, dynamic>.from(json));

  return switch (result) {
    SchemaValidationSuccess<T>() => json,
    SchemaValidationError<T>(errors: final errors) =>
      throw RpcException.internalError(
        'Invalid RPC output for "$method": ${_formatLuthorErrors(errors)}',
      ),
  };
}

String _formatLuthorErrors(Map<String, dynamic> errors) {
  final messages = <String>[];

  void visit(String path, Object? value) {
    if (value is List) {
      for (final item in value) {
        if (item is! String) {
          continue;
        }

        messages.add(path.isEmpty ? item : '$path: $item');
      }
      return;
    }

    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        final childPath = path.isEmpty ? key : '$path.$key';
        visit(childPath, entry.value);
      }
    }
  }

  visit('', errors);

  if (messages.isEmpty) {
    return 'Validation failed.';
  }

  return messages.join('; ');
}
