import 'dart:math';

const _traceparentHeader = 'traceparent';
const _supportedVersion = '00';
const _invalidVersion = 'ff';
final _traceparentPattern = RegExp(
  r'^([0-9a-f]{2})-([0-9a-f]{32})-([0-9a-f]{16})-([0-9a-f]{2})',
);
final _zeroTraceId = '0' * 32;
final _zeroSpanId = '0' * 16;
const _sampledFlag = 0x01;

/// A W3C Trace Context position: which trace and span a call belongs to.
final class RpcTraceContext {
  const RpcTraceContext({
    required this.traceId,
    required this.spanId,
    this.sampled = true,
  });

  /// Reads a `traceparent` header. Returns null for a missing or invalid one.
  static RpcTraceContext? fromTraceparent(String? header) {
    if (header == null) {
      return null;
    }
    final match = _traceparentPattern.firstMatch(header.trim().toLowerCase());
    if (match == null) {
      return null;
    }
    final [version, traceId, spanId, flags] = [
      for (var group = 1; group <= 4; group++) match.group(group) ?? '',
    ];
    if (version == _invalidVersion ||
        (version == _supportedVersion && header.trim().length != 55) ||
        traceId == _zeroTraceId ||
        spanId == _zeroSpanId) {
      return null;
    }
    return RpcTraceContext(
      traceId: traceId,
      spanId: spanId,
      sampled: int.parse(flags, radix: 16) & _sampledFlag != 0,
    );
  }

  /// The header name a trace context is propagated in.
  static const headerName = _traceparentHeader;

  /// 32 lower-case hex characters.
  final String traceId;

  /// 16 lower-case hex characters.
  final String spanId;
  final bool sampled;

  String toTraceparent() =>
      '$_supportedVersion-$traceId-$spanId-${sampled ? '01' : '00'}';
}

/// Creates random, non-zero W3C trace and span ids.
final class RpcTraceIds {
  RpcTraceIds([Random? random]) : _random = random ?? Random(_secureSeed());

  final Random _random;

  static int _secureSeed() => Random.secure().nextInt(1 << 32);

  String traceId() => _nonZeroHex(4, _zeroTraceId);

  String spanId() => _nonZeroHex(2, _zeroSpanId);

  bool sample(double ratio) => ratio >= 1 || _random.nextDouble() < ratio;

  String _nonZeroHex(int words, String zero) {
    while (true) {
      final buffer = StringBuffer();
      for (var word = 0; word < words; word++) {
        buffer.write(
          _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0'),
        );
      }
      final id = buffer.toString();
      if (id != zero) {
        return id;
      }
    }
  }
}
