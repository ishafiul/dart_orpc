import 'rpc_cancellation.dart';

final class RpcContext {
  RpcContext({
    required Map<String, String> headers,
    this.httpMethod = 'POST',
    this.path = '/rpc',
    Map<String, Object?> attributes = const {},
    this.cancellation = RpcCancellationSignal.none,
  }) : headers = Map<String, String>.unmodifiable(headers),
       attributes = Map<String, Object?>.unmodifiable(attributes);

  final Map<String, String> headers;
  final String httpMethod;
  final String path;
  final Map<String, Object?> attributes;
  final RpcCancellationSignal cancellation;

  RpcContext copyWith({
    Map<String, String>? headers,
    String? httpMethod,
    String? path,
    Map<String, Object?>? attributes,
    RpcCancellationSignal? cancellation,
  }) {
    return RpcContext(
      headers: headers ?? this.headers,
      httpMethod: httpMethod ?? this.httpMethod,
      path: path ?? this.path,
      attributes: attributes ?? this.attributes,
      cancellation: cancellation ?? this.cancellation,
    );
  }
}
