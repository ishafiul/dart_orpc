// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// RpcModuleGenerator
// **************************************************************************

export 'package:dart_orpc_user_test_benchmark/challenge_app.dart';
export 'package:dart_orpc_user_test_benchmark/challenge_dtos.dart';

import 'package:dart_orpc/dart_orpc.dart';
import 'package:dart_orpc_user_test_benchmark/challenge_app.dart';
import 'package:dart_orpc_user_test_benchmark/challenge_auth.dart';
import 'package:dart_orpc_user_test_benchmark/challenge_database.dart';
import 'package:dart_orpc_user_test_benchmark/challenge_dtos.dart';
import 'package:dart_orpc_user_test_benchmark/challenge_service.dart';

class _$ChallengeModuleContainer {
  _$ChallengeModuleContainer({
    required this.challengeDatabase,
    required this.challengeService,
    required this.challengeBearerGuard,
    required this.healthController,
    required this.postReadController,
    required this.postWriteController,
  });

  final ChallengeDatabase challengeDatabase;

  final ChallengeService challengeService;

  final ChallengeBearerGuard challengeBearerGuard;

  final HealthController healthController;

  final PostReadController postReadController;

  final PostWriteController postWriteController;

  Future<void> dispose() => disposeRpcProviders([
    postWriteController,
    postReadController,
    healthController,
    challengeBearerGuard,
    challengeService,
    challengeDatabase,
  ]);
}

_$ChallengeModuleContainer _$createChallengeModuleContainer() {
  final challengeDatabase = ChallengeDatabase();
  final challengeService = ChallengeService(challengeDatabase);
  final challengeBearerGuard = ChallengeBearerGuard();

  final healthController = HealthController(challengeService);

  final postReadController = PostReadController(challengeService);

  final postWriteController = PostWriteController(challengeService);

  return _$ChallengeModuleContainer(
    challengeDatabase: challengeDatabase,
    challengeService: challengeService,
    challengeBearerGuard: challengeBearerGuard,
    healthController: healthController,
    postReadController: postReadController,
    postWriteController: postWriteController,
  );
}

// ignore: unused_element
RpcProcedureRegistry _$createChallengeModuleLocalProcedureRegistry() {
  final container = _$createChallengeModuleContainer();
  return _$createChallengeModuleProcedureRegistryFromContainer(container);
}

RpcProcedureRegistry _$createChallengeModuleProcedureRegistryFromContainer(
  _$ChallengeModuleContainer container,
) {
  final metadataRegistry =
      _$createChallengeModuleLocalProcedureMetadataRegistry();
  return RpcProcedureRegistry([
    RpcUnaryProcedure<Null, HealthResponseDto>(
      method: 'health.health',
      decodeInput: (rawInput) =>
          expectNoRpcInput(rawInput, context: 'RPC method "health.health"'),
      encodeOutput: (output) => output.toJson(),
      metadata: metadataRegistry['health.health']!,

      handler: (context, input) => container.healthController.health(),
    ),
    RpcUnaryProcedure<Null, FeedResponseDto>(
      method: 'posts.feed',
      decodeInput: (rawInput) =>
          expectNoRpcInput(rawInput, context: 'RPC method "posts.feed"'),
      encodeOutput: (output) => output.toJson(),
      metadata: metadataRegistry['posts.feed']!,

      handler: (context, input) => container.postReadController.feed(),
    ),
  ]);
}

RpcProcedureRegistry _$createChallengeModuleProcedureRegistry() {
  return RpcProcedureRegistry([
    ..._$createChallengeModuleLocalProcedureRegistry().procedures,
  ]);
}

RpcProcedureRegistry dartOrpcCreateChallengeModuleProcedureRegistry() =>
    _$createChallengeModuleProcedureRegistry();

({RpcProcedureRegistry procedures, RestRouteRegistry restRoutes})
_$createChallengeModuleRuntime() {
  final container = _$createChallengeModuleContainer();
  final localProcedures = _$createChallengeModuleProcedureRegistryFromContainer(
    container,
  );
  final localRestRoutes = _$createChallengeModuleRestRouteRegistryFromContainer(
    container,
  );

  return (
    procedures: RpcProcedureRegistry([...localProcedures.procedures]),
    restRoutes: RestRouteRegistry([...localRestRoutes.routes]),
  );
}

({RpcProcedureRegistry procedures, RestRouteRegistry restRoutes})
dartOrpcCreateChallengeModuleRuntime() => _$createChallengeModuleRuntime();

// ignore: unused_element
RestRouteRegistry _$createChallengeModuleLocalRestRouteRegistry() {
  final container = _$createChallengeModuleContainer();
  return _$createChallengeModuleRestRouteRegistryFromContainer(container);
}

