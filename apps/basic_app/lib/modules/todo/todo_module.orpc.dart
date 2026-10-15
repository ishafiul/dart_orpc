// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// RpcModuleGenerator
// **************************************************************************

export 'package:basic_app/modules/todo/todo_dtos.dart';
export 'package:basic_app/modules/todo/todo_module.dart';

import 'package:basic_app/database/app_database.dart';
import 'package:basic_app/guard/jwt_auth_guard.dart';
import 'package:basic_app/guard/logger_guard.dart';
import 'package:basic_app/guard/permission_guard.dart';
import 'package:basic_app/modules/todo/todo_controller.dart';
import 'package:basic_app/modules/todo/todo_dtos.dart';
import 'package:basic_app/modules/todo/todo_module.dart';
import 'package:basic_app/modules/todo/todo_service.dart';
import 'package:dart_orpc/dart_orpc.dart';

class _$TodoModuleContainer {
  _$TodoModuleContainer({
    required this.appDatabase,
    required this.todoService,
    required this.basicAppJwtAuthGuard,
    required this.todoRouteLoggerGuard,
    required this.todoPermissionGuard,
    required this.todoController,
  });

  final AppDatabase appDatabase;

  final TodoService todoService;

  final BasicAppJwtAuthGuard basicAppJwtAuthGuard;

  final TodoRouteLoggerGuard todoRouteLoggerGuard;

  final TodoPermissionGuard todoPermissionGuard;

  final TodoController todoController;

  Future<void> dispose() => disposeRpcProviders([
    todoController,
    todoPermissionGuard,
    todoRouteLoggerGuard,
    basicAppJwtAuthGuard,
    todoService,
    appDatabase,
  ]);
}

_$TodoModuleContainer _$createTodoModuleContainer() {
  final appDatabase = AppDatabase();
  final todoService = TodoService(appDatabase);
  final basicAppJwtAuthGuard = BasicAppJwtAuthGuard();
  final todoRouteLoggerGuard = TodoRouteLoggerGuard();
  final todoPermissionGuard = TodoPermissionGuard();

  final todoController = TodoController(todoService);

  return _$TodoModuleContainer(
    appDatabase: appDatabase,
    todoService: todoService,
    basicAppJwtAuthGuard: basicAppJwtAuthGuard,
    todoRouteLoggerGuard: todoRouteLoggerGuard,
    todoPermissionGuard: todoPermissionGuard,
    todoController: todoController,
  );
}

// ignore: unused_element
RpcProcedureRegistry _$createTodoModuleLocalProcedureRegistry() {
  final container = _$createTodoModuleContainer();
  return _$createTodoModuleProcedureRegistryFromContainer(container);
}

