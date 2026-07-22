import 'dart:convert';

import 'package:serverpod/serverpod.dart';

const _message = 'Hello, World!';

final class PlaintextRoute extends Route {
  PlaintextRoute();

  @override
  Result handleCall(Session session, Request request) {
    return Response.ok(
      body: Body.fromString(_message, mimeType: MimeType.plainText),
    );
  }
}

final class JsonRoute extends Route {
  JsonRoute();

  @override
  Result handleCall(Session session, Request request) {
    return Response.ok(
      body: Body.fromString(
        jsonEncode(const {'message': _message}),
        mimeType: MimeType.json,
      ),
    );
  }
}

final class EchoRoute extends Route {
  EchoRoute() : super(methods: const {Method.post});

  @override
  Future<Result> handleCall(Session session, Request request) async {
    final input = jsonDecode(await request.readAsString());
    return Response.ok(
      body: Body.fromString(jsonEncode(input), mimeType: MimeType.json),
    );
  }
}
