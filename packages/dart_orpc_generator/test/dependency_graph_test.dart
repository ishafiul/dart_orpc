import 'dart:math';

import 'package:dart_orpc_generator/src/graph/depth_first_search.dart';
import 'package:dart_orpc_generator/src/graph/topological_sort.dart';
import 'package:test/test.dart';

void main() {
  group('Depth-first dependency traversal', () {
    test('empty roots produce empty output', () {
      expect(
        depthFirstPostorder<int, int>(
          [],
          keyOf: (node) => node,
          dependenciesOf: (_) => [],
        ),
        isEmpty,
      );
    });

    test('shared dependencies are visited once in dependency-first order', () {
      final graph = {
        'root': ['left', 'right'],
        'left': ['base'],
        'right': ['base'],
        'base': <String>[],
      };
      final reads = <String, int>{};
      final ordered = depthFirstPostorder<String, String>(
        ['root', 'left', 'other'],
        keyOf: (node) => node,
        dependenciesOf: (node) {
          reads.update(node, (count) => count + 1, ifAbsent: () => 1);
          return graph[node] ?? [];
        },
      );

      expect(ordered, ['base', 'left', 'right', 'root', 'other']);
      expect(reads.values, everyElement(1));
    });

    test('keys identify equivalent node references', () {
      final ordered = depthFirstPostorder<({String key, int instance}), String>(
        [(key: 'same', instance: 1), (key: 'same', instance: 2)],
        keyOf: (node) => node.key,
        dependenciesOf: (_) => [],
      );
      expect(ordered, [(key: 'same', instance: 1)]);
    });

    test('cycle diagnostics exclude ancestors outside the cycle', () {
      final graph = {
        'root': ['first'],
        'first': ['second'],
        'second': ['first'],
      };
      expect(
        findDependencyCycle<String, String>(
          ['root'],
          keyOf: (node) => node,
          dependenciesOf: (node) => graph[node] ?? [],
        ),
        ['first', 'second', 'first'],
      );
    });

    test('self dependencies report a closed cycle', () {
      expect(
        () => depthFirstPostorder<String, String>(
          ['self'],
          keyOf: (node) => node,
          dependenciesOf: (node) => [node],
        ),
        throwsA(
          isA<DependencyCycle<String>>().having((cycle) => cycle.path, 'path', [
            'self',
            'self',
          ]),
        ),
      );
    });

    test('deep graphs do not depend on the Dart recursion limit', () {
      const count = 20000;
      var reads = 0;
      final ordered = depthFirstPostorder<int, int>(
        [0],
        keyOf: (node) => node,
        dependenciesOf: (node) {
          reads++;
          return node + 1 < count ? [node + 1] : [];
        },
      );
      expect(
        ordered,
        orderedEquals(List.generate(count, (i) => count - i - 1)),
      );
      expect(reads, count);
    });

    test('acyclic shared subgraphs are not searched repeatedly', () {
      const count = 1000;
      var reads = 0;
      final cycle = findDependencyCycle<int, int>(
        List.generate(count, (index) => index),
        keyOf: (node) => node,
        dependenciesOf: (node) {
          reads++;
          return [if (node > 0) node - 1, if (node > 1) node - 2];
        },
      );
      expect(cycle, isNull);
      expect(reads, count);
    });
  });

  group('Kahn dependency ordering', () {
    test('empty graph is fully resolved', () {
      final result = _sort({});
      expect(result.ordered, isEmpty);
      expect(result.unresolved, isEmpty);
    });

    test(
      'preserves declaration passes when newly ready nodes overtake others',
      () {
        final result = _sort({
          'base': [],
          'service': ['base'],
          'optionalConsumer': [],
        });
        expect(result.ordered, ['base', 'service', 'optionalConsumer']);
        expect(result.unresolved, isEmpty);
      },
    );

    test('earlier unlocked declarations wait until the next pass', () {
      final result = _sort({
        'service': ['base'],
        'optionalConsumer': [],
        'base': [],
      });
      expect(result.ordered, ['optionalConsumer', 'base', 'service']);
    });

    test('external dependencies and repeated edges count once', () {
      final graph = {
        'consumer': ['service', 'service', 'external'],
        'service': <String>[],
      };
      final result = topologicalSort<String, String>(
        graph.keys,
        keyOf: (node) => node,
        dependenciesOf: (node) => graph[node]!,
        available: ['external'],
      );
      expect(result.ordered, ['service', 'consumer']);
      expect(result.unresolved, isEmpty);
    });

    test('missing keys block their consumers without inventing a cycle', () {
      final result = _sort({
        'consumer': ['blocked'],
        'ready': [],
        'blocked': ['missing'],
      });
      expect(result.ordered, ['ready']);
      expect(result.unresolved, ['consumer', 'blocked']);
    });

    test('cycles leave only blocked nodes in declaration order', () {
      final result = _sort({
        'first': ['second'],
        'independent': [],
        'second': ['first'],
        'consumer': ['first'],
      });
      expect(result.ordered, ['independent']);
      expect(result.unresolved, ['first', 'second', 'consumer']);
    });

    test('duplicate keys are rejected', () {
      expect(
        () => topologicalSort<int, int>(
          [1, 1],
          keyOf: (node) => node,
          dependenciesOf: (_) => [],
        ),
        throwsArgumentError,
      );
    });

    test('dependencies are read once even for reverse-declared chains', () {
      const count = 5000;
      var reads = 0;
      final result = topologicalSort<int, int>(
        List.generate(count, (index) => index),
        keyOf: (node) => node,
        dependenciesOf: (node) {
          reads++;
          return node + 1 < count ? [node + 1] : [];
        },
      );
      expect(
        result.ordered,
        orderedEquals(List.generate(count, (i) => count - i - 1)),
      );
      expect(result.unresolved, isEmpty);
      expect(reads, count);
    });

    test(
      'matches declaration-scan behavior across deterministic generated graphs',
      () {
        final random = Random(17);
        for (var sample = 0; sample < 300; sample++) {
          final graph = <int, List<int>>{
            for (var node = 0; node < 12; node++)
              node: [
                for (var dependency = 0; dependency < 14; dependency++)
                  if (random.nextInt(12) == 0) dependency,
              ],
          };
          final result = topologicalSort<int, int>(
            graph.keys,
            keyOf: (node) => node,
            dependenciesOf: (node) => graph[node]!,
          );
          final expected = _declarationScan(graph);
          expect(result.ordered, expected, reason: 'Graph $sample: $graph');
          expect(
            result.unresolved,
            graph.keys.where((node) => !expected.contains(node)),
          );
        }
      },
    );
  });
}

TopologicalSortResult<String> _sort(Map<String, List<String>> graph) {
  return topologicalSort<String, String>(
    graph.keys,
    keyOf: (node) => node,
    dependenciesOf: (node) => graph[node]!,
  );
}

List<int> _declarationScan(Map<int, List<int>> graph) {
  final ordered = <int>[];
  final available = <int>{};
  while (true) {
    var progressed = false;
    for (final node in graph.keys) {
      if (available.contains(node) || !graph[node]!.every(available.contains)) {
        continue;
      }
      ordered.add(node);
      available.add(node);
      progressed = true;
    }
    if (!progressed) return ordered;
  }
}
