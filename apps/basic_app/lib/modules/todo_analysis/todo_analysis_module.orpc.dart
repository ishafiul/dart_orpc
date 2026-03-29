// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// RpcModuleGenerator
// **************************************************************************

export 'package:basic_app/modules/todo_analysis/todo_analysis_module.dart';

import 'package:basic_app/database/app_database.dart';
import 'package:basic_app/modules/todo/todo_service.dart';
import 'package:basic_app/modules/todo_analysis/todo_analysis_controller.dart';
import 'package:basic_app/modules/todo_analysis/todo_analysis_dtos.dart';
import 'package:basic_app/modules/todo_analysis/todo_analysis_module.dart';
import 'package:basic_app/modules/todo_analysis/todo_analysis_service.dart';
import 'package:dart_orpc/dart_orpc.dart';

class _$TodoAnalysisModuleContainer {
  _$TodoAnalysisModuleContainer({
    required this.appDatabase,
    required this.todoService,
    required this.todoAnalysisService,
    required this.todoAnalysisController,
  });

  final AppDatabase appDatabase;

  final TodoService todoService;

  final TodoAnalysisService todoAnalysisService;

  final TodoAnalysisController todoAnalysisController;
}

_$TodoAnalysisModuleContainer _$createTodoAnalysisModuleContainer() {
  final appDatabase = AppDatabase();
  final todoService = TodoService(appDatabase);
  final todoAnalysisService = TodoAnalysisService(todoService);

  final todoAnalysisController = TodoAnalysisController(todoAnalysisService);

  return _$TodoAnalysisModuleContainer(
    appDatabase: appDatabase,
    todoService: todoService,
    todoAnalysisService: todoAnalysisService,
    todoAnalysisController: todoAnalysisController,
  );
}

// ignore: unused_element
RpcProcedureRegistry _$createTodoAnalysisModuleLocalProcedureRegistry() {
  final container = _$createTodoAnalysisModuleContainer();
  return _$createTodoAnalysisModuleProcedureRegistryFromContainer(container);
}

RpcProcedureRegistry _$createTodoAnalysisModuleProcedureRegistryFromContainer(
  _$TodoAnalysisModuleContainer container,
) {
  return RpcProcedureRegistry([
    RpcProcedure<Null, TodoAnalysisSummaryDto>(
      method: 'todoAnalysis.summary',
      decodeInput: (rawInput) => expectNoRpcInput(
        rawInput,
        context: 'RPC method "todoAnalysis.summary"',
      ),
      encodeOutput: (output) =>
          encodeRpcOutputWithLuthor<TodoAnalysisSummaryDto>(
            output: output,
            method: 'todoAnalysis.summary',
            toJson: (output) => output.toJson(),
            validate: $TodoAnalysisSummaryDtoValidate,
          ),
      handler: (context, input) =>
          container.todoAnalysisController.summary(context),
    ),
  ]);
}

RpcProcedureRegistry _$createTodoAnalysisModuleProcedureRegistry() {
  return RpcProcedureRegistry([
    ..._$createTodoAnalysisModuleLocalProcedureRegistry().procedures,
  ]);
}

RpcProcedureRegistry dartOrpcCreateTodoAnalysisModuleProcedureRegistry() =>
    _$createTodoAnalysisModuleProcedureRegistry();

// ignore: unused_element
RestRouteRegistry _$createTodoAnalysisModuleLocalRestRouteRegistry() {
  final container = _$createTodoAnalysisModuleContainer();
  return _$createTodoAnalysisModuleRestRouteRegistryFromContainer(container);
}

RestRouteRegistry _$createTodoAnalysisModuleRestRouteRegistryFromContainer(
  _$TodoAnalysisModuleContainer container,
) {
  return RestRouteRegistry([
    RestRoute(
      method: 'GET',
      path: '/todos/analysis/summary',
      handler: (context, request, pathParameters) async {
        final output = await container.todoAnalysisController.summary(context);
        return ((output) => encodeRpcOutputWithLuthor<TodoAnalysisSummaryDto>(
          output: output,
          method: 'todoAnalysis.summary',
          toJson: (output) => output.toJson(),
          validate: $TodoAnalysisSummaryDtoValidate,
        ))(output);
      },
    ),
  ]);
}

