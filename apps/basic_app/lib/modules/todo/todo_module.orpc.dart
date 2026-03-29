// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// RpcModuleGenerator
// **************************************************************************

export 'package:basic_app/modules/todo/todo_dtos.dart';
export 'package:basic_app/modules/todo/todo_module.dart';

import 'package:basic_app/database/app_database.dart';
import 'package:basic_app/modules/todo/todo_controller.dart';
import 'package:basic_app/modules/todo/todo_dtos.dart';
import 'package:basic_app/modules/todo/todo_module.dart';
import 'package:basic_app/modules/todo/todo_route_logger_guard.dart';
import 'package:basic_app/modules/todo/todo_service.dart';
import 'package:dart_orpc/dart_orpc.dart';

class _$TodoModuleContainer {
  _$TodoModuleContainer({
    required this.appDatabase,
    required this.todoService,
    required this.todoRouteLoggerGuard,
    required this.todoController,
  });

  final AppDatabase appDatabase;

  final TodoService todoService;

  final TodoRouteLoggerGuard todoRouteLoggerGuard;

  final TodoController todoController;
}

_$TodoModuleContainer _$createTodoModuleContainer() {
  final appDatabase = AppDatabase();
  final todoService = TodoService(appDatabase);
  final todoRouteLoggerGuard = TodoRouteLoggerGuard();

  final todoController = TodoController(todoService);

  return _$TodoModuleContainer(
    appDatabase: appDatabase,
    todoService: todoService,
    todoRouteLoggerGuard: todoRouteLoggerGuard,
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
    RpcProcedure<Null, TodoListResponseDto>(
      method: 'todo.list',
      decodeInput: (rawInput) =>
          expectNoRpcInput(rawInput, context: 'RPC method "todo.list"'),
      encodeOutput: (output) => encodeRpcOutputWithLuthor<TodoListResponseDto>(
        output: output,
        method: 'todo.list',
        toJson: (output) => output.toJson(),
        validate: $TodoListResponseDtoValidate,
      ),
      beforeInvoke: (context, input) => runRpcGuards(
        [container.todoRouteLoggerGuard],
        rpcContext: context,
        procedure: metadataRegistry['todo.list']!,
        input: input,
      ),
      handler: (context, input) => container.todoController.list(context),
    ),
    RpcProcedure<GetTodoDto, TodoResponseDto>(
      method: 'todo.getById',
      decodeInput: (rawInput) => decodeRpcInputWithLuthor<GetTodoDto>(
        rawInput: rawInput,
        method: 'todo.getById',
        validate: $GetTodoDtoValidate,
      ),
      encodeOutput: (output) => encodeRpcOutputWithLuthor<TodoResponseDto>(
        output: output,
        method: 'todo.getById',
        toJson: (output) => output.toJson(),
        validate: $TodoResponseDtoValidate,
      ),
      beforeInvoke: (context, input) => runRpcGuards(
        [container.todoRouteLoggerGuard],
        rpcContext: context,
        procedure: metadataRegistry['todo.getById']!,
        input: input,
      ),
      handler: (context, input) =>
          container.todoController.getById(context, input),
    ),
    RpcProcedure<CreateTodoDto, TodoResponseDto>(
      method: 'todo.create',
      decodeInput: (rawInput) => decodeRpcInputWithLuthor<CreateTodoDto>(
        rawInput: rawInput,
        method: 'todo.create',
        validate: $CreateTodoDtoValidate,
      ),
      encodeOutput: (output) => encodeRpcOutputWithLuthor<TodoResponseDto>(
        output: output,
        method: 'todo.create',
        toJson: (output) => output.toJson(),
        validate: $TodoResponseDtoValidate,
      ),
      beforeInvoke: (context, input) => runRpcGuards(
        [container.todoRouteLoggerGuard],
        rpcContext: context,
        procedure: metadataRegistry['todo.create']!,
        input: input,
      ),
      handler: (context, input) =>
          container.todoController.create(context, input),
    ),
    RpcProcedure<UpdateTodoDto, TodoResponseDto>(
      method: 'todo.update',
      decodeInput: (rawInput) => decodeRpcInputWithLuthor<UpdateTodoDto>(
        rawInput: rawInput,
        method: 'todo.update',
        validate: $UpdateTodoDtoValidate,
      ),
      encodeOutput: (output) => encodeRpcOutputWithLuthor<TodoResponseDto>(
        output: output,
        method: 'todo.update',
        toJson: (output) => output.toJson(),
        validate: $TodoResponseDtoValidate,
      ),
      beforeInvoke: (context, input) => runRpcGuards(
        [container.todoRouteLoggerGuard],
        rpcContext: context,
        procedure: metadataRegistry['todo.update']!,
        input: input,
      ),
      handler: (context, input) =>
          container.todoController.update(context, input),
    ),
    RpcProcedure<GetTodoDto, DeleteTodoResponseDto>(
      method: 'todo.delete',
      decodeInput: (rawInput) => decodeRpcInputWithLuthor<GetTodoDto>(
        rawInput: rawInput,
        method: 'todo.delete',
        validate: $GetTodoDtoValidate,
      ),
      encodeOutput: (output) =>
          encodeRpcOutputWithLuthor<DeleteTodoResponseDto>(
            output: output,
            method: 'todo.delete',
            toJson: (output) => output.toJson(),
            validate: $DeleteTodoResponseDtoValidate,
          ),
      beforeInvoke: (context, input) => runRpcGuards(
        [container.todoRouteLoggerGuard],
        rpcContext: context,
        procedure: metadataRegistry['todo.delete']!,
        input: input,
      ),
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
    RestRoute(
      method: 'GET',
      path: '/todos',
      handler: (context, request, pathParameters) async {
        await runRpcGuards(
          [container.todoRouteLoggerGuard],
          rpcContext: context,
          procedure: metadataRegistry['todo.list']!,
          input: null,
        );
        final output = await container.todoController.list(context);
        return ((output) => encodeRpcOutputWithLuthor<TodoListResponseDto>(
          output: output,
          method: 'todo.list',
          toJson: (output) => output.toJson(),
          validate: $TodoListResponseDtoValidate,
        ))(output);
      },
    ),
    RestRoute(
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
        ))(rawInput);
        await runRpcGuards(
          [container.todoRouteLoggerGuard],
          rpcContext: context,
          procedure: metadataRegistry['todo.getById']!,
          input: input,
        );
        final output = await container.todoController.getById(context, input);
        return ((output) => encodeRpcOutputWithLuthor<TodoResponseDto>(
          output: output,
          method: 'todo.getById',
          toJson: (output) => output.toJson(),
          validate: $TodoResponseDtoValidate,
        ))(output);
      },
    ),
    RestRoute(
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
        ))(rawInput);
        await runRpcGuards(
          [container.todoRouteLoggerGuard],
          rpcContext: context,
          procedure: metadataRegistry['todo.create']!,
          input: input,
        );
        final output = await container.todoController.create(context, input);
        return ((output) => encodeRpcOutputWithLuthor<TodoResponseDto>(
          output: output,
          method: 'todo.create',
          toJson: (output) => output.toJson(),
          validate: $TodoResponseDtoValidate,
        ))(output);
      },
    ),
    RestRoute(
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
        ))(rawInput);
        await runRpcGuards(
          [container.todoRouteLoggerGuard],
          rpcContext: context,
          procedure: metadataRegistry['todo.update']!,
          input: input,
        );
        final output = await container.todoController.update(context, input);
        return ((output) => encodeRpcOutputWithLuthor<TodoResponseDto>(
          output: output,
          method: 'todo.update',
          toJson: (output) => output.toJson(),
          validate: $TodoResponseDtoValidate,
        ))(output);
      },
    ),
    RestRoute(
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
        ))(rawInput);
        await runRpcGuards(
          [container.todoRouteLoggerGuard],
          rpcContext: context,
          procedure: metadataRegistry['todo.delete']!,
          input: input,
        );
        final output = await container.todoController.delete(context, input);
        return ((output) => encodeRpcOutputWithLuthor<DeleteTodoResponseDto>(
          output: output,
          method: 'todo.delete',
          toJson: (output) => output.toJson(),
          validate: $DeleteTodoResponseDtoValidate,
        ))(output);
      },
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
      guardTypes: ['TodoRouteLoggerGuard'],
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
      guardTypes: ['TodoRouteLoggerGuard'],
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
      guardTypes: ['TodoRouteLoggerGuard'],
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
      guardTypes: ['TodoRouteLoggerGuard'],
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
      guardTypes: ['TodoRouteLoggerGuard'],
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
      name: 'TodoListResponseDto',
      validator: $TodoListResponseDtoSchema,
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

