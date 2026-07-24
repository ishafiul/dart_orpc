class RpcClientException implements Exception {
  const RpcClientException(this.message);

  final String message;

  @override
  String toString() => 'RpcClientException: $message';
}

final class RpcClientConfigurationException extends RpcClientException {
  const RpcClientConfigurationException(super.message);

  factory RpcClientConfigurationException.missingUnary(String method) {
    return RpcClientConfigurationException(
      'RPC method "$method" requires a unary transport.',
    );
  }

  factory RpcClientConfigurationException.missingStreaming(String method) {
    return RpcClientConfigurationException(
      'RPC method "$method" requires a streaming transport.',
    );
  }

  @override
  String toString() => 'RpcClientConfigurationException: $message';
}
