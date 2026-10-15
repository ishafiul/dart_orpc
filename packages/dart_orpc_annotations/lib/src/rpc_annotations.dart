final class Module {
  const Module({
    this.imports = const [],
    this.controllers = const [],
    this.providers = const [],
    this.bindings = const [],
    this.exports = const [],
    this.global = false,
  });

  final List<Type> imports;
  final List<Type> controllers;
  final List<Type> providers;
  final List<RpcProviderBinding> bindings;
  final List<Type> exports;

  /// Whether this module's explicitly exported providers are visible to every
  /// module in the reachable application graph.
  final bool global;
}

/// Binds an injectable token to a generated class or factory.
///
/// Providers are singletons within one generated application container.
final class RpcProviderBinding {
  const RpcProviderBinding.useClass({
    required this.provide,
    required this.useClass,
  }) : factory = null;

  const RpcProviderBinding.useFactory({
    required this.provide,
    required this.factory,
  }) : useClass = null;

  /// Type consumed by constructor parameters and exported by the module.
  final Type provide;

  /// Injectable class used to create [provide].
  final Type? useClass;

  /// Top-level or static synchronous factory used to create [provide].
  final Function? factory;
}

final class Controller {
  const Controller(this.namespace);

  final String namespace;
}

final class RestMapping {
  const RestMapping.get(String path, {this.statusCode, this.headers = const {}})
    : method = 'GET',
      rawPath = path,
      isSse = false;

  const RestMapping.post(
    String path, {
    this.statusCode,
    this.headers = const {},
  }) : method = 'POST',
       rawPath = path,
       isSse = false;

  const RestMapping.put(String path, {this.statusCode, this.headers = const {}})
    : method = 'PUT',
      rawPath = path,
      isSse = false;

  const RestMapping.patch(
    String path, {
    this.statusCode,
    this.headers = const {},
  }) : method = 'PATCH',
       rawPath = path,
       isSse = false;

  const RestMapping.delete(
    String path, {
    this.statusCode,
    this.headers = const {},
  }) : method = 'DELETE',
       rawPath = path,
       isSse = false;

  const RestMapping.sse(String path, {this.statusCode, this.headers = const {}})
    : method = 'GET',
      rawPath = path,
      isSse = true;

  final int? statusCode;
  final Map<String, String> headers;
  final String method;
  final String rawPath;
  final bool isSse;

  String get path {
    if (rawPath.isEmpty) {
      return '/';
    }

    return rawPath.startsWith('/') ? rawPath : '/$rawPath';
  }
}

final class RpcMethod {
  const RpcMethod({
    this.name,
    this.path,
    this.description,
    this.tags = const [],
  });

  final String? name;
  final RestMapping? path;
  final String? description;
  final List<String> tags;
}

final class UseGuards {
  const UseGuards(this.guards);

  final List<Type> guards;
}

/// Declares that a procedure requires an HTTP Bearer token.
///
/// This annotation describes the public API contract. Applications still
/// provide the guard that validates the token and populates [RpcContext].
final class BearerAuth {
  const BearerAuth({required this.guard});

  /// Application guard that validates the bearer token.
  final Type guard;
}

final class RpcMetadata {
  const RpcMetadata(this.key);

  final String key;
}

final class RpcInputField<T> {
  const RpcInputField(this.field, [this.name]);

  final String field;
  final String? name;
}

final class RpcInputBinding<T> {
  const RpcInputBinding({
    this.path = const [],
    this.query = const [],
    this.headers = const [],
    this.body = const [],
  });

  final List<RpcInputField<T>> path;
  final List<RpcInputField<T>> query;
  final List<RpcInputField<T>> headers;
  final List<RpcInputField<T>> body;
}

final class RpcInput {
  const RpcInput({this.binding});

  final RpcInputBinding<dynamic>? binding;
}

final class PathParam {
  const PathParam([this.name]);

  final String? name;
}

final class QueryParam {
  const QueryParam([this.name]);

  final String? name;
}

final class Body {
  const Body();
}

final class FromPath {
  const FromPath([this.name]);

  final String? name;
}

final class FromQuery {
  const FromQuery([this.name]);

  final String? name;
}

final class FromHeader {
  const FromHeader([this.name]);

  final String? name;
}
