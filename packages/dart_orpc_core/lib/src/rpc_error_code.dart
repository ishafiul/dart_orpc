enum RpcErrorCode {
  badRequest('BAD_REQUEST', 400),
  unauthorized('UNAUTHORIZED', 401),
  forbidden('FORBIDDEN', 403),
  notFound('NOT_FOUND', 404),
  conflict('CONFLICT', 409),
  requestTimeout('REQUEST_TIMEOUT', 408),
  payloadTooLarge('PAYLOAD_TOO_LARGE', 413),
  unsupportedMediaType('UNSUPPORTED_MEDIA_TYPE', 415),
  headersTooLarge('HEADERS_TOO_LARGE', 431),
  cancelled('CANCELLED', 499),
  resourceExhausted('RESOURCE_EXHAUSTED', 429),
  unavailable('UNAVAILABLE', 503),
  deadlineExceeded('DEADLINE_EXCEEDED', 504),
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