RpcProcedureRegistry _$createTodoModuleProcedureRegistryFromContainer(
  _$TodoModuleContainer container,
) {
  final metadataRegistry = _$createTodoModuleLocalProcedureMetadataRegistry();
  return RpcProcedureRegistry([
    RpcUnaryProcedure<Null, TodoListResponseDto>(
      method: 'todo.list',
      decodeInput: (rawInput) =>
          expectNoRpcInput(rawInput, context: 'RPC method "todo.list"'),
      encodeOutput: (output) =>
          encodeRpcOutputJsonWithLuthor<TodoListResponseDto>(
            output: output,
            method: 'todo.list',
            toJson: (output) => output.toJson(),
            validateJson: (json) =>
                $TodoListResponseDtoSchema.validateSchema(json),
          ),
      metadata: metadataRegistry['todo.list']!,
      guards: [
        container.basicAppJwtAuthGuard,
        container.todoRouteLoggerGuard,
        container.todoPermissionGuard,
      ],

      handler: (context, input) => container.todoController.list(context),
    ),
    RpcStreamProcedure<Null, TodoResponseDto>(
      method: 'todo.watch',
      decodeInput: (rawInput) =>
          expectNoRpcInput(rawInput, context: 'RPC method "todo.watch"'),
      encodeOutput: (output) => encodeRpcOutputJsonWithLuthor<TodoResponseDto>(
        output: output,
        method: 'todo.watch',
        toJson: (output) => output.toJson(),
        validateJson: (json) => $TodoResponseDtoSchema.validateSchema(json),
      ),
      metadata: metadataRegistry['todo.watch']!,
      guards: [
        container.basicAppJwtAuthGuard,
        container.todoRouteLoggerGuard,
        container.todoPermissionGuard,
      ],

      handler: (context, input) => container.todoController.watch(context),
    ),
    RpcStreamProcedure<Null, TodoChangeResponseDto>(
      method: 'todo.watchLive',
      decodeInput: (rawInput) =>
          expectNoRpcInput(rawInput, context: 'RPC method "todo.watchLive"'),
      encodeOutput: (output) =>
          encodeRpcOutputJsonWithLuthor<TodoChangeResponseDto>(
            output: output,
            method: 'todo.watchLive',
            toJson: (output) => output.toJson(),
            validateJson: (json) =>
                $TodoChangeResponseDtoSchema.validateSchema(json),
          ),
      metadata: metadataRegistry['todo.watchLive']!,
      guards: [
        container.basicAppJwtAuthGuard,
        container.todoRouteLoggerGuard,
        container.todoPermissionGuard,
      ],

      handler: (context, input) => container.todoController.watchLive(context),
    ),
    RpcUnaryProcedure<GetTodoDto, TodoResponseDto>(
      method: 'todo.getById',
      decodeInput: (rawInput) => decodeRpcInputWithLuthor<GetTodoDto>(
        rawInput: rawInput,
        method: 'todo.getById',
        validate: $GetTodoDtoValidate,
        validateReadOnly: $GetTodoDtoValidate,
      ),
      encodeOutput: (output) => encodeRpcOutputJsonWithLuthor<TodoResponseDto>(
        output: output,
        method: 'todo.getById',
        toJson: (output) => output.toJson(),
        validateJson: (json) => $TodoResponseDtoSchema.validateSchema(json),
      ),
      metadata: metadataRegistry['todo.getById']!,
      guards: [
        container.basicAppJwtAuthGuard,
        container.todoRouteLoggerGuard,
        container.todoPermissionGuard,
      ],

      handler: (context, input) =>
          container.todoController.getById(context, input),
    ),
    RpcUnaryProcedure<CreateTodoDto, TodoResponseDto>(
      method: 'todo.create',
      decodeInput: (rawInput) => decodeRpcInputWithLuthor<CreateTodoDto>(
        rawInput: rawInput,
        method: 'todo.create',
        validate: $CreateTodoDtoValidate,
        validateReadOnly: $CreateTodoDtoValidate,
      ),
      encodeOutput: (output) => encodeRpcOutputJsonWithLuthor<TodoResponseDto>(
        output: output,
        method: 'todo.create',
        toJson: (output) => output.toJson(),
        validateJson: (json) => $TodoResponseDtoSchema.validateSchema(json),
      ),
      metadata: metadataRegistry['todo.create']!,
      guards: [
        container.basicAppJwtAuthGuard,
        container.todoRouteLoggerGuard,
        container.todoPermissionGuard,
      ],

      handler: (context, input) =>
          container.todoController.create(context, input),
    ),
    RpcUnaryProcedure<UpdateTodoDto, TodoResponseDto>(
      method: 'todo.update',
      decodeInput: (rawInput) => decodeRpcInputWithLuthor<UpdateTodoDto>(
        rawInput: rawInput,
        method: 'todo.update',
        validate: $UpdateTodoDtoValidate,
        validateReadOnly: $UpdateTodoDtoValidate,
      ),
      encodeOutput: (output) => encodeRpcOutputJsonWithLuthor<TodoResponseDto>(
        output: output,
        method: 'todo.update',
        toJson: (output) => output.toJson(),
        validateJson: (json) => $TodoResponseDtoSchema.validateSchema(json),
      ),
      metadata: metadataRegistry['todo.update']!,
      guards: [
        container.basicAppJwtAuthGuard,
        container.todoRouteLoggerGuard,
        container.todoPermissionGuard,
      ],

      handler: (context, input) =>
          container.todoController.update(context, input),
    ),
    RpcUnaryProcedure<GetTodoDto, DeleteTodoResponseDto>(
      method: 'todo.delete',
      decodeInput: (rawInput) => decodeRpcInputWithLuthor<GetTodoDto>(
        rawInput: rawInput,
        method: 'todo.delete',
        validate: $GetTodoDtoValidate,
        validateReadOnly: $GetTodoDtoValidate,
      ),
      encodeOutput: (output) =>
          encodeRpcOutputJsonWithLuthor<DeleteTodoResponseDto>(
            output: output,
            method: 'todo.delete',
            toJson: (output) => output.toJson(),
            validateJson: (json) =>
                $DeleteTodoResponseDtoSchema.validateSchema(json),
          ),
      metadata: metadataRegistry['todo.delete']!,
      guards: [
        container.basicAppJwtAuthGuard,
        container.todoRouteLoggerGuard,
        container.todoPermissionGuard,
      ],

      handler: (context, input) =>
          container.todoController.delete(context, input),
    ),
  ]);
}

RpcProcedureRegistry _$createTodoModuleProcedureRegistry() {
  return RpcProcedureRegistry([
    ..._$createTodoModuleLocalProcedureRegistry().procedures,
  ]);
}

RpcProcedureRegistry dartOrpcCreateTodoModuleProcedureRegistry() =>
    _$createTodoModuleProcedureRegistry();

