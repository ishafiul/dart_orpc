final class Module {
  const Module({this.controllers = const [], this.providers = const []});

  final List<Type> controllers;
  final List<Type> providers;
}

final class Controller {
  const Controller(this.namespace);

  final String namespace;
}

final class RestMapping {
  const RestMapping.get(String path) : method = 'GET', rawPath = path;

  const RestMapping.post(String path) : method = 'POST', rawPath = path;

  const RestMapping.put(String path) : method = 'PUT', rawPath = path;

  const RestMapping.patch(String path) : method = 'PATCH', rawPath = path;

  const RestMapping.delete(String path) : method = 'DELETE', rawPath = path;

  final String method;
  final String rawPath;

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

final class RpcInput {
  const RpcInput();
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
