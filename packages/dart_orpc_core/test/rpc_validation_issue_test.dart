import 'dart:convert';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:test/test.dart';

void main() {
  group('Given a validation issue', () {
    final issue = RpcValidationIssue(
      path: ['items', 1, 'id'],
      code: 'required',
      message: 'id is required',
    );

    test('When serialized then it has path, code and message', () {
      expect(issue.toJson(), {
        'path': ['items', 1, 'id'],
        'code': 'required',
        'message': 'id is required',
      });
    });

    test('When its path is mutated then it fails', () {
      expect(() => issue.path.add('x'), throwsUnsupportedError);
    });

    test('When the source path list changes then the issue keeps its path', () {
      final path = <Object>['name'];
      final copy = RpcValidationIssue(path: path, code: 'c', message: 'm');
      path.add('changed');

      expect(copy.path, ['name']);
    });

    test('When compared then equal fields make equal issues', () {
      expect(
        RpcValidationIssue(
          path: ['items', 1, 'id'],
          code: 'required',
          message: 'id is required',
        ),
        issue,
      );
      expect(
        RpcValidationIssue(
          path: ['items', 2, 'id'],
          code: 'required',
          message: 'id is required',
        ).hashCode,
        isNot(issue.hashCode),
      );
    });
  });

  group('Given paths that are not strings and list indexes', () {
    for (final (label, segment) in [
      ('a double', 1.5),
      ('a negative index', -1),
      ('a boolean', true),
    ]) {
      test('When a path holds $label then construction fails', () {
        expect(
          () => RpcValidationIssue(
            path: [segment],
            code: 'invalidType',
            message: 'Invalid.',
          ),
          throwsArgumentError,
        );
      });
    }
  });

  group('Given paths that must round-trip exactly', () {
    for (final (label, path) in [
      ('a root path', <Object>[]),
      ('a dotted key', <Object>['a.b']),
      ('a numeric string key', <Object>['0']),
      ('string keys and integer indexes', <Object>['items', 0, 'tags', 2]),
    ]) {
      test('When $label is encoded and parsed then it is unchanged', () {
        final issue = RpcValidationIssue(
          path: path,
          code: 'customCode',
          message: 'Failed.',
        );
        final wire = jsonDecode(
          jsonEncode(rpcValidationIssueDetails([issue])),
        ) as Map<String, Object?>;

        final parsed = parseRpcValidationIssues(wire);

        expect(parsed, [issue]);
        expect(parsed.single.path, path);
        expect(parsed.single.path.map((segment) => segment.runtimeType), [
          for (final segment in path) segment.runtimeType,
        ]);
      });
    }
  });

  group('Given details carrying issues', () {
    test('When built then the issues sit under the reserved key in order', () {
      final details = rpcValidationIssueDetails([
        RpcValidationIssue(path: ['b'], code: 'second', message: '2'),
        RpcValidationIssue(path: ['a'], code: 'first', message: '1'),
      ]);

      expect(details.keys, [rpcValidationIssuesKey]);
      expect(rpcValidationIssuesKey, 'issues');
      expect(details['issues'], [
        {
          'path': ['b'],
          'code': 'second',
          'message': '2',
        },
        {
          'path': ['a'],
          'code': 'first',
          'message': '1',
        },
      ]);
    });

    test('When an exception carries them then the wire envelope keeps them', () {
      final exception = RpcException.badRequest(
        'Invalid RPC input for "todo.getById": id: Expected an integer.',
        details: rpcValidationIssueDetails([
          RpcValidationIssue(
            path: ['id'],
            code: 'invalidType',
            message: 'Expected an integer.',
          ),
        ]),
      );

      expect(encodeRpcError(exception).json, {
        'error': {
          'code': 'BAD_REQUEST',
          'message':
              'Invalid RPC input for "todo.getById": id: Expected an integer.',
          'details': {
            'issues': [
              {
                'path': ['id'],
                'code': 'invalidType',
                'message': 'Expected an integer.',
              },
            ],
          },
        },
      });
    });
  });

  group('Given wire details to parse', () {
    test('When entries are mixed then valid ones are kept in order', () {
      final parsed = parseRpcValidationIssues({
        'issues': [
          {
            'path': ['first'],
            'code': 'futureCode',
            'message': 'One.',
          },
          'not an object',
          {'path': 'first', 'code': 'c', 'message': 'Path is not a list.'},
          {
            'path': ['x', 1.5],
            'code': 'c',
            'message': 'Bad segment.',
          },
          {
            'path': ['x'],
            'code': 7,
            'message': 'Code is not a string.',
          },
          {
            'path': ['x'],
            'code': 'c',
          },
          {
            'path': [0],
            'code': 'tooShort',
            'message': 'Two.',
          },
        ],
        'other': 'kept by the application',
      });

      expect(parsed, [
        RpcValidationIssue(
          path: ['first'],
          code: 'futureCode',
          message: 'One.',
        ),
        RpcValidationIssue(path: [0], code: 'tooShort', message: 'Two.'),
      ]);
    });

    test('When entries have extra keys then they still parse', () {
      final parsed = parseRpcValidationIssues({
        'issues': [
          {
            'path': ['a'],
            'code': 'c',
            'message': 'm',
            'params': {'min': 1},
          },
        ],
      });

      expect(parsed, [
        RpcValidationIssue(path: ['a'], code: 'c', message: 'm'),
      ]);
    });

    for (final (label, details) in [
      ('absent details', null),
      ('details without issues', <String, Object?>{'other': true}),
      ('issues that are not a list', <String, Object?>{'issues': 'nope'}),
      ('an empty issue list', <String, Object?>{'issues': <Object?>[]}),
    ]) {
      test('When parsing $label then the result is empty', () {
        expect(parseRpcValidationIssues(details), isEmpty);
      });
    }

    test('When parsed then the result cannot be mutated', () {
      final parsed = parseRpcValidationIssues({
        'issues': [
          {'path': <Object?>[], 'code': 'c', 'message': 'm'},
        ],
      });

      expect(
        () => parsed.add(RpcValidationIssue(path: [], code: 'c', message: 'm')),
        throwsUnsupportedError,
      );
    });
  });
}
