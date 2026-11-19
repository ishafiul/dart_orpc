import 'dart:async';
import 'dart:math';

import 'rpc_cancellation.dart';

/// Waits for real time to pass.
///
/// Inject it wherever code must wait on purpose, such as a retry backoff, a
/// rate limit or a polling interval, instead of calling `Future.delayed`. The
/// waiting then has one owner, and tests replace it with [RecordingDelay] so
/// they run instantly and deterministically.
abstract interface class Delay {
  /// Completes after [duration], or fails with the cancellation error as soon
  /// as [cancellation] is cancelled.
  Future<void> wait(
    Duration duration, {
    RpcCancellationSignal cancellation = RpcCancellationSignal.none,
  });
}

/// A [Delay] backed by a [Timer].
final class SystemDelay implements Delay {
  const SystemDelay();

  @override
  Future<void> wait(
    Duration duration, {
    RpcCancellationSignal cancellation = RpcCancellationSignal.none,
  }) {
    if (cancellation.isCancelled) {
      return Future.sync(cancellation.throwIfCancelled);
    }
    final done = Completer<void>();
    late final RpcCancellationRegistration registration;
    final timer = Timer(duration, () {
      registration.dispose();
      done.complete();
    });
    registration = cancellation.onCancel(() {
      timer.cancel();
      if (!done.isCompleted) {
        done.complete(Future.sync(cancellation.throwIfCancelled));
      }
    });
    return done.future;
  }
}

/// A [Delay] for tests: returns at once and records every requested wait.
final class RecordingDelay implements Delay {
  final List<Duration> waits = [];

  @override
  Future<void> wait(
    Duration duration, {
    RpcCancellationSignal cancellation = RpcCancellationSignal.none,
  }) {
    if (cancellation.isCancelled) {
      return Future.sync(cancellation.throwIfCancelled);
    }
    waits.add(duration);
    return Future.value();
  }
}

/// Retries an operation that failed for a known, transient reason, with
/// exponential backoff and jitter.
///
/// There is no blind retry: [run] requires a `retryIf` that names the
/// failures worth retrying, and every other failure is rethrown at once.
final class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 200),
    this.multiplier = 2,
    this.maxDelay = const Duration(seconds: 10),
    this.jitter = 0.2,
  }) : assert(maxAttempts >= 1, 'maxAttempts must be at least 1'),
       assert(multiplier >= 1, 'multiplier must be at least 1'),
       assert(jitter >= 0 && jitter <= 1, 'jitter must be between 0 and 1');

  /// Attempts in total, including the first one.
  final int maxAttempts;
  final Duration initialDelay;
  final double multiplier;
  final Duration maxDelay;

  /// How far a wait may move from the exponential value, as a share of it:
  /// 0.2 spreads waits over 80%..120%, so many clients do not retry together.
  final double jitter;

  /// The wait before retry number [retry], counted from 1.
  Duration backoff(int retry, {Random? random}) {
    final exponential =
        initialDelay.inMicroseconds * pow(multiplier, retry - 1).toDouble();
    final spread = jitter == 0
        ? 1.0
        : 1 - jitter + (random ?? _random).nextDouble() * 2 * jitter;
    final micros = min(exponential * spread, maxDelay.inMicroseconds * 1.0);
    return Duration(microseconds: micros.round());
  }

  /// Runs [action] until it succeeds, a failure is not retryable, or
  /// [maxAttempts] are used. [action] receives the attempt number, from 1.
  Future<T> run<T>(
    Future<T> Function(int attempt) action, {
    required bool Function(Object error) retryIf,
    required Delay delay,
    RpcCancellationSignal cancellation = RpcCancellationSignal.none,
    Random? random,
  }) async {
    for (var attempt = 1; ; attempt++) {
      cancellation.throwIfCancelled();
      try {
        return await action(attempt);
      } on Object catch (error) {
        if (attempt >= maxAttempts || !retryIf(error)) {
          rethrow;
        }
      }
      await delay.wait(
        backoff(attempt, random: random),
        cancellation: cancellation,
      );
    }
  }
}

final _random = Random();