RestRouteRegistry _$createChallengeModuleRestRouteRegistryFromContainer(
  _$ChallengeModuleContainer container,
) {
  final metadataRegistry =
      _$createChallengeModuleLocalProcedureMetadataRegistry();
  return RestRouteRegistry([
    RestUnaryRoute(
      method: 'GET',
      path: '/health',
      handler: (context, request, pathParameters) {
        final output = container.healthController.health();
        return ((output) =>
            output is RpcJsonBytes ? output : output.toJson())(output);
      },
      metadata: metadataRegistry['health.health']!,
    ),
    RestUnaryRoute(
      method: 'GET',
      path: '/feed',
      handler: (context, request, pathParameters) {
        final output = container.postReadController.feed();
        return ((output) =>
            output is RpcJsonBytes ? output : output.toJson())(output);
      },
      metadata: metadataRegistry['posts.feed']!,
    ),
    RestUnaryRoute(
      method: 'GET',
      path: '/posts/:id',
      handler: (context, request, pathParameters) {
        final id = decodeRestScalarParameter<String>(
          rawValue: pathParameters['id'],
          source: 'path parameter',
          name: 'id',
          route: 'GET /posts/:id',
        );
        final output = container.postReadController.getById(id);
        return ((output) =>
            output is RpcJsonBytes ? output : output.toJson())(output);
      },
      metadata: metadataRegistry['posts.getById']!,
    ),
    RestUnaryRoute(
      method: 'POST',
      path: '/posts',
      handler: (context, request, pathParameters) {
        final body = decodeRestBody<Map<String, Object?>>(
          rawBody: request.body,
          route: 'POST /posts',
          parameterName: 'body',
          decode: (rawBody) =>
              expectJsonObject(rawBody, context: 'POST /posts body'),
        );
        final output = container.postWriteController.create(context, body);
        return ((output) =>
            output is RpcJsonBytes ? output : output.toJson())(output);
      },
      metadata: metadataRegistry['posts.create']!,
      guards: [container.challengeBearerGuard],
    ),
    RestUnaryRoute(
      method: 'POST',
      path: '/posts/:id/like',
      handler: (context, request, pathParameters) {
        final id = decodeRestScalarParameter<String>(
          rawValue: pathParameters['id'],
          source: 'path parameter',
          name: 'id',
          route: 'POST /posts/:id/like',
        );
        final output = container.postWriteController.like(context, id);
        return ((output) =>
            output is RpcJsonBytes ? output : output.toJson())(output);
      },
      metadata: metadataRegistry['posts.like']!,
      guards: [container.challengeBearerGuard],
    ),
  ]);
}

RestRouteRegistry _$createChallengeModuleRestRouteRegistry() {
  return RestRouteRegistry([
    ..._$createChallengeModuleLocalRestRouteRegistry().routes,
  ]);
}

RestRouteRegistry dartOrpcCreateChallengeModuleRestRouteRegistry() =>
    _$createChallengeModuleRestRouteRegistry();

// ignore: unused_element
ProcedureMetadataRegistry
_$createChallengeModuleLocalProcedureMetadataRegistry() {
  return ProcedureMetadataRegistry([
    const ProcedureMetadata(
      rpcMethod: 'health.health',
      controllerNamespace: 'health',
      methodName: 'health',
      path: RestProcedureMetadata(method: 'GET', path: '/health'),
      outputTypeCode: 'HealthResponseDto',
    ),
    const ProcedureMetadata(
      rpcMethod: 'posts.feed',
      controllerNamespace: 'posts',
      methodName: 'feed',
      path: RestProcedureMetadata(method: 'GET', path: '/feed'),
      outputTypeCode: 'FeedResponseDto',
    ),
    const ProcedureMetadata(
      rpcMethod: 'posts.getById',
      controllerNamespace: 'posts',
      methodName: 'getById',
      path: RestProcedureMetadata(method: 'GET', path: '/posts/:id'),
      outputTypeCode: 'PostResponseDto',
      parameters: [
        ProcedureParameterMetadata(
          parameterName: 'id',
          wireName: 'id',
          source: ProcedureParameterSourceKind.path,
          typeCode: 'String',
        ),
      ],
    ),
    const ProcedureMetadata(
      rpcMethod: 'posts.create',
      controllerNamespace: 'posts',
      methodName: 'create',
      path: RestProcedureMetadata(method: 'POST', path: '/posts'),
      outputTypeCode: 'CreatePostResponseDto',
      guardTypes: ['ChallengeBearerGuard'],
      securityRequirements: [ProcedureSecurityRequirement('bearerAuth')],
      parameters: [
        ProcedureParameterMetadata(
          parameterName: 'body',
          wireName: 'body',
          source: ProcedureParameterSourceKind.body,
          typeCode: 'Map<String, Object?>',
        ),
      ],
    ),
    const ProcedureMetadata(
      rpcMethod: 'posts.like',
      controllerNamespace: 'posts',
      methodName: 'like',
      path: RestProcedureMetadata(method: 'POST', path: '/posts/:id/like'),
      outputTypeCode: 'LikeResponseDto',
      guardTypes: ['ChallengeBearerGuard'],
      securityRequirements: [ProcedureSecurityRequirement('bearerAuth')],
      parameters: [
        ProcedureParameterMetadata(
          parameterName: 'id',
          wireName: 'id',
          source: ProcedureParameterSourceKind.path,
          typeCode: 'String',
        ),
      ],
    ),
  ]);
}

