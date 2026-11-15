/// Record kinds and flags shared with Rust (`native/src/protocol/kinds.rs`).
library;

/// Flag bits of a record from Rust.
abstract final class RequestFlags {
  /// The request is HTTP/1.0.
  static const int http10 = 1;

  /// The request is a valid WebSocket upgrade request.
  static const int webSocketUpgrade = 1 << 1;

  /// The body lives in native memory and is freed by a finalizer.
  static const int externalBody = 1 << 2;

  /// Shift of the [InboundKind] in the flags.
  static const int kindShift = 8;
}

/// What a record from Rust carries.
enum InboundKind {
  /// An HTTP request.
  request,

  /// A text WebSocket message.
  webSocketText,

  /// A binary WebSocket message.
  webSocketBinary,

  /// The WebSocket closed; the port field holds the close code.
  webSocketClosed,

  /// Bytes of a streamed body reached the socket.
  streamSent,

  /// The client of a streamed body is gone.
  streamGone;

  /// The kind encoded in [flags], or null for an unknown one.
  static InboundKind? fromFlags(int flags) {
    final index = (flags >> RequestFlags.kindShift) & 0xff;
    return index < values.length ? values[index] : null;
  }
}

/// What a record to Rust carries. [wire] is the low byte of its kind field.
enum OutboundKind {
  /// A whole HTTP answer.
  answer(0),

  /// Accepts a WebSocket upgrade.
  webSocketAccept(1),

  /// A text message for a WebSocket.
  webSocketText(2),

  /// A binary message for a WebSocket.
  webSocketBinary(3),

  /// Closes a WebSocket.
  webSocketClose(4),

  /// Acknowledges handled client message bytes.
  webSocketAck(5),

  /// Starts a streamed answer.
  streamStart(6),

  /// One part of a streamed body.
  streamPart(7),

  /// Ends a streamed body.
  streamEnd(8);

  const OutboundKind(this.wire);

  /// The value of the kind field's low byte.
  final int wire;

  /// Whether this record answers a request.
  bool get answersRequest =>
      this == answer || this == webSocketAccept || this == streamStart;
}

/// Flag bits in the high byte of an outbound kind field.
abstract final class AnswerFlags {
  /// Rust gzips the body.
  static const int gzip = 0x100;

  /// The header lines contain `connection: close`.
  static const int connectionClose = 0x200;
}
