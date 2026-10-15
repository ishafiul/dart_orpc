import 'dart:async';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:test/test.dart';

void main() {
  test(
    'listeners are asynchronous, ordered, removable, and notified once',
    () async {
      final source = RpcCancellationSource();
      final trace = <int>[];
      final first = source.signal.onCancel(() => trace.add(1));
      final removed = source.signal.onCancel(() => trace.add(2));
      final done = Completer<void>();
      source.signal.onCancel(() {
        trace.add(3);
        done.complete();
      });
      removed.dispose();
      removed.dispose();
      source.cancel();
      source.cancel();
      expect(source.isCancelled, isTrue);
      expect(trace, isEmpty);
      await done.future;
      expect(trace, [1, 3]);
      first.dispose();
      await source.signal.cancelled;
      expect(source.signal.cancelled, same(source.signal.cancelled));
    },
  );

  test('registration disposal suppresses already queued callbacks', () async {
    final source = RpcCancellationSource();
    var called = false;
    final registration = source.signal.onCancel(() => called = true);
    source.cancel();
    registration.dispose();
    final lateRegistration = source.signal.onCancel(() => called = true);
    lateRegistration.dispose();
    await source.signal.cancelled;
    expect(called, isFalse);
    final done = Completer<void>();
    source.signal.onCancel(done.complete);
    expect(done.isCompleted, isFalse);
    await done.future;
  });

  test(
    'listener may unregister another listener during notification',
    () async {
      final source = RpcCancellationSource();
      late RpcCancellationRegistration second;
      var secondCalled = false;
      final done = Completer<void>();
      source.signal.onCancel(() {
        second.dispose();
        source.signal.onCancel(done.complete);
      });
      second = source.signal.onCancel(() => secondCalled = true);
      source.cancel();
      await done.future;
      expect(secondCalled, isFalse);
    },
  );

  test(
    'listener exceptions reach registration zone without interrupting others',
    () async {
      final source = RpcCancellationSource();
      final error = Completer<Object>();
      final done = Completer<void>();
      runZonedGuarded(
        () {
          source.signal.onCancel(() => throw StateError('listener failed'));
        },
        (Object e, StackTrace _) {
          error.complete(e);
        },
      );
      source.signal.onCancel(done.complete);
      source.cancel();
      expect(await error.future, isA<StateError>());
      await done.future;
    },
  );

  test('legacy signals and none remain compatible with disposal', () async {
    final legacy = _LegacySignal();
    var called = 0;
    final removed = legacy.onCancel(() => called++);
    removed.dispose();
    final done = Completer<void>();
    legacy.onCancel(done.complete);
    legacy.source.cancel();
    await done.future;
    expect(called, 0);
    final none = RpcCancellationSignal.none.onCancel(() => called++);
    none.dispose();
    none.dispose();
    expect(RpcCancellationSignal.none.isCancelled, isFalse);
    expect(called, 0);
  });

  test(
    'finished streams release cancellation listeners on shared signal',
    () async {
      final signal = _CountingSignal();
      for (var i = 0; i < 20; i++) {
        final procedure = _procedure((_, _) => Stream.value('event'));
        expect(
          await procedure
              .invokeStream(RpcContext(headers: {}, cancellation: signal), null)
              .toList(),
          ['event'],
        );
        expect(signal.listeners, 0);
      }
      signal.source.cancel();
      await signal.cancelled;
      expect(signal.notifications, 0);
    },
  );

  test(
    'failed encoding, source errors, and setup failures detach listeners',
    () async {
      for (final procedure in [
        _procedure((_, _) => Stream<String>.error(StateError('source failed'))),
        _procedure(
          (_, _) => Stream.value('bad'),
          encode: (_) => throw StateError('encoding failed'),
        ),
        _procedure((_, _) => throw StateError('setup failed')),
      ]) {
        final signal = _CountingSignal();
        await expectLater(
          procedure.invokeStream(
            RpcContext(headers: {}, cancellation: signal),
            null,
          ),
          emitsError(anything),
        );
        expect(signal.listeners, 0);
      }
    },
  );

  test(
    'consumer cancellation releases listener and source while idle',
    () async {
      final signal = _CountingSignal();
      final started = Completer<void>();
      final cancelled = Completer<void>();
      final controller = StreamController<String>(
        onListen: started.complete,
        onCancel: cancelled.complete,
      );
      addTearDown(controller.close);
      final subscription = _procedure((_, _) => controller.stream)
          .invokeStream(RpcContext(headers: {}, cancellation: signal), null)
          .listen((_) {});
      await started.future;
      expect(signal.listeners, 1);
      await subscription.cancel();
      await cancelled.future;
      expect(signal.listeners, 0);
    },
  );
}

RpcStreamProcedure<Null, String> _procedure(
  RpcStreamHandler<Null, String> handler, {
  RpcOutputEncoder<String>? encode,
}) => RpcStreamProcedure(
  method: 'events.watch',
  metadata: const ProcedureMetadata(
    rpcMethod: 'events.watch',
    controllerNamespace: 'events',
    methodName: 'watch',
    outputTypeCode: 'String',
    kind: RpcProcedureKind.serverStream,
  ),
  decodeInput: (_) => null,
  encodeOutput: encode ?? (value) => value,
  handler: handler,
);

final class _LegacySignal implements RpcCancellationSignal {
  final source = RpcCancellationSource();
  @override
  bool get isCancelled => source.isCancelled;
  @override
  Future<void> get cancelled => source.signal.cancelled;
  @override
  void throwIfCancelled() => source.signal.throwIfCancelled();
}

final class _CountingSignal implements RpcCancellationListenerSignal {
  final source = RpcCancellationSource();
  int listeners = 0;
  int notifications = 0;
  @override
  bool get isCancelled => source.isCancelled;
  @override
  Future<void> get cancelled => source.signal.cancelled;
  @override
  void throwIfCancelled() => source.signal.throwIfCancelled();
  @override
  RpcCancellationRegistration addCancellationListener(
    void Function() listener,
  ) {
    listeners++;
    late _CountedRegistration counted;
    final native = source.signal.onCancel(() {
      counted.dispose();
      notifications++;
      listener();
    });
    counted = _CountedRegistration(native, () => listeners--);
    return counted;
  }
}

final class _CountedRegistration implements RpcCancellationRegistration {
  _CountedRegistration(this.native, this.onDispose);
  final RpcCancellationRegistration native;
  void Function()? onDispose;
  @override
  void dispose() {
    native.dispose();
    final callback = onDispose;
    onDispose = null;
    callback?.call();
  }
}
