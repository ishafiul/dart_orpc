// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'todo_dtos.dart';

// **************************************************************************
// RpcDtoFieldRefGenerator
// **************************************************************************

abstract final class CreateTodoDtoFields {
  static const title = RpcInputField<CreateTodoDto>('title');
}

abstract final class GetTodoDtoFields {
  static const id = RpcInputField<GetTodoDto>('id');
}

abstract final class UpdateTodoDtoFields {
  static const completed = RpcInputField<UpdateTodoDto>('completed');
  static const id = RpcInputField<UpdateTodoDto>('id');
  static const title = RpcInputField<UpdateTodoDto>('title');
}

abstract final class TodoMetadataDtoFields {
  static const priority = RpcInputField<TodoMetadataDto>('priority');
  static const tags = RpcInputField<TodoMetadataDto>('tags');
}

abstract final class TodoResponseDtoFields {
  static const completed = RpcInputField<TodoResponseDto>('completed');
  static const createdAt = RpcInputField<TodoResponseDto>('createdAt');
  static const id = RpcInputField<TodoResponseDto>('id');
  static const metadata = RpcInputField<TodoResponseDto>('metadata');
  static const title = RpcInputField<TodoResponseDto>('title');
}

abstract final class TodoChangeResponseDtoFields {
  static const todo = RpcInputField<TodoChangeResponseDto>('todo');
  static const type = RpcInputField<TodoChangeResponseDto>('type');
}

abstract final class TodoListResponseDtoFields {
  static const items = RpcInputField<TodoListResponseDto>('items');
}

