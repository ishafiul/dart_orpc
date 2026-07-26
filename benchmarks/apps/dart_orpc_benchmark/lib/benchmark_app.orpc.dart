// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// RpcModuleGenerator
// **************************************************************************

export 'package:dart_orpc_benchmark/benchmark_app.dart';

import 'package:dart_orpc/dart_orpc.dart';
import 'package:dart_orpc_benchmark/benchmark_app.dart';

class _$BenchmarkModuleContainer {
  _$BenchmarkModuleContainer({
    required this.benchmarkService,
    required this.benchmarkController,
  });

  final BenchmarkService benchmarkService;

  final BenchmarkController benchmarkController;
}

_$BenchmarkModuleContainer _$createBenchmarkModuleContainer() {
  final benchmarkService = BenchmarkService();

  final benchmarkController = BenchmarkController(benchmarkService);

  return _$BenchmarkModuleContainer(
    benchmarkService: benchmarkService,
    benchmarkController: benchmarkController,
  );
}

// ignore: unused_element
RpcProcedureRegistry _$createBenchmarkModuleLocalProcedureRegistry() {
  final container = _$createBenchmarkModuleContainer();
  return _$createBenchmarkModuleProcedureRegistryFromContainer(container);
}

RpcProcedureRegistry _$createBenchmarkModuleProcedureRegistryFromContainer(
  _$BenchmarkModuleContainer container,
) {
  final metadataRegistry =
      _$createBenchmarkModuleLocalProcedureMetadataRegistry();
  return RpcProcedureRegistry([
    RpcUnaryProcedure<CatalogQueryDto, CatalogResponseDto>(
      method: 'benchmark.catalog',
      decodeInput: (rawInput) => decodeRpcInputWithLuthor<CatalogQueryDto>(
        rawInput: rawInput,
        method: 'benchmark.catalog',
        validate: $CatalogQueryDtoValidate,
      ),
      encodeOutput: (output) => output.toJson(),
      metadata: metadataRegistry['benchmark.catalog']!,

      handler: (context, input) => container.benchmarkController.catalog(input),
    ),
    RpcUnaryProcedure<CheckoutInputDto, CheckoutResponseDto>(
      method: 'benchmark.checkout',
      decodeInput: (rawInput) => decodeRpcInputWithLuthor<CheckoutInputDto>(
        rawInput: rawInput,
        method: 'benchmark.checkout',
        validate: $CheckoutInputDtoValidate,
      ),
      encodeOutput: (output) => output.toJson(),
      metadata: metadataRegistry['benchmark.checkout']!,

      handler: (context, input) =>
          container.benchmarkController.checkout(input),
    ),
    RpcUnaryProcedure<EchoInputDto, EchoResponseDto>(
      method: 'benchmark.echo',
      decodeInput: (rawInput) => decodeRpcInputWithLuthor<EchoInputDto>(
        rawInput: rawInput,
        method: 'benchmark.echo',
        validate: $EchoInputDtoValidate,
      ),
      encodeOutput: (output) => output.toJson(),
      metadata: metadataRegistry['benchmark.echo']!,

      handler: (context, input) => container.benchmarkController.echo(input),
    ),
  ]);
}

RpcProcedureRegistry _$createBenchmarkModuleProcedureRegistry() {
  return RpcProcedureRegistry([
    ..._$createBenchmarkModuleLocalProcedureRegistry().procedures,
  ]);
}

RpcProcedureRegistry dartOrpcCreateBenchmarkModuleProcedureRegistry() =>
    _$createBenchmarkModuleProcedureRegistry();

({RpcProcedureRegistry procedures, RestRouteRegistry restRoutes})
_$createBenchmarkModuleRuntime() {
  final container = _$createBenchmarkModuleContainer();
  final localProcedures = _$createBenchmarkModuleProcedureRegistryFromContainer(
    container,
  );
  final localRestRoutes = _$createBenchmarkModuleRestRouteRegistryFromContainer(
    container,
  );

  return (
    procedures: RpcProcedureRegistry([...localProcedures.procedures]),
    restRoutes: RestRouteRegistry([...localRestRoutes.routes]),
  );
}

({RpcProcedureRegistry procedures, RestRouteRegistry restRoutes})
dartOrpcCreateBenchmarkModuleRuntime() => _$createBenchmarkModuleRuntime();