ProcedureMetadataRegistry _$createChallengeModuleProcedureMetadataRegistry() {
  return ProcedureMetadataRegistry([
    ..._$createChallengeModuleLocalProcedureMetadataRegistry().procedures,
  ]);
}

ProcedureMetadataRegistry
dartOrpcCreateChallengeModuleProcedureMetadataRegistry() =>
    _$createChallengeModuleProcedureMetadataRegistry();

OpenApiSchemaRegistry _$createChallengeModuleLocalOpenApiSchemaRegistry() {
  return OpenApiSchemaRegistry([]);
}

OpenApiSchemaRegistry _$createChallengeModuleOpenApiSchemaRegistry() {
  return OpenApiSchemaRegistry([
    ..._$createChallengeModuleLocalOpenApiSchemaRegistry().components,
  ]);
}

OpenApiSchemaRegistry dartOrpcCreateChallengeModuleOpenApiSchemaRegistry() =>
    _$createChallengeModuleOpenApiSchemaRegistry();

JsonObject _$createChallengeModuleOpenApiDocument({
  OpenApiDocumentOptions? options,
}) {
  final effectiveOptions = options ?? const OpenApiDocumentOptions();
  return createOpenApiDocument(
    title: effectiveOptions.title ?? 'Challenge API',
    version: effectiveOptions.version,
    description: effectiveOptions.description,
    servers: effectiveOptions.servers,
    procedures: _$createChallengeModuleProcedureMetadataRegistry(),
    schemas: _$createChallengeModuleOpenApiSchemaRegistry(),
  );
}

JsonObject dartOrpcCreateChallengeModuleOpenApiDocument({
  OpenApiDocumentOptions? options,
}) => _$createChallengeModuleOpenApiDocument(options: options);

RpcHttpApp _$buildChallengeModuleRpcApp({
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
  final effectiveOpenApiTitle = effectiveOpenApi.title ?? 'Challenge API';
  final effectiveOpenApiPath = effectiveDocs.openApiPath;
  final container = _$createChallengeModuleContainer();
  final procedures = _$createChallengeModuleProcedureRegistryFromContainer(
    container,
  );
  final restRoutes = _$createChallengeModuleRestRouteRegistryFromContainer(
    container,
  );
  return RpcHttpApp(
    procedures: procedures,
    restRoutes: restRoutes,
    onClose: container.dispose,
    openApiDocument: _$createChallengeModuleOpenApiDocument(
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

RpcHttpApp dartOrpcBuildChallengeModuleRpcApp({
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
}) => _$buildChallengeModuleRpcApp(
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

class ChallengeClient {
  ChallengeClient({required RpcClientTransports transports})
    : _transports = transports;

  final RpcClientTransports _transports;

  late final health = HealthClient(_transports);
  late final posts = PostReadClient(_transports);
}

class HealthClient {
  HealthClient(this._transports);

  final RpcClientTransports _transports;

  Future<HealthResponseDto> health() {
    return RpcCaller(
      _transports.requireUnary('health.health'),
    ).call<HealthResponseDto>(
      method: 'health.health',
      options: null,
      decode: (json) => HealthResponseDto.fromJson(
        Map<String, dynamic>.from(
          expectJsonObject(json, context: 'RPC response for "health.health"'),
        ),
      ),
    );
  }
}

class PostReadClient {
  PostReadClient(this._transports);

  final RpcClientTransports _transports;

  Future<FeedResponseDto> feed() {
    return RpcCaller(
      _transports.requireUnary('posts.feed'),
    ).call<FeedResponseDto>(
      method: 'posts.feed',
      options: null,
      decode: (json) => FeedResponseDto.fromJson(
        Map<String, dynamic>.from(
          expectJsonObject(json, context: 'RPC response for "posts.feed"'),
        ),
      ),
    );
  }
}

extension DartOrpcChallengeModuleGenerated on ChallengeModule {
  RpcProcedureRegistry procedureRegistry() =>
      dartOrpcCreateChallengeModuleProcedureRegistry();
  RestRouteRegistry restRouteRegistry() =>
      dartOrpcCreateChallengeModuleRestRouteRegistry();
  ProcedureMetadataRegistry procedureMetadata() =>
      dartOrpcCreateChallengeModuleProcedureMetadataRegistry();
  OpenApiSchemaRegistry openApiSchemaRegistry() =>
      dartOrpcCreateChallengeModuleOpenApiSchemaRegistry();
  JsonObject openApiDocument({OpenApiDocumentOptions? options}) =>
      dartOrpcCreateChallengeModuleOpenApiDocument(options: options);
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
  }) => dartOrpcBuildChallengeModuleRpcApp(
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
  ChallengeClient createClient({required RpcClientTransports transports}) =>
      ChallengeClient(transports: transports);
}