({RpcProcedureRegistry procedures, RestRouteRegistry restRoutes})
_$createTodoModuleRuntime() {
  final container = _$createTodoModuleContainer();
  final localProcedures = _$createTodoModuleProcedureRegistryFromContainer(
    container,
  );
  final localRestRoutes = _$createTodoModuleRestRouteRegistryFromContainer(
    container,
  );

  return (
    procedures: RpcProcedureRegistry([...localProcedures.procedures]),
    restRoutes: RestRouteRegistry([...localRestRoutes.routes]),
  );
}

({RpcProcedureRegistry procedures, RestRouteRegistry restRoutes})
dartOrpcCreateTodoModuleRuntime() => _$createTodoModuleRuntime();

// ignore: unused_element
RestRouteRegistry _$createTodoModuleLocalRestRouteRegistry() {
  final container = _$createTodoModuleContainer();
  return _$createTodoModuleRestRouteRegistryFromContainer(container);
}

RestRouteRegistry _$createTodoModuleRestRouteRegistryFromContainer(
  _$TodoModuleContainer container,
) {
  final metadataRegistry = _$createTodoModuleLocalProcedureMetadataRegistry();
  return RestRouteRegistry([
    RestUnaryRoute(
      method: 'GET',
      path: '/todos',
      handler: (context, request, pathParameters) async {
        final output = await container.todoController.list(context);
        return ((output) => encodeRpcOutputJsonWithLuthor<TodoListResponseDto>(
          output: output,
          method: 'todo.list',
          toJson: (output) => output.toJson(),
          validateJson: (json) =>
              $TodoListResponseDtoSchema.validateSchema(json),
        ))(output);
      },
      metadata: metadataRegistry['todo.list']!,
      guards: [
        container.basicAppJwtAuthGuard,
        container.todoRouteLoggerGuard,
        container.todoPermissionGuard,
      ],
    ),
    RestStreamRoute(
      path: '/todos/events',
      handler: (context, request, pathParameters) {
        final output = container.todoController.watch(context);
        return output.map(
          (output) => encodeRpcOutputJsonWithLuthor<TodoResponseDto>(
            output: output,
            method: 'todo.watch',
            toJson: (output) => output.toJson(),
            validateJson: (json) => $TodoResponseDtoSchema.validateSchema(json),
          ),
        );
      },
      metadata: metadataRegistry['todo.watch']!,
      guards: [
        container.basicAppJwtAuthGuard,
        container.todoRouteLoggerGuard,
        container.todoPermissionGuard,
      ],
    ),
    RestStreamRoute(
      path: '/todos/live-events',
      handler: (context, request, pathParameters) {
        final output = container.todoController.watchLive(context);
        return output.map(
          (output) => encodeRpcOutputJsonWithLuthor<TodoChangeResponseDto>(
            output: output,
            method: 'todo.watchLive',
            toJson: (output) => output.toJson(),
            validateJson: (json) =>
                $TodoChangeResponseDtoSchema.validateSchema(json),
          ),
        );
      },
      metadata: metadataRegistry['todo.watchLive']!,
      guards: [
        container.basicAppJwtAuthGuard,
        container.todoRouteLoggerGuard,
        container.todoPermissionGuard,
      ],
    ),
    RestUnaryRoute(
      method: 'GET',
      path: '/todos/:id',
      handler: (context, request, pathParameters) async {
        final rawInput = <String, Object?>{};
        rawInput['id'] = decodeRestScalarParameter<int>(
          rawValue: pathParameters['id'],
          source: 'path parameter',
          name: 'id',
          route: 'GET /todos/:id',
        );
        final input = ((rawInput) => decodeRpcInputWithLuthor<GetTodoDto>(
          rawInput: rawInput,
          method: 'todo.getById',
          validate: $GetTodoDtoValidate,
          validateReadOnly: $GetTodoDtoValidate,
        ))(rawInput);
        final output = await container.todoController.getById(context, input);
        return ((output) => encodeRpcOutputJsonWithLuthor<TodoResponseDto>(
          output: output,
          method: 'todo.getById',
          toJson: (output) => output.toJson(),
          validateJson: (json) => $TodoResponseDtoSchema.validateSchema(json),
        ))(output);
      },
      metadata: metadataRegistry['todo.getById']!,
      guards: [
        container.basicAppJwtAuthGuard,
        container.todoRouteLoggerGuard,
        container.todoPermissionGuard,
      ],
    ),
    RestUnaryRoute(
      method: 'POST',
      path: '/todos',
      handler: (context, request, pathParameters) async {
        final rawInput = request.body.trim().isEmpty
            ? <String, Object?>{}
            : Map<String, Object?>.from(
                decodeRestBody<JsonObject>(
                  rawBody: request.body,
                  route: 'POST /todos',
                  parameterName: 'input',
                  decode: (rawJson) =>
                      expectJsonObject(rawJson, context: 'POST /todos body'),
                ),
              );
        final input = ((rawInput) => decodeRpcInputWithLuthor<CreateTodoDto>(
          rawInput: rawInput,
          method: 'todo.create',
          validate: $CreateTodoDtoValidate,
          validateReadOnly: $CreateTodoDtoValidate,
        ))(rawInput);
        final output = await container.todoController.create(context, input);
        return ((output) => encodeRpcOutputJsonWithLuthor<TodoResponseDto>(
          output: output,
          method: 'todo.create',
          toJson: (output) => output.toJson(),
          validateJson: (json) => $TodoResponseDtoSchema.validateSchema(json),
        ))(output);
      },
      metadata: metadataRegistry['todo.create']!,
      guards: [
        container.basicAppJwtAuthGuard,
        container.todoRouteLoggerGuard,
        container.todoPermissionGuard,
      ],
    ),
    RestUnaryRoute(
      method: 'PATCH',
      path: '/todos/:id',
      handler: (context, request, pathParameters) async {
        final rawInput = request.body.trim().isEmpty
            ? <String, Object?>{}
            : Map<String, Object?>.from(
                decodeRestBody<JsonObject>(
                  rawBody: request.body,
                  route: 'PATCH /todos/:id',
                  parameterName: 'input',
                  decode: (rawJson) => expectJsonObject(
                    rawJson,
                    context: 'PATCH /todos/:id body',
                  ),
                ),
              );
        rawInput['id'] = decodeRestScalarParameter<int>(
          rawValue: pathParameters['id'],
          source: 'path parameter',
          name: 'id',
          route: 'PATCH /todos/:id',
        );
        final input = ((rawInput) => decodeRpcInputWithLuthor<UpdateTodoDto>(
          rawInput: rawInput,
          method: 'todo.update',
          validate: $UpdateTodoDtoValidate,
          validateReadOnly: $UpdateTodoDtoValidate,
        ))(rawInput);
        final output = await container.todoController.update(context, input);
        return ((output) => encodeRpcOutputJsonWithLuthor<TodoResponseDto>(
          output: output,
          method: 'todo.update',
          toJson: (output) => output.toJson(),
          validateJson: (json) => $TodoResponseDtoSchema.validateSchema(json),
        ))(output);
      },
      metadata: metadataRegistry['todo.update']!,
      guards: [
        container.basicAppJwtAuthGuard,
        container.todoRouteLoggerGuard,
        container.todoPermissionGuard,
      ],
    ),
    RestUnaryRoute(
      method: 'DELETE',
      path: '/todos/:id',
      handler: (context, request, pathParameters) async {
        final rawInput = <String, Object?>{};
        rawInput['id'] = decodeRestScalarParameter<int>(
          rawValue: pathParameters['id'],
          source: 'path parameter',
          name: 'id',
          route: 'DELETE /todos/:id',
        );
        final input = ((rawInput) => decodeRpcInputWithLuthor<GetTodoDto>(
          rawInput: rawInput,
          method: 'todo.delete',
          validate: $GetTodoDtoValidate,
          validateReadOnly: $GetTodoDtoValidate,
        ))(rawInput);
        final output = await container.todoController.delete(context, input);
        return ((output) =>
            encodeRpcOutputJsonWithLuthor<DeleteTodoResponseDto>(
              output: output,
              method: 'todo.delete',
              toJson: (output) => output.toJson(),
              validateJson: (json) =>
                  $DeleteTodoResponseDtoSchema.validateSchema(json),
            ))(output);
      },
      metadata: metadataRegistry['todo.delete']!,
      guards: [
        container.basicAppJwtAuthGuard,
        container.todoRouteLoggerGuard,
        container.todoPermissionGuard,
      ],
    ),
  ]);
}

