import 'json_utils.dart';

final class RpcSuccessResponse {
  const RpcSuccessResponse({required this.data});

  final Object? data;

  JsonObject toJson() => {'data': data};
}

final class RpcErrorBody {
  const RpcErrorBody({required this.code, required this.message, this.details});

  final String code;
  final String message;

  /// Client-visible structured context. The `issues` key is reserved for
  /// framework validation issues. Null and empty details are omitted.
  final JsonObject? details;

  JsonObject toJson() {
    final details = this.details;
    return {
      'code': code,
      'message': message,
      if (details != null && details.isNotEmpty) 'details': details,
    };
  }
}

final class RpcErrorResponse {
  const RpcErrorResponse({required this.error});

  final RpcErrorBody error;

  JsonObject toJson() => {'error': error.toJson()};
}
