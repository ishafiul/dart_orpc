import 'dart:io';

import 'package:dart_orpc_user_test_benchmark/challenge_app.orpc.dart';
import 'package:dart_orpc_user_test_benchmark/challenge_auth.dart';
import 'package:dart_orpc_user_test_benchmark/challenge_wire_middleware.dart';

Future<void> main() async {
  final host = Platform.environment['HOST'] ?? '127.0.0.1';
  final port = int.parse(Platform.environment['PORT'] ?? '3000');
  final app = const ChallengeModule().buildRpcApp(
    contextFactory: challengeContextFactory,
    middleware: [challengeWireMiddleware],
  );
  final server = await app.listen(port, hostname: host);
  stdout.writeln('READY dart_orpc_user_test_benchmark ${server.port}');
}
