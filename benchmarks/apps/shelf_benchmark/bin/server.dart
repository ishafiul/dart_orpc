import 'dart:convert';
import 'dart:io';

import 'package:benchmark_workloads/benchmark_workloads.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

const _message = 'Hello, World!';

Future<void> main() async {
  final router = Router()
    ..get('/plaintext', _plaintext)
    ..get('/json', _json)
    ..post('/echo', _echo)
    ..get('/catalog', _catalog)
    ..post('/checkout', _checkout);

  final port = int.parse(Platform.environment['PORT'] ?? '8082');
  final server = await shelf_io.serve(
    router.call,
    InternetAddress.anyIPv6,
    port,
  );
  stdout.writeln('READY shelf ${server.port}');
}

Response _plaintext(Request _) => Response.ok(
  _message,
  headers: const {'content-type': 'text/plain; charset=utf-8'},
);

Response _json(Request _) => Response.ok(
  jsonEncode(const {'message': _message}),
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

Future<Response> _echo(Request request) async {
  final body = jsonDecode(await request.readAsString());
  return Response.ok(
    jsonEncode(body),
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

Response _catalog(Request request) {
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

Future<Response> _checkout(Request request) async {
  try {
    return _jsonResponse(
      processCheckout(jsonDecode(await request.readAsString())),
    );
  } on FormatException catch (error) {
    return _badRequest(error.message);
  }
}

Response _jsonResponse(Object? body) => Response.ok(
  jsonEncode(body),
  headers: const {'content-type': 'application/json; charset=utf-8'},
);

Response _badRequest(String message) => Response(
  HttpStatus.badRequest,
  body: jsonEncode({'error': message}),
  headers: const {'content-type': 'application/json; charset=utf-8'},
);
