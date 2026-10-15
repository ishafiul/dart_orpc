// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// **************************************************************************
// RpcModuleGenerator
// **************************************************************************

export 'package:basic_app/modules/auth/auth_dtos.dart';
export 'package:basic_app/modules/auth/auth_module.dart';

import 'package:basic_app/database/app_database.dart';
import 'package:basic_app/modules/auth/auth_controller.dart';
import 'package:basic_app/modules/auth/auth_dtos.dart';
import 'package:basic_app/modules/auth/auth_module.dart';
import 'package:basic_app/modules/auth/auth_service.dart';
import 'package:dart_orpc/dart_orpc.dart';

class _$AuthModuleContainer {
  _$AuthModuleContainer({
    required this.appDatabase,
    required this.authService,
    required this.authController,
  });

  final AppDatabase appDatabase;

  final AuthService authService;

  final AuthController authController;

  Future<void> dispose() =>
      disposeRpcProviders([authController, authService, appDatabase]);
}

_$AuthModuleContainer _$createAuthModuleContainer() {
  final appDatabase = AppDatabase();
  final authService = AuthService(appDatabase);

  final authController = AuthController(authService);

  return _$AuthModuleContainer(
    appDatabase: appDatabase,
    authService: authService,
    authController: authController,
  );
}

// ignore: unused_element
RpcProcedureRegistry _$createAuthModuleLocalProcedureRegistry() {
  final container = _$createAuthModuleContainer();
  return _$createAuthModuleProcedureRegistryFromContainer(container);
}

RpcProcedureRegistry _$createAuthModuleProcedureRegistryFromContainer(
  _$AuthModuleContainer container,
) {
  final metadataRegistry = _$createAuthModuleLocalProcedureMetadataRegistry();
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
  ]);
}

RpcProcedureRegistry _$createAuthModuleProcedureRegistry() {
  return RpcProcedureRegistry([
    ..._$createAuthModuleLocalProcedureRegistry().procedures,
  ]);
}

RpcProcedureRegistry dartOrpcCreateAuthModuleProcedureRegistry() =>
    _$createAuthModuleProcedureRegistry();

({RpcProcedureRegistry procedures, RestRouteRegistry restRoutes})
_$createAuthModuleRuntime() {
  final container = _$createAuthModuleContainer();
  final localProcedures = _$createAuthModuleProcedureRegistryFromContainer(
    container,
  );
  final localRestRoutes = _$createAuthModuleRestRouteRegistryFromContainer(
    container,
  );

  return (
    procedures: RpcProcedureRegistry([...localProcedures.procedures]),
    restRoutes: RestRouteRegistry([...localRestRoutes.routes]),
  );
}

({RpcProcedureRegistry procedures, RestRouteRegistry restRoutes})
dartOrpcCreateAuthModuleRuntime() => _$createAuthModuleRuntime();

// ignore: unused_element
RestRouteRegistry _$createAuthModuleLocalRestRouteRegistry() {
  final container = _$createAuthModuleContainer();
  return _$createAuthModuleRestRouteRegistryFromContainer(container);
}

RestRouteRegistry _$createAuthModuleRestRouteRegistryFromContainer(
  _$AuthModuleContainer container,
) {
  final metadataRegistry = _$createAuthModuleLocalProcedureMetadataRegistry();
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
  ]);
}

RestRouteRegistry _$createAuthModuleRestRouteRegistry() {
  return RestRouteRegistry([
    ..._$createAuthModuleLocalRestRouteRegistry().routes,
  ]);
}

RestRouteRegistry dartOrpcCreateAuthModuleRestRouteRegistry() =>
    _$createAuthModuleRestRouteRegistry();

// ignore: unused_element
ProcedureMetadataRegistry _$createAuthModuleLocalProcedureMetadataRegistry() {
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
  ]);
}

ProcedureMetadataRegistry _$createAuthModuleProcedureMetadataRegistry() {
  return ProcedureMetadataRegistry([
    ..._$createAuthModuleLocalProcedureMetadataRegistry().procedures,
  ]);
}

ProcedureMetadataRegistry dartOrpcCreateAuthModuleProcedureMetadataRegistry() =>
    _$createAuthModuleProcedureMetadataRegistry();

OpenApiSchemaRegistry _$createAuthModuleLocalOpenApiSchemaRegistry() {
  return OpenApiSchemaRegistry([
    OpenApiSchemaComponent(
      name: 'AuthResponseDto',
      validator: $AuthResponseDtoSchema,
    ),
    OpenApiSchemaComponent(name: 'AuthUserDto', validator: $AuthUserDtoSchema),
    OpenApiSchemaComponent(name: 'LoginDto', validator: $LoginDtoSchema),
    OpenApiSchemaComponent(name: 'SignUpDto', validator: $SignUpDtoSchema),
  ]);
}

