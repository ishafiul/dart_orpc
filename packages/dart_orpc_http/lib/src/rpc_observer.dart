import 'dart:async';

import 'rpc_http_options.dart';

/// Observes every call an app serves, for logging, tracing and metrics.
///
/// The adapter calls [startCall] when a call begins and runs the call inside a
/// zone that carries the returned [RpcCallObservation], so code running for
/// that call can reach it through [currentRpcCallObservation].
///
/// Implementations must return quickly and never throw: they run on the
/// request path. Anything slow, such as exporting, belongs in the background.
abstract interface class RpcObserver {
  RpcCallObservation startCall(RpcObservedCallStart start);

  /// The app is listening and serves [server]'s endpoints.
  void serverStarted(RpcObservedServer server);

  /// The app stopped accepting requests and drained the ones in flight.
  void serverStopped(RpcObservedServer server);

  /// Flushes buffered data. Called once, after the app's providers close.
  Future<void> close();
}

/// One observed call: an HTTP exchange, or one call on a WebSocket connection.
abstract interface class RpcCallObservation {
  /// Names the RPC procedure once the adapter has resolved it.
  void identify(String rpcMethod);

  /// Records an error the call produced. May be called before [end].
  void recordError(Object error, StackTrace stackTrace);

  /// Ends the call. Called exactly once.
  void end(RpcObservedCallEnd end);
}

final class RpcObservedCallStart {
  const RpcObservedCallStart({
    required this.transport,
    required this.method,
    required this.path,
    this.header = _noHeader,
    this.requestId,
    this.remoteAddress,
    this.rpcMethod,
    this.callId,
  });

  final RpcTransportKind transport;

  /// The HTTP method, or the HTTP method of the WebSocket upgrade.
  final String method;
  final String path;

  /// Reads one request header by lower-case name, such as `traceparent`.
  /// Nothing is copied unless the observer asks for a header.
  final String? Function(String name) header;
  final String? requestId;
  final String? remoteAddress;

  /// The RPC method, when the transport knows it at the start of the call.
  final String? rpcMethod;

  /// The transport call id, such as a WebSocket frame id.
  final String? callId;
}

final class RpcObservedCallEnd {
  const RpcObservedCallEnd({
    required this.elapsed,
    this.route,
    this.statusCode,
    this.receivedBytes = 0,
    this.sentBytes = 0,
    this.streaming = false,
    this.disconnected = false,
    this.failed = false,
  });

  final Duration elapsed;

  /// The registered route template, or a bounded label for unmatched paths.
  final String? route;

  /// The HTTP status code. Null for WebSocket calls.
  final int? statusCode;
  final int receivedBytes;
  final int sentBytes;
  final bool streaming;
  final bool disconnected;
  final bool failed;
}

/// What an app serves, reported when it starts and stops listening.
final class RpcObservedServer {
  const RpcObservedServer({
    required this.host,
    required this.port,
    this.endpoints = const [],
  });

  /// The host clients reach the server on; loopback when it binds every
  /// interface.
  final String host;
  final int port;
  final List<RpcObservedEndpoint> endpoints;
}

final class RpcObservedEndpoint {
  const RpcObservedEndpoint({required this.name, required this.url});

  /// A short label, such as `rpc`, `websocket`, `docs` or `health`.
  final String name;
  final Uri url;
}

/// Implemented by an [RpcHttpUpgradeHandler] that serves an endpoint worth
/// announcing, such as the WebSocket RPC path.
abstract interface class RpcHttpEndpointDescriptor {
  String get endpointName;

  /// The URI scheme clients use, such as `ws`.
  String get endpointScheme;
  String get endpointPath;
}

String? _noHeader(String name) => null;

const _observationZoneKey = #dart_orpc.http.callObservation;

/// The observation of the call the current code runs for, if any.
RpcCallObservation? currentRpcCallObservation() =>
    switch (Zone.current[_observationZoneKey]) {
      final RpcCallObservation observation => observation,
      _ => null,
    };

/// Runs [body] so that [currentRpcCallObservation] returns [observation].
R runRpcCallObserved<R>(RpcCallObservation observation, R Function() body) =>
    runZoned(body, zoneValues: {_observationZoneKey: observation});
