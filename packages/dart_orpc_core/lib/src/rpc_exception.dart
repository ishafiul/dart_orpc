import 'rpc_error_code.dart';
import 'rpc_response.dart';

final class RpcException implements Exception {
  const RpcException({required this.code, required this.message});

  factory RpcException.badRequest(String message) {
    return RpcException(code: RpcErrorCode.badRequest, message: message);
  }

  factory RpcException.unauthorized(String message) {
    return RpcException(code: RpcErrorCode.unauthorized, message: message);
  }

  factory RpcException.forbidden(String message) {
    return RpcException(code: RpcErrorCode.forbidden, message: message);
  }

  factory RpcException.notFound(String message) {
    return RpcException(code: RpcErrorCode.notFound, message: message);
  }

  factory RpcException.conflict(String message) {
    return RpcException(code: RpcErrorCode.conflict, message: message);
  }

  factory RpcException.internalError([
    String message = 'Internal server error.',
  ]) {
    return RpcException(code: RpcErrorCode.internalError, message: message);
  }

  final RpcErrorCode code;
  final String message;

  int get statusCode => code.statusCode;

  RpcErrorResponse toResponse() {
    return RpcErrorResponse(
      error: RpcErrorBody(code: code.wireName, message: message),
    );
  }

  @override
  String toString() => 'RpcException(${code.wireName}): $message';
}
