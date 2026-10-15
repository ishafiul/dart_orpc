import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:test/test.dart';

void main() {
  test('guard runner consumes lazy guard iterables exactly once', () async {
    final trace = <String>[];
    Iterable<RpcGuard> guards() sync* {
      trace.add('iterator');
      yield _Guard((_) {
        trace.add('first');
      });
      yield _Guard((_) {
        trace.add('second');
      });
    }

    await runRpcGuards(
      guards(),
      rpcContext: RpcContext(headers: {}),
      procedure: _metadata(),
    );
    expect(trace, ['iterator', 'first', 'second']);
    await runRpcGuards(
      const [],
      rpcContext: RpcContext(headers: {}),
      procedure: _metadata(),
    );
  });

  const key = RpcContextKey<String>('first');
  const secondKey = RpcContextKey<int>('second');
  test('binding builder batches updates and isolates every built snapshot', () {
    final base = const RpcContextBindings.empty().withValue(key, 'base');
    final builder = base.toBuilder()
      ..set(key, 'one')
      ..set(secondKey, 2);
    final first = builder.build();
    final sameContents = builder.build();
    builder.set(key, 'two');
    final second = builder.build();
    builder.addAll(const RpcContextBindings.empty().withValue(key, 'three'));
    final third = builder.build();
    expect(base.require(key), 'base');
    expect(first.require(key), 'one');
    expect(sameContents.require(key), 'one');
    expect(second.require(key), 'two');
    expect(third.require(key), 'three');
    expect(third.require(secondKey), 2);
    expect(first.merge(third).require(key), 'three');
    builder.addAll(const RpcContextBindings.empty());
    expect(builder.build().require(key), 'three');
  });

  test('binding key identity and type checks survive batching', () {
    final one = RpcContextKey<String>('same');
    final other = RpcContextKey<String>('same');
    final builder = RpcContextBindingsBuilder()
      ..set(one, 'one')
      ..set(other, 'other');
    final result = builder.build();
    expect(result.require(one), 'one');
    expect(result.require(other), 'other');
    expect(const RpcContextBindings.empty().merge(result), same(result));
    expect(result.merge(const RpcContextBindings.empty()), same(result));
  });

  for (final count in [1, 2, 8, 16]) {
    test(
      'header lookup preserves first case-insensitive spelling for $count lookups',
      () {
        final mutable = {
          'X-Tenant': 'first',
          'x-tenant': 'second',
          'Accept': 'json',
        };
        final context = RpcContext(headers: mutable)
          ..prepareHeaderLookup(count);
        mutable['X-Tenant'] = 'mutated';
        expect(context.headerValue('x-TENANT'), 'first');
        expect(context.headerValue('ACCEPT'), 'json');
        expect(context.headerValue('missing'), isNull);
        context.prepareHeaderLookup(count);
        expect(context.copyWith().headerValue('X-Tenant'), 'first');
        expect(
          context
              .copyWith(headers: {'x-tenant': 'replacement'})
              .headerValue('X-Tenant'),
          'replacement',
        );
        final canonical = RpcContext(
          headers: {'x-tenant': 'one', 'accept': 'json'},
        )..prepareHeaderLookup(count);
        expect(canonical.headerValue('X-TENANT'), 'one');
      },
    );
  }

  test(
    'registry snapshots header plans and avoids per-call metadata scans',
    () async {
      final parameters = _CountedList<ProcedureParameterMetadata>([
        for (var i = 0; i < 10; i++)
          ProcedureParameterMetadata(
            parameterName: 'value$i',
            wireName: 'X-Header-$i',
            source: ProcedureParameterSourceKind.header,
            typeCode: 'String',
          ),
      ]);
      final metadata = _metadata(parameters: parameters);
      final procedure = RpcUnaryProcedure<Object?, Object?>(
        method: 'test.echo',
        metadata: metadata,
        decodeInput: (raw) => raw,
        encodeOutput: (value) => value,
        handler: (_, input) => input,
      );
      final registry = RpcProcedureRegistry([procedure]);
      final reads = parameters.reads;
      parameters.values.clear();
      final input = {'value0': 'spoof', 'keep': true};
      for (var i = 0; i < 3; i++) {
        final output = await registry.dispatch(
          RpcContext(
            headers: {for (var i = 0; i < 10; i++) 'X-Header-$i': '$i'},
          ),
          RpcRequest(method: 'test.echo', input: input),
        );
        expect(output, {
          'keep': true,
          for (var i = 0; i < 10; i++) 'value$i': '$i',
        });
      }
      expect(parameters.reads, reads);
      expect(input, {'value0': 'spoof', 'keep': true});
      expect(registry.procedures.single, same(procedure));
      expect(() => metadata.parameters.clear(), throwsUnsupportedError);
      expect(
        await registry.dispatch(
          RpcContext(headers: {}),
          const RpcRequest(method: 'test.echo', input: null),
        ),
        isNull,
      );
    },
  );

  test(
    'metadata index preserves duplicate keys, order, and registration snapshot',
    () {
      final entries = _CountedList<ProcedureCustomMetadata>([
        const ProcedureCustomMetadata(
          key: 'permission',
          value: {'name': 'one'},
        ),
        const ProcedureCustomMetadata(key: 'other', value: {}),
        const ProcedureCustomMetadata(
          key: 'permission',
          value: {'name': 'two'},
        ),
      ]);
      final metadata = _metadata(customMetadata: entries);
      final registry = ProcedureMetadataRegistry([metadata]);
      final reads = entries.reads;
      entries.values.clear();
      for (var i = 0; i < 5; i++) {
        expect(registry['test.echo']!.metadataValues('permission'), [
          {'name': 'one'},
          {'name': 'two'},
        ]);
        expect(metadata.firstMetadataValue('permission'), {'name': 'one'});
        expect(metadata.metadataEntries('absent'), isEmpty);
        expect(metadata.firstMetadataValue('absent'), isNull);
      }
      expect(entries.reads, reads);
      expect(() => metadata.customMetadata.clear(), throwsUnsupportedError);
      expect(
        () => (metadata.metadataEntries('permission') as List).clear(),
        throwsUnsupportedError,
      );
    },
  );

  group('structural JSON normalization', () {
    test(
      'matches round trip for JSON primitives, DTOs, unusual strings and numeric limits',
      () {
        final values = <Object?>[
          {
            'string': 'বাংলা\n"\\\ud800',
            'null': null,
            'bool': true,
            'numbers': [
              0,
              -0.0,
              1.0,
              1.5,
              9223372036854775807,
              -9223372036854775808,
            ],
          },
          {
            'nested': [
              _JsonValue({
                'id': 1,
                'list': [
                  _JsonValue({'ok': true}),
                ],
              }),
            ],
          },
          _JsonValue({'value': 'root DTO'}),
          <Object?, Object?>{
            'string-key': <Object?>[1, false],
          },
          {
            'equal DTOs': [
              _EqualJsonValue([
                _EqualJsonValue({'ok': true}),
              ]),
            ],
          },
        ];
        for (final value in values) {
          expect(
            normalizeJsonObject(value, context: 'output'),
            jsonDecode(jsonEncode(value)),
          );
        }
      },
    );

    test(
      'creates independent snapshots and permits repeated noncyclic references',
      () {
        final child = {
          'values': <Object?>[1, 2],
        };
        final original = {'first': child, 'second': child};
        final normalized = normalizeJsonObject(original, context: 'output');
        (child['values'] as List).add(3);
        expect(normalized, {
          'first': {
            'values': [1, 2],
          },
          'second': {
            'values': [1, 2],
          },
        });
        expect(normalized['first'], isNot(same(normalized['second'])));
        (normalized['first'] as Map)['extra'] = true;
        expect(normalized['second'], {
          'values': [1, 2],
        });
      },
    );

    test('rejects cycles and unsupported values like JsonEncoder', () {
      final cyclicList = <Object?>[];
      cyclicList.add(cyclicList);
      final cyclicMap = <String, Object?>{};
      cyclicMap['self'] = cyclicMap;
      final customCycle = _MutableJsonValue();
      customCycle.value = {'self': customCycle};
      for (final value in [
        {'cycle': cyclicList},
        cyclicMap,
        customCycle,
        {'value': double.nan},
        {'value': double.infinity},
        {'value': double.negativeInfinity},
        {'value': Object()},
        {1: 'invalid key'},
        _JsonValue(_JsonValue({'two conversions': 'unsupported'})),
        _ThrowingJsonValue(),
      ]) {
        Object? expected;
        try {
          jsonDecode(jsonEncode(value));
        } catch (error) {
          expected = error;
        }
        expect(expected, isNotNull);
        try {
          normalizeJsonObject(value, context: 'output');
          fail('Expected ${expected.runtimeType}');
        } catch (actual) {
          expect(actual.runtimeType, expected.runtimeType);
        }
      }
    });

    test(
      'toJson gets one conversion chance per value, preserving error cause',
      () {
        final dto = _CountedJsonValue({'id': 1});
        expect(normalizeJsonObject({'dto': dto}, context: 'output'), {
          'dto': {'id': 1},
        });
        expect(dto.calls, 1);
        expect(
          () => normalizeJsonObject(_ThrowingJsonValue(), context: 'output'),
          throwsA(
            isA<JsonUnsupportedObjectError>().having(
              (error) => error.cause,
              'cause',
              isA<StateError>(),
            ),
          ),
        );
      },
    );

    test('map entry snapshot survives nested toJson mutating original map', () {
      final value = <String, Object?>{};
      value['dto'] = _MutatingJsonValue(value);
      value['keep'] = 1;
      expect(normalizeJsonObject(value, context: 'output'), {
        'dto': {'done': true},
        'keep': 1,
      });
    });

    test('non-object roots retain bad-request error', () {
      for (final value in [
        null,
        1,
        'text',
        true,
        [],
        _JsonValue([1]),
      ]) {
        expect(
          () => normalizeJsonObject(value, context: 'output'),
          throwsA(
            isA<RpcException>().having(
              (error) => error.code,
              'code',
              RpcErrorCode.badRequest,
            ),
          ),
        );
      }
    });
  });

  test(
    'empty guard fast path preserves async entry and immediate cancellation',
    () async {
      final source = RpcCancellationSource();
      var handled = false;
      final procedure = RpcUnaryProcedure<Null, String>(
        method: 'test.echo',
        metadata: _metadata(),
        decodeInput: (_) => null,
        encodeOutput: (value) => value,
        handler: (_, _) {
          handled = true;
          return 'done';
        },
      );
      final future = procedure.invoke(
        RpcContext(headers: {}, cancellation: source.signal),
        null,
      );
      expect(handled, isFalse);
      source.cancel();
      await expectLater(
        future,
        throwsA(
          isA<RpcException>().having(
            (error) => error.code,
            'code',
            RpcErrorCode.cancelled,
          ),
        ),
      );
      expect(handled, isFalse);
      expect(await procedure.invoke(RpcContext(headers: {}), null), 'done');
    },
  );

  test(
    'guards and before hooks remain sequential and short-circuit on denial',
    () async {
      final trace = <String>[];
      final release = Completer<void>();
      final entered = Completer<void>();
      final procedure = RpcUnaryProcedure<Null, String>(
        method: 'test.echo',
        metadata: _metadata(),
        decodeInput: (_) {
          trace.add('decode');
          return null;
        },
        encodeOutput: (value) => value,
        guards: [
          _Guard((_) async {
            trace.add('guard1');
            entered.complete();
            await release.future;
          }),
          _Guard((_) {
            trace.add('guard2');
          }),
        ],
        beforeInvoke: (_, _) {
          trace.add('before');
        },
        handler: (_, _) {
          trace.add('handler');
          return 'done';
        },
      );
      final result = procedure.invoke(RpcContext(headers: {}), null);
      await entered.future;
      expect(trace, ['decode', 'guard1']);
      release.complete();
      expect(await result, 'done');
      expect(trace, ['decode', 'guard1', 'guard2', 'before', 'handler']);
      final denied = RpcUnaryProcedure<Null, String>(
        method: 'test.echo',
        metadata: _metadata(),
        decodeInput: (_) => null,
        encodeOutput: (value) => value,
        guards: [_Guard((_) => throw RpcException.forbidden('denied'))],
        handler: (_, _) => throw StateError('must not run'),
      );
      await expectLater(
        denied.invoke(RpcContext(headers: {}), null),
        throwsA(
          isA<RpcException>().having(
            (error) => error.code,
            'code',
            RpcErrorCode.forbidden,
          ),
        ),
      );
    },
  );
}

