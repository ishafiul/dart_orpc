import 'json_utils.dart';
import 'rpc_exception.dart';
import 'rpc_response.dart';

/// Reported when an [RpcException]'s details could not be encoded and were
/// dropped from the wire envelope.
final class RpcErrorDetailsEncodingException implements Exception {
  const RpcErrorDetailsEncodingException({
    required this.exception,
    required this.cause,
  });

  /// The exception whose details were dropped.
  final RpcException exception;

  /// The normalizer failure, such as a `JsonUnsupportedObjectError` or a
  /// `JsonCyclicError`.
  final Object cause;

  @override
  String toString() =>
      'RpcErrorDetailsEncodingException(${exception.code.wireName}): '
      'details dropped: $cause';
}

/// The wire envelope for an [RpcException], produced by [encodeRpcError].
final class RpcErrorEncoding {
  const RpcErrorEncoding._({
    required this.exception,
    required this.json,
    this.detailsError,
    this.detailsStackTrace,
  });

  /// The exception that was encoded.
  final RpcException exception;

  /// The `{"error": {...}}` envelope, safe to pass to `jsonEncode`.
  final JsonObject json;

  /// Set when the details could not be encoded and were dropped.
  final RpcErrorDetailsEncodingException? detailsError;

  /// The stack trace of the normalizer failure behind [detailsError].
  final StackTrace? detailsStackTrace;

  /// The same error with its details removed, keeping the code and message.
  RpcErrorEncoding withoutDetails() {
    return RpcErrorEncoding._(
      exception: exception,
      json: _envelope(exception, null),
    );
  }
}

/// Encodes [exception] into its wire envelope.
///
/// Details are normalized like procedure outputs, so objects with `toJson()`
/// are converted. When normalization fails, the envelope keeps the real code
/// and message without details, and the failure is returned in
/// [RpcErrorEncoding.detailsError] for reporting.
RpcErrorEncoding encodeRpcError(RpcException exception) {
  final details = exception.details;
  if (details == null || details.isEmpty) {
    return RpcErrorEncoding._(
      exception: exception,
      json: _envelope(exception, null),
    );
  }

  try {
    final normalized = normalizeJsonObject(
      details,
      context: 'RPC error details',
    );
    return RpcErrorEncoding._(
      exception: exception,
      json: _envelope(exception, normalized),
    );
  } catch (error, stackTrace) {
    return RpcErrorEncoding._(
      exception: exception,
      json: _envelope(exception, null),
      detailsError: RpcErrorDetailsEncodingException(
        exception: exception,
        cause: error,
      ),
      detailsStackTrace: stackTrace,
    );
  }
}

JsonObject _envelope(RpcException exception, JsonObject? details) {
  return RpcErrorResponse(
    error: RpcErrorBody(
      code: exception.code.wireName,
      message: exception.message,
      details: details,
    ),
  ).toJson();
}
