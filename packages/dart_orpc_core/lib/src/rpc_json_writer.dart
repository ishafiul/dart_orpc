import 'dart:convert';
import 'dart:typed_data';

import 'rpc_json_bytes.dart';

/// Writes UTF-8 JSON straight into a growable byte buffer.
///
/// The output is byte-for-byte what `utf8.encode(jsonEncode(value))` gives,
/// without building the intermediate string. Use [writeValue] for a decoded
/// JSON tree (such as a `toJson()` map), or the typed writes with [writeRaw]
/// to write a DTO without building a map at all, for example in an
/// [RpcJsonBytes.toJsonBytes] implementation:
///
/// ```dart
/// final writer = RpcJsonWriter()
///   ..writeRaw('{"id":')
///   ..writeInt(id)
///   ..writeRaw(',"name":')
///   ..writeString(name)
///   ..writeRaw('}');
/// return writer.takeBytes();
/// ```
///
/// If a write throws, the bytes written so far are unspecified.
final class RpcJsonWriter {
  /// Creates a writer whose buffer starts at [initialCapacity] bytes.
  RpcJsonWriter({int initialCapacity = 1024})
    : _initialCapacity = initialCapacity < 16 ? 16 : initialCapacity,
      _buffer = _empty;

  // Containers nested deeper than this are handed to jsonEncode, which
  // detects cycles instead of overflowing the stack.
  static const int _maxDirectDepth = 256;

  static final Uint8List _empty = Uint8List(0);

  final int _initialCapacity;
  Uint8List _buffer;
  int _length = 0;
  int _depth = 0;

  /// The number of bytes written so far.
  int get length => _length;

  /// Returns the bytes written so far and resets the writer.
  Uint8List takeBytes() {
    final bytes = Uint8List.sublistView(_buffer, 0, _length);
    _buffer = _empty;
    _length = 0;
    return bytes;
  }

  /// Returns an exact-size copy of the bytes written so far.
  ///
  /// Unlike [takeBytes], the writer keeps its buffer, so a writer that is
  /// [clear]ed and reused does not allocate a new buffer per value.
  Uint8List toBytes() => Uint8List(_length)..setRange(0, _length, _buffer);

  /// Discards the bytes written so far and keeps the buffer for reuse.
  ///
  /// A buffer that grew past [maxRetainedCapacity] bytes is released, so one
  /// large value does not pin its memory.
  void clear({int maxRetainedCapacity = 64 * 1024}) {
    _length = 0;
    _depth = 0;
    if (_buffer.length > maxRetainedCapacity) {
      _buffer = _empty;
    }
  }

  /// Writes [json], which must be ASCII JSON text such as `{"id":` or `]`.
  ///
  /// The text is copied as is: it is not escaped or checked for being valid
  /// JSON, only for being ASCII.
  void writeRaw(String json) {
    final length = json.length;
    _reserve(length);
    final buffer = _buffer;
    var offset = _length;
    for (var index = 0; index < length; index++) {
      final unit = json.codeUnitAt(index);
      if (unit > 0x7f) {
        throw ArgumentError.value(json, 'json', 'must be ASCII');
      }
      buffer[offset++] = unit;
    }
    _length = offset;
  }

  /// Writes `null`.
  void writeNull() => _writeAscii('null');

  /// Writes `true` or `false`.
  void writeBool(bool value) => _writeAscii(value ? 'true' : 'false');

  /// Writes [value] in decimal.
  void writeInt(int value) {
    if (value >= 0 && value < 10) {
      _reserve(1);
      _buffer[_length++] = 0x30 + value;
      return;
    }
    _writeAscii(value.toString());
  }

  /// Writes [value] as `jsonEncode` does. NaN and infinities throw
  /// [JsonUnsupportedObjectError].
  void writeDouble(double value) {
    if (!value.isFinite) {
      throw JsonUnsupportedObjectError(value);
    }
    _writeAscii(value.toString());
  }

  /// Writes [value] as a quoted, escaped JSON string.
  void writeString(String value) {
    final length = value.length;
    // The common case: printable ASCII with nothing to escape.
    _reserve(length + 2);
    final buffer = _buffer;
    var offset = _length;
    buffer[offset++] = 0x22;
    for (var index = 0; index < length; index++) {
      final unit = value.codeUnitAt(index);
      if (unit < 0x20 || unit == 0x22 || unit == 0x5c || unit > 0x7f) {
        _length = offset;
        _writeStringTail(value, index);
        return;
      }
      buffer[offset++] = unit;
    }
    buffer[offset++] = 0x22;
    _length = offset;
  }

  /// Writes any value that `jsonEncode` accepts: null, bool, num, String,
  /// List, Map with String keys, [RpcJsonBytes], or an object with `toJson`.
  ///
  /// Throws what `jsonEncode` throws for anything else.
  void writeValue(Object? value) {
    if (value is String) {
      writeString(value);
    } else if (value is int) {
      writeInt(value);
    } else if (value == null) {
      writeNull();
    } else if (value is bool) {
      writeBool(value);
    } else if (value is double) {
      writeDouble(value);
    } else if (value is RpcJsonBytes) {
      _writeBytes(value.toJsonBytes());
    } else if (_depth >= _maxDirectDepth) {
      _writeEncoded(value);
    } else if (value is List<Object?>) {
      _writeList(value);
    } else if (value is Map<String, Object?>) {
      _writeMap(value);
    } else if (value is Map<Object?, Object?> && value.keys.every(_isString)) {
      _writeMap(value.cast<String, Object?>());
    } else {
      _writeEncoded(value);
    }
  }

