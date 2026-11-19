// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// RpcModuleGenerator
// **************************************************************************

// ignore_for_file: unnecessary_import

export 'package:basic_app/modules/todo/todo_module.orpc.dart';
export 'package:basic_app/modules/todo_analysis/todo_analysis_dtos.dart';
export 'package:basic_app/modules/todo_analysis/todo_analysis_module.dart';

import 'package:basic_app/database/app_database.dart';
import 'package:basic_app/guard/jwt_auth_guard.dart';
import 'package:basic_app/guard/logger_guard.dart';
import 'package:basic_app/guard/permission_guard.dart';
import 'package:basic_app/modules/todo/todo_controller.dart';
import 'package:basic_app/modules/todo/todo_module.orpc.dart';
import 'package:basic_app/modules/todo/todo_service.dart';
import 'package:basic_app/modules/todo_analysis/todo_analysis_controller.dart';
import 'package:basic_app/modules/todo_analysis/todo_analysis_dtos.dart';
import 'package:basic_app/modules/todo_analysis/todo_analysis_module.dart';
import 'package:basic_app/modules/todo_analysis/todo_analysis_service.dart';
import 'package:dart_orpc/dart_orpc.dart';

class _$TodoAnalysisModuleContainer {
  _$TodoAnalysisModuleContainer({
    required this.todoService,
    required this.basicAppJwtAuthGuard,
    required this.todoRouteLoggerGuard,
    required this.todoPermissionGuard,
    required this.todoAnalysisService,
    required this.todoController,
    required this.todoAnalysisController,
  });

  final TodoService todoService;

  final BasicAppJwtAuthGuard basicAppJwtAuthGuard;

  final TodoRouteLoggerGuard todoRouteLoggerGuard;

  final TodoPermissionGuard todoPermissionGuard;

  final TodoAnalysisService todoAnalysisService;

  final TodoController todoController;

  final TodoAnalysisController todoAnalysisController;

  Future<void> dispose() => disposeRpcProviders([
    todoAnalysisController,
    todoController,
    todoAnalysisService,
    todoPermissionGuard,
    todoRouteLoggerGuard,
    basicAppJwtAuthGuard,
    todoService,
  ]);
}

_$TodoAnalysisModuleContainer _$createTodoAnalysisModuleContainer({
  required AppDatabase appDatabase,
}) {
  final todoService = TodoService(appDatabase);
  final basicAppJwtAuthGuard = BasicAppJwtAuthGuard();
  final todoRouteLoggerGuard = TodoRouteLoggerGuard();
  final todoPermissionGuard = TodoPermissionGuard();

  final todoAnalysisService = TodoAnalysisService(todoService);

  final todoController = TodoController(todoService);

  final todoAnalysisController = TodoAnalysisController(todoAnalysisService);

  return _$TodoAnalysisModuleContainer(
    todoService: todoService,
    basicAppJwtAuthGuard: basicAppJwtAuthGuard,
    todoRouteLoggerGuard: todoRouteLoggerGuard,
    todoPermissionGuard: todoPermissionGuard,
    todoAnalysisService: todoAnalysisService,
    todoController: todoController,
    todoAnalysisController: todoAnalysisController,
  );
}