OpenApiSchemaRegistry _$createAuthModuleOpenApiSchemaRegistry() {
  return OpenApiSchemaRegistry([
    ..._$createAuthModuleLocalOpenApiSchemaRegistry().components,
  ]);
}

OpenApiSchemaRegistry dartOrpcCreateAuthModuleOpenApiSchemaRegistry() =>
    _$createAuthModuleOpenApiSchemaRegistry();

JsonObject _$createAuthModuleOpenApiDocument({
  OpenApiDocumentOptions? options,
}) {
  final effectiveOptions = options ?? const OpenApiDocumentOptions();
  return createOpenApiDocument(
    title: effectiveOptions.title ?? 'Auth API',
    version: effectiveOptions.version,
    description: effectiveOptions.description,
    servers: effectiveOptions.servers,
    procedures: _$createAuthModuleProcedureMetadataRegistry(),
    schemas: _$createAuthModuleOpenApiSchemaRegistry(),
  );
}

JsonObject dartOrpcCreateAuthModuleOpenApiDocument({
  OpenApiDocumentOptions? options,
}) => _$createAuthModuleOpenApiDocument(options: options);

RpcHttpApp _$buildAuthModuleRpcApp({
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
  final effectiveOpenApiTitle = effectiveOpenApi.title ?? 'Auth API';
  final effectiveOpenApiPath = effectiveDocs.openApiPath;
  final container = _$createAuthModuleContainer();
  final procedures = _$createAuthModuleProcedureRegistryFromContainer(
    container,
  );
  final restRoutes = _$createAuthModuleRestRouteRegistryFromContainer(
    container,
  );
  return RpcHttpApp(
    procedures: procedures,
    restRoutes: restRoutes,
    onClose: container.dispose,
    openApiDocument: _$createAuthModuleOpenApiDocument(
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

RpcHttpApp dartOrpcBuildAuthModuleRpcApp({
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
}) => _$buildAuthModuleRpcApp(
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

class AuthClientRoot {
  AuthClientRoot({required RpcClientTransports transports})
    : _transports = transports;

  final RpcClientTransports _transports;

  late final auth = AuthClient(_transports);
}

class AuthClient {
  AuthClient(this._transports);

  final RpcClientTransports _transports;

  Future<AuthResponseDto> signUp(SignUpDto input) {
    return RpcCaller(
      _transports.requireUnary('auth.signUp'),
    ).call<AuthResponseDto>(
      method: 'auth.signUp',
      input: input.toJson(),
      options: null,
      decode: (json) => AuthResponseDto.fromJson(
        Map<String, dynamic>.from(
          expectJsonObject(json, context: 'RPC response for "auth.signUp"'),
        ),
      ),
    );
  }

  Future<AuthResponseDto> login(LoginDto input) {
    return RpcCaller(
      _transports.requireUnary('auth.login'),
    ).call<AuthResponseDto>(
      method: 'auth.login',
      input: input.toJson(),
      options: null,
      decode: (json) => AuthResponseDto.fromJson(
        Map<String, dynamic>.from(
          expectJsonObject(json, context: 'RPC response for "auth.login"'),
        ),
      ),
    );
  }

  Future<int> test() {
    return RpcCaller(_transports.requireUnary('auth.test')).call<int>(
      method: 'auth.test',
      options: null,
      decode: (json) => json as int,
    );
  }
}

extension DartOrpcAuthModuleGenerated on AuthModule {
  RpcProcedureRegistry procedureRegistry() =>
      dartOrpcCreateAuthModuleProcedureRegistry();
  RestRouteRegistry restRouteRegistry() =>
      dartOrpcCreateAuthModuleRestRouteRegistry();
  ProcedureMetadataRegistry procedureMetadata() =>
      dartOrpcCreateAuthModuleProcedureMetadataRegistry();
  OpenApiSchemaRegistry openApiSchemaRegistry() =>
      dartOrpcCreateAuthModuleOpenApiSchemaRegistry();
  JsonObject openApiDocument({OpenApiDocumentOptions? options}) =>
      dartOrpcCreateAuthModuleOpenApiDocument(options: options);
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
  }) => dartOrpcBuildAuthModuleRpcApp(
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
  AuthClientRoot createClient({required RpcClientTransports transports}) =>
      AuthClientRoot(transports: transports);
}
