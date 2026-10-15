// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// RpcModuleGenerator
// **************************************************************************

export 'package:basic_app/app.dart';
export 'package:basic_app/modules/auth/auth_module.orpc.dart';
export 'package:basic_app/modules/todo/todo_module.orpc.dart';
export 'package:basic_app/modules/todo_analysis/todo_analysis_module.orpc.dart';

import 'package:basic_app/app.dart';
import 'package:basic_app/database/app_database.dart';
import 'package:basic_app/guard/jwt_auth_guard.dart';
import 'package:basic_app/guard/logger_guard.dart';
import 'package:basic_app/guard/permission_guard.dart';
import 'package:basic_app/modules/auth/auth_controller.dart';
import 'package:basic_app/modules/auth/auth_module.orpc.dart';
import 'package:basic_app/modules/auth/auth_service.dart';
import 'package:basic_app/modules/todo/todo_controller.dart';
import 'package:basic_app/modules/todo/todo_module.orpc.dart';
import 'package:basic_app/modules/todo/todo_service.dart';
import 'package:basic_app/modules/todo_analysis/todo_analysis_controller.dart';
import 'package:basic_app/modules/todo_analysis/todo_analysis_module.orpc.dart';
import 'package:basic_app/modules/todo_analysis/todo_analysis_service.dart';
import 'package:dart_orpc/dart_orpc.dart';

class _$AppModuleContainer {
  _$AppModuleContainer({
    required this.appDatabase,
    required this.authService,
    required this.appDatabase2,
    required this.todoService,
    required this.basicAppJwtAuthGuard,
    required this.todoRouteLoggerGuard,
    required this.todoPermissionGuard,
    required this.appDatabase3,
    required this.todoService2,
    required this.todoAnalysisService,
    required this.authController,
    required this.todoController,
    required this.todoAnalysisController,
  });

  final AppDatabase appDatabase;

  final AuthService authService;

  final AppDatabase appDatabase2;

  final TodoService todoService;

  final BasicAppJwtAuthGuard basicAppJwtAuthGuard;

  final TodoRouteLoggerGuard todoRouteLoggerGuard;

  final TodoPermissionGuard todoPermissionGuard;

  final AppDatabase appDatabase3;

  final TodoService todoService2;

  final TodoAnalysisService todoAnalysisService;

  final AuthController authController;

  final TodoController todoController;

  final TodoAnalysisController todoAnalysisController;

  Future<void> dispose() => disposeRpcProviders([
    todoAnalysisController,
    todoController,
    authController,
    todoAnalysisService,
    todoService2,
    appDatabase3,
    todoPermissionGuard,
    todoRouteLoggerGuard,
    basicAppJwtAuthGuard,
    todoService,
    appDatabase2,
    authService,
    appDatabase,
  ]);
}

_$AppModuleContainer _$createAppModuleContainer() {
  final appDatabase = AppDatabase();
  final authService = AuthService(appDatabase);
  final appDatabase2 = AppDatabase();
  final todoService = TodoService(appDatabase2);
  final basicAppJwtAuthGuard = BasicAppJwtAuthGuard();
  final todoRouteLoggerGuard = TodoRouteLoggerGuard();
  final todoPermissionGuard = TodoPermissionGuard();
  final appDatabase3 = AppDatabase();
  final todoService2 = TodoService(appDatabase3);
  final todoAnalysisService = TodoAnalysisService(todoService2);
  final authController = AuthController(authService);

  final todoController = TodoController(todoService);

  final todoAnalysisController = TodoAnalysisController(todoAnalysisService);

  return _$AppModuleContainer(
    appDatabase: appDatabase,
    authService: authService,
    appDatabase2: appDatabase2,
    todoService: todoService,
    basicAppJwtAuthGuard: basicAppJwtAuthGuard,
    todoRouteLoggerGuard: todoRouteLoggerGuard,
    todoPermissionGuard: todoPermissionGuard,
    appDatabase3: appDatabase3,
    todoService2: todoService2,
    todoAnalysisService: todoAnalysisService,
    authController: authController,
    todoController: todoController,
    todoAnalysisController: todoAnalysisController,
  );
}

// ignore: unused_element
RpcProcedureRegistry _$createAppModuleLocalProcedureRegistry() {
  final container = _$createAppModuleContainer();
  return _$createAppModuleProcedureRegistryFromContainer(container);
}

