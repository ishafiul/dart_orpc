import 'package:dart_orpc/dart_orpc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'todo_dtos.freezed.dart';
part 'todo_dtos.g.dart';

@luthor
@freezed
abstract class CreateTodoDto with _$CreateTodoDto {
  const factory CreateTodoDto({@HasMin(1) required String title}) =
      _CreateTodoDto;

  factory CreateTodoDto.fromJson(Map<String, dynamic> json) =>
      _$CreateTodoDtoFromJson(json);
}

@luthor
@freezed
abstract class GetTodoDto with _$GetTodoDto {
  const factory GetTodoDto({@FromPath() required int id}) = _GetTodoDto;

  factory GetTodoDto.fromJson(Map<String, dynamic> json) =>
      _$GetTodoDtoFromJson(json);
}

@luthor
@freezed
abstract class UpdateTodoDto with _$UpdateTodoDto {
  const factory UpdateTodoDto({
    @FromPath() required int id,
    @JsonKey(includeIfNull: false) String? title,
    @JsonKey(includeIfNull: false) bool? completed,
  }) = _UpdateTodoDto;

  factory UpdateTodoDto.fromJson(Map<String, dynamic> json) =>
      _$UpdateTodoDtoFromJson(json);
}

@luthor
@freezed
abstract class TodoMetadataDto with _$TodoMetadataDto {
  const factory TodoMetadataDto({
    required String priority,
    required List<String> tags,
  }) = _TodoMetadataDto;

  factory TodoMetadataDto.fromJson(Map<String, dynamic> json) =>
      _$TodoMetadataDtoFromJson(json);
}

@luthor
@freezed
abstract class TodoResponseDto with _$TodoResponseDto {
  const factory TodoResponseDto({
    required int id,
    @HasMin(1) required String title,
    required bool completed,
    required DateTime createdAt,
    TodoMetadataDto? metadata,
  }) = _TodoResponseDto;

  factory TodoResponseDto.fromJson(Map<String, dynamic> json) =>
      _$TodoResponseDtoFromJson(json);
}

@luthor
@freezed
abstract class TodoListResponseDto with _$TodoListResponseDto {
  const factory TodoListResponseDto({required List<TodoResponseDto> items}) =
      _TodoListResponseDto;

  factory TodoListResponseDto.fromJson(Map<String, dynamic> json) =>
      _$TodoListResponseDtoFromJson(json);
}

@luthor
@freezed
abstract class DeleteTodoResponseDto with _$DeleteTodoResponseDto {
  const factory DeleteTodoResponseDto({@Default(true) bool deleted}) =
      _DeleteTodoResponseDto;

  factory DeleteTodoResponseDto.fromJson(Map<String, dynamic> json) =>
      _$DeleteTodoResponseDtoFromJson(json);
}
