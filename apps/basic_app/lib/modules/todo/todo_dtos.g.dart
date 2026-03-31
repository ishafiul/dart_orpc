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

Validator $CreateTodoDtoSchema = l.withName('CreateTodoDto').schema({
  CreateTodoDtoSchemaKeys.title: l.string().min(1).required(),
});

SchemaValidationResult<CreateTodoDto> $CreateTodoDtoValidate(
  Map<String, dynamic> json,
) =>
    $CreateTodoDtoSchema.validateSchema(json, fromJson: CreateTodoDto.fromJson);

extension CreateTodoDtoValidationExtension on CreateTodoDto {
  SchemaValidationResult<CreateTodoDto> validateSelf() =>
      $CreateTodoDtoValidate(toJson());
}

// ignore: constant_identifier_names
const CreateTodoDtoErrorKeys = (title: "title");

// ignore: constant_identifier_names
const GetTodoDtoSchemaKeys = (id: "id");

Validator $GetTodoDtoSchema = l.withName('GetTodoDto').schema({
  GetTodoDtoSchemaKeys.id: l.int().required(),
});

SchemaValidationResult<GetTodoDto> $GetTodoDtoValidate(
  Map<String, dynamic> json,
) => $GetTodoDtoSchema.validateSchema(json, fromJson: GetTodoDto.fromJson);

extension GetTodoDtoValidationExtension on GetTodoDto {
  SchemaValidationResult<GetTodoDto> validateSelf() =>
      $GetTodoDtoValidate(toJson());
}

// ignore: constant_identifier_names
const GetTodoDtoErrorKeys = (id: "id");

// ignore: constant_identifier_names
const UpdateTodoDtoSchemaKeys = (
  id: "id",
  title: "title",
  completed: "completed",
);

Validator $UpdateTodoDtoSchema = l.withName('UpdateTodoDto').schema({
  UpdateTodoDtoSchemaKeys.id: l.int().required(),
  UpdateTodoDtoSchemaKeys.title: l.string(),
  UpdateTodoDtoSchemaKeys.completed: l.boolean(),
});

SchemaValidationResult<UpdateTodoDto> $UpdateTodoDtoValidate(
  Map<String, dynamic> json,
) =>
    $UpdateTodoDtoSchema.validateSchema(json, fromJson: UpdateTodoDto.fromJson);

extension UpdateTodoDtoValidationExtension on UpdateTodoDto {
  SchemaValidationResult<UpdateTodoDto> validateSelf() =>
      $UpdateTodoDtoValidate(toJson());
}

// ignore: constant_identifier_names
const UpdateTodoDtoErrorKeys = (
  id: "id",
  title: "title",
  completed: "completed",
);

// ignore: constant_identifier_names
const TodoMetadataDtoSchemaKeys = (priority: "priority", tags: "tags");

Validator $TodoMetadataDtoSchema = l.withName('TodoMetadataDto').schema({
  TodoMetadataDtoSchemaKeys.priority: l.string().required(),
  TodoMetadataDtoSchemaKeys.tags: l
      .list(validators: [l.string().required()])
      .required(),
});

SchemaValidationResult<TodoMetadataDto> $TodoMetadataDtoValidate(
  Map<String, dynamic> json,
) => $TodoMetadataDtoSchema.validateSchema(
  json,
  fromJson: TodoMetadataDto.fromJson,
);

extension TodoMetadataDtoValidationExtension on TodoMetadataDto {
  SchemaValidationResult<TodoMetadataDto> validateSelf() =>
      $TodoMetadataDtoValidate(toJson());
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

Validator $TodoResponseDtoSchema = l.withName('TodoResponseDto').schema({
  TodoResponseDtoSchemaKeys.id: l.int().required(),
  TodoResponseDtoSchemaKeys.title: l.string().min(1).required(),
  TodoResponseDtoSchemaKeys.completed: l.boolean().required(),
  TodoResponseDtoSchemaKeys.createdAt: l.string().dateTime().required(),
  TodoResponseDtoSchemaKeys.metadata: $TodoMetadataDtoSchema,
});

SchemaValidationResult<TodoResponseDto> $TodoResponseDtoValidate(
  Map<String, dynamic> json,
) => $TodoResponseDtoSchema.validateSchema(
  json,
  fromJson: TodoResponseDto.fromJson,
);

extension TodoResponseDtoValidationExtension on TodoResponseDto {
  SchemaValidationResult<TodoResponseDto> validateSelf() =>
      $TodoResponseDtoValidate(toJson());
}

// ignore: constant_identifier_names
const TodoResponseDtoErrorKeys = (
  id: "id",
  title: "title",
  completed: "completed",
  createdAt: "createdAt",
  metadata: (priority: "metadata.priority", tags: "metadata.tags"),
);

// ignore: constant_identifier_names
const TodoListResponseDtoSchemaKeys = (items: "items");

Validator $TodoListResponseDtoSchema = l.withName('TodoListResponseDto').schema(
  {
    TodoListResponseDtoSchemaKeys.items: l
        .list(validators: [$TodoResponseDtoSchema.required()])
        .required(),
  },
);

SchemaValidationResult<TodoListResponseDto> $TodoListResponseDtoValidate(
  Map<String, dynamic> json,
) => $TodoListResponseDtoSchema.validateSchema(
  json,
  fromJson: TodoListResponseDto.fromJson,
);

extension TodoListResponseDtoValidationExtension on TodoListResponseDto {
  SchemaValidationResult<TodoListResponseDto> validateSelf() =>
      $TodoListResponseDtoValidate(toJson());
}

// ignore: constant_identifier_names
const TodoListResponseDtoErrorKeys = (items: "items");

// ignore: constant_identifier_names
const DeleteTodoResponseDtoSchemaKeys = (deleted: "deleted");

Validator $DeleteTodoResponseDtoSchema = l
    .withName('DeleteTodoResponseDto')
    .schema({DeleteTodoResponseDtoSchemaKeys.deleted: l.boolean()});

SchemaValidationResult<DeleteTodoResponseDto> $DeleteTodoResponseDtoValidate(
  Map<String, dynamic> json,
) => $DeleteTodoResponseDtoSchema.validateSchema(
  json,
  fromJson: DeleteTodoResponseDto.fromJson,
);

extension DeleteTodoResponseDtoValidationExtension on DeleteTodoResponseDto {
  SchemaValidationResult<DeleteTodoResponseDto> validateSelf() =>
      $DeleteTodoResponseDtoValidate(toJson());
}

// ignore: constant_identifier_names
const DeleteTodoResponseDtoErrorKeys = (deleted: "deleted");
