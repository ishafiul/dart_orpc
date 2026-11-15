import 'dart:typed_data';

import 'kinds.dart';
import 'record_buffer.dart';

/// Size of the head of a record to Rust.
const int outboundHeadLength = 20;

/// Writes records to Rust into a [RecordBuffer].
///
/// A record is written in three steps: [start], any header lines, then
/// [finish] with the body.
final class OutboundRecordWriter {
  /// Creates a writer over [buffer].
  OutboundRecordWriter(this.buffer);

  /// The storage.
  final RecordBuffer buffer;

  /// Bytes written since the last [reset].
  int length = 0;

  /// Whether nothing is written.
  bool get isEmpty => length == 0;

  /// Forgets what was written, after Rust took it.
  void reset() => length = 0;

  /// Starts a record and returns its offset, for [finish].
  int start(int id, int status, OutboundKind kind, {int flags = 0}) {
    _ensure(outboundHeadLength);
    final at = length;
    buffer.data
      ..setUint64(at, id, Endian.little)
      ..setUint16(at + 8, status, Endian.little)
      ..setUint16(at + 10, kind.wire | flags, Endian.little);
    length += outboundHeadLength;
    return at;
  }

  /// Adds answer flags to the record at [start].
  void addFlags(int start, int flags) {
    final data = buffer.data;
    final kind = data.getUint16(start + 10, Endian.little);
    data.setUint16(start + 10, kind | flags, Endian.little);
  }

  /// Writes `name: value\r\n`. Both must be validated ASCII.
  void headerLine(String name, String value) {
    _ensure(name.length + value.length + 4);
    final out = buffer.bytes;
    var at = length;
    for (var i = 0; i < name.length; i++) {
      out[at++] = name.codeUnitAt(i);
    }
    out[at++] = 0x3a;
    out[at++] = 0x20;
    for (var i = 0; i < value.length; i++) {
      out[at++] = value.codeUnitAt(i);
    }
    out[at++] = 0x0d;
    out[at++] = 0x0a;
    length = at;
  }

  /// Writes encoded header lines as they are.
  void headerBytes(List<int> lines) {
    _ensure(lines.length);
    buffer.bytes.setRange(length, length + lines.length, lines);
    length += lines.length;
  }

  /// Ends the record at [start] with [body]. A [prefix] word (a stream id)
  /// goes before the body.
  void finish(int start, List<int> body, {int? prefix}) {
    final extra = prefix == null ? 0 : 8;
    final linesLength = length - start - outboundHeadLength;
    _ensure(body.length + extra);
    final data = buffer.data
      ..setUint32(start + 12, linesLength, Endian.little)
      ..setUint32(start + 16, body.length + extra, Endian.little);
    if (prefix != null) {
      data.setUint64(length, prefix, Endian.little);
      length += 8;
    }
    buffer.bytes.setRange(length, length + body.length, body);
    length += body.length;
  }

  void _ensure(int extra) => buffer.ensureCapacity(length + extra);
}