abstract final class DeleteTodoResponseDtoFields {
  static const deleted = RpcInputField<DeleteTodoResponseDto>('deleted');
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CreateTodoDto _$CreateTodoDtoFromJson(Map<String, dynamic> json) =>
    _CreateTodoDto(title: json['title'] as String);

Map<String, dynamic> _$CreateTodoDtoToJson(_CreateTodoDto instance) =>
    <String, dynamic>{'title': instance.title};

_GetTodoDto _$GetTodoDtoFromJson(Map<String, dynamic> json) =>
    _GetTodoDto(id: (json['id'] as num).toInt());

Map<String, dynamic> _$GetTodoDtoToJson(_GetTodoDto instance) =>
    <String, dynamic>{'id': instance.id};

_UpdateTodoDto _$UpdateTodoDtoFromJson(Map<String, dynamic> json) =>
    _UpdateTodoDto(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String?,
      completed: json['completed'] as bool?,
    );

Map<String, dynamic> _$UpdateTodoDtoToJson(_UpdateTodoDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': ?instance.title,
      'completed': ?instance.completed,
    };

_TodoMetadataDto _$TodoMetadataDtoFromJson(Map<String, dynamic> json) =>
    _TodoMetadataDto(
      priority: json['priority'] as String,
      tags: (json['tags'] as List<dynamic>).map((e) => e as String).toList(),
    );

Map<String, dynamic> _$TodoMetadataDtoToJson(_TodoMetadataDto instance) =>
    <String, dynamic>{'priority': instance.priority, 'tags': instance.tags};

_TodoResponseDto _$TodoResponseDtoFromJson(Map<String, dynamic> json) =>
    _TodoResponseDto(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String,
      completed: json['completed'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      metadata: json['metadata'] == null
          ? null
          : TodoMetadataDto.fromJson(json['metadata'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$TodoResponseDtoToJson(_TodoResponseDto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'completed': instance.completed,
      'createdAt': instance.createdAt.toIso8601String(),
      'metadata': instance.metadata,
    };

_TodoChangeResponseDto _$TodoChangeResponseDtoFromJson(
  Map<String, dynamic> json,
) => _TodoChangeResponseDto(
  type: json['type'] as String,
  todo: TodoResponseDto.fromJson(json['todo'] as Map<String, dynamic>),
);

Map<String, dynamic> _$TodoChangeResponseDtoToJson(
  _TodoChangeResponseDto instance,
) => <String, dynamic>{'type': instance.type, 'todo': instance.todo};

_TodoListResponseDto _$TodoListResponseDtoFromJson(Map<String, dynamic> json) =>
    _TodoListResponseDto(
      items: (json['items'] as List<dynamic>)
          .map((e) => TodoResponseDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$TodoListResponseDtoToJson(
  _TodoListResponseDto instance,
) => <String, dynamic>{'items': instance.items};

_DeleteTodoResponseDto _$DeleteTodoResponseDtoFromJson(
  Map<String, dynamic> json,
) => _DeleteTodoResponseDto(deleted: json['deleted'] as bool? ?? true);

Map<String, dynamic> _$DeleteTodoResponseDtoToJson(
  _DeleteTodoResponseDto instance,
) => <String, dynamic>{'deleted': instance.deleted};

// **************************************************************************
// LuthorGenerator
// **************************************************************************

// ignore: constant_identifier_names
const CreateTodoDtoSchemaKeys = (title: "title");

final SchemaValidator $CreateTodoDtoSchema = l
    .schema({CreateTodoDtoSchemaKeys.title: l.string().min(1).required()})
    .strict()
    .withName("CreateTodoDto");

ValidationResult<CreateTodoDto> $CreateTodoDtoValidate(Object? json) =>
    $CreateTodoDtoSchema.validateSchema(json, fromJson: CreateTodoDto.fromJson);

extension CreateTodoDtoValidationExtension on CreateTodoDto {
  ValidationResult<CreateTodoDto> validateSelf() =>
      $CreateTodoDtoValidate(_$luthorJsonMap(toJson()));
}

// ignore: constant_identifier_names
const CreateTodoDtoErrorKeys = (title: "title");

// ignore: constant_identifier_names
const GetTodoDtoSchemaKeys = (id: "id");

final SchemaValidator $GetTodoDtoSchema = l
    .schema({GetTodoDtoSchemaKeys.id: l.int().required()})
    .strict()
    .withName("GetTodoDto");

ValidationResult<GetTodoDto> $GetTodoDtoValidate(Object? json) =>
    $GetTodoDtoSchema.validateSchema(json, fromJson: GetTodoDto.fromJson);

extension GetTodoDtoValidationExtension on GetTodoDto {
  ValidationResult<GetTodoDto> validateSelf() =>
      $GetTodoDtoValidate(_$luthorJsonMap(toJson()));
}

// ignore: constant_identifier_names
const GetTodoDtoErrorKeys = (id: "id");

// ignore: constant_identifier_names
const UpdateTodoDtoSchemaKeys = (
  id: "id",
  title: "title",
  completed: "completed",
);

final SchemaValidator $UpdateTodoDtoSchema = l
    .schema({
      UpdateTodoDtoSchemaKeys.id: l.int().required(),
      UpdateTodoDtoSchemaKeys.title: l.string(),
      UpdateTodoDtoSchemaKeys.completed: l.bool(),
    })
    .strict()
    .withName("UpdateTodoDto");

ValidationResult<UpdateTodoDto> $UpdateTodoDtoValidate(Object? json) =>
    $UpdateTodoDtoSchema.validateSchema(json, fromJson: UpdateTodoDto.fromJson);

extension UpdateTodoDtoValidationExtension on UpdateTodoDto {
  ValidationResult<UpdateTodoDto> validateSelf() =>
      $UpdateTodoDtoValidate(_$luthorJsonMap(toJson()));
}

// ignore: constant_identifier_names
const UpdateTodoDtoErrorKeys = (
  id: "id",
  title: "title",
  completed: "completed",
);

// ignore: constant_identifier_names
const TodoMetadataDtoSchemaKeys = (priority: "priority", tags: "tags");

final SchemaValidator $TodoMetadataDtoSchema = l
    .schema({
      TodoMetadataDtoSchemaKeys.priority: l.string().required(),
      TodoMetadataDtoSchemaKeys.tags: l.list(l.string().required()).required(),
    })
    .withName("TodoMetadataDto");

ValidationResult<TodoMetadataDto> $TodoMetadataDtoValidate(Object? json) =>
    $TodoMetadataDtoSchema.validateSchema(
      json,
      fromJson: TodoMetadataDto.fromJson,
    );

extension TodoMetadataDtoValidationExtension on TodoMetadataDto {
  ValidationResult<TodoMetadataDto> validateSelf() =>
      $TodoMetadataDtoValidate(_$luthorJsonMap(toJson()));
}

// ignore: constant_identifier_names
const TodoMetadataDtoErrorKeys = (priority: "priority", tags: "tags");

// ignore: constant_identifier_names
const TodoResponseDtoSchemaKeys = (
  id: "id",
  title: "title",
  completed: "completed",
  createdAt: "createdAt",
  metadata: "metadata",
);

final SchemaValidator $TodoResponseDtoSchema = l
    .schema({
      TodoResponseDtoSchemaKeys.id: l.int().required(),
      TodoResponseDtoSchemaKeys.title: l.string().min(1).required(),
      TodoResponseDtoSchemaKeys.completed: l.bool().required(),
      TodoResponseDtoSchemaKeys.createdAt: l.string().dateTime().required(),
      TodoResponseDtoSchemaKeys.metadata: forwardRef(
        () => $TodoMetadataDtoSchema,
      ),
    })
    .withName("TodoResponseDto");

ValidationResult<TodoResponseDto> $TodoResponseDtoValidate(Object? json) =>
    $TodoResponseDtoSchema.validateSchema(
      json,
      fromJson: TodoResponseDto.fromJson,
    );

extension TodoResponseDtoValidationExtension on TodoResponseDto {
  ValidationResult<TodoResponseDto> validateSelf() =>
      $TodoResponseDtoValidate(_$luthorJsonMap(toJson()));
}

// ignore: constant_identifier_names
const TodoResponseDtoErrorKeys = (
  id: "id",
  title: "title",
  completed: "completed",
  createdAt: "createdAt",
  metadata: (
    $key: "metadata",
    priority: "metadata.priority",
    tags: "metadata.tags",
  ),
);

// ignore: constant_identifier_names
const TodoChangeResponseDtoSchemaKeys = (type: "type", todo: "todo");

final SchemaValidator $TodoChangeResponseDtoSchema = l
    .schema({
      TodoChangeResponseDtoSchemaKeys.type: l.string().required(),
      TodoChangeResponseDtoSchemaKeys.todo: forwardRef(
        () => $TodoResponseDtoSchema.required(),
      ),
    })
    .withName("TodoChangeResponseDto");

ValidationResult<TodoChangeResponseDto> $TodoChangeResponseDtoValidate(
  Object? json,
) => $TodoChangeResponseDtoSchema.validateSchema(
  json,
  fromJson: TodoChangeResponseDto.fromJson,
);

extension TodoChangeResponseDtoValidationExtension on TodoChangeResponseDto {
  ValidationResult<TodoChangeResponseDto> validateSelf() =>
      $TodoChangeResponseDtoValidate(_$luthorJsonMap(toJson()));
}

// ignore: constant_identifier_names
const TodoChangeResponseDtoErrorKeys = (
  type: "type",
  todo: (
    $key: "todo",
    id: "todo.id",
    title: "todo.title",
    completed: "todo.completed",
    createdAt: "todo.createdAt",
    metadata: (
      $key: "todo.metadata",
      priority: "todo.metadata.priority",
      tags: "todo.metadata.tags",
    ),
  ),
);

// ignore: constant_identifier_names
const TodoListResponseDtoSchemaKeys = (items: "items");

final SchemaValidator $TodoListResponseDtoSchema = l
    .schema({
      TodoListResponseDtoSchemaKeys.items: l
          .list(forwardRef(() => $TodoResponseDtoSchema.required()))
          .required(),
    })
    .withName("TodoListResponseDto");

ValidationResult<TodoListResponseDto> $TodoListResponseDtoValidate(
  Object? json,
) => $TodoListResponseDtoSchema.validateSchema(
  json,
  fromJson: TodoListResponseDto.fromJson,
);

extension TodoListResponseDtoValidationExtension on TodoListResponseDto {
  ValidationResult<TodoListResponseDto> validateSelf() =>
      $TodoListResponseDtoValidate(_$luthorJsonMap(toJson()));
}

// ignore: constant_identifier_names
const TodoListResponseDtoErrorKeys = (items: "items");

// ignore: constant_identifier_names
const DeleteTodoResponseDtoSchemaKeys = (deleted: "deleted");

final SchemaValidator $DeleteTodoResponseDtoSchema = l
    .schema({DeleteTodoResponseDtoSchemaKeys.deleted: l.bool()})
    .withName("DeleteTodoResponseDto");

ValidationResult<DeleteTodoResponseDto> $DeleteTodoResponseDtoValidate(
  Object? json,
) => $DeleteTodoResponseDtoSchema.validateSchema(
  json,
  fromJson: DeleteTodoResponseDto.fromJson,
);

extension DeleteTodoResponseDtoValidationExtension on DeleteTodoResponseDto {
  ValidationResult<DeleteTodoResponseDto> validateSelf() =>
      $DeleteTodoResponseDtoValidate(_$luthorJsonMap(toJson()));
}

// ignore: constant_identifier_names
const DeleteTodoResponseDtoErrorKeys = (deleted: "deleted");

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
