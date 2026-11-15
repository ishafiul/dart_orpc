import 'dart:async';
import 'dart:io';

import '../answer_channel.dart';

/// A body sent in parts, with flow control: at most [window] bytes wait in
/// the engine, so a large source never sits in memory.
final class StreamedBody implements StreamListener {
  /// Creates the state for a body of [declaredLength] bytes (-1 for none),
  /// of which [alreadySent] went with the head.
  StreamedBody({required int declaredLength, required int alreadySent})
    : _declaredLength = declaredLength,
      _remaining = declaredLength - alreadySent;

  /// Most bytes handed to the engine and not yet on the socket.
  static const int window = 1024 * 1024;

  final int _declaredLength;
  int _remaining;
  int _unsent = 0;
  bool _clientGone = false;
  Completer<void>? _room;

  /// The stream id in the engine.
  late final int id;

  /// Whether the client left.
  bool get clientGone => _clientGone;

  /// Whether the declared length is known.
  bool get hasDeclaredLength => _declaredLength >= 0;

  /// Whether the declared length was not reached.
  bool get isShort => hasDeclaredLength && _remaining > 0 && !_clientGone;

  /// Bytes written so far against the declared length.
  int get written => _declaredLength - _remaining;

  /// The declared length.
  int get declaredLength => _declaredLength;

  /// Counts [count] bytes handed to the engine. Throws an [HttpException]
  /// when they exceed the declared length, like dart:io.
  void count(int count) {
    if (hasDeclaredLength) {
      if (count > _remaining) {
        throw HttpException(
          'Content size exceeds specified contentLength. '
          '${written + count} bytes written while expected '
          '$_declaredLength.',
        );
      }
      _remaining -= count;
    }
    _unsent += count;
  }

  /// Waits while the engine holds a full window.
  Future<void> roomToSend() async {
    if (_unsent <= window || _clientGone) return;
    await (_room ??= Completer<void>()).future;
  }

  @override
  void onSent(int bytes) {
    _unsent -= bytes;
    _wakeIfRoom();
  }

  @override
  void onClientGone() {
    _clientGone = true;
    _wakeIfRoom();
  }

  void _wakeIfRoom() {
    final room = _room;
    if (room != null && (_clientGone || _unsent <= window)) {
      _room = null;
      room.complete();
    }
  }
}