RpcProcedureRegistry _$createTodoAnalysisModuleProcedureRegistryFromContainer(
  _$TodoAnalysisModuleContainer container,
) {
  final metadataRegistry = _$todoAnalysisModuleProcedureMetadata;
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
            validateJson: $TodoListResponseDtoSchema.validate,
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
        validateJson: $TodoResponseDtoSchema.validate,
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
            validateJson: $TodoChangeResponseDtoSchema.validate,
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
      ),
      encodeOutput: (output) => encodeRpcOutputJsonWithLuthor<TodoResponseDto>(
        output: output,
        method: 'todo.getById',
        toJson: (output) => output.toJson(),
        validateJson: $TodoResponseDtoSchema.validate,
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
    RpcStreamProcedure<GetTodoDto, TodoResponseDto>(
      method: 'todo.watchById',
      decodeInput: (rawInput) => decodeRpcInputWithLuthor<GetTodoDto>(
        rawInput: rawInput,
        method: 'todo.watchById',
        validate: $GetTodoDtoValidate,
      ),
      encodeOutput: (output) => encodeRpcOutputJsonWithLuthor<TodoResponseDto>(
        output: output,
        method: 'todo.watchById',
        toJson: (output) => output.toJson(),
        validateJson: $TodoResponseDtoSchema.validate,
      ),
      metadata: metadataRegistry['todo.watchById']!,
      guards: [
        container.basicAppJwtAuthGuard,
        container.todoRouteLoggerGuard,
        container.todoPermissionGuard,
      ],

      handler: (context, input) =>
          container.todoController.watchById(context, input),
    ),
    RpcUnaryProcedure<CreateTodoDto, TodoResponseDto>(
      method: 'todo.create',
      decodeInput: (rawInput) => decodeRpcInputWithLuthor<CreateTodoDto>(
        rawInput: rawInput,
        method: 'todo.create',
        validate: $CreateTodoDtoValidate,
      ),
      encodeOutput: (output) => encodeRpcOutputJsonWithLuthor<TodoResponseDto>(
        output: output,
        method: 'todo.create',
        toJson: (output) => output.toJson(),
        validateJson: $TodoResponseDtoSchema.validate,
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
      ),
      encodeOutput: (output) => encodeRpcOutputJsonWithLuthor<TodoResponseDto>(
        output: output,
        method: 'todo.update',
        toJson: (output) => output.toJson(),
        validateJson: $TodoResponseDtoSchema.validate,
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
      ),
      encodeOutput: (output) =>
          encodeRpcOutputJsonWithLuthor<DeleteTodoResponseDto>(
            output: output,
            method: 'todo.delete',
            toJson: (output) => output.toJson(),
            validateJson: $DeleteTodoResponseDtoSchema.validate,
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
    RpcUnaryProcedure<Null, TodoAnalysisSummaryDto>(
      method: 'todoAnalysis.summary',
      decodeInput: (rawInput) => expectNoRpcInput(
        rawInput,
        context: 'RPC method "todoAnalysis.summary"',
      ),
      encodeOutput: (output) =>
          encodeRpcOutputJsonWithLuthor<TodoAnalysisSummaryDto>(
            output: output,
            method: 'todoAnalysis.summary',
            toJson: (output) => output.toJson(),
            validateJson: $TodoAnalysisSummaryDtoSchema.validate,
          ),
      metadata: metadataRegistry['todoAnalysis.summary']!,

      handler: (context, input) =>
          container.todoAnalysisController.summary(context),
    ),
  ]);
}

RpcProcedureRegistry _$createTodoAnalysisModuleProcedureRegistry({
  required AppDatabase appDatabase,
}) => _$createTodoAnalysisModuleProcedureRegistryFromContainer(
  _$createTodoAnalysisModuleContainer(appDatabase: appDatabase),
);

RpcProcedureRegistry dartOrpcCreateTodoAnalysisModuleProcedureRegistry({
  required AppDatabase appDatabase,
}) => _$createTodoAnalysisModuleProcedureRegistry(appDatabase: appDatabase);

({RpcProcedureRegistry procedures, RestRouteRegistry restRoutes})
_$createTodoAnalysisModuleRuntime({required AppDatabase appDatabase}) {
  final container = _$createTodoAnalysisModuleContainer(
    appDatabase: appDatabase,
  );
  return (
    procedures: _$createTodoAnalysisModuleProcedureRegistryFromContainer(
      container,
    ),
    restRoutes: _$createTodoAnalysisModuleRestRouteRegistryFromContainer(
      container,
    ),
  );
}

({RpcProcedureRegistry procedures, RestRouteRegistry restRoutes})
dartOrpcCreateTodoAnalysisModuleRuntime({required AppDatabase appDatabase}) =>
    _$createTodoAnalysisModuleRuntime(appDatabase: appDatabase);

