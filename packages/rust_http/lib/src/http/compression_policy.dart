import 'dart:io';

/// Decides whether an answer body is gzipped, for `autoCompress`.
abstract final class CompressionPolicy {
  /// Bodies at most this long are not worth compressing.
  static const int minimumBodyLength = 256;

  /// Whether to gzip [bodyLength] bytes answering a request with
  /// [acceptEncoding], given the [response] headers. Updates the headers:
  /// adds `vary: accept-encoding` when the body could be gzipped, and sets
  /// `content-encoding: gzip` when it will be.
  static bool apply({
    required String? acceptEncoding,
    required HttpHeaders response,
    required int bodyLength,
  }) {
    if (bodyLength <= minimumBodyLength) return false;
    if (response.value(HttpHeaders.contentEncodingHeader) != null) {
      return false;
    }
    if (isCompressedType(response.value(HttpHeaders.contentTypeHeader))) {
      return false;
    }
    // A shared cache must not give gzip to a client that cannot read it.
    if (!variesOnEncoding(response[HttpHeaders.varyHeader])) {
      response.add(HttpHeaders.varyHeader, 'Accept-Encoding');
    }
    if (!acceptsGzip(acceptEncoding)) return false;
    response.set(HttpHeaders.contentEncodingHeader, 'gzip');
    return true;
  }

  /// Whether [vary] already names `Accept-Encoding`, or is `*`.
  static bool variesOnEncoding(List<String>? vary) {
    if (vary == null) return false;
    for (final value in vary) {
      final lower = value.toLowerCase();
      if (lower.contains('accept-encoding') || lower.trim() == '*') {
        return true;
      }
    }
    return false;
  }

  /// Whether [accept] lists gzip with a q above 0.
  static bool acceptsGzip(String? accept) {
    if (accept == null || !accept.contains('gzip')) return false;
    for (final part in accept.split(',')) {
      final params = part.split(';');
      final name = params.first.trim().toLowerCase();
      if (name != 'gzip' && name != 'x-gzip') continue;
      for (final param in params.skip(1)) {
        final p = param.trim().toLowerCase();
        if (p.startsWith('q=')) {
          final q = double.tryParse(p.substring(2).trim());
          if (q != null && q <= 0) return false;
        }
      }
      return true;
    }
    return false;
  }

  /// Whether [contentType] is compressed already, where gzip only adds
  /// bytes: images (but SVG), audio, video, archives and web fonts.
  static bool isCompressedType(String? contentType) {
    if (contentType == null) return false;
    var type = contentType.toLowerCase();
    final semicolon = type.indexOf(';');
    if (semicolon >= 0) type = type.substring(0, semicolon);
    type = type.trim();
    if (type.startsWith('image/')) return type != 'image/svg+xml';
    if (type.startsWith('audio/') || type.startsWith('video/')) return true;
    return _compressedTypes.contains(type);
  }

  static const Set<String> _compressedTypes = {
    'application/zip',
    'application/gzip',
    'application/x-gzip',
    'application/x-bzip2',
    'application/x-xz',
    'application/x-7z-compressed',
    'application/x-rar-compressed',
    'application/vnd.rar',
    'application/zstd',
    'application/x-brotli',
    'font/woff',
    'font/woff2',
  };
}
