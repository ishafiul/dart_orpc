import 'rpc_cancellation.dart';

const _minimumIndexedHeaderLookups = 8;

/// Correlation ID assigned by the transport at the request boundary.
const rpcRequestIdKey = RpcContextKey<String>('dart_orpc.requestId');

final class RpcContextKey<T extends Object> {
  const RpcContextKey(this.name);

  final String name;

  T cast(Object? value) {
    if (value is T) {
      return value;
    }
    throw StateError(
      'RpcContext binding "$name" has type ${value.runtimeType}, expected $T.',
    );
  }
}

final class RpcContextBindings {
  const RpcContextBindings.empty() : _values = const {};

  // Only freshly owned maps enter this constructor; storage is never exposed.
  RpcContextBindings._(this._values);

  final Map<RpcContextKey<Object>, Object> _values;

  RpcContextBindings withValue<T extends Object>(
    RpcContextKey<T> key,
    T value,
  ) {
    return RpcContextBindings._({..._values, key: value});
  }

  RpcContextBindings merge(RpcContextBindings other) {
    if (_values.isEmpty) {
      return other;
    }
    if (other._values.isEmpty) {
      return this;
    }
    return RpcContextBindings._({..._values, ...other._values});
  }

  RpcContextBindingsBuilder toBuilder() => RpcContextBindingsBuilder(this);

  T? get<T extends Object>(RpcContextKey<T> key) {
    final value = _values[key];
    return value == null ? null : key.cast(value);
  }

  T require<T extends Object>(RpcContextKey<T> key) {
    final value = _values[key];
    if (value == null) {
      throw StateError('RpcContext binding "${key.name}" is missing.');
    }
    return key.cast(value);
  }
}

/// Accumulates typed updates and transfers ownership on build. Reusable: later
/// updates copy only when a previously built snapshot still owns the map.
final class RpcContextBindingsBuilder {
  RpcContextBindingsBuilder([
    RpcContextBindings bindings = const RpcContextBindings.empty(),
  ]) : _values = bindings._values;

  Map<RpcContextKey<Object>, Object> _values;
  bool _shared = true;

  void set<T extends Object>(RpcContextKey<T> key, T value) {
    _ensureOwned();
    _values[key] = value;
  }

  void addAll(RpcContextBindings bindings) {
    if (bindings._values.isEmpty) return;
    _ensureOwned();
    _values.addAll(bindings._values);
  }

  void _ensureOwned() {
    if (_shared) {
      _values = {..._values};
      _shared = false;
    }
  }

  RpcContextBindings build() {
    _shared = true;
    return RpcContextBindings._(_values);
  }
}

final class RpcContext {
  RpcContext({
    required Map<String, String> headers,
    this.httpMethod = 'POST',
    this.path = '/rpc',
    Map<String, Object?> attributes = const {},
    this.bindings = const RpcContextBindings.empty(),
    this.cancellation = RpcCancellationSignal.none,
  }) : headers = Map<String, String>.unmodifiable(headers),
       attributes = Map<String, Object?>.unmodifiable(attributes);

  RpcContext._({
    required this.headers,
    required this.httpMethod,
    required this.path,
    required this.attributes,
    required this.bindings,
    required this.cancellation,
  });

  final Map<String, String> headers;
  final String httpMethod;
  final String path;
  final Map<String, Object?> attributes;
  final RpcContextBindings bindings;
  final RpcCancellationSignal cancellation;
  bool? _canonicalHeaders;
  Map<String, String>? _headerIndex;

  /// Case-insensitive lookup. Duplicate spellings retain their first value.
  String? headerValue(String name) {
    final normalized = name.toLowerCase();
    if (_canonicalHeaders == true) return headers[normalized];
    final index = _headerIndex;
    if (index != null) return index[normalized];
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == normalized) return entry.value;
    }
    return null;
  }

  /// Amortizes normalization when a procedure binds many headers.
  void prepareHeaderLookup(int lookupCount) {
    if (lookupCount < 2 || _headerIndex != null) return;
    final canonical = _canonicalHeaders ??= headers.keys.every(
      (name) => name == name.toLowerCase(),
    );
    if (canonical || lookupCount < _minimumIndexedHeaderLookups) return;
    final indexed = <String, String>{};
    for (final entry in headers.entries) {
      indexed.putIfAbsent(entry.key.toLowerCase(), () => entry.value);
    }
    _headerIndex = indexed;
  }

  T? binding<T extends Object>(RpcContextKey<T> key) => bindings.get(key);

  T requireBinding<T extends Object>(RpcContextKey<T> key) =>
      bindings.require(key);

  RpcContext copyWith({
    Map<String, String>? headers,
    String? httpMethod,
    String? path,
    Map<String, Object?>? attributes,
    RpcContextBindings? bindings,
    RpcCancellationSignal? cancellation,
  }) {
    return RpcContext._(
      headers: headers == null
          ? this.headers
          : Map<String, String>.unmodifiable(headers),
      httpMethod: httpMethod ?? this.httpMethod,
      path: path ?? this.path,
      attributes: attributes == null
          ? this.attributes
          : Map<String, Object?>.unmodifiable(attributes),
      bindings: bindings ?? this.bindings,
      cancellation: cancellation ?? this.cancellation,
    );
  }
}
