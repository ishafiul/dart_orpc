import 'dart:async';
import 'dart:convert';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_http/dart_orpc_http.dart';
import 'package:test/test.dart';

void main() {
  test(
    'SSE completion and source errors detach shared cancellation listener',
    () async {
      for (final source in [
        Stream<Object?>.value({'ready': true}),
        Stream<Object?>.error(StateError('failed')),
      ]) {
        final signal = _Signal();
        final body = await utf8.decodeStream(
          encodeSseResponseBody(
            source,
            cancellation: signal,
            heartbeatInterval: Duration.zero,
          ),
        );
        expect(body, contains('event: dart-orpc-'));
        expect(signal.listeners, 0);
        signal.source.cancel();
        await signal.cancelled;
        expect(signal.notifications, 0);
      }
    },
  );

  test(
    'SSE consumer cancellation removes listener and cancels source',
    () async {
      final signal = _Signal();
      final entered = Completer<void>();
      final cancelled = Completer<void>();
      final source = StreamController<Object?>(
        onListen: entered.complete,
        onCancel: cancelled.complete,
      );
      addTearDown(source.close);
      final subscription = encodeSseResponseBody(
        source.stream,
        cancellation: signal,
        heartbeatInterval: Duration.zero,
      ).listen((_) {});
      await entered.future;
      expect(signal.listeners, 1);
      await subscription.cancel();
      await cancelled.future;
      expect(signal.listeners, 0);
    },
  );

  test(
    'SSE signal cancellation detaches listener and closes idle source',
    () async {
      final signal = _Signal();
      final entered = Completer<void>();
      final source = StreamController<Object?>(onListen: entered.complete);
      addTearDown(source.close);
      final result = encodeSseResponseBody(
        source.stream,
        cancellation: signal,
        heartbeatInterval: Duration.zero,
      ).toList();
      await entered.future;
      signal.source.cancel();
      expect(await result, isEmpty);
      expect(signal.listeners, 0);
      expect(source.hasListener, isFalse);
    },
  );
}

final class _Signal implements RpcCancellationListenerSignal {
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
    late _Registration registration;
    final native = source.signal.onCancel(() {
      registration.dispose();
      notifications++;
      listener();
    });
    registration = _Registration(native, () => listeners--);
    return registration;
  }
}

final class _Registration implements RpcCancellationRegistration {
  _Registration(this.native, this.onDispose);
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
