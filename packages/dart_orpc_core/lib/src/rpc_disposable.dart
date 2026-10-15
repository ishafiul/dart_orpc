import 'dart:async';
import 'dart:collection';

/// Resource-owning providers can implement this interface for app shutdown.
abstract interface class RpcDisposable {
  FutureOr<void> dispose();
}

/// Disposes owned providers in the order supplied, attempting every instance.
///
/// Duplicate object identities are disposed once. The first disposal failure
/// is rethrown with its original stack trace after cleanup completes.
Future<void> disposeRpcProviders(Iterable<Object> providers) async {
  final disposed = HashSet<Object>.identity();
  (Object, StackTrace)? firstFailure;

  for (final provider in providers) {
    if (!disposed.add(provider) || provider is! RpcDisposable) {
      continue;
    }

    try {
      await provider.dispose();
    } catch (error, stackTrace) {
      firstFailure ??= (error, stackTrace);
    }
  }

  final failure = firstFailure;
  if (failure != null) {
    Error.throwWithStackTrace(failure.$1, failure.$2);
  }
}