// ignore: unused_element
RpcHttpApp _$buildTodoModuleRpcApp({
  OpenApiDocumentOptions? openApi,
  RpcHttpDocsOptions? docs,
  Iterable<RpcHttpMiddleware> middleware = const [],
}) {
  final effectiveOpenApi = openApi ?? const OpenApiDocumentOptions();
  final effectiveDocs = docs ?? const RpcHttpDocsOptions();
  final effectiveOpenApiTitle = effectiveOpenApi.title ?? 'Todo API';
  final effectiveOpenApiPath = effectiveDocs.openApiPath;
  return RpcHttpApp(
    procedures: _$createTodoModuleProcedureRegistry(),
    restRoutes: _$createTodoModuleRestRouteRegistry(),
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
    middleware: middleware,
  );
}

RpcHttpApp dartOrpcBuildTodoModuleRpcApp({
  OpenApiDocumentOptions? openApi,
  RpcHttpDocsOptions? docs,
  Iterable<RpcHttpMiddleware> middleware = const [],
}) => _$buildTodoModuleRpcApp(
  openApi: openApi,
  docs: docs,
  middleware: middleware,
);

class TodoClientRoot {
  TodoClientRoot({required RpcTransport transport})
    : _caller = RpcCaller(transport);

  final RpcCaller _caller;

