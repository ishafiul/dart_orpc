import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import '../ffi/bindings.dart';
import '../ffi/native_library.dart';
import '../protocol/inbound_record.dart';
import '../protocol/record_buffer.dart';
import 'http_engine.dart';
import 'native_record_buffer.dart';

/// The [HttpEngine] backed by the Rust library through `dart:ffi`.
final class FfiHttpEngine implements HttpEngine {
  /// Creates the engine. The native library must be available.
  const FfiHttpEngine();

  /// Initial size of the buffer for answers.
  static const int outboundCapacity = 1 << 16;

  @override
  ExternalBodyResolver get externalBodies => const _FinalizedBodies();

  @override
  RecordBuffer newOutboundBuffer() => NativeRecordBuffer(outboundCapacity);

  @override
  EngineServer bind(BindConfig config, int sendPort) {
    nativeLibrary.ensureAvailable();
    final raw = config.address?.rawAddress ?? const <int>[];
    final family = config.address == null ? 0 : (raw.length == 4 ? 4 : 6);
    var high = 0;
    var low = 0;
    for (var i = 0; i < raw.length; i++) {
      if (raw.length == 16 && i < 8) {
        high = (high << 8) | raw[i];
      } else {
        low = (low << 8) | raw[i];
      }
    }
    final handle = rustHttpBind(
      config.port,
      sendPort,
      config.maxBodySize,
      config.maxMultipartSize,
      config.bodyTimeout.inMilliseconds,
      family,
      high,
      low,
      config.maxConnections ?? 0,
      config.idleTimeout.inMilliseconds,
      config.shared ? 1 : 0,
    );
    if (handle <= 0) {
      final osError = handle <= -1000 ? -(handle + 1000) : 0;
      throw SocketException(
        'rust_http: bind failed ($handle)',
        osError: OSError('', osError),
        address: config.address,
        port: config.port,
      );
    }
    return _FfiEngineServer(handle);
  }
}

final class _FfiEngineServer implements EngineServer {
  _FfiEngineServer(this._handle) : port = rustHttpBoundPort(_handle);

  /// Initial and resting size of the inbox.
  static const int _inboxCapacity = 1 << 18;

  /// Buffers above this size are shrunk after use.
  static const int _shrinkAbove = 1 << 20;

  final int _handle;
  final NativeRecordBuffer _inbox = NativeRecordBuffer(_inboxCapacity);

  @override
  final int port;

  @override
  InboundBatch? run(RecordBuffer answers, int length, Duration budget) {
    final out = answers as NativeRecordBuffer;
    var read = rustHttpRun(
      _handle,
      out.pointer,
      length,
      _inbox.pointer,
      _inbox.bytes.length,
      budget.inMicroseconds,
    );
    out.shrinkIfAbove(_shrinkAbove, FfiHttpEngine.outboundCapacity);
    while (read < 0) {
      // One record is bigger than the inbox.
      _inbox.ensureCapacity(-read);
      read = rustHttpRun(
        _handle,
        out.pointer,
        0,
        _inbox.pointer,
        _inbox.bytes.length,
        0,
      );
    }
    if (read == 0) return null;
    // A copy: the next call reuses the inbox, and requests keep views.
    final batch = InboundBatch(_inbox.bytes.sublist(0, read));
    _inbox.shrinkIfAbove(_shrinkAbove, _inboxCapacity);
    return batch;
  }

  @override
  void shutdown() => rustHttpShutdown(_handle);

  @override
  void unbind() {
    rustHttpUnbind(_handle);
    _inbox.free();
  }
}

/// Wraps native bodies as typed lists that free themselves.
final class _FinalizedBodies implements ExternalBodyResolver {
  const _FinalizedBodies();

  static final Pointer<NativeFinalizerFunction> _free =
      Native.addressOf<NativeFinalizerFunction>(rustHttpFreeBody);

  @override
  Uint8List resolve(int address, int token, int length) {
    return Pointer<Uint8>.fromAddress(address).asTypedList(
      length,
      finalizer: _free,
      token: Pointer<Void>.fromAddress(token),
    );
  }
}
