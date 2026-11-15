// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'todo_analysis_dtos.dart';

// **************************************************************************
// RpcDtoFieldRefGenerator
// **************************************************************************

abstract final class TodoAnalysisSummaryDtoFields {
  static const completed = RpcInputField<TodoAnalysisSummaryDto>('completed');
  static const completionRate = RpcInputField<TodoAnalysisSummaryDto>(
    'completionRate',
  );
  static const pending = RpcInputField<TodoAnalysisSummaryDto>('pending');
  static const total = RpcInputField<TodoAnalysisSummaryDto>('total');
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TodoAnalysisSummaryDto _$TodoAnalysisSummaryDtoFromJson(
  Map<String, dynamic> json,
) => _TodoAnalysisSummaryDto(
  total: (json['total'] as num).toInt(),
  completed: (json['completed'] as num).toInt(),
  pending: (json['pending'] as num).toInt(),
  completionRate: (json['completionRate'] as num).toDouble(),
);

Map<String, dynamic> _$TodoAnalysisSummaryDtoToJson(
  _TodoAnalysisSummaryDto instance,
) => <String, dynamic>{
  'total': instance.total,
  'completed': instance.completed,
  'pending': instance.pending,
  'completionRate': instance.completionRate,
};

// **************************************************************************
// LuthorGenerator
// **************************************************************************

// ignore: constant_identifier_names
const TodoAnalysisSummaryDtoSchemaKeys = (
  total: "total",
  completed: "completed",
  pending: "pending",
  completionRate: "completionRate",
);

final SchemaValidator $TodoAnalysisSummaryDtoSchema = l
    .schema({
      TodoAnalysisSummaryDtoSchemaKeys.total: l.int().required(),
      TodoAnalysisSummaryDtoSchemaKeys.completed: l.int().required(),
      TodoAnalysisSummaryDtoSchemaKeys.pending: l.int().required(),
      TodoAnalysisSummaryDtoSchemaKeys.completionRate: l.double().required(),
    })
    .withName("TodoAnalysisSummaryDto");

ValidationResult<TodoAnalysisSummaryDto> $TodoAnalysisSummaryDtoValidate(
  Object? json,
) => $TodoAnalysisSummaryDtoSchema.validateSchema(
  json,
  fromJson: TodoAnalysisSummaryDto.fromJson,
);

extension TodoAnalysisSummaryDtoValidationExtension on TodoAnalysisSummaryDto {
  ValidationResult<TodoAnalysisSummaryDto> validateSelf() =>
      $TodoAnalysisSummaryDtoValidate(_$luthorJsonMap(toJson()));
}

// ignore: constant_identifier_names
const TodoAnalysisSummaryDtoErrorKeys = (
  total: "total",
  completed: "completed",
  pending: "pending",
  completionRate: "completionRate",
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
