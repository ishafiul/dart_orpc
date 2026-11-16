import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:test/test.dart';

List<int> reference(Object? value) => utf8.encode(jsonEncode(value));

List<int> written(Object? value) =>
    (RpcJsonWriter()..writeValue(value)).takeBytes();

final class _HasToJson {
  const _HasToJson(this.name);

  final String name;

  Map<String, Object?> toJson() => {'name': name};
}

final class _Preencoded implements RpcJsonBytes {
  const _Preencoded(this.json);

  final String json;

  @override
  List<int> toJsonBytes() => utf8.encode(json);
}

void main() {
  group('writeValue matches jsonEncode', () {
    final cases = <String, Object?>{
      'null': null,
      'true': true,
      'false': false,
      'zero': 0,
      'negative int': -42,
      'large int': 9007199254740993,
      'double': 1.5,
      'whole double': 2.0,
      'negative zero': -0.0,
      'exponent double': 1e21,
      'small double': 1e-7,
      'empty string': '',
      'ascii string': 'hello world',
      'quote and backslash': r'say "hi" \ bye',
      'control characters': '\b\f\n\r\t\u0000\u0001\u001f\u007f',
      'non-ascii': 'café ü 日本',
      'emoji': 'smile 😀 end',
      'lone high surrogate': 'a\ud800b',
      'lone low surrogate': 'a\udc00b',
      'trailing high surrogate': 'end\ud83d',
      'empty list': <Object?>[],
      'empty map': <String, Object?>{},
      'nested': {
        'posts': [
          {
            'id': 1,
            'body': 'x "y"',
            'tags': ['a', null, true],
          },
          {
            'id': 2,
            'nested': {
              'deep': [1.25, -3],
            },
          },
        ],
      },
      'object with toJson': const _HasToJson('né'),
      'list of objects with toJson': [const _HasToJson('a'), 1],
    };
    for (final MapEntry(:key, :value) in cases.entries) {
      test(key, () => expect(written(value), reference(value)));
    }
  });

  test('writeValue matches jsonEncode on random strings', () {
    final random = Random(7);
    for (var round = 0; round < 2000; round++) {
      final units = [
        for (var i = 0; i < random.nextInt(40); i++)
          switch (random.nextInt(5)) {
            0 => random.nextInt(0x20),
            1 => 0x20 + random.nextInt(0x60),
            2 => 0x80 + random.nextInt(0x780),
            3 => 0xd800 + random.nextInt(0x800),
            _ => random.nextInt(0x10000),
          },
      ];
      final value = String.fromCharCodes(units);
      expect(written(value), reference(value), reason: 'units: $units');
    }
  });

  test('writeValue embeds RpcJsonBytes values as they are', () {
    expect(
      utf8.decode(written({'raw': const _Preencoded('[1,2]'), 'n': 3})),
      '{"raw":[1,2],"n":3}',
    );
  });

  test('writeValue rejects what jsonEncode rejects', () {
    for (final value in <Object?>[
      double.nan,
      double.infinity,
      {1: 'non-string key'},
      Object(),
    ]) {
      expect(
        () => written(value),
        throwsA(isA<JsonUnsupportedObjectError>()),
        reason: '$value',
      );
    }
  });

  test('deep trees match jsonEncode and cycles throw JsonCyclicError', () {
    Object? deep = 'leaf';
    for (var level = 0; level < 600; level++) {
      deep = level.isEven ? [deep] : {'k': deep};
    }
    expect(written(deep), reference(deep));

    final cyclic = <Object?>[];
    cyclic.add([cyclic]);
    expect(() => written(cyclic), throwsA(isA<JsonCyclicError>()));
  });

  test('typed writes build a document without an intermediate map', () {
    final writer = RpcJsonWriter()
      ..writeRaw('{"id":')
      ..writeInt(7)
      ..writeRaw(',"name":')
      ..writeString('Ann "A"')
      ..writeRaw(',"score":')
      ..writeDouble(0.5)
      ..writeRaw(',"ok":')
      ..writeBool(true)
      ..writeRaw(',"gone":')
      ..writeNull()
      ..writeRaw('}');

    expect(
      utf8.decode(writer.takeBytes()),
      '{"id":7,"name":"Ann \\"A\\"","score":0.5,"ok":true,"gone":null}',
    );
  });

  test('writeRaw rejects non-ASCII text', () {
    expect(() => RpcJsonWriter().writeRaw('é'), throwsArgumentError);
  });

  test('writeDouble rejects non-finite numbers', () {
    expect(
      () => RpcJsonWriter().writeDouble(double.nan),
      throwsA(isA<JsonUnsupportedObjectError>()),
    );
  });

  test('the buffer grows past its initial capacity', () {
    final long = 'x' * 10000;
    final writer = RpcJsonWriter(initialCapacity: 8)..writeValue([long, long]);

    expect(writer.length, 20007);
    expect(writer.takeBytes(), reference([long, long]));
  });

  test('takeBytes returns a Uint8List and resets the writer', () {
    final writer = RpcJsonWriter()..writeInt(12);
    final first = writer.takeBytes();
    writer.writeInt(3);

    expect(first, isA<Uint8List>());
    expect(utf8.decode(first), '12');
    expect(utf8.decode(writer.takeBytes()), '3');
    expect(writer.length, 0);
  });
}