RestRouteRegistry _$createTodoModuleRestRouteRegistry() {
  return RestRouteRegistry([
    ..._$createTodoModuleLocalRestRouteRegistry().routes,
  ]);
}

RestRouteRegistry dartOrpcCreateTodoModuleRestRouteRegistry() =>
    _$createTodoModuleRestRouteRegistry();

// ignore: unused_element
ProcedureMetadataRegistry _$createTodoModuleLocalProcedureMetadataRegistry() {
  return ProcedureMetadataRegistry([
    const ProcedureMetadata(
      rpcMethod: 'todo.list',
      controllerNamespace: 'todo',
      methodName: 'list',
      path: RestProcedureMetadata(method: 'GET', path: '/todos'),
      outputTypeCode: 'TodoListResponseDto',
      description: 'List all todos.',
      tags: ['todo'],
      guardTypes: [
        'BasicAppJwtAuthGuard',
        'TodoRouteLoggerGuard',
        'TodoPermissionGuard',
      ],
      securityRequirements: [ProcedureSecurityRequirement('bearerAuth')],
      customMetadata: [
        ProcedureCustomMetadata(
          key: 'permissions',
          value: {
            'anyOf': ['todo.read', 'todo.admin'],
          },
        ),
      ],
    ),
    const ProcedureMetadata(
      rpcMethod: 'todo.watch',
      controllerNamespace: 'todo',
      methodName: 'watch',
      kind: RpcProcedureKind.serverStream,
      path: RestProcedureMetadata(
        method: 'GET',
        path: '/todos/events',
        responseKind: RestResponseKind.sse,
      ),
      outputTypeCode: 'TodoResponseDto',
      description: 'Stream the current todo snapshot as validated events.',
      tags: ['todo'],
      guardTypes: [
        'BasicAppJwtAuthGuard',
        'TodoRouteLoggerGuard',
        'TodoPermissionGuard',
      ],
      securityRequirements: [ProcedureSecurityRequirement('bearerAuth')],
      customMetadata: [
        ProcedureCustomMetadata(
          key: 'permissions',
          value: {
            'anyOf': ['todo.read', 'todo.admin'],
          },
        ),
      ],
    ),
    const ProcedureMetadata(
      rpcMethod: 'todo.watchLive',
      controllerNamespace: 'todo',
      methodName: 'watchLive',
      kind: RpcProcedureKind.serverStream,
      path: RestProcedureMetadata(
        method: 'GET',
        path: '/todos/live-events',
        responseKind: RestResponseKind.sse,
      ),
      outputTypeCode: 'TodoChangeResponseDto',
      description:
          'Stream todo create, update, and delete events as they happen.',
      tags: ['todo'],
      guardTypes: [
        'BasicAppJwtAuthGuard',
        'TodoRouteLoggerGuard',
        'TodoPermissionGuard',
      ],
      securityRequirements: [ProcedureSecurityRequirement('bearerAuth')],
      customMetadata: [
        ProcedureCustomMetadata(
          key: 'permissions',
          value: {
            'anyOf': ['todo.read', 'todo.admin'],
          },
        ),
      ],
    ),
    const ProcedureMetadata(
      rpcMethod: 'todo.getById',
      controllerNamespace: 'todo',
      methodName: 'getById',
      path: RestProcedureMetadata(method: 'GET', path: '/todos/:id'),
      inputTypeCode: 'GetTodoDto',
      outputTypeCode: 'TodoResponseDto',
      description: 'Get a single todo by id.',
      tags: ['todo'],
      guardTypes: [
        'BasicAppJwtAuthGuard',
        'TodoRouteLoggerGuard',
        'TodoPermissionGuard',
      ],
      securityRequirements: [ProcedureSecurityRequirement('bearerAuth')],
      customMetadata: [
        ProcedureCustomMetadata(
          key: 'permissions',
          value: {
            'anyOf': ['todo.read', 'todo.admin'],
          },
        ),
      ],
      parameters: [
        ProcedureParameterMetadata(
          parameterName: 'id',
          wireName: 'id',
          source: ProcedureParameterSourceKind.path,
          typeCode: 'int',
        ),
      ],
    ),
    const ProcedureMetadata(
      rpcMethod: 'todo.create',
      controllerNamespace: 'todo',
      methodName: 'create',
      path: RestProcedureMetadata(method: 'POST', path: '/todos'),
      inputTypeCode: 'CreateTodoDto',
      outputTypeCode: 'TodoResponseDto',
      description: 'Create a todo.',
      tags: ['todo'],
      guardTypes: [
        'BasicAppJwtAuthGuard',
        'TodoRouteLoggerGuard',
        'TodoPermissionGuard',
      ],
      securityRequirements: [ProcedureSecurityRequirement('bearerAuth')],
      customMetadata: [
        ProcedureCustomMetadata(
          key: 'permissions',
          value: {
            'allOf': ['tenant.active'],
          },
        ),
      ],
      parameters: [
        ProcedureParameterMetadata(
          parameterName: 'input',
          wireName: 'input',
          source: ProcedureParameterSourceKind.body,
          typeCode: 'CreateTodoDto',
        ),
      ],
    ),
    const ProcedureMetadata(
      rpcMethod: 'todo.update',
      controllerNamespace: 'todo',
      methodName: 'update',
      path: RestProcedureMetadata(method: 'PATCH', path: '/todos/:id'),
      inputTypeCode: 'UpdateTodoDto',
      outputTypeCode: 'TodoResponseDto',
      description: 'Update a todo.',
      tags: ['todo'],
      guardTypes: [
        'BasicAppJwtAuthGuard',
        'TodoRouteLoggerGuard',
        'TodoPermissionGuard',
      ],
      securityRequirements: [ProcedureSecurityRequirement('bearerAuth')],
      customMetadata: [
        ProcedureCustomMetadata(
          key: 'permissions',
          value: {
            'anyOf': ['todo.write', 'todo.admin'],
          },
        ),
      ],
      parameters: [
        ProcedureParameterMetadata(
          parameterName: 'id',
          wireName: 'id',
          source: ProcedureParameterSourceKind.path,
          typeCode: 'int',
        ),
        ProcedureParameterMetadata(
          parameterName: 'input',
          wireName: 'input',
          source: ProcedureParameterSourceKind.body,
          typeCode: 'UpdateTodoDto',
        ),
      ],
    ),
    const ProcedureMetadata(
      rpcMethod: 'todo.delete',
      controllerNamespace: 'todo',
      methodName: 'delete',
      path: RestProcedureMetadata(method: 'DELETE', path: '/todos/:id'),
      inputTypeCode: 'GetTodoDto',
      outputTypeCode: 'DeleteTodoResponseDto',
      description: 'Delete a todo.',
      tags: ['todo'],
      guardTypes: [
        'BasicAppJwtAuthGuard',
        'TodoRouteLoggerGuard',
        'TodoPermissionGuard',
      ],
      securityRequirements: [ProcedureSecurityRequirement('bearerAuth')],
      customMetadata: [
        ProcedureCustomMetadata(
          key: 'permissions',
          value: {
            'allOf': ['tenant.active'],
          },
        ),
      ],
      parameters: [
        ProcedureParameterMetadata(
          parameterName: 'id',
          wireName: 'id',
          source: ProcedureParameterSourceKind.path,
          typeCode: 'int',
        ),
      ],
    ),
  ]);
}

