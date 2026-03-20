final class RpcContext {
  const RpcContext({
    required this.headers,
    this.httpMethod = 'POST',
    this.path = '/rpc',
  });

  final Map<String, String> headers;
  final String httpMethod;
  final String path;
}
