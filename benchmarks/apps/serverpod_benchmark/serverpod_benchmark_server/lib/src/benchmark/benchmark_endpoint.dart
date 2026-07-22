import 'package:serverpod/serverpod.dart';

class BenchmarkEndpoint extends Endpoint {
  Future<String> plaintext(Session session) async => 'Hello, World!';

  Future<Map<String, String>> json(Session session) async {
    return const {'message': 'Hello, World!'};
  }

  Future<Map<String, String>> echo(
    Session session,
    Map<String, String> input,
  ) async {
    return input;
  }
}