ProcedureMetadataRegistry _$createTodoModuleProcedureMetadataRegistry() {
  return ProcedureMetadataRegistry([
    ..._$createTodoModuleLocalProcedureMetadataRegistry().procedures,
  ]);
}

ProcedureMetadataRegistry dartOrpcCreateTodoModuleProcedureMetadataRegistry() =>
    _$createTodoModuleProcedureMetadataRegistry();

OpenApiSchemaRegistry _$createTodoModuleLocalOpenApiSchemaRegistry() {
  return OpenApiSchemaRegistry([
    OpenApiSchemaComponent(
      name: 'CreateTodoDto',
      validator: $CreateTodoDtoSchema,
    ),
    OpenApiSchemaComponent(
      name: 'DeleteTodoResponseDto',
      validator: $DeleteTodoResponseDtoSchema,
    ),
    OpenApiSchemaComponent(name: 'GetTodoDto', validator: $GetTodoDtoSchema),
    OpenApiSchemaComponent(
      name: 'TodoChangeResponseDto',
      validator: $TodoChangeResponseDtoSchema,
    ),
    OpenApiSchemaComponent(
      name: 'TodoListResponseDto',
      validator: $TodoListResponseDtoSchema,
    ),
    OpenApiSchemaComponent(
      name: 'TodoMetadataDto',
      validator: $TodoMetadataDtoSchema,
    ),
    OpenApiSchemaComponent(
      name: 'TodoResponseDto',
      validator: $TodoResponseDtoSchema,
    ),
    OpenApiSchemaComponent(
      name: 'UpdateTodoDto',
      validator: $UpdateTodoDtoSchema,
    ),
  ]);
}

