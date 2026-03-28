// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_dtos.dart';

// **************************************************************************
// RpcDtoFieldRefGenerator
// **************************************************************************

abstract final class GetUserDtoFields {
  static const id = RpcInputField<GetUserDto>('id');
  static const include = RpcInputField<GetUserDto>('include');
}

abstract final class UserResponseDtoFields {
  static const id = RpcInputField<UserResponseDto>('id');
  static const name = RpcInputField<UserResponseDto>('name');
}

abstract final class UserStatusDtoFields {
  static const status = RpcInputField<UserStatusDto>('status');
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GetUserDto _$GetUserDtoFromJson(Map<String, dynamic> json) =>
    _GetUserDto(id: json['id'] as String, include: json['include'] as String?);

Map<String, dynamic> _$GetUserDtoToJson(_GetUserDto instance) =>
    <String, dynamic>{'id': instance.id, 'include': ?instance.include};

_UserResponseDto _$UserResponseDtoFromJson(Map<String, dynamic> json) =>
    _UserResponseDto(id: json['id'] as String, name: json['name'] as String);

Map<String, dynamic> _$UserResponseDtoToJson(_UserResponseDto instance) =>
    <String, dynamic>{'id': instance.id, 'name': instance.name};

_UserStatusDto _$UserStatusDtoFromJson(Map<String, dynamic> json) =>
    _UserStatusDto(status: json['status'] as String);

Map<String, dynamic> _$UserStatusDtoToJson(_UserStatusDto instance) =>
    <String, dynamic>{'status': instance.status};

// **************************************************************************
// LuthorGenerator
// **************************************************************************

// ignore: constant_identifier_names
const GetUserDtoSchemaKeys = (id: "id", include: "include");

Validator $GetUserDtoSchema = l.withName('GetUserDto').schema({
  GetUserDtoSchemaKeys.id: l.string().min(1).required(),
  GetUserDtoSchemaKeys.include: l.string(),
});

SchemaValidationResult<GetUserDto> $GetUserDtoValidate(
  Map<String, dynamic> json,
) => $GetUserDtoSchema.validateSchema(json, fromJson: GetUserDto.fromJson);

extension GetUserDtoValidationExtension on GetUserDto {
  SchemaValidationResult<GetUserDto> validateSelf() =>
      $GetUserDtoValidate(toJson());
}

// ignore: constant_identifier_names
const GetUserDtoErrorKeys = (id: "id", include: "include");

// ignore: constant_identifier_names
const UserResponseDtoSchemaKeys = (id: "id", name: "name");

Validator $UserResponseDtoSchema = l.withName('UserResponseDto').schema({
  UserResponseDtoSchemaKeys.id: l.string().min(1).required(),
  UserResponseDtoSchemaKeys.name: l.string().min(1).required(),
});

SchemaValidationResult<UserResponseDto> $UserResponseDtoValidate(
  Map<String, dynamic> json,
) => $UserResponseDtoSchema.validateSchema(
  json,
  fromJson: UserResponseDto.fromJson,
);

extension UserResponseDtoValidationExtension on UserResponseDto {
  SchemaValidationResult<UserResponseDto> validateSelf() =>
      $UserResponseDtoValidate(toJson());
}

// ignore: constant_identifier_names
const UserResponseDtoErrorKeys = (id: "id", name: "name");

// ignore: constant_identifier_names
const UserStatusDtoSchemaKeys = (status: "status");

Validator $UserStatusDtoSchema = l.withName('UserStatusDto').schema({
  UserStatusDtoSchemaKeys.status: l.string().min(1).required(),
});

SchemaValidationResult<UserStatusDto> $UserStatusDtoValidate(
  Map<String, dynamic> json,
) =>
    $UserStatusDtoSchema.validateSchema(json, fromJson: UserStatusDto.fromJson);

extension UserStatusDtoValidationExtension on UserStatusDto {
  SchemaValidationResult<UserStatusDto> validateSelf() =>
      $UserStatusDtoValidate(toJson());
}

// ignore: constant_identifier_names
const UserStatusDtoErrorKeys = (status: "status");