RpcProcedureRegistry _$createAppModuleProcedureRegistryFromContainer(
  _$AppModuleContainer container,
) {
  final metadataRegistry = _$createAppModuleLocalProcedureMetadataRegistry();
  return RpcProcedureRegistry([
    RpcUnaryProcedure<SignUpDto, AuthResponseDto>(
      method: 'auth.signUp',
      decodeInput: (rawInput) => decodeRpcInputWithLuthor<SignUpDto>(
        rawInput: rawInput,
        method: 'auth.signUp',
        validate: $SignUpDtoValidate,
        validateReadOnly: $SignUpDtoValidate,
      ),
      encodeOutput: (output) => encodeRpcOutputJsonWithLuthor<AuthResponseDto>(
        output: output,
        method: 'auth.signUp',
        toJson: (output) => output.toJson(),
        validateJson: (json) => $AuthResponseDtoSchema.validateSchema(json),
      ),
      metadata: metadataRegistry['auth.signUp']!,

      handler: (context, input) =>
          container.authController.signUp(context, input),
    ),
    RpcUnaryProcedure<LoginDto, AuthResponseDto>(
      method: 'auth.login',
      decodeInput: (rawInput) => decodeRpcInputWithLuthor<LoginDto>(
        rawInput: rawInput,
        method: 'auth.login',
        validate: $LoginDtoValidate,
        validateReadOnly: $LoginDtoValidate,
      ),
      encodeOutput: (output) => encodeRpcOutputJsonWithLuthor<AuthResponseDto>(
        output: output,
        method: 'auth.login',
        toJson: (output) => output.toJson(),
        validateJson: (json) => $AuthResponseDtoSchema.validateSchema(json),
      ),
      metadata: metadataRegistry['auth.login']!,

      handler: (context, input) =>
          container.authController.login(context, input),
    ),
    RpcUnaryProcedure<Null, int>(
      method: 'auth.test',
      decodeInput: (rawInput) =>
          expectNoRpcInput(rawInput, context: 'RPC method "auth.test"'),
      encodeOutput: (output) => output,
      metadata: metadataRegistry['auth.test']!,

      handler: (context, input) => container.authController.test(context),
    ),
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
            validateJson: (json) =>
                $TodoAnalysisSummaryDtoSchema.validateSchema(json),
          ),
      metadata: metadataRegistry['todoAnalysis.summary']!,

      handler: (context, input) =>
          container.todoAnalysisController.summary(context),
    ),
  ]);
}

RpcProcedureRegistry _$createAppModuleProcedureRegistry() {
  return RpcProcedureRegistry([
    ..._$createAppModuleLocalProcedureRegistry().procedures,
  ]);
}

RpcProcedureRegistry dartOrpcCreateAppModuleProcedureRegistry() =>
    _$createAppModuleProcedureRegistry();

({RpcProcedureRegistry procedures, RestRouteRegistry restRoutes})
_$createAppModuleRuntime() {
  final container = _$createAppModuleContainer();
  final localProcedures = _$createAppModuleProcedureRegistryFromContainer(
    container,
  );
  final localRestRoutes = _$createAppModuleRestRouteRegistryFromContainer(
    container,
  );

  return (
    procedures: RpcProcedureRegistry([...localProcedures.procedures]),
    restRoutes: RestRouteRegistry([...localRestRoutes.routes]),
  );
}

({RpcProcedureRegistry procedures, RestRouteRegistry restRoutes})
dartOrpcCreateAppModuleRuntime() => _$createAppModuleRuntime();

// ignore: unused_element
RestRouteRegistry _$createAppModuleLocalRestRouteRegistry() {
  final container = _$createAppModuleContainer();
  return _$createAppModuleRestRouteRegistryFromContainer(container);
}