OpenApiSchemaRegistry _$createTodoModuleOpenApiSchemaRegistry() {
  return OpenApiSchemaRegistry([
    ..._$createTodoModuleLocalOpenApiSchemaRegistry().components,
  ]);
}

OpenApiSchemaRegistry dartOrpcCreateTodoModuleOpenApiSchemaRegistry() =>
    _$createTodoModuleOpenApiSchemaRegistry();

JsonObject _$createTodoModuleOpenApiDocument({
  OpenApiDocumentOptions? options,
}) {
  final effectiveOptions = options ?? const OpenApiDocumentOptions();
  return createOpenApiDocument(
    title: effectiveOptions.title ?? 'Todo API',
    version: effectiveOptions.version,
    description: effectiveOptions.description,
    servers: effectiveOptions.servers,
    procedures: _$createTodoModuleProcedureMetadataRegistry(),
    schemas: _$createTodoModuleOpenApiSchemaRegistry(),
  );
}

JsonObject dartOrpcCreateTodoModuleOpenApiDocument({
  OpenApiDocumentOptions? options,
}) => _$createTodoModuleOpenApiDocument(options: options);

RpcHttpApp _$buildTodoModuleRpcApp({
  OpenApiDocumentOptions? openApi,
  RpcHttpDocsOptions? docs,
  RpcHttpStaticOptions? staticAssets,
  RpcHttpHealthOptions? health,
  RpcHttpMetricsOptions? metrics,
  RpcWebSocketServerOptions? webSocket,
  RpcContextBindings bindings = const RpcContextBindings.empty(),
  RpcContextFactory? contextFactory,
  Duration sseHeartbeatInterval = const Duration(seconds: 15),
  bool sseFlushEachChunk = true,
  bool encodeJsonToBytes = false,
  int? maxConcurrentRequests,
  Duration? requestBodyIdleTimeout,
  RpcHttpServerOptions serverOptions = const RpcHttpServerOptions(),
  Iterable<RpcHttpMiddleware> middleware = const [],
}) {
  final effectiveOpenApi = openApi ?? const OpenApiDocumentOptions();
  final effectiveDocs = docs ?? const RpcHttpDocsOptions();
  final effectiveOpenApiTitle = effectiveOpenApi.title ?? 'Todo API';
  final effectiveOpenApiPath = effectiveDocs.openApiPath;
  final container = _$createTodoModuleContainer();
  final procedures = _$createTodoModuleProcedureRegistryFromContainer(
    container,
  );
  final restRoutes = _$createTodoModuleRestRouteRegistryFromContainer(
    container,
  );
  return RpcHttpApp(
    procedures: procedures,
    restRoutes: restRoutes,
    onClose: container.dispose,
    openApiDocument: _$createTodoModuleOpenApiDocument(
      options: effectiveOpenApi,
    ),
    openApiPath: effectiveOpenApiPath,
    docsHtml:
        effectiveDocs.html ??
        createScalarHtml(
          title: effectiveDocs.title ?? effectiveOpenApiTitle,
          openApiPath: effectiveOpenApiPath,
        ),
    docsPath: effectiveDocs.docsPath,
    docsBasicAuth: effectiveDocs.basicAuth,
    staticAssets: staticAssets,
    health: health,
    metrics: metrics,
    bindings: bindings,
    contextFactory: contextFactory,
    sseHeartbeatInterval: sseHeartbeatInterval,
    sseFlushEachChunk: sseFlushEachChunk,
    encodeJsonToBytes: encodeJsonToBytes,
    maxConcurrentRequests: maxConcurrentRequests,
    requestBodyIdleTimeout: requestBodyIdleTimeout,
    serverOptions: serverOptions,
    upgradeHandlers: [
      if (webSocket != null)
        RpcWebSocketUpgradeHandler(procedures: procedures, options: webSocket),
    ],
    middleware: middleware,
  );
}

