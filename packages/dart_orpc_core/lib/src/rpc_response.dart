import 'json_utils.dart';

final class RpcSuccessResponse {
  const RpcSuccessResponse({required this.data});

  final Object? data;

  JsonObject toJson() => {'data': data};
}

final class RpcErrorBody {
  const RpcErrorBody({required this.code, required this.message});

  final String code;
  final String message;

  JsonObject toJson() => {'code': code, 'message': message};
}

final class RpcErrorResponse {
  const RpcErrorResponse({required this.error});

  final RpcErrorBody error;

  JsonObject toJson() => {'error': error.toJson()};
}
