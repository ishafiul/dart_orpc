import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_luthor/dart_orpc_luthor.dart';
import 'package:test/test.dart';

void main() {
  group('Luthor RPC validation bridge', () {
    test('decodes valid RPC input through a Luthor schema', () {
      final decoded = decodeRpcInputWithLuthor<_TestDto>(
        rawInput: {'id': '1'},
        method: 'user.getById',
        validate: _validateTestDto,
      );

      expect(decoded.id, '1');
    });

    test('read-only input validators receive the original JSON map', () {
      final input = <String, dynamic>{'id': '1'};
      Map<String, dynamic>? validatedInput;

      final decoded = decodeRpcInputWithLuthor<_TestDto>(
        rawInput: input,
        method: 'user.getById',
        validate: _validateTestDto,
        validateReadOnly: (json) {
          validatedInput = json;
          return _validateTestDto(json);
        },
      );

      expect(decoded.id, '1');
      expect(validatedInput, same(input));
    });

    test('legacy input validators receive a defensive map copy', () {
      final input = <String, dynamic>{'id': '1'};

      decodeRpcInputWithLuthor<_TestDto>(
        rawInput: input,
        method: 'user.getById',
        validate: (json) {
          json['extra'] = true;
          return _validateTestDto(json);
        },
      );

      expect(input, {'id': '1'});
    });

    test('read-only input validation preserves RPC error mapping', () {
      expect(
        () => decodeRpcInputWithLuthor<_TestDto>(
          rawInput: {'id': ''},
          method: 'user.getById',
          validate: _validateTestDto,
          validateReadOnly: _validateTestDto,
        ),
        throwsA(
          isA<RpcException>()
              .having((error) => error.code, 'code', RpcErrorCode.badRequest)
              .having(
                (error) => error.message,
                'message',
                'Invalid RPC input for "user.getById": id: id must be at least 1 character long',
              ),
        ),
      );
    });

    test('returns bad request when RPC input fails Luthor validation', () {
      expect(
        () => decodeRpcInputWithLuthor<_TestDto>(
          rawInput: {'id': ''},
          method: 'user.getById',
          validate: _validateTestDto,
        ),
        throwsA(
          isA<RpcException>()
              .having((error) => error.code, 'code', RpcErrorCode.badRequest)
              .having(
                (error) => error.message,
                'message',
                'Invalid RPC input for "user.getById": id: id must be at least 1 character long',
              ),
        ),
      );
    });

    test('returns internal error when RPC output fails Luthor validation', () {
      expect(
        () => encodeRpcOutputWithLuthor<_TestDto>(
          output: const _TestDto(id: ''),
          method: 'user.getById',
          toJson: (output) => output.toJson(),
          validate: _validateTestDto,
        ),
        throwsA(
          isA<RpcException>()
              .having((error) => error.code, 'code', RpcErrorCode.internalError)
              .having(
                (error) => error.message,
                'message',
                'Invalid RPC output for "user.getById": id: id must be at least 1 character long',
              ),
        ),
      );
    });

    test(
      'encodes nested DTO output to plain JSON before validating list schemas',
      () {
        final encoded = encodeRpcOutputWithLuthor<_TestListDto>(
          output: const _TestListDto(items: [_TestDto(id: '1')]),
          method: 'user.list',
          toJson: (output) => output.toJson(),
          validate: _validateTestListDto,
        );

        expect(encoded, {
          'items': [
            {'id': '1'},
          ],
        });
      },
    );

    test('JSON output validation skips reconstructing output DTOs', () {
      _TestDto.fromJsonCalls = 0;
      final output = const _TestListDto(items: [_TestDto(id: '1')]);

      final encoded = encodeRpcOutputJsonWithLuthor<_TestListDto>(
        output: output,
        method: 'user.list',
        toJson: (value) => value.toJson(),
        validateJson: _validateTestListDtoJson,
      );

      expect(encoded, {
        'items': [
          {'id': '1'},
        ],
      });
      expect(_TestDto.fromJsonCalls, 0);
    });

    test('JSON output validation maps nested failures to internal errors', () {
      expect(
        () => encodeRpcOutputJsonWithLuthor<_TestDto>(
          output: const _TestDto(id: ''),
          method: 'user.getById',
          toJson: (output) => output.toJson(),
          validateJson: _validateTestDtoJson,
        ),
        throwsA(
          isA<RpcException>()
              .having((error) => error.code, 'code', RpcErrorCode.internalError)
              .having(
                (error) => error.message,
                'message',
                'Invalid RPC output for "user.getById": id: id must be at least 1 character long',
              ),
        ),
      );
    });

    test('nested validation errors format in traversal order without blanks', () {
      expect(
        () => decodeRpcInputWithLuthor<_TestDto>(
          rawInput: {'id': '1'},
          method: 'user.getById',
          validate: (_) => SchemaValidationError<_TestDto>(
            errors: {
              'profile': {
                'name': ['required', 'invalid'],
                'age': ['too young'],
              },
              'other': ['failed', 42],
            },
          ),
        ),
        throwsA(
          isA<RpcException>().having(
            (error) => error.message,
            'message',
            'Invalid RPC input for "user.getById": profile.name: required; profile.name: invalid; profile.age: too young; other: failed',
          ),
        ),
      );
    });

    test('empty validation errors keep the generic failure message', () {
      expect(
        () => decodeRpcInputWithLuthor<_TestDto>(
          rawInput: {'id': '1'},
          method: 'user.getById',
          validate: (_) => SchemaValidationError<_TestDto>(errors: {}),
        ),
        throwsA(
          isA<RpcException>().having(
            (error) => error.message,
            'message',
            'Invalid RPC input for "user.getById": Validation failed.',
          ),
        ),
      );
    });
  });
}

final Validator _testDtoSchema = l.withName('_TestDto').schema({
  'id': l.string().min(1).required(),
});

SchemaValidationResult<_TestDto> _validateTestDto(Map<String, dynamic> json) {
  return _testDtoSchema.validateSchema(json, fromJson: _TestDto.fromJson);
}

SchemaValidationResult<JsonObject> _validateTestDtoJson(
  Map<String, dynamic> json,
) {
  return _testDtoSchema.validateSchema(json);
}

final Validator _testListDtoSchema = l.withName('_TestListDto').schema({
  'items': l.list(validators: [_testDtoSchema.required()]).required(),
});

SchemaValidationResult<_TestListDto> _validateTestListDto(
  Map<String, dynamic> json,
) {
  return _testListDtoSchema.validateSchema(
    json,
    fromJson: _TestListDto.fromJson,
  );
}

SchemaValidationResult<JsonObject> _validateTestListDtoJson(
  Map<String, dynamic> json,
) {
  return _testListDtoSchema.validateSchema(json);
}

final class _TestDto {
  const _TestDto({required this.id});

  static int fromJsonCalls = 0;

  factory _TestDto.fromJson(Object? json) {
    fromJsonCalls++;
    final object = expectJsonObject(json, context: '_TestDto');
    return _TestDto(id: object['id'] as String);
  }

  final String id;

  JsonObject toJson() => {'id': id};
}

final class _TestListDto {
  const _TestListDto({required this.items});

  factory _TestListDto.fromJson(Object? json) {
    final object = expectJsonObject(json, context: '_TestListDto');
    return _TestListDto(
      items: (object['items'] as List<Object?>)
          .map(_TestDto.fromJson)
          .toList(growable: false),
    );
  }

  final List<_TestDto> items;

  JsonObject toJson() => {'items': items};
}