RestRouteRegistry _$createAppModuleRestRouteRegistryFromContainer(
  _$AppModuleContainer container,
) {
  final metadataRegistry = _$createAppModuleLocalProcedureMetadataRegistry();
  return RestRouteRegistry([
    RestUnaryRoute(
      method: 'POST',
      path: '/auth/signup',
      handler: (context, request, pathParameters) async {
        final rawInput = request.body.trim().isEmpty
            ? <String, Object?>{}
            : Map<String, Object?>.from(
                decodeRestBody<JsonObject>(
                  rawBody: request.body,
                  route: 'POST /auth/signup',
                  parameterName: 'input',
                  decode: (rawJson) => expectJsonObject(
                    rawJson,
                    context: 'POST /auth/signup body',
                  ),
                ),
              );
        final input = ((rawInput) => decodeRpcInputWithLuthor<SignUpDto>(
          rawInput: rawInput,
          method: 'auth.signUp',
          validate: $SignUpDtoValidate,
          validateReadOnly: $SignUpDtoValidate,
        ))(rawInput);
        final output = await container.authController.signUp(context, input);
        return ((output) => encodeRpcOutputJsonWithLuthor<AuthResponseDto>(
          output: output,
          method: 'auth.signUp',
          toJson: (output) => output.toJson(),
          validateJson: (json) => $AuthResponseDtoSchema.validateSchema(json),
        ))(output);
      },
      metadata: metadataRegistry['auth.signUp']!,
    ),
    RestUnaryRoute(
      method: 'POST',
      path: '/auth/login',
      handler: (context, request, pathParameters) async {
        final rawInput = request.body.trim().isEmpty
            ? <String, Object?>{}
            : Map<String, Object?>.from(
                decodeRestBody<JsonObject>(
                  rawBody: request.body,
                  route: 'POST /auth/login',
                  parameterName: 'input',
                  decode: (rawJson) => expectJsonObject(
                    rawJson,
                    context: 'POST /auth/login body',
                  ),
                ),
              );
        final input = ((rawInput) => decodeRpcInputWithLuthor<LoginDto>(
          rawInput: rawInput,
          method: 'auth.login',
          validate: $LoginDtoValidate,
          validateReadOnly: $LoginDtoValidate,
        ))(rawInput);
        final output = await container.authController.login(context, input);
        return ((output) => encodeRpcOutputJsonWithLuthor<AuthResponseDto>(
          output: output,
          method: 'auth.login',
          toJson: (output) => output.toJson(),
          validateJson: (json) => $AuthResponseDtoSchema.validateSchema(json),
        ))(output);
      },
      metadata: metadataRegistry['auth.login']!,
    ),
    RestUnaryRoute(
      method: 'POST',
      path: '/auth/test',
      handler: (context, request, pathParameters) async {
        final output = await container.authController.test(context);
        return ((output) => output)(output);
      },
      metadata: metadataRegistry['auth.test']!,
    ),
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
    RestUnaryRoute(
      method: 'GET',
      path: '/todos/analysis/summary',
      handler: (context, request, pathParameters) async {
        final output = await container.todoAnalysisController.summary(context);
        return ((output) =>
            encodeRpcOutputJsonWithLuthor<TodoAnalysisSummaryDto>(
              output: output,
              method: 'todoAnalysis.summary',
              toJson: (output) => output.toJson(),
              validateJson: (json) =>
                  $TodoAnalysisSummaryDtoSchema.validateSchema(json),
            ))(output);
      },
      metadata: metadataRegistry['todoAnalysis.summary']!,
    ),
  ]);
}

RestRouteRegistry _$createAppModuleRestRouteRegistry() {
  return RestRouteRegistry([
    ..._$createAppModuleLocalRestRouteRegistry().routes,
  ]);
}

RestRouteRegistry dartOrpcCreateAppModuleRestRouteRegistry() =>
    _$createAppModuleRestRouteRegistry();

