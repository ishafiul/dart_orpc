import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

const _message = 'Hello, World!';

Future<void> main() async {
  final router = Router()
    ..get('/plaintext', _plaintext)
    ..get('/json', _json)
    ..post('/echo', _echo);

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
