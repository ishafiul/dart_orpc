import 'package:serverpod/serverpod.dart';

import 'src/benchmark/benchmark_routes.dart';
import 'src/generated/endpoints.dart';
import 'src/generated/protocol.dart';

Future<void> run(List<String> args) async {
  final pod = Serverpod(args, Protocol(), Endpoints());
  pod.webServer
    ..addRoute(PlaintextRoute(), '/plaintext')
    ..addRoute(JsonRoute(), '/json')
    ..addRoute(EchoRoute(), '/echo');
  await pod.start();
}
