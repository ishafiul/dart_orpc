import 'dart:convert';
import 'dart:io';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_http/dart_orpc_http.dart';
import 'package:test/test.dart';

/// What the luthor bridge throws when [method]'s output fails validation.
RpcException _outputValidationFailure(String method) => RpcException(
  code: RpcErrorCode.internalError,
  message: 'Internal server error.',
  diagnostic: RpcOutputValidationDiagnostic(
    method: method,
    issues: [
      RpcValidationIssue(
        path: ['secret'],
        code: 'tooLong',
        message: 'secret must be at most 3 characters long',
      ),
    ],
  ),
);

const _genericError = {
  'error': {'code': 'INTERNAL_ERROR', 'message': 'Internal server error.'},
};

RpcHttpHandler _handler() {
  return createRpcHttpHandler(
    procedures: RpcProcedureRegistry([
      RpcProcedure<Null, JsonObject>(
        method: 'item.get',
        metadata: const ProcedureMetadata(
          rpcMethod: 'item.get',
          controllerNamespace: 'item',
          methodName: 'get',
          outputTypeCode: 'JsonObject',
        ),
        decodeInput: (_) => null,
        // The core encoder wrapper must keep the diagnostic.
        encodeOutput: (_) => throw _outputValidationFailure('item.get'),
        handler: (_, _) => {'secret': 'hidden-value'},
      ),
    ]),
    restRoutes: RestRouteRegistry([
      RestRoute(
        method: 'GET',
        path: '/items/1',
        handler: (_, _, _) => throw _outputValidationFailure('item.get'),
      ),
      RestStreamRoute(
        path: '/items/events',
        handler: (_, _, _) async* {
          yield {'id': 1};
          throw _outputValidationFailure('item.watch');
        },
      ),
    ]),
    sseHeartbeatInterval: Duration.zero,
  );
}

void main() {
  late RpcHttpHandler handler;
  late List<Object> reported;

  setUp(() {
    handler = _handler();
    reported = [];
  });

  void report(Object error, StackTrace _) => reported.add(error);

  Matcher diagnosticFor(String method) => isA<RpcException>().having(
    (error) => error.diagnostic,
    'diagnostic',
    isA<RpcOutputValidationDiagnostic>()
        .having((diagnostic) => diagnostic.method, 'method', method)
        .having((diagnostic) => diagnostic.issues.single.path, 'issue path', [
          'secret',
        ]),
  );

  group('Given output that fails validation', () {
    test('When called over POST /rpc then the error is generic', () async {
      final response = await handler(
        RpcHttpRequest(
          method: 'POST',
          path: '/rpc',
          body: jsonEncode({'method': 'item.get'}),
          onError: report,
        ),
      );

      expect(response.statusCode, HttpStatus.internalServerError);
      expect(jsonDecode(response.body as String), _genericError);
      expect(response.body, isNot(contains('secret')));
      expect(reported, [diagnosticFor('item.get')]);
    });

    test('When called over REST then the error is generic', () async {
      final response = await handler(
        RpcHttpRequest(method: 'GET', path: '/items/1', onError: report),
      );

      expect(response.statusCode, HttpStatus.internalServerError);
      expect(jsonDecode(response.body as String), _genericError);
      expect(reported, [diagnosticFor('item.get')]);
    });

    test('When a stream event fails over SSE then the error event is '
        'generic', () async {
      final response = await handler(
        RpcHttpRequest(method: 'GET', path: '/items/events', onError: report),
      );
      final content = response.content as RpcStreamingHttpBody;
      final body = await utf8.decodeStream(content.chunks);

      expect(body, contains('data: {"id":1}\n\n'));
      expect(
        body,
        contains(
          'event: dart-orpc-error\ndata: ${jsonEncode(_genericError)}\n\n',
        ),
      );
      expect(body, isNot(contains('secret')));
      expect(reported, [diagnosticFor('item.watch')]);
    });
  });
}