RpcHttpApp dartOrpcBuildTodoModuleRpcApp({
  OpenApiDocumentOptions? openApi,
  RpcHttpDocsOptions? docs,
  RpcHttpStaticOptions? staticAssets,
  RpcHttpHealthOptions? health,
  RpcHttpMetricsOptions? metrics,
  RpcWebSocketServerOptions? webSocket,
  RpcContextFactory? contextFactory,
  RpcContextBindings bindings = const RpcContextBindings.empty(),
  Duration sseHeartbeatInterval = const Duration(seconds: 15),
  bool sseFlushEachChunk = true,
  bool encodeJsonToBytes = false,
  int? maxConcurrentRequests,
  Duration? requestBodyIdleTimeout,
  RpcHttpServerOptions serverOptions = const RpcHttpServerOptions(),
  Iterable<RpcHttpMiddleware> middleware = const [],
}) => _$buildTodoModuleRpcApp(
  openApi: openApi,
  docs: docs,
  staticAssets: staticAssets,
  health: health,
  metrics: metrics,
  webSocket: webSocket,
  bindings: bindings,
  contextFactory: contextFactory,
  sseHeartbeatInterval: sseHeartbeatInterval,
  sseFlushEachChunk: sseFlushEachChunk,
  encodeJsonToBytes: encodeJsonToBytes,
  maxConcurrentRequests: maxConcurrentRequests,
  requestBodyIdleTimeout: requestBodyIdleTimeout,
  serverOptions: serverOptions,
  middleware: middleware,
);

class TodoClientRoot {
  TodoClientRoot({required RpcClientTransports transports})
    : _transports = transports;

  final RpcClientTransports _transports;

  late final todo = TodoClient(_transports);
}

class TodoClient {
  TodoClient(this._transports);

  final RpcClientTransports _transports;

  Future<TodoListResponseDto> list({RpcCallOptions? options}) {
    return RpcCaller(
      _transports.requireUnary('todo.list'),
    ).call<TodoListResponseDto>(
      method: 'todo.list',
      options: options,
      decode: (json) => TodoListResponseDto.fromJson(
        Map<String, dynamic>.from(
          expectJsonObject(json, context: 'RPC response for "todo.list"'),
        ),
      ),
    );
  }

  Stream<TodoResponseDto> watch({RpcCallOptions? options}) {
    return RpcStreamCaller(
      _transports.requireStreaming('todo.watch'),
    ).call<TodoResponseDto>(
      method: 'todo.watch',
      options: options,
      decode: (json) => TodoResponseDto.fromJson(
        Map<String, dynamic>.from(
          expectJsonObject(json, context: 'RPC response for "todo.watch"'),
        ),
      ),
    );
  }

