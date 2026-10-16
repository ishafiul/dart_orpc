import 'dart:collection';

final class TopologicalSortResult<T extends Object> {
  TopologicalSortResult({
    required Iterable<T> ordered,
    required Iterable<T> unresolved,
  }) : ordered = List.unmodifiable(ordered),
       unresolved = List.unmodifiable(unresolved);

  final List<T> ordered;
  final List<T> unresolved;
}

/// Kahn's algorithm with declaration-pass ordering among ready nodes.
///
/// An unlocked node later in declaration order runs in the current pass; an
/// earlier node runs in the next pass. This preserves the ordering of repeated
/// declaration scans without revisiting blocked nodes. The ordered ready queue
/// costs O(E + V log V) time and O(V + E) space. Unknown dependency keys block
/// consumers unless listed in [available]; duplicate edges count once.
TopologicalSortResult<T> topologicalSort<T extends Object, K extends Object>(
  Iterable<T> nodes, {
  required K Function(T node) keyOf,
  required Iterable<K> Function(T node) dependenciesOf,
  Iterable<K> available = const [],
}) {
  final nodeByKey = <K, T>{};
  final indexByKey = <K, int>{};
  for (final node in nodes) {
    final key = keyOf(node);
    if (nodeByKey.containsKey(key)) {
      throw ArgumentError.value(key, 'nodes', 'Duplicate graph node key.');
    }
    indexByKey[key] = nodeByKey.length;
    nodeByKey[key] = node;
  }

  final availableKeys = available.toSet();
  final dependencyCounts = <K, int>{};
  final dependents = <K, List<K>>{};
  final ready = SplayTreeMap<({int pass, int index}), K>((left, right) {
    final passOrder = left.pass.compareTo(right.pass);
    return passOrder != 0 ? passOrder : left.index.compareTo(right.index);
  });
  for (final entry in nodeByKey.entries) {
    final dependencies = dependenciesOf(
      entry.value,
    ).where((dependency) => !availableKeys.contains(dependency)).toSet();
    dependencyCounts[entry.key] = dependencies.length;
    for (final dependency in dependencies) {
      (dependents[dependency] ??= []).add(entry.key);
    }
    if (dependencies.isEmpty) {
      ready[(pass: 0, index: indexByKey[entry.key]!)] = entry.key;
    }
  }

  final ordered = <T>[];
  final emitted = <K>{};
  while (ready.isNotEmpty) {
    final priority = ready.firstKey()!;
    final key = ready.remove(priority)!;
    ordered.add(nodeByKey[key]!);
    emitted.add(key);
    for (final dependent in dependents[key] ?? <K>[]) {
      final remaining = dependencyCounts[dependent]! - 1;
      dependencyCounts[dependent] = remaining;
      if (remaining != 0) continue;
      final index = indexByKey[dependent]!;
      final pass = priority.pass + (index < priority.index ? 1 : 0);
      ready[(pass: pass, index: index)] = dependent;
    }
  }

  return TopologicalSortResult(
    ordered: ordered,
    unresolved: [
      for (final entry in nodeByKey.entries)
        if (!emitted.contains(entry.key)) entry.value,
    ],
  );
}
