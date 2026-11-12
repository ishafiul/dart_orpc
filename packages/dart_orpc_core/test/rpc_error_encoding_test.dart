import 'dart:convert';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:test/test.dart';

final class _Point {
  const _Point(this.x, this.y);

  final int x;
  final int y;

  Map<String, Object?> toJson() => {'x': x, 'y': y};
}

final class _Opaque {}

void main() {
  group('Given an RpcException without details', () {
    late RpcErrorEncoding encoding;

    setUp(() {
      encoding = encodeRpcError(RpcException.notFound('User not found.'));
    });

    test('When it is encoded then the envelope has code and message only', () {
      expect(encoding.json, {
        'error': {'code': 'NOT_FOUND', 'message': 'User not found.'},
      });
    });

    test('When it is encoded then no details error is reported', () {
      expect(encoding.detailsError, isNull);
      expect(encoding.detailsStackTrace, isNull);
    });
  });

  group('Given details containing toJson objects', () {
    late RpcErrorEncoding encoding;

    setUp(() {
      encoding = encodeRpcError(
        RpcException.conflict(
          'Version conflict.',
          details: {
            'current': const _Point(1, 2),
            'history': [const _Point(0, 0)],
          },
        ),
      );
    });

    test('When it is encoded then the objects are converted to JSON', () {
      expect(encoding.json, {
        'error': {
          'code': 'CONFLICT',
          'message': 'Version conflict.',
          'details': {
            'current': {'x': 1, 'y': 2},
            'history': [
              {'x': 0, 'y': 0},
            ],
          },
        },
      });
    });

    test('When it is encoded then the envelope is jsonEncode-safe', () {
      expect(() => jsonEncode(encoding.json), returnsNormally);
    });
  });

  group('Given empty details', () {
    late RpcErrorEncoding encoding;

    setUp(() {
      encoding = encodeRpcError(
        const RpcException(
          code: RpcErrorCode.badRequest,
          message: 'Bad.',
          details: {},
        ),
      );
    });

    test('When it is encoded then details are omitted', () {
      expect(encoding.json, {
        'error': {'code': 'BAD_REQUEST', 'message': 'Bad.'},
      });
      expect(encoding.detailsError, isNull);
    });
  });

  group('Given details with an unsupported value', () {
    late RpcException exception;
    late RpcErrorEncoding encoding;

    setUp(() {
      exception = RpcException.forbidden(
        'Denied.',
        details: {'opaque': _Opaque()},
      );
      encoding = encodeRpcError(exception);
    });

    test('When it is encoded then the real code and message are kept', () {
      expect(encoding.json, {
        'error': {'code': 'FORBIDDEN', 'message': 'Denied.'},
      });
    });

    test(
      'When it is encoded then a details encoding exception is reported',
      () {
        expect(
          encoding.detailsError,
          isA<RpcErrorDetailsEncodingException>()
              .having((error) => error.exception, 'exception', same(exception))
              .having(
                (error) => error.cause,
                'cause',
                isA<JsonUnsupportedObjectError>(),
              ),
        );
        expect(encoding.detailsStackTrace, isNotNull);
      },
    );
  });

  group('Given cyclic details', () {
    late RpcErrorEncoding encoding;

    setUp(() {
      final cycle = <String, Object?>{};
      cycle['self'] = cycle;
      encoding = encodeRpcError(
        RpcException.badRequest('Cyclic.', details: {'cycle': cycle}),
      );
    });

    test('When it is encoded then details are dropped with the cause', () {
      expect(encoding.json, {
        'error': {'code': 'BAD_REQUEST', 'message': 'Cyclic.'},
      });
      expect(
        encoding.detailsError,
        isA<RpcErrorDetailsEncodingException>().having(
          (error) => error.cause,
          'cause',
          isA<JsonCyclicError>(),
        ),
      );
    });
  });

  group('Given an encoding with details', () {
    late RpcErrorEncoding withoutDetails;

    setUp(() {
      withoutDetails = encodeRpcError(
        RpcException.payloadTooLarge('Too big.', details: {'limit': 10}),
      ).withoutDetails();
    });

    test('When withoutDetails is called then code and message are kept', () {
      expect(withoutDetails.json, {
        'error': {'code': 'PAYLOAD_TOO_LARGE', 'message': 'Too big.'},
      });
    });

    test('When withoutDetails is called then no details error is attached', () {
      expect(withoutDetails.detailsError, isNull);
    });
  });
}
