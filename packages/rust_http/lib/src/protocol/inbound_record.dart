import 'dart:typed_data';

import 'kinds.dart';

/// Size of the head of a record from Rust.
const int inboundHeadLength = 44;

/// Turns the reference of a body in native memory into a typed list that
/// frees the memory when it is collected.
abstract interface class ExternalBodyResolver {
  /// The bytes at [address]; [token] frees them.
  Uint8List resolve(int address, int token, int length);
}

/// A record from Rust.
sealed class InboundRecord {
  const InboundRecord(this.id);

  /// Request, WebSocket or stream id.
  final int id;
}

/// An HTTP request. Its byte fields are views into the batch.
final class RequestRecord extends InboundRecord {
  /// Creates a request record.
  const RequestRecord({
    required int id,
    required this.method,
    required this.target,
    required this.rawHeaders,
    required this.body,
    required this.remoteIp,
    required this.remotePort,
    required this.http10,
    required this.isWebSocketUpgrade,
    this.streamingBody = false,
  }) : super(id);

  /// The request method.
  final String method;

  /// The request target as sent, with non-ASCII bytes `%XX` escaped.
  final String target;

  /// The header block; see `RequestHeaders`.
  final Uint8List rawHeaders;

  /// Whether the request body follows in separate records.
  final bool streamingBody;

  /// The buffered body.
  final Uint8List body;

  /// The remote IP, 16 bytes, IPv4 mapped.
  final Uint8List remoteIp;

  /// The remote port.
  final int remotePort;

  /// The request is HTTP/1.0.
  final bool http10;

  /// The request is a valid WebSocket upgrade request.
  final bool isWebSocketUpgrade;
}

/// A body chunk, or completion with zero for success and an HTTP error otherwise.
final class RequestBodyRecord extends InboundRecord {
  /// Creates a body chunk or end record.
  const RequestBodyRecord(super.id, this.bytes, this.status);

  /// Bytes of this chunk, empty for an end record.
  final Uint8List bytes;

  /// Null for a chunk. Zero for success, or an HTTP status on error.
  final int? status;
}

/// A message or the close of a WebSocket.
final class WebSocketRecord extends InboundRecord {
  /// Creates a WebSocket record.
  const WebSocketRecord(super.id, this.kind, this.closeCode, this.payload);

  /// [InboundKind.webSocketText], [InboundKind.webSocketBinary] or
  /// [InboundKind.webSocketClosed].
  final InboundKind kind;

  /// The close code of a closed WebSocket.
  final int closeCode;

  /// The message, or the close reason.
  final Uint8List payload;
}

/// Progress of a streamed body.
final class StreamProgressRecord extends InboundRecord {
  /// Creates a progress record. [sentBytes] is null when the client is gone.
  const StreamProgressRecord(super.id, this.sentBytes);

  /// Body bytes that reached the socket, or null when the client is gone.
  final int? sentBytes;

  /// The client of the stream is gone.
  bool get clientGone => sentBytes == null;
}

/// Reads the records of one batch from Rust.
final class InboundBatchReader {
  /// Creates a reader that resolves external bodies with [externalBodies].
  const InboundBatchReader(this.externalBodies);

  /// Resolves bodies in native memory.
  final ExternalBodyResolver externalBodies;

  /// The records of [batch], in order.
  Iterable<InboundRecord> read(Uint8List batch) sync* {
    final data = ByteData.sublistView(batch);
    var at = 0;
    while (at + inboundHeadLength <= batch.length) {
      final id = data.getUint64(at, Endian.little);
      final flags = data.getUint32(at + 8, Endian.little);
      final methodLength = data.getUint16(at + 12, Endian.little);
      final targetLength = data.getUint16(at + 14, Endian.little);
      final headersLength = data.getUint32(at + 16, Endian.little);
      final bodyLength = data.getUint32(at + 20, Endian.little);
      final port = data.getUint16(at + 24, Endian.little);
      var cursor = at + inboundHeadLength;
      final ip = Uint8List.sublistView(batch, at + 28, cursor);
      final method = _method(batch, cursor, methodLength);
      cursor += methodLength;
      final target = String.fromCharCodes(batch, cursor, cursor + targetLength);
      cursor += targetLength;
      final headers = Uint8List.sublistView(
        batch,
        cursor,
        cursor + headersLength,
      );
      cursor += headersLength;
      final body = flags & RequestFlags.externalBody != 0
          ? externalBodies.resolve(
              data.getUint64(cursor, Endian.little),
              data.getUint64(cursor + 8, Endian.little),
              data.getUint64(cursor + 16, Endian.little),
            )
          : Uint8List.sublistView(batch, cursor, cursor + bodyLength);
      at = cursor + bodyLength;
      switch (InboundKind.fromFlags(flags)) {
        case InboundKind.request:
          yield RequestRecord(
            id: id,
            method: method,
            target: target,
            rawHeaders: headers,
            body: body,
            remoteIp: ip,
            remotePort: port,
            streamingBody: flags & RequestFlags.streamingBody != 0,
            http10: flags & RequestFlags.http10 != 0,
            isWebSocketUpgrade: flags & RequestFlags.webSocketUpgrade != 0,
          );
        case InboundKind.requestBody:
          yield RequestBodyRecord(id, body, null);
        case InboundKind.requestBodyEnd:
          yield RequestBodyRecord(id, body, port);
        case InboundKind.streamSent:
          yield StreamProgressRecord(
            id,
            ByteData.sublistView(body).getUint64(0, Endian.little),
          );
        case InboundKind.streamGone:
          yield StreamProgressRecord(id, null);
        case final kind?:
          yield WebSocketRecord(id, kind, port, body);
        case null:
          break;
      }
    }
  }

  /// The common methods without a new String. Every byte is checked, so a
  /// method like `GOT` never turns into `GET`.
  static String _method(Uint8List b, int at, int length) {
    switch (length) {
      case 3 when b[at] == 0x47 && b[at + 1] == 0x45 && b[at + 2] == 0x54:
        return 'GET';
      case 3 when b[at] == 0x50 && b[at + 1] == 0x55 && b[at + 2] == 0x54:
        return 'PUT';
      case 4
          when b[at] == 0x50 &&
              b[at + 1] == 0x4f &&
              b[at + 2] == 0x53 &&
              b[at + 3] == 0x54:
        return 'POST';
      case 6
          when b[at] == 0x44 &&
              b[at + 1] == 0x45 &&
              b[at + 2] == 0x4c &&
              b[at + 3] == 0x45 &&
              b[at + 4] == 0x54 &&
              b[at + 5] == 0x45:
        return 'DELETE';
    }
    return String.fromCharCodes(b, at, at + length);
  }
}
