// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'strip_module.dart';

// **************************************************************************
// RpcDtoFieldRefGenerator
// **************************************************************************

abstract final class StripDtoFields {
  static const value = RpcInputField<StripDto>('value');
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StripDto _$StripDtoFromJson(Map<String, dynamic> json) {
  $checkKeys(json, allowedKeys: const ['value']);
  return StripDto(value: json['value'] as String);
}

Map<String, dynamic> _$StripDtoToJson(StripDto instance) => <String, dynamic>{
  'value': instance.value,
};

// **************************************************************************
// LuthorGenerator
// **************************************************************************

// ignore: constant_identifier_names
const StripDtoSchemaKeys = (value: "value");

final SchemaValidator $StripDtoSchema = l
    .schema({StripDtoSchemaKeys.value: l.string().required()})
    .withName("StripDto");

ValidationResult<StripDto> $StripDtoValidate(Object? json) =>
    $StripDtoSchema.validateSchema(json, fromJson: StripDto.fromJson);

extension StripDtoValidationExtension on StripDto {
  ValidationResult<StripDto> validateSelf() =>
      $StripDtoValidate(_$luthorJsonMap(toJson()));
}

// ignore: constant_identifier_names
const StripDtoErrorKeys = (value: "value");

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
