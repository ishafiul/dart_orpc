import 'package:dart_orpc_core/dart_orpc_core.dart';

/// An immutable HTTP request created for an RPC call.
final class HttpRpcRequest {
  HttpRpcRequest({
    required this.method,
    required this.uri,
    required Map<String, String> headers,
    required this.body,
    required this.rpcRequest,
  }) : headers = Map.unmodifiable(headers);

  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final String body;
  final RpcRequest rpcRequest;

  HttpRpcRequest copyWith({
    String? method,
    Uri? uri,
    Map<String, String>? headers,
    String? body,
  }) {
    return HttpRpcRequest(
      method: method ?? this.method,
      uri: uri ?? this.uri,
      headers: headers ?? this.headers,
      body: body ?? this.body,
      rpcRequest: rpcRequest,
    );
  }
}

/// An immutable HTTP response returned through the interceptor pipeline.
final class HttpRpcResponse {
  HttpRpcResponse({
    required this.statusCode,
    required Map<String, String> headers,
    required this.body,
    required this.request,
  }) : headers = Map.unmodifiable(headers);

  final int statusCode;
  final Map<String, String> headers;
  final String body;
  final HttpRpcRequest request;

  HttpRpcResponse copyWith({
    int? statusCode,
    Map<String, String>? headers,
    String? body,
    HttpRpcRequest? request,
  }) {
    return HttpRpcResponse(
      statusCode: statusCode ?? this.statusCode,
      headers: headers ?? this.headers,
      body: body ?? this.body,
      request: request ?? this.request,
    );
  }
}

/// Continues an HTTP RPC interceptor pipeline.
abstract interface class HttpRpcHandler {
  Future<HttpRpcResponse> next(HttpRpcRequest request);
}

/// Intercepts the HTTP request and response used for an RPC invocation.
///
/// Implementations can modify requests and responses, recover from errors,
/// short-circuit requests, or invoke [next] again for a bounded retry.
abstract interface class RpcInterceptorCore {
  Future<HttpRpcResponse> intercept(
    HttpRpcRequest request,
    HttpRpcHandler next,
  );
}

/// A convenience interceptor with separate request, response, and error hooks.
///
/// Extend this class when a single pass through each phase is sufficient. Use
/// [RpcInterceptorCore] directly for advanced control such as short-circuiting
/// or invoking the downstream handler multiple times.
abstract base class RpcInterceptor implements RpcInterceptorCore {
  const RpcInterceptor();

  Future<HttpRpcRequest> onRequest(HttpRpcRequest request) async => request;

  Future<HttpRpcResponse> onResponse(HttpRpcResponse response) async =>
      response;

  Future<HttpRpcResponse> onError(
    Object error,
    StackTrace stackTrace,
    HttpRpcRequest request,
  ) async {
    Error.throwWithStackTrace(error, stackTrace);
  }

  @override
  Future<HttpRpcResponse> intercept(
    HttpRpcRequest request,
    HttpRpcHandler next,
  ) async {
    var currentRequest = request;
    try {
      currentRequest = await onRequest(currentRequest);
      final response = await next.next(currentRequest);
      return await onResponse(response);
    } catch (error, stackTrace) {
      return onError(error, stackTrace, currentRequest);
    }
  }
}
