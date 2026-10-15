import 'dart:math';

import 'package:dart_orpc_http/dart_orpc_http.dart';
import 'package:test/test.dart';

void main() {
  const one = RpcHttpRequest(method: 'GET', path: '/', remoteAddress: 'one');
  const two = RpcHttpRequest(method: 'GET', path: '/', remoteAddress: 'two');
  const three = RpcHttpRequest(
    method: 'GET',
    path: '/',
    remoteAddress: 'three',
  );

  test('requests expire individually across the old window boundary', () {
    final start = DateTime.utc(2026);
    var now = start;
    final limiter = RpcHttpRateLimiter(
      const RpcHttpRateLimitOptions(
        maxRequests: 2,
        window: Duration(seconds: 10),
      ),
      clock: () => now,
    );

    expect(limiter.check(one), isNull);
    now = start.add(const Duration(seconds: 9));
    expect(limiter.check(one), isNull);
    now = start.add(const Duration(seconds: 10));
    expect(limiter.check(one), isNull);
    expect(limiter.check(one), const Duration(seconds: 9));
    now = start.add(const Duration(seconds: 19));
    expect(limiter.check(one), isNull);
    expect(limiter.check(one), const Duration(seconds: 1));
  });

  test('rejected requests do not extend expiry and preserve microseconds', () {
    final start = DateTime.utc(2026);
    var now = start;
    final limiter = RpcHttpRateLimiter(
      const RpcHttpRateLimitOptions(
        maxRequests: 1,
        window: Duration(microseconds: 10),
      ),
      clock: () => now,
    );

    expect(limiter.check(one), isNull);
    now = start.add(const Duration(microseconds: 9));
    expect(limiter.check(one), const Duration(microseconds: 1));
    expect(limiter.check(one), const Duration(microseconds: 1));
    now = start.add(const Duration(microseconds: 10));
    expect(limiter.check(one), isNull);
  });

  test('capacity follows the most recent admission without evicting keys', () {
    final start = DateTime.utc(2026);
    var now = start;
    final limiter = RpcHttpRateLimiter(
      const RpcHttpRateLimitOptions(
        maxRequests: 2,
        maxKeys: 2,
        window: Duration(seconds: 10),
      ),
      clock: () => now,
    );

    expect(limiter.check(one), isNull);
    now = start.add(const Duration(seconds: 1));
    expect(limiter.check(two), isNull);
    now = start.add(const Duration(seconds: 2));
    expect(limiter.check(one), isNull);
    expect(limiter.check(three), const Duration(seconds: 9));
    now = start.add(const Duration(seconds: 10));
    expect(limiter.check(three), const Duration(seconds: 1));
    now = start.add(const Duration(seconds: 11));
    expect(limiter.check(three), isNull);
    expect(limiter.check(one), isNull);
    expect(limiter.check(one), const Duration(seconds: 1));
  });

  test('custom keys share limits across peer addresses and request paths', () {
    final limiter = RpcHttpRateLimiter(
      RpcHttpRateLimitOptions(
        maxRequests: 1,
        key: (request) => request.headers['x-client'] ?? 'anonymous',
      ),
      clock: () => DateTime.utc(2026),
    );

    expect(limiter.check(one), isNull);
    expect(limiter.check(two), const Duration(minutes: 1));
    expect(
      limiter.check(
        const RpcHttpRequest(
          method: 'POST',
          path: '/rpc',
          headers: {'x-client': 'other'},
        ),
      ),
      isNull,
    );
  });

  test('large timestamp queues release only the expired part of a burst', () {
    final start = DateTime.utc(2026);
    var now = start;
    final limiter = RpcHttpRateLimiter(
      const RpcHttpRateLimitOptions(
        maxRequests: 33,
        window: Duration(seconds: 10),
      ),
      clock: () => now,
    );

    for (var index = 0; index < 20; index++) {
      expect(limiter.check(one), isNull);
    }
    now = start.add(const Duration(seconds: 1));
    for (var index = 0; index < 13; index++) {
      expect(limiter.check(one), isNull);
    }
    expect(limiter.check(one), const Duration(seconds: 9));
    now = start.add(const Duration(seconds: 10));
    for (var index = 0; index < 20; index++) {
      expect(limiter.check(one), isNull);
    }
    expect(limiter.check(one), const Duration(seconds: 1));
    now = start.add(const Duration(seconds: 11));
    for (var index = 0; index < 13; index++) {
      expect(limiter.check(one), isNull);
    }
    expect(limiter.check(one), const Duration(seconds: 9));
  });

  test('backward clock changes cannot reorder identity expiry', () {
    final start = DateTime.utc(2026);
    var now = start;
    final limiter = RpcHttpRateLimiter(
      const RpcHttpRateLimitOptions(
        maxRequests: 2,
        maxKeys: 2,
        window: Duration(seconds: 10),
      ),
      clock: () => now,
    );

    expect(limiter.check(one), isNull);
    now = start.add(const Duration(seconds: 5));
    expect(limiter.check(two), isNull);
    now = start.add(const Duration(seconds: 1));
    expect(limiter.check(one), isNull);
    expect(limiter.check(one), const Duration(seconds: 5));
    now = start.add(const Duration(seconds: 10));
    expect(limiter.check(three), const Duration(seconds: 5));
    now = start.add(const Duration(seconds: 15));
    expect(limiter.check(three), isNull);
  });

  test(
    'admissions agree with a sliding log across sustained mixed traffic',
    () {
      var now = DateTime.utc(2026);
      final limiter = RpcHttpRateLimiter(
        const RpcHttpRateLimitOptions(
          maxRequests: 7,
          maxKeys: 3,
          window: Duration(microseconds: 100),
        ),
        clock: () => now,
      );
      final admitted = <String, List<DateTime>>{};
      final random = Random(42);
      for (var index = 0; index < 3000; index++) {
        now = now.add(Duration(microseconds: random.nextInt(12)));
        final key = '${random.nextInt(5)}';
        final cutoff = now.subtract(const Duration(microseconds: 100));
        for (final timestamps in admitted.values) {
          timestamps.removeWhere((timestamp) => !timestamp.isAfter(cutoff));
        }
        admitted.removeWhere((_, timestamps) => timestamps.isEmpty);
        final timestamps = admitted[key];
        Duration? expected;
        if (timestamps == null && admitted.length == 3) {
          final earliestExpiry = admitted.values
              .map((timestamps) => timestamps.last)
              .reduce((left, right) => left.isBefore(right) ? left : right)
              .add(const Duration(microseconds: 100));
          expected = earliestExpiry.difference(now);
        } else if (timestamps != null && timestamps.length == 7) {
          expected = timestamps.first
              .add(const Duration(microseconds: 100))
              .difference(now);
        } else {
          (admitted[key] ??= []).add(now);
        }
        expect(
          limiter.check(
            RpcHttpRequest(method: 'GET', path: '/', remoteAddress: key),
          ),
          expected,
          reason: 'request $index for $key at $now',
        );
      }
    },
  );

  test('invalid rate limit values are rejected', () {
    for (final options in [
      const RpcHttpRateLimitOptions(maxRequests: 0),
      const RpcHttpRateLimitOptions(maxRequests: -1),
      const RpcHttpRateLimitOptions(maxRequests: 1, window: Duration.zero),
      const RpcHttpRateLimitOptions(maxRequests: 1, maxKeys: 0),
    ]) {
      expect(() => RpcHttpRateLimiter(options), throwsArgumentError);
    }
  });
}
