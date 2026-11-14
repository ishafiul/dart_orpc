import 'package:dart_orpc_core/dart_orpc_core.dart';
import 'package:dart_orpc_luthor/dart_orpc_luthor.dart';
import 'package:test/test.dart';

void main() {
  group('Given the luthor RPC validation bridge', () {
    setUp(() {
      _TestDto.fromJsonInputs.clear();
    });

    test('When input is valid then it decodes the DTO', () {
      final decoded = decodeRpcInputWithLuthor<_TestDto>(
        rawInput: {'id': '1'},
        method: 'user.getById',
        validate: _validateTestDto,
      );

      expect(decoded.id, '1');
    });

    test('When input has an unknown key then it is dropped', () {
      final input = <String, Object?>{'id': '1', 'extra': true};

      final decoded = decodeRpcInputWithLuthor<_TestDto>(
        rawInput: input,
        method: 'user.getById',
        validate: _validateTestDto,
      );

      expect(decoded.id, '1');
      expect(_TestDto.fromJsonInputs.single, {'id': '1'});
      expect(input, {'id': '1', 'extra': true});
    });

    test('When input fails validation then it is a bad request', () {
      expect(
        () => decodeRpcInputWithLuthor<_TestDto>(
          rawInput: {'id': ''},
          method: 'user.getById',
          validate: _validateTestDto,
        ),
        _throwsRpc(
          RpcErrorCode.badRequest,
          'Invalid RPC input for "user.getById": id: $_tooShort',
        ),
      );
    });

    test('When input is not an object then it is a bad request', () {
      expect(
        () => decodeRpcInputWithLuthor<_TestDto>(
          rawInput: ['1'],
          method: 'user.getById',
          validate: _validateTestDto,
        ),
        throwsA(
          isA<RpcException>().having(
            (error) => error.code,
            'code',
            RpcErrorCode.badRequest,
          ),
        ),
      );
    });

    test('When fromJson throws then it is a bad request', () {
      expect(
        () => decodeRpcInputWithLuthor<_TestDto>(
          rawInput: {'id': '1'},
          method: 'user.getById',
          validate: (json) => _testDtoSchema.validateSchema(
            json,
            fromJson: (_) => throw const FormatException('broken'),
          ),
        ),
        throwsA(
          isA<RpcException>()
              .having((error) => error.code, 'code', RpcErrorCode.badRequest)
              .having(
                (error) => error.message,
                'message',
                startsWith('Invalid RPC input for "user.getById": '),
              ),
        ),
      );
    });

    test('When list elements fail then the issues carry their paths', () {
      expect(
        () => decodeRpcInputWithLuthor<_TestListDto>(
          rawInput: {
            'items': [
              {'id': '1'},
              {'id': ''},
              {'id': ''},
            ],
          },
          method: 'user.list',
          validate: _validateTestListDto,
        ),
        _throwsRpc(
          RpcErrorCode.badRequest,
          'Invalid RPC input for "user.list": '
          'items.1.id: $_tooShort; items.2.id: $_tooShort',
        ),
      );
    });

    test('When output fails validation then it is an internal error', () {
      expect(
        () => encodeRpcOutputWithLuthor<_TestDto>(
          output: const _TestDto(id: ''),
          method: 'user.getById',
          toJson: (output) => output.toJson(),
          validate: _validateTestDto,
        ),
        _throwsRpc(
          RpcErrorCode.internalError,
          'Invalid RPC output for "user.getById": id: $_tooShort',
        ),
      );
    });

    test('When nested DTO output is valid then it encodes to plain JSON', () {
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
    });

    test('When output JSON is validated then no DTO is rebuilt', () {
      final encoded = encodeRpcOutputJsonWithLuthor<_TestListDto>(
        output: const _TestListDto(items: [_TestDto(id: '1')]),
        method: 'user.list',
        toJson: (value) => value.toJson(),
        validateJson: _testListDtoSchema.validate,
      );

      expect(encoded, {
        'items': [
          {'id': '1'},
        ],
      });
      expect(_TestDto.fromJsonInputs, isEmpty);
    });

    test('When output JSON fails validation then it is an internal error', () {
      expect(
        () => encodeRpcOutputJsonWithLuthor<_TestDto>(
          output: const _TestDto(id: ''),
          method: 'user.getById',
          toJson: (output) => output.toJson(),
          validateJson: _testDtoSchema.validate,
        ),
        _throwsRpc(
          RpcErrorCode.internalError,
          'Invalid RPC output for "user.getById": id: $_tooShort',
        ),
      );
    });

    test('When issues are at the root then only their messages are shown', () {
      expect(
        () => decodeRpcInputWithLuthor<_TestDto>(
          rawInput: {'id': '1'},
          method: 'user.getById',
          validate: (json) => ValidationFailure<_TestDto>(
            input: json,
            issues: const [
              ValidationIssue(code: IssueCode.custom, message: 'root failed'),
              ValidationIssue(
                code: IssueCode.custom,
                message: 'deep failed',
                path: ['profile', 0, 'name'],
              ),
            ],
          ),
        ),
        _throwsRpc(
          RpcErrorCode.badRequest,
          'Invalid RPC input for "user.getById": '
          'root failed; profile.0.name: deep failed',
        ),
      );
    });
  });
}

/// luthor 1.1's message for an empty `id` with `min(1)`.
const _tooShort = 'id must be at least 1 character long';

Matcher _throwsRpc(RpcErrorCode code, String message) => throwsA(
  isA<RpcException>()
      .having((error) => error.code, 'code', code)
      .having((error) => error.message, 'message', message),
);

final _testDtoSchema = l
    .schema({'id': l.string().min(1).required()})
    .withName('_TestDto');

ValidationResult<_TestDto> _validateTestDto(Object? json) =>
    _testDtoSchema.validateSchema(json, fromJson: _TestDto.fromJson);

final _testListDtoSchema = l
    .schema({'items': l.list(_testDtoSchema.required()).required()})
    .withName('_TestListDto');

ValidationResult<_TestListDto> _validateTestListDto(Object? json) =>
    _testListDtoSchema.validateSchema(json, fromJson: _TestListDto.fromJson);

final class _TestDto {
  const _TestDto({required this.id});

  static final fromJsonInputs = <Object?>[];

  factory _TestDto.fromJson(Object? json) {
    fromJsonInputs.add(json);
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