RestRouteRegistry _$createTodoAnalysisModuleRestRouteRegistry() {
  return RestRouteRegistry([
    ..._$createTodoAnalysisModuleLocalRestRouteRegistry().routes,
  ]);
}

RestRouteRegistry dartOrpcCreateTodoAnalysisModuleRestRouteRegistry() =>
    _$createTodoAnalysisModuleRestRouteRegistry();

// ignore: unused_element
ProcedureMetadataRegistry
_$createTodoAnalysisModuleLocalProcedureMetadataRegistry() {
  return ProcedureMetadataRegistry([
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

ProcedureMetadataRegistry
_$createTodoAnalysisModuleProcedureMetadataRegistry() {
  return ProcedureMetadataRegistry([
    ..._$createTodoAnalysisModuleLocalProcedureMetadataRegistry().procedures,
  ]);
}

ProcedureMetadataRegistry
dartOrpcCreateTodoAnalysisModuleProcedureMetadataRegistry() =>
    _$createTodoAnalysisModuleProcedureMetadataRegistry();

OpenApiSchemaRegistry _$createTodoAnalysisModuleLocalOpenApiSchemaRegistry() {
  return OpenApiSchemaRegistry([
    OpenApiSchemaComponent(
      name: 'TodoAnalysisSummaryDto',
      validator: $TodoAnalysisSummaryDtoSchema,
    ),
  ]);
}

OpenApiSchemaRegistry _$createTodoAnalysisModuleOpenApiSchemaRegistry() {
  return OpenApiSchemaRegistry([
    ..._$createTodoAnalysisModuleLocalOpenApiSchemaRegistry().components,
  ]);
}

OpenApiSchemaRegistry dartOrpcCreateTodoAnalysisModuleOpenApiSchemaRegistry() =>
    _$createTodoAnalysisModuleOpenApiSchemaRegistry();

JsonObject _$createTodoAnalysisModuleOpenApiDocument() {
  return createOpenApiDocument(
    title: 'TodoAnalysis API',
    procedures: _$createTodoAnalysisModuleProcedureMetadataRegistry(),
    schemas: _$createTodoAnalysisModuleOpenApiSchemaRegistry(),
  );
}

JsonObject dartOrpcCreateTodoAnalysisModuleOpenApiDocument() =>
    _$createTodoAnalysisModuleOpenApiDocument();

// ignore: unused_element
RpcHttpApp _$buildTodoAnalysisModuleRpcApp() {
  return RpcHttpApp(
    procedures: _$createTodoAnalysisModuleProcedureRegistry(),
    restRoutes: _$createTodoAnalysisModuleRestRouteRegistry(),
    openApiDocument: _$createTodoAnalysisModuleOpenApiDocument(),
    docsHtml: createScalarHtml(title: 'TodoAnalysis API'),
  );
}

RpcHttpApp dartOrpcBuildTodoAnalysisModuleRpcApp() =>
    _$buildTodoAnalysisModuleRpcApp();

class TodoAnalysisClientRoot {
  TodoAnalysisClientRoot({required RpcTransport transport})
    : _caller = RpcCaller(transport);

  final RpcCaller _caller;

  late final todoAnalysis = TodoAnalysisClient(_caller);
}

class TodoAnalysisClient {
  TodoAnalysisClient(this._caller);

  final RpcCaller _caller;

  Future<TodoAnalysisSummaryDto> summary() {
    return _caller.call<TodoAnalysisSummaryDto>(
      method: 'todoAnalysis.summary',
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
  RpcProcedureRegistry procedureRegistry() =>
      dartOrpcCreateTodoAnalysisModuleProcedureRegistry();
  RestRouteRegistry restRouteRegistry() =>
      dartOrpcCreateTodoAnalysisModuleRestRouteRegistry();
  ProcedureMetadataRegistry procedureMetadata() =>
      dartOrpcCreateTodoAnalysisModuleProcedureMetadataRegistry();
  OpenApiSchemaRegistry openApiSchemaRegistry() =>
      dartOrpcCreateTodoAnalysisModuleOpenApiSchemaRegistry();
  JsonObject openApiDocument() =>
      dartOrpcCreateTodoAnalysisModuleOpenApiDocument();
  RpcHttpApp buildRpcApp() => dartOrpcBuildTodoAnalysisModuleRpcApp();
  TodoAnalysisClientRoot createClient({required RpcTransport transport}) =>
      TodoAnalysisClientRoot(transport: transport);
}
