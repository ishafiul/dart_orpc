/// A closed dependency path, including the repeated node at both ends.
final class DependencyCycle<T extends Object> implements Exception {
  DependencyCycle(Iterable<T> path) : path = List.unmodifiable(path);

  final List<T> path;
}

enum _VisitState { visiting, done }

/// Visits dependencies before their consumers, preserving root and edge order.
///
/// Keys identify nodes across repeated references. Each node's dependencies are
/// read once. Explicit frames avoid recursion limits on deep graphs. Traversal
/// takes O(V + E) time and O(V + E) space, including dependency iterators.
List<T> depthFirstPostorder<T extends Object, K extends Object>(
  Iterable<T> roots, {
  required K Function(T node) keyOf,
  required Iterable<T> Function(T node) dependenciesOf,
}) {
  final states = <K, _VisitState>{};
  final pathIndices = <K, int>{};
  final frames = <_TraversalFrame<T, K>>[];
  final ordered = <T>[];

  void enter(T node, K key) {
    states[key] = _VisitState.visiting;
    pathIndices[key] = frames.length;
    frames.add(_TraversalFrame(node, key, dependenciesOf(node).iterator));
  }

  for (final root in roots) {
    final rootKey = keyOf(root);
    if (states[rootKey] == _VisitState.done) continue;
    enter(root, rootKey);
    while (frames.isNotEmpty) {
      final frame = frames.last;
      if (!frame.dependencies.moveNext()) {
        frames.removeLast();
        pathIndices.remove(frame.key);
        states[frame.key] = _VisitState.done;
        ordered.add(frame.node);
        continue;
      }

      final dependency = frame.dependencies.current;
      final key = keyOf(dependency);
      switch (states[key]) {
        case _VisitState.done:
          continue;
        case _VisitState.visiting:
          final start = pathIndices[key];
          if (start == null) throw StateError('Missing active graph node.');
          throw DependencyCycle<T>([
            for (var index = start; index < frames.length; index++)
              frames[index].node,
            dependency,
          ]);
        case null:
          enter(dependency, key);
      }
    }
  }
  return ordered;
}

/// Finds the first cycle in deterministic root/edge order, or returns null.
List<T>? findDependencyCycle<T extends Object, K extends Object>(
  Iterable<T> roots, {
  required K Function(T node) keyOf,
  required Iterable<T> Function(T node) dependenciesOf,
}) {
  try {
    depthFirstPostorder(roots, keyOf: keyOf, dependenciesOf: dependenciesOf);
    return null;
  } on DependencyCycle<T> catch (cycle) {
    return cycle.path;
  }
}

final class _TraversalFrame<T extends Object, K extends Object> {
  const _TraversalFrame(this.node, this.key, this.dependencies);

  final T node;
  final K key;
  final Iterator<T> dependencies;
}
