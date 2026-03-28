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
  });
}

final Validator _testDtoSchema = l.withName('_TestDto').schema({
  'id': l.string().min(1).required(),
});

SchemaValidationResult<_TestDto> _validateTestDto(Map<String, dynamic> json) {
  return _testDtoSchema.validateSchema(json, fromJson: _TestDto.fromJson);
}

final class _TestDto {
  const _TestDto({required this.id});

  factory _TestDto.fromJson(Object? json) {
    final object = expectJsonObject(json, context: '_TestDto');
    return _TestDto(id: object['id'] as String);
  }

  final String id;

  JsonObject toJson() => {'id': id};
}
