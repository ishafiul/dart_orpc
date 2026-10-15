import 'dart:async';

import 'rpc_exception.dart';

abstract interface class RpcCancellationSignal {
  static const RpcCancellationSignal none = _NeverCancelledSignal();

  bool get isCancelled;
  Future<void> get cancelled;
  void throwIfCancelled();
}

abstract interface class RpcCancellationRegistration {
  /// Idempotently removes the callback, including a queued notification.
  void dispose();
}

/// Optional capability; existing implementations of RpcCancellationSignal remain valid.
abstract interface class RpcCancellationListenerSignal
    implements RpcCancellationSignal {
  RpcCancellationRegistration addCancellationListener(void Function() listener);
}

extension RpcCancellationListeners on RpcCancellationSignal {
  RpcCancellationRegistration onCancel(void Function() listener) {
    if (identical(this, RpcCancellationSignal.none)) return _emptyRegistration;
    final signal = this;
    if (signal is RpcCancellationListenerSignal) {
      return signal.addCancellationListener(listener);
    }
    // A legacy Future cannot detach its continuation. Disposing this registration
    // still releases the application callback and its captured resources.
    final registration = _CancellationRegistration(listener);
    unawaited(cancelled.then((_) => registration.notify()));
    return registration;
  }
}

final _emptyRegistration = _CancellationRegistration(null);

final class RpcCancellationSource {
  RpcCancellationSource() : _signal = _MutableRpcCancellationSignal();
  final _MutableRpcCancellationSignal _signal;
  RpcCancellationSignal get signal => _signal;
  bool get isCancelled => _signal.isCancelled;
  void cancel() => _signal.cancel();
}

final class _MutableRpcCancellationSignal
    implements RpcCancellationListenerSignal {
  Completer<void>? _cancelled;
  bool _isCancelled = false;
  Map<Object, _CancellationRegistration>? _listeners;

  @override
  bool get isCancelled => _isCancelled;

  @override
  Future<void> get cancelled {
    final existing = _cancelled;
    if (existing != null) return existing.future;
    final completer = _cancelled = Completer<void>();
    if (_isCancelled) completer.complete();
    return completer.future;
  }

  @override
  RpcCancellationRegistration addCancellationListener(
    void Function() listener,
  ) {
    if (_isCancelled) {
      final registration = _CancellationRegistration(listener);
      scheduleMicrotask(registration.notify);
      return registration;
    }
    final token = Object();
    final registration = _CancellationRegistration(
      listener,
      () => _listeners?.remove(token),
    );
    (_listeners ??= {})[token] = registration;
    return registration;
  }

  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    _cancelled?.complete();
    final listeners = _listeners;
    _listeners = null;
    if (listeners == null) return;
    for (final registration in listeners.values) {
      registration.detach();
      scheduleMicrotask(registration.notify);
    }
  }

  @override
  void throwIfCancelled() {
    if (_isCancelled) throw RpcException.cancelled();
  }
}

final class _CancellationRegistration implements RpcCancellationRegistration {
  _CancellationRegistration(void Function()? listener, [this._remove])
    : _listener = listener == null
          ? null
          : Zone.current.bindCallbackGuarded(listener);
  void Function()? _listener;
  void Function()? _remove;

  void detach() => _remove = null;

  void notify() {
    final listener = _listener;
    dispose();
    listener?.call();
  }

  @override
  void dispose() {
    final remove = _remove;
    _listener = null;
    _remove = null;
    remove?.call();
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
