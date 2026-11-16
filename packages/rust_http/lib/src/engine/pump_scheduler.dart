import 'dart:async';

/// Decides when the server pumps the engine again.
///
/// Most pumps run as microtasks, so answers go out fast. Every 16th in a
/// row goes through the event loop instead, so timers and other ports
/// (e.g. a database driver) get a turn under load.
final class PumpScheduler {
  /// Creates a scheduler that calls `pump`.
  PumpScheduler(this._pump);

  static const int _fairnessMask = 15;

  final void Function() _pump;
  bool _queued = false;
  int _chain = 0;
  bool _stopped = false;

  /// Whether a pump is queued.
  bool get isQueued => _queued;

  /// Queues one pump, unless one is queued already.
  void schedule() {
    if (_queued || _stopped) return;
    _queued = true;
    if (++_chain & _fairnessMask == 0) {
      Timer.run(_run);
    } else {
      scheduleMicrotask(_run);
    }
  }

  /// The engine had nothing: the next pump starts a new chain.
  void idle() => _chain = 0;

  /// Stops scheduling for good.
  void stop() => _stopped = true;

  void _run() {
    _queued = false;
    if (!_stopped) _pump();
  }
}
