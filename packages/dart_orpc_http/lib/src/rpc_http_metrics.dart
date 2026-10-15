import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'rpc_http_options.dart';

/// Collector-local counters; callers supply only registered route templates.
final class RpcHttpMetricsCollector {
  static const _buckets = [
    0.005,
    0.01,
    0.025,
    0.05,
    0.1,
    0.25,
    0.5,
    1.0,
    2.5,
    5.0,
    10.0,
  ];
  final _started = Stopwatch()..start();
  final Map<String, _RouteMetrics> _routes = {};
  int activeRequests = 0;
  int activeStreams = 0;
  int hookErrors = 0;

  void begin() => activeRequests++;
  void beginStream() => activeStreams++;
  void complete(RpcHttpCompletion event) {
    activeRequests--;
    if (event.streaming) activeStreams--;
    final method =
        const {
          'GET',
          'POST',
          'PUT',
          'PATCH',
          'DELETE',
          'HEAD',
          'OPTIONS',
        }.contains(event.request.method)
        ? event.request.method
        : 'OTHER';
    final key = '$method ${event.route}';
    final route = _routes.putIfAbsent(key, _RouteMetrics.new);
    route.requests++;
    if (event.statusCode >= 400 || event.failed) route.errors++;
    if (event.statusCode == 429 || event.statusCode == 503) route.rejected++;
    route.receivedBytes += event.receivedBytes;
    route.sentBytes += event.sentBytes;
    final seconds =
        event.elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    route.durationSeconds += seconds;
    var low = 0;
    var high = _buckets.length;
    while (low < high) {
      final middle = (low + high) >> 1;
      if (seconds <= _buckets[middle]) {
        high = middle;
      } else {
        low = middle + 1;
      }
    }
    route.buckets[low]++;
  }

  JsonObject snapshot() => {
    'active_requests': activeRequests,
    'active_streams': activeStreams,
    'hook_errors': hookErrors,
    'uptime_seconds': _started.elapsed.inSeconds,
    'routes': {
      for (final entry in _routes.entries)
        entry.key: {
          'requests': entry.value.requests,
          'errors': entry.value.errors,
          'rejected': entry.value.rejected,
          'received_bytes': entry.value.receivedBytes,
          'sent_bytes': entry.value.sentBytes,
          'duration_seconds_sum': entry.value.durationSeconds,
          'duration_seconds_buckets': _cumulativeBuckets(entry.value),
        },
    },
  };

  Map<String, int> _cumulativeBuckets(_RouteMetrics route) {
    var count = 0;
    return {
      for (var index = 0; index < _buckets.length; index++)
        '${_buckets[index]}': count += route.buckets[index],
      '+Inf': route.requests,
    };
  }
}

final class _RouteMetrics {
  int requests = 0;
  int errors = 0;
  int rejected = 0;
  int receivedBytes = 0;
  int sentBytes = 0;
  double durationSeconds = 0;
  final List<int> buckets = List.filled(
    RpcHttpMetricsCollector._buckets.length + 1,
    0,
  );
}