  Stream<TodoChangeResponseDto> watchLive({RpcCallOptions? options}) {
    return RpcStreamCaller(
      _transports.requireStreaming('todo.watchLive'),
    ).call<TodoChangeResponseDto>(
      method: 'todo.watchLive',
      options: options,
      decode: (json) => TodoChangeResponseDto.fromJson(
        Map<String, dynamic>.from(
          expectJsonObject(json, context: 'RPC response for "todo.watchLive"'),
        ),
      ),
    );
  }

  Future<TodoResponseDto> getById(GetTodoDto input, {RpcCallOptions? options}) {
    return RpcCaller(
      _transports.requireUnary('todo.getById'),
    ).call<TodoResponseDto>(
      method: 'todo.getById',
      input: input.toJson(),
      options: options,
      decode: (json) => TodoResponseDto.fromJson(
        Map<String, dynamic>.from(
          expectJsonObject(json, context: 'RPC response for "todo.getById"'),
        ),
      ),
    );
  }

  Future<TodoResponseDto> create(
    CreateTodoDto input, {
    RpcCallOptions? options,
  }) {
    return RpcCaller(
      _transports.requireUnary('todo.create'),
    ).call<TodoResponseDto>(
      method: 'todo.create',
      input: input.toJson(),
      options: options,
      decode: (json) => TodoResponseDto.fromJson(
        Map<String, dynamic>.from(
          expectJsonObject(json, context: 'RPC response for "todo.create"'),
        ),
      ),
    );
  }

  Future<TodoResponseDto> update(
    UpdateTodoDto input, {
    RpcCallOptions? options,
  }) {
    return RpcCaller(
      _transports.requireUnary('todo.update'),
    ).call<TodoResponseDto>(
      method: 'todo.update',
      input: input.toJson(),
      options: options,
      decode: (json) => TodoResponseDto.fromJson(
        Map<String, dynamic>.from(
          expectJsonObject(json, context: 'RPC response for "todo.update"'),
        ),
      ),
    );
  }

  Future<DeleteTodoResponseDto> delete(
    GetTodoDto input, {
    RpcCallOptions? options,
  }) {
    return RpcCaller(
      _transports.requireUnary('todo.delete'),
    ).call<DeleteTodoResponseDto>(
      method: 'todo.delete',
      input: input.toJson(),
      options: options,
      decode: (json) => DeleteTodoResponseDto.fromJson(
        Map<String, dynamic>.from(
          expectJsonObject(json, context: 'RPC response for "todo.delete"'),
        ),
      ),
    );
  }
}

extension DartOrpcTodoModuleGenerated on TodoModule {
  RpcProcedureRegistry procedureRegistry() =>
      dartOrpcCreateTodoModuleProcedureRegistry();
  RestRouteRegistry restRouteRegistry() =>
      dartOrpcCreateTodoModuleRestRouteRegistry();
  ProcedureMetadataRegistry procedureMetadata() =>
      dartOrpcCreateTodoModuleProcedureMetadataRegistry();
  OpenApiSchemaRegistry openApiSchemaRegistry() =>
      dartOrpcCreateTodoModuleOpenApiSchemaRegistry();
  JsonObject openApiDocument({OpenApiDocumentOptions? options}) =>
      dartOrpcCreateTodoModuleOpenApiDocument(options: options);
  RpcHttpApp buildRpcApp({
    OpenApiDocumentOptions? openApi,
    RpcHttpDocsOptions? docs,
    RpcHttpStaticOptions? staticAssets,
    RpcHttpHealthOptions? health,
    RpcHttpMetricsOptions? metrics,
    RpcWebSocketServerOptions? webSocket,
    RpcContextBindings bindings = const RpcContextBindings.empty(),
    RpcContextFactory? contextFactory,
    Duration sseHeartbeatInterval = const Duration(seconds: 15),
    bool sseFlushEachChunk = true,
    bool encodeJsonToBytes = false,
    int? maxConcurrentRequests,
    Duration? requestBodyIdleTimeout,
    RpcHttpServerOptions serverOptions = const RpcHttpServerOptions(),
    Iterable<RpcHttpMiddleware> middleware = const [],
  }) => dartOrpcBuildTodoModuleRpcApp(
    openApi: openApi,
    docs: docs,
    staticAssets: staticAssets,
    health: health,
    metrics: metrics,
    webSocket: webSocket,
    bindings: bindings,
    contextFactory: contextFactory,
    sseHeartbeatInterval: sseHeartbeatInterval,
    sseFlushEachChunk: sseFlushEachChunk,
    encodeJsonToBytes: encodeJsonToBytes,
    maxConcurrentRequests: maxConcurrentRequests,
    requestBodyIdleTimeout: requestBodyIdleTimeout,
    serverOptions: serverOptions,
    middleware: middleware,
  );
  TodoClientRoot createClient({required RpcClientTransports transports}) =>
      TodoClientRoot(transports: transports);
}