// ignore: unused_element
RestRouteRegistry _$createBenchmarkModuleLocalRestRouteRegistry() {
  final container = _$createBenchmarkModuleContainer();
  return _$createBenchmarkModuleRestRouteRegistryFromContainer(container);
}

RestRouteRegistry _$createBenchmarkModuleRestRouteRegistryFromContainer(
  _$BenchmarkModuleContainer container,
) {
  final metadataRegistry =
      _$createBenchmarkModuleLocalProcedureMetadataRegistry();
  return RestRouteRegistry([
    RestUnaryRoute(
      method: 'GET',
      path: '/catalog',
      handler: (context, request, pathParameters) async {
        final rawInput = <String, Object?>{};
        rawInput['category'] = decodeRestScalarParameter<String>(
          rawValue: request.queryParameters['category'],
          source: 'query parameter',
          name: 'category',
          route: 'GET /catalog',
        );
        rawInput['page'] = decodeRestScalarParameter<int>(
          rawValue: request.queryParameters['page'],
          source: 'query parameter',
          name: 'page',
          route: 'GET /catalog',
        );
        rawInput['limit'] = decodeRestScalarParameter<int>(
          rawValue: request.queryParameters['limit'],
          source: 'query parameter',
          name: 'limit',
          route: 'GET /catalog',
        );
        final input = ((rawInput) => decodeRpcInputWithLuthor<CatalogQueryDto>(
          rawInput: rawInput,
          method: 'benchmark.catalog',
          validate: $CatalogQueryDtoValidate,
        ))(rawInput);
        final output = await container.benchmarkController.catalog(input);
        return ((output) => output.toJson())(output);
      },
      metadata: metadataRegistry['benchmark.catalog']!,
    ),
    RestUnaryRoute(
      method: 'POST',
      path: '/checkout',
      handler: (context, request, pathParameters) async {
        final rawInput = request.body.trim().isEmpty
            ? <String, Object?>{}
            : Map<String, Object?>.from(
                decodeRestBody<JsonObject>(
                  rawBody: request.body,
                  route: 'POST /checkout',
                  parameterName: 'input',
                  decode: (rawJson) =>
                      expectJsonObject(rawJson, context: 'POST /checkout body'),
                ),
              );
        final input = ((rawInput) => decodeRpcInputWithLuthor<CheckoutInputDto>(
          rawInput: rawInput,
          method: 'benchmark.checkout',
          validate: $CheckoutInputDtoValidate,
        ))(rawInput);
        final output = await container.benchmarkController.checkout(input);
        return ((output) => output.toJson())(output);
      },
      metadata: metadataRegistry['benchmark.checkout']!,
    ),
  ]);
}

RestRouteRegistry _$createBenchmarkModuleRestRouteRegistry() {
  return RestRouteRegistry([
    ..._$createBenchmarkModuleLocalRestRouteRegistry().routes,
  ]);
}

RestRouteRegistry dartOrpcCreateBenchmarkModuleRestRouteRegistry() =>
    _$createBenchmarkModuleRestRouteRegistry();

// ignore: unused_element
ProcedureMetadataRegistry
_$createBenchmarkModuleLocalProcedureMetadataRegistry() {
  return ProcedureMetadataRegistry([
    const ProcedureMetadata(
      rpcMethod: 'benchmark.catalog',
      controllerNamespace: 'benchmark',
      methodName: 'catalog',
      path: RestProcedureMetadata(method: 'GET', path: '/catalog'),
      inputTypeCode: 'CatalogQueryDto',
      outputTypeCode: 'CatalogResponseDto',
      description: 'Return a filtered page of catalog items.',
      tags: ['benchmark'],
      parameters: [
        ProcedureParameterMetadata(
          parameterName: 'category',
          wireName: 'category',
          source: ProcedureParameterSourceKind.query,
          typeCode: 'String',
        ),
        ProcedureParameterMetadata(
          parameterName: 'page',
          wireName: 'page',
          source: ProcedureParameterSourceKind.query,
          typeCode: 'int',
        ),
        ProcedureParameterMetadata(
          parameterName: 'limit',
          wireName: 'limit',
          source: ProcedureParameterSourceKind.query,
          typeCode: 'int',
        ),
      ],
    ),
    const ProcedureMetadata(
      rpcMethod: 'benchmark.checkout',
      controllerNamespace: 'benchmark',
      methodName: 'checkout',
      path: RestProcedureMetadata(method: 'POST', path: '/checkout'),
      inputTypeCode: 'CheckoutInputDto',
      outputTypeCode: 'CheckoutResponseDto',
      description: 'Validate and calculate a checkout.',
      tags: ['benchmark'],
      parameters: [
        ProcedureParameterMetadata(
          parameterName: 'input',
          wireName: 'input',
          source: ProcedureParameterSourceKind.body,
          typeCode: 'CheckoutInputDto',
        ),
      ],
    ),
    const ProcedureMetadata(
      rpcMethod: 'benchmark.echo',
      controllerNamespace: 'benchmark',
      methodName: 'echo',
      inputTypeCode: 'EchoInputDto',
      outputTypeCode: 'EchoResponseDto',
      parameters: [
        ProcedureParameterMetadata(
          parameterName: 'input',
          wireName: 'input',
          source: ProcedureParameterSourceKind.rpcInput,
          typeCode: 'EchoInputDto',
        ),
      ],
    ),
  ]);
}

