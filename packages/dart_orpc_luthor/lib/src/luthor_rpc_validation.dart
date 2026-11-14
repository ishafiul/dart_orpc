import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:luthor/luthor.dart';

/// Validates JSON and decodes it into a [T], like luthor_generator's
/// `$XValidate` functions.
///
/// The validator must not mutate the JSON it receives.
typedef LuthorValidator<T> = ValidationResult<T> Function(Object? json);

/// Validates serialized JSON without constructing a DTO from it, like a
/// generated schema's `validate` method.
///
/// The validator must not mutate the JSON it receives.
typedef LuthorJsonValidator = ValidationResult<Object?> Function(Object? json);

/// Validates RPC input and decodes it with [validate].
///
/// Keys the DTO does not declare are handled by its schema: luthor strips
/// them by default. Failures, including a throwing `fromJson`, become
/// `BAD_REQUEST`.
T decodeRpcInputWithLuthor<T>({
  required Object? rawInput,
  required String method,
  required LuthorValidator<T> validate,
}) {
  final object = expectJsonObject(
    rawInput,
    context: 'RPC method "$method" input',
  );

  return switch (validate(object)) {
    ValidationSuccess<T>(:final data) => data,
    ValidationFailure<T>(:final issues) => throw RpcException.badRequest(
      'Invalid RPC input for "$method": ${_formatIssues(issues)}',
    ),
  };
}

/// Encodes [output] with [toJson] and checks it by decoding it again with
/// [validate]. Failures become `INTERNAL_ERROR`.
JsonObject encodeRpcOutputWithLuthor<T>({
  required T output,
  required String method,
  required JsonObject Function(T output) toJson,
  required LuthorValidator<T> validate,
}) {
  final json = normalizeJsonObject(
    toJson(output),
    context: 'RPC method "$method" output',
  );

  return _validatedOutput(json, method, validate(json));
}

/// Encodes [output] with [toJson] and validates the JSON without
/// deserializing it back into a DTO.
///
/// Generated code uses this for output DTOs whose runtime type the handler
/// has already checked. Failures become `INTERNAL_ERROR`.
JsonObject encodeRpcOutputJsonWithLuthor<T>({
  required T output,
  required String method,
  required JsonObject Function(T output) toJson,
  required LuthorJsonValidator validateJson,
}) {
  final json = normalizeJsonObject(
    toJson(output),
    context: 'RPC method "$method" output',
  );

  return _validatedOutput(json, method, validateJson(json));
}

JsonObject _validatedOutput<T>(
  JsonObject json,
  String method,
  ValidationResult<T> result,
) => switch (result) {
  ValidationSuccess<T>() => json,
  ValidationFailure<T>(:final issues) => throw RpcException.internalError(
    'Invalid RPC output for "$method": ${_formatIssues(issues)}',
  ),
};

/// Each issue as `path: message`, or just the message at the root, in
/// luthor's order.
String _formatIssues(List<ValidationIssue> issues) => issues
    .map(
      (issue) => issue.errorPath.isEmpty
          ? issue.message
          : '${issue.errorPath}: ${issue.message}',
    )
    .join('; ');
