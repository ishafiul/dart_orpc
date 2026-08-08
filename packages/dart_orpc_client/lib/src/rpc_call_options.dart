import 'dart:async';

/// Per-invocation HTTP options for a generated RPC client call.
final class RpcCallOptions {
  const RpcCallOptions({this.headers = const {}, this.bearerToken});

  /// Additional headers for this invocation.
  final Map<String, String> headers;

  /// Overrides the transport token for this invocation when non-null.
  final String? bearerToken;
}

/// Resolves the bearer token used by a client transport.
typedef RpcBearerTokenProvider = FutureOr<String?> Function();
