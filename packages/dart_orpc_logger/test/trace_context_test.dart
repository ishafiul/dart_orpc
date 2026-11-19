import 'dart:math';

import 'package:dart_orpc_logger/dart_orpc_logger.dart';
import 'package:test/test.dart';

const _traceId = '4bf92f3577b34da6a3ce929d0e0e4736';
const _spanId = '00f067aa0ba902b7';

void main() {
  group('Given a traceparent header', () {
    test('When it is valid and sampled then its ids and flag are read', () {
      final context = RpcTraceContext.fromTraceparent(
        '00-$_traceId-$_spanId-01',
      );

      expect(context?.traceId, _traceId);
      expect(context?.spanId, _spanId);
      expect(context?.sampled, isTrue);
    });

    test('When the sampled flag is off then the context is not sampled', () {
      final context = RpcTraceContext.fromTraceparent(
        '00-$_traceId-$_spanId-00',
      );

      expect(context?.sampled, isFalse);
    });

    test('When it is malformed then no context is read', () {
      for (final header in [
        null,
        '',
        'ff-$_traceId-$_spanId-01',
        '00-${'0' * 32}-$_spanId-01',
        '00-$_traceId-${'0' * 16}-01',
        '00-$_traceId-$_spanId-01-extra',
        '00-${_traceId.substring(1)}-$_spanId-01',
      ]) {
        expect(RpcTraceContext.fromTraceparent(header), isNull, reason: header);
      }
    });

    test('When it is written back then it round-trips', () {
      const context = RpcTraceContext(traceId: _traceId, spanId: _spanId);

      expect(context.toTraceparent(), '00-$_traceId-$_spanId-01');
    });
  });

  group('Given trace id generation', () {
    test('When ids are created then they are non-zero lower-case hex', () {
      final ids = RpcTraceIds(Random(7));

      for (var index = 0; index < 50; index++) {
        expect(ids.traceId(), matches(RegExp(r'^[0-9a-f]{32}$')));
        expect(ids.spanId(), matches(RegExp(r'^[0-9a-f]{16}$')));
      }
    });

    test('When sampling at ratio 0 or 1 then the decision is fixed', () {
      final ids = RpcTraceIds(Random(7));

      expect(List.generate(20, (_) => ids.sample(1)), everyElement(isTrue));
      expect(List.generate(20, (_) => ids.sample(0)), everyElement(isFalse));
    });
  });
}