  late final todo = TodoClient(_caller);
}

class TodoClient {
  TodoClient(this._caller);

  final RpcCaller _caller;

  Future<TodoListResponseDto> list() {
    return _caller.call<TodoListResponseDto>(
      method: 'todo.list',
      decode: (json) => TodoListResponseDto.fromJson(
        Map<String, dynamic>.from(
          expectJsonObject(json, context: 'RPC response for "todo.list"'),
        ),
      ),
    );
  }

  Future<TodoResponseDto> getById(GetTodoDto input) {
    return _caller.call<TodoResponseDto>(
      method: 'todo.getById',
      input: input.toJson(),
      decode: (json) => TodoResponseDto.fromJson(
        Map<String, dynamic>.from(
          expectJsonObject(json, context: 'RPC response for "todo.getById"'),
        ),
      ),
    );
  }

  Future<TodoResponseDto> create(CreateTodoDto input) {
    return _caller.call<TodoResponseDto>(
      method: 'todo.create',
      input: input.toJson(),
      decode: (json) => TodoResponseDto.fromJson(
        Map<String, dynamic>.from(
          expectJsonObject(json, context: 'RPC response for "todo.create"'),
        ),
      ),
    );
  }

  Future<TodoResponseDto> update(UpdateTodoDto input) {
    return _caller.call<TodoResponseDto>(
      method: 'todo.update',
      input: input.toJson(),
      decode: (json) => TodoResponseDto.fromJson(
        Map<String, dynamic>.from(
          expectJsonObject(json, context: 'RPC response for "todo.update"'),
        ),
      ),
    );
  }

  Future<DeleteTodoResponseDto> delete(GetTodoDto input) {
    return _caller.call<DeleteTodoResponseDto>(
      method: 'todo.delete',
      input: input.toJson(),
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
    Iterable<RpcHttpMiddleware> middleware = const [],
  }) => dartOrpcBuildTodoModuleRpcApp(
    openApi: openApi,
    docs: docs,
    middleware: middleware,
  );
  TodoClientRoot createClient({required RpcTransport transport}) =>
      TodoClientRoot(transport: transport);
}
