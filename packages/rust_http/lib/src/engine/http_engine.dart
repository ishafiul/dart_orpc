import 'dart:io';

import '../protocol/inbound_record.dart';
import '../protocol/record_buffer.dart';

/// Messages the native side posts to the server's receive port.
abstract final class EngineSignal {
  /// The sockets have work: pump.
  static const int wake = 1;

  /// A graceful shutdown is complete.
  static const int drained = 2;
}

/// The limits and address a server binds with.
final class BindConfig {
  /// Creates a bind configuration.
  const BindConfig({
    required this.port,
    required this.address,
    required this.maxBodySize,
    required this.maxMultipartSize,
    required this.bodyTimeout,
    required this.maxConnections,
    required this.idleTimeout,
    this.shared = false,
    this.streamRequestBodies = false,
  });

  /// The port, 0 for any.
  final int port;

  /// The host, or null for all interfaces.
  final InternetAddress? address;

  /// Max bytes of a request body.
  final int maxBodySize;

  /// Max bytes of a multipart form body.
  final int maxMultipartSize;

  /// Max idle time between body bytes.
  final Duration bodyTimeout;

  /// Max open connections, or null for no limit.
  final int? maxConnections;

  /// Keep-alive timeout.
  final Duration idleTimeout;

  /// Whether other shared servers of this process may bind the same port.
  final bool shared;

  /// Whether requests can reach Dart before their body is complete.
  final bool streamRequestBodies;
}

/// The native HTTP core, as the Dart server sees it.
///
/// The FFI implementation is `FfiHttpEngine`; tests can substitute a fake.
abstract interface class HttpEngine {
  /// Binds a server that posts [EngineSignal]s to [sendPort].
  ///
  /// Throws a [SocketException] when the bind fails.
  EngineServer bind(BindConfig config, int sendPort);

  /// A new buffer for records to the engine.
  RecordBuffer newOutboundBuffer();

  /// Resolves bodies the engine moved to Dart without a copy.
  ExternalBodyResolver get externalBodies;
}

/// One bound server of an [HttpEngine].
abstract interface class EngineServer {
  /// The bound port.
  int get port;

  /// Hands [length] bytes of [answers] to the engine and returns the next
  /// batch of records, or null when none came. Waits up to [budget] for
  /// requests.
  ///
  /// The batch is valid until the next call.
  InboundBatch? run(RecordBuffer answers, int length, Duration budget);

  /// Starts a graceful shutdown.
  void shutdown();

  /// Closes every socket and frees the server.
  void unbind();
}

/// Records from one [EngineServer.run] call.
final class InboundBatch {
  /// Creates a batch over [bytes].
  const InboundBatch(this.bytes);

  /// The record bytes; a private copy that stays valid.
  final List<int> bytes;
}