RestRouteRegistry _$createTodoAnalysisModuleRestRouteRegistryFromContainer(
  _$TodoAnalysisModuleContainer container,
) {
  final metadataRegistry = _$todoAnalysisModuleProcedureMetadata;
  return RestRouteRegistry([
    RestUnaryRoute(
      method: 'GET',
      path: '/todos',
      handler: (context, request, pathParameters) async {
        final output = await container.todoController.list(context);
        return encodeRpcOutputJsonWithLuthor<TodoListResponseDto>(
          output: output,
          method: 'todo.list',
          toJson: (output) => output.toJson(),
          validateJson: $TodoListResponseDtoSchema.validate,
        );
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
            validateJson: $TodoResponseDtoSchema.validate,
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
            validateJson: $TodoChangeResponseDtoSchema.validate,
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
        ))(rawInput);
        final output = await container.todoController.getById(context, input);
        return encodeRpcOutputJsonWithLuthor<TodoResponseDto>(
          output: output,
          method: 'todo.getById',
          toJson: (output) => output.toJson(),
          validateJson: $TodoResponseDtoSchema.validate,
        );
      },
      metadata: metadataRegistry['todo.getById']!,
      guards: [
        container.basicAppJwtAuthGuard,
        container.todoRouteLoggerGuard,
        container.todoPermissionGuard,
      ],
    ),
    RestStreamRoute(
      path: '/todos/:id/events',
      handler: (context, request, pathParameters) {
        final rawInput = <String, Object?>{};
        rawInput['id'] = decodeRestScalarParameter<int>(
          rawValue: pathParameters['id'],
          source: 'path parameter',
          name: 'id',
          route: 'GET /todos/:id/events',
        );
        final input = ((rawInput) => decodeRpcInputWithLuthor<GetTodoDto>(
          rawInput: rawInput,
          method: 'todo.watchById',
          validate: $GetTodoDtoValidate,
        ))(rawInput);
        final output = container.todoController.watchById(context, input);
        return output.map(
          (output) => encodeRpcOutputJsonWithLuthor<TodoResponseDto>(
            output: output,
            method: 'todo.watchById',
            toJson: (output) => output.toJson(),
            validateJson: $TodoResponseDtoSchema.validate,
          ),
        );
      },
      metadata: metadataRegistry['todo.watchById']!,
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
        final rawInput = decodeRestRpcInputBody(
          request,
          route: 'POST /todos',
          parameterName: 'input',
        );
        final input = ((rawInput) => decodeRpcInputWithLuthor<CreateTodoDto>(
          rawInput: rawInput,
          method: 'todo.create',
          validate: $CreateTodoDtoValidate,
        ))(rawInput);
        final output = await container.todoController.create(context, input);
        return encodeRpcOutputJsonWithLuthor<TodoResponseDto>(
          output: output,
          method: 'todo.create',
          toJson: (output) => output.toJson(),
          validateJson: $TodoResponseDtoSchema.validate,
        );
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
        final rawInput = decodeRestRpcInputBody(
          request,
          route: 'PATCH /todos/:id',
          parameterName: 'input',
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
        final output = await container.todoController.update(context, input);
        return encodeRpcOutputJsonWithLuthor<TodoResponseDto>(
          output: output,
          method: 'todo.update',
          toJson: (output) => output.toJson(),
          validateJson: $TodoResponseDtoSchema.validate,
        );
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
        ))(rawInput);
        final output = await container.todoController.delete(context, input);
        return encodeRpcOutputJsonWithLuthor<DeleteTodoResponseDto>(
          output: output,
          method: 'todo.delete',
          toJson: (output) => output.toJson(),
          validateJson: $DeleteTodoResponseDtoSchema.validate,
        );
      },
      metadata: metadataRegistry['todo.delete']!,
      guards: [
        container.basicAppJwtAuthGuard,
        container.todoRouteLoggerGuard,
        container.todoPermissionGuard,
      ],
    ),
    RestUnaryRoute(
      method: 'GET',
      path: '/todos/analysis/summary',
      handler: (context, request, pathParameters) async {
        final output = await container.todoAnalysisController.summary(context);
        return encodeRpcOutputJsonWithLuthor<TodoAnalysisSummaryDto>(
          output: output,
          method: 'todoAnalysis.summary',
          toJson: (output) => output.toJson(),
          validateJson: $TodoAnalysisSummaryDtoSchema.validate,
        );
      },
      metadata: metadataRegistry['todoAnalysis.summary']!,
    ),
  ]);
}

RestRouteRegistry _$createTodoAnalysisModuleRestRouteRegistry({
  required AppDatabase appDatabase,
}) => _$createTodoAnalysisModuleRestRouteRegistryFromContainer(
  _$createTodoAnalysisModuleContainer(appDatabase: appDatabase),
);