ProcedureMetadataRegistry _$createBenchmarkModuleProcedureMetadataRegistry() {
  return ProcedureMetadataRegistry([
    ..._$createBenchmarkModuleLocalProcedureMetadataRegistry().procedures,
  ]);
}

ProcedureMetadataRegistry
dartOrpcCreateBenchmarkModuleProcedureMetadataRegistry() =>
    _$createBenchmarkModuleProcedureMetadataRegistry();

OpenApiSchemaRegistry _$createBenchmarkModuleLocalOpenApiSchemaRegistry() {
  return OpenApiSchemaRegistry([
    OpenApiSchemaComponent(
      name: 'CatalogQueryDto',
      validator: $CatalogQueryDtoSchema,
    ),
    OpenApiSchemaComponent(
      name: 'CheckoutCustomerDto',
      validator: $CheckoutCustomerDtoSchema,
    ),
    OpenApiSchemaComponent(
      name: 'CheckoutInputDto',
      validator: $CheckoutInputDtoSchema,
    ),
    OpenApiSchemaComponent(
      name: 'CheckoutItemDto',
      validator: $CheckoutItemDtoSchema,
    ),
  ]);
}

OpenApiSchemaRegistry _$createBenchmarkModuleOpenApiSchemaRegistry() {
  return OpenApiSchemaRegistry([
    ..._$createBenchmarkModuleLocalOpenApiSchemaRegistry().components,
  ]);
}

OpenApiSchemaRegistry dartOrpcCreateBenchmarkModuleOpenApiSchemaRegistry() =>
    _$createBenchmarkModuleOpenApiSchemaRegistry();

JsonObject _$createBenchmarkModuleOpenApiDocument({
  OpenApiDocumentOptions? options,
}) {
  final effectiveOptions = options ?? const OpenApiDocumentOptions();
  return createOpenApiDocument(
    title: effectiveOptions.title ?? 'Benchmark API',
    version: effectiveOptions.version,
    description: effectiveOptions.description,
    servers: effectiveOptions.servers,
    procedures: _$createBenchmarkModuleProcedureMetadataRegistry(),
    schemas: _$createBenchmarkModuleOpenApiSchemaRegistry(),
  );
}

JsonObject dartOrpcCreateBenchmarkModuleOpenApiDocument({
  OpenApiDocumentOptions? options,
}) => _$createBenchmarkModuleOpenApiDocument(options: options);

