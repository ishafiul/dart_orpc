import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_http/dart_orpc_http.dart';
import 'package:test/test.dart';

void main() {
  _issueTests();

  group('Given REST scalar bindings', () {
    test('When supported values are decoded then their Dart types match', () {
      expect(_decodeScalar<String>('text'), 'text');
      expect(_decodeScalar<int>('42'), 42);
      expect(_decodeScalar<double>('4.5'), 4.5);
      expect(_decodeScalar<bool>('true'), isTrue);
      expect(_decodeScalar<bool>('1'), isTrue);
      expect(_decodeScalar<bool>('false'), isFalse);
      expect(_decodeScalar<bool>('0'), isFalse);
      expect(_decodeScalar<String?>(null), isNull);
    });

    test('When values are invalid then bad request identifies the binding', () {
      for (final decode in <Object? Function()>[
        () => _decodeScalar<int>('not-int'),
        () => _decodeScalar<double>('not-double'),
        () => _decodeScalar<bool>('not-bool'),
        () => _decodeScalar<String>(null),
      ]) {
        expect(
          decode,
          throwsA(
            isA<RpcException>().having(
              (error) => error.code,
              'code',
              RpcErrorCode.badRequest,
            ),
          ),
        );
      }
    });

    test(
      'When a scalar type is unsupported then it is an internal contract error',
      () {
        expect(
          () => _decodeScalar<DateTime>('2026-01-01'),
          throwsA(
            isA<RpcException>().having(
              (error) => error.code,
              'code',
              RpcErrorCode.internalError,
            ),
          ),
        );
      },
    );
  });

  group('Given REST JSON body bindings', () {
    test(
      'When required and optional bodies decode then values are preserved',
      () {
        expect(
          decodeRestBody<Map<String, Object?>>(
            rawBody: '{"id":1}',
            route: 'POST /items',
            parameterName: 'body',
            decode: (json) => expectJsonObject(json, context: 'body'),
          ),
          {'id': 1},
        );
        expect(
          decodeRestBody<Object?>(
            rawBody: 'null',
            route: 'POST /items',
            parameterName: 'body',
            decode: (json) => json,
          ),
          isNull,
        );
        expect(
          decodeRestBody<Object?>(
            rawBody: '',
            route: 'POST /items',
            parameterName: 'body',
            decode: (json) => json,
          ),
          isNull,
        );
      },
    );

    test('When a required body is absent then it fails before decoding', () {
      expect(
        () => decodeRestBody<Map<String, Object?>>(
          rawBody: ' ',
          route: 'POST /items',
          parameterName: 'body',
          decode: (json) => expectJsonObject(json, context: 'body'),
        ),
        throwsA(isA<RpcException>()),
      );
    });

    test('When a decoder fails then RPC errors survive and other errors become bad request', () {
      expect(
        () => decodeRestBody<Object>(
          rawBody: '{}',
          route: 'POST /items',
          parameterName: 'body',
          decode: (_) => throw RpcException.conflict('duplicate'),
        ),
        throwsA(
          isA<RpcException>().having(
            (error) => error.code,
            'code',
            RpcErrorCode.conflict,
          ),
        ),
      );
      expect(
        () => decodeRestBody<Object>(
          rawBody: '{}',
          route: 'POST /items',
          parameterName: 'body',
          decode: (_) => throw StateError('invalid'),
        ),
        throwsA(
          isA<RpcException>().having(
            (error) => error.code,
            'code',
            RpcErrorCode.badRequest,
          ),
        ),
      );
    });
  });

  group('Given REST JSON field bindings', () {
    test(
      'When scalar JSON types match then values are converted predictably',
      () {
        expect(_decodeJson<String>('value'), 'value');
        expect(_decodeJson<int>(7), 7);
        expect(_decodeJson<double>(7), 7.0);
        expect(_decodeJson<bool>(true), isTrue);
        expect(_decodeJson<String?>(null), isNull);
      },
    );

    test('When JSON types are absent, invalid, or unsupported then errors are typed', () {
      expect(
        () => _decodeJson<String>(null),
        throwsA(
          isA<RpcException>().having(
            (error) => error.code,
            'code',
            RpcErrorCode.badRequest,
          ),
        ),
      );
      expect(
        () => _decodeJson<int>('7'),
        throwsA(
          isA<RpcException>().having(
            (error) => error.code,
            'code',
            RpcErrorCode.badRequest,
          ),
        ),
      );
      expect(
        () => _decodeJson<DateTime>('2026-01-01'),
        throwsA(
          isA<RpcException>().having(
            (error) => error.code,
            'code',
            RpcErrorCode.internalError,
          ),
        ),
      );
    });
  });
}

