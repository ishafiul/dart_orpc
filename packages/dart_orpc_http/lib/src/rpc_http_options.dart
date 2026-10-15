import 'dart:collection';

import 'rpc_http_handler.dart';
import 'middleware/cors.dart';

/// Optional policies owned by the HTTP adapter. Deadlines are disabled by default.
final class RpcHttpServerOptions {
  const RpcHttpServerOptions({
    this.cors,
    this.onError,
    this.onComplete,
    this.requestIdFactory,
    this.trustRequestId = false,
    this.maxHeaderBytes,
    this.bodyTimeout,
    this.handlerTimeout,
    this.compress = false,
    this.rateLimit,
  });

  /// Applies to all responses, including failures before request middleware.
  final CorsOptions? cors;
  final void Function(RpcHttpErrorEvent event)? onError;
  final void Function(RpcHttpCompletion event)? onComplete;
  final String Function()? requestIdFactory;
  final bool trustRequestId;
  final int? maxHeaderBytes;
  final Duration? bodyTimeout;
  final Duration? handlerTimeout;
  final bool compress;
  final RpcHttpRateLimitOptions? rateLimit;
}

final class RpcHttpErrorEvent {
  const RpcHttpErrorEvent({
    required this.request,
    required this.error,
    required this.stackTrace,
  });
  final RpcHttpRequest request;
  final Object error;
  final StackTrace stackTrace;
}

final class RpcHttpCompletion {
  const RpcHttpCompletion({
    required this.request,
    required this.route,
    required this.statusCode,
    required this.elapsed,
    required this.receivedBytes,
    required this.sentBytes,
    required this.streaming,
    required this.disconnected,
    this.failed = false,
  });
  final RpcHttpRequest request;

  /// Registered route template, or a bounded framework label for unmatched paths.
  final String route;
  final int statusCode;
  final Duration elapsed;
  final int receivedBytes;

  /// Encoded body bytes passed to the HTTP writer, excluding HTTP framing.
  final int sentBytes;
  final bool streaming;
  final bool disconnected;
  final bool failed;
}

final class RpcHttpRateLimitOptions {
  const RpcHttpRateLimitOptions({
    required this.maxRequests,
    this.window = const Duration(minutes: 1),
    this.maxKeys = 10000,
    this.key,
  });
  final int maxRequests;
  final Duration window;

  /// Hard bound on identities in each limiter instance. New identities are rejected
  /// while full; active entries are never evicted to bypass a limit.
  final int maxKeys;

  /// Defaults to the direct peer address. Proxy headers are never trusted implicitly.
  final String Function(RpcHttpRequest request)? key;
}

final class RpcHttpRateLimiter {
  RpcHttpRateLimiter(this.options, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now,
      _windowMicroseconds = options.window.inMicroseconds {
    if (options.maxRequests <= 0 ||
        options.window <= Duration.zero ||
        options.maxKeys <= 0) {
      throw ArgumentError('Rate limit values must be positive.');
    }
  }
  final RpcHttpRateLimitOptions options;
  final DateTime Function() _clock;
  final int _windowMicroseconds;
  final Map<String, _RateLimitBucket> _entries = {};
  int? _lastCheckMicroseconds;

  /// Null means admitted; otherwise the minimum Retry-After duration.
  Duration? check(RpcHttpRequest request) {
    final clockMicroseconds = _clock().microsecondsSinceEpoch;
    final previousCheck = _lastCheckMicroseconds;
    // Preserve timestamp and identity expiry order across wall-clock rollbacks.
    final now = previousCheck != null && clockMicroseconds < previousCheck
        ? previousCheck
        : clockMicroseconds;
    _lastCheckMicroseconds = now;
    final cutoff = now - _windowMicroseconds;
    // Admitted keys move to the end, ordering whole-bucket expiry by the latest
    // timestamp. Cleanup visits expired identities without scanning active ones.
    while (_entries.isNotEmpty &&
        _entries.values.first.requests.last <= cutoff) {
      _entries.remove(_entries.keys.first);
    }
    final key =
        options.key?.call(request) ?? request.remoteAddress ?? 'unknown';
    final entry = _entries[key];
    if (entry == null) {
      if (_entries.length >= options.maxKeys) {
        return Duration(
          microseconds:
              _entries.values.first.requests.last + _windowMicroseconds - now,
        );
      }
      _entries[key] = _RateLimitBucket(now);
      return null;
    }
    while (entry.requests.isNotEmpty && entry.requests.first <= cutoff) {
      entry.requests.removeFirst();
    }
    if (entry.requests.length >= options.maxRequests) {
      return Duration(
        microseconds: entry.requests.first + _windowMicroseconds - now,
      );
    }
    entry.requests.addLast(now);
    _entries.remove(key);
    _entries[key] = entry;
    return null;
  }
}

final class _RateLimitBucket {
  _RateLimitBucket(int timestamp) {
    requests.addLast(timestamp);
  }

  final ListQueue<int> requests = ListQueue<int>();
}
