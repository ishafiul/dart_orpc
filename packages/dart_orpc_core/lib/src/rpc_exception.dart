import 'json_utils.dart';
import 'rpc_error_code.dart';
import 'rpc_output_validation.dart';
import 'rpc_response.dart';
import 'rpc_validation_issue.dart';

final class RpcException implements Exception {
  const RpcException({
    required this.code,
    required this.message,
    this.details,
    this.diagnostic,
  });

  factory RpcException.badRequest(String message, {JsonObject? details}) {
    return RpcException(
      code: RpcErrorCode.badRequest,
      message: message,
      details: details,
    );
  }

  factory RpcException.unauthorized(String message, {JsonObject? details}) {
    return RpcException(
      code: RpcErrorCode.unauthorized,
      message: message,
      details: details,
    );
  }

  factory RpcException.forbidden(String message, {JsonObject? details}) {
    return RpcException(
      code: RpcErrorCode.forbidden,
      message: message,
      details: details,
    );
  }

  factory RpcException.notFound(String message, {JsonObject? details}) {
    return RpcException(
      code: RpcErrorCode.notFound,
      message: message,
      details: details,
    );
  }

  factory RpcException.conflict(String message, {JsonObject? details}) {
    return RpcException(
      code: RpcErrorCode.conflict,
      message: message,
      details: details,
    );
  }

  /// To attach [details], use the [RpcException] constructor.
  factory RpcException.cancelled([String message = 'RPC call was cancelled.']) {
    return RpcException(code: RpcErrorCode.cancelled, message: message);
  }

  factory RpcException.resourceExhausted(
    String message, {
    JsonObject? details,
  }) {
    return RpcException(
      code: RpcErrorCode.resourceExhausted,
      message: message,
      details: details,
    );
  }

  /// To attach [details] or a [diagnostic], use the [RpcException]
  /// constructor.
  factory RpcException.internalError([
    String message = 'Internal server error.',
  ]) {
    return RpcException(code: RpcErrorCode.internalError, message: message);
  }

  factory RpcException.requestTimeout(String message, {JsonObject? details}) {
    return RpcException(
      code: RpcErrorCode.requestTimeout,
      message: message,
      details: details,
    );
  }

  factory RpcException.payloadTooLarge(String message, {JsonObject? details}) {
    return RpcException(
      code: RpcErrorCode.payloadTooLarge,
      message: message,
      details: details,
    );
  }

  factory RpcException.unavailable(String message, {JsonObject? details}) {
    return RpcException(
      code: RpcErrorCode.unavailable,
      message: message,
      details: details,
    );
  }

  factory RpcException.deadlineExceeded(String message, {JsonObject? details}) {
    return RpcException(
      code: RpcErrorCode.deadlineExceeded,
      message: message,
      details: details,
    );
  }

  final RpcErrorCode code;
  final String message;

  /// Client-visible structured context, serialized as `error.details`.
  /// Must not contain secrets or internal diagnostics.
  final JsonObject? details;

  /// Server-only context, such as an [RpcOutputValidationDiagnostic].
  ///
  /// Never serialized: transports send only [code], [message] and
  /// [details]. Server `onError` hooks receive the exception, so they can
  /// read it, and [toString] includes it for logs.
  final Object? diagnostic;

  int get statusCode => code.statusCode;

  /// The framework validation issues in [details], in wire order.
  ///
  /// Malformed entries are skipped and unrecognized codes are kept; the list
  /// is empty when there are no valid issues, for example from an older
  /// server. Raw [details] stay available alongside.
  List<RpcValidationIssue> get validationIssues =>
      parseRpcValidationIssues(details);

  RpcErrorResponse toResponse() {
    return RpcErrorResponse(
      error: RpcErrorBody(
        code: code.wireName,
        message: message,
        details: details,
      ),
    );
  }

  @override
  String toString() {
    final base = 'RpcException(${code.wireName}): $message';
    return diagnostic == null ? base : '$base [$diagnostic]';
  }
}
