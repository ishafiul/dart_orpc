import 'dart:convert';
import 'dart:io';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_http/dart_orpc_http.dart';
import 'package:test/test.dart';

final class _Opaque {}

RpcException _errorFor(String kind) => switch (kind) {
  'details' => RpcException.conflict(
    'Version conflict.',
    details: {'currentVersion': 3},
  ),
  'opaque' => RpcException.conflict(
    'Version conflict.',
    details: {'opaque': _Opaque()},
  ),
  _ => RpcException.notFound('Item not found.'),
};

RpcHttpHandler _handler() {
  return createRpcHttpHandler(
    procedures: RpcProcedureRegistry([
      RpcProcedure<JsonObject, JsonObject>(
        method: 'item.fail',
        metadata: const ProcedureMetadata(
          rpcMethod: 'item.fail',
          controllerNamespace: 'item',
          methodName: 'fail',
          outputTypeCode: 'JsonObject',
        ),
        decodeInput: (input) => expectJsonObject(input, context: 'input'),
        encodeOutput: (output) => output,
        handler: (_, input) => throw _errorFor(input['kind'] as String),
      ),
    ]),
    restRoutes: RestRouteRegistry([
      RestRoute(
        method: 'GET',
        path: '/items/:kind',
        handler: (_, _, pathParameters) =>
            throw _errorFor(pathParameters['kind']!),
      ),
    ]),
  );
}

RpcHttpRequest _rpc(
  String kind, {
  void Function(Object error, StackTrace stackTrace)? onError,
}) {
  return RpcHttpRequest(
    method: 'POST',
    path: '/rpc',
    body: jsonEncode({
      'method': 'item.fail',
      'input': {'kind': kind},
    }),
    onError: onError,
  );
}

RpcHttpRequest _rest(
  String kind, {
  void Function(Object error, StackTrace stackTrace)? onError,
}) {
  return RpcHttpRequest(method: 'GET', path: '/items/$kind', onError: onError);
}

void main() {
  late RpcHttpHandler handler;

  setUp(() {
    handler = _handler();
  });

  group('Given a procedure that throws an error with details', () {
    test('When called over POST /rpc then the envelope has details', () async {
      final response = await handler(_rpc('details'));

      expect(response.statusCode, HttpStatus.conflict);
      expect(jsonDecode(response.body as String), {
        'error': {
          'code': 'CONFLICT',
          'message': 'Version conflict.',
          'details': {'currentVersion': 3},
        },
      });
    });

    test('When called over REST then the error object matches RPC', () async {
      final rpc = await handler(_rpc('details'));
      final rest = await handler(_rest('details'));

      expect(rest.statusCode, rpc.statusCode);
      expect(rest.body, rpc.body);
    });
  });

  group('Given a procedure that throws an error without details', () {
    test('When called over POST /rpc then the body is unchanged', () async {
      final response = await handler(_rpc('plain'));

      expect(
        response.body,
        '{"error":{"code":"NOT_FOUND","message":"Item not found."}}',
      );
    });

    test('When called over REST then the body is unchanged', () async {
      final response = await handler(_rest('plain'));

      expect(
        response.body,
        '{"error":{"code":"NOT_FOUND","message":"Item not found."}}',
      );
    });
  });

  group('Given details that cannot be encoded', () {
    late List<Object> reported;

    setUp(() {
      reported = [];
    });

    test(
      'When called over POST /rpc then the code is kept without details',
      () async {
        final response = await handler(
          _rpc('opaque', onError: (error, _) => reported.add(error)),
        );

        expect(response.statusCode, HttpStatus.conflict);
        expect(
          response.body,
          '{"error":{"code":"CONFLICT","message":"Version conflict."}}',
        );
      },
    );

    test(
      'When called over POST /rpc then the dropped details are reported',
      () async {
        await handler(
          _rpc('opaque', onError: (error, _) => reported.add(error)),
        );

        expect(reported, [
          isA<RpcException>(),
          isA<RpcErrorDetailsEncodingException>(),
        ]);
      },
    );

    test(
      'When called over REST then the dropped details are reported',
      () async {
        final response = await handler(
          _rest('opaque', onError: (error, _) => reported.add(error)),
        );

        expect(
          response.body,
          '{"error":{"code":"CONFLICT","message":"Version conflict."}}',
        );
        expect(reported.last, isA<RpcErrorDetailsEncodingException>());
      },
    );
  });

  group('Given an RpcHttpApp and details that cannot be encoded', () {
    late RpcHttpServer server;
    late List<RpcHttpErrorEvent> events;

    setUp(() async {
      events = [];
      server = await RpcHttpApp(
        procedures: RpcProcedureRegistry([
          RpcProcedure<JsonObject, JsonObject>(
            method: 'item.fail',
            metadata: const ProcedureMetadata(
              rpcMethod: 'item.fail',
              controllerNamespace: 'item',
              methodName: 'fail',
              outputTypeCode: 'JsonObject',
            ),
            decodeInput: (input) => expectJsonObject(input, context: 'input'),
            encodeOutput: (output) => output,
            handler: (_, _) => throw _errorFor('opaque'),
          ),
        ]),
        serverOptions: RpcHttpServerOptions(onError: events.add),
      ).listen(0, hostname: InternetAddress.loopbackIPv4.address);
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test(
      'When called then onError gets the error and the dropped details',
      () async {
        final client = HttpClient();
        addTearDown(() => client.close(force: true));
        final request = await client.postUrl(
          Uri.parse('http://${server.address.address}:${server.port}/rpc'),
        );
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode({'method': 'item.fail', 'input': {}}));
        final response = await request.close();
        final body = await utf8.decoder.bind(response).join();

        expect(response.statusCode, HttpStatus.conflict);
        expect(
          body,
          '{"error":{"code":"CONFLICT","message":"Version conflict."}}',
        );
        expect(events.map((event) => event.error), [
          isA<RpcException>(),
          isA<RpcErrorDetailsEncodingException>(),
        ]);
        expect(
          events.map((event) => event.transport),
          everyElement(RpcTransportKind.http),
        );
      },
    );
  });
}
