import 'rpc_cancellation.dart';

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

  RpcContextBindings._(Map<RpcContextKey<Object>, Object> values)
    : _values = Map<RpcContextKey<Object>, Object>.unmodifiable(values);

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

  final Map<String, String> headers;
  final String httpMethod;
  final String path;
  final Map<String, Object?> attributes;
  final RpcContextBindings bindings;
  final RpcCancellationSignal cancellation;

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
    return RpcContext(
      headers: headers ?? this.headers,
      httpMethod: httpMethod ?? this.httpMethod,
      path: path ?? this.path,
      attributes: attributes ?? this.attributes,
      bindings: bindings ?? this.bindings,
      cancellation: cancellation ?? this.cancellation,
    );
  }
}