RestRouteRegistry dartOrpcCreateTodoAnalysisModuleRestRouteRegistry({
  required AppDatabase appDatabase,
}) => _$createTodoAnalysisModuleRestRouteRegistry(appDatabase: appDatabase);

final ProcedureMetadataRegistry _$todoAnalysisModuleProcedureMetadata =
    ProcedureMetadataRegistry([
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
        rpcMethod: 'todo.watchById',
        controllerNamespace: 'todo',
        methodName: 'watchById',
        kind: RpcProcedureKind.serverStream,
        path: RestProcedureMetadata(
          method: 'GET',
          path: '/todos/:id/events',
          responseKind: RestResponseKind.sse,
        ),
        inputTypeCode: 'GetTodoDto',
        outputTypeCode: 'TodoResponseDto',
        description: 'Stream the current state of a single todo.',
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
      const ProcedureMetadata(
        rpcMethod: 'todoAnalysis.summary',
        controllerNamespace: 'todoAnalysis',
        methodName: 'summary',
        path: RestProcedureMetadata(
          method: 'GET',
          path: '/todos/analysis/summary',
        ),
        outputTypeCode: 'TodoAnalysisSummaryDto',
        description: 'Aggregate todo counts and completion rate.',
        tags: ['analysis'],
      ),
    ]);

ProcedureMetadataRegistry
_$createTodoAnalysisModuleProcedureMetadataRegistry() =>
    _$todoAnalysisModuleProcedureMetadata;

ProcedureMetadataRegistry
dartOrpcCreateTodoAnalysisModuleProcedureMetadataRegistry() =>
    _$createTodoAnalysisModuleProcedureMetadataRegistry();

JsonObject _$createTodoAnalysisModuleOpenApiDocument({
  OpenApiDocumentOptions? options,
}) {
  final effectiveOptions = options ?? const OpenApiDocumentOptions();
  return createOpenApiDocument(
    title: effectiveOptions.title ?? 'TodoAnalysis API',
    version: effectiveOptions.version,
    description: effectiveOptions.description,
    servers: effectiveOptions.servers,
    procedures: _$createTodoAnalysisModuleProcedureMetadataRegistry(),
    schemas: _$createTodoAnalysisModuleDtoSchemaRegistry(),
  );
}

JsonObject dartOrpcCreateTodoAnalysisModuleOpenApiDocument({
  OpenApiDocumentOptions? options,
}) => _$createTodoAnalysisModuleOpenApiDocument(options: options);

