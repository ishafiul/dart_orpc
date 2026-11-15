/// Checks for header names and values written to the wire.
///
/// Rust splits Dart's header lines on line breaks, so an unchecked value
/// could inject a header.
library;

/// Separator characters a header name may not contain (RFC 9110 5.6.2).
const Set<int> _separators = {
  0x22, 0x28, 0x29, 0x2c, 0x2f, 0x3a, 0x3b, 0x3c, //
  0x3d, 0x3e, 0x3f, 0x40, 0x5b, 0x5c, 0x5d, 0x7b, 0x7d,
};

/// Returns [value] when it is visible ASCII, space or tab, like dart:io.
///
/// Throws a [FormatException] otherwise.
String checkHeaderValue(String value) {
  for (var i = 0; i < value.length; i++) {
    final c = value.codeUnitAt(i);
    if ((c < 0x20 && c != 0x09) || c > 0x7f) {
      throw FormatException('Invalid HTTP header field value', value, i);
    }
  }
  return value;
}

/// Returns [name] when it is a token, like dart:io.
///
/// Throws a [FormatException] otherwise.
String checkHeaderName(String name) {
  for (var i = 0; i < name.length; i++) {
    final c = name.codeUnitAt(i);
    if (c <= 0x20 || c >= 0x7f || _separators.contains(c)) {
      throw FormatException('Invalid HTTP header field name', name, i);
    }
  }
  return name;
}
