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

Validator $TodoAnalysisSummaryDtoSchema = l
    .withName('TodoAnalysisSummaryDto')
    .schema({
      TodoAnalysisSummaryDtoSchemaKeys.total: l.int().required(),
      TodoAnalysisSummaryDtoSchemaKeys.completed: l.int().required(),
      TodoAnalysisSummaryDtoSchemaKeys.pending: l.int().required(),
      TodoAnalysisSummaryDtoSchemaKeys.completionRate: l.double().required(),
    });

SchemaValidationResult<TodoAnalysisSummaryDto> $TodoAnalysisSummaryDtoValidate(
  Map<String, dynamic> json,
) => $TodoAnalysisSummaryDtoSchema.validateSchema(
  json,
  fromJson: TodoAnalysisSummaryDto.fromJson,
);

extension TodoAnalysisSummaryDtoValidationExtension on TodoAnalysisSummaryDto {
  SchemaValidationResult<TodoAnalysisSummaryDto> validateSelf() =>
      $TodoAnalysisSummaryDtoValidate(toJson());
}

// ignore: constant_identifier_names
const TodoAnalysisSummaryDtoErrorKeys = (
  total: "total",
  completed: "completed",
  pending: "pending",
  completionRate: "completionRate",
);