void _issueTests() {
  group('Given REST decoding failures', () {
    test('When a standalone parameter fails then its name is the path', () {
      expect(
        _issueOf(() => _decodeScalar<int>('nope')),
        _issue(
          ['value'],
          'invalidType',
          'query parameter "value" for "GET /items" must be a valid int.',
        ),
      );
      expect(_issueOf(() => _decodeScalar<double>('x')).code, 'invalidType');
      expect(_issueOf(() => _decodeScalar<bool>('x')).code, 'invalidType');
      expect(
        _issueOf(() => _decodeScalar<String>(null)),
        _issue(
          ['value'],
          'required',
          'Missing required query parameter "value" for "GET /items".',
        ),
      );
    });

    test('When an aliased DTO field fails then its JSON key is the path', () {
      expect(
        _issueOf(
          () => decodeRestScalarParameter<int>(
            rawValue: 'nope',
            source: 'path parameter',
            name: 'todoId',
            inputKey: 'id',
            route: 'GET /todos/:todoId',
          ),
        ),
        _issue(
          ['id'],
          'invalidType',
          'path parameter "todoId" for "GET /todos/:todoId" must be a valid '
              'int.',
        ),
      );
      expect(
        _issueOf(
          () => decodeRestScalarParameter<String>(
            rawValue: null,
            source: 'header',
            name: 'x-tenant-id',
            inputKey: 'tenantId',
            route: 'GET /todos',
          ),
        ).path,
        ['tenantId'],
      );
    });

    test('When a JSON value has the wrong type then it is invalidType', () {
      expect(
        _issueOf(() => _decodeJson<int>('7')),
        _issue(
          ['value'],
          'invalidType',
          'body field "value" for "POST /items" has an invalid JSON type.',
        ),
      );
      expect(_issueOf(() => _decodeJson<String>(null)).code, 'required');
    });

    test('When a whole body value is wrong then the path is the root', () {
      expect(
        _issueOf(
          () => decodeRestJsonValue<int>(
            rawValue: 'seven',
            source: 'body parameter',
            name: 'count',
            issuePath: const [],
            route: 'POST /counts',
          ),
        ).path,
        isEmpty,
      );
    });

    test('When a required body is missing then it is required at the root', () {
      expect(
        _issueOf(() => _decodeBody<Object>('  ', (json) => json!)),
        _issue(
          <Object>[],
          'required',
          'Missing required JSON body for "POST /items".',
        ),
      );
    });

    test('When the body is malformed JSON then it is invalidJson', () {
      expect(
        _issueOf(() => _decodeBody<Object?>('{', (json) => json)),
        _issue(
          <Object>[],
          'invalidJson',
          'REST request body for "POST /items" must be valid JSON.',
        ),
      );
    });

    test('When the body decoder throws then it is invalidBody', () {
      expect(
        _issueOf(
          () => _decodeBody<Object?>(
            '{}',
            (json) => throw const FormatException('bad'),
          ),
        ),
        _issue(
          <Object>[],
          'invalidBody',
          'Failed to decode REST body parameter "body" for "POST /items".',
        ),
      );
    });

    test('When the body decoder reports issues then they pass through', () {
      final validation = RpcException.badRequest(
        'Invalid RPC input for "items.create": name: name is required',
        details: rpcValidationIssueDetails([
          RpcValidationIssue(
            path: ['name'],
            code: 'required',
            message: 'name is required',
          ),
        ]),
      );

      expect(
        () => _decodeBody<Object?>('{}', (json) => throw validation),
        throwsA(same(validation)),
      );
    });

    test(
      'When the body decoder throws a plain RpcException then it is kept',
      () {
        final notObject = RpcException.badRequest('Expected a JSON object.');

        expect(
          () => _decodeBody<Object?>('[]', (json) => throw notObject),
          throwsA(same(notObject)),
        );
      },
    );
  });
}

T _decodeBody<T>(String rawBody, T Function(Object? json) decode) =>
    decodeRestBody<T>(
      rawBody: rawBody,
      route: 'POST /items',
      parameterName: 'body',
      decode: decode,
    );

RpcValidationIssue _issue(List<Object> path, String code, String message) =>
    RpcValidationIssue(path: path, code: code, message: message);

/// The single issue of the `BAD_REQUEST` [decode] throws, with its message
/// checked against the error's top-level message.
RpcValidationIssue _issueOf(Object? Function() decode) {
  try {
    decode();
  } on RpcException catch (error) {
    expect(error.code, RpcErrorCode.badRequest);
    final issues = parseRpcValidationIssues(error.details);
    expect(issues, hasLength(1));
    expect(issues.single.message, error.message);
    return issues.single;
  }
  fail('Expected a BAD_REQUEST.');
}

T _decodeScalar<T>(String? value) {
  return decodeRestScalarParameter<T>(
    rawValue: value,
    source: 'query parameter',
    name: 'value',
    route: 'GET /items',
  );
}

T _decodeJson<T>(Object? value) {
  return decodeRestJsonValue<T>(
    rawValue: value,
    source: 'body field',
    name: 'value',
    route: 'POST /items',
  );
}
