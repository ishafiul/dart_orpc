import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:test/test.dart';

void main() {
  test(
    'disposes providers in supplied order and only once per identity',
    () async {
      final events = <String>[];
      final provider = _RecordingDisposable('first', events);

      await disposeRpcProviders([
        provider,
        _RecordingDisposable('second', events),
        provider,
        Object(),
      ]);

      expect(events, ['first', 'second']);
    },
  );

  test('continues cleanup and rethrows the first disposal error', () async {
    final events = <String>[];
    final failure = StateError('dispose failed');

    await expectLater(
      disposeRpcProviders([
        _ThrowingDisposable(failure),
        _RecordingDisposable('last', events),
      ]),
      throwsA(same(failure)),
    );

    expect(events, ['last']);
  });
}

final class _RecordingDisposable implements RpcDisposable {
  const _RecordingDisposable(this.name, this.events);

  final String name;
  final List<String> events;

  @override
  void dispose() => events.add(name);
}

final class _ThrowingDisposable implements RpcDisposable {
  const _ThrowingDisposable(this.error);

  final Object error;

  @override
  void dispose() => throw error;
}
