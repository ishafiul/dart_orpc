final class ProjectTemplate {
  const ProjectTemplate({required this.packageName});

  final String packageName;

  Map<String, String> get files => {
    'pubspec.yaml': _pubspec,
    'README.md': _readme,
    'bin/server.dart': _server,
    'lib/$packageName.dart': _library,
    'lib/src/app.dart': _app,
    'lib/src/hello/hello_controller.dart': _helloController,
    'lib/src/hello/hello_module.dart': _helloModule,
  };

  String get _pubspec =>
      '''
name: $packageName
description: A minimal dart_orpc server.
version: 0.1.0
publish_to: none

environment:
  sdk: ^3.11.0

dependencies:
  dart_orpc: ^0.1.0-dev.2

dev_dependencies:
  build_runner: ^2.12.2
  dart_orpc_generator: ^0.1.0-dev.2
''';

  String get _readme =>
      '''
# $packageName

A minimal hello-world API built with `dart_orpc`.

```sh
dart run build_runner build
dart run bin/server.dart
```

The server exposes `hello.say` over `POST /rpc` and `GET /hello`.
''';

  String get _server =>
      '''
import 'dart:io';

import 'package:$packageName/$packageName.dart';

Future<void> main() async {
  final app = const AppModule().buildRpcApp();
  final port = int.tryParse(Platform.environment['PORT'] ?? '') ?? 3000;
  final server = await app.listen(port);

  print('dart_orpc listening on http://127.0.0.1:\${server.port}');
  print('RPC:  POST /rpc  method: hello.say');
  print('REST: GET  /hello');
}
''';

  String get _library => '''
library;

export 'src/app.orpc.dart';
''';

  String get _app => '''
import 'package:dart_orpc/dart_orpc.dart';

import 'hello/hello_module.dart';

@Module(imports: [HelloModule])
final class AppModule {
  const AppModule();
}
''';

  String get _helloController => '''
import 'package:dart_orpc/dart_orpc.dart';

part 'hello_controller.g.dart';

@Controller('hello')
final class HelloController {
  const HelloController();

  @RpcMethod(
    name: 'say',
    path: RestMapping.get('/hello'),
    description: 'Return a hello-world message.',
    tags: ['hello'],
  )
  Future<HelloResponse> say(RpcContext _) async {
    return const HelloResponse(message: 'Hello, World!');
  }
}

final class HelloResponse {
  const HelloResponse({required this.message});

  factory HelloResponse.fromJson(Map<String, Object?> json) {
    return HelloResponse(message: json['message']! as String);
  }

  final String message;

  Map<String, Object?> toJson() => {'message': message};
}
''';

  String get _helloModule => '''
import 'package:dart_orpc/dart_orpc.dart';

import 'hello_controller.dart';

@Module(controllers: [HelloController])
final class HelloModule {
  const HelloModule();
}
''';
}
