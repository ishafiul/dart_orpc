import 'dart:async';

import 'rpc_exception.dart';

abstract interface class RpcCancellationSignal {
  static const RpcCancellationSignal none = _NeverCancelledSignal();

  bool get isCancelled;

  Future<void> get cancelled;

  void throwIfCancelled();
}

final class RpcCancellationSource {
  RpcCancellationSource() : _signal = _MutableRpcCancellationSignal();

  final _MutableRpcCancellationSignal _signal;

  RpcCancellationSignal get signal => _signal;

  bool get isCancelled => _signal.isCancelled;

  void cancel() => _signal.cancel();
}

final class _MutableRpcCancellationSignal implements RpcCancellationSignal {
  final Completer<void> _cancelled = Completer<void>();

  @override
  bool get isCancelled => _cancelled.isCompleted;

  @override
  Future<void> get cancelled => _cancelled.future;

  void cancel() {
    if (!_cancelled.isCompleted) {
      _cancelled.complete();
    }
  }

  @override
  void throwIfCancelled() {
    if (isCancelled) {
      throw RpcException.cancelled();
    }
  }
}

final class _NeverCancelledSignal implements RpcCancellationSignal {
  const _NeverCancelledSignal();

  static final Future<void> _never = Completer<void>().future;

  @override
  bool get isCancelled => false;

  @override
  Future<void> get cancelled => _never;

  @override
  void throwIfCancelled() {}
}
