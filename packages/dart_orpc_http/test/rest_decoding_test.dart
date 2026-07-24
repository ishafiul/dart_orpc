import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_http/dart_orpc_http.dart';
import 'package:test/test.dart';

void main() {
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

    test(
      'When a decoder fails then RPC errors survive and other errors become bad request',
      () {
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
      },
    );
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

    test(
      'When JSON types are absent, invalid, or unsupported then errors are typed',
      () {
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
      },
    );
  });
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
