import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:luthor/luthor.dart';

typedef LuthorSchemaValidator<T> =
    SchemaValidationResult<T> Function(Map<String, dynamic> json);

/// Schema validator callback for read-only input maps.
///
/// The callback must not mutate [json]. Supplying it lets the bridge avoid a
/// defensive copy when the validator only inspects input.
typedef LuthorReadOnlySchemaValidator<T> = LuthorSchemaValidator<T>;

/// Validates serialized JSON without constructing a DTO from it.
///
/// The callback must not mutate [json]. The map is returned as the encoded
/// output after validation succeeds.
typedef LuthorJsonSchemaValidator =
    SchemaValidationResult<JsonObject> Function(Map<String, dynamic> json);

T decodeRpcInputWithLuthor<T>({
  required Object? rawInput,
  required String method,
  required LuthorSchemaValidator<T> validate,
  LuthorReadOnlySchemaValidator<T>? validateReadOnly,
}) {
  final object = expectJsonObject(
    rawInput,
    context: 'RPC method "$method" input',
  );
  final validationInput = validateReadOnly == null
      ? Map<String, dynamic>.from(object)
      : object;
  final result = (validateReadOnly ?? validate)(validationInput);

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

  return _validatedOutput(json, method, result);
}

/// Encodes and validates output JSON without deserializing it back into a DTO.
///
/// Generated schemas use this for output DTOs whose runtime type has already
/// been checked by the handler. Custom validators must not mutate [json].
JsonObject encodeRpcOutputJsonWithLuthor<T>({
  required T output,
  required String method,
  required JsonObject Function(T output) toJson,
  required LuthorJsonSchemaValidator validateJson,
}) {
  final json = normalizeJsonObject(
    toJson(output),
    context: 'RPC method "$method" output',
  );
  final result = validateJson(json);

  return _validatedOutput(json, method, result);
}

JsonObject _validatedOutput<T>(
  JsonObject json,
  String method,
  SchemaValidationResult<T> result,
) => switch (result) {
  SchemaValidationSuccess<T>() => json,
  SchemaValidationError<T>(errors: final errors) =>
    throw RpcException.internalError(
      'Invalid RPC output for "$method": ${_formatLuthorErrors(errors)}',
    ),
};

String _formatLuthorErrors(Map<String, dynamic> errors) {
  final buffer = StringBuffer();
  var hasMessages = false;

  void writeMessage(String path, String message) {
    if (hasMessages) buffer.write('; ');
    if (path.isNotEmpty) {
      buffer
        ..write(path)
        ..write(': ');
    }
    buffer.write(message);
    hasMessages = true;
  }

  void visit(String path, Object? value) {
    if (value is List) {
      for (final item in value) {
        if (item is! String) {
          continue;
        }

        writeMessage(path, item);
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

  return hasMessages ? buffer.toString() : 'Validation failed.';
}
