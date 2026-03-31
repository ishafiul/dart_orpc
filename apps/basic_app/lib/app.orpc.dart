// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// RpcModuleGenerator
// **************************************************************************

export 'package:basic_app/app.dart';
export 'package:basic_app/modules/todo/todo_module.orpc.dart';
export 'package:basic_app/modules/todo_analysis/todo_analysis_module.orpc.dart';

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
  Iterable<RpcHttpMiddleware> middleware = const [],
}) {
  final effectiveOpenApi = openApi ?? const OpenApiDocumentOptions();
  final effectiveDocs = docs ?? const RpcHttpDocsOptions();
  final effectiveOpenApiTitle = effectiveOpenApi.title ?? 'App API';
  final effectiveOpenApiPath = effectiveDocs.openApiPath;
  return RpcHttpApp(
    procedures: _$createAppModuleProcedureRegistry(),
    restRoutes: _$createAppModuleRestRouteRegistry(),
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
    middleware: middleware,
  );
}

RpcHttpApp dartOrpcBuildAppModuleRpcApp({
  OpenApiDocumentOptions? openApi,
  RpcHttpDocsOptions? docs,
  RpcHttpStaticOptions? staticAssets,
  RpcHttpHealthOptions? health,
  RpcHttpMetricsOptions? metrics,
  Iterable<RpcHttpMiddleware> middleware = const [],
}) => _$buildAppModuleRpcApp(
  openApi: openApi,
  docs: docs,
  staticAssets: staticAssets,
  health: health,
  metrics: metrics,
  middleware: middleware,
);

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
  JsonObject openApiDocument({OpenApiDocumentOptions? options}) =>
      dartOrpcCreateAppModuleOpenApiDocument(options: options);
  RpcHttpApp buildRpcApp({
    OpenApiDocumentOptions? openApi,
    RpcHttpDocsOptions? docs,
    RpcHttpStaticOptions? staticAssets,
    RpcHttpHealthOptions? health,
    RpcHttpMetricsOptions? metrics,
    Iterable<RpcHttpMiddleware> middleware = const [],
  }) => dartOrpcBuildAppModuleRpcApp(
    openApi: openApi,
    docs: docs,
    staticAssets: staticAssets,
    health: health,
    metrics: metrics,
    middleware: middleware,
  );
  AppClient createClient({required RpcTransport transport}) =>
      AppClient(transport: transport);
}
