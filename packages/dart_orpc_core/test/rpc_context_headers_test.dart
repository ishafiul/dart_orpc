import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:test/test.dart';

void main() {
  group('Given RpcContext headers', () {
    test('When headers are adopted Then the context shares them', () {
      final adopted = adoptRpcHeaders({'x-id': '1'});

      final context = RpcContext(headers: adopted);

      expect(identical(context.headers, adopted), isTrue);
      expect(
        identical(context.copyWith(headers: adopted).headers, adopted),
        isTrue,
      );
      expect(() => adopted['x-id'] = '2', throwsUnsupportedError);
    });

    test('When headers are a plain map Then the context snapshots them', () {
      final plain = {'x-id': '1'};

      final context = RpcContext(headers: plain);
      plain['x-id'] = '2';

      expect(context.headers, {'x-id': '1'});
      expect(() => context.headers['x-id'] = '3', throwsUnsupportedError);
    });

    test('When adopted twice Then the same wrapper is returned', () {
      final adopted = adoptRpcHeaders({'x-id': '1'});

      expect(identical(adoptRpcHeaders(adopted), adopted), isTrue);
    });

    test('When headers are adopted as lowercase Then lookups hit the map', () {
      final adopted = adoptRpcHeaders({'x-id': '1'}, lowercaseNames: true);
      final context = RpcContext(headers: adopted);

      expect(lookupRpcHeader(adopted, 'X-Id'), '1');
      expect(lookupRpcHeader(adopted, 'x-missing'), isNull);
      expect(context.headerValue('X-ID'), '1');
      expect(context.headerValue('x-missing'), isNull);
    });

    test('When plain headers have mixed case Then lookups still match', () {
      final headers = {'X-Id': '1'};
      final context = RpcContext(headers: headers);

      expect(lookupRpcHeader(headers, 'x-id'), '1');
      expect(lookupRpcHeader(adoptRpcHeaders(headers), 'x-id'), '1');
      expect(context.headerValue('x-id'), '1');
    });

    test(
      'When adopted headers are re-adopted as lowercase Then it upgrades',
      () {
        final plain = adoptRpcHeaders({'x-id': '1'});
        final lower = adoptRpcHeaders(plain, lowercaseNames: true);

        expect(identical(lower, plain), isFalse);
        expect(identical(adoptRpcHeaders(lower), lower), isTrue);
        expect(lower['x-id'], '1');
      },
    );
  });
}