ProcedureMetadata _metadata({
  List<ProcedureParameterMetadata> parameters = const [],
  List<ProcedureCustomMetadata> customMetadata = const [],
}) => ProcedureMetadata(
  rpcMethod: 'test.echo',
  controllerNamespace: 'test',
  methodName: 'echo',
  outputTypeCode: 'Object?',
  parameters: parameters,
  customMetadata: customMetadata,
);

class _JsonValue {
  const _JsonValue(this.value);
  final Object? value;
  Object? toJson() => value;
}

final class _MutableJsonValue {
  Object? value;
  Object? toJson() => value;
}

final class _EqualJsonValue extends _JsonValue {
  const _EqualJsonValue(super.value);
  @override
  bool operator ==(Object other) => other is _EqualJsonValue;
  @override
  int get hashCode => 0;
}

final class _CountedJsonValue {
  _CountedJsonValue(this.value);
  final Object? value;
  int calls = 0;
  Object? toJson() {
    calls++;
    return value;
  }
}

final class _ThrowingJsonValue {
  Object? toJson() => throw StateError('failed');
}

final class _MutatingJsonValue {
  _MutatingJsonValue(this.original);
  final Map<String, Object?> original;
  Map<String, Object?> toJson() {
    original.clear();
    return {'done': true};
  }
}

final class _CountedList<T> extends ListBase<T> {
  _CountedList(this.values);
  final List<T> values;
  int reads = 0;
  @override
  int get length => values.length;
  @override
  set length(int value) => values.length = value;
  @override
  T operator [](int index) {
    reads++;
    return values[index];
  }

  @override
  void operator []=(int index, T value) => values[index] = value;
}

final class _Guard implements RpcGuard {
  _Guard(this.callback);
  final FutureOr<void> Function(RpcGuardContext) callback;
  @override
  FutureOr<void> canActivate(RpcGuardContext context) => callback(context);
}
