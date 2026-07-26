import 'dart:convert';

import 'package:benchmark_workloads/benchmark_workloads.dart';
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

final class CatalogRoute extends Route {
  CatalogRoute() : super(methods: const {Method.get});

  @override
  Result handleCall(Session session, Request request) {
    try {
      final query = request.url.queryParameters;
      return _jsonResponse(
        buildCatalog(
          category: query['category'] ?? '',
          page: int.parse(query['page'] ?? ''),
          limit: int.parse(query['limit'] ?? ''),
        ),
      );
    } on FormatException catch (error) {
      return _badRequest(error.message);
    }
  }
}

final class CheckoutRoute extends Route {
  CheckoutRoute() : super(methods: const {Method.post});

  @override
  Future<Result> handleCall(Session session, Request request) async {
    try {
      return _jsonResponse(
        processCheckout(jsonDecode(await request.readAsString())),
      );
    } on FormatException catch (error) {
      return _badRequest(error.message);
    }
  }
}

Response _jsonResponse(Object? body) {
  return Response.ok(
    body: Body.fromString(jsonEncode(body), mimeType: MimeType.json),
  );
}

Response _badRequest(String message) {
  return Response(
    400,
    body: Body.fromString(
      jsonEncode({'error': message}),
      mimeType: MimeType.json,
    ),
  );
}
