// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// RpcModuleGenerator
// **************************************************************************

export 'package:basic_app/test_support/strip_module.dart';

import 'package:basic_app/test_support/strip_module.dart';
import 'package:dart_orpc/dart_orpc.dart';

class _$StripModuleContainer {
  _$StripModuleContainer({required this.stripController});

  final StripController stripController;

  Future<void> dispose() => disposeRpcProviders([stripController]);
}

_$StripModuleContainer _$createStripModuleContainer() {
  final stripController = StripController();

  return _$StripModuleContainer(stripController: stripController);
}

RpcProcedureRegistry _$createStripModuleProcedureRegistryFromContainer(
  _$StripModuleContainer container,
) {
  final metadataRegistry = _$stripModuleProcedureMetadata;
  return RpcProcedureRegistry([
    RpcUnaryProcedure<StripDto, StripDto>(
      method: 'strip.echo',
      decodeInput: (rawInput) => decodeRpcInputWithLuthor<StripDto>(
        rawInput: rawInput,
        method: 'strip.echo',
        validate: $StripDtoValidate,
      ),
      encodeOutput: (output) => encodeRpcOutputJsonWithLuthor<StripDto>(
        output: output,
        method: 'strip.echo',
        toJson: (output) => output.toJson(),
        validateJson: $StripDtoSchema.validate,
      ),
      metadata: metadataRegistry['strip.echo']!,

      handler: (context, input) => container.stripController.echo(input),
    ),
  ]);
}

RpcProcedureRegistry _$createStripModuleProcedureRegistry() =>
    _$createStripModuleProcedureRegistryFromContainer(
      _$createStripModuleContainer(),
    );

RpcProcedureRegistry dartOrpcCreateStripModuleProcedureRegistry() =>
    _$createStripModuleProcedureRegistry();

({RpcProcedureRegistry procedures, RestRouteRegistry restRoutes})
_$createStripModuleRuntime() {
  final container = _$createStripModuleContainer();
  return (
    procedures: _$createStripModuleProcedureRegistryFromContainer(container),
    restRoutes: _$createStripModuleRestRouteRegistryFromContainer(container),
  );
}

({RpcProcedureRegistry procedures, RestRouteRegistry restRoutes})
dartOrpcCreateStripModuleRuntime() => _$createStripModuleRuntime();

RestRouteRegistry _$createStripModuleRestRouteRegistryFromContainer(
  _$StripModuleContainer container,
) {
  final metadataRegistry = _$stripModuleProcedureMetadata;
  return RestRouteRegistry([
    RestUnaryRoute(
      method: 'POST',
      path: '/strip',
      handler: (context, request, pathParameters) {
        final rawInput = decodeRestRpcInputBody(
          request,
          route: 'POST /strip',
          parameterName: 'input',
        );
        final input = ((rawInput) => decodeRpcInputWithLuthor<StripDto>(
          rawInput: rawInput,
          method: 'strip.echo',
          validate: $StripDtoValidate,
        ))(rawInput);
        final output = container.stripController.echo(input);
        return encodeRpcOutputJsonWithLuthor<StripDto>(
          output: output,
          method: 'strip.echo',
          toJson: (output) => output.toJson(),
          validateJson: $StripDtoSchema.validate,
        );
      },
      metadata: metadataRegistry['strip.echo']!,
    ),
  ]);
}

RestRouteRegistry _$createStripModuleRestRouteRegistry() =>
    _$createStripModuleRestRouteRegistryFromContainer(
      _$createStripModuleContainer(),
    );

RestRouteRegistry dartOrpcCreateStripModuleRestRouteRegistry() =>
    _$createStripModuleRestRouteRegistry();

final ProcedureMetadataRegistry _$stripModuleProcedureMetadata =
    ProcedureMetadataRegistry([
      const ProcedureMetadata(
        rpcMethod: 'strip.echo',
        controllerNamespace: 'strip',
        methodName: 'echo',
        path: RestProcedureMetadata(method: 'POST', path: '/strip'),
        inputTypeCode: 'StripDto',
        outputTypeCode: 'StripDto',
        parameters: [
          ProcedureParameterMetadata(
            parameterName: 'input',
            wireName: 'input',
            source: ProcedureParameterSourceKind.body,
            typeCode: 'StripDto',
          ),
        ],
      ),
    ]);