RpcHttpApp _$buildBenchmarkModuleRpcApp({
  OpenApiDocumentOptions? openApi,
  RpcHttpDocsOptions? docs,
  RpcHttpStaticOptions? staticAssets,
  RpcHttpHealthOptions? health,
  RpcHttpMetricsOptions? metrics,
  RpcWebSocketServerOptions? webSocket,
  RpcContextBindings bindings = const RpcContextBindings.empty(),
  RpcContextFactory? contextFactory,
  Duration sseHeartbeatInterval = const Duration(seconds: 15),
  Iterable<RpcHttpMiddleware> middleware = const [],
}) {
  final effectiveOpenApi = openApi ?? const OpenApiDocumentOptions();
  final effectiveDocs = docs ?? const RpcHttpDocsOptions();
  final effectiveOpenApiTitle = effectiveOpenApi.title ?? 'Benchmark API';
  final effectiveOpenApiPath = effectiveDocs.openApiPath;
  final runtime = _$createBenchmarkModuleRuntime();
  return RpcHttpApp(
    procedures: runtime.procedures,
    restRoutes: runtime.restRoutes,
    openApiDocument: _$createBenchmarkModuleOpenApiDocument(
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
    upgradeHandlers: [
      if (webSocket != null)
        RpcWebSocketUpgradeHandler(
          procedures: runtime.procedures,
          options: webSocket,
        ),
    ],
    middleware: middleware,
  );
}

RpcHttpApp dartOrpcBuildBenchmarkModuleRpcApp({
  OpenApiDocumentOptions? openApi,
  RpcHttpDocsOptions? docs,
  RpcHttpStaticOptions? staticAssets,
  RpcHttpHealthOptions? health,
  RpcHttpMetricsOptions? metrics,
  RpcWebSocketServerOptions? webSocket,
  RpcContextBindings bindings = const RpcContextBindings.empty(),
  RpcContextFactory? contextFactory,
  Duration sseHeartbeatInterval = const Duration(seconds: 15),
  Iterable<RpcHttpMiddleware> middleware = const [],
}) => _$buildBenchmarkModuleRpcApp(
  openApi: openApi,
  docs: docs,
  staticAssets: staticAssets,
  health: health,
  metrics: metrics,
  webSocket: webSocket,
  bindings: bindings,
  contextFactory: contextFactory,
  sseHeartbeatInterval: sseHeartbeatInterval,
  middleware: middleware,
);

class BenchmarkClientRoot {
  BenchmarkClientRoot({required RpcClientTransports transports})
    : _transports = transports;

  final RpcClientTransports _transports;

  late final benchmark = BenchmarkClient(_transports);
}

class BenchmarkClient {
  BenchmarkClient(this._transports);

  final RpcClientTransports _transports;

  Future<CatalogResponseDto> catalog(CatalogQueryDto input) {
    return RpcCaller(
      _transports.requireUnary('benchmark.catalog'),
    ).call<CatalogResponseDto>(
      method: 'benchmark.catalog',
      input: input.toJson(),
      decode: (json) => CatalogResponseDto.fromJson(
        Map<String, dynamic>.from(
          expectJsonObject(
            json,
            context: 'RPC response for "benchmark.catalog"',
          ),
        ),
      ),
    );
  }

  Future<CheckoutResponseDto> checkout(CheckoutInputDto input) {
    return RpcCaller(
      _transports.requireUnary('benchmark.checkout'),
    ).call<CheckoutResponseDto>(
      method: 'benchmark.checkout',
      input: input.toJson(),
      decode: (json) => CheckoutResponseDto.fromJson(
        Map<String, dynamic>.from(
          expectJsonObject(
            json,
            context: 'RPC response for "benchmark.checkout"',
          ),
        ),
      ),
    );
  }

  Future<EchoResponseDto> echo(EchoInputDto input) {
    return RpcCaller(
      _transports.requireUnary('benchmark.echo'),
    ).call<EchoResponseDto>(
      method: 'benchmark.echo',
      input: input.toJson(),
      decode: (json) => EchoResponseDto.fromJson(
        Map<String, dynamic>.from(
          expectJsonObject(json, context: 'RPC response for "benchmark.echo"'),
        ),
      ),
    );
  }
}

extension DartOrpcBenchmarkModuleGenerated on BenchmarkModule {
  RpcProcedureRegistry procedureRegistry() =>
      dartOrpcCreateBenchmarkModuleProcedureRegistry();
  RestRouteRegistry restRouteRegistry() =>
      dartOrpcCreateBenchmarkModuleRestRouteRegistry();
  ProcedureMetadataRegistry procedureMetadata() =>
      dartOrpcCreateBenchmarkModuleProcedureMetadataRegistry();
  OpenApiSchemaRegistry openApiSchemaRegistry() =>
      dartOrpcCreateBenchmarkModuleOpenApiSchemaRegistry();
  JsonObject openApiDocument({OpenApiDocumentOptions? options}) =>
      dartOrpcCreateBenchmarkModuleOpenApiDocument(options: options);
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
    Iterable<RpcHttpMiddleware> middleware = const [],
  }) => dartOrpcBuildBenchmarkModuleRpcApp(
    openApi: openApi,
    docs: docs,
    staticAssets: staticAssets,
    health: health,
    metrics: metrics,
    webSocket: webSocket,
    bindings: bindings,
    contextFactory: contextFactory,
    sseHeartbeatInterval: sseHeartbeatInterval,
    middleware: middleware,
  );
  BenchmarkClientRoot createClient({required RpcClientTransports transports}) =>
      BenchmarkClientRoot(transports: transports);
}
