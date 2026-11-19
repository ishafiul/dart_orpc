import 'dart:math';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:test/test.dart';

final class _Transient implements Exception {
  const _Transient();
}

final class _Permanent implements Exception {
  const _Permanent();
}

bool _isTransient(Object error) => error is _Transient;

void main() {
  group('Given SystemDelay', () {
    test('When the duration passes then the wait completes', () async {
      final watch = Stopwatch()..start();

      await const SystemDelay().wait(const Duration(milliseconds: 20));

      expect(
        watch.elapsed,
        greaterThanOrEqualTo(const Duration(milliseconds: 15)),
      );
    });

    test(
      'When cancelled during the wait then it fails at once with cancelled',
      () async {
        final source = RpcCancellationSource();
        final watch = Stopwatch()..start();

        final wait = const SystemDelay().wait(
          const Duration(seconds: 30),
          cancellation: source.signal,
        );
        source.cancel();

        await expectLater(
          wait,
          throwsA(
            isA<RpcException>().having(
              (error) => error.code,
              'code',
              RpcErrorCode.cancelled,
            ),
          ),
        );
        expect(watch.elapsed, lessThan(const Duration(seconds: 5)));
      },
    );

    test(
      'When already cancelled then the wait fails without starting',
      () async {
        final source = RpcCancellationSource()..cancel();

        await expectLater(
          const SystemDelay().wait(Duration.zero, cancellation: source.signal),
          throwsA(isA<RpcException>()),
        );
      },
    );
  });

  group('Given a RetryPolicy', () {
    const policy = RetryPolicy(
      maxAttempts: 4,
      initialDelay: Duration(milliseconds: 100),
      maxDelay: Duration(milliseconds: 300),
      jitter: 0,
    );

    test('When backoff grows then it doubles and stops at the maximum', () {
      expect(
        [for (var retry = 1; retry <= 4; retry++) policy.backoff(retry)],
        const [
          Duration(milliseconds: 100),
          Duration(milliseconds: 200),
          Duration(milliseconds: 300),
          Duration(milliseconds: 300),
        ],
      );
    });

    test(
      'When jitter is set then waits spread around the exponential value',
      () {
        const jittered = RetryPolicy(
          initialDelay: Duration(milliseconds: 100),
          jitter: 0.2,
        );
        final random = Random(1);

        final waits = [
          for (var index = 0; index < 50; index++)
            jittered.backoff(1, random: random).inMilliseconds,
        ];

        expect(waits, everyElement(inInclusiveRange(80, 120)));
        expect(waits.toSet().length, greaterThan(1));
      },
    );

    test(
      'When a transient failure clears then the action is retried with backoff',
      () async {
        final delay = RecordingDelay();
        final attempts = <int>[];

        final result = await policy.run(
          (attempt) async {
            attempts.add(attempt);
            if (attempt < 3) {
              throw const _Transient();
            }
            return 'done';
          },
          retryIf: _isTransient,
          delay: delay,
        );

        expect(result, 'done');
        expect(attempts, [1, 2, 3]);
        expect(delay.waits, const [
          Duration(milliseconds: 100),
          Duration(milliseconds: 200),
        ]);
      },
    );

    test(
      'When a failure is not retryable then it is rethrown without waiting',
      () async {
        final delay = RecordingDelay();
        var attempts = 0;

        await expectLater(
          policy.run<void>(
            (_) async {
              attempts++;
              throw const _Permanent();
            },
            retryIf: _isTransient,
            delay: delay,
          ),
          throwsA(isA<_Permanent>()),
        );
        expect(attempts, 1);
        expect(delay.waits, isEmpty);
      },
    );

    test(
      'When every attempt fails then the last failure is rethrown',
      () async {
        final delay = RecordingDelay();
        var attempts = 0;

        await expectLater(
          policy.run<void>(
            (_) async {
              attempts++;
              throw const _Transient();
            },
            retryIf: _isTransient,
            delay: delay,
          ),
          throwsA(isA<_Transient>()),
        );
        expect(attempts, 4);
        expect(delay.waits, hasLength(3));
      },
    );

    test('When the call is cancelled then retrying stops', () async {
      final source = RpcCancellationSource();
      var attempts = 0;

      await expectLater(
        policy.run<void>(
          (_) async {
            attempts++;
            source.cancel();
            throw const _Transient();
          },
          retryIf: _isTransient,
          delay: RecordingDelay(),
          cancellation: source.signal,
        ),
        throwsA(isA<RpcException>()),
      );
      expect(attempts, 1);
    });
  });
}
