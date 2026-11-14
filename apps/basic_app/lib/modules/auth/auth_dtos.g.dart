// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_dtos.dart';

// **************************************************************************
// RpcDtoFieldRefGenerator
// **************************************************************************

abstract final class SignUpDtoFields {
  static const email = RpcInputField<SignUpDto>('email');
  static const name = RpcInputField<SignUpDto>('name');
  static const password = RpcInputField<SignUpDto>('password');
}

abstract final class LoginDtoFields {
  static const email = RpcInputField<LoginDto>('email');
  static const password = RpcInputField<LoginDto>('password');
}

abstract final class AuthUserDtoFields {
  static const email = RpcInputField<AuthUserDto>('email');
  static const id = RpcInputField<AuthUserDto>('id');
  static const name = RpcInputField<AuthUserDto>('name');
}

abstract final class AuthResponseDtoFields {
  static const accessToken = RpcInputField<AuthResponseDto>('accessToken');
  static const expiresIn = RpcInputField<AuthResponseDto>('expiresIn');
  static const tokenType = RpcInputField<AuthResponseDto>('tokenType');
  static const user = RpcInputField<AuthResponseDto>('user');
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SignUpDto _$SignUpDtoFromJson(Map<String, dynamic> json) => _SignUpDto(
  name: json['name'] as String,
  email: json['email'] as String,
  password: json['password'] as String,
);

Map<String, dynamic> _$SignUpDtoToJson(_SignUpDto instance) =>
    <String, dynamic>{
      'name': instance.name,
      'email': instance.email,
      'password': instance.password,
    };

_LoginDto _$LoginDtoFromJson(Map<String, dynamic> json) => _LoginDto(
  email: json['email'] as String,
  password: json['password'] as String,
);

Map<String, dynamic> _$LoginDtoToJson(_LoginDto instance) => <String, dynamic>{
  'email': instance.email,
  'password': instance.password,
};

_AuthUserDto _$AuthUserDtoFromJson(Map<String, dynamic> json) => _AuthUserDto(
  id: json['id'] as String,
  name: json['name'] as String,
  email: json['email'] as String,
);

Map<String, dynamic> _$AuthUserDtoToJson(_AuthUserDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'email': instance.email,
    };

_AuthResponseDto _$AuthResponseDtoFromJson(Map<String, dynamic> json) =>
    _AuthResponseDto(
      accessToken: json['accessToken'] as String,
      tokenType: json['tokenType'] as String? ?? 'Bearer',
      expiresIn: (json['expiresIn'] as num).toInt(),
      user: AuthUserDto.fromJson(json['user'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$AuthResponseDtoToJson(_AuthResponseDto instance) =>
    <String, dynamic>{
      'accessToken': instance.accessToken,
      'tokenType': instance.tokenType,
      'expiresIn': instance.expiresIn,
      'user': instance.user,
    };

// **************************************************************************
// LuthorGenerator
// **************************************************************************

// ignore: constant_identifier_names
const SignUpDtoSchemaKeys = (
  name: "name",
  email: "email",
  password: "password",
);

final SchemaValidator $SignUpDtoSchema = l
    .schema({
      SignUpDtoSchemaKeys.name: l.string().min(3).required(),
      SignUpDtoSchemaKeys.email: l
          .string()
          .email(message: "Enter a valid email address.")
          .max(254)
          .required(),
      SignUpDtoSchemaKeys.password: l
          .string()
          .min(8)
          .max(72)
          .regex(
            RegExp(r'^(?=.*[A-Za-z])(?=.*\d).+$'),
            message:
                "Password must contain at least one letter and one number.",
          )
          .required(),
    })
    .withName("SignUpDto");

ValidationResult<SignUpDto> $SignUpDtoValidate(Object? json) =>
    $SignUpDtoSchema.validateSchema(json, fromJson: SignUpDto.fromJson);

extension SignUpDtoValidationExtension on SignUpDto {
  ValidationResult<SignUpDto> validateSelf() =>
      $SignUpDtoValidate(_$luthorJsonMap(toJson()));
}

// ignore: constant_identifier_names
const SignUpDtoErrorKeys = (name: "name", email: "email", password: "password");

// ignore: constant_identifier_names
const LoginDtoSchemaKeys = (email: "email", password: "password");

final SchemaValidator $LoginDtoSchema = l
    .schema({
      LoginDtoSchemaKeys.email: l
          .string()
          .email(message: "Enter a valid email address.")
          .max(254)
          .required(),
      LoginDtoSchemaKeys.password: l
          .string()
          .min(8)
          .max(72)
          .regex(
            RegExp(r'^(?=.*[A-Za-z])(?=.*\d).+$'),
            message:
                "Password must contain at least one letter and one number.",
          )
          .required(),
    })
    .withName("LoginDto");

ValidationResult<LoginDto> $LoginDtoValidate(Object? json) =>
    $LoginDtoSchema.validateSchema(json, fromJson: LoginDto.fromJson);

extension LoginDtoValidationExtension on LoginDto {
  ValidationResult<LoginDto> validateSelf() =>
      $LoginDtoValidate(_$luthorJsonMap(toJson()));
}

// ignore: constant_identifier_names
const LoginDtoErrorKeys = (email: "email", password: "password");

// ignore: constant_identifier_names
const AuthUserDtoSchemaKeys = (id: "id", name: "name", email: "email");

final SchemaValidator $AuthUserDtoSchema = l
    .schema({
      AuthUserDtoSchemaKeys.id: l.string().required(),
      AuthUserDtoSchemaKeys.name: l.string().required(),
      AuthUserDtoSchemaKeys.email: l.string().required(),
    })
    .withName("AuthUserDto");

ValidationResult<AuthUserDto> $AuthUserDtoValidate(Object? json) =>
    $AuthUserDtoSchema.validateSchema(json, fromJson: AuthUserDto.fromJson);

extension AuthUserDtoValidationExtension on AuthUserDto {
  ValidationResult<AuthUserDto> validateSelf() =>
      $AuthUserDtoValidate(_$luthorJsonMap(toJson()));
}

// ignore: constant_identifier_names
const AuthUserDtoErrorKeys = (id: "id", name: "name", email: "email");

// ignore: constant_identifier_names
const AuthResponseDtoSchemaKeys = (
  accessToken: "accessToken",
  tokenType: "tokenType",
  expiresIn: "expiresIn",
  user: "user",
);

final SchemaValidator $AuthResponseDtoSchema = l
    .schema({
      AuthResponseDtoSchemaKeys.accessToken: l.string().required(),
      AuthResponseDtoSchemaKeys.tokenType: l.string(),
      AuthResponseDtoSchemaKeys.expiresIn: l.int().required(),
      AuthResponseDtoSchemaKeys.user: forwardRef(
        () => $AuthUserDtoSchema.required(),
      ),
    })
    .withName("AuthResponseDto");

ValidationResult<AuthResponseDto> $AuthResponseDtoValidate(Object? json) =>
    $AuthResponseDtoSchema.validateSchema(
      json,
      fromJson: AuthResponseDto.fromJson,
    );

extension AuthResponseDtoValidationExtension on AuthResponseDto {
  ValidationResult<AuthResponseDto> validateSelf() =>
      $AuthResponseDtoValidate(_$luthorJsonMap(toJson()));
}

// ignore: constant_identifier_names
const AuthResponseDtoErrorKeys = (
  accessToken: "accessToken",
  tokenType: "tokenType",
  expiresIn: "expiresIn",
  user: ($key: "user", id: "user.id", name: "user.name", email: "user.email"),
);

Map<String, Object?> _$luthorJsonMap(Map<Object?, Object?> map) => {
  for (final entry in map.entries)
    entry.key.toString(): _$luthorJsonValue(entry.value),
};

Object? _$luthorJsonValue(Object? value) {
  if (value == null || value is String || value is num || value is bool) {
    return value;
  }
  if (value is Map) return _$luthorJsonMap(value);
  if (value is Iterable) {
    return [for (final item in value) _$luthorJsonValue(item)];
  }
  try {
    // ignore: avoid_dynamic_calls
    return _$luthorJsonValue((value as dynamic).toJson());
    // ignore: avoid_catching_errors
  } on NoSuchMethodError {
    return value;
  }
}