RpcHttpApp _$buildTodoAnalysisModuleRpcApp({
  required AppDatabase appDatabase,
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
  bool encodeJsonToBytes = true,
  int? maxConcurrentRequests,
  Duration? requestBodyIdleTimeout,
  RpcHttpServerOptions serverOptions = const RpcHttpServerOptions(),
  Iterable<RpcHttpMiddleware> middleware = const [],
  RpcObserver? observer,
}) {
  final effectiveOpenApi = openApi ?? const OpenApiDocumentOptions();
  final effectiveDocs = docs ?? const RpcHttpDocsOptions();
  final effectiveOpenApiTitle = effectiveOpenApi.title ?? 'TodoAnalysis API';
  final effectiveOpenApiPath = effectiveDocs.openApiPath;
  final container = _$createTodoAnalysisModuleContainer(
    appDatabase: appDatabase,
  );
  final procedures = _$createTodoAnalysisModuleProcedureRegistryFromContainer(
    container,
  );
  final restRoutes = _$createTodoAnalysisModuleRestRouteRegistryFromContainer(
    container,
  );
  return RpcHttpApp(
    procedures: procedures,
    restRoutes: restRoutes,
    onClose: container.dispose,
    openApiDocument: _$createTodoAnalysisModuleOpenApiDocument(
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
    middleware: middleware,
    observer: observer,
    upgradeHandlers: [
      if (webSocket != null)
        RpcWebSocketUpgradeHandler(
          procedures: procedures,
          options: webSocket,
          observer: observer,
        ),
    ],
  );
}

RpcHttpApp dartOrpcBuildTodoAnalysisModuleRpcApp({
  required AppDatabase appDatabase,
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
  bool encodeJsonToBytes = true,
  int? maxConcurrentRequests,
  Duration? requestBodyIdleTimeout,
  RpcHttpServerOptions serverOptions = const RpcHttpServerOptions(),
  Iterable<RpcHttpMiddleware> middleware = const [],
  RpcObserver? observer,
}) => _$buildTodoAnalysisModuleRpcApp(
  appDatabase: appDatabase,
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
  observer: observer,
);

DtoSchemaRegistry _$createTodoAnalysisModuleLocalDtoSchemaRegistry() {
  return DtoSchemaRegistry(const [
    DtoSchemaMetadata(
      name: 'TodoAnalysisSummaryDto',
      fields: [
        DtoFieldMetadata(wireName: 'total', type: DtoIntegerType()),
        DtoFieldMetadata(wireName: 'completed', type: DtoIntegerType()),
        DtoFieldMetadata(wireName: 'pending', type: DtoIntegerType()),
        DtoFieldMetadata(wireName: 'completionRate', type: DtoNumberType()),
      ],
    ),
  ]);
}

DtoSchemaRegistry dartOrpcCreateTodoAnalysisModuleLocalDtoSchemaRegistry() =>
    _$createTodoAnalysisModuleLocalDtoSchemaRegistry();

DtoSchemaRegistry _$createTodoAnalysisModuleDtoSchemaRegistry() {
  return DtoSchemaRegistry([
    ...dartOrpcCreateTodoModuleLocalDtoSchemaRegistry().schemas,
    ..._$createTodoAnalysisModuleLocalDtoSchemaRegistry().schemas,
  ]);
}

DtoSchemaRegistry dartOrpcCreateTodoAnalysisModuleDtoSchemaRegistry() =>
    _$createTodoAnalysisModuleDtoSchemaRegistry();

class TodoAnalysisClientRoot {
  TodoAnalysisClientRoot({required RpcClientTransports transports})
    : _transports = transports;

  final RpcClientTransports _transports;

  late final TodoClientRoot _todoModuleClient = TodoClientRoot(
    transports: _transports,
  );
  late final todo = _todoModuleClient.todo;
  late final todoAnalysis = TodoAnalysisClient(_transports);
}

class TodoAnalysisClient {
  TodoAnalysisClient(this._transports);

  final RpcClientTransports _transports;

  Future<TodoAnalysisSummaryDto> summary() {
    return RpcCaller(_transports.requireUnary('todoAnalysis.summary'))
        .call<TodoAnalysisSummaryDto>(
          method: 'todoAnalysis.summary',
          options: null,
          decode: (json) => TodoAnalysisSummaryDto.fromJson(
            Map<String, dynamic>.from(
              expectJsonObject(
                json,
                context: 'RPC response for "todoAnalysis.summary"',
              ),
            ),
          ),
        );
  }
}

extension DartOrpcTodoAnalysisModuleGenerated on TodoAnalysisModule {
  RpcProcedureRegistry procedureRegistry({required AppDatabase appDatabase}) =>
      dartOrpcCreateTodoAnalysisModuleProcedureRegistry(
        appDatabase: appDatabase,
      );
  RestRouteRegistry restRouteRegistry({required AppDatabase appDatabase}) =>
      dartOrpcCreateTodoAnalysisModuleRestRouteRegistry(
        appDatabase: appDatabase,
      );
  ProcedureMetadataRegistry procedureMetadata() =>
      dartOrpcCreateTodoAnalysisModuleProcedureMetadataRegistry();
  DtoSchemaRegistry dtoSchemaRegistry() =>
      dartOrpcCreateTodoAnalysisModuleDtoSchemaRegistry();
  JsonObject openApiDocument({OpenApiDocumentOptions? options}) =>
      dartOrpcCreateTodoAnalysisModuleOpenApiDocument(options: options);
  RpcHttpApp buildRpcApp({
    required AppDatabase appDatabase,
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
    bool encodeJsonToBytes = true,
    int? maxConcurrentRequests,
    Duration? requestBodyIdleTimeout,
    RpcHttpServerOptions serverOptions = const RpcHttpServerOptions(),
    Iterable<RpcHttpMiddleware> middleware = const [],
    RpcObserver? observer,
  }) => dartOrpcBuildTodoAnalysisModuleRpcApp(
    appDatabase: appDatabase,
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
    observer: observer,
  );
  TodoAnalysisClientRoot createClient({
    required RpcClientTransports transports,
  }) => TodoAnalysisClientRoot(transports: transports);
}
