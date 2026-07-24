import 'dart:async';

import 'package:dart_orpc_client/dart_orpc_client.dart';
import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:test/test.dart';

void main() {
  group('Given an RpcStreamCaller', () {
    test('When events arrive then it decodes them in order', () async {
      final caller = RpcStreamCaller(
        _FakeStreamTransport(
          Stream<Object?>.fromIterable([
            {'value': 1},
            {'value': 2},
          ]),
        ),
      );

      final values = await caller
          .call<int>(
            method: 'counter.watch',
            decode: (event) =>
                expectJsonObject(event, context: 'counter event')['value']
                    as int,
          )
          .toList();

      expect(values, [1, 2]);
    });

    test(
      'When event decoding fails then it throws RpcClientException',
      () async {
        final caller = RpcStreamCaller(
          _FakeStreamTransport(Stream<Object?>.value('invalid')),
        );

        await expectLater(
          caller.call<int>(
            method: 'counter.watch',
            decode: (_) => throw StateError('bad event'),
          ),
          emitsError(
            isA<RpcClientException>().having(
              (error) => error.message,
              'message',
              contains('Failed to decode RPC stream event'),
            ),
          ),
        );
      },
    );

    test('When cancelled then it cancels the source subscription', () async {
      var wasCancelled = false;
      late StreamController<Object?> controller;
      controller = StreamController<Object?>(
        onListen: () => controller.add(1),
        onCancel: () => wasCancelled = true,
      );
      final caller = RpcStreamCaller(_FakeStreamTransport(controller.stream));
      final subscription = caller
          .call<int>(method: 'counter.watch', decode: (event) => event! as int)
          .listen((_) {});

      await subscription.cancel();

      expect(wasCancelled, isTrue);
      await controller.close();
    });
  });

  group('Given RpcClientTransports', () {
    test('When configured as duplex then it exposes both capabilities', () {
      final transport = _FakeDuplexTransport();
      final transports = RpcClientTransports.duplex(transport);

      expect(transports.requireUnary('counter.get'), same(transport));
      expect(transports.requireStreaming('counter.watch'), same(transport));
    });

    test(
      'When a unary-only configuration requires streaming then it fails clearly',
      () {
        final transports = RpcClientTransports.unary(_FakeDuplexTransport());

        expect(
          () => transports.requireStreaming('counter.watch'),
          throwsA(
            isA<RpcClientConfigurationException>().having(
              (error) => error.message,
              'message',
              'RPC method "counter.watch" requires a streaming transport.',
            ),
          ),
        );
      },
    );

    test(
      'When configured with split transports then each capability resolves independently',
      () {
        final unary = _FakeDuplexTransport();
        final streaming = _FakeDuplexTransport();
        final transports = RpcClientTransports.split(
          unary: unary,
          streaming: streaming,
        );

        expect(transports.requireUnary('counter.get'), same(unary));
        expect(transports.requireStreaming('counter.watch'), same(streaming));
      },
    );

    test(
      'When a streaming-only configuration requires unary then it fails clearly',
      () {
        final transports = RpcClientTransports.streaming(
          _FakeDuplexTransport(),
        );

        expect(
          () => transports.requireUnary('counter.get'),
          throwsA(
            isA<RpcClientConfigurationException>().having(
              (error) => error.message,
              'message',
              'RPC method "counter.get" requires a unary transport.',
            ),
          ),
        );
      },
    );
  });
}

final class _FakeStreamTransport implements RpcStreamTransport {
  const _FakeStreamTransport(this.events);

  final Stream<Object?> events;

  @override
  Stream<Object?> subscribe(RpcRequest request) => events;
}

final class _FakeDuplexTransport implements RpcDuplexTransport {
  @override
  Future<Object?> send(RpcRequest request) async => null;

  @override
  Stream<Object?> subscribe(RpcRequest request) => const Stream.empty();
}
