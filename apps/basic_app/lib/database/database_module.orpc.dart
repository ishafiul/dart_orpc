// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// RpcModuleGenerator
// **************************************************************************

// ignore_for_file: unnecessary_import

export 'package:basic_app/database/database_module.dart';

import 'package:basic_app/database/app_database.dart';
import 'package:basic_app/database/database_module.dart';
import 'package:dart_orpc/dart_orpc.dart';

class _$DatabaseModuleContainer {
  _$DatabaseModuleContainer({required this.appDatabase});

  final AppDatabase appDatabase;

  Future<void> dispose() => disposeRpcProviders([appDatabase]);
}

_$DatabaseModuleContainer _$createDatabaseModuleContainer() {
  final appDatabase = AppDatabase();

  return _$DatabaseModuleContainer(appDatabase: appDatabase);
}

RpcProcedureRegistry _$createDatabaseModuleProcedureRegistryFromContainer(
  _$DatabaseModuleContainer container,
) {
  return RpcProcedureRegistry([]);
}

RpcProcedureRegistry _$createDatabaseModuleProcedureRegistry() =>
    _$createDatabaseModuleProcedureRegistryFromContainer(
      _$createDatabaseModuleContainer(),
    );

RpcProcedureRegistry dartOrpcCreateDatabaseModuleProcedureRegistry() =>
    _$createDatabaseModuleProcedureRegistry();

({RpcProcedureRegistry procedures, RestRouteRegistry restRoutes})
_$createDatabaseModuleRuntime() {
  final container = _$createDatabaseModuleContainer();
  return (
    procedures: _$createDatabaseModuleProcedureRegistryFromContainer(container),
    restRoutes: _$createDatabaseModuleRestRouteRegistryFromContainer(container),
  );
}

({RpcProcedureRegistry procedures, RestRouteRegistry restRoutes})
dartOrpcCreateDatabaseModuleRuntime() => _$createDatabaseModuleRuntime();

RestRouteRegistry _$createDatabaseModuleRestRouteRegistryFromContainer(
  _$DatabaseModuleContainer container,
) {
  return RestRouteRegistry([]);
}

RestRouteRegistry _$createDatabaseModuleRestRouteRegistry() =>
    _$createDatabaseModuleRestRouteRegistryFromContainer(
      _$createDatabaseModuleContainer(),
    );

RestRouteRegistry dartOrpcCreateDatabaseModuleRestRouteRegistry() =>
    _$createDatabaseModuleRestRouteRegistry();

final ProcedureMetadataRegistry _$databaseModuleProcedureMetadata =
    ProcedureMetadataRegistry([]);

ProcedureMetadataRegistry _$createDatabaseModuleProcedureMetadataRegistry() =>
    _$databaseModuleProcedureMetadata;

ProcedureMetadataRegistry
dartOrpcCreateDatabaseModuleProcedureMetadataRegistry() =>
    _$createDatabaseModuleProcedureMetadataRegistry();

JsonObject _$createDatabaseModuleOpenApiDocument({
  OpenApiDocumentOptions? options,
}) {
  final effectiveOptions = options ?? const OpenApiDocumentOptions();
  return createOpenApiDocument(
    title: effectiveOptions.title ?? 'Database API',
    version: effectiveOptions.version,
    description: effectiveOptions.description,
    servers: effectiveOptions.servers,
    procedures: _$createDatabaseModuleProcedureMetadataRegistry(),
    schemas: _$createDatabaseModuleDtoSchemaRegistry(),
  );
}

JsonObject dartOrpcCreateDatabaseModuleOpenApiDocument({
  OpenApiDocumentOptions? options,
}) => _$createDatabaseModuleOpenApiDocument(options: options);

RpcHttpApp _$buildDatabaseModuleRpcApp({
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
}) {
  final effectiveOpenApi = openApi ?? const OpenApiDocumentOptions();
  final effectiveDocs = docs ?? const RpcHttpDocsOptions();
  final effectiveOpenApiTitle = effectiveOpenApi.title ?? 'Database API';
  final effectiveOpenApiPath = effectiveDocs.openApiPath;
  final container = _$createDatabaseModuleContainer();
  final procedures = _$createDatabaseModuleProcedureRegistryFromContainer(
    container,
  );
  final restRoutes = _$createDatabaseModuleRestRouteRegistryFromContainer(
    container,
  );
  return RpcHttpApp(
    procedures: procedures,
    restRoutes: restRoutes,
    onClose: container.dispose,
    openApiDocument: _$createDatabaseModuleOpenApiDocument(
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
    upgradeHandlers: [
      if (webSocket != null)
        RpcWebSocketUpgradeHandler(procedures: procedures, options: webSocket),
    ],
  );
}

RpcHttpApp dartOrpcBuildDatabaseModuleRpcApp({
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
}) => _$buildDatabaseModuleRpcApp(
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

DtoSchemaRegistry _$createDatabaseModuleLocalDtoSchemaRegistry() {
  return DtoSchemaRegistry(const []);
}

DtoSchemaRegistry dartOrpcCreateDatabaseModuleLocalDtoSchemaRegistry() =>
    _$createDatabaseModuleLocalDtoSchemaRegistry();

DtoSchemaRegistry _$createDatabaseModuleDtoSchemaRegistry() {
  return DtoSchemaRegistry([
    ..._$createDatabaseModuleLocalDtoSchemaRegistry().schemas,
  ]);
}

DtoSchemaRegistry dartOrpcCreateDatabaseModuleDtoSchemaRegistry() =>
    _$createDatabaseModuleDtoSchemaRegistry();

class DatabaseClient {
  DatabaseClient({required RpcClientTransports transports});
}

extension DartOrpcDatabaseModuleGenerated on DatabaseModule {
  RpcProcedureRegistry procedureRegistry() =>
      dartOrpcCreateDatabaseModuleProcedureRegistry();
  RestRouteRegistry restRouteRegistry() =>
      dartOrpcCreateDatabaseModuleRestRouteRegistry();
  ProcedureMetadataRegistry procedureMetadata() =>
      dartOrpcCreateDatabaseModuleProcedureMetadataRegistry();
  DtoSchemaRegistry dtoSchemaRegistry() =>
      dartOrpcCreateDatabaseModuleDtoSchemaRegistry();
  JsonObject openApiDocument({OpenApiDocumentOptions? options}) =>
      dartOrpcCreateDatabaseModuleOpenApiDocument(options: options);
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
    bool encodeJsonToBytes = true,
    int? maxConcurrentRequests,
    Duration? requestBodyIdleTimeout,
    RpcHttpServerOptions serverOptions = const RpcHttpServerOptions(),
    Iterable<RpcHttpMiddleware> middleware = const [],
  }) => dartOrpcBuildDatabaseModuleRpcApp(
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
  DatabaseClient createClient({required RpcClientTransports transports}) =>
      DatabaseClient(transports: transports);
}