// ignore: unused_element
ProcedureMetadataRegistry _$createAppModuleLocalProcedureMetadataRegistry() {
  return ProcedureMetadataRegistry([
    const ProcedureMetadata(
      rpcMethod: 'auth.signUp',
      controllerNamespace: 'auth',
      methodName: 'signUp',
      path: RestProcedureMetadata(method: 'POST', path: '/auth/signup'),
      inputTypeCode: 'SignUpDto',
      outputTypeCode: 'AuthResponseDto',
      description: 'Create an account and return a JWT access token.',
      tags: ['auth'],
      parameters: [
        ProcedureParameterMetadata(
          parameterName: 'input',
          wireName: 'input',
          source: ProcedureParameterSourceKind.body,
          typeCode: 'SignUpDto',
        ),
      ],
    ),
    const ProcedureMetadata(
      rpcMethod: 'auth.login',
      controllerNamespace: 'auth',
      methodName: 'login',
      path: RestProcedureMetadata(method: 'POST', path: '/auth/login'),
      inputTypeCode: 'LoginDto',
      outputTypeCode: 'AuthResponseDto',
      description: 'Authenticate with email and password.',
      tags: ['auth'],
      parameters: [
        ProcedureParameterMetadata(
          parameterName: 'input',
          wireName: 'input',
          source: ProcedureParameterSourceKind.body,
          typeCode: 'LoginDto',
        ),
      ],
    ),
    const ProcedureMetadata(
      rpcMethod: 'auth.test',
      controllerNamespace: 'auth',
      methodName: 'test',
      path: RestProcedureMetadata(method: 'POST', path: '/auth/test'),
      outputTypeCode: 'int',
      description: 'Authenticate with email and password.',
      tags: ['auth'],
    ),
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
}

ProcedureMetadataRegistry _$createAppModuleProcedureMetadataRegistry() {
  return ProcedureMetadataRegistry([
    ..._$createAppModuleLocalProcedureMetadataRegistry().procedures,
  ]);
}

ProcedureMetadataRegistry dartOrpcCreateAppModuleProcedureMetadataRegistry() =>
    _$createAppModuleProcedureMetadataRegistry();

OpenApiSchemaRegistry _$createAppModuleLocalOpenApiSchemaRegistry() {
  return OpenApiSchemaRegistry([]);
}

OpenApiSchemaRegistry _$createAppModuleOpenApiSchemaRegistry() {
  return OpenApiSchemaRegistry([
    ...dartOrpcCreateAuthModuleOpenApiSchemaRegistry().components,
    ...dartOrpcCreateTodoModuleOpenApiSchemaRegistry().components,
    ...dartOrpcCreateTodoAnalysisModuleOpenApiSchemaRegistry().components,
    ..._$createAppModuleLocalOpenApiSchemaRegistry().components,
  ]);
}

OpenApiSchemaRegistry dartOrpcCreateAppModuleOpenApiSchemaRegistry() =>
    _$createAppModuleOpenApiSchemaRegistry();

JsonObject _$createAppModuleOpenApiDocument({OpenApiDocumentOptions? options}) {
  final effectiveOptions = options ?? const OpenApiDocumentOptions();
  return createOpenApiDocument(
    title: effectiveOptions.title ?? 'App API',
    version: effectiveOptions.version,
    description: effectiveOptions.description,
    servers: effectiveOptions.servers,
    procedures: _$createAppModuleProcedureMetadataRegistry(),
    schemas: _$createAppModuleOpenApiSchemaRegistry(),
  );
}

JsonObject dartOrpcCreateAppModuleOpenApiDocument({
  OpenApiDocumentOptions? options,
}) => _$createAppModuleOpenApiDocument(options: options);

RpcHttpApp _$buildAppModuleRpcApp({
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
  final effectiveOpenApiTitle = effectiveOpenApi.title ?? 'App API';
  final effectiveOpenApiPath = effectiveDocs.openApiPath;
  final container = _$createAppModuleContainer();
  final procedures = _$createAppModuleProcedureRegistryFromContainer(container);
  final restRoutes = _$createAppModuleRestRouteRegistryFromContainer(container);
  return RpcHttpApp(
    procedures: procedures,
    restRoutes: restRoutes,
    onClose: container.dispose,
    openApiDocument: _$createAppModuleOpenApiDocument(
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

RpcHttpApp dartOrpcBuildAppModuleRpcApp({
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
}) => _$buildAppModuleRpcApp(
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

class AppClient {
  AppClient({required RpcClientTransports transports})
    : _transports = transports;

  final RpcClientTransports _transports;

  late final AuthClientRoot _authModuleClient = AuthClientRoot(
    transports: _transports,
  );
  late final TodoClientRoot _todoModuleClient = TodoClientRoot(
    transports: _transports,
  );
  late final TodoAnalysisClientRoot _todoAnalysisModuleClient =
      TodoAnalysisClientRoot(transports: _transports);
  late final auth = _authModuleClient.auth;
  late final todo = _todoModuleClient.todo;
  late final todoAnalysis = _todoAnalysisModuleClient.todoAnalysis;
}

extension DartOrpcAppModuleGenerated on AppModule {
  RpcProcedureRegistry procedureRegistry() =>
      dartOrpcCreateAppModuleProcedureRegistry();
  RestRouteRegistry restRouteRegistry() =>
      dartOrpcCreateAppModuleRestRouteRegistry();
  ProcedureMetadataRegistry procedureMetadata() =>
      dartOrpcCreateAppModuleProcedureMetadataRegistry();
  OpenApiSchemaRegistry openApiSchemaRegistry() =>
      dartOrpcCreateAppModuleOpenApiSchemaRegistry();
  JsonObject openApiDocument({OpenApiDocumentOptions? options}) =>
      dartOrpcCreateAppModuleOpenApiDocument(options: options);
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
  }) => dartOrpcBuildAppModuleRpcApp(
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
  AppClient createClient({required RpcClientTransports transports}) =>
      AppClient(transports: transports);
}
