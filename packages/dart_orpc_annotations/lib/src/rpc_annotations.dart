final class Module {
  const Module({this.controllers = const [], this.providers = const []});

  final List<Type> controllers;
  final List<Type> providers;
}

final class Controller {
  const Controller(this.namespace);

  final String namespace;
}

final class RpcMethod {
  const RpcMethod({this.name});

  final String? name;
}

final class RpcInput {
  const RpcInput();
}