  static bool _isString(Object? key) => key is String;

  void _writeList(List<Object?> list) {
    _depth++;
    _writeByte(0x5b);
    for (var index = 0; index < list.length; index++) {
      if (index > 0) _writeByte(0x2c);
      writeValue(list[index]);
    }
    _writeByte(0x5d);
    _depth--;
  }

  void _writeMap(Map<String, Object?> map) {
    _depth++;
    _writeByte(0x7b);
    var first = true;
    for (final MapEntry(:key, :value) in map.entries) {
      if (!first) _writeByte(0x2c);
      first = false;
      writeString(key);
      _writeByte(0x3a);
      writeValue(value);
    }
    _writeByte(0x7d);
    _depth--;
  }

  // Objects with toJson, deep trees and invalid values: jsonEncode gives the
  // same output and the same errors.
  void _writeEncoded(Object? value) =>
      _writeBytes(utf8.encode(jsonEncode(value)));

  void _writeStringTail(String value, int start) {
    final length = value.length;
    for (var index = start; index < length; index++) {
      final unit = value.codeUnitAt(index);
      if (unit < 0x80) {
        _writeAsciiUnit(unit);
      } else if (unit < 0x800) {
        _reserve(2);
        _buffer[_length++] = 0xc0 | (unit >> 6);
        _buffer[_length++] = 0x80 | (unit & 0x3f);
      } else if (unit < 0xd800 || unit > 0xdfff) {
        _writeThreeBytes(unit);
      } else if (unit < 0xdc00 &&
          index + 1 < length &&
          _isLowSurrogate(value.codeUnitAt(index + 1))) {
        final low = value.codeUnitAt(++index);
        final codePoint = 0x10000 + ((unit - 0xd800) << 10) + (low - 0xdc00);
        _reserve(4);
        _buffer[_length++] = 0xf0 | (codePoint >> 18);
        _buffer[_length++] = 0x80 | ((codePoint >> 12) & 0x3f);
        _buffer[_length++] = 0x80 | ((codePoint >> 6) & 0x3f);
        _buffer[_length++] = 0x80 | (codePoint & 0x3f);
      } else {
        // A lone surrogate has no UTF-8 form; jsonEncode escapes it.
        _writeUnicodeEscape(unit);
      }
    }
    _writeByte(0x22);
  }

  static bool _isLowSurrogate(int unit) => unit >= 0xdc00 && unit <= 0xdfff;

  void _writeAsciiUnit(int unit) {
    switch (unit) {
      case 0x22:
        _writeAscii(r'\"');
      case 0x5c:
        _writeAscii(r'\\');
      case 0x08:
        _writeAscii(r'\b');
      case 0x09:
        _writeAscii(r'\t');
      case 0x0a:
        _writeAscii(r'\n');
      case 0x0c:
        _writeAscii(r'\f');
      case 0x0d:
        _writeAscii(r'\r');
      default:
        if (unit < 0x20) {
          _writeUnicodeEscape(unit);
        } else {
          _writeByte(unit);
        }
    }
  }

  void _writeThreeBytes(int unit) {
    _reserve(3);
    _buffer[_length++] = 0xe0 | (unit >> 12);
    _buffer[_length++] = 0x80 | ((unit >> 6) & 0x3f);
    _buffer[_length++] = 0x80 | (unit & 0x3f);
  }

  static const String _hexDigits = '0123456789abcdef';

  void _writeUnicodeEscape(int unit) {
    _reserve(6);
    _buffer[_length++] = 0x5c;
    _buffer[_length++] = 0x75;
    for (var shift = 12; shift >= 0; shift -= 4) {
      _buffer[_length++] = _hexDigits.codeUnitAt((unit >> shift) & 0xf);
    }
  }

  void _writeAscii(String text) {
    final length = text.length;
    _reserve(length);
    final buffer = _buffer;
    var offset = _length;
    for (var index = 0; index < length; index++) {
      buffer[offset++] = text.codeUnitAt(index);
    }
    _length = offset;
  }

  void _writeByte(int byte) {
    _reserve(1);
    _buffer[_length++] = byte;
  }

  void _writeBytes(List<int> bytes) {
    _reserve(bytes.length);
    _buffer.setRange(_length, _length + bytes.length, bytes);
    _length += bytes.length;
  }

  @pragma('vm:prefer-inline')
  void _reserve(int extra) {
    final needed = _length + extra;
    if (needed <= _buffer.length) return;
    var capacity = _buffer.length < _initialCapacity
        ? _initialCapacity
        : _buffer.length * 2;
    while (capacity < needed) {
      capacity *= 2;
    }
    _buffer = Uint8List(capacity)..setRange(0, _length, _buffer);
  }
}
