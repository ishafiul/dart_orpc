import 'dart:io';

import 'package:rust_http/src/http/compression_policy.dart';
import 'package:rust_http/src/http/headers/response_headers.dart';
import 'package:test/test.dart';

void main() {
  ResponseHeaders headers([String? type]) {
    final h = ResponseHeaders.empty();
    if (type != null) h.set(HttpHeaders.contentTypeHeader, type);
    return h;
  }

  test('gzips a large text body for a client that accepts gzip', () {
    final response = headers('text/plain');

    final gzip = CompressionPolicy.apply(
      acceptEncoding: 'br, gzip;q=0.8',
      response: response,
      bodyLength: 1000,
    );

    expect(gzip, isTrue);
    expect(response.value(HttpHeaders.contentEncodingHeader), 'gzip');
    expect(response.value(HttpHeaders.varyHeader), 'Accept-Encoding');
  });

  test('adds vary even when the client takes no gzip', () {
    final response = headers('text/plain');

    final gzip = CompressionPolicy.apply(
      acceptEncoding: 'gzip;q=0',
      response: response,
      bodyLength: 1000,
    );

    expect(gzip, isFalse);
    expect(response.value(HttpHeaders.varyHeader), 'Accept-Encoding');
    expect(response.value(HttpHeaders.contentEncodingHeader), isNull);
  });

  test('skips small, encoded and already compressed bodies', () {
    expect(
      CompressionPolicy.apply(
        acceptEncoding: 'gzip',
        response: headers(),
        bodyLength: CompressionPolicy.minimumBodyLength,
      ),
      isFalse,
    );
    expect(
      CompressionPolicy.apply(
        acceptEncoding: 'gzip',
        response: headers()..set(HttpHeaders.contentEncodingHeader, 'br'),
        bodyLength: 1000,
      ),
      isFalse,
    );
    for (final type in ['image/png', 'video/mp4', 'font/woff2']) {
      expect(CompressionPolicy.isCompressedType(type), isTrue, reason: type);
    }
    expect(CompressionPolicy.isCompressedType('image/svg+xml'), isFalse);
  });

  test('keeps an existing vary on accept-encoding or *', () {
    expect(
      CompressionPolicy.variesOnEncoding(['Origin, Accept-Encoding']),
      isTrue,
    );
    expect(CompressionPolicy.variesOnEncoding(['*']), isTrue);
    expect(CompressionPolicy.variesOnEncoding(['Origin']), isFalse);
  });
}
