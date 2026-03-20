enum RpcErrorCode {
  badRequest('BAD_REQUEST', 400),
  unauthorized('UNAUTHORIZED', 401),
  forbidden('FORBIDDEN', 403),
  notFound('NOT_FOUND', 404),
  conflict('CONFLICT', 409),
  internalError('INTERNAL_ERROR', 500);

  const RpcErrorCode(this.wireName, this.statusCode);

  final String wireName;
  final int statusCode;

  static RpcErrorCode? tryParseWireName(String wireName) {
    for (final value in RpcErrorCode.values) {
      if (value.wireName == wireName) {
        return value;
      }
    }

    return null;
  }
}
