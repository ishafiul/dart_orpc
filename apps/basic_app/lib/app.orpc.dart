// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// RpcModuleGenerator
// **************************************************************************

export 'package:basic_app/app.dart';

import 'package:basic_app/app.dart';
import 'package:basic_app/modules/todo/todo_module.orpc.dart';
import 'package:basic_app/modules/todo_analysis/todo_analysis_module.orpc.dart';
import 'package:dart_orpc/dart_orpc.dart';

class _$AppModuleContainer {
  _$AppModuleContainer();
}

_$AppModuleContainer _$createAppModuleContainer() {
  return _$AppModuleContainer();
}

// ignore: unused_element
RpcProcedureRegistry _$createAppModuleLocalProcedureRegistry() {
  final container = _$createAppModuleContainer();
  return _$createAppModuleProcedureRegistryFromContainer(container);
}

RpcProcedureRegistry _$createAppModuleProcedureRegistryFromContainer(
  _$AppModuleContainer container,
) {
  return RpcProcedureRegistry([]);
}

RpcProcedureRegistry _$createAppModuleProcedureRegistry() {
  return RpcProcedureRegistry([
    ...dartOrpcCreateTodoModuleProcedureRegistry().procedures,
    ...dartOrpcCreateTodoAnalysisModuleProcedureRegistry().procedures,
    ..._$createAppModuleLocalProcedureRegistry().procedures,
  ]);
}

RpcProcedureRegistry dartOrpcCreateAppModuleProcedureRegistry() =>
    _$createAppModuleProcedureRegistry();

// ignore: unused_element
RestRouteRegistry _$createAppModuleLocalRestRouteRegistry() {
  final container = _$createAppModuleContainer();
  return _$createAppModuleRestRouteRegistryFromContainer(container);
}

RestRouteRegistry _$createAppModuleRestRouteRegistryFromContainer(
  _$AppModuleContainer container,
) {
  return RestRouteRegistry([]);
}

RestRouteRegistry _$createAppModuleRestRouteRegistry() {
  return RestRouteRegistry([
    ...dartOrpcCreateTodoModuleRestRouteRegistry().routes,
    ...dartOrpcCreateTodoAnalysisModuleRestRouteRegistry().routes,
    ..._$createAppModuleLocalRestRouteRegistry().routes,
  ]);
}

RestRouteRegistry dartOrpcCreateAppModuleRestRouteRegistry() =>
    _$createAppModuleRestRouteRegistry();

// ignore: unused_element
ProcedureMetadataRegistry _$createAppModuleLocalProcedureMetadataRegistry() {
  return ProcedureMetadataRegistry([]);
}

ProcedureMetadataRegistry _$createAppModuleProcedureMetadataRegistry() {
  return ProcedureMetadataRegistry([
    ...dartOrpcCreateTodoModuleProcedureMetadataRegistry().procedures,
    ...dartOrpcCreateTodoAnalysisModuleProcedureMetadataRegistry().procedures,
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
    ...dartOrpcCreateTodoModuleOpenApiSchemaRegistry().components,
    ...dartOrpcCreateTodoAnalysisModuleOpenApiSchemaRegistry().components,
    ..._$createAppModuleLocalOpenApiSchemaRegistry().components,
  ]);
}

OpenApiSchemaRegistry dartOrpcCreateAppModuleOpenApiSchemaRegistry() =>
    _$createAppModuleOpenApiSchemaRegistry();

JsonObject _$createAppModuleOpenApiDocument() {
  return createOpenApiDocument(
    title: 'App API',
    procedures: _$createAppModuleProcedureMetadataRegistry(),
    schemas: _$createAppModuleOpenApiSchemaRegistry(),
  );
}

JsonObject dartOrpcCreateAppModuleOpenApiDocument() =>
    _$createAppModuleOpenApiDocument();

// ignore: unused_element
RpcHttpApp _$buildAppModuleRpcApp() {
  return RpcHttpApp(
    procedures: _$createAppModuleProcedureRegistry(),
    restRoutes: _$createAppModuleRestRouteRegistry(),
    openApiDocument: _$createAppModuleOpenApiDocument(),
    docsHtml: createScalarHtml(title: 'App API'),
  );
}

RpcHttpApp dartOrpcBuildAppModuleRpcApp() => _$buildAppModuleRpcApp();

class AppClient {
  AppClient({required RpcTransport transport}) : _transport = transport;

  final RpcTransport _transport;

  late final TodoClientRoot _todoModuleClient = TodoClientRoot(
    transport: _transport,
  );
  late final TodoAnalysisClientRoot _todoAnalysisModuleClient =
      TodoAnalysisClientRoot(transport: _transport);
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
  JsonObject openApiDocument() => dartOrpcCreateAppModuleOpenApiDocument();
  RpcHttpApp buildRpcApp() => dartOrpcBuildAppModuleRpcApp();
  AppClient createClient({required RpcTransport transport}) =>
      AppClient(transport: transport);
}