ProcedureMetadataRegistry _$createStripModuleProcedureMetadataRegistry() =>
    _$stripModuleProcedureMetadata;

ProcedureMetadataRegistry
dartOrpcCreateStripModuleProcedureMetadataRegistry() =>
    _$createStripModuleProcedureMetadataRegistry();

JsonObject _$createStripModuleOpenApiDocument({
  OpenApiDocumentOptions? options,
}) {
  final effectiveOptions = options ?? const OpenApiDocumentOptions();
  return createOpenApiDocument(
    title: effectiveOptions.title ?? 'Strip API',
    version: effectiveOptions.version,
    description: effectiveOptions.description,
    servers: effectiveOptions.servers,
    procedures: _$createStripModuleProcedureMetadataRegistry(),
    schemas: _$createStripModuleDtoSchemaRegistry(),
  );
}

JsonObject dartOrpcCreateStripModuleOpenApiDocument({
  OpenApiDocumentOptions? options,
}) => _$createStripModuleOpenApiDocument(options: options);

RpcHttpApp _$buildStripModuleRpcApp({
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
  final effectiveOpenApiTitle = effectiveOpenApi.title ?? 'Strip API';
  final effectiveOpenApiPath = effectiveDocs.openApiPath;
  final container = _$createStripModuleContainer();
  final procedures = _$createStripModuleProcedureRegistryFromContainer(
    container,
  );
  final restRoutes = _$createStripModuleRestRouteRegistryFromContainer(
    container,
  );
  return RpcHttpApp(
    procedures: procedures,
    restRoutes: restRoutes,
    onClose: container.dispose,
    openApiDocument: _$createStripModuleOpenApiDocument(
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

RpcHttpApp dartOrpcBuildStripModuleRpcApp({
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
}) => _$buildStripModuleRpcApp(
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

DtoSchemaRegistry _$createStripModuleLocalDtoSchemaRegistry() {
  return DtoSchemaRegistry(const [
    DtoSchemaMetadata(
      name: 'StripDto',
      fields: [DtoFieldMetadata(wireName: 'value', type: DtoStringType())],
    ),
  ]);
}

DtoSchemaRegistry _$createStripModuleDtoSchemaRegistry() {
  return DtoSchemaRegistry([
    ..._$createStripModuleLocalDtoSchemaRegistry().schemas,
  ]);
}

DtoSchemaRegistry dartOrpcCreateStripModuleDtoSchemaRegistry() =>
    _$createStripModuleDtoSchemaRegistry();

class StripClientRoot {
  StripClientRoot({required RpcClientTransports transports})
    : _transports = transports;

  final RpcClientTransports _transports;

  late final strip = StripClient(_transports);
}

class StripClient {
  StripClient(this._transports);

  final RpcClientTransports _transports;

  Future<StripDto> echo(StripDto input) {
    return RpcCaller(_transports.requireUnary('strip.echo')).call<StripDto>(
      method: 'strip.echo',
      input: input.toJson(),
      options: null,
      decode: (json) => StripDto.fromJson(
        Map<String, dynamic>.from(
          expectJsonObject(json, context: 'RPC response for "strip.echo"'),
        ),
      ),
    );
  }
}

extension DartOrpcStripModuleGenerated on StripModule {
  RpcProcedureRegistry procedureRegistry() =>
      dartOrpcCreateStripModuleProcedureRegistry();
  RestRouteRegistry restRouteRegistry() =>
      dartOrpcCreateStripModuleRestRouteRegistry();
  ProcedureMetadataRegistry procedureMetadata() =>
      dartOrpcCreateStripModuleProcedureMetadataRegistry();
  DtoSchemaRegistry dtoSchemaRegistry() =>
      dartOrpcCreateStripModuleDtoSchemaRegistry();
  JsonObject openApiDocument({OpenApiDocumentOptions? options}) =>
      dartOrpcCreateStripModuleOpenApiDocument(options: options);
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
  }) => dartOrpcBuildStripModuleRpcApp(
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
  StripClientRoot createClient({required RpcClientTransports transports}) =>
      StripClientRoot(transports: transports);
}
