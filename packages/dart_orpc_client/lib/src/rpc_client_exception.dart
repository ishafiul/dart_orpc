final class RpcClientException implements Exception {
  const RpcClientException(this.message);

  final String message;

  @override
  String toString() => 'RpcClientException: $message';
}
