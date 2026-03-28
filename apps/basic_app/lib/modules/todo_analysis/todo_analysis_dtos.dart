import 'package:dart_orpc/dart_orpc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'todo_analysis_dtos.freezed.dart';
part 'todo_analysis_dtos.g.dart';

@luthor
@freezed
abstract class TodoAnalysisSummaryDto with _$TodoAnalysisSummaryDto {
  const factory TodoAnalysisSummaryDto({
    required int total,
    required int completed,
    required int pending,
    required double completionRate,
  }) = _TodoAnalysisSummaryDto;

  factory TodoAnalysisSummaryDto.fromJson(Map<String, dynamic> json) =>
      _$TodoAnalysisSummaryDtoFromJson(json);
}
